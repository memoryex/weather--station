#Requires AutoHotkey v2.0

/*
    ========================================================================
    LoRa DX-LR22 868MHz - Valdymo ir Stebėsenos Skydelis (Dashboard)
    ========================================================================
    - Tiesioginė Win32 serijinio prievado (COM Port) komunikacija per kernel32.dll
    - Automatinis COM prievadų aptikimas iš Windows registro
    - ESP32-C3 CPU temperatūros ir būsenos gavimas realiuoju laiku
    - Interaktyvus RGB LED valdymas (spalvų pasirinkimas, RGB šliaužikliai)
    - PING / PONG ryšio tikrinimas ir komandų siuntimas
    - Būsenos žurnalas (Log Console) su laiko žymomis
*/

; 全局 Global Variables
global g_ComPort := "COM6"
global g_BaudRate := 9600
global g_hCom := -1
global g_IsConnected := false
global g_RxBuffer := ""
global g_CurrentTemp := "---"

; Langelio sukūrimas (GUI Setup)
mainGui := Gui("+Resize +MinSize480x520", "LoRa DX-LR22 (868MHz) - Dashboard")
mainGui.SetFont("s10", "Segoe UI")
mainGui.OnEvent("Close", (*) => OnGuiClose())

; --- COM Prievado Pasirinkimas ---
mainGui.AddGroupBox("w440 h70 x15 y10", "Serijinis Prievadas (COM Port)")
mainGui.AddText("x30 y35", "Prievadas:")
cbComPorts := mainGui.AddComboBox("x100 y31 w120", GetAvailableComPorts())
cbComPorts.Text := g_ComPort
btnConnect := mainGui.AddButton("x230 y30 w90 h28", "Prisijungti")
btnConnect.OnEvent("Click", (*) => ToggleConnection())
btnRefresh := mainGui.AddButton("x330 y30 w110 h28", "Atnaujinti Sąrašą")
btnRefresh.OnEvent("Click", (*) => RefreshComList())

; --- Telemetrija ir Būsenos ---
mainGui.AddGroupBox("w440 h100 x15 y90", "ESP32 Telemetrija & Būsena")
txtStatus := mainGui.AddText("x30 y115 w380", "Būsena: Neprisijungta 🔴")
txtTemp := mainGui.AddText("x30 y145 w380", "CPU Temperatūra: --- °C")
txtTemp.SetFont("s12 bold", "Segoe UI")

; --- RGB Valdymas ---
mainGui.AddGroupBox("w440 h180 x15 y200", "RGB Neopixel Valdymas (Pin 8)")

; Greiti mygtukai
mainGui.AddButton("x30 y225 w80 h30", "Raudona").OnEvent("Click", (*) => SetRGB(255, 0, 0))
mainGui.AddButton("x120 y225 w80 h30", "Žalia").OnEvent("Click", (*) => SetRGB(0, 255, 0))
mainGui.AddButton("x210 y225 w80 h30", "Mėlyna").OnEvent("Click", (*) => SetRGB(0, 0, 255))
mainGui.AddButton("x300 y225 w60 h30", "Geltona").OnEvent("Click", (*) => SetRGB(255, 255, 0))
mainGui.AddButton("x370 y225 w70 h30", "Išjungti").OnEvent("Click", (*) => SetRGB(0, 0, 0))

; RGB Šliaužikliai (Sliders)
mainGui.AddText("x30 y270 w20", "R:")
sldR := mainGui.AddSlider("x50 y265 w200 Range0-255", 0)
txtRVal := mainGui.AddText("x255 y270 w30", "0")

mainGui.AddText("x30 y300 w20", "G:")
sldG := mainGui.AddSlider("x50 y295 w200 Range0-255", 0)
txtGVal := mainGui.AddText("x255 y300 w30", "0")

mainGui.AddText("x30 y330 w20", "B:")
sldB := mainGui.AddSlider("x50 y325 w200 Range0-255", 0)
txtBVal := mainGui.AddText("x255 y330 w30", "0")

sldR.OnEvent("Change", (*) => OnSliderChange())
sldG.OnEvent("Change", (*) => OnSliderChange())
sldB.OnEvent("Change", (*) => OnSliderChange())

btnSendRGB := mainGui.AddButton("x295 y270 w145 h40", "Siųsti RGB")
btnSendRGB.OnEvent("Click", (*) => SetRGB(sldR.Value, sldG.Value, sldB.Value))

; Spalvos peržiūros blokas (Color Preview Box)
picPreview := mainGui.AddProgress("x295 y320 w145 h20 Background000000", 0)

; --- Komandų Siuntimas Ir Testavimas ---
mainGui.AddGroupBox("w440 h70 x15 y390", "Siųsti Pasirinktinę Komandą")
edtCustomCmd := mainGui.AddEdit("x30 y415 w230", "PING")
btnSendCustom := mainGui.AddButton("x270 y414 w80 h28", "Siųsti")
btnSendCustom.OnEvent("Click", (*) => SendCustomCommand())
btnPing := mainGui.AddButton("x355 y414 w85 h28", "PING")
btnPing.OnEvent("Click", (*) => SendCmd("PING"))

; --- Komunikacijos Žurnalas (Log Console) ---
mainGui.AddGroupBox("w440 h180 x15 y470", "Komunikacijos Žurnalas")
edtLog := mainGui.AddEdit("x30 y495 w410 h120 ReadOnly Multi +0x100000") ; WS_VSCROLL
btnClearLog := mainGui.AddButton("x340 y620 w100 h25", "Valyti žurnalą")
btnClearLog.OnEvent("Click", (*) => (edtLog.Value := ""))

mainGui.Show("w470 h655")

; Periodinė Win32 COM Buffer patikra (20ms laikmatis)
SetTimer(PollComPort, 20)

; ------------------------------------------------------------------------
;  Funkcijos: RGB ir GUI valdymas
; ------------------------------------------------------------------------

OnSliderChange() {
    r := sldR.Value
    g := sldG.Value
    b := sldB.Value

    txtRVal.Value := r
    txtGVal.Value := g
    txtBVal.Value := b

    ; Atnaujiname spalvos peržiūrą (HEX BGR formatas progress controlui)
    hexColor := Format("0x{:02X}{:02X}{:02X}", r, g, b)
    picPreview.Opt("+c" hexColor)
}

SetRGB(r, g, b) {
    sldR.Value := r
    sldG.Value := g
    sldB.Value := b
    OnSliderChange()

    cmd := Format("RGB:{},{},{}", r, g, b)
    SendCmd(cmd)
}

SendCustomCommand() {
    cmd := Trim(edtCustomCmd.Value)
    if (cmd != "") {
        SendCmd(cmd)
    }
}

LogMessage(msg, type := "INFO") {
    timeStr := FormatTime(, "HH:mm:ss")
    line := Format("[{}] [{}] {}\r\n", timeStr, type, msg)
    edtLog.Value := line . edtLog.Value
}

; ------------------------------------------------------------------------
;  Win32 API Serijinio Prievado Kommunikacija (Kernel32)
; ------------------------------------------------------------------------

GetAvailableComPorts() {
    ports := []
    Loop Reg, "HKLM\HARDWARE\DEVICEMAP\SERIALCOMM"
    {
        portName := RegRead()
        if (portName != "")
            ports.Push(portName)
    }
    if (ports.Length == 0) {
        ports.Push("COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8")
    }
    return ports
}

RefreshComList() {
    ports := GetAvailableComPorts()
    cbComPorts.Delete()
    cbComPorts.Add(ports)
    if (ports.Length > 0)
        cbComPorts.Text := ports[1]
    LogMessage("COM prievadų sąrašas atnaujintas.")
}

ToggleConnection() {
    if (g_IsConnected) {
        CloseComPort()
    } else {
        OpenComPort(cbComPorts.Text)
    }
}

OpenComPort(portName) {
    global g_hCom, g_IsConnected, g_ComPort

    g_ComPort := portName
    portPath := "\\.\" . portName

    ; GENERIC_READ = 0x80000000, GENERIC_WRITE = 0x40000000
    ; OPEN_EXISTING = 3
    g_hCom := DllCall("Kernel32.dll\CreateFileW",
        "Str", portPath,
        "UInt", 0x80000000 | 0x40000000,
        "UInt", 0,
        "Ptr", 0,
        "UInt", 3,
        "UInt", 0,
        "Ptr", 0,
        "Ptr")

    if (g_hCom == -1 || g_hCom == 0) {
        txtStatus.Value := "Būsena: Klaida atidarant " . portName . " 🔴"
        LogMessage("Nepavyko atidaryti prievado " . portName, "KLAIDA")
        g_IsConnected := false
        btnConnect.Text := "Prisijungti"
        return
    }

    ; Konfigūruojame DCB (Device Control Block)
    ; DCB dydis AHK 64-bit/32-bit aplinkoje ~28 bytes minimum (sukuriam Buffer 28 bytes)
    dcb := Buffer(28, 0)
    NumPut("UInt", 28, dcb, 0) ; DCBlength

    if !DllCall("Kernel32.dll\GetCommState", "Ptr", g_hCom, "Ptr", dcb) {
        LogMessage("Nepavyko gauti DCB būsenos", "KLAIDA")
        CloseComPort()
        return
    }

    ; BaudRate (offset 4) = 9600
    ; fBinary (bitfield offset 8) = 1
    ; ByteSize (offset 18) = 8
    ; Parity (offset 19) = 0 (NOPARITY)
    ; StopBits (offset 20) = 0 (ONESTOPBIT)
    NumPut("UInt", g_BaudRate, dcb, 4)
    NumPut("UChar", 8, dcb, 18)
    NumPut("UChar", 0, dcb, 19)
    NumPut("UChar", 0, dcb, 20)

    if !DllCall("Kernel32.dll\SetCommState", "Ptr", g_hCom, "Ptr", dcb) {
        LogMessage("Nepavyko nustatyti BaudRate ", "KLAIDA")
        CloseComPort()
        return
    }

    ; Nustatome Timeouts (COMMTIMEOUTS struct 20 bytes)
    ; ReadIntervalTimeout = MAXDWORD (0xFFFFFFFF)
    timeouts := Buffer(20, 0)
    NumPut("UInt", 0xFFFFFFFF, timeouts, 0) ; ReadIntervalTimeout
    NumPut("UInt", 0, timeouts, 4)          ; ReadTotalTimeoutMultiplier
    NumPut("UInt", 0, timeouts, 8)          ; ReadTotalTimeoutConstant
    NumPut("UInt", 0, timeouts, 12)         ; WriteTotalTimeoutMultiplier
    NumPut("UInt", 1000, timeouts, 16)      ; WriteTotalTimeoutConstant

    DllCall("Kernel32.dll\SetCommTimeouts", "Ptr", g_hCom, "Ptr", timeouts)

    g_IsConnected := true
    btnConnect.Text := "Atsijungti"
    txtStatus.Value := "Būsena: Prisijungta prie " . portName . " (9600 baud) 🟢"
    LogMessage("Sėkmingai prisijungta prie " . portName, "OK")
}

CloseComPort() {
    global g_hCom, g_IsConnected
    if (g_hCom != -1 && g_hCom != 0) {
        DllCall("Kernel32.dll\CloseHandle", "Ptr", g_hCom)
        g_hCom := -1
    }
    g_IsConnected := false
    btnConnect.Text := "Prisijungti"
    txtStatus.Value := "Būsena: Neprisijungta 🔴"
    LogMessage("Atsijungta nuo COM prievado.")
}

SendCmd(cmd) {
    global g_hCom, g_IsConnected

    if (!g_IsConnected || g_hCom == -1) {
        LogMessage("Klaida: Nėra ryšio su COM prievadu!", "KLAIDA")
        return false
    }

    fullCmd := cmd . "`r`n"
    buf := Buffer(StrPut(fullCmd, "UTF-8"))
    StrPut(fullCmd, buf, "UTF-8")
    bytesToWrite := buf.Size - 1

    written := 0
    res := DllCall("Kernel32.dll\WriteFile",
        "Ptr", g_hCom,
        "Ptr", buf,
        "UInt", bytesToWrite,
        "UInt*", &written,
        "Ptr", 0)

    if (res) {
        LogMessage("TX >> " . cmd, "SIŲSTA")
        return true
    } else {
        LogMessage("Siuntimo klaida!", "KLAIDA")
        return false
    }
}

PollComPort() {
    global g_hCom, g_IsConnected, g_RxBuffer

    if (!g_IsConnected || g_hCom == -1)
        return

    ; Nusaitome galimus gauti duomenis
    buf := Buffer(512, 0)
    bytesRead := 0

    res := DllCall("Kernel32.dll\ReadFile",
        "Ptr", g_hCom,
        "Ptr", buf,
        "UInt", 512,
        "UInt*", &bytesRead,
        "Ptr", 0)

    if (res && bytesRead > 0) {
        chunk := StrGet(buf, bytesRead, "UTF-8")
        g_RxBuffer .= chunk

        ; Tikriname ar gavome eilutės pabaigą (`\n`)
        while InStr(g_RxBuffer, "`n") {
            pos := InStr(g_RxBuffer, "`n")
            line := SubStr(g_RxBuffer, 1, pos - 1)
            g_RxBuffer := SubStr(g_RxBuffer, pos + 1)

            line := Trim(line, "`r`n ")
            if (line != "") {
                ProcessIncomingLine(line)
            }
        }
    }
}

ProcessIncomingLine(line) {
    LogMessage("RX << " . line, "GAUTA")

    if InStr(line, "CPU_TEMP:") {
        tempVal := StrReplace(line, "CPU_TEMP:")
        tempVal := Trim(tempVal)
        txtTemp.Value := "CPU Temperatūra: " . tempVal . " °C"

        ; Keičiame teksto spalvą priklausomai nuo temperatūros
        try {
            valNum := Float(tempVal)
            if (valNum > 60.0) {
                txtTemp.SetFont("cRed")
            } else if (valNum > 45.0) {
                txtTemp.SetFont("cOrange")
            } else {
                txtTemp.SetFont("cGreen")
            }
        }
    }
    else if (line == "PONG") {
        txtStatus.Value := "Būsena: PONG gautas! Ryšys aktyvus 🟢"
    }
    else if InStr(line, "RGB_OK") {
        txtStatus.Value := "Būsena: RGB spalva pakeista (" . line . ") 🟢"
    }
    else if InStr(line, "ESP32 READY") {
        txtStatus.Value := "Būsena: ESP32 Modulis paruoštas darbui 🟢"
    }
}

OnGuiClose() {
    CloseComPort()
    ExitApp()
}

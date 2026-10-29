#Requires AutoHotkey v2.0

/*
    ========================================================================
    LoRa DX-LR22 868MHz - Valdymo ir Stebėsenos Skydelis (Dashboard v3.0)
    ========================================================================
    - Tiesioginė Win32 serijinio prievado (COM Port) komunikacija per kernel32.dll
    - Automatinis COM prievadų aptikimas iš Windows registro
    - ESP32-C3 CPU temperatūros, Uptime, Heap atminties gavimas realiuoju laiku
    - LoRa Signalo Stiprumo indikuojamas dBm ir Procentais (0-100%) su Progress juosta
    - Tikėtino Atstumo Apskaičiavimas M / KM pagal Log-Distance Path Loss modelį
    - Interaktyvus RGB LED valdymas + Efektai (Varivara, Mirksėjimas, Strobas)
    - Išplėstinis komandų rinkinys (SYS_INFO, RESET, EFFECT, PING)
    - Įvykių žurnalas (Log Console) slenkantis ŽEMYN su auto-scroll
*/

; 全局 Global Variables
global g_ComPort := "COM6"
global g_BaudRate := 9600
global g_hCom := -1
global g_IsConnected := false
global g_RxBuffer := ""
global g_PingStartTime := 0
global g_LastPingSeq := 0
global g_CurrentRssi := -70

; Langelio sukūrimas (GUI Setup)
mainGui := Gui("+Resize +MinSize540x840", "LoRa DX-LR22 (868MHz) - Valdymo Skydelis v3")
mainGui.SetFont("s10", "Segoe UI")
mainGui.OnEvent("Close", (*) => OnGuiClose())

; --- COM Prievado Pasirinkimas ---
mainGui.AddGroupBox("w500 h70 x15 y10", "Serijinis Prievadas (COM Port)")
mainGui.AddText("x30 y35", "Prievadas:")
cbComPorts := mainGui.AddComboBox("x100 y31 w130", GetAvailableComPorts())
cbComPorts.Text := g_ComPort
btnConnect := mainGui.AddButton("x245 y30 w110 h28", "Prisijungti")
btnConnect.OnEvent("Click", (*) => ToggleConnection())
btnRefresh := mainGui.AddButton("x365 y30 w135 h28", "Atnaujinti Sąrašą")
btnRefresh.OnEvent("Click", (*) => RefreshComList())

; --- Telemetrija ir Būsenos ---
mainGui.AddGroupBox("w500 h120 x15 y90", "ESP32 Telemetrija & Būsena")
txtStatus := mainGui.AddText("x30 y112 w460", "Būsena: Neprisijungta 🔴")
txtTemp := mainGui.AddText("x30 y138 w230", "CPU Temp: --- °C")
txtTemp.SetFont("s11 bold", "Segoe UI")
txtUptime := mainGui.AddText("x270 y138 w230", "Uptime: ---")
txtHeap := mainGui.AddText("x30 y172 w230", "Laisva RAM: --- KB")
txtLatency := mainGui.AddText("x270 y172 w230", "Ryšio Vėlavimas: --- ms")

; --- LoRa Signalo Stiprumas (RSSI) ir Atstumas ---
mainGui.AddGroupBox("w500 h130 x15 y220", "LoRa Ryšio Kokybė & Atstumo Įvertinimas")
txtRssiDbm := mainGui.AddText("x30 y245 w230", "Signalo Stiprumas: -70 dBm")
txtRssiPct := mainGui.AddText("x270 y245 w230", "Kokybė: 56 %")
txtRssiPct.SetFont("s10 bold", "Segoe UI")

barRssi := mainGui.AddProgress("x30 y275 w470 h18 Range0-100 BackgroundE0E0E0 cGreen", 56)
txtDistance := mainGui.AddText("x30 y302 w470", "Apskaičiuotas Atstumas: ~42 m (Log-Path Loss n=2.7)")
txtDistance.SetFont("s10 bold cNavy", "Segoe UI")

; --- RGB Valdymas & Efektai ---
mainGui.AddGroupBox("w500 h220 x15 y360", "RGB Neopixel Valdymas & Efektai (Pin 8)")

; Greiti mygtukai
mainGui.AddButton("x30 y385 w85 h30", "Raudona").OnEvent("Click", (*) => SetRGB(255, 0, 0))
mainGui.AddButton("x125 y385 w85 h30", "Žalia").OnEvent("Click", (*) => SetRGB(0, 255, 0))
mainGui.AddButton("x220 y385 w85 h30", "Mėlyna").OnEvent("Click", (*) => SetRGB(0, 0, 255))
mainGui.AddButton("x315 y385 w85 h30", "Geltona").OnEvent("Click", (*) => SetRGB(255, 255, 0))
mainGui.AddButton("x410 y385 w85 h30", "Išjungti").OnEvent("Click", (*) => SetRGB(0, 0, 0))

; RGB Šliaužikliai (Sliders)
mainGui.AddText("x30 y430 w20", "R:")
sldR := mainGui.AddSlider("x50 y425 w210 Range0-255", 0)
txtRVal := mainGui.AddText("x265 y430 w30", "0")

mainGui.AddText("x30 y460 w20", "G:")
sldG := mainGui.AddSlider("x50 y455 w210 Range0-255", 0)
txtGVal := mainGui.AddText("x265 y460 w30", "0")

mainGui.AddText("x30 y490 w20", "B:")
sldB := mainGui.AddSlider("x50 y485 w210 Range0-255", 0)
txtBVal := mainGui.AddText("x265 y490 w30", "0")

sldR.OnEvent("Change", (*) => OnSliderChange())
sldG.OnEvent("Change", (*) => OnSliderChange())
sldB.OnEvent("Change", (*) => OnSliderChange())

btnSendRGB := mainGui.AddButton("x310 y430 w185 h30", "Siųsti RGB Spalvą")
btnSendRGB.OnEvent("Click", (*) => SetRGB(sldR.Value, sldG.Value, sldB.Value))

; Spalvos peržiūros blokas (Color Preview Box)
picPreview := mainGui.AddProgress("x310 y465 w185 h15 Background000000", 0)

; LED Efektai
mainGui.AddText("x30 y525 w60", "Efektai:")
mainGui.AddButton("x95 y520 w115 h30", "🌈 Varivara").OnEvent("Click", (*) => SendCmd("EFFECT:RAINBOW"))
mainGui.AddButton("x220 y520 w115 h30", "💡 Mirksėjimas").OnEvent("Click", (*) => SendCmd("EFFECT:BLINK"))
mainGui.AddButton("x345 y520 w150 h30", "⚡ Stroboskopas").OnEvent("Click", (*) => SendCmd("EFFECT:STROBE"))

; --- Komandų Valdymas Ir Įrankiai ---
mainGui.AddGroupBox("w500 h90 x15 y590", "Komandų Valdymas Ir Įrankiai")
edtCustomCmd := mainGui.AddEdit("x30 y615 w210", "SYS_INFO")
btnSendCustom := mainGui.AddButton("x250 y614 w80 h28", "Siųsti")
btnSendCustom.OnEvent("Click", (*) => SendCustomCommand())

btnSysInfo := mainGui.AddButton("x340 y614 w75 h28", "Info")
btnSysInfo.OnEvent("Click", (*) => SendCmd("SYS_INFO"))

btnPing := mainGui.AddButton("x425 y614 w75 h28", "PING")
btnPing.OnEvent("Click", (*) => MeasurePing())

btnReset := mainGui.AddButton("x30 y648 w125 h26", "🔄 Perkrauti ESP32")
btnReset.OnEvent("Click", (*) => ConfirmReset())

btnGetTemp := mainGui.AddButton("x165 y648 w135 h26", "🌡️ Gauti Temp")
btnGetTemp.OnEvent("Click", (*) => SendCmd("GET_TEMP"))

; --- Komunikacijos Žurnalas (Log Console - Slenka Žemyn) ---
mainGui.AddGroupBox("w500 h190 x15 y690", "Įvykių Žurnalas (Eina Žemyn ⬇️)")
edtLog := mainGui.AddEdit("x30 y715 w470 h125 ReadOnly Multi +0x100000") ; WS_VSCROLL
btnClearLog := mainGui.AddButton("x385 y848 w115 h25", "Valyti Žurnalą")
btnClearLog.OnEvent("Click", (*) => (edtLog.Value := ""))

mainGui.Show("w530 h885")

; Periodinė Win32 COM Buffer patikra (20ms laikmatis)
SetTimer(PollComPort, 20)

; Nuolatinis pratinis RSSI atnaujinimas
UpdateRssiDisplay(g_CurrentRssi)

; ------------------------------------------------------------------------
;  Funkcijos: RSSI, Atstumo Apskaičiavimas ir GUI
; ------------------------------------------------------------------------

UpdateRssiDisplay(rssiDbm) {
    global g_CurrentRssi
    g_CurrentRssi := rssiDbm

    txtRssiDbm.Value := "Signalo Stiprumas: " . rssiDbm . " dBm"

    ; Signal Quality Percentage Calculation
    ; Map -120 dBm (0%) to -30 dBm (100%)
    pct := Floor(((rssiDbm - (-120)) / ((-30) - (-120))) * 100)
    if (pct < 0)
        pct := 0
    if (pct > 100)
        pct := 100

    txtRssiPct.Value := "Kokybė: " . pct . " %"
    barRssi.Value := pct

    ; Dynamically set bar color based on RSSI strength
    if (pct > 65) {
        barRssi.Opt("cGreen")
    } else if (pct > 35) {
        barRssi.Opt("cFF8C00") ; Orange in Hex RGB format
    } else {
        barRssi.Opt("cRed")
    }

    ; Distance Calculation using Log-Distance Path Loss Model:
    ; d = 10 ^ ((TxPower_at_1m - RSSI) / (10 * n))
    ; Standard outdoor parameters: TxPower_1m = -40 dBm, path loss exponent n = 2.7
    txPower1m := -40.0
    pathLossN := 2.7

    try {
        exponent := (txPower1m - Float(rssiDbm)) / (10.0 * pathLossN)
        distMeters := 10.0 ** exponent

        if (distMeters >= 1000.0) {
            distKm := Round(distMeters / 1000.0, 2)
            txtDistance.Value := "Apskaičiuotas Atstumas: ~" . distKm . " km (Log-Path Loss n=2.7)"
        } else if (distMeters >= 1.0) {
            distM := Round(distMeters, 1)
            txtDistance.Value := "Apskaičiuotas Atstumas: ~" . distM . " m (Log-Path Loss n=2.7)"
        } else {
            txtDistance.Value := "Apskaičiuotas Atstumas: < 1 m (Arti vienas kito)"
        }
    } catch {
        txtDistance.Value := "Apskaičiuotas Atstumas: N/A"
    }
}

OnSliderChange() {
    r := sldR.Value
    g := sldG.Value
    b := sldB.Value

    txtRVal.Value := r
    txtGVal.Value := g
    txtBVal.Value := b

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

MeasurePing() {
    global g_PingStartTime, g_LastPingSeq
    g_LastPingSeq := Random(100, 999)
    g_PingStartTime := A_TickCount
    SendCmd("PING:" . g_LastPingSeq)
}

ConfirmReset() {
    res := MsgBox("Ar tikrai norite perkrauti ESP32-C3 mikrokontrolerį?", "Perkrovimo patvirtinimas", "YesNo IconExclamation")
    if (res == "Yes") {
        SendCmd("RESET")
    }
}

; Slenkantis žemyn žurnalo įrašymas
LogMessage(msg, type := "INFO") {
    timeStr := FormatTime(, "HH:mm:ss")
    line := Format("[{}] [{}] {}\r\n", timeStr, type, msg)

    edtLog.Value .= line

    DllCall("User32.dll\SendMessage", "Ptr", edtLog.Hwnd, "UInt", 0x00B1, "Ptr", -1, "Ptr", -1)
    DllCall("User32.dll\SendMessage", "Ptr", edtLog.Hwnd, "UInt", 0x00B7, "Ptr", 0, "Ptr", 0)
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

    dcb := Buffer(28, 0)
    NumPut("UInt", 28, dcb, 0)

    if !DllCall("Kernel32.dll\GetCommState", "Ptr", g_hCom, "Ptr", dcb) {
        LogMessage("Nepavyko gauti DCB būsenos", "KLAIDA")
        CloseComPort()
        return
    }

    NumPut("UInt", g_BaudRate, dcb, 4)
    NumPut("UChar", 8, dcb, 18)
    NumPut("UChar", 0, dcb, 19)
    NumPut("UChar", 0, dcb, 20)

    if !DllCall("Kernel32.dll\SetCommState", "Ptr", g_hCom, "Ptr", dcb) {
        LogMessage("Nepavyko nustatyti BaudRate ", "KLAIDA")
        CloseComPort()
        return
    }

    timeouts := Buffer(20, 0)
    NumPut("UInt", 0xFFFFFFFF, timeouts, 0)
    NumPut("UInt", 0, timeouts, 4)
    NumPut("UInt", 0, timeouts, 8)
    NumPut("UInt", 0, timeouts, 12)
    NumPut("UInt", 1000, timeouts, 16)

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
    global g_PingStartTime

    LogMessage("RX << " . line, "GAUTA")

    ; Parse attached RSSI parameter if present in line (e.g. ...,RSSI=-72)
    if InStr(line, "RSSI=") {
        try {
            rssiPos := InStr(line, "RSSI=")
            rssiValStr := SubStr(line, rssiPos + 5)
            rssiValStr := StrSplit(rssiValStr, ",")[1]
            rssiValStr := StrSplit(rssiValStr, " ")[1]
            rssiNum := Integer(rssiValStr)
            UpdateRssiDisplay(rssiNum)
        }
    }

    if InStr(line, "CPU_TEMP:") {
        tempVal := StrReplace(line, "CPU_TEMP:")
        tempVal := StrSplit(tempVal, ",")[1]
        tempVal := Trim(tempVal)
        txtTemp.Value := "CPU Temp: " . tempVal . " °C"

        try {
            valNum := Float(tempVal)
            if (valNum > 60.0) {
                txtTemp.SetFont("cRed")
            } else if (valNum > 45.0) {
                txtTemp.SetFont("cFF8C00")
            } else {
                txtTemp.SetFont("cGreen")
            }
        }
    }
    else if InStr(line, "SYS_INFO:") {
        infoStr := StrReplace(line, "SYS_INFO:")
        parts := StrSplit(infoStr, ",")
        for idx, part in parts {
            kv := StrSplit(part, "=")
            if (kv.Length == 2) {
                k := Trim(kv[1])
                v := Trim(kv[2])
                if (k == "TEMP") {
                    txtTemp.Value := "CPU Temp: " . v . " °C"
                } else if (k == "UPTIME") {
                    sec := Integer(v)
                    min := Floor(sec / 60)
                    hrs := Floor(min / 60)
                    txtUptime.Value := Format("Uptime: {}h {}m {}s", hrs, Mod(min, 60), Mod(sec, 60))
                } else if (k == "HEAP") {
                    kb := Round(Integer(v) / 1024, 1)
                    txtHeap.Value := "Laisva RAM: " . kb . " KB"
                } else if (k == "RSSI") {
                    UpdateRssiDisplay(Integer(v))
                }
            }
        }
    }
    else if InStr(line, "PONG") {
        if (g_PingStartTime > 0) {
            elapsed := A_TickCount - g_PingStartTime
            txtLatency.Value := "Ryšio Vėlavimas: " . elapsed . " ms"
            g_PingStartTime := 0
        }
        txtStatus.Value := "Būsena: PONG gautas! Ryšys aktyvus 🟢"
    }
    else if InStr(line, "EFFECT_OK") {
        txtStatus.Value := "Būsena: LED Efektas aktyvuotas (" . line . ") 🟢"
    }
    else if InStr(line, "RGB_OK") {
        txtStatus.Value := "Būsena: RGB spalva pakeista (" . line . ") 🟢"
    }
    else if InStr(line, "SYS_RESETTING") {
        txtStatus.Value := "Būsena: ESP32 perkraunamas... 🔄"
    }
    else if InStr(line, "ESP32 READY") {
        txtStatus.Value := "Būsena: ESP32 Modulis paruoštas darbui 🟢"
    }
}

OnGuiClose() {
    CloseComPort()
    ExitApp()
}

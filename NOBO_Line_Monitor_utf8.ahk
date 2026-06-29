#Requires AutoHotkey v2.0
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

; =======================================================
; GLOBALAI (Super-global)
; =======================================================
Global OverlayGui, CtrlGui, SettingsGui
Global CURRENT_VERSION := "2.6"
Global RemoteVersion := "laukiama..."
Global LastHttpStatus := "0"
Global LastRawResponse := "nieko"
Global LastCallUrl := "dar nebuvo užklausos"

; GitHub Gist "Raw" nuorodos:
Global UPDATE_CHECK_URL := "https://gist.githubusercontent.com/memoryex/f364f28f1288c9229faac5d385738613/raw/version.txt"
Global SCRIPT_DOWNLOAD_URL := "https://gist.githubusercontent.com/memoryex/f364f28f1288c9229faac5d385738613/raw/auto_skait" . (A_IsCompiled ? ".exe" : ".ahk")

Global CountText := 0
Global ResetBtn := 0
Global CancelBtn := 0
Global DecBtn := 0
Global InfoBtn := 0
Global GearBtn := 0
Global UpdateBtn := 0

Global NewFilesCount := 0
Global LastFileCount := -1
Global g_ih := 0
Global LogFile := ""
Global CountdownPending := false
Global CountdownDeadline := 0
Global CountdownAction := ""

; Settings globals
Global COM_PORT := "COM3"
Global COM_BAUD := 9600
Global Stebimas_Katalogas := A_Desktop
Global Selected_Line := "XLE 1"

; ThingSpeak Globals
Global TS_CHANNEL_ID := "807602"
Global TS_READ_KEY := "WUO1DG7GXYNZP6SG"
Global TS_API_KEY := "O7IB88R7L2ELXR3Q"
Global TS_FIELD_COUNT := "field5"
Global TS_FIELD_BARCODE := "field6"

Global TS_MIN_INTERVAL := 15000
Global TS_FLUSH_INTERVAL := 1000

Global IniFile := A_ScriptDir "\settings.ini"

; Line Data Map
Global LineMap := Map(
    "PLXE 1", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field1", Barcode: "field2"},
    "PLXE 2", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field3", Barcode: "field4"},
    "PLXE 3", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field5", Barcode: "field6"},
    "PLXE 4", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field7", Barcode: "field8"},
    "NOBO 1", {ID: "703669", Read: "S44OBKWC5C7FODZ5", Write: "XPIME2EC8RKX9JO3", Count: "field1", Barcode: "field2"},
    "NOBO 2", {ID: "703669", Read: "S44OBKWC5C7FODZ5", Write: "XPIME2EC8RKX9JO3", Count: "field3", Barcode: "field4"},
    "NOBO 3", {ID: "703669", Read: "S44OBKWC5C7FODZ5", Write: "XPIME2EC8RKX9JO3", Count: "field5", Barcode: "field6"},
    "NOBO 4", {ID: "703669", Read: "S44OBKWC5C7FODZ5", Write: "XPIME2EC8RKX9JO3", Count: "field7", Barcode: "field8"},
    "NOBO 5", {ID: "802414", Read: "I6NIZAVZYLPVV1ME", Write: "DNPJZCU9G6NJD0VF", Count: "field1", Barcode: "field2"},
    "NOBO 6", {ID: "802414", Read: "I6NIZAVZYLPVV1ME", Write: "DNPJZCU9G6NJD0VF", Count: "field3", Barcode: "field4"},
    "NOBO 7", {ID: "802414", Read: "I6NIZAVZYLPVV1ME", Write: "DNPJZCU9G6NJD0VF", Count: "field5", Barcode: "field6"},
    "PLXE 5", {ID: "802414", Read: "I6NIZAVZYLPVV1ME", Write: "DNPJZCU9G6NJD0VF", Count: "field7", Barcode: "field8"},
    "UI perrašymas", {ID: "807602", Read: "WUO1DG7GXYNZP6SG", Write: "O7IB88R7L2ELXR3Q", Count: "field1", Barcode: "field2"},
    "QRAD 1", {ID: "807602", Read: "WUO1DG7GXYNZP6SG", Write: "O7IB88R7L2ELXR3Q", Count: "field3", Barcode: "field4"},
    "XLE 1",  {ID: "807602", Read: "WUO1DG7GXYNZP6SG", Write: "O7IB88R7L2ELXR3Q", Count: "field5", Barcode: "field6"},
    "XLE ReWork", {ID: "807602", Read: "WUO1DG7GXYNZP6SG", Write: "O7IB88R7L2ELXR3Q", Count: "field7", Barcode: "field8"}
)

LoadSettings() {
    global
    COM_PORT := IniRead(IniFile, "Settings", "ComPort", "COM3")
    Stebimas_Katalogas := IniRead(IniFile, "Settings", "Folder", A_Desktop)
    Selected_Line := IniRead(IniFile, "Settings", "Line", "XLE 1")
    NewFilesCount := IniRead(IniFile, "State", Selected_Line "_Count", 0)
    global Start_X := IniRead(IniFile, "Settings", "PosX", 420)
    global Start_Y := IniRead(IniFile, "Settings", "PosY", 800)

    if LineMap.Has(Selected_Line) {
        data := LineMap[Selected_Line]
        TS_CHANNEL_ID := data.ID
        TS_READ_KEY := data.Read
        TS_API_KEY := data.Write
        TS_FIELD_COUNT := data.Count
        TS_FIELD_BARCODE := data.Barcode
    }
}
LoadSettings()

; =======================================================
; GUI SETUP
; =======================================================
Lango_Dydis := 200
; Start_X ir Start_Y užkraunami iš LoadSettings()

OverlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption +LastFound +E0x20")
OverlayGui.BackColor := "Blue"
OverlayGui.SetFont("s65 bold cWhite", "Arial")
CountText := OverlayGui.Add("Text", "x0 y50 w" Lango_Dydis " h120 Center", NewFilesCount)

OverlayGui.SetFont("s10 italic cD4AF37", "Arial")
OverlayGui.Add("Text", "x5 y175 w190 h20 BackgroundTrans", "v" CURRENT_VERSION " | " Selected_Line)

OverlayGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)
WinSetTransparent(200, OverlayGui)

CtrlGui := Gui("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner" OverlayGui.Hwnd)
CtrlGui.BackColor := "010101"
WinSetTransColor("010101", CtrlGui)

ResetBtn := CtrlGui.Add("Text", "x5 y5 w190 h50 Center +0x100 +0x200 BackgroundFF0000 cWhite", "RESET")
ResetBtn.SetFont("s14 bold", "Verdana")

DecBtn := CtrlGui.Add("Text", "x140 y70 w50 h55 Center +0x100 +0x200 Background333333 cWhite Hidden", "-")
DecBtn.SetFont("s26 bold")

InfoBtn := CtrlGui.Add("Text", "x130 y165 w30 h30 Center +0x100 +0x200 Background0000FF cWhite", "i")
InfoBtn.SetFont("s15 bold italic", "Times New Roman")

GearBtn := CtrlGui.Add("Text", "x165 y165 w30 h30 Center +0x100 +0x200 Background0000FF cWhite", "⚙")
GearBtn.SetFont("s15", "Segoe UI Symbol")

CancelBtn := CtrlGui.Add("Text", "x5 y5 w190 h80 Center +0x100 +0x200 BackgroundFF8800 cWhite Hidden", "")
CancelBtn.SetFont("s8 bold", "Verdana")

UpdateBtn := CtrlGui.Add("Text", "x5 y55 w190 h35 Center +0x100 +0x200 BackgroundE67E22 cWhite Hidden", "YRA NAUJA VERSIJA")
UpdateBtn.SetFont("s9 bold")

CtrlGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)

; Įvykių apdorojimas per pranešimus (v2 skaidriems langams patikimiau)
OnMessage(0x0201, WM_LBUTTONDOWN)

SetTimer EnsureTopMost, 500
SetTimer TikrintiKataloga, 1000
SetTimer CheckExternalUpdate, 10000

; PATIKRINTI IŠKART IR TADA KAS MINUTĘ
SetTimer CheckForUpdates, -1000
SetTimer CheckForUpdates, 60000

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global ResetBtn, DecBtn, GearBtn, UpdateBtn, CancelBtn, CountdownPending

    ctrl := GuiCtrlFromHwnd(hwnd)
    if (!ctrl)
        return

    ; Jei rodomas atšaukimo mygtukas, tikriname tik jį
    if (CancelBtn.Visible && ctrl.Hwnd == CancelBtn.Hwnd) {
        CancelCountdown()
        return
    }

    if (CountdownPending)
        return

    if (ctrl.Hwnd == ResetBtn.Hwnd)
        StartCountdown("RESET")
    else if (DecBtn.Visible && ctrl.Hwnd == DecBtn.Hwnd)
        StartCountdown("DEC")
    else if (ctrl.Hwnd == InfoBtn.Hwnd)
        ShowInfo()
    else if (ctrl.Hwnd == GearBtn.Hwnd)
        ShowSettings()
    else if (UpdateBtn.Visible && ctrl.Hwnd == UpdateBtn.Hwnd)
        StartUpdate()
}

EnsureTopMost() {
    global OverlayGui, CtrlGui
    if WinActive("ahk_id " OverlayGui.Hwnd) || WinActive("ahk_id " CtrlGui.Hwnd)
        return
    OverlayGui.Opt("+AlwaysOnTop")
    CtrlGui.Opt("+AlwaysOnTop")
}

; =======================================================
; UPDATE LOGIC (Optimizuota GitHub / Raw tekstui)
; =======================================================
CheckForUpdates() {
    global RemoteVersion, LastHttpStatus, LastRawResponse, LastCallUrl, UpdateBtn, CURRENT_VERSION, UPDATE_CHECK_URL

    LastCallUrl := UPDATE_CHECK_URL
    TempFile := A_Temp "\version_check.txt"
    if FileExist(TempFile)
        FileDelete(TempFile)

    try {
        Download(UPDATE_CHECK_URL, TempFile)

        if FileExist(TempFile) {
            Content := FileRead(TempFile, "UTF-8")
            LastHttpStatus := "OK (Download)"
            LastRawResponse := SubStr(Content, 1, 200)
            RemoteVersion := Trim(RegExReplace(Content, "[^\d\.]"))

            if (RemoteVersion != "" && VerCompare(RemoteVersion, CURRENT_VERSION) > 0) {
                UpdateBtn.Visible := true
            } else {
                UpdateBtn.Visible := false
            }
        }
    } catch Error as e {
        LastHttpStatus := "KLAIDA (Exception)"
        LastRawResponse := e.Message
    }
}

StartUpdate(*) {
    global SCRIPT_DOWNLOAD_URL, UpdateBtn
    if (MsgBox("Ar norite atnaujinti programą į naują versiją?", "Atnaujinimas", 4) == "No")
        return
    try {
        UpdateBtn.Value := "SIUNČIAMA..."
        TempScript := A_Temp "\update_nobo_new" . (A_IsCompiled ? ".exe" : ".ahk")
        if FileExist(TempScript)
            FileDelete(TempScript)

        Download(SCRIPT_DOWNLOAD_URL, TempScript)

        if FileExist(TempScript) {
            ; Naudojame bat failą kad pakeistume veikiantį EXE/AHK
            BatFile := A_Temp "\update_nobo.bat"
            if FileExist(BatFile)
                FileDelete(BatFile)

            ; Sukuriame komandų failą kuris palauks kol išsijungsime, pakeis failą ir paleis iš naujo
            BatchContent := '
            (
            @echo off
            timeout /t 2 /nobreak > nul
            move /y "{1}" "{2}"
            start "" "{2}"
            del "%~f0"
            )'
            BatchContent := Format(BatchContent, TempScript, A_ScriptFullPath)

            FileAppend(BatchContent, BatFile, "CP0")
            Run(BatFile, , "Hide")
            ExitApp()
        }
    } catch Error as e {
        MsgBox "Klaida atnaujinant: " . e.Message, "Klaida", "Iconx"
        UpdateBtn.Value := "YRA NAUJA VERSIJA"
    }
}

SaveState() {
    global Selected_Line, NewFilesCount, IniFile
    IniWrite(NewFilesCount, IniFile, "State", Selected_Line "_Count")
}

DoDecrement() {
    global NewFilesCount, CountText
    if (NewFilesCount > 0) {
        NewFilesCount -= 1
        UpdateCountDisplay()
        TSQueueCount(NewFilesCount)
        SaveState()
        SoundBeep 400, 100
    }
}

; =======================================================
; SETTINGS GUI
; =======================================================
ShowSettings(*) {
    global SettingsGui, COM_PORT, Stebimas_Katalogas, Selected_Line

    ; Slaptažodžio užklausa
    PwdGui := Gui("+AlwaysOnTop", "Saugumas")
    PwdGui.Add("Text", , "Įveskite nustatymų slaptažodį:")
    pwdEdit := PwdGui.Add("Edit", "w200 Password")
    pwdBtn := PwdGui.Add("Button", "w200 Default", "Patvirtinti")

    pwdBtn.OnEvent("Click", (*) => CheckPassword())

    CheckPassword() {
        if (pwdEdit.Value == "4321") {
            PwdGui.Destroy()
            OpenSettings()
        } else {
            MsgBox "Neteisingas slaptažodis!", "Klaida", "Iconx"
            pwdEdit.Value := ""
        }
    }

    PwdGui.Show()
}

ShowInfo(*) {
    global Stebimas_Katalogas
    total := 0
    oldest := ""
    Loop Files, Stebimas_Katalogas "\*.*" {
        total++
        try {
            ctime := FileGetTime(A_LoopFileFullPath, "C")
            if (oldest == "" || ctime < oldest)
                oldest := ctime
        }
    }
    dateStr := (oldest == "") ? "nėra failų" : FormatTime(oldest, "yyyy-MM-dd HH:MM:ss")
    MsgBox("Viso gaminiu pagaminta: " total "`nLinija paleista nuo: " dateStr, "Informacija", "Iconi")
}

OpenSettings() {
    global SettingsGui, COM_PORT, Stebimas_Katalogas, Selected_Line, Start_X, Start_Y
    SettingsGui := Gui("+AlwaysOnTop", "Nustatymai")
    SettingsGui.Add("Text", , "COM Prievadas:")
    comPorts := GetAvailableComPorts()
    comChoice := SettingsGui.Add("DropDownList", "w300", comPorts)
    selectedIdx := 1
    Loop comPorts.Length {
        if InStr(comPorts[A_Index], "(" COM_PORT ")") {
            selectedIdx := A_Index
            break
        }
    }
    if comPorts.Length > 0 {
        try comChoice.Choose(selectedIdx)
    }
    SettingsGui.Add("Text", , "Stebimas katalogas:")
    folderEdit := SettingsGui.Add("Edit", "w300 vFolder", Stebimas_Katalogas)
    SettingsGui.Add("Button", "x+5 w30", "...").OnEvent("Click", (*) => (f := SelectFolder(), f ? folderEdit.Value := f : 0))
    SettingsGui.Add("Text", , "Gamybos linija:")
    lineNames := []
    for name, data in LineMap
        lineNames.Push(name)
    lineChoice := SettingsGui.Add("DropDownList", "w200", lineNames)
    Loop lineNames.Length {
        if lineNames[A_Index] = Selected_Line {
            lineChoice.Choose(A_Index)
            break
        }
    }

    SettingsGui.Add("Text", "xm", "Lango kordinatės (X ir Y):")
    editX := SettingsGui.Add("Edit", "w60", Start_X)
    editY := SettingsGui.Add("Edit", "x+5 w60", Start_Y)

    saveBtn := SettingsGui.Add("Button", "xm w120 Default", "Save and Restart")
    saveBtn.OnEvent("Click", ProcessSave)
    ProcessSave(*) {
        RegExMatch(comChoice.Text, "COM\d+", &match)
        portName := match ? match[0] : "COM3"
        SaveAndRestart(portName, folderEdit.Value, lineChoice.Text, editX.Value, editY.Value)
    }
    SettingsGui.Show()
}
SelectFolder() {
    return DirSelect(Stebimas_Katalogas, 3, "Pasirinkite stebimą katalogą")
}
SaveAndRestart(c, f, l, x, y) {
    IniWrite(c, IniFile, "Settings", "ComPort")
    IniWrite(f, IniFile, "Settings", "Folder")
    IniWrite(l, IniFile, "Settings", "Line")
    IniWrite(x, IniFile, "Settings", "PosX")
    IniWrite(y, IniFile, "Settings", "PosY")
    Reload()
}

; =======================================================
; FAILŲ TIKRINIMAS IR PAGALBINĖS
; =======================================================
FormatTS() {
    return FormatTime(, "yyyy-MM-dd HH:mm:ss")
}
LogAppend(line) {
    global LogFile
    if (LogFile == "")
        return
    try FileAppend(line "`r`n", LogFile, "UTF-8")
}
LogBarcode(code) {
    LogAppend(FormatTS() " nuskanuotas barkodas ~" code "~")
}
LogCount(count) {
    LogAppend(FormatTS() " " count " gaminys")
}
TikrintiKataloga() {
    global NewFilesCount, LastFileCount, CountText, Stebimas_Katalogas
    CurrentCount := 0
    Loop Files, Stebimas_Katalogas "\*.*"
        CurrentCount++
    if (LastFileCount == -1) {
        LastFileCount := CurrentCount
        return
    }
    if (CurrentCount > LastFileCount) {
        Diff := CurrentCount - LastFileCount
        NewFilesCount += Diff
        Loop Diff {
            RelayPulse()
        }
        UpdateCountDisplay()
        LogCount(NewFilesCount)
        TSQueueCount(NewFilesCount)
        SaveState()
    }
    LastFileCount := CurrentCount
}
UpdateCountDisplay() {
    global NewFilesCount, CountText
    CountText.Value := NewFilesCount
    CountText.SetFont("cLime")
    SetTimer ResetCountColor, -350
}
ResetCountColor() {
    global CountText
    CountText.SetFont("cWhite")
}
Nunulinti() {
    global NewFilesCount, CountText
    NewFilesCount := 0
    CountText.Value := "0"
    TSQueueCount(0)
    SaveState()
    SoundBeep 700, 150
}
CheckExternalUpdate() {
    global TS_CHANNEL_ID, TS_READ_KEY, TS_FIELD_COUNT, NewFilesCount, TS_PENDING, TS_LAST_SEND_TS

    ; Svarbu: po to, kai patys išsiuntėme duomenis, palaukiame 30 sek. prieš priimdami išorinius pokyčius.
    ; Tai apsaugo nuo "atšokimo", kai ThingSpeak dar nespėjo atnaujinti savo API atsakymo.
    if (A_TickCount - TS_LAST_SEND_TS < 30000)
        return

    ; Jei turime neišsiųstų vietinių atnaujinimų, laukiame
    if (TS_PENDING.Has(TS_FIELD_COUNT))
        return

    url := "https://api.thingspeak.com/channels/" . TS_CHANNEL_ID . "/fields/" . SubStr(TS_FIELD_COUNT, 6) . "/last.json?api_key=" . TS_READ_KEY
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, false)
        req.Send()
        if (req.Status = 200) {
            if (RegExMatch(req.ResponseText, '"' . TS_FIELD_COUNT . '":"(\d+)"', &match)) {
                val := Integer(match[1])
                if (val != NewFilesCount) {
                    LogAppend(FormatTS() " aptiktas išorinis kiekio pasikeitimas (" NewFilesCount " -> " val ")")
                    NewFilesCount := val
                    UpdateCountDisplay()
                    SaveState()
                }
            }
        }
    }
}
StartCountdown(action) {
    global ResetBtn, CancelBtn, DecBtn, CountdownPending, CountdownDeadline, CountdownAction, NewFilesCount
    if (CountdownPending)
        return

    if (action == "DEC" && NewFilesCount <= 0) {
        SoundBeep 300, 100
        return
    }

    CountdownAction := action
    CountdownPending := true
    CountdownDeadline := A_TickCount + 5000

    CancelBtn.Visible := true
    ResetBtn.Visible := false
    DecBtn.Visible := false

    UpdateCountdown() ; Atnaujinti tekstą iškart
    SetTimer UpdateCountdown, 50
    SoundBeep 600, 150
}
UpdateCountdown() {
    global ResetBtn, CancelBtn, DecBtn, CountdownPending, CountdownDeadline, CountdownAction
    if (!CountdownPending) {
        SetTimer UpdateCountdown, 0
        return
    }
    RemainingMs := CountdownDeadline - A_TickCount
    if (RemainingMs <= 0) {
        SetTimer UpdateCountdown, 0
        CancelBtn.Visible := false
        DecBtn.Visible := false
        ResetBtn.Visible := true
        CountdownPending := false

        if (CountdownAction == "RESET")
            Nunulinti()
        else if (CountdownAction == "DEC")
            DoDecrement()

        return
    }
    actionText := (CountdownAction == "RESET") ? " RESET" : "GAMINĮ -1"
    CancelBtn.Value := "ATŠAUKTI`n" actionText "`n(" Format("{:0.1f}s", RemainingMs/1000) ")"
}
CancelCountdown(*) {
    global ResetBtn, CancelBtn, DecBtn, CountdownPending
    CountdownPending := false
    SetTimer UpdateCountdown, 0
    CancelBtn.Visible := false
    DecBtn.Visible := false
    ResetBtn.Visible := true
    SoundBeep 500, 120
}
RelayPulse() {
    global COM_PORT, COM_BAUD
    hPort := DllCall("CreateFile", "Str", "\\.\" COM_PORT, "UInt", 0x40000000, "UInt", 0, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
    if (hPort == -1)
        return
    DCB := Buffer(28, 0)
    if DllCall("GetCommState", "Ptr", hPort, "Ptr", DCB) {
        NumPut("UInt", COM_BAUD, DCB, 4)
        NumPut("UInt", 0x0001, DCB, 8)
        NumPut("UChar", 8, DCB, 18)
        NumPut("UChar", 0, DCB, 19)
        NumPut("UChar", 0, DCB, 20)
        DllCall("SetCommState", "Ptr", hPort, "Ptr", DCB)
    }
    VarOut := Buffer(1, 0)
    NumPut("UChar", Ord("1"), VarOut, 0)
    DllCall("WriteFile", "Ptr", hPort, "Ptr", VarOut, "UInt", 1, "Ptr", Buffer(4, 0), "Ptr", 0)
    Sleep 1000
    NumPut("UChar", Ord("0"), VarOut, 0)
    DllCall("WriteFile", "Ptr", hPort, "Ptr", VarOut, "UInt", 1, "Ptr", Buffer(4, 0), "Ptr", 0)
    DllCall("CloseHandle", "Ptr", hPort)
}
GetAvailableComPorts() {
    ports := []
    try {
        colItems := ComObjGet("winmgmts:").ExecQuery("Select Name from Win32_PnPEntity where Name LIKE '%(COM%)'")
        for objItem in colItems
            ports.Push(objItem.Name)
    } catch {
    }
    if (ports.Length == 0) {
        Loop 20
            ports.Push("Serial Port (COM" A_Index ")")
    }
    return ports
}
g_ih := InputHook("V T0.15", "{Enter}")
g_ih.Start()
SetTimer CheckBarcode, 80
CheckBarcode() {
    global g_ih
    if g_ih.InProgress
        return
    text := g_ih.Input
    g_ih.Stop(), g_ih.Start()
    startPos := InStr(text, "~")
    if (startPos > 0) {
        endPos := InStr(text, "~", false, startPos + 1)
        if (endPos > startPos) {
            raw := SubStr(text, startPos + 1, endPos - startPos - 1)
            LogBarcode(raw)
            code := RegExReplace(raw, "[^\d]")
            if (code != "")
                TSQueueBarcode(code)
        }
    }
}
Global TS_PENDING := Map()
Global TS_LAST_SEND_TS := 0
TSQueueCount(val) {
    global TS_FIELD_COUNT
    TS_PENDING[TS_FIELD_COUNT] := val . ""
}
TSQueueBarcode(val) {
    global TS_FIELD_BARCODE
    TS_PENDING[TS_FIELD_BARCODE] := val . ""
}
SetTimer TSFlush, TS_FLUSH_INTERVAL
TSFlush() {
    global TS_PENDING, TS_LAST_SEND_TS, TS_MIN_INTERVAL
    if (TS_PENDING.Count == 0)
        return
    if (A_TickCount - TS_LAST_SEND_TS < TS_MIN_INTERVAL)
        return
    body := "api_key=" . TS_API_KEY
    for f,v in TS_PENDING
        body .= "&" f "=" v
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("POST", "https://api.thingspeak.com/update", false)
        req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        req.Send(body)
        if (req.Status = 200 && req.ResponseText != "0") {
            TS_PENDING.Clear()
            TS_LAST_SEND_TS := A_TickCount
        }
    }
}
F4::Nunulinti()
F8::RelayPulse()
F9:: {
    global
    CheckForUpdates()
    MsgBox "Dabartinė: " CURRENT_VERSION "`nNuotolinė: " RemoteVersion "`nHTTP Status: " LastHttpStatus "`nRaw: " LastRawResponse "`nURL: " LastCallUrl
}

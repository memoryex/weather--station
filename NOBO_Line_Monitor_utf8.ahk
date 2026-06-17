#Requires AutoHotkey v2.0
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

; =======================================================
; GLOBALAI
; =======================================================
Global OverlayGui, CtrlGui, SettingsGui
Global CountText := 0
Global ResetBtn := 0
Global CancelBtn := 0
Global DecBtn := 0
Global GearBtn := 0

Global NewFilesCount := 0
Global LastFileCount := 0
Global g_ih := 0
Global LogFile := ""
Global ResetPending := false
Global ResetDeadline := 0
Global DecStartTime := 0

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

; Line Data Map - Consistent with GD_Linijos.html
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
    "XLE 1",  {ID: "807602", Read: "WUO1DG7GXYNZP6SG", Write: "O7IB88R7L2ELXR3Q", Count: "field5", Barcode: "field6"}
)

LoadSettings() {
    global
    COM_PORT := IniRead(IniFile, "Settings", "ComPort", "COM3")
    Stebimas_Katalogas := IniRead(IniFile, "Settings", "Folder", A_Desktop)
    Selected_Line := IniRead(IniFile, "Settings", "Line", "XLE 1")

    if LineMap.Has(Selected_Line) {
        data := LineMap[Selected_Line]
        TS_CHANNEL_ID := data.ID
        TS_READ_KEY := data.Read
        TS_API_KEY := data.Write
        TS_FIELD_COUNT := data.Count
        TS_FIELD_BARCODE := data.Barcode
    }
}

SaveSettings(newCom, newFolder, newLine) {
    IniWrite(newCom, IniFile, "Settings", "ComPort")
    IniWrite(newFolder, IniFile, "Settings", "Folder")
    IniWrite(newLine, IniFile, "Settings", "Line")
}

LoadSettings()

; =======================================================
; PAGALBINĖS
; =======================================================
FormatTS() => FormatTime(, "yyyy-MM-dd HH:mm:ss")

LogAppend(line) {
    global LogFile
    if (LogFile = "")
        return
    try FileAppend line "`r`n", LogFile, "UTF-8"
}
LogBarcode(code) {
    LogAppend(FormatTS() " nuskanuotas barkodas ~" code "~")
}
LogCount(count) {
    LogAppend(FormatTS() " " count " gaminys")
}

RelayPulse() {
    global COM_PORT, COM_BAUD
    hPort := DllCall("CreateFile", "Str", "\\.\" COM_PORT, "UInt", 0x40000000, "UInt", 0, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
    if (hPort = -1)
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
    BytesWritten := Buffer(4, 0)
    DllCall("WriteFile", "Ptr", hPort, "Ptr", VarOut, "UInt", 1, "Ptr", BytesWritten, "Ptr", 0)
    Sleep 1000
    NumPut("UChar", Ord("0"), VarOut, 0)
    DllCall("WriteFile", "Ptr", hPort, "Ptr", VarOut, "UInt", 1, "Ptr", BytesWritten, "Ptr", 0)
    DllCall("CloseHandle", "Ptr", hPort)
}

GetAvailableComPorts() {
    ports := []
    try {
        for device in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_PnPEntity where Name Like '%(COM[0-9]%)'") {
            ports.Push(device.Name)
        }
    } catch {
        Loop 20
            ports.Push("Serial Port (COM" A_Index ")")
    }
    if (ports.Length = 0) {
        Loop 20
            ports.Push("Serial Port (COM" A_Index ")")
    }
    return ports
}

; =======================================================
; START
; =======================================================
if !DirExist(Stebimas_Katalogas) {
    MsgBox "Katalogas nerastas: " Stebimas_Katalogas ". Naudojamas Desktop."
    Stebimas_Katalogas := A_Desktop
}

LogFile := Stebimas_Katalogas "\scan_log.txt"
LastFileCount := 0
Loop Files, Stebimas_Katalogas "\*.*"
    LastFileCount++

; =======================================================
; GUI
; =======================================================
Lango_Dydis := 200
Start_X := 420
Start_Y := 800

; OverlayGui - Background and Big Number
OverlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption +LastFound +E0x20")
OverlayGui.BackColor := "Blue"
OverlayGui.SetFont("s65 bold cWhite", "Arial")
CountText := OverlayGui.Add("Text", "x0 y50 w" Lango_Dydis " h120 Center", "0")

; Version Label bottom-left (Yellowish color as in photo)
OverlayGui.SetFont("s10 italic cD4AF37", "Arial")
OverlayGui.Add("Text", "x5 y175 w50 h20 BackgroundTrans", "v2.3")

OverlayGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)
WinSetTransparent(200, OverlayGui)

; CtrlGui - Interaction Layer
CtrlGui := Gui("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner" OverlayGui.Hwnd)
CtrlGui.BackColor := "010101"
WinSetTransColor("010101", CtrlGui)

; Reset button - Full width
ResetBtn := CtrlGui.Add("Text", "x5 y5 w190 h30 Center +0x100 BackgroundRed cWhite", "RESET")
ResetBtn.SetFont("s10 bold", "Verdana")

; Small "-" button in vertical middle on the right
DecBtn := CtrlGui.Add("Text", "x165 y85 w30 h30 Center +0x100 BackgroundBlack cWhite", "-")
DecBtn.SetFont("s14 bold")

; Gear icon bottom right - solid background to ensure clickability
GearBtn := CtrlGui.Add("Text", "x165 y165 w30 h30 Center +0x100 BackgroundBlue cWhite", "⚙")
GearBtn.SetFont("s15", "Segoe UI Symbol")

CancelBtn := CtrlGui.Add("Button", "x5 y5 w190 h30 Hidden", "ATŠAUKTI")

CtrlGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)

ResetBtn.OnEvent("Click", StartResetCountdown)
GearBtn.OnEvent("Click", ShowSettings)
CancelBtn.OnEvent("Click", CancelReset)
DecBtn.OnEvent("Click", (*) => 0) ; Dummy to enable notifications for OnMessage

OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x0202, WM_LBUTTONUP)

SetTimer EnsureTopMost, 500
SetTimer TikrintiKataloga, 1000
SetTimer CheckExternalReset, 20000

EnsureTopMost() {
    global OverlayGui, CtrlGui
    if WinActive("ahk_id " OverlayGui.Hwnd) || WinActive("ahk_id " CtrlGui.Hwnd)
        return
    OverlayGui.Opt("+AlwaysOnTop")
    CtrlGui.Opt("+AlwaysOnTop")
}

; =======================================================
; MOUSE EVENTS (For hold logic)
; =======================================================
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global DecBtn, DecStartTime, NewFilesCount
    try {
        ctrl := GuiCtrlFromHwnd(hwnd)
        if (ctrl && ctrl.Hwnd = DecBtn.Hwnd) {
            if (NewFilesCount > 0) {
                DecStartTime := A_TickCount
                SetTimer UpdateDecCountdown, 100
            }
        }
    }
}

WM_LBUTTONUP(wParam, lParam, msg, hwnd) {
    global DecBtn
    SetTimer UpdateDecCountdown, 0
    if (DecBtn.Value != "-") {
        DecBtn.Value := "-"
    }
}

UpdateDecCountdown() {
    global DecBtn, DecStartTime
    Elapsed := A_TickCount - DecStartTime
    if (Elapsed >= 2000) {
        SetTimer UpdateDecCountdown, 0
        DoDecrement()
    } else {
        DecBtn.Value := Format("{:0.1f}", (2000 - Elapsed) / 1000)
    }
}

DoDecrement() {
    global NewFilesCount, DecBtn
    if (NewFilesCount > 0) {
        NewFilesCount -= 1
        UpdateCountDisplay()
        TSQueueCount(NewFilesCount)
        SoundBeep 400, 100
    }
    DecBtn.Value := "-"
}

; =======================================================
; SETTINGS GUI
; =======================================================
ShowSettings(*) {
    global SettingsGui, COM_PORT, Stebimas_Katalogas, Selected_Line
    SettingsGui := Gui("+AlwaysOnTop", "Nustatymai")

    SettingsGui.Add("Text", , "COM Prievadas:")
    comPorts := GetAvailableComPorts()
    comChoice := SettingsGui.Add("DropDownList", "vComPort w300", comPorts)

    selectedIdx := 1
    for idx, port in comPorts {
        if InStr(port, "(" COM_PORT ")") {
            selectedIdx := idx
            break
        }
    }
    comChoice.Choose(selectedIdx)

    SettingsGui.Add("Text", , "Stebimas katalogas:")
    folderEdit := SettingsGui.Add("Edit", "w300 vFolder", Stebimas_Katalogas)
    SettingsGui.Add("Button", "x+5 w30", "...").OnEvent("Click", (*) => (f := SelectFolder(), f ? folderEdit.Value := f : 0))

    SettingsGui.Add("Text", , "Gamybos linija:")
    lineNames := []
    for name, data in LineMap
        lineNames.Push(name)
    lineChoice := SettingsGui.Add("DropDownList", "w200 vLine", lineNames)
    Loop lineNames.Length {
        if lineNames[A_Index] = Selected_Line {
            lineChoice.Choose(A_Index)
            break
        }
    }

    saveBtn := SettingsGui.Add("Button", "w120 Default", "Save & Restart")
    saveBtn.OnEvent("Click", (*) => {
        RegExMatch(comChoice.Text, "COM\d+", &match)
        portName := match ? match[0] : "COM3"
        SaveAndRestart(portName, folderEdit.Value, lineChoice.Text)
    })

    SettingsGui.Show()
}

SelectFolder() {
    return DirSelect(Stebimas_Katalogas, 3, "Pasirinkite stebimą katalogą")
}

SaveAndRestart(c, f, l) {
    SaveSettings(c, f, l)
    Reload()
}

; =======================================================
; FAILŲ TIKRINIMAS
; =======================================================
TikrintiKataloga() {
    global NewFilesCount, LastFileCount, CountText, Stebimas_Katalogas
    CurrentCount := 0
    Loop Files, Stebimas_Katalogas "\*.*"
        CurrentCount++

    if (CurrentCount > LastFileCount) {
        Diff := CurrentCount - LastFileCount
        NewFilesCount += Diff
        Loop Diff {
            RelayPulse()
        }
        UpdateCountDisplay()
        LogCount(NewFilesCount)
        TSQueueCount(NewFilesCount)
    }
    LastFileCount := CurrentCount
}

UpdateCountDisplay() {
    global NewFilesCount, CountText
    CountText.Value := NewFilesCount
    CountText.SetFont("cLime")
    SetTimer () => CountText.SetFont("cWhite"), -350
}

Nunulinti() {
    global NewFilesCount, CountText, ResetBtn
    NewFilesCount := 0
    CountText.Value := 0
    ResetBtn.Value := "RESET"
    SoundBeep 700, 150
    TSQueueCount(0)
}

CheckExternalReset() {
    global TS_CHANNEL_ID, TS_READ_KEY, TS_FIELD_COUNT, NewFilesCount
    if (NewFilesCount == 0)
        return
    url := "https://api.thingspeak.com/channels/" . TS_CHANNEL_ID . "/fields/" . SubStr(TS_FIELD_COUNT, 6) . "/last.json?api_key=" . TS_READ_KEY
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, false)
        req.Send()
        if (req.Status = 200) {
            if (RegExMatch(req.ResponseText, '"' . TS_FIELD_COUNT . '":"0"')) {
                LogAppend(FormatTS() " aptiktas išorinis RESET per ThingSpeak")
                Nunulinti()
            }
        }
    }
}

; =======================================================
; RESET SU COUNTDOWN
; =======================================================
StartResetCountdown(*) {
    global ResetBtn, CancelBtn, DecBtn, ResetPending, ResetDeadline
    if (ResetPending)
        return
    ResetPending := true
    ResetDeadline := A_TickCount + 5000
    CancelBtn.Visible := true
    ResetBtn.Visible := false
    DecBtn.Visible := false
    SetTimer UpdateResetCountdown, 50
}

UpdateResetCountdown() {
    global ResetBtn, CancelBtn, DecBtn, ResetPending, ResetDeadline
    if (!ResetPending) {
        SetTimer UpdateResetCountdown, 0
        return
    }
    RemainingMs := ResetDeadline - A_TickCount
    if (RemainingMs <= 0) {
        SetTimer UpdateResetCountdown, 0
        CancelBtn.Visible := false
        DecBtn.Visible := true
        ResetBtn.Visible := true
        ResetPending := false
        ResetBtn.Value := "RESET"
        Nunulinti()
        return
    }
    CancelBtn.Text := "ATŠAUKTI (" Format("{:0.1f}s", RemainingMs/1000) ")"
}

CancelReset(*) {
    global ResetBtn, CancelBtn, DecBtn, ResetPending
    ResetPending := false
    SetTimer UpdateResetCountdown, 0
    CancelBtn.Visible := false
    DecBtn.Visible := true
    ResetBtn.Visible := true
    ResetBtn.Value := "RESET"
    SoundBeep 500, 120
}

; =======================================================
; BARCODE + THINGSPEAK
; =======================================================
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
    if (TS_PENDING.Count = 0)
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

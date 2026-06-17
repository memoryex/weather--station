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

Global TS_ENDPOINT := "https://api.thingspeak.com/update"
Global TS_MIN_INTERVAL := 15000
Global TS_FLUSH_INTERVAL := 1000
Global TS_LOG_ERRORS := true

Global IniFile := A_ScriptDir "\settings.ini"

; Line Data Map
Global LineMap := Map(
    "PLXE 1", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field1", Barcode: "field2"},
    "PLXE 2", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field3", Barcode: "field4"},
    "PLXE 3", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field5", Barcode: "field6"},
    "PLXE 4", {ID: "463450", Read: "VAL3TD2W5LADX7K1", Write: "9RO3MUI3LNTMQ0WO", Count: "field7", Barcode: "field8"},
    "NOBO 1", {ID: "703669", Read: "S44OBKWC5C7FODZ2", Write: "XPIME2EC8RKX9JO3", Count: "field1", Barcode: "field2"},
    "NOBO 2", {ID: "703669", Read: "S44OBKWC5C7FODZ3", Write: "XPIME2EC8RKX9JO3", Count: "field3", Barcode: "field4"},
    "NOBO 3", {ID: "703669", Read: "S44OBKWC5C7FODZ4", Write: "XPIME2EC8RKX9JO3", Count: "field5", Barcode: "field6"},
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
    try FileAppend line "`r`n", LogFile, "UTF-8"
}
LogBarcode(code) {
    LogAppend(FormatTS() " nuskanuotas barkodas ~" code "~")
}
LogCount(count) {
    LogAppend(FormatTS() " " count " gaminys")
}

MakeWindowClickThrough(hwnd) {
    WinSetExStyle("+0x20", "ahk_id " hwnd)
}

EnsureTopMost() {
    global OverlayGui, CtrlGui
    if WinActive("ahk_id " OverlayGui.Hwnd) || WinActive("ahk_id " CtrlGui.Hwnd)
        return
    OverlayGui.Opt("+AlwaysOnTop")
    CtrlGui.Opt("+AlwaysOnTop")
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
Pagrindine_Spalva := "Blue"
Langas_Skaidrumas := 200
Start_X := 420
Start_Y := 800

OverlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption")
OverlayGui.BackColor := Pagrindine_Spalva
OverlayGui.SetFont("s65 bold cWhite", "Arial")
CountText := OverlayGui.Add("Text", "x0 y80 w" Lango_Dydis " h100 Center", "0")

OverlayGui.SetFont("s20", "Segoe UI Symbol")
GearBtn := OverlayGui.Add("Text", "x165 y5 w30 h30 Center BackgroundTrans cWhite", "⚙")
GearBtn.OnEvent("Click", ShowSettings)

OverlayGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)
WinSetTransparent(Langas_Skaidrumas, OverlayGui)
MakeWindowClickThrough(OverlayGui.Hwnd)

BtnWidth := 160
BtnHeight := 38
BtnGap := 8
CtrlOffsetX := 10
CtrlOffsetY := 10

CtrlGui := Gui("+AlwaysOnTop +ToolWindow -Caption")
CtrlGui.BackColor := Pagrindine_Spalva
CtrlGui.SetFont("s10 bold cWhite", "Verdana")

ResetBtn := CtrlGui.Add("Text", "x10 y10 w" BtnWidth " h" BtnHeight " Center BackgroundRed", "RESET")
CancelBtn := CtrlGui.Add("Button", "x10 y" (10 + BtnHeight + BtnGap) " w" BtnWidth " h28 Hidden", "ATŠAUKTI")
DecBtn := CtrlGui.Add("Text", "x10 y" (10 + BtnHeight + BtnGap) " w" BtnWidth " h" BtnHeight " Center BackgroundBlack cWhite", "-")

CtrlGuiW := BtnWidth + 20
CtrlGuiH := 10 + (BtnHeight + BtnGap) * 2 + 10
CtrlGui.Show("x" (Start_X + CtrlOffsetX) " y" (Start_Y + CtrlOffsetY) " w" CtrlGuiW " h" CtrlGuiH)
WinSetTransparent(Langas_Skaidrumas, CtrlGui)

ResetBtn.OnEvent("Click", StartResetCountdown)
CancelBtn.OnEvent("Click", CancelReset)

; Custom hold logic for DecBtn
DecBtn.OnEvent("Click", (*) => 0) ; Dummy click handler
OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x0202, WM_LBUTTONUP)

SetTimer EnsureTopMost, 500
SetTimer TikrintiKataloga, 1000
SetTimer CheckExternalReset, 20000

; =======================================================
; MOUSE EVENTS (For hold logic)
; =======================================================
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global NewFilesCount, DecBtn
    if (hwnd = DecBtn.Hwnd) {
        if (NewFilesCount <= 0) return
        DecBtn.Value := "2s..."
        SetTimer DoDecrement, -2000 ; Run once after 2s
    }
}

WM_LBUTTONUP(wParam, lParam, msg, hwnd) {
    global DecBtn
    SetTimer DoDecrement, 0 ; Cancel if released early
    DecBtn.Value := "-"
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
    comList := "COM1|COM2|COM3|COM4|COM5|COM6|COM7|COM8|COM9|COM10|COM11|COM12|COM13|COM14|COM15|COM16|COM17|COM18|COM19|COM20"
    comChoice := SettingsGui.Add("DropDownList", "vComPort w100", StrSplit(comList, "|"))
    Loop StrSplit(comList, "|").Length {
        if StrSplit(comList, "|")[A_Index] = COM_PORT {
            comChoice.Choose(A_Index)
            break
        }
    }

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
    saveBtn.OnEvent("Click", (*) => SaveAndRestart(comChoice.Text, folderEdit.Value, lineChoice.Text))

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
        ResetPending := false
        ResetBtn.Value := "RESET"
        Nunulinti()
        return
    }
    ResetBtn.Value := "Atšaukti: " Format("{:0.1f}s", RemainingMs/1000)
}

CancelReset(*) {
    global ResetBtn, CancelBtn, DecBtn, ResetPending
    ResetPending := false
    SetTimer UpdateResetCountdown, 0
    CancelBtn.Visible := false
    DecBtn.Visible := true
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

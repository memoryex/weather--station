import re

ahk_content = r'''#Requires AutoHotkey v2.0
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

; =======================================================
; GLOBALAI
; =======================================================
Global OverlayGui, CtrlGui, SettingsGui
Global CURRENT_VERSION := "2.3"
Global RemoteVersion := "laukiama..."
Global LastHttpStatus := 0
Global LastRawResponse := "nieko"
Global LastCallUrl := ""

; Google Drive Direct Download nuorodos (iš Jūsų ID):
Global UPDATE_CHECK_URL := "https://docs.google.com/uc?export=download&id=1HG_aCqHaaXuHoLNjyoW1L3qNY1UqtMgt"
Global SCRIPT_DOWNLOAD_URL := "https://docs.google.com/uc?export=download&id=1zqCrySODTcXA29o_6aESCiuXQA3RtJUI"

Global CountText := 0
Global ResetBtn := 0
Global CancelBtn := 0
Global DecBtn := 0
Global GearBtn := 0
Global UpdateBtn := 0

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

LoadSettings()

; =======================================================
; GUI SETUP
; =======================================================
Lango_Dydis := 200
Start_X := 420
Start_Y := 800

OverlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption +LastFound +E0x20")
OverlayGui.BackColor := "Blue"
OverlayGui.SetFont("s65 bold cWhite", "Arial")
CountText := OverlayGui.Add("Text", "x0 y50 w" Lango_Dydis " h120 Center", "0")

OverlayGui.SetFont("s10 italic cD4AF37", "Arial")
OverlayGui.Add("Text", "x5 y175 w50 h20 BackgroundTrans", "v" CURRENT_VERSION)

OverlayGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)
WinSetTransparent(200, OverlayGui)

CtrlGui := Gui("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner" OverlayGui.Hwnd)
CtrlGui.BackColor := "010101"
WinSetTransColor("010101", CtrlGui)

ResetBtn := CtrlGui.Add("Text", "x5 y5 w190 h30 Center +0x100 BackgroundRed cWhite", "RESET")
ResetBtn.SetFont("s10 bold", "Verdana")

DecBtn := CtrlGui.Add("Text", "x165 y85 w30 h30 Center +0x100 BackgroundBlack cWhite", "-")
DecBtn.SetFont("s14 bold")

GearBtn := CtrlGui.Add("Text", "x165 y165 w30 h30 Center +0x100 BackgroundBlue cWhite", "⚙")
GearBtn.SetFont("s15", "Segoe UI Symbol")

CancelBtn := CtrlGui.Add("Button", "x5 y5 w190 h30 Hidden", "ATŠAUKTI")

UpdateBtn := CtrlGui.Add("Text", "x5 y40 w190 h25 Center +0x100 BackgroundE67E22 cWhite Hidden", "YRA NAUJA VERSIJA")
UpdateBtn.SetFont("s9 bold")
UpdateBtn.OnEvent("Click", StartUpdate)

CtrlGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)

ResetBtn.OnEvent("Click", StartResetCountdown)
GearBtn.OnEvent("Click", ShowSettings)
CancelBtn.OnEvent("Click", CancelReset)
DecBtn.OnEvent("Click", (*) => 0)

OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x0202, WM_LBUTTONUP)

SetTimer EnsureTopMost, 500
SetTimer TikrintiKataloga, 1000
SetTimer CheckExternalReset, 20000
SetTimer CheckForUpdates, 30000

EnsureTopMost() {
    global OverlayGui, CtrlGui
    if WinActive("ahk_id " OverlayGui.Hwnd) || WinActive("ahk_id " CtrlGui.Hwnd)
        return
    OverlayGui.Opt("+AlwaysOnTop")
    CtrlGui.Opt("+AlwaysOnTop")
}

; =======================================================
; UPDATE LOGIC (Robust for Google Drive)
; =======================================================
CheckForUpdates() {
    global UPDATE_CHECK_URL, CURRENT_VERSION, UpdateBtn, RemoteVersion, LastHttpStatus, LastRawResponse, LastCallUrl
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        Separator := InStr(UPDATE_CHECK_URL, "?") ? "&" : "?"
        LastCallUrl := UPDATE_CHECK_URL . Separator . "t=" . A_TickCount

        whr.Open("GET", LastCallUrl, true)
        whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        whr.SetRequestHeader("Pragma", "no-cache")
        whr.SetRequestHeader("Cache-Control", "no-cache")
        whr.Send()
        whr.WaitForResponse(10)

        LastHttpStatus := whr.Status
        LastRawResponse := SubStr(whr.ResponseText, 1, 200)

        if (whr.Status == 200) {
            if (InStr(whr.ResponseText, "<html") || InStr(whr.ResponseText, "<body")) {
                RemoteVersion := "KLAIDA: Gautas HTML (ne failas)"
                return
            }

            RemoteVersion := Trim(RegExReplace(whr.ResponseText, "[^\d\.]"))
            if (RemoteVersion != "" && RemoteVersion != CURRENT_VERSION) {
                UpdateBtn.Visible := true
            }
        }
    } catch Error as e {
        LastHttpStatus := "KLAIDA: " . e.Message
    }
}

StartUpdate(*) {
    global SCRIPT_DOWNLOAD_URL, UpdateBtn
    if (MsgBox("Ar norite atnaujinti programą į naują versiją?", "Atnaujinimas", 4) == "No")
        return

    try {
        UpdateBtn.Value := "SIUNČIAMA..."
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", SCRIPT_DOWNLOAD_URL . "?t=" . A_TickCount, true)
        whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        whr.Send()
        whr.WaitForResponse(30)

        if (whr.Status == 200) {
            NewCode := whr.ResponseText
            if (InStr(NewCode, "#Requires AutoHotkey") && !InStr(NewCode, "<html")) {
                f := FileOpen(A_ScriptFullPath, "w", "UTF-8")
                f.Write(NewCode)
                f.Close()
                MsgBox "Atnaujinta sėkmingai! Programa persikraus.", "Baigta", "Iconi"
                Reload()
            } else {
                throw Error("Parsiųstas failas neatrodo kaip teisingas kodas (gautas HTML).")
            }
        }
    } catch Error as e {
        MsgBox "Klaida atnaujinant: " . e.Message, "Klaida", "Iconx"
        UpdateBtn.Value := "YRA NAUJA VERSIJA"
    }
}

; =======================================================
; MOUSE EVENTS
; =======================================================
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global DecBtn, DecStartTime, NewFilesCount
    try {
        ctrl := GuiCtrlFromHwnd(hwnd)
        if (ctrl && ctrl.Hwnd == DecBtn.Hwnd) {
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
        if lineNames[A_Index] == Selected_Line {
            lineChoice.Choose(A_Index)
            break
        }
    }
    saveBtn := SettingsGui.Add("Button", "w120 Default", "Save & Restart")
    saveBtn.OnEvent("Click", ProcessSave)
    ProcessSave(*) {
        RegExMatch(comChoice.Text, "COM\d+", &match)
        portName := match ? match[0] : "COM3"
        SaveAndRestart(portName, folderEdit.Value, lineChoice.Text)
    }
    SettingsGui.Show()
}
SelectFolder() {
    return DirSelect(Stebimas_Katalogas, 3, "Pasirinkite stebimą katalogą")
}
SaveAndRestart(c, f, l) {
    IniWrite(c, IniFile, "Settings", "ComPort")
    IniWrite(f, IniFile, "Settings", "Folder")
    IniWrite(l, IniFile, "Settings", "Line")
    Reload()
}

; =======================================================
; FAILŲ TIKRINIMAS IR PAGALBINĖS
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
LogAppend(line) {
    global LogFile
    if (LogFile == "")
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

; BARCODE + THINGSPEAK
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
F9::MsgBox "Dabartinė: " CURRENT_VERSION "`nNuotolinė: " RemoteVersion "`nHTTP Status: " LastHttpStatus "`nURL: " LastCallUrl "`nRaw: " LastRawResponse
'''

with open('NOBO_Line_Monitor_v2.4_Prototype.ahk', 'w', encoding='utf-8') as f:
    f.write(ahk_content)

print("Prototype fixed (SaveSettings removed, logic inlined).")

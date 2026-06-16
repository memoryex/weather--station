#Requires AutoHotkey v2.0
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

; =======================================================
; GLOBALAI
; =======================================================
Global OverlayGui, CtrlGui
Global CountText := 0
Global ResetBtn := 0
Global CancelBtn := 0

Global NewFilesCount := 0
Global LastFileCount := 0
Global g_ih := 0
Global LogFile := ""
Global ResetPending := false
Global ResetDeadline := 0

; ===== ATNAUJINTA: RELĖS NUSTATYMAI =====
Global COM_PORT := "COM3"
Global COM_BAUD := 9600

; Patikimesnis COM prievado impulsas naudojant Windows API (DllCall)
RelayPulse() {
    global COM_PORT, COM_BAUD

    ; 1. Atsidarome COM prievadą (palaiko ir COM numerius virš 9, pvz. "\\.\COM3")
    portName := (SubStr(COM_PORT, 1, 4) = "\\.\") ? COM_PORT : "\\.\" COM_PORT
    hPort := DllCall("CreateFile", "Str", portName, "UInt", 0xC0000000, "UInt", 0, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")

    if (hPort = -1 || hPort = 0xFFFFFFFF) {
        LogAppend(FormatTS() " KLAIDA: Nepavyko atidaryti " COM_PORT)
        return
    }

    ; 2. Sukonfigūruojame greitį (Baud Rate) ir parametrus pagal AHK v2 taisykles
    DCB := Buffer(28, 0)
    NumPut("UInt", 28, DCB, 0) ; DCBlength

    if DllCall("GetCommState", "Ptr", hPort, "Ptr", DCB) {
        ; AHK v2 NumPut sintaksė: NumPut(Tipas1, Reikšmė1, Tipas2, Reikšmė2, ..., Buferis, Poslinkis)
        NumPut("UInt", COM_BAUD, DCB, 4)   ; BaudRate
        NumPut("UInt", 0x0001, DCB, 8)     ; fBinary = 1
        NumPut("UChar", 8, DCB, 18)        ; ByteSize (UChar atitinka baitą)
        NumPut("UChar", 0, DCB, 19)        ; Parity (0 = NOPARITY)
        NumPut("UChar", 0, DCB, 20)        ; StopBits (0 = ONESTOPBIT)

        DllCall("SetCommState", "Ptr", hPort, "Ptr", DCB)
    }

    ; 3. Išsiunčiame "1" (Įjungti)
    VarOut := Buffer(1, 0)
    NumPut("UChar", Ord("1"), VarOut, 0)
    BytesWritten := Buffer(4, 0)
    DllCall("WriteFile", "Ptr", hPort, "Ptr", VarOut, "UInt", 1, "Ptr", BytesWritten, "Ptr", 0)

    ; 4. Palaukiame 1 sekundę
    Sleep 1000

    ; 5. Išsiunčiame "0" (Išjungti)
    NumPut("UChar", Ord("0"), VarOut, 0)
    DllCall("WriteFile", "Ptr", hPort, "Ptr", VarOut, "UInt", 1, "Ptr", BytesWritten, "Ptr", 0)

    ; 6. Uždarome prievadą
    DllCall("CloseHandle", "Ptr", hPort)
}

; =======================================================
; NUSTATYMAI
; =======================================================
Stebimas_Katalogas := "C:\Users\Localadmin\Documents\Test_Results\Passed"

Langas_Skaidrumas := 200
Pagrindine_Spalva := "Blue"
Lango_Dydis := 200

Start_X := 300
Start_Y := 800

BtnWidth := 160
BtnHeight := 38
BtnGap := 8

ResetTouchDelayMs := 5000
ResetMouseHoldMs := 1000

; ----------- THINGSPEAK --------------
TS_CHANNEL_ID := "703669"
TS_READ_KEY := "S44OBKWC5C7FODZ5"
TS_API_KEY := "XPIME2EC8RKX9JO3"
TS_FIELD_COUNT := "field1"
TS_FIELD_BARCODE := "field2"

TS_ENDPOINT := "https://api.thingspeak.com/update"
TS_MIN_INTERVAL := 15000
TS_FLUSH_INTERVAL := 1000
TS_LOG_ERRORS := true

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

EnsureTopMost() {
    global OverlayGui, CtrlGui
    try WinSetAlwaysOnTop 1, OverlayGui.Hwnd
    try WinSetAlwaysOnTop 1, CtrlGui.Hwnd
}

MakeWindowClickThrough(hwnd) {
    ex := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
    DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr", ex | 0x20 | 0x80000)
}

MoveBoth(x, y) {
    global OverlayGui, CtrlGui, CtrlOffsetX, CtrlOffsetY
    OverlayGui.Move(x, y)
    CtrlGui.Move(x + CtrlOffsetX, y + CtrlOffsetY)
}

; =======================================================
; START
; =======================================================
if !DirExist(Stebimas_Katalogas) {
    MsgBox "Katalogas nerastas:`n" Stebimas_Katalogas
    ExitApp
}

LogFile := Stebimas_Katalogas "\scan_log.txt"

LastFileCount := 0
Loop Files, Stebimas_Katalogas "\*.*"
    LastFileCount++

; =======================================================
; GUI
; =======================================================
OverlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption")
OverlayGui.BackColor := Pagrindine_Spalva
OverlayGui.SetFont("s65 bold cWhite", "Arial")
CountText := OverlayGui.Add("Text", "x0 y100 w" Lango_Dydis " h100 Center", "0")
OverlayGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" Lango_Dydis)
WinSetTransparent(Langas_Skaidrumas, OverlayGui)
MakeWindowClickThrough(OverlayGui.Hwnd)

CtrlGui := Gui("+AlwaysOnTop +ToolWindow -Caption")
CtrlGui.BackColor := Pagrindine_Spalva
CtrlGui.SetFont("s10 bold cWhite", "Verdana")

ResetBtn := CtrlGui.Add("Text", "x10 y10 w" BtnWidth " h" BtnHeight " Center BackgroundRed", "RESET")
CancelBtn := CtrlGui.Add("Button", "x10 y" (10 + BtnHeight + BtnGap) " w" BtnWidth " h28 Hidden", "ATŠAUKTI")

CtrlGuiW := BtnWidth + 20
CtrlGuiH := 10 + BtnHeight + BtnGap + 28 + 10
CtrlOffsetX := 10
CtrlOffsetY := 10

CtrlGui.Show("x" (Start_X + CtrlOffsetX) " y" (Start_Y + CtrlOffsetY) " w" CtrlGuiW " h" CtrlGuiH)
WinSetTransparent(Langas_Skaidrumas, CtrlGui)

ResetBtn.OnEvent("Click", StartResetCountdown)
CancelBtn.OnEvent("Click", CancelReset)

SetTimer EnsureTopMost, 500
SetTimer TikrintiKataloga, 1000
SetTimer CheckExternalReset, 20000 ; Polling ThingSpeak kas 20 sekundžių

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

        ; Generuojame relės impulsus pagal naujų failų skaičių
        Loop Diff {
            RelayPulse()
        }

        CountText.Value := NewFilesCount
        LogCount(NewFilesCount)
        TSQueueCount(NewFilesCount)

        CountText.SetFont("cLime")
        SetTimer () => CountText.SetFont("cWhite"), -350
    }
    LastFileCount := CurrentCount
}

; =======================================================
Nunulinti() {
    global NewFilesCount, CountText, ResetBtn
    NewFilesCount := 0
    CountText.Value := 0
    ResetBtn.Value := "RESET"
    SoundBeep 700, 150
    TSQueueCount(0)
}

; =======================================================
; IŠORINIO RESET TIKRINIMAS (IŠ HTML)
; =======================================================
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
            resp := req.ResponseText
            ; Tikriname ar ThingSpeak lauke yra "0"
            if (RegExMatch(resp, '"' . TS_FIELD_COUNT . '":"0"')) {
                LogAppend(FormatTS() " aptiktas išorinis RESET per ThingSpeak")
                Nunulinti()
            }
        }
    }
    catch {
        ; Tinklo klaidos ignoruojamos
    }
}

; =======================================================
; RESET SU COUNTDOWN
; =======================================================
StartResetCountdown(*) {
    global ResetBtn, CancelBtn, ResetPending, ResetDeadline, ResetTouchDelayMs
    if (ResetPending)
        return
    ResetPending := true
    ResetDeadline := A_TickCount + ResetTouchDelayMs
    CancelBtn.Visible := true
    UpdateResetCountdown()
    SetTimer UpdateResetCountdown, 50
}

UpdateResetCountdown() {
    global ResetBtn, CancelBtn, ResetPending, ResetDeadline
    if (!ResetPending) {
        SetTimer UpdateResetCountdown, 0
        return
    }

    RemainingMs := ResetDeadline - A_TickCount

    if (RemainingMs <= 0) {
        SetTimer UpdateResetCountdown, 0
        CancelBtn.Visible := false
        ResetPending := false
        ResetBtn.Value := "RESET"
        Nunulinti()
        return
    }

    ResetBtn.Value := "Atšaukti per: " Format("{:0.1f}s", RemainingMs/1000)
}

CancelReset(*) {
    global ResetBtn, CancelBtn, ResetPending
    ResetPending := false
    SetTimer UpdateResetCountdown, 0
    CancelBtn.Visible := false
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

; =======================================================
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

    body := BuildTSBody()
    if (body = "")
        return

    if (TSSendBody(body)) {
        TS_PENDING.Clear()
        TS_LAST_SEND_TS := A_TickCount
    }
}

BuildTSBody() {
    global TS_PENDING, TS_API_KEY
    if (TS_PENDING.Count = 0)
        return ""
    body := "api_key=" . TS_API_KEY
    for f,v in TS_PENDING
        body .= "&" f "=" v
    return body
}

TSSendBody(body) {
    global TS_ENDPOINT, TS_LOG_ERRORS
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("POST", TS_ENDPOINT, false)
        req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        req.Send(body)
        status := req.Status
        resp := req.ResponseText
        if (status = 200 && resp != "0")
            return true
        return false
    }
    catch {
        return false
    }
}

; =======================================================
^!t::
{
    global NewFilesCount
    TSQueueCount(NewFilesCount)
}

F4::Nunulinti()
F8::RelayPulse()

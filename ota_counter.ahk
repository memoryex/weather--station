#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Event"
CoordMode "Mouse", "Screen"

; =======================================================
; NUSTATYMAI (Numatytieji)
; =======================================================
global Root_Katalogai := [
    "C:\Users\EoltUI\Desktop\WIFI ALTA 5.0",
    "C:\Users\EoltUI\Desktop\WIFI ALTA 5.0 FGT",
    "C:\Users\EoltUI\Desktop\EP4164_XLEEU_OTA_reprogram"
]

Langas_Skaidrumas := 200
Pagrindine_Spalva := 0x0055AA
Lango_Dydis := 220

Start_X := 300
Start_Y := 800

BtnWidth := 160
BtnHeight := 38

; -------- THINGSPEAK --------
TS_API_KEY      := "O7IB88R7L2ELXR3Q"
TS_FIELD_COUNT  := "field1"
TS_ENDPOINT     := "https://api.thingspeak.com/update"
TS_MIN_INTERVAL := 15000

; =======================================================
; GLOBALAI
; =======================================================
global OverlayGui := 0
global CtrlGui := 0
global SettingsGui := 0
global TotalText := 0
global NewText := 0
global TotalCount := 0
global NewCount := 0
global ScannedLogs := Map()
global DirTotals := Map()
global DirTextCtrls := Map()
global TS_LAST_SEND := 0

global ResetPending := false
global ResetCountdown := 5
global ResetBtn := 0
global SettingsBtn := 0

; =======================================================
; CONFIG VALDYMAS (settings.ini)
; =======================================================
LoadConfig() {
    global Root_Katalogai
    iniPath := A_ScriptDir "\settings.ini"

    if (!FileExist(iniPath))
        return

    try {
        val := IniRead(iniPath, "Settings", "Root_Katalogai", "")
        if (val != "") {
            loaded := StrSplit(val, "|")
            if (loaded.Length > 0) {
                Root_Katalogai := loaded
            }
        }
    }
}

SaveConfig() {
    global Root_Katalogai
    iniPath := A_ScriptDir "\settings.ini"

    str := ""
    for i, dir in Root_Katalogai {
        str .= (i = 1 ? "" : "|") . dir
    }

    try {
        IniWrite(str, iniPath, "Settings", "Root_Katalogai")
    }
}

; =======================================================
; FUNKCIJOS
; =======================================================
EnsureTopMost() {
    global OverlayGui, CtrlGui
    if IsObject(OverlayGui) {
        try WinSetAlwaysOnTop true, "ahk_id " OverlayGui.Hwnd
    }
    if IsObject(CtrlGui) {
        try WinSetAlwaysOnTop true, "ahk_id " CtrlGui.Hwnd
    }
}

MakeWindowClickThrough(hwnd) {
    style := DllCall("GetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr")
    DllCall("SetWindowLongPtr", "ptr", hwnd, "int", -20, "ptr", style | 0x20 | 0x80000)
}

GetDirDisplayName(dir) {
    global Root_Katalogai
    SplitPath(dir, &outName, &outDir)
    if (outName = "")
        return dir

    dupCount := 0
    for _, d in Root_Katalogai {
        SplitPath(d, &n)
        if (n = outName)
            dupCount++
    }

    if (dupCount > 1) {
        SplitPath(outDir, &parentName)
        if (parentName != "")
            return parentName "\" outName
    }

    return outName
}

; =======================================================
; RESET LOGIKA SU ATŠAUKIMU
; =======================================================
OnResetClick(*) {
    global ResetPending

    if (!ResetPending)
        StartReset()
    else
        CancelReset()
}

StartReset() {
    global ResetPending, ResetCountdown, ResetBtn

    ResetPending := true
    ResetCountdown := 5
    ResetBtn.Text := "ATŠAUKTI (" ResetCountdown ")"

    SetTimer(UpdateResetCountdown, 1000)
}

UpdateResetCountdown() {
    global ResetPending, ResetCountdown, ResetBtn

    ResetCountdown--

    if (!ResetPending) {
        SetTimer(UpdateResetCountdown, 0)
        return
    }

    if (ResetCountdown > 0) {
        ResetBtn.Text := "ATŠAUKTI (" ResetCountdown ")"
    } else {
        SetTimer(UpdateResetCountdown, 0)
        DoReset()
    }
}

CancelReset() {
    global ResetPending, ResetBtn

    if (!ResetPending)
        return

    ResetPending := false
    SetTimer(UpdateResetCountdown, 0)
    ResetBtn.Text := "RESET"
}

DoReset() {
    global ResetPending, NewCount, NewText, ResetBtn

    ResetPending := false
    NewCount := 0
    if IsObject(NewText)
        NewText.Value := "Nauji: 0"
    ResetBtn.Text := "RESET"

    SetTimer(UpdateResetCountdown, 0)
}

; =======================================================
; NUSTATYMŲ GUI
; =======================================================
OnSettingsClick(*) {
    global SettingsGui

    if (IsObject(SettingsGui)) {
        try {
            WinActivate("ahk_id " SettingsGui.Hwnd)
            return
        }
    }

    OpenSettingsGui()
}

OpenSettingsGui() {
    global SettingsGui, Root_Katalogai

    SettingsGui := Gui("+AlwaysOnTop +ToolWindow", "Katalogų nustatymai")
    SettingsGui.SetFont("s10", "Segoe UI")

    SettingsGui.AddText("x10 y10 w480", "Stebimi katalogai:")

    LV := SettingsGui.Add("ListView", "x10 y35 w480 h200 -Multi Grid", ["Katalogas"])
    for _, dir in Root_Katalogai {
        LV.Add("", dir)
    }
    LV.ModifyCol(1, 460)

    BtnAdd := SettingsGui.Add("Button", "x10 y245 w140 h32", "Pridėti katalogą")
    BtnDel := SettingsGui.Add("Button", "x160 y245 w140 h32", "Pašalinti pasirinktą")
    BtnSave := SettingsGui.Add("Button", "x310 y245 w85 h32", "Išsaugoti")
    BtnCancel := SettingsGui.Add("Button", "x405 y245 w85 h32", "Atšaukti")

    BtnAdd.OnEvent("Click", (*) => OnAddDir(LV))
    BtnDel.OnEvent("Click", (*) => OnDelDir(LV))
    BtnSave.OnEvent("Click", (*) => OnSaveSettings(LV))
    BtnCancel.OnEvent("Click", (*) => SettingsGui.Destroy())
    SettingsGui.OnEvent("Close", (*) => (SettingsGui := 0))

    SettingsGui.Show("w500 h290")
}

OnAddDir(LV) {
    chosen := DirSelect("", 3, "Pasirinkite stebimą katalogą")
    if (chosen != "") {
        Loop LV.GetCount() {
            if (StrCompare(LV.GetText(A_Index), chosen, true) = 0) {
                MsgBox("Šis katalogas jau yra sąraše!", "Informacija", "64")
                return
            }
        }
        LV.Add("", chosen)
        LV.ModifyCol(1, 460)
    }
}

OnDelDir(LV) {
    row := LV.GetNext(0)
    if (row > 0) {
        LV.Delete(row)
    } else {
        MsgBox("Pasirinkite katalogą, kurį norite pašalinti.", "Informacija", "64")
    }
}

OnSaveSettings(LV) {
    global Root_Katalogai, SettingsGui

    newDirs := []
    Loop LV.GetCount() {
        path := LV.GetText(A_Index)
        if (path != "") {
            newDirs.Push(path)
        }
    }

    if (newDirs.Length = 0) {
        MsgBox("Būtina pasirinkti bent vieną katalogą!", "Klaida", "48")
        return
    }

    Root_Katalogai := newDirs
    SaveConfig()
    if IsObject(SettingsGui) {
        SettingsGui.Destroy()
        SettingsGui := 0
    }
    ReinitAll()
}

; =======================================================
; PRADINIS LOGŲ NUSKAITYMAS (kad Nauji = 0)
; =======================================================
InitLogCounts() {
    global Root_Katalogai, ScannedLogs, TotalCount, NewCount, DirTotals

    ScannedLogs := Map()
    DirTotals := Map()
    TotalCount := 0
    NewCount := 0

    for _, dir in Root_Katalogai {
        DirTotals[dir] := 0

        if !DirExist(dir)
            continue

        Loop Files, dir "\*.log", "R" {
            file := A_LoopFileFullPath

            try {
                f := FileOpen(file, "r")
                if !f
                    continue

                text := f.Read()
                f.Close()

                cnt := 0
                RegExReplace(text, "INFO.*OTA.*Exit", , &cnt)

                ScannedLogs[file] := cnt
                DirTotals[dir] += cnt
                TotalCount += cnt
            }
        }
    }
}

; =======================================================
; LOGŲ SKENAVIMAS
; =======================================================
TikrintiKataloga() {
    global Root_Katalogai, TotalCount, NewCount, ScannedLogs, DirTotals

    hasNewData := false

    for _, dir in Root_Katalogai {
        if !DirTotals.Has(dir)
            DirTotals[dir] := 0

        if !DirExist(dir)
            continue

        Loop Files, dir "\*.log", "R" {
            file := A_LoopFileFullPath
            prev := ScannedLogs.Has(file) ? ScannedLogs[file] : 0

            try {
                f := FileOpen(file, "r")
                if !f
                    continue

                text := f.Read()
                f.Close()

                cnt := 0
                RegExReplace(text, "INFO.*OTA.*Exit", , &cnt)

                if (cnt > prev) {
                    diff := cnt - prev

                    TotalCount += diff
                    NewCount += diff
                    DirTotals[dir] += diff

                    hasNewData := true
                }

                ScannedLogs[file] := cnt
            }
        }
    }

    UpdateOverlayValues()

    if (hasNewData) {
        TS_Send(NewCount)
    }
}

UpdateOverlayValues() {
    global TotalText, NewText, DirTextCtrls, TotalCount, NewCount, Root_Katalogai, DirTotals

    if (!IsObject(OverlayGui))
        return

    TotalText.Value := "Viso: " TotalCount
    NewText.Value := "Nauji: " NewCount

    for _, dir in Root_Katalogai {
        if DirTextCtrls.Has(dir) {
            displayName := GetDirDisplayName(dir)
            cnt := DirTotals.Has(dir) ? DirTotals[dir] : 0
            DirTextCtrls[dir].Value := displayName ": " cnt
        }
    }
}

; =======================================================
; THINGSPEAK
; =======================================================
TS_Send(value) {
    global TS_API_KEY, TS_FIELD_COUNT, TS_ENDPOINT, TS_MIN_INTERVAL, TS_LAST_SEND

    if (A_TickCount - TS_LAST_SEND < TS_MIN_INTERVAL)
        return

    body := "api_key=" TS_API_KEY "&" TS_FIELD_COUNT "=" value

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("POST", TS_ENDPOINT, false)
        req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        req.Send(body)
        if (req.Status = 200)
            TS_LAST_SEND := A_TickCount
    }
}

; =======================================================
; GUI – SKAITLIUKAS (Dinamiškas Overlay)
; =======================================================
RebuildOverlayGui() {
    global OverlayGui, TotalText, NewText, DirTextCtrls
    global Pagrindine_Spalva, Lango_Dydis, Start_X, Start_Y, Langas_Skaidrumas
    global TotalCount, NewCount, Root_Katalogai, DirTotals

    if IsObject(OverlayGui) {
        try OverlayGui.Destroy()
    }
    DirTextCtrls := Map()

    OverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    OverlayGui.BackColor := Pagrindine_Spalva

    yPos := 15
    OverlayGui.SetFont("s22 bold cWhite", "Arial")
    TotalText := OverlayGui.AddText("x0 y" yPos " w" Lango_Dydis " Center", "Viso: " TotalCount)

    yPos += 42
    NewText := OverlayGui.AddText("x0 y" yPos " w" Lango_Dydis " Center", "Nauji: " NewCount)

    yPos += 45
    OverlayGui.SetFont("s9 bold cYellow", "Arial")
    OverlayGui.AddText("x10 y" yPos " w" (Lango_Dydis - 20) " Center", "--- KATALOGAI ---")

    yPos += 20
    OverlayGui.SetFont("s10 bold cWhite", "Arial")
    for _, dir in Root_Katalogai {
        displayName := GetDirDisplayName(dir)
        cnt := DirTotals.Has(dir) ? DirTotals[dir] : 0

        ctrl := OverlayGui.AddText("x10 y" yPos " w" (Lango_Dydis - 20) " Left", displayName ": " cnt)
        DirTextCtrls[dir] := ctrl
        yPos += 22
    }

    yPos += 15
    OverlayGui.Show("x" Start_X " y" Start_Y " w" Lango_Dydis " h" yPos " NoActivate")
    WinSetTransparent Langas_Skaidrumas, "ahk_id " OverlayGui.Hwnd
    MakeWindowClickThrough OverlayGui.Hwnd
}

; =======================================================
; GUI – VALDYMAS (RESET IR NUSTATYMAI)
; =======================================================
BuildCtrlGui() {
    global CtrlGui, ResetBtn, SettingsBtn
    global Pagrindine_Spalva, Start_X, Start_Y, Lango_Dydis, BtnHeight, Langas_Skaidrumas

    if IsObject(CtrlGui) {
        try CtrlGui.Destroy()
    }

    CtrlGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    CtrlGui.BackColor := Pagrindine_Spalva
    CtrlGui.SetFont("s9 bold cWhite", "Verdana")

    btnW := Integer((Lango_Dydis - 25) / 2)

    ResetBtn := CtrlGui.AddText(
        "x10 y10 w" btnW " h" BtnHeight " Center BackgroundRed",
        "RESET"
    )
    ResetBtn.OnEvent("Click", OnResetClick)

    SettingsBtn := CtrlGui.AddText(
        "x" (15 + btnW) " y10 w" btnW " h" BtnHeight " Center Background007ACC",
        "NUSTATYMAI"
    )
    SettingsBtn.OnEvent("Click", OnSettingsClick)

    CtrlGui.Show(
        "x" Start_X
        " y" (Start_Y - 55)
        " w" Lango_Dydis
        " h" (BtnHeight + 20)
    )
    WinSetTransparent Langas_Skaidrumas, "ahk_id " CtrlGui.Hwnd
}

ReinitAll() {
    InitLogCounts()
    RebuildOverlayGui()
}

; =======================================================
; INICIALIZACIJA IR TIMERIAI
; =======================================================
LoadConfig()
InitLogCounts()
BuildCtrlGui()
RebuildOverlayGui()

SetTimer EnsureTopMost, 500
SetTimer TikrintiKataloga, 10000

; =======================================================
; HOTKEY
; =======================================================
Esc::ExitApp

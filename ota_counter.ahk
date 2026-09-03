#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Event"
CoordMode "Mouse", "Screen"

; =======================================================
; NUSTATYMAI (Numatytieji)
; =======================================================
global TS_API_KEY      := "O7IB88R7L2ELXR3Q"
global TS_FIELD_COUNT  := "field1"
global TS_ENDPOINT     := "https://api.thingspeak.com/update"
global TS_MIN_INTERVAL := 15000

global Root_Katalogai := [
    { path: "C:\Users\EoltUI\Desktop\WIFI ALTA 5.0", apiKey: TS_API_KEY, field: TS_FIELD_COUNT },
    { path: "C:\Users\EoltUI\Desktop\WIFI ALTA 5.0 FGT", apiKey: TS_API_KEY, field: TS_FIELD_COUNT },
    { path: "C:\Users\EoltUI\Desktop\EP4164_XLEEU_OTA_reprogram", apiKey: TS_API_KEY, field: TS_FIELD_COUNT }
]

Langas_Skaidrumas := 200
Pagrindine_Spalva := 0x0055AA
Lango_Dydis := 220

Start_X := 300
Start_Y := 800

BtnWidth := 160
BtnHeight := 38

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
global TS_LAST_SEND := Map()

global ResetPending := false
global ResetCountdown := 5
global ResetBtn := 0
global SettingsBtn := 0

; =======================================================
; CONFIG VALDYMAS (settings.ini)
; =======================================================
LoadConfig() {
    global Root_Katalogai, TS_API_KEY, TS_FIELD_COUNT
    iniPath := A_ScriptDir "\settings.ini"

    if (!FileExist(iniPath))
        return

    try {
        val := IniRead(iniPath, "Settings", "Root_Katalogai", "")
        if (val != "") {
            loaded := []
            for item in StrSplit(val, "||") {
                if (item = "")
                    continue
                parts := StrSplit(item, "|")
                p := parts[1]
                k := (parts.Length >= 2 && parts[2] != "") ? parts[2] : TS_API_KEY
                f := (parts.Length >= 3 && parts[3] != "") ? parts[3] : TS_FIELD_COUNT
                if (p != "") {
                    loaded.Push({ path: p, apiKey: k, field: f })
                }
            }
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
    for i, item in Root_Katalogai {
        str .= (i = 1 ? "" : "||") . item.path . "|" . item.apiKey . "|" . item.field
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
    for _, item in Root_Katalogai {
        SplitPath(item.path, &n)
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
    global SettingsGui, Root_Katalogai, TS_API_KEY, TS_FIELD_COUNT

    SettingsGui := Gui("+AlwaysOnTop +ToolWindow", "Katalogų / Termostatų nustatymai")
    SettingsGui.SetFont("s9", "Segoe UI")

    SettingsGui.AddText("x10 y10 w580", "Stebimi katalogai (Termostatai) ir ThingSpeak nustatymai:")

    LV := SettingsGui.Add("ListView", "x10 y32 w580 h160 -Multi Grid", ["Katalogas", "API Raktas (Write Key)", "Laukas"])
    for _, item in Root_Katalogai {
        LV.Add("", item.path, item.apiKey, item.field)
    }
    LV.ModifyCol(1, 260)
    LV.ModifyCol(2, 200)
    LV.ModifyCol(3, 100)

    SettingsGui.AddGroupBox("x10 y200 w580 h70", "Pasirinkto įrašo nustatymai")
    SettingsGui.AddText("x20 y222 w140", "API Raktas (Write Key):")
    EditKey := SettingsGui.Add("Edit", "x20 y240 w220 h24", TS_API_KEY)

    SettingsGui.AddText("x250 y222 w100", "Laukas:")
    EditField := SettingsGui.Add("Edit", "x250 y240 w100 h24", TS_FIELD_COUNT)

    BtnUpdateRow := SettingsGui.Add("Button", "x360 y240 w120 h24", "Išsaugoti eilutę")

    BtnAdd := SettingsGui.Add("Button", "x10 y280 w140 h32", "Pridėti katalogą")
    BtnDel := SettingsGui.Add("Button", "x160 y280 w140 h32", "Pašalinti pasirinktą")
    BtnSave := SettingsGui.Add("Button", "x380 y280 w90 h32", "Išsaugoti viską")
    BtnCancel := SettingsGui.Add("Button", "x480 y280 w90 h32", "Atšaukti")

    LV.OnEvent("ItemSelect", (*) => OnLVSelect(LV, EditKey, EditField))
    BtnUpdateRow.OnEvent("Click", (*) => OnUpdateRow(LV, EditKey, EditField))
    BtnAdd.OnEvent("Click", (*) => OnAddDir(LV, EditKey, EditField))
    BtnDel.OnEvent("Click", (*) => OnDelDir(LV))
    BtnSave.OnEvent("Click", (*) => OnSaveSettings(LV, EditKey, EditField))
    BtnCancel.OnEvent("Click", (*) => SettingsGui.Destroy())
    SettingsGui.OnEvent("Close", (*) => (SettingsGui := 0))

    SettingsGui.Show("w600 h325")
}

OnLVSelect(LV, EditKey, EditField) {
    row := LV.GetNext(0)
    if (row > 0) {
        EditKey.Value := LV.GetText(row, 2)
        EditField.Value := LV.GetText(row, 3)
    }
}

OnUpdateRow(LV, EditKey, EditField) {
    row := LV.GetNext(0)
    if (row > 0) {
        LV.Modify(row, "Col2", EditKey.Value)
        LV.Modify(row, "Col3", EditField.Value)
    } else {
        MsgBox("Pasirinkite lentelės eilutę, kurią norite atnaujinti.", "Informacija", "64")
    }
}

OnAddDir(LV, EditKey, EditField) {
    global TS_API_KEY, TS_FIELD_COUNT
    chosen := DirSelect("", 3, "Pasirinkite stebimą katalogą")
    if (chosen != "") {
        Loop LV.GetCount() {
            if (StrCompare(LV.GetText(A_Index, 1), chosen, true) = 0) {
                MsgBox("Šis katalogas jau yra sąraše!", "Informacija", "64")
                return
            }
        }
        k := (EditKey.Value != "") ? EditKey.Value : TS_API_KEY
        f := (EditField.Value != "") ? EditField.Value : TS_FIELD_COUNT
        LV.Add("", chosen, k, f)
        LV.ModifyCol(1, 260)
        LV.ModifyCol(2, 200)
        LV.ModifyCol(3, 100)
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

OnSaveSettings(LV, EditKey, EditField) {
    global Root_Katalogai, SettingsGui

    row := LV.GetNext(0)
    if (row > 0) {
        LV.Modify(row, "Col2", EditKey.Value)
        LV.Modify(row, "Col3", EditField.Value)
    }

    newDirs := []
    Loop LV.GetCount() {
        p := LV.GetText(A_Index, 1)
        k := LV.GetText(A_Index, 2)
        f := LV.GetText(A_Index, 3)
        if (p != "") {
            newDirs.Push({ path: p, apiKey: k, field: f })
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

    for _, item in Root_Katalogai {
        dir := item.path
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

    for _, item in Root_Katalogai {
        dir := item.path
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

                    TS_Send(diff, item.apiKey, item.field)
                }

                ScannedLogs[file] := cnt
            }
        }
    }

    UpdateOverlayValues()
}

UpdateOverlayValues() {
    global TotalText, NewText, DirTextCtrls, TotalCount, NewCount, Root_Katalogai, DirTotals

    if (!IsObject(OverlayGui))
        return

    TotalText.Value := "Viso: " TotalCount
    NewText.Value := "Nauji: " NewCount

    for _, item in Root_Katalogai {
        dir := item.path
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
TS_Send(value, apiKey := "", field := "") {
    global TS_API_KEY, TS_FIELD_COUNT, TS_ENDPOINT, TS_MIN_INTERVAL, TS_LAST_SEND

    keyToSend := (apiKey != "") ? apiKey : TS_API_KEY
    fieldToSend := (field != "") ? field : TS_FIELD_COUNT

    if (keyToSend = "")
        return

    tsKey := keyToSend "_" fieldToSend
    lastSend := TS_LAST_SEND.Has(tsKey) ? TS_LAST_SEND[tsKey] : 0

    if (A_TickCount - lastSend < TS_MIN_INTERVAL)
        return

    body := "api_key=" keyToSend "&" fieldToSend "=" value

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("POST", TS_ENDPOINT, false)
        req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        req.Send(body)
        if (req.Status = 200)
            TS_LAST_SEND[tsKey] := A_TickCount
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
    OverlayGui.AddText("x10 y" yPos " w" (Lango_Dydis - 20) " Center", "--- TERMOSTATAI ---")

    yPos += 20
    OverlayGui.SetFont("s10 bold cWhite", "Arial")
    for _, item in Root_Katalogai {
        dir := item.path
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

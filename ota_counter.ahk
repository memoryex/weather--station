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
    { path: "C:\Users\EoltUI\Desktop\WIFI ALTA 5.0", name: "WIFI ALTA 5.0", apiKey: TS_API_KEY, field: TS_FIELD_COUNT },
    { path: "C:\Users\EoltUI\Desktop\WIFI ALTA 5.0 FGT", name: "WIFI ALTA 5.0 FGT", apiKey: TS_API_KEY, field: TS_FIELD_COUNT },
    { path: "C:\Users\EoltUI\Desktop\EP4164_XLEEU_OTA_reprogram", name: "EP4164_XLEEU_OTA_reprogram", apiKey: TS_API_KEY, field: TS_FIELD_COUNT }
]

global Langas_Skaidrumas := 200
global Pagrindine_Spalva := 0x0055AA
global Lango_Dydis := 220

global Start_X := 300
global Start_Y := 800

global BtnWidth := 160
global BtnHeight := 38

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
    global Root_Katalogai, TS_API_KEY, TS_FIELD_COUNT, Start_X, Start_Y
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
                n := ""
                k := TS_API_KEY
                f := TS_FIELD_COUNT

                if (parts.Length >= 4) {
                    n := parts[2]
                    k := (parts[3] != "") ? parts[3] : TS_API_KEY
                    f := (parts[4] != "") ? parts[4] : TS_FIELD_COUNT
                } else if (parts.Length = 3) {
                    k := (parts[2] != "") ? parts[2] : TS_API_KEY
                    f := (parts[3] != "") ? parts[3] : TS_FIELD_COUNT
                } else if (parts.Length = 2) {
                    n := parts[2]
                }

                if (p != "") {
                    loaded.Push({ path: p, name: n, apiKey: k, field: f })
                }
            }
            if (loaded.Length > 0) {
                Root_Katalogai := loaded
            }
        }

        xVal := IniRead(iniPath, "Settings", "Start_X", "")
        if (xVal != "" && IsNumber(xVal))
            Start_X := Integer(xVal)

        yVal := IniRead(iniPath, "Settings", "Start_Y", "")
        if (yVal != "" && IsNumber(yVal))
            Start_Y := Integer(yVal)
    }
}

SaveConfig() {
    global Root_Katalogai, Start_X, Start_Y
    iniPath := A_ScriptDir "\settings.ini"

    str := ""
    for i, item in Root_Katalogai {
        str .= (i = 1 ? "" : "||") . item.path . "|" . item.name . "|" . item.apiKey . "|" . item.field
    }

    try {
        IniWrite(str, iniPath, "Settings", "Root_Katalogai")
        IniWrite(Start_X, iniPath, "Settings", "Start_X")
        IniWrite(Start_Y, iniPath, "Settings", "Start_Y")
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

GetDirDisplayName(item) {
    global Root_Katalogai

    p := IsObject(item) ? item.path : item
    n := (IsObject(item) && item.HasOwnProp("name")) ? item.name : ""

    if (n != "")
        return n

    SplitPath(p, &outName, &outDir)
    if (outName = "")
        return p

    dupCount := 0
    for _, it in Root_Katalogai {
        pathToCheck := IsObject(it) ? it.path : it
        SplitPath(pathToCheck, &fn)
        if (fn = outName)
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
    global SettingsGui, Root_Katalogai, TS_API_KEY, TS_FIELD_COUNT, Start_X, Start_Y

    SettingsGui := Gui("+AlwaysOnTop +ToolWindow", "Katalogų / Termostatų nustatymai")
    SettingsGui.SetFont("s9", "Segoe UI")

    SettingsGui.AddText("x10 y10 w680", "Stebimi katalogai (Termostatai), pavadinimai ir ThingSpeak nustatymai:")

    LV := SettingsGui.Add("ListView", "x10 y32 w680 h160 -Multi Grid", ["Katalogas", "Pavadinimas", "API Raktas (Write Key)", "Laukas"])
    for _, item in Root_Katalogai {
        LV.Add("", item.path, item.name, item.apiKey, item.field)
    }
    LV.ModifyCol(1, 240)
    LV.ModifyCol(2, 160)
    LV.ModifyCol(3, 180)
    LV.ModifyCol(4, 80)

    SettingsGui.AddGroupBox("x10 y200 w680 h70", "Pasirinkto įrašo nustatymai")

    SettingsGui.AddText("x20 y222 w160", "Pavadinimas (Rodyti kaip):")
    EditName := SettingsGui.Add("Edit", "x20 y240 w160 h24", "")

    SettingsGui.AddText("x190 y222 w200", "API Raktas (Write Key):")
    EditKey := SettingsGui.Add("Edit", "x190 y240 w200 h24", TS_API_KEY)

    SettingsGui.AddText("x400 y222 w100", "Laukas:")
    EditField := SettingsGui.Add("Edit", "x400 y240 w100 h24", TS_FIELD_COUNT)

    BtnUpdateRow := SettingsGui.Add("Button", "x510 y240 w160 h24", "Išsaugoti eilutę")

    SettingsGui.AddGroupBox("x10 y280 w680 h55", "Lango pozicija ekrane (Kordinatės)")
    SettingsGui.AddText("x20 y302 w80", "Pozicija X:")
    EditX := SettingsGui.Add("Edit", "x100 y300 w80 h24 Number", Start_X)

    SettingsGui.AddText("x200 y302 w80", "Pozicija Y:")
    EditY := SettingsGui.Add("Edit", "x280 y300 w80 h24 Number", Start_Y)

    BtnAdd := SettingsGui.Add("Button", "x10 y345 w150 h32", "Pridėti katalogą")
    BtnDel := SettingsGui.Add("Button", "x170 y345 w150 h32", "Pašalinti pasirinktą")
    BtnSave := SettingsGui.Add("Button", "x470 y345 w100 h32", "Išsaugoti viską")
    BtnCancel := SettingsGui.Add("Button", "x580 y345 w100 h32", "Atšaukti")

    LV.OnEvent("ItemSelect", (*) => OnLVSelect(LV, EditName, EditKey, EditField))
    BtnUpdateRow.OnEvent("Click", (*) => OnUpdateRow(LV, EditName, EditKey, EditField))
    BtnAdd.OnEvent("Click", (*) => OnAddDir(LV, EditName, EditKey, EditField))
    BtnDel.OnEvent("Click", (*) => OnDelDir(LV))
    BtnSave.OnEvent("Click", (*) => OnSaveSettings(LV, EditName, EditKey, EditField, EditX, EditY))
    BtnCancel.OnEvent("Click", (*) => SettingsGui.Destroy())
    SettingsGui.OnEvent("Close", (*) => (SettingsGui := 0))

    SettingsGui.Show("w700 h390")
}

OnLVSelect(LV, EditName, EditKey, EditField) {
    row := LV.GetNext(0)
    if (row > 0) {
        EditName.Value := LV.GetText(row, 2)
        EditKey.Value := LV.GetText(row, 3)
        EditField.Value := LV.GetText(row, 4)
    }
}

OnUpdateRow(LV, EditName, EditKey, EditField) {
    row := LV.GetNext(0)
    if (row > 0) {
        LV.Modify(row, "Col2", EditName.Value)
        LV.Modify(row, "Col3", EditKey.Value)
        LV.Modify(row, "Col4", EditField.Value)
    } else {
        MsgBox("Pasirinkite lentelės eilutę, kurią norite atnaujinti.", "Informacija", "64")
    }
}

OnAddDir(LV, EditName, EditKey, EditField) {
    global TS_API_KEY, TS_FIELD_COUNT
    chosen := DirSelect("", 3, "Pasirinkite stebimą katalogą")
    if (chosen != "") {
        Loop LV.GetCount() {
            if (StrCompare(LV.GetText(A_Index, 1), chosen, true) = 0) {
                MsgBox("Šis katalogas jau yra sąraše!", "Informacija", "64")
                return
            }
        }
        SplitPath(chosen, &folderName)
        dispName := (EditName.Value != "") ? EditName.Value : folderName
        k := (EditKey.Value != "") ? EditKey.Value : TS_API_KEY
        f := (EditField.Value != "") ? EditField.Value : TS_FIELD_COUNT
        LV.Add("", chosen, dispName, k, f)
        LV.ModifyCol(1, 240)
        LV.ModifyCol(2, 160)
        LV.ModifyCol(3, 180)
        LV.ModifyCol(4, 80)
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

OnSaveSettings(LV, EditName, EditKey, EditField, EditX, EditY) {
    global Root_Katalogai, SettingsGui, Start_X, Start_Y

    row := LV.GetNext(0)
    if (row > 0) {
        LV.Modify(row, "Col2", EditName.Value)
        LV.Modify(row, "Col3", EditKey.Value)
        LV.Modify(row, "Col4", EditField.Value)
    }

    newDirs := []
    Loop LV.GetCount() {
        p := LV.GetText(A_Index, 1)
        n := LV.GetText(A_Index, 2)
        k := LV.GetText(A_Index, 3)
        f := LV.GetText(A_Index, 4)
        if (p != "") {
            newDirs.Push({ path: p, name: n, apiKey: k, field: f })
        }
    }

    if (newDirs.Length = 0) {
        MsgBox("Būtina pasirinkti bent vieną katalogą!", "Klaida", "48")
        return
    }

    if (EditX.Value != "" && IsNumber(EditX.Value))
        Start_X := Integer(EditX.Value)

    if (EditY.Value != "" && IsNumber(EditY.Value))
        Start_Y := Integer(EditY.Value)

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
            displayName := GetDirDisplayName(item)
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
        displayName := GetDirDisplayName(item)
        cnt := DirTotals.Has(dir) ? DirTotals[dir] : 0

        ctrl := OverlayGui.AddText("x10 y" yPos " w" (Lango_Dydis - 20) " Left", displayName ": " cnt)
        DirTextCtrls[dir] := ctrl
        yPos += 22
    }

    yPos += 10
    ahkVer := "v" . SubStr(A_AhkVersion, 1, 3)
    OverlayGui.SetFont("s8 cLightGray norm", "Arial")
    OverlayGui.AddText("x10 y" yPos " w" (Lango_Dydis - 20) " Right", ahkVer)
    yPos += 18

    yPos += 5
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
    BuildCtrlGui()
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

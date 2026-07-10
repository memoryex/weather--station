#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
Global CURRENT_VERSION := "5.4 (Advanced Settings)"
Global LOG_DIR := A_ScriptDir "\logs"
if !DirExist(LOG_DIR) {
    DirCreate(LOG_DIR)
}

; Configuration (Loaded from config.ini)
Global CONFIG_FILE := A_ScriptDir "\config.ini"
Global SERVER_LOG_FILE := "\\10.12.24.50\fgt_hal\AHK_log\logas.txt"
Global EXCEL_PATH := A_ScriptDir "\GD_Gamybos_Ataskaita.xlsx"
Global READ_KEYS := Map()

LoadConfig() {
    global SERVER_LOG_FILE, EXCEL_PATH, READ_KEYS
    if FileExist(CONFIG_FILE) {
        try {
            SERVER_LOG_FILE := IniRead(CONFIG_FILE, "Paths", "ServerLog", SERVER_LOG_FILE)
            EXCEL_PATH := IniRead(CONFIG_FILE, "Paths", "ExcelPath", EXCEL_PATH)
            for ch in ["463450", "703669", "802414", "807602"] {
                READ_KEYS[ch] := IniRead(CONFIG_FILE, "ThingSpeak", "Key_" ch, "")
            }
        }
    }
}
LoadConfig()

Global LINES := [
    {name: "PLXE 1",    channel: "463450", fieldCount: 1, fieldBarcode: 2, color: "C6EFCE", tab: "PLXE"},
    {name: "PLXE 2",    channel: "463450", fieldCount: 3, fieldBarcode: 4, color: "FFCCFF", tab: "PLXE"},
    {name: "PLXE 3",    channel: "463450", fieldCount: 5, fieldBarcode: 6, color: "FFCCFF", tab: "PLXE"},
    {name: "PLXE 4",    channel: "463450", fieldCount: 7, fieldBarcode: 8, color: "FFCCFF", tab: "PLXE"},
    {name: "PLXE 5",    channel: "802414", fieldCount: 7, fieldBarcode: 8, color: "C6EFCE", tab: "PLXE"},
    {name: "NOBO 1",    channel: "703669", fieldCount: 1, fieldBarcode: 2, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 2",    channel: "703669", fieldCount: 3, fieldBarcode: 4, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 3",    channel: "703669", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 4",    channel: "703669", fieldCount: 7, fieldBarcode: 8, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 5",    channel: "802414", fieldCount: 1, fieldBarcode: 2, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 6",    channel: "802414", fieldCount: 3, fieldBarcode: 4, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 7",    channel: "802414", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA", tab: "NOBO"},
    {name: "QRAD 1",    channel: "807602", fieldCount: 3, fieldBarcode: 4, color: "CCFFFF", tab: "Kiti"},
    {name: "XLE 1",     channel: "807602", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA", tab: "Kiti"},
    {name: "XLE ReWork",channel: "807602", fieldCount: 7, fieldBarcode: 8, color: "E2EFDA", tab: "Kiti"},
    {name: "UI perrašymas", channel: "807602", fieldCount: 1, fieldBarcode: 0, color: "E2EFDA", tab: "Kiti"}
]

Global INTERVALS := [
    ["06:00", "07:00"], ["07:00", "08:00"], ["08:00", "09:00"], ["09:10", "10:00"],
    ["10:00", "11:00"], ["11:30", "12:00"], ["12:00", "13:00"], ["13:00", "14:00"],
    ["14:10", "15:00"], ["15:00", "16:00"]
]

; =======================================================
; HELPERS
; =======================================================
GetNum(Value) {
    if IsNumber(Value) {
        return Value
    }
    strVal := String(Value)
    if (strVal == "") {
        return 0
    }
    clean := RegExReplace(strVal, "[^\d\.]")
    if (clean == "" || clean == ".") {
        return 0
    }
    try {
        return Number(clean)
    } catch {
        return 0
    }
}

; =======================================================
; GUI CONSTRUCTION
; =======================================================
Global MainGui := Gui("+Resize", "GD Gamybos Dashboard v" CURRENT_VERSION)
MainGui.SetFont("s9", "Segoe UI")

MainGui.Add("Text", "x10 y15", "Pasirinkite datą:")

; Previous Day Button
BtnPrev := MainGui.Add("Button", "x110 y10 w30 h24", "<")
OnPrevClick(*) {
    currentDate := Calendar.Value
    newDate := DateAdd(currentDate, -1, "Days")
    Calendar.Value := newDate
    LoadDateData()
}
BtnPrev.OnEvent("Click", OnPrevClick)

Global Calendar := MainGui.Add("DateTime", "x145 y10 w120", "yyyy-MM-dd")

; Next Day Button
BtnNext := MainGui.Add("Button", "x270 y10 w30 h24", ">")
OnNextClick(*) {
    currentDate := Calendar.Value
    newDate := DateAdd(currentDate, 1, "Days")
    Calendar.Value := newDate
    LoadDateData()
}
BtnNext.OnEvent("Click", OnNextClick)

OnCalendarChange(ctrl, *) {
    LoadDateData()
}
Calendar.OnEvent("Change", OnCalendarChange)

BtnRefresh := MainGui.Add("Button", "x310 y10 w100", "Atnaujinti")
OnRefreshClick(ctrl, *) {
    SyncLocalServer("down")
    LoadDateData(true)
    RefreshDataFromTS()
}
BtnRefresh.OnEvent("Click", OnRefreshClick)

BtnSaveAll := MainGui.Add("Button", "x420 y10 w120", "Saugoti viską")
OnSaveAllClick(ctrl, *) {
    SaveAndSync()
}
BtnSaveAll.OnEvent("Click", OnSaveAllClick)

BtnExport := MainGui.Add("Button", "x550 y10 w120", "Eksportuoti Excel")
OnExportClick(ctrl, *) {
    ExportToExcel()
}
BtnExport.OnEvent("Click", OnExportClick)

BtnSettings := MainGui.Add("Button", "x680 y10 w100", "Nustatymai")
OnSettingsClick(ctrl, *) {
    ShowSettings()
}
BtnSettings.OnEvent("Click", OnSettingsClick)

Global StatusText := MainGui.Add("Text", "x790 y15 w600", "Pasiruošęs")

Global Tabs := MainGui.Add("Tab3", "x10 y50 w1520 h35", ["PLXE", "NOBO", "Kiti"])

OnTabChange(ctrl, *) {
    global ActiveChild, ChildGuis, MainGui
    if (ActiveChild != "") {
        ChildGuis[ActiveChild].Hide()
    }
    MainGui.GetClientPos(,, &guiW, &guiH)
    if ChildGuis.Has(ctrl.Text) {
        ChildGuis[ctrl.Text].Show("x10 y85 w" (guiW - 20) " h" (guiH - 90))
        ActiveChild := ctrl.Text
        UpdateScrollBars(ChildGuis[ActiveChild])
    }
}
Tabs.OnEvent("Change", OnTabChange)

Global ChildGuis := Map()
Global ActiveChild := ""
Global Controls := Map()
Global TabFooters := Map()
Global CommHwnds := Map()

AddIntervalHeaders(TargetGui, YPos) {
    global INTERVALS
    TargetGui.SetFont("s9 bold")
    Loop INTERVALS.Length {
        X := 230 + (A_Index-1) * 95
        TargetGui.Add("Text", "x" X " y" YPos " w90 h20 Center", INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2])
    }
    X_V := 230 + INTERVALS.Length * 95
    TargetGui.Add("Text", "x" X_V " y" YPos " w90 h20 Center", "Viso")
    X_A := 230 + (INTERVALS.Length + 1) * 95
    TargetGui.Add("Text", "x" X_A " y" YPos " w120 h20 Center", "Vidurkis per val.")
    TargetGui.SetFont("s9 norm")
}

CreateLineGrid(TargetGui, LineObj, YPos) {
    global Controls, INTERVALS, CommHwnds
    name := LineObj.name

    TargetGui.SetFont("s10 bold")
    TargetGui.Add("Text", "x15 y" YPos " w100 h20", name)

    ; Activity Indicator
    cIndicator := TargetGui.Add("Progress", "x15 y" YPos+22 " w100 h10 BackgroundRed cRed", 0)

    TargetGui.SetFont("s9 bold")
    TargetGui.Add("Text", "x125 y" YPos " w95 h20", "Planas")
    TargetGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Faktas")
    TargetGui.Add("Text", "x125 y" YPos+46 " w95 h20", "Gaminys")
    TargetGui.Add("Text", "x125 y" YPos+69 " w95 h20", "Komentaras")
    TargetGui.SetFont("s9 norm")

    lineCtrls := []
    Loop INTERVALS.Length {
        idx := A_Index
        X := 230 + (idx-1) * 95

        cPlan := TargetGui.Add("Edit", "x" X " y" YPos " w90 h20 Center")
        cFact := TargetGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly")
        cProd := TargetGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center")
        cComm := TargetGui.Add("Edit", "x" X " y" YPos+69 " w90 h20 Center cRed")

        lineCtrls.Push({Plan: cPlan, Fact: cFact, Prod: cProd, Comm: cComm})
        CommHwnds[cComm.Hwnd] := cComm

        cPlan.OnEvent("LoseFocus", (ctrl, *) => (SaveManualInput(name, idx, "Plan", ctrl.Value), UpdateCalculations()))
        cProd.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Prod", ctrl.Value))
        cComm.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Comm", ctrl.Value))
    }

    X_Total := 230 + INTERVALS.Length * 95
    TargetGui.SetFont("s9 bold")
    cPlanTotal := TargetGui.Add("Edit", "x" X_Total " y" YPos " w90 h20 Center ReadOnly")
    cFactTotal := TargetGui.Add("Edit", "x" X_Total " y" YPos+23 " w90 h20 Center ReadOnly")
    X_Avg := X_Total + 95
    cPlanAvg := TargetGui.Add("Edit", "x" X_Avg " y" YPos " w90 h20 Center ReadOnly")
    cFactAvg := TargetGui.Add("Edit", "x" X_Avg " y" YPos+23 " w90 h20 Center ReadOnly")
    TargetGui.SetFont("s9 norm")

    Controls[name] := {intervals: lineCtrls, planTotal: cPlanTotal, planAvg: cPlanAvg, factTotal: cFactTotal, factAvg: cFactAvg, tab: LineObj.tab, indicator: cIndicator}
}

CreateTabFooter(TargetGui, TabName, YPos) {
    global TabFooters, INTERVALS
    fH := []
    pH := []
    pcH := []
    TargetGui.SetFont("s9 bold")
    TargetGui.Add("Text", "x125 y" YPos " w95 h20", "Faktas")
    TargetGui.Add("Text", "x15 y" YPos+23 " w100 h20", "Tikslas:")
    TargetGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Planas")

    Loop INTERVALS.Length {
        X := 230 + (A_Index-1) * 95
        fH.Push(TargetGui.Add("Edit", "x" X " y" YPos " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(TargetGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(TargetGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center ReadOnly +0x800 BackgroundWhite"))
    }
    TargetGui.Add("Text", "x1380 y" YPos-25 " w130 h20 Center", "Viso per dieną:")
    TargetGui.SetFont("s32 bold")
    cGrand := TargetGui.Add("Edit", "x1380 y" YPos-5 " w130 h80 Center ReadOnly Border")
    TargetGui.SetFont("s9 norm")
    TabFooters[TabName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGrand}
}

headerY := 5
contentStartY := 35
lineStep := 120
footerGap := 40
for tName in ["PLXE", "NOBO", "Kiti"] {
    cG := Gui("-Caption +Parent" MainGui.Hwnd " +0x00200000")
    cG.BackColor := "White"
    AddIntervalHeaders(cG, headerY)
    YPosGrid := contentStartY
    for line in LINES {
        if (line.tab == tName) {
            CreateLineGrid(cG, line, YPosGrid)
            YPosGrid += lineStep
        }
    }
    CreateTabFooter(cG, tName, YPosGrid + footerGap)
    ChildGuis[tName] := cG
}

OnMainSize(guiObj, minMax, width, height) {
    global ActiveChild, ChildGuis, Tabs
    if (minMax == -1) {
        return
    }
    Tabs.Move(,, width - 20)
    if (ActiveChild != "" && ChildGuis.Has(ActiveChild)) {
        ChildGuis[ActiveChild].Show("w" (width - 20) " h" (height - 90))
        UpdateScrollBars(ChildGuis[ActiveChild])
    }
}
MainGui.OnEvent("Size", OnMainSize)

MainGui.Show("w1540 h1040")
OnTabChange(Tabs)

OnScroll(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild == "" || !ChildGuis.Has(ActiveChild) || hwnd != ChildGuis[ActiveChild].Hwnd) {
        return
    }
    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0)
    NumPut("UInt", 0x17, si, 4)
    DllCall("GetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si)
    nPos := NumGet(si, 20, "Int")
    nMin := NumGet(si, 8, "Int")
    nMax := NumGet(si, 12, "Int")
    nPage := NumGet(si, 16, "UInt")
    action := wp & 0xFFFF
    if (action == 0) {
        newPos := nPos - 40
    } else if (action == 1) {
        newPos := nPos + 40
    } else if (action == 2) {
        newPos := nPos - nPage
    } else if (action == 3) {
        newPos := nPos + nPage
    } else if (action == 4 || action == 5) {
        newPos := wp >> 16
    } else {
        return
    }
    newPos := Max(nMin, Min(newPos, nMax - Integer(nPage)))
    if (newPos == nPos) {
        return
    }
    DllCall("ScrollWindowEx", "Ptr", hwnd, "Int", 0, "Int", nPos - newPos, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
    NumPut("Int", newPos, si, 20)
    DllCall("SetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si, "Int", 1)
    DllCall("UpdateWindow", "Ptr", hwnd)
}
OnMessage(0x0115, OnScroll)

OnWheel(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild == "" || !ChildGuis.Has(ActiveChild)) {
        return
    }
    delta := (wp >> 16) > 0x7FFF ? (wp >> 16) - 0x10000 : (wp >> 16)
    Loop Integer(Abs(delta) / 120) {
        SendMessage(0x0115, delta > 0 ? 0 : 1, 0, ChildGuis[ActiveChild].Hwnd)
    }
}
OnMessage(0x020A, OnWheel)

WM_MOUSEMOVE_Handler(wParam, lParam, msg, hwnd) {
    global CommHwnds
    static LastHwnd := 0
    if (hwnd == LastHwnd) {
        return
    }
    LastHwnd := hwnd
    try {
        if CommHwnds.Has(hwnd) {
            val := CommHwnds[hwnd].Value
            if (val != "") {
                ToolTip(val)
                SetTimer(CheckMousePosTimer, 100)
            } else {
                ToolTip()
            }
        } else {
            ToolTip()
        }
    } catch {
        ToolTip()
    }
}
OnMessage(0x0200, WM_MOUSEMOVE_Handler)

CheckMousePosTimer() {
    global CommHwnds
    MouseGetPos(,, &TargetHwnd, &ControlHwnd, 2)
    if (!CommHwnds.Has(ControlHwnd)) {
        ToolTip()
        SetTimer(CheckMousePosTimer, 0)
    }
}

UpdateCalculations() {
    global Controls, TabFooters, INTERVALS
    stats := Map()
    for t in ["PLXE", "NOBO", "Kiti"] {
        stats[t] := {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0}
    }

    for name, data in Controls {
        lineTotalFact := 0
        lineTotalPlan := 0
        activeFact := 0
        activePlan := 0
        for idx, int_obj in data.intervals {
            p := GetNum(int_obj.Plan.Value)
            f := GetNum(int_obj.Fact.Value)
            stats[data.tab].Plan[idx] += p
            stats[data.tab].Fact[idx] += f
            lineTotalPlan += p
            lineTotalFact += f
            if (f > 0) {
                activeFact++
            }
            if (p > 0) {
                activePlan++
            }
            if (p > 0) {
                int_obj.Plan.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
                int_obj.Fact.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
            } else {
                int_obj.Plan.Opt("BackgroundWhite")
                int_obj.Fact.Opt("BackgroundWhite")
            }
            int_obj.Plan.Redraw()
            int_obj.Fact.Redraw()
        }
        data.planTotal.Value := lineTotalPlan
        data.factTotal.Value := lineTotalFact
        stats[data.tab].Grand += lineTotalFact
        data.planAvg.Value := activePlan > 0 ? Round(lineTotalPlan / activePlan, 1) : 0
        data.factAvg.Value := activeFact > 0 ? Round(lineTotalFact / activeFact, 1) : 0
    }
    for t, d in stats {
        if TabFooters.Has(t) {
            f := TabFooters[t]
            Loop INTERVALS.Length {
                fv := d.Fact[A_Index]
                pv := d.Plan[A_Index]
                f.Fact[A_Index].Value := fv
                f.Plan[A_Index].Value := pv
                pct := pv > 0 ? Round((fv/pv-1)*100) : 0
                f.Pct[A_Index].Value := (pct > 0 ? "+" : "") pct "%"
            }
            f.Grand.Value := d.Grand
        }
    }
}

SyncLocalServer(mode) {
    global SERVER_LOG_FILE, LOG_DIR, StatusText
    try {
        if (mode == "down") {
            StatusText.Value := "Siunčiama iš serverio..."
            if !FileExist(SERVER_LOG_FILE) {
                StatusText.Value := "Serverio failas nerastas."
                return
            }
            content := FileRead(SERVER_LOG_FILE, "UTF-8")
            if (InStr(content, "[FILE:")) {
                fileCount := 0
                currentFile := ""
                fileBuffer := ""
                Loop Parse, content, "`n", "`r" {
                    line := Trim(A_LoopField, " `t")
                    if RegExMatch(line, "^\[FILE:(.+)\]$", &fm) {
                        if (currentFile != "") {
                            if FileExist(currentFile) {
                                FileDelete(currentFile)
                            }
                            FileAppend(RTrim(fileBuffer, "`n`r"), currentFile, "UTF-8")
                            fileCount++
                        }
                        currentFile := LOG_DIR "\" fm[1]
                        fileBuffer := ""
                    } else if (currentFile != "") {
                        fileBuffer .= A_LoopField "`r`n"
                    }
                }
                if (currentFile != "") {
                    if FileExist(currentFile) {
                        FileDelete(currentFile)
                    }
                    FileAppend(RTrim(fileBuffer, "`n`r"), currentFile, "UTF-8")
                    fileCount++
                }
                StatusText.Value := "Sinchronizuota (" fileCount " failai)."
            } else {
                StatusText.Value := "Serverio failas tuščias."
            }
        } else if (mode == "up") {
            StatusText.Value := "Siunčiama į serverį..."
            payload := ""
            fileCount := 0
            Loop Files, LOG_DIR "\*.ini" {
                payload .= "[FILE:" A_LoopFileName "]`n" FileRead(A_LoopFileFullPath) "`n"
                fileCount++
            }
            if (fileCount == 0) {
                StatusText.Value := "Nėra duomenų logs aplanke."
                return
            }
            if FileExist(SERVER_LOG_FILE) {
                FileDelete(SERVER_LOG_FILE)
            }
            FileAppend(payload, SERVER_LOG_FILE, "UTF-8")
            StatusText.Value := "Įkelta į serverį (" fileCount ")."
        }
    } catch Error as e {
        StatusText.Value := "Serverio klaida: " e.Message
    }
}

SaveAndSync() {
    SaveAll()
    SyncLocalServer("up")
}

FetchTSData(channel, start_dt, end_dt) {
    global READ_KEYS
    key := READ_KEYS.Has(channel) ? READ_KEYS[channel] : ""
    url := "https://api.thingspeak.com/channels/" channel "/feeds.json?api_key=" key "&start=" StrReplace(start_dt, " ", "T") "&end=" StrReplace(end_dt, " ", "T") "&timezone=Europe/Vilnius"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, true)
        req.Send()
        if (req.WaitForResponse(10)) {
            if (req.Status == 200) {
                return req.ResponseText
            }
        }
    } catch {
        ; Silent fail
    }
    return ""
}

ParseFeeds(jsonStr) {
    feeds := []
    pos := 1
    while pos := RegExMatch(jsonStr, '\{"created_at":"[^"]+"[^}]*\}', &match, pos) {
        objStr := match[0]
        obj := Map()
        if RegExMatch(objStr, '"created_at":"([^"]+)"', &m) {
            obj["created_at"] := m[1]
        }
        Loop 8 {
            fName := "field" A_Index
            if RegExMatch(objStr, '"' fName '":"?([^",}]*)"?', &m) {
                val := m[1]
                obj[fName] := (val == "null") ? "" : val
            } else {
                obj[fName] := ""
            }
        }
        feeds.Push(obj)
        pos += match.Len
    }
    return feeds
}

CalculateDelta(feeds, fieldName) {
    if (feeds.Length < 2) {
        return 0
    }
    vals := []
    for index, f in feeds {
        val := f.Has(fieldName) ? f[fieldName] : ""
        if (val != "" && val != "null") {
            try {
                vals.Push(Float(val))
            } catch {
                ; Ignore
            }
        }
    }
    if (vals.Length < 2) {
        return 0
    }
    total := 0
    Loop (vals.Length - 1) {
        diff := vals[A_Index + 1] - vals[A_Index]
        if (diff > 0) {
            total += diff
        }
    }
    return Integer(total)
}

GetLastVal(feeds, fieldName) {
    idx := feeds.Length
    while (idx > 0) {
        val := feeds[idx].Has(fieldName) ? feeds[idx][fieldName] : ""
        if (val != "" && val != "null") {
            return val
        }
        idx--
    }
    return ""
}

; Activity logic: Find timestamp of the very last counter increment
GetLastActivityTS(feeds, fieldName) {
    if (feeds.Length < 2) {
        return ""
    }
    idx := feeds.Length
    while (idx > 1) {
        currVal := GetNum(feeds[idx].Has(fieldName) ? feeds[idx][fieldName] : "")
        prevVal := GetNum(feeds[idx-1].Has(fieldName) ? feeds[idx-1][fieldName] : "")
        if (currVal > prevVal && currVal > 0) {
            return feeds[idx]["created_at"]
        }
        idx--
    }
    return ""
}

FilterFeedsByTime(feeds, startT, endT) {
    filtered := []
    s := StrReplace(StrReplace(StrReplace(startT, "-", ""), " ", ""), ":", "")
    e := StrReplace(StrReplace(StrReplace(endT, "-", ""), " ", ""), ":", "")
    for index, f in feeds {
        ft := StrReplace(StrReplace(StrReplace(SubStr(f["created_at"], 1, 19), "-", ""), "T", ""), ":", "")
        if (ft >= s && ft <= e) {
            filtered.Push(f)
        }
    }
    return filtered
}

LoadDateData(forceRefresh := false) {
    global Calendar, StatusText, Controls, INTERVALS, LOG_DIR
    dateStr := FormatTime(Calendar.Value, "yyyy-MM-dd")
    StatusText.Value := "Kraunama: " dateStr
    iniPath := LOG_DIR "\" dateStr ".ini"
    for name, data in Controls {
        Loop (INTERVALS.Length) {
            idx := A_Index
            int_obj := data.intervals[idx]
            int_obj.Plan.Value := IniRead(iniPath, name, "Plan_" idx, "")
            int_obj.Fact.Value := IniRead(iniPath, name, "Fact_" idx, "")
            int_obj.Prod.Value := IniRead(iniPath, name, "Prod_" idx, "")
            int_obj.Comm.Value := IniRead(iniPath, name, "Comm_" idx, "")
            if (int_obj.Prod.Value != "") {
                if (SubStr(int_obj.Prod.Value, 1, 2) == "X-" || int_obj.Prod.Value == "UI v5") {
                    int_obj.Prod.Opt("+ReadOnly")
                } else {
                    int_obj.Prod.Opt("-ReadOnly")
                }
            } else {
                int_obj.Prod.Opt("-ReadOnly")
            }
        }
    }
    UpdateCalculations()
    if (dateStr == FormatTime(A_Now, "yyyy-MM-dd") || !FileExist(iniPath) || forceRefresh) {
        RefreshDataFromTS(dateStr)
    }
}

RefreshDataFromTS(targetDate := "") {
    global Calendar, StatusText, LINES, INTERVALS, Controls
    tDate := (targetDate == "") ? FormatTime(Calendar.Value, "yyyy-MM-dd") : targetDate
    StatusText.Value := "Siunčiama iš ThingSpeak..."
    channels := Map()
    for l in LINES {
        if !channels.Has(l.channel) {
            channels[l.channel] := []
        }
        channels[l.channel].Push(l)
    }
    today := FormatTime(A_Now, "yyyy-MM-dd")
    nowT := FormatTime(A_Now, "HH:mm")
    nowFull := A_Now

    for ch, lines in channels {
        rawSelDate := StrReplace(tDate, "-", "")
        lookback := DateAdd(rawSelDate "000000", -3, "Days")
        startDT := FormatTime(lookback, "yyyy-MM-dd HH:mm:ss")
        endDT := tDate " 16:00:00"
        json := FetchTSData(ch, startDT, endDT)
        if (json == "") {
            continue
        }
        allF := ParseFeeds(json)
        for l in lines {
            ; Check Activity for Indicator
            lastAct := GetLastActivityTS(allF, "field" l.fieldCount)
            if (lastAct != "") {
                ; Parse ThingSpeak ISO 8601 to AHK YYYYMMDDHH24MISS
                ts := StrReplace(StrReplace(StrReplace(SubStr(lastAct, 1, 19), "-", ""), "T", ""), ":", "")
                diff := DateDiff(nowFull, ts, "Minutes")
                if (diff <= 30) {
                    Controls[l.name].indicator.Opt("BackgroundGreen cGreen")
                } else {
                    Controls[l.name].indicator.Opt("BackgroundRed cRed")
                }
            } else {
                Controls[l.name].indicator.Opt("BackgroundRed cRed")
            }

            Loop INTERVALS.Length {
                idx := A_Index
                int_v := INTERVALS[idx]
                if (tDate == today) {
                    if (StrCompare(int_v[1], nowT) > 0) {
                        continue
                    }
                }
                startTimeStr := tDate " " int_v[1] ":00"
                endTimeStr := tDate " " int_v[2] ":00"
                intF := FilterFeedsByTime(allF, startTimeStr, endTimeStr)
                prod := CalculateDelta(intF, "field" l.fieldCount)
                upToNowF := FilterFeedsByTime(allF, startDT, endTimeStr)
                barcode := (l.fieldBarcode) ? GetLastVal(upToNowF, "field" l.fieldBarcode) : ""
                ; UI perrašymas check
                if (l.channel == "807602" && l.fieldCount == 1) {
                    barcode := "UI v5"
                } else if (barcode != "") {
                    barcode := "X-" barcode
                }

                guiInt := Controls[l.name].intervals[idx]
                guiInt.Fact.Value := prod
                SaveToCache(tDate, l.name, idx, "Fact", prod)
                if (barcode != "") {
                    guiInt.Prod.Value := barcode
                    guiInt.Prod.Opt("+ReadOnly")
                    SaveToCache(tDate, l.name, idx, "Prod", barcode)
                } else {
                    guiInt.Prod.Opt("-ReadOnly")
                }
            }
        }
    }
    UpdateCalculations()
    StatusText.Value := "Užkrauta: " FormatTime(, "HH:mm:ss")
}

SaveToCache(date, line, idx, type, val) {
    IniWrite(val, LOG_DIR "\" date ".ini", line, type "_" idx)
}

SaveManualInput(line, idx, type, val) {
    global Calendar
    SaveToCache(FormatTime(Calendar.Value, "yyyy-MM-dd"), line, idx, type, val)
}

SaveAll() {
    global Calendar, Controls, INTERVALS
    d := FormatTime(Calendar.Value, "yyyy-MM-dd")
    for name, data in Controls {
        Loop (INTERVALS.Length) {
            int_obj := data.intervals[A_Index]
            SaveToCache(d, name, A_Index, "Plan", int_obj.Plan.Value)
            SaveToCache(d, name, A_Index, "Fact", int_obj.Fact.Value)
            SaveToCache(d, name, A_Index, "Prod", int_obj.Prod.Value)
            SaveToCache(d, name, A_Index, "Comm", int_obj.Comm.Value)
        }
    }
    SoundBeep(750, 100)
}

ShowSettings() {
    global CONFIG_FILE, SERVER_LOG_FILE, EXCEL_PATH, LINES
    SetGui := Gui("+AlwaysOnTop", "Programos nustatymai")
    SetGui.SetFont("s9", "Segoe UI")

    SetGui.Add("Text", "xm y+10", "Serverio logas (nuoroda):")
    servEdit := SetGui.Add("Edit", "w500", SERVER_LOG_FILE)
    SetGui.Add("Button", "x+5 w30", "...").OnEvent("Click", (*) => (f := FileSelect(3,, "Pasirinkite logas.txt"), f ? servEdit.Value := f : 0))

    SetGui.Add("Text", "xm y+15", "Excel ataskaitos failas:")
    excelEdit := SetGui.Add("Edit", "w500", EXCEL_PATH)
    SetGui.Add("Button", "x+5 w30", "...").OnEvent("Click", (*) => (f := FileSelect(3,, "Pasirinkite Excel failą"), f ? excelEdit.Value := f : 0))

    SetGui.Add("GroupBox", "xm y+20 w550 h250", "Excel laukelių kordinatės (Start Row/Col)")
    SetGui.Add("Text", "xp+10 yp+25", "Kiekvienai linijai nurodykite 'Row' ir 'Col' kur prasideda jos duomenys.")

    ; We'll use a small ListView or just a scrollable area for line mappings
    LV := SetGui.Add("ListView", "xp yp+30 w530 h180 Grid", ["Linija", "Excel Row", "Excel Col"])
    for l in LINES {
        r := IniRead(CONFIG_FILE, "Mapping", l.name "_Row", "2")
        c := IniRead(CONFIG_FILE, "Mapping", l.name "_Col", "1")
        LV.Add(, l.name, r, c)
    }
    LV.OnEvent("DoubleClick", EditLV)
    EditLV(ctrl, rowIdx) {
        if !rowIdx return
        lineName := LV.GetText(rowIdx, 1)
        currRow := LV.GetText(rowIdx, 2)
        currCol := LV.GetText(rowIdx, 3)

        prompt := Gui("+AlwaysOnTop", "Keisti kordinates: " lineName)
        prompt.Add("Text",, "Row:")
        eR := prompt.Add("Edit", "w50", currRow)
        prompt.Add("Text",, "Col:")
        eC := prompt.Add("Edit", "w50", currCol)
        prompt.Add("Button", "Default", "OK").OnEvent("Click", (*) => (LV.Modify(rowIdx,, lineName, eR.Value, eC.Value), prompt.Destroy()))
        prompt.Show()
    }

    saveBtn := SetGui.Add("Button", "xm y+20 w100", "Išsaugoti")
    saveBtn.OnEvent("Click", (*) {
        IniWrite(servEdit.Value, CONFIG_FILE, "Paths", "ServerLog")
        IniWrite(excelEdit.Value, CONFIG_FILE, "Paths", "ExcelPath")
        Loop LV.GetCount() {
            n := LV.GetText(A_Index, 1)
            r := LV.GetText(A_Index, 2)
            c := LV.GetText(A_Index, 3)
            IniWrite(r, CONFIG_FILE, "Mapping", n "_Row")
            IniWrite(c, CONFIG_FILE, "Mapping", n "_Col")
        }
        MsgBox("Nustatymai išsaugoti. Programa persikraus.")
        Reload()
    })
    SetGui.Show()
}

ExportToExcel() {
    global Calendar, Controls, INTERVALS, LINES, EXCEL_PATH, CONFIG_FILE
    date := FormatTime(Calendar.Value, "yyyy-MM-dd")
    sheetName := FormatTime(Calendar.Value, "MM.dd")
    StatusText.Value := "Eksportuojama..."

    if !FileExist(EXCEL_PATH) {
        MsgBox("Excel failas nerastas nurodytoje vietoje: " EXCEL_PATH)
        return
    }

    try {
        xl := ComObject("Excel.Application")
        xl.DisplayAlerts := false
        wb := xl.Workbooks.Open(EXCEL_PATH)

        ; Find or create sheet
        ws := 0
        try ws := wb.Sheets(sheetName)
        if !ws {
            ws := wb.Sheets.Add(,, 1)
            ws.Name := sheetName
        }

        for l in LINES {
            d := Controls[l.name]
            startRow := GetNum(IniRead(CONFIG_FILE, "Mapping", l.name "_Row", "2"))
            startCol := GetNum(IniRead(CONFIG_FILE, "Mapping", l.name "_Col", "1"))

            ; Map:
            ; Row: Name (Merged 4)
            ; Row: Planas
            ; Row+1: Faktas
            ; Row+2: Gaminys
            ; Row+3: Komentaras

            ws.Cells(startRow, startCol).Value := l.name
            ws.Range(ws.Cells(startRow, startCol), ws.Cells(startRow+3, startCol)).Merge()
            ws.Cells(startRow, startCol).Font.Bold := true

            ws.Cells(startRow, startCol+1).Value := l.name " Planas"
            Loop INTERVALS.Length {
                ws.Cells(startRow, startCol+1+A_Index).Value := d.intervals[A_Index].Plan.Value
            }

            ws.Cells(startRow+1, startCol+1).Value := l.name " Faktas"
            Loop INTERVALS.Length {
                ws.Cells(startRow+1, startCol+1+A_Index).Value := d.intervals[A_Index].Fact.Value
                ws.Cells(startRow+1, startCol+1+A_Index).Font.Color := 0x0000FF
            }

            ws.Cells(startRow+2, startCol+1).Value := "Gaminys"
            Loop INTERVALS.Length {
                ws.Cells(startRow+2, startCol+1+A_Index).Value := d.intervals[A_Index].Prod.Value
            }

            ws.Cells(startRow+3, startCol+1).Value := "Komentaras"
            Loop INTERVALS.Length {
                ws.Cells(startRow+3, startCol+1+A_Index).Value := d.intervals[A_Index].Comm.Value
            }
        }

        wb.Save()
        wb.Close()
        xl.Quit()
        StatusText.Value := "Baigta (Excel atnaujintas)."
    } catch Error as e {
        MsgBox("Excel klaida: " e.Message)
        StatusText.Value := "Klaida."
    }
}

UpdateScrollBars(GuiObj) {
    static SIF_ALL := 0x17
    global ChildGuis, LINES
    GuiObj.GetClientPos(,, &guiW, &guiH)
    numLines := 0
    for line in LINES {
        if (ChildGuis.Has(line.tab) && ChildGuis[line.tab].Hwnd == GuiObj.Hwnd) {
            numLines++
        }
    }
    contentH := 5 + (numLines * 120) + 40 + 100 + 50
    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0)
    NumPut("UInt", SIF_ALL, si, 4)
    DllCall("GetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si)
    currPos := NumGet(si, 20, "Int")
    NumPut("Int", 0, si, 8)
    NumPut("Int", contentH, si, 12)
    NumPut("UInt", guiH, si, 16)
    NumPut("Int", currPos, si, 20)
    DllCall("SetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si, "Int", 1)
}

StartupProc(*) {
    SyncLocalServer("down")
    LoadDateData()
}
SetTimer(StartupProc, -500)

RefreshTimerProc(*) {
    RefreshDataFromTS()
}
SetTimer(RefreshTimerProc, 300000)

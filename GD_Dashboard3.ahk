#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
Global CURRENT_VERSION := "6.1 (Final Stability Update)"
Global LOG_DIR := A_ScriptDir . "\logs"
if !DirExist(LOG_DIR) {
    DirCreate(LOG_DIR)
}

; Configuration File Path
Global CONFIG_FILE := A_ScriptDir . "\config.ini"

; Defaults
Global SERVER_LOG_FILE := "\\10.12.24.50\fgt_hal\AHK_log\logas.txt"
Global EXCEL_PATH := A_ScriptDir . "\GD_Gamybos_Ataskaita.xlsx"
Global READ_KEYS := Map()

; Load Configuration
LoadConfig() {
    global SERVER_LOG_FILE, EXCEL_PATH, READ_KEYS, CONFIG_FILE
    if FileExist(CONFIG_FILE) {
        try {
            SERVER_LOG_FILE := IniRead(CONFIG_FILE, "Paths", "ServerLog", SERVER_LOG_FILE)
            EXCEL_PATH := IniRead(CONFIG_FILE, "Paths", "ExcelPath", EXCEL_PATH)
            for ch in ["463450", "703669", "802414", "807602"] {
                val := IniRead(CONFIG_FILE, "ThingSpeak", "Key_" . ch, "")
                if (val != "") {
                    READ_KEYS[ch] := val
                }
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
    if IsNumber(Value)
        return Value
    strVal := String(Value)
    if (strVal == "")
        return 0
    clean := RegExReplace(strVal, "[^\d\.]")
    if (clean == "" || clean == ".")
        return 0
    try
        return Number(clean)
    catch
        return 0
}

; =======================================================
; GUI CONSTRUCTION
; =======================================================
Global MainGui := Gui("+Resize", "GD Dashboard v" . CURRENT_VERSION)
MainGui.SetFont("s9", "Segoe UI")

MainGui.Add("Text", "x10 y15", "Pasirinkite datą:")

GoPrevDay(*) {
    global Calendar
    Calendar.Value := DateAdd(Calendar.Value, -1, "Days")
    LoadDateData()
}
GoNextDay(*) {
    global Calendar
    Calendar.Value := DateAdd(Calendar.Value, 1, "Days")
    LoadDateData()
}

BtnPrev := MainGui.Add("Button", "x110 y10 w30 h24", "<")
BtnPrev.OnEvent("Click", GoPrevDay)

Global Calendar := MainGui.Add("DateTime", "x145 y10 w120", "yyyy-MM-dd")
HandleCalendarChange(*) {
    LoadDateData()
}
Calendar.OnEvent("Change", HandleCalendarChange)

BtnNext := MainGui.Add("Button", "x270 y10 w30 h24", ">")
BtnNext.OnEvent("Click", GoNextDay)

OnRefresh(*) {
    SyncLocalServer("down")
    LoadDateData(true)
}
BtnRefresh := MainGui.Add("Button", "x310 y10 w100", "Atnaujinti")
BtnRefresh.OnEvent("Click", OnRefresh)

OnSaveAll(*) {
    SaveAndSync()
}
BtnSaveAll := MainGui.Add("Button", "x420 y10 w120", "Saugoti viską")
BtnSaveAll.OnEvent("Click", OnSaveAll)

OnExport(*) {
    ExportToExcel()
}
BtnExport := MainGui.Add("Button", "x550 y10 w120", "Excel")
BtnExport.OnEvent("Click", OnExport)

OnSettings(*) {
    ShowSettings()
}
BtnSettings := MainGui.Add("Button", "x680 y10 w100", "Nustatymai")
BtnSettings.OnEvent("Click", OnSettings)

Global StatusText := MainGui.Add("Text", "x790 y15 w600", "Pasiruošęs")
Global Tabs := MainGui.Add("Tab3", "x10 y50 w1520 h35", ["PLXE", "NOBO", "Kiti"])

HandleTabChange(ctrl, *) {
    global ActiveChild, ChildGuis, MainGui
    if (ActiveChild != "") {
        ChildGuis[ActiveChild].Hide()
    }
    MainGui.GetClientPos(,, &guiW, &guiH)
    if ChildGuis.Has(ctrl.Text) {
        ChildGuis[ctrl.Text].Show("x10 y85 w" . (guiW - 20) . " h" . (guiH - 90))
        ActiveChild := ctrl.Text
        UpdateScrollBars(ChildGuis[ActiveChild])
    }
}
Tabs.OnEvent("Change", HandleTabChange)

Global ChildGuis := Map()
Global ActiveChild := ""
Global Controls := Map()
Global TabFooters := Map()
Global CommHwnds := Map()

AddIntervalHeaders(TargetGui, YPos) {
    global INTERVALS
    TargetGui.SetFont("s9 bold")
    Loop INTERVALS.Length {
        idx := A_Index
        X := 230 + (idx-1) * 95
        TargetGui.Add("Text", "x" . X . " y" . YPos . " w90 h20 Center", INTERVALS[idx][1] . "-" . INTERVALS[idx][2])
    }
    TargetGui.Add("Text", "x" . (230 + INTERVALS.Length * 95) . " y" . YPos . " w90 h20 Center", "Viso")
    TargetGui.Add("Text", "x" . (230 + (INTERVALS.Length + 1) * 95) . " y" . YPos . " w120 h20 Center", "Vidurkis/val.")
    TargetGui.SetFont("s9 norm")
}

CreateLineGrid(TargetGui, LineObj, YPos) {
    global Controls, INTERVALS, CommHwnds
    name := LineObj.name

    TargetGui.SetFont("s10 bold")
    TargetGui.Add("Text", "x15 y" . YPos . " w100 h20", name)
    cIndicator := TargetGui.Add("Progress", "x15 y" . YPos+22 . " w100 h10 BackgroundRed cRed", 0)

    TargetGui.SetFont("s9 bold")
    TargetGui.Add("Text", "x125 y" . YPos . " w95 h20", "Planas")
    TargetGui.Add("Text", "x125 y" . YPos+23 . " w95 h20", "Faktas")
    TargetGui.Add("Text", "x125 y" . YPos+46 . " w95 h20", "Gaminys")
    TargetGui.Add("Text", "x125 y" . YPos+69 . " w95 h20", "Komentaras")
    TargetGui.SetFont("s9 norm")

    lineCtrls := []
    Loop INTERVALS.Length {
        idx := A_Index
        X := 230 + (idx-1) * 95

        cPlan := TargetGui.Add("Edit", "x" . X . " y" . YPos . " w90 h20 Center")
        cFact := TargetGui.Add("Edit", "x" . X . " y" . YPos+23 . " w90 h20 Center ReadOnly")
        cProd := TargetGui.Add("Edit", "x" . X . " y" . YPos+46 . " w90 h20 Center")
        cComm := TargetGui.Add("Edit", "x" . X . " y" . YPos+69 . " w90 h20 Center cRed")

        lineCtrls.Push({Plan: cPlan, Fact: cFact, Prod: cProd, Comm: cComm})
        CommHwnds[cComm.Hwnd] := cComm

        cPlan.OnEvent("LoseFocus", OnFieldLoseFocus.Bind(name, idx, "Plan"))
        cProd.OnEvent("LoseFocus", OnFieldLoseFocus.Bind(name, idx, "Prod"))
        cComm.OnEvent("LoseFocus", OnFieldLoseFocus.Bind(name, idx, "Comm"))
    }

    XT := 230 + INTERVALS.Length * 95
    TargetGui.SetFont("s9 bold")
    cPlanTotal := TargetGui.Add("Edit", "x" . XT . " y" . YPos . " w90 h20 Center ReadOnly")
    cFactTotal := TargetGui.Add("Edit", "x" . XT . " y" . YPos+23 . " w90 h20 Center ReadOnly")
    XA := XT + 95
    cPlanAvg := TargetGui.Add("Edit", "x" . XA . " y" . YPos . " w90 h20 Center ReadOnly")
    cFactAvg := TargetGui.Add("Edit", "x" . XA . " y" . YPos+23 . " w90 h20 Center ReadOnly")
    TargetGui.SetFont("s9 norm")

    Controls[name] := {intervals: lineCtrls, planTotal: cPlanTotal, planAvg: cPlanAvg, factTotal: cFactTotal, factAvg: cFactAvg, tab: LineObj.tab, indicator: cIndicator}
}

OnFieldLoseFocus(lName, iIdx, iType, ctrl, *) {
    SaveManualInput(lName, iIdx, iType, ctrl.Value)
    if (iType = "Plan")
        UpdateCalculations()
}

CreateTabFooter(TargetGui, TabName, YPos) {
    global TabFooters, INTERVALS
    fH := [], pH := [], pcH := []
    TargetGui.SetFont("s9 bold")
    TargetGui.Add("Text", "x125 y" . YPos . " w95 h20", "Faktas")
    TargetGui.Add("Text", "x15 y" . YPos+23 . " w100 h20", "Tikslas:")
    TargetGui.Add("Text", "x125 y" . YPos+23 . " w95 h20", "Planas")
    Loop INTERVALS.Length {
        X := 230 + (A_Index-1) * 95
        fH.Push(TargetGui.Add("Edit", "x" . X . " y" . YPos . " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(TargetGui.Add("Edit", "x" . X . " y" . YPos+23 . " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(TargetGui.Add("Edit", "x" . X . " y" . YPos+46 . " w90 h20 Center ReadOnly +0x800 BackgroundWhite"))
    }
    TargetGui.Add("Text", "x1380 y" . YPos-25 . " w130 h20 Center", "Viso:")
    TargetGui.SetFont("s32 bold")
    cGrand := TargetGui.Add("Edit", "x1380 y" . YPos-5 . " w130 h80 Center ReadOnly Border")
    TargetGui.SetFont("s9 norm")
    TabFooters[TabName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGrand}
}

for tName in ["PLXE", "NOBO", "Kiti"] {
    cG := Gui("-Caption +Parent" . MainGui.Hwnd . " +0x00200000")
    cG.BackColor := "White"
    AddIntervalHeaders(cG, 5)
    Y := 35
    for line in LINES {
        if (line.tab == tName) {
            CreateLineGrid(cG, line, Y)
            Y += 120
        }
    }
    CreateTabFooter(cG, tName, Y + 40)
    ChildGuis[tName] := cG
}

OnMainSize(guiObj, minMax, width, height) {
    global Tabs, ActiveChild, ChildGuis
    if (minMax != -1) {
        Tabs.Move(,, width - 20)
        if (ActiveChild != "" && ChildGuis.Has(ActiveChild)) {
            ChildGuis[ActiveChild].Show("w" . (width - 20) . " h" . (height - 90))
            UpdateScrollBars(ChildGuis[ActiveChild])
        }
    }
}
MainGui.OnEvent("Size", OnMainSize)

MainGui.Show("w1540 h1040")
HandleTabChange(Tabs)

OnMessage(0x0115, OnScroll)
OnMessage(0x020A, OnWheel)

UpdateScrollBars(GuiObj) {
    static SIF_ALL := 0x17
    GuiObj.GetClientPos(,, &guiW, &guiH)
    numLines := 0
    for line in LINES
        if (ChildGuis.Has(line.tab) && ChildGuis[line.tab].Hwnd == GuiObj.Hwnd)
            numLines++
    contentH := 5 + (numLines * 120) + 40 + 100 + 50
    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0), NumPut("UInt", SIF_ALL, si, 4)
    DllCall("GetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si)
    currPos := NumGet(si, 20, "Int")
    NumPut("Int", 0, si, 8), NumPut("Int", contentH, si, 12), NumPut("UInt", guiH, si, 16), NumPut("Int", currPos, si, 20)
    DllCall("SetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si, "Int", 1)
}

OnScroll(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild == "" || hwnd != ChildGuis[ActiveChild].Hwnd)
        return
    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0), NumPut("UInt", 0x17, si, 4)
    DllCall("GetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si)
    nPos := NumGet(si, 20, "Int"), nMin := NumGet(si, 8, "Int"), nMax := NumGet(si, 12, "Int"), nPage := NumGet(si, 16, "UInt")
    action := wp & 0xFFFF
    if (action == 0) newPos := nPos - 40
    else if (action == 1) newPos := nPos + 40
    else if (action == 2) newPos := nPos - nPage
    else if (action == 3) newPos := nPos + nPage
    else if (action == 4 || action == 5) newPos := wp >> 16
    else return
    newPos := Max(nMin, Min(newPos, nMax - Integer(nPage)))
    if (newPos == nPos) return
    DllCall("ScrollWindowEx", "Ptr", hwnd, "Int", 0, "Int", nPos - newPos, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
    NumPut("Int", newPos, si, 20), DllCall("SetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si, "Int", 1), DllCall("UpdateWindow", "Ptr", hwnd)
}

OnWheel(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild == "") return
    delta := (wp >> 16) > 0x7FFF ? (wp >> 16) - 0x10000 : (wp >> 16)
    Loop Integer(Abs(delta) / 120)
        SendMessage(0x0115, delta > 0 ? 0 : 1, 0, ChildGuis[ActiveChild].Hwnd)
}

OnMessage(0x0200, WM_MOUSEMOVE)
WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    static LastHwnd := 0
    if (hwnd == LastHwnd) return
    LastHwnd := hwnd
    try {
        if CommHwnds.Has(hwnd) {
            val := CommHwnds[hwnd].Value
            if (val != "") ToolTip(val), SetTimer(CheckMousePos.Bind(hwnd), 100)
            else ToolTip()
        } else ToolTip()
    } catch ToolTip()
}

CheckMousePos(OriginalHwnd) {
    try {
        MouseGetPos(,, &TargetHwnd, &ControlHwnd, 2)
        if (TargetHwnd != OriginalHwnd && ControlHwnd != OriginalHwnd) ToolTip(), SetTimer(CheckMousePos.Bind(OriginalHwnd), 0)
        else if (CommHwnds.Has(OriginalHwnd)) ToolTip(CommHwnds[OriginalHwnd].Value)
    } catch {
        ToolTip(), SetTimer(CheckMousePos.Bind(OriginalHwnd), 0)
    }
}

UpdateCalculations() {
    global Controls, TabFooters, INTERVALS
    stats := Map()
    for t in ["PLXE", "NOBO", "Kiti"]
        stats[t] := {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0}

    for name, data in Controls {
        lTF := 0, lTP := 0, aF := 0, aP := 0
        for idx, int_obj in data.intervals {
            p := GetNum(int_obj.Plan.Value)
            f := GetNum(int_obj.Fact.Value)
            stats[data.tab].Plan[idx] += p
            stats[data.tab].Fact[idx] += f
            lTP += p
            lTF += f
            if (f > 0) aF++
            if (p > 0) aP++
            if (p > 0) {
                int_obj.Plan.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
                int_obj.Fact.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
            } else {
                int_obj.Plan.Opt("BackgroundWhite"), int_obj.Fact.Opt("BackgroundWhite")
            }
            int_obj.Plan.Redraw()
            int_obj.Fact.Redraw()
        }
        data.planTotal.Value := lTP
        data.factTotal.Value := lTF
        stats[data.tab].Grand += lTF
        data.planAvg.Value := aP > 0 ? Round(lTP / aP, 1) : 0
        data.factAvg.Value := aF > 0 ? Round(lTF / aF, 1) : 0
    }
    for t, d in stats {
        if TabFooters.Has(t) {
            f := TabFooters[t]
            Loop INTERVALS.Length {
                idx := A_Index
                fv := d.Fact[idx]
                pv := d.Plan[idx]
                f.Fact[idx].Value := fv
                f.Plan[idx].Value := pv
                pct := pv > 0 ? Round((fv/pv-1)*100) : 0
                f.Pct[idx].Value := (pct > 0 ? "+" : "") . pct . "%"
            }
            f.Grand.Value := d.Grand
        }
    }
}

SyncLocalServer(mode) {
    global SERVER_LOG_FILE, LOG_DIR, StatusText
    try {
        if (mode == "down") {
            if !FileExist(SERVER_LOG_FILE) return
            content := FileRead(SERVER_LOG_FILE, "UTF-8")
            if (InStr(content, "[FILE:")) {
                cF := "", fBuf := ""
                Loop Parse, content, "`n", "`r" {
                    line := Trim(A_LoopField, " `t")
                    if RegExMatch(line, "^\[FILE:(.+)\]$", &fm) {
                        if (cF != "") {
                            if FileExist(cF)
                                FileDelete(cF)
                            FileAppend(RTrim(fBuf, "`n`r"), cF, "UTF-8")
                        }
                        cF := LOG_DIR . "\" . fm[1]
                        fBuf := ""
                    } else if (cF != "") {
                        fBuf .= A_LoopField . "`r`n"
                    }
                }
                if (cF != "") {
                    if FileExist(cF)
                        FileDelete(cF)
                    FileAppend(RTrim(fBuf, "`n`r"), cF, "UTF-8")
                }
            }
        } else if (mode == "up") {
            pLoad := ""
            Loop Files, LOG_DIR . "\*.ini" {
                pLoad .= "[FILE:" . A_LoopFileName . "]`n" . FileRead(A_LoopFileFullPath) . "`n"
            }
            if (pLoad == "") return
            if FileExist(SERVER_LOG_FILE)
                FileDelete(SERVER_LOG_FILE)
            FileAppend(pLoad, SERVER_LOG_FILE, "UTF-8")
        }
    } catch Error as e {
        StatusText.Value := "Klaida: " . e.Message
    }
}

SaveAndSync() {
    SaveAll()
    SyncLocalServer("up")
}

FetchTSData(ch, start, end) {
    global READ_KEYS
    key := READ_KEYS.Has(ch) ? READ_KEYS[ch] : ""
    url := "https://api.thingspeak.com/channels/" . ch . "/feeds.json?api_key=" . key . "&start=" . StrReplace(start, " ", "T") . "&end=" . StrReplace(end, " ", "T") . "&timezone=Europe/Vilnius"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, true)
        req.Send()
        if (req.WaitForResponse(10)) {
            if (req.Status == 200) {
                return req.ResponseText
            }
        }
    }
    return ""
}

ParseFeeds(jStr) {
    feeds := [], pos := 1
    while pos := RegExMatch(jStr, '\{"created_at":"[^"]+"[^}]*\}', &m, pos) {
        objStr := m[0], obj := Map()
        if RegExMatch(objStr, '"created_at":"([^"]+)"', &mm)
            obj["created_at"] := mm[1]
        Loop 8 {
            fN := "field" . A_Index
            if RegExMatch(objStr, '"' . fN . '":"?([^",}]*)"?', &mm)
                obj[fN] := (mm[1] == "null") ? "" : mm[1]
            else obj[fN] := ""
        }
        feeds.Push(obj)
        pos += m.Len
    }
    return feeds
}

CalculateDelta(feeds, field) {
    if (feeds.Length < 2) return 0
    vals := []
    for f in feeds {
        v := f.Has(field) ? f[field] : ""
        if (v != "" && v != "null") {
            try {
                vals.Push(Float(v))
            }
        }
    }
    if (vals.Length < 2) return 0
    total := 0
    Loop (vals.Length - 1) {
        diff := vals[A_Index + 1] - vals[A_Index]
        if (diff > 0) total += diff
    }
    return Integer(total)
}

GetLastVal(feeds, field) {
    idx := feeds.Length
    while (idx > 0) {
        val := feeds[idx].Has(field) ? feeds[idx][field] : ""
        if (val != "" && val != "null") return val
        idx--
    }
    return ""
}

GetLastActivityTS(feeds, field) {
    if (feeds.Length < 2) return ""
    idx := feeds.Length
    while (idx > 1) {
        cv := GetNum(feeds[idx].Has(field) ? feeds[idx][field] : "")
        pv := GetNum(feeds[idx-1].Has(field) ? feeds[idx-1][field] : "")
        if (cv > pv && cv > 0) return feeds[idx]["created_at"]
        idx--
    }
    return ""
}

FilterFeedsByTime(feeds, sT, eT) {
    filtered := []
    s := StrReplace(StrReplace(StrReplace(sT, "-", ""), " ", ""), ":", "")
    e := StrReplace(StrReplace(StrReplace(eT, "-", ""), " ", ""), ":", "")
    for f in feeds {
        ft := StrReplace(StrReplace(StrReplace(SubStr(f["created_at"], 1, 19), "-", ""), "T", ""), ":", "")
        if (ft >= s && ft <= e) filtered.Push(f)
    }
    return filtered
}

LoadDateData(force := false) {
    global Calendar, LOG_DIR, Controls, INTERVALS
    dStr := FormatTime(Calendar.Value, "yyyy-MM-dd")
    iPath := LOG_DIR . "\" . dStr . ".ini"
    for name, data in Controls {
        Loop INTERVALS.Length {
            idx := A_Index
            io := data.intervals[idx]
            io.Plan.Value := IniRead(iPath, name, "Plan_" . idx, "")
            io.Fact.Value := IniRead(iPath, name, "Fact_" . idx, "")
            io.Prod.Value := IniRead(iPath, name, "Prod_" . idx, "")
            io.Comm.Value := IniRead(iPath, name, "Comm_" . idx, "")
            if (io.Prod.Value != "" && (SubStr(io.Prod.Value, 1, 2) == "X-" || io.Prod.Value == "UI v5"))
                io.Prod.Opt("+ReadOnly")
            else io.Prod.Opt("-ReadOnly")
        }
    }
    UpdateCalculations()
    if (dStr == FormatTime(A_Now, "yyyy-MM-dd") || !FileExist(iPath) || force)
        RefreshDataFromTS(dStr)
}

RefreshDataFromTS(target := "") {
    global Calendar, LINES, INTERVALS, Controls
    tD := (target == "") ? FormatTime(Calendar.Value, "yyyy-MM-dd") : target
    channels := Map()
    for l in LINES {
        if !channels.Has(l.channel)
            channels[l.channel] := []
        channels[l.channel].Push(l)
    }
    today := FormatTime(A_Now, "yyyy-MM-dd")
    nowT := FormatTime(A_Now, "HH:mm")
    nowF := A_Now
    for ch, lines in channels {
        lb := DateAdd(StrReplace(tD, "-", "") . "000000", -3, "Days")
        json := FetchTSData(ch, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), tD . " 16:00:00")
        if (json == "") continue
        allF := ParseFeeds(json)
        for l in lines {
            la := GetLastActivityTS(allF, "field" . l.fieldCount)
            if (la != "") {
                ts := StrReplace(StrReplace(StrReplace(SubStr(la, 1, 19), "-", ""), "T", ""), ":", "")
                if (DateDiff(nowF, ts, "Minutes") <= 30)
                    Controls[l.name].indicator.Opt("BackgroundGreen cGreen")
                else
                    Controls[l.name].indicator.Opt("BackgroundRed cRed")
            } else {
                Controls[l.name].indicator.Opt("BackgroundRed cRed")
            }
            for idx, iv in INTERVALS {
                if (tD == today && StrCompare(iv[1], nowT) > 0) continue
                startTimeStr := tD . " " . iv[1] . ":00"
                endTimeStr := tD . " " . iv[2] . ":00"
                intF := FilterFeedsByTime(allF, startTimeStr, endTimeStr)
                p := CalculateDelta(intF, "field" . l.fieldCount)

                b := ""
                if (l.fieldBarcode > 0) {
                    uF := FilterFeedsByTime(allF, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), endTimeStr)
                    b := GetLastVal(uF, "field" . l.fieldBarcode)
                }
                b := (l.name == "UI perrašymas") ? "UI v5" : (b != "" ? "X-" . b : "")

                gi := Controls[l.name].intervals[idx]
                gi.Fact.Value := p
                SaveToCache(tD, l.name, idx, "Fact", p)
                if (b != "") {
                    gi.Prod.Value := b
                    gi.Prod.Opt("+ReadOnly")
                    SaveToCache(tD, l.name, idx, "Prod", b)
                } else {
                    gi.Prod.Opt("-ReadOnly")
                }
            }
        }
    }
    UpdateCalculations()
}

SaveToCache(d, l, i, t, v) {
    IniWrite(v, LOG_DIR . "\" . d . ".ini", l, t . "_" . i)
}
SaveManualInput(l, i, t, v) {
    global Calendar
    SaveToCache(FormatTime(Calendar.Value, "yyyy-MM-dd"), l, i, t, v)
}

SaveAll() {
    global Calendar, Controls, INTERVALS
    d := FormatTime(Calendar.Value, "yyyy-MM-dd")
    for name, data in Controls {
        Loop INTERVALS.Length {
            idx := A_Index
            io := data.intervals[idx]
            SaveToCache(d, name, idx, "Plan", io.Plan.Value)
            SaveToCache(d, name, idx, "Fact", io.Fact.Value)
            SaveToCache(d, name, idx, "Prod", io.Prod.Value)
            SaveToCache(d, name, idx, "Comm", io.Comm.Value)
        }
    }
    SoundBeep(750, 100)
}

ShowSettings() {
    global CONFIG_FILE, SERVER_LOG_FILE, EXCEL_PATH, LINES
    SetGui := Gui("+AlwaysOnTop", "Programos nustatymai")
    SetGui.Add("Text", "xm", "Serverio logas:")
    sE := SetGui.Add("Edit", "w500", SERVER_LOG_FILE)
    btnLog := SetGui.Add("Button", "x+5", "...")
    btnLog.OnEvent("Click", (*) {
        f := FileSelect(3)
        if f
            sE.Value := f
    })

    SetGui.Add("Text", "xm", "Excel failas:")
    xE := SetGui.Add("Edit", "w500", EXCEL_PATH)
    btnExcel := SetGui.Add("Button", "x+5", "...")
    btnExcel.OnEvent("Click", (*) {
        f := FileSelect(3)
        if f
            xE.Value := f
    })
    LV := SetGui.Add("ListView", "xm w530 h180 Grid", ["Linija", "Row", "Col"])
    for l in LINES
        LV.Add(, l.name, IniRead(CONFIG_FILE, "Mapping", l.name . "_Row", "2"), IniRead(CONFIG_FILE, "Mapping", l.name . "_Col", "1"))

    HandleLVOk(p, r, c, rowIdx, *) {
        LV.Modify(rowIdx,, LV.GetText(rowIdx, 1), r.Value, c.Value)
        p.Destroy()
    }

    OnLVDoubleClick(ctrl, rowIdx) {
        if !rowIdx return
        p := Gui("+AlwaysOnTop", "Keisti koordinates")
        p.Add("Text",, "Eilutė (Row):")
        r := p.Add("Edit", "w50", LV.GetText(rowIdx, 2))
        p.Add("Text",, "Stulpelis (Col):")
        c := p.Add("Edit", "w50", LV.GetText(rowIdx, 3))
        btnOk := p.Add("Button", "Default", "Gerai")
        btnOk.OnEvent("Click", HandleLVOk.Bind(p, r, c, rowIdx))
        p.Show()
    }
    LV.OnEvent("DoubleClick", OnLVDoubleClick)

    SaveSettingsBtn(*) {
        IniWrite(sE.Value, CONFIG_FILE, "Paths", "ServerLog")
        IniWrite(xE.Value, CONFIG_FILE, "Paths", "ExcelPath")
        Loop LV.GetCount() {
            rowIdx := A_Index
            IniWrite(LV.GetText(rowIdx, 2), CONFIG_FILE, "Mapping", LV.GetText(rowIdx, 1) . "_Row")
            IniWrite(LV.GetText(rowIdx, 3), CONFIG_FILE, "Mapping", LV.GetText(rowIdx, 1) . "_Col")
        }
        Reload()
    }
    SetGui.Add("Button", "xm w100", "Išsaugoti").OnEvent("Click", SaveSettingsBtn)
    SetGui.Show()
}

ExportToExcel() {
    global Calendar, Controls, INTERVALS, LINES, EXCEL_PATH, CONFIG_FILE, StatusText
    sName := FormatTime(Calendar.Value, "MM.dd")
    if !FileExist(EXCEL_PATH) return MsgBox("Excel failas nerastas:`n" . EXCEL_PATH)

    StatusText.Value := "Jungiamasi prie Excel..."
    xl := ""
    try {
        xl := ComObjActive("Excel.Application")
    } catch {
        try {
            xl := ComObject("Excel.Application")
        } catch Error as e {
            return MsgBox("Nepavyko paleisti Excel programos:`n" . e.Message)
        }
    }

    retryCount := 0
    maxRetries := 3
    wb := ""

    while (retryCount < maxRetries) {
        try {
            xl.Visible := true
            xl.DisplayAlerts := false

            Loop xl.Workbooks.Count {
                if (xl.Workbooks.Item(A_Index).FullName = EXCEL_PATH) {
                    wb := xl.Workbooks.Item(A_Index)
                    break
                }
            }

            if !wb {
                wb := xl.Workbooks.Open(EXCEL_PATH)
            }
            break
        } catch Error as e {
            if (InStr(e.Message, "0x80010001") || InStr(e.Message, "rejected")) {
                retryCount++
                StatusText.Value := "Excel užimtas, bandymas " . retryCount . " iš " . maxRetries . "..."
                Sleep 2000
                continue
            }
            return MsgBox("Klaida atidarant Excel failą:`n" . e.Message . "`n`nJei failas atidarytas OneDrive, uždarykite jį.")
        }
    }

    if !wb return MsgBox("Nepavyko pasiekti Excel darbaknygės.")

    try {
        try ws := wb.Sheets(sName)
        catch {
            ws := wb.Sheets.Add(,, 1)
            ws.Name := sName
        }

        for l in LINES {
            d := Controls[l.name]
            rowStart := GetNum(IniRead(CONFIG_FILE, "Mapping", l.name . "_Row", "2"))
            colStart := GetNum(IniRead(CONFIG_FILE, "Mapping", l.name . "_Col", "1"))

            ws.Cells(rowStart, colStart).Value := l.name
            ws.Range(ws.Cells(rowStart, colStart), ws.Cells(rowStart+3, colStart)).Merge()
            ws.Cells(rowStart, colStart).Font.Bold := true
            ws.Cells(rowStart, colStart).HorizontalAlignment := -4108

            ws.Cells(rowStart,     colStart+1).Value := l.name . " Planas"
            ws.Cells(rowStart + 1, colStart+1).Value := l.name . " Faktas"
            ws.Cells(rowStart + 2, colStart+1).Value := "Gaminys"
            ws.Cells(rowStart + 3, colStart+1).Value := "Komentaras"

            Loop INTERVALS.Length {
                idx := A_Index
                ws.Cells(rowStart,     colStart+1+idx).Value := d.intervals[idx].Plan.Value
                ws.Cells(rowStart + 1, colStart+1+idx).Value := d.intervals[idx].Fact.Value
                ws.Cells(rowStart + 1, colStart+1+idx).Font.Color := 0x0000FF
                ws.Cells(rowStart + 2, colStart+1+idx).Value := d.intervals[idx].Prod.Value
                ws.Cells(rowStart + 3, colStart+1+idx).Value := d.intervals[idx].Comm.Value
            }
        }

        wb.Save()
        StatusText.Value := "Eksportas baigtas sėkmingai (" . sName . ")."
        SoundBeep(1000, 200)
    } catch Error as e {
        MsgBox("Klaida pildant Excel duomenis:`n" . e.Message)
    }
}

StartupProc(*) {
    SyncLocalServer("down")
    LoadDateData()
}

TimerRefresh(*) {
    RefreshDataFromTS()
}

SetTimer(StartupProc, -500)
SetTimer(TimerRefresh, 300000)

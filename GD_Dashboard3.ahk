#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; GLOBAL SETTINGS & ERROR HANDLING
; =======================================================
OnError(GlobalErrorHandler)
GlobalErrorHandler(exc, mode) {
    if (mode != "ExitApp") {
        MsgBox("Kritinė klaida!`n`n" . exc.Message . "`n`nEilutė: " . exc.Line . "`nFunkcija: " . exc.What, "Dashboard Error", 16)
        return true
    }
}

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
global CURRENT_VERSION := "15.1 (Stable)"
global LOG_DIR := A_ScriptDir . "\logs"
global CONFIG_FILE := A_ScriptDir . "\config.ini"
global SERVER_LOG_FILE := "\\10.12.24.50\fgt_hal\AHK_log\logas.txt"
global EXCEL_PATH := A_ScriptDir . "\GD_Gamybos_Ataskaita.xlsx"
global READ_KEYS := Map()

if !DirExist(LOG_DIR)
    DirCreate(LOG_DIR)

global LINES := [
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

global INTERVALS := [
    ["06:00", "07:00"], ["07:00", "08:00"], ["08:00", "09:00"], ["09:10", "10:00"],
    ["10:00", "11:00"], ["11:30", "12:00"], ["12:00", "13:00"], ["13:00", "14:00"],
    ["14:10", "15:00"], ["15:00", "16:00"]
]

; UI Component Holders
global MainGui := ""
global Calendar := ""
global StatusText := ""
global Tabs := ""
global ChildGuis := Map()
global ActiveChild := ""
global Controls := Map()
global TabFooters := Map()
global CommHwnds := Map()

; =======================================================
; HELPERS
; =======================================================

LoadConfig() {
    global SERVER_LOG_FILE, EXCEL_PATH, READ_KEYS, CONFIG_FILE
    if FileExist(CONFIG_FILE) {
        try {
            SERVER_LOG_FILE := IniRead(CONFIG_FILE, "Paths", "ServerLog", SERVER_LOG_FILE)
            EXCEL_PATH := IniRead(CONFIG_FILE, "Paths", "ExcelPath", EXCEL_PATH)
            for ch in ["463450", "703669", "802414", "807602"] {
                val := IniRead(CONFIG_FILE, "ThingSpeak", "Key_" . ch, "")
                if (val != "")
                    READ_KEYS[ch] := val
            }
        }
    }
}

GetNum(Value) {
    if IsNumber(Value)
        return Value
    strVal := String(Value)
    if (strVal = "")
        return 0
    clean := RegExReplace(strVal, "[^\d\.]")
    if (clean = "" || clean = ".")
        return 0
    try
        return Number(clean)
    catch
        return 0
}

; =======================================================
; BUSINESS LOGIC
; =======================================================

UpdateCalculations() {
    global Controls, TabFooters, INTERVALS
    stats := Map()
    for tName in ["PLXE", "NOBO", "Kiti"] {
        stats[tName] := {Fact: [0,0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0,0], Grand: 0}
    }

    for name, data in Controls {
        lFactT := 0, lPlanT := 0, lFactC := 0, lPlanC := 0
        for idx, io in data.intervals {
            pVal := GetNum(io.Plan.Value), fVal := GetNum(io.Fact.Value)
            stats[data.tab].Plan[idx] += pVal, stats[data.tab].Fact[idx] += fVal
            lPlanT += pVal, lFactT += fVal
            if (fVal > 0) lFactC++
            if (pVal > 0) lPlanC++
            if (pVal > 0) {
                clr := (fVal >= pVal) ? "Background90EE90" : "BackgroundFF7F7F"
                io.Plan.Opt(clr), io.Fact.Opt(clr)
            } else {
                io.Plan.Opt("BackgroundWhite"), io.Fact.Opt("BackgroundWhite")
            }
            io.Plan.Redraw(), io.Fact.Redraw()
        }
        data.planTotal.Value := lPlanT, data.factTotal.Value := lFactT, stats[data.tab].Grand += lFactT
        data.planAvg.Value := (lPlanC > 0) ? Round(lPlanT / lPlanC, 1) : 0
        data.factAvg.Value := (lFactC > 0) ? Round(lFactT / lFactC, 1) : 0
    }

    for tName, d in stats {
        if TabFooters.Has(tName) {
            f := TabFooters[tName]
            Loop INTERVALS.Length {
                i := A_Index
                fv := d.Fact[i], pv := d.Plan[i]
                f.Fact[i].Value := fv, f.Plan[i].Value := pv
                pct := (pv > 0) ? Round((fv/pv - 1) * 100) : 0
                f.Pct[i].Value := (pct > 0 ? "+" : "") . pct . "%"
            }
            f.Grand.Value := d.Grand
        }
    }
}

SyncLocalServer(mode) {
    global SERVER_LOG_FILE, LOG_DIR, StatusText
    try {
        if (mode = "down") {
            if !FileExist(SERVER_LOG_FILE) return
            content := FileRead(SERVER_LOG_FILE, "UTF-8")
            if InStr(content, "[FILE:") {
                curF := "", fBuf := ""
                Loop Parse, content, "`n", "`r" {
                    ln := Trim(A_LoopField, " `t")
                    if RegExMatch(ln, "^\[FILE:(.+)\]$", &fm) {
                        if (curF != "") {
                            if FileExist(curF) FileDelete(curF)
                            FileAppend(RTrim(fBuf, "`n`r"), curF, "UTF-8")
                        }
                        curF := LOG_DIR . "\" . fm[1], fBuf := ""
                    } else if (curF != "")
                        fBuf .= A_LoopField . "`r`n"
                }
                if (curF != "") {
                    if FileExist(curF) FileDelete(curF)
                    FileAppend(RTrim(fBuf, "`n`r"), curF, "UTF-8")
                }
            }
        } else if (mode = "up") {
            payload := ""
            Loop Files, LOG_DIR . "\*.ini"
                payload .= "[FILE:" . A_LoopFileName . "]`n" . FileRead(A_LoopFileFullPath) . "`n"
            if (payload = "") return
            if FileExist(SERVER_LOG_FILE) FileDelete(SERVER_LOG_FILE)
            FileAppend(payload, SERVER_LOG_FILE, "UTF-8")
        }
    } catch Error as e
        StatusText.Value := "Klaida: " . e.Message
}

SaveToCache(d, l, i, t, v) {
    global LOG_DIR
    IniWrite(v, LOG_DIR . "\" . d . ".ini", l, t . "_" . i)
}

SaveManualInput(l, i, t, v) {
    global Calendar
    dStr := FormatTime(Calendar.Value, "yyyy-MM-dd")
    SaveToCache(dStr, l, i, t, v)
}

SaveAndSync(*) {
    global Calendar, Controls, INTERVALS
    dStr := FormatTime(Calendar.Value, "yyyy-MM-dd")
    for name, data in Controls {
        Loop INTERVALS.Length {
            idx := A_Index, io := data.intervals[idx]
            SaveToCache(dStr, name, idx, "Plan", io.Plan.Value)
            SaveToCache(dStr, name, idx, "Fact", io.Fact.Value)
            SaveToCache(dStr, name, idx, "Prod", io.Prod.Value)
            SaveToCache(dStr, name, idx, "Comm", io.Comm.Value)
        }
    }
    SyncLocalServer("up")
    SoundBeep(750, 100)
}

; =======================================================
; DATA FETCHING (ThingSpeak)
; =======================================================

FetchTSData(ch, start, end) {
    global READ_KEYS
    key := READ_KEYS.Has(ch) ? READ_KEYS[ch] : ""
    url := "https://api.thingspeak.com/channels/" . ch . "/feeds.json?api_key=" . key . "&start=" . StrReplace(start, " ", "T") . "&end=" . StrReplace(end, " ", "T") . "&timezone=Europe/Vilnius"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, true), req.Send()
        if (req.WaitForResponse(10))
            if (req.Status = 200) return req.ResponseText
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
                obj[fN] := (mm[1] = "null") ? "" : mm[1]
            else obj[fN] := ""
        }
        feeds.Push(obj), pos += m.Len
    }
    return feeds
}

CalculateDelta(feeds, field) {
    if (feeds.Length < 2) return 0
    vals := []
    for f in feeds {
        v := f.Has(field) ? f[field] : ""
        if (v != "" && v != "null") {
            try vals.Push(Float(v))
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

RefreshDataFromTS(target := "") {
    global Calendar, LINES, INTERVALS, Controls, StatusText
    tD := (target = "") ? FormatTime(Calendar.Value, "yyyy-MM-dd") : target
    StatusText.Value := "Kraunama..."
    chMap := Map()
    for l in LINES {
        if !chMap.Has(l.channel) chMap[l.channel] := []
        chMap[l.channel].Push(l)
    }
    today := FormatTime(A_Now, "yyyy-MM-dd"), nowT := FormatTime(A_Now, "HH:mm"), nowF := A_Now
    for ch, lines in chMap {
        lb := DateAdd(StrReplace(tD, "-", "") . "000000", -3, "Days")
        json := FetchTSData(ch, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), tD . " 16:00:00")
        if (json = "") continue
        allF := ParseFeeds(json)
        for l in lines {
            la := GetLastActivityTS(allF, "field" . l.fieldCount)
            if (la != "") {
                ts := StrReplace(StrReplace(StrReplace(SubStr(la, 1, 19), "-", ""), "T", ""), ":", "")
                if (DateDiff(nowF, ts, "Minutes") <= 30)
                    Controls[l.name].indicator.Opt("BackgroundGreen cGreen")
                else Controls[l.name].indicator.Opt("BackgroundRed cRed")
            } else Controls[l.name].indicator.Opt("BackgroundRed cRed")
            for idx, iv in INTERVALS {
                if (tD = today && StrCompare(iv[1], nowT) > 0) continue
                stT := tD . " " . iv[1] . ":00", enT := tD . " " . iv[2] . ":00"
                intF := FilterFeedsByTime(allF, stT, enT), p := CalculateDelta(intF, "field" . l.fieldCount)
                b := ""
                if (l.fieldBarcode > 0) {
                    uF := FilterFeedsByTime(allF, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), enT)
                    b := GetLastVal(uF, "field" . l.fieldBarcode)
                }
                b := (l.name = "UI perrašymas") ? "UI v5" : (b != "" ? "X-" . b : "")
                gi := Controls[l.name].intervals[idx]
                gi.Fact.Value := p, SaveToCache(tD, l.name, idx, "Fact", p)
                if (b != "") {
                    gi.Prod.Value := b, gi.Prod.Opt("+ReadOnly"), SaveToCache(tD, l.name, idx, "Prod", b)
                } else gi.Prod.Opt("-ReadOnly")
            }
        }
    }
    UpdateCalculations(), StatusText.Value := "Atnaujinta: " . FormatTime(, "HH:mm:ss")
}

OnRefreshBtn(*) {
    RefreshDataFromTS()
}

LoadDateData(force := false) {
    global Calendar, LOG_DIR, Controls, INTERVALS
    dStr := FormatTime(Calendar.Value, "yyyy-MM-dd"), iPath := LOG_DIR . "\" . dStr . ".ini"
    for name, data in Controls {
        Loop INTERVALS.Length {
            idx := A_Index, io := data.intervals[idx]
            io.Plan.Value := IniRead(iPath, name, "Plan_" . idx, "")
            io.Fact.Value := IniRead(iPath, name, "Fact_" . idx, "")
            io.Prod.Value := IniRead(iPath, name, "Prod_" . idx, "")
            io.Comm.Value := IniRead(iPath, name, "Comm_" . idx, "")
            if (io.Prod.Value != "" && (SubStr(io.Prod.Value, 1, 2) = "X-" || io.Prod.Value = "UI v5"))
                io.Prod.Opt("+ReadOnly")
            else io.Prod.Opt("-ReadOnly")
        }
    }
    UpdateCalculations()
    if (dStr = FormatTime(A_Now, "yyyy-MM-dd") || !FileExist(iPath) || force)
        RefreshDataFromTS(dStr)
}

; =======================================================
; UI HANDLERS
; =======================================================

OnMainSize(guiObj, minMax, width, height) {
    global Tabs, ActiveChild, ChildGuis
    if (minMax = -1) return
    if IsObject(Tabs)
        Tabs.Move(,, width - 20)
    if (ActiveChild != "" && ChildGuis.Has(ActiveChild)) {
        ChildGuis[ActiveChild].Show("w" . (width - 20) . " h" . (height - 90))
        UpdateScrollBars(ChildGuis[ActiveChild])
    }
}

GoPrevDay(*) {
    global Calendar
    Calendar.Value := DateAdd(Calendar.Value, -1, "Days"), LoadDateData()
}

GoNextDay(*) {
    global Calendar
    Calendar.Value := DateAdd(Calendar.Value, 1, "Days"), LoadDateData()
}

HandleTabChange(ctrl, *) {
    global ActiveChild, ChildGuis, MainGui
    if (ActiveChild != "")
        ChildGuis[ActiveChild].Hide()
    MainGui.GetClientPos(,, &guiW, &guiH)
    if ChildGuis.Has(ctrl.Text) {
        ChildGuis[ctrl.Text].Show("x10 y85 w" . (guiW - 20) . " h" . (guiH - 90))
        ActiveChild := ctrl.Text, UpdateScrollBars(ChildGuis[ActiveChild])
    }
}

OnFieldLoseFocus(lName, iIdx, iType, ctrl, *) {
    SaveManualInput(lName, iIdx, iType, ctrl.Value)
    if (iType = "Plan") UpdateCalculations()
}

UpdateScrollBars(GuiObj) {
    static SIF_ALL := 0x17
    GuiObj.GetClientPos(,, &guiW, &guiH)
    numLines := 0
    for l in LINES
        if (ChildGuis.Has(l.tab) && ChildGuis[l.tab].Hwnd = GuiObj.Hwnd)
            numLines++
    contentH := 5 + (numLines * 120) + 40 + 100 + 50
    si := Buffer(28, 0), NumPut("UInt", 28, si, 0), NumPut("UInt", SIF_ALL, si, 4)
    DllCall("GetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si)
    currPos := NumGet(si, 20, "Int")
    NumPut("Int", 0, si, 8), NumPut("Int", contentH, si, 12), NumPut("UInt", guiH, si, 16), NumPut("Int", currPos, si, 20)
    DllCall("SetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si, "Int", 1)
}

OnScroll(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild = "" || hwnd != ChildGuis[ActiveChild].Hwnd) return
    si := Buffer(28, 0), NumPut("UInt", 28, si, 0), NumPut("UInt", 0x17, si, 4)
    DllCall("GetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si)
    nPos := NumGet(si, 20, "Int"), nMin := NumGet(si, 8, "Int"), nMax := NumGet(si, 12, "Int"), nPage := NumGet(si, 16, "UInt")
    action := wp & 0xFFFF
    if (action = 0) newPos := nPos - 40
    else if (action = 1) newPos := nPos + 40
    else if (action = 2) newPos := nPos - nPage
    else if (action = 3) newPos := nPos + nPage
    else if (action = 4 || action = 5) newPos := wp >> 16
    else return
    newPos := Max(nMin, Min(newPos, nMax - Integer(nPage)))
    if (newPos = nPos) return
    DllCall("ScrollWindowEx", "Ptr", hwnd, "Int", 0, "Int", nPos - newPos, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
    NumPut("Int", newPos, si, 20), DllCall("SetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si, "Int", 1), DllCall("UpdateWindow", "Ptr", hwnd)
}

OnWheel(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild = "") return
    delta := (wp >> 16) > 0x7FFF ? (wp >> 16) - 0x10000 : (wp >> 16)
    Loop Integer(Abs(delta) / 120)
        SendMessage(0x0115, delta > 0 ? 0 : 1, 0, ChildGuis[ActiveChild].Hwnd)
}

OnMouseMove(wParam, lParam, msg, hwnd) {
    global CommHwnds
    static LastH := 0
    if (hwnd = LastH) return
    LastH := hwnd
    try {
        if CommHwnds.Has(hwnd) {
            val := CommHwnds[hwnd].Value
            if (val != "") ToolTip(val), SetTimer(CheckMousePos.Bind(hwnd), 100)
            else ToolTip()
        } else ToolTip()
    } catch ToolTip()
}

CheckMousePos(OHwnd) {
    global CommHwnds
    try {
        MouseGetPos(,, &THwnd, &CHwnd, 2)
        if (THwnd != OHwnd && CHwnd != OHwnd) ToolTip(), SetTimer(CheckMousePos.Bind(OHwnd), 0)
        else if (CommHwnds.Has(OHwnd)) ToolTip(CommHwnds[OHwnd].Value)
    } catch ToolTip(), SetTimer(CheckMousePos.Bind(OHwnd), 0)
}

; =======================================================
; EXCEL & SETTINGS
; =======================================================

ExportToExcel(*) {
    global Calendar, Controls, INTERVALS, LINES, EXCEL_PATH, CONFIG_FILE, StatusText
    sN := FormatTime(Calendar.Value, "MM.dd")
    if !FileExist(EXCEL_PATH) return MsgBox("Failas nerastas")
    xl := ""
    try xl := ComObjActive("Excel.Application")
    catch try xl := ComObject("Excel.Application")
    if !xl return
    xl.Visible := true, xl.DisplayAlerts := false, wb := "", rC := 0
    while (rC < 3) {
        try {
            Loop xl.Workbooks.Count
                if (xl.Workbooks(A_Index).FullName = EXCEL_PATH) {
                    wb := xl.Workbooks(A_Index), break
                }
            if !wb wb := xl.Workbooks.Open(EXCEL_PATH)
            break
        } catch (rC++, Sleep(2000))
    }
    if !wb return
    try {
        try ws := wb.Sheets(sN)
        catch ws := (sh := wb.Sheets.Add(,, 1), sh.Name := sN, sh)
        for l in LINES {
            d := Controls[l.name], r := GetNum(IniRead(CONFIG_FILE, "Mapping", l.name . "_Row", "2")), c := GetNum(IniRead(CONFIG_FILE, "Mapping", l.name . "_Col", "1"))
            ws.Cells(r, c).Value := l.name, ws.Range(ws.Cells(r, c), ws.Cells(r+3, c)).Merge(), ws.Cells(r, c).Font.Bold := true, ws.Cells(r, c).HorizontalAlignment := -4108
            ws.Cells(r, c+1).Value := l.name . " Planas", ws.Cells(r+1, c+1).Value := l.name . " Faktas", ws.Cells(r+2, c+1).Value := "Gaminys", ws.Cells(r+3, c+1).Value := "Komentaras"
            Loop INTERVALS.Length {
                i := A_Index, ws.Cells(r, c+1+i).Value := d.intervals[i].Plan.Value, ws.Cells(r+1, c+1+i).Value := d.intervals[i].Fact.Value, ws.Cells(r+1, c+1+i).Font.Color := 0x0000FF, ws.Cells(r+2, c+1+i).Value := d.intervals[i].Prod.Value, ws.Cells(r+3, c+1+i).Value := d.intervals[i].Comm.Value
            }
        }
        wb.Save(), StatusText.Value := "Baigta."
    } catch Error as e
        MsgBox("Excel klaida: " . e.Message)
}

ShowSettings(*) {
    global CONFIG_FILE, SERVER_LOG_FILE, EXCEL_PATH, LINES
    SGui := Gui("+AlwaysOnTop", "Nustatymai")
    SGui.Add("Text", "xm", "Log:"), eL := SGui.Add("Edit", "w500", SERVER_LOG_FILE), SGui.Add("Button", "x+5", "...").OnEvent("Click", SelectLog)
    SelectLog(*) {
        f := FileSelect(3)
        if f eL.Value := f
    }
    SGui.Add("Text", "xm", "Excel:"), eE := SGui.Add("Edit", "w500", EXCEL_PATH), SGui.Add("Button", "x+5", "...").OnEvent("Click", SelectExcel)
    SelectExcel(*) {
        f := FileSelect(3)
        if f eE.Value := f
    }
    LV := SGui.Add("ListView", "xm w530 h180 Grid", ["Linija", "Row", "Col"])
    for l in LINES
        LV.Add(, l.name, IniRead(CONFIG_FILE, "Mapping", l.name . "_Row", "2"), IniRead(CONFIG_FILE, "Mapping", l.name . "_Col", "1"))

    LV.OnEvent("DoubleClick", (ctrl, rowIdx) {
        if !rowIdx return
        p := Gui("+AlwaysOnTop", "Keisti"), p.Add("Text",, "Row:"), r := p.Add("Edit", "w50", LV.GetText(rowIdx, 2)), p.Add("Text",, "Col:"), c := p.Add("Edit", "w50", LV.GetText(rowIdx, 3))
        p.Add("Button", "Default", "OK").OnEvent("Click", (*) {
            LV.Modify(rowIdx,, LV.GetText(rowIdx, 1), r.Value, c.Value)
            p.Destroy()
        })
        p.Show()
    })

    SGui.Add("Button", "xm w100", "Išsaugoti").OnEvent("Click", (*) {
        IniWrite(eL.Value, CONFIG_FILE, "Paths", "ServerLog"), IniWrite(eE.Value, CONFIG_FILE, "Paths", "ExcelPath")
        Loop LV.GetCount() {
            i := A_Index
            IniWrite(LV.GetText(i, 2), CONFIG_FILE, "Mapping", LV.GetText(i, 1) . "_Row")
            IniWrite(LV.GetText(i, 3), CONFIG_FILE, "Mapping", LV.GetText(i, 1) . "_Col")
        }
        Reload()
    })
    SGui.Show()
}

; =======================================================
; MAIN EXECUTION
; =======================================================
LoadConfig()

MainGui := Gui("+Resize", "GD Dashboard v" . CURRENT_VERSION)
MainGui.SetFont("s9", "Segoe UI")
MainGui.OnEvent("Size", OnMainSize)
MainGui.OnEvent("Close", (*) => ExitApp())

MainGui.Add("Text", "x10 y15", "Data:")
BtnPrev := MainGui.Add("Button", "x50 y10 w30 h24", "<")
BtnPrev.OnEvent("Click", GoPrevDay)

Calendar := MainGui.Add("DateTime", "x85 y10 w120", "yyyy-MM-dd")
Calendar.OnEvent("Change", (*) => LoadDateData())

BtnNext := MainGui.Add("Button", "x210 y10 w30 h24", ">")
BtnNext.OnEvent("Click", GoNextDay)

MainGui.Add("Button", "x250 y10 w100", "Atnaujinti").OnEvent("Click", OnRefreshBtn)
MainGui.Add("Button", "x360 y10 w120", "Saugoti").OnEvent("Click", SaveAndSync)
MainGui.Add("Button", "x490 y10 w100", "Excel").OnEvent("Click", ExportToExcel)
MainGui.Add("Button", "x600 y10 w100", "Nustatymai").OnEvent("Click", ShowSettings)

StatusText := MainGui.Add("Text", "x710 y15 w600", "Kraunama...")
Tabs := MainGui.Add("Tab3", "x10 y50 w1520 h35", ["PLXE", "NOBO", "Kiti"])
Tabs.OnEvent("Change", HandleTabChange)

for tName in ["PLXE", "NOBO", "Kiti"] {
    cG := Gui("-Caption +Parent" . MainGui.Hwnd . " +0x00200000")
    cG.BackColor := "White"

    ; Header labels
    cG.SetFont("s9 bold")
    Loop INTERVALS.Length {
        idx := A_Index, X := 230 + (idx-1) * 95
        cG.Add("Text", "x" . X . " y5 w90 h20 Center", INTERVALS[idx][1] . "-" . INTERVALS[idx][2])
    }
    cG.Add("Text", "x" . (230 + INTERVALS.Length * 95) . " y5 w90 h20 Center", "Viso")
    cG.Add("Text", "x" . (230 + (INTERVALS.Length + 1) * 95) . " y5 w120 h20 Center", "Vidurkis")
    cG.SetFont("s9 norm")

    curY := 35
    for l in LINES {
        if (l.tab = tName) {
            name := l.name
            cG.SetFont("s10 bold")
            cG.Add("Text", "x15 y" . curY . " w100 h20", name)
            cInd := cG.Add("Progress", "x15 y" . curY+22 . " w100 h10 BackgroundRed cRed", 0)
            cG.SetFont("s9 bold")
            cG.Add("Text", "x125 y" . curY . " w95 h20", "Planas")
            cG.Add("Text", "x125 y" . curY+23 . " w95 h20", "Faktas")
            cG.Add("Text", "x125 y" . curY+46 . " w95 h20", "Gaminys")
            cG.Add("Text", "x125 y" . curY+69 . " w95 h20", "Komentaras")
            cG.SetFont("s9 norm")

            lineCtrls := []
            Loop INTERVALS.Length {
                idx := A_Index, X := 230 + (idx-1) * 95
                cP := cG.Add("Edit", "x" . X . " y" . curY . " w90 h20 Center")
                cF := cG.Add("Edit", "x" . X . " y" . curY+23 . " w90 h20 Center ReadOnly")
                cPr := cG.Add("Edit", "x" . X . " y" . curY+46 . " w90 h20 Center")
                cCm := cG.Add("Edit", "x" . X . " y" . curY+69 . " w90 h20 Center cRed")
                lineCtrls.Push({Plan: cP, Fact: cF, Prod: cPr, Comm: cCm})
                CommHwnds[cCm.Hwnd] := cCm
                cP.OnEvent("LoseFocus", OnFieldLoseFocus.Bind(name, idx, "Plan"))
                cPr.OnEvent("LoseFocus", OnFieldLoseFocus.Bind(name, idx, "Prod"))
                cCm.OnEvent("LoseFocus", OnFieldLoseFocus.Bind(name, idx, "Comm"))
            }
            XT := 230 + INTERVALS.Length * 95
            cG.SetFont("s9 bold")
            cPT := cG.Add("Edit", "x" . XT . " y" . curY . " w90 h20 Center ReadOnly")
            cFT := cG.Add("Edit", "x" . XT . " y" . curY+23 . " w90 h20 Center ReadOnly")
            XA := XT + 95
            cPA := cG.Add("Edit", "x" . XA . " y" . curY . " w90 h20 Center ReadOnly")
            cFA := cG.Add("Edit", "x" . XA . " y" . curY+23 . " w90 h20 Center ReadOnly")
            cG.SetFont("s9 norm")
            Controls[name] := {intervals: lineCtrls, planTotal: cPT, planAvg: cPA, factTotal: cFT, factAvg: cFA, tab: l.tab, indicator: cInd}
            curY += 120
        }
    }

    fH := [], pH := [], pcH := []
    footerY := curY + 40
    cG.SetFont("s9 bold")
    cG.Add("Text", "x125 y" . footerY . " w95 h20", "Faktas")
    cG.Add("Text", "x15 y" . footerY+23 . " w100 h20", "Tikslas:")
    cG.Add("Text", "x125 y" . footerY+23 . " w95 h20", "Planas")
    Loop INTERVALS.Length {
        idx := A_Index, X := 230 + (idx-1) * 95
        fH.Push(cG.Add("Edit", "x" . X . " y" . footerY . " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(cG.Add("Edit", "x" . X . " y" . footerY+23 . " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(cG.Add("Edit", "x" . X . " y" . footerY+46 . " w90 h20 Center ReadOnly +0x800 BackgroundWhite"))
    }
    cG.Add("Text", "x1380 y" . footerY-25 . " w130 h20 Center", "Viso:")
    cG.SetFont("s32 bold")
    cGr := cG.Add("Edit", "x1380 y" . footerY-5 . " w130 h80 Center ReadOnly Border")
    cG.SetFont("s9 norm")
    TabFooters[tName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGr}
    ChildGuis[tName] := cG
}

MainGui.Show("w1540 h1040")
HandleTabChange(Tabs)

OnMessage(0x0115, OnScroll)
OnMessage(0x020A, OnWheel)
OnMessage(0x0200, OnMouseMove)

StartupProcess(*) {
    SyncLocalServer("down"), LoadDateData()
}
SetTimer(StartupProcess, -500)
SetTimer(() => RefreshDataFromTS(), 300000)

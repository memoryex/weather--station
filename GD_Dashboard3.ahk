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
global CURRENT_VERSION := "1.1(beta)"
global LOG_DIR := A_ScriptDir . "\logs"
global CONFIG_FILE := A_ScriptDir . "\config.ini"
global SERVER_LOG_FILE := "\\10.12.24.50\fgt_hal\AHK_log\logas.txt"
global EXCEL_PATH := A_ScriptDir . "\GD_Gamybos_Ataskaita.xlsx"
global READ_KEYS := Map()
global CONF_WIDTH := 0
global CONF_HEIGHT := 0
global CURRENT_THEME := "Light"

if !DirExist(LOG_DIR) {
    DirCreate(LOG_DIR)
}

global LINES := [
    {name: "LSTE",    channel: "463450", fieldCount: 1, fieldBarcode: 2, color: "C6EFCE", tab: "PLXE"},
    {name: "PLXE 2",    channel: "463450", fieldCount: 3, fieldBarcode: 4, color: "FFCCFF", tab: "PLXE"},
    {name: "PLXE 3",    channel: "463450", fieldCount: 5, fieldBarcode: 6, color: "FFCCFF", tab: "PLXE"},
    {name: "QRAD (PLXE 4)",    channel: "463450", fieldCount: 7, fieldBarcode: 8, color: "FFCCFF", tab: "PLXE"},
    {name: "QRAD 1",    channel: "807602", fieldCount: 3, fieldBarcode: 4, color: "CCFFFF", tab: "Kiti"},
    {name: "NOBO 1",    channel: "703669", fieldCount: 1, fieldBarcode: 2, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 2",    channel: "703669", fieldCount: 3, fieldBarcode: 4, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 3",    channel: "703669", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 4",    channel: "703669", fieldCount: 7, fieldBarcode: 8, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 5",    channel: "802414", fieldCount: 1, fieldBarcode: 2, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 6",    channel: "802414", fieldCount: 3, fieldBarcode: 4, color: "E2EFDA", tab: "NOBO"},
    {name: "NOBO 7",    channel: "802414", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA", tab: "NOBO"},
    {name: "PLXE 5",    channel: "802414", fieldCount: 7, fieldBarcode: 8, color: "C6EFCE", tab: "PLXE"},
    {name: "XLE 1",     channel: "807602", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA", tab: "Kiti"},
    {name: "XLE ReWork",channel: "807602", fieldCount: 7, fieldBarcode: 8, color: "E2EFDA", tab: "Kiti"}
]

global INTERVALS := [
    ["06:00", "07:00"], ["07:00", "08:00"], ["08:00", "09:00"], ["09:10", "10:00"],
    ["10:00", "11:00"], ["11:00", "12:00"], ["12:00", "13:00"], ["13:00", "14:00"],
    ["14:00", "15:00"], ["15:00", "16:00"]
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
global TextControls := []
global BtnTheme := ""

; =======================================================
; HELPERS
; =======================================================

LoadConfig() {
    global SERVER_LOG_FILE, EXCEL_PATH, READ_KEYS, CONFIG_FILE, CONF_WIDTH, CONF_HEIGHT, LINES, CURRENT_THEME
    if FileExist(CONFIG_FILE) {
        try {
            SERVER_LOG_FILE := IniRead(CONFIG_FILE, "Paths", "ServerLog", SERVER_LOG_FILE)
            EXCEL_PATH := IniRead(CONFIG_FILE, "Paths", "ExcelPath", EXCEL_PATH)
            CONF_WIDTH := GetNum(IniRead(CONFIG_FILE, "Resolution", "Width", "0"))
            CONF_HEIGHT := GetNum(IniRead(CONFIG_FILE, "Resolution", "Height", "0"))
            CURRENT_THEME := IniRead(CONFIG_FILE, "Theme", "Mode", "Light")
            for ch in ["463450", "703669", "802414", "807602"] {
                val := IniRead(CONFIG_FILE, "ThingSpeak", "Key_" . ch, "")
                if (val != "") {
                    READ_KEYS[ch] := val
                }
            }
        }
    }
    for l in LINES {
        if !l.HasOwnProp("origName") {
            l.origName := l.name
        }
        if FileExist(CONFIG_FILE) {
            l.displayName := IniRead(CONFIG_FILE, "LineNames", l.origName, l.origName)
        } else {
            l.displayName := l.origName
        }
    }
}

GetNum(Value) {
    if IsNumber(Value) {
        return Value
    }
    strVal := String(Value)
    if (strVal = "") {
        return 0
    }
    clean := RegExReplace(strVal, "[^\d\.]")
    if (clean = "" || clean = ".") {
        return 0
    }
    try {
        return Number(clean)
    } catch {
        return 0
    }
}

GetColLetter(col) {
    letter := ""
    while (col > 0) {
        modVal := Mod(col - 1, 26)
        letter := Chr(65 + modVal) . letter
        col := Integer((col - modVal - 1) / 26)
    }
    return letter
}

HexRGBtoBGR(hexColor) {
    if (StrLen(hexColor) = 6) {
        r := SubStr(hexColor, 1, 2)
        g := SubStr(hexColor, 3, 2)
        b := SubStr(hexColor, 5, 2)
        return Integer("0x" . b . g . r)
    }
    return 0xFFFFFF
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
        lFactT := 0
        lPlanT := 0
        lFactC := 0
        lPlanC := 0
        for idx, io in data.intervals {
            pVal := GetNum(io.Plan.Value)
            fVal := GetNum(io.Fact.Value)
            stats[data.tab].Plan[idx] += pVal
            stats[data.tab].Fact[idx] += fVal
            lPlanT += pVal
            lFactT += fVal
            if (fVal > 0) {
                lFactC++
            }
            if (pVal > 0) {
                lPlanC++
            }
            if (pVal > 0) {
                clr := (fVal >= pVal) ? "Background90EE90 cBlack" : "BackgroundFF7F7F cBlack"
                io.Plan.Opt(clr)
                io.Fact.Opt(clr)
            } else {
                clrP := (CURRENT_THEME = "Dark") ? "Background333333 cFFFFFF" : "BackgroundWhite cBlack"
                clrF := (CURRENT_THEME = "Dark") ? "Background2D2D2D cFFFFFF" : "BackgroundWhite cBlack"
                io.Plan.Opt(clrP)
                io.Fact.Opt(clrF)
            }
            io.Plan.Redraw()
            io.Fact.Redraw()
        }
        data.planTotal.Value := lPlanT
        data.factTotal.Value := lFactT
        stats[data.tab].Grand += lFactT
        data.planAvg.Value := (lPlanC > 0) ? Round(lPlanT / lPlanC, 1) : 0
        data.factAvg.Value := (lFactC > 0) ? Round(lFactT / lFactC, 1) : 0
    }

    for tName, d in stats {
        if TabFooters.Has(tName) {
            f := TabFooters[tName]
            Loop INTERVALS.Length {
                i := A_Index
                fv := d.Fact[i]
                pv := d.Plan[i]
                f.Fact[i].Value := fv
                f.Plan[i].Value := pv
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
            if !FileExist(SERVER_LOG_FILE) {
                return
            }
            content := FileRead(SERVER_LOG_FILE, "UTF-8")
            if InStr(content, "[FILE:") {
                curF := ""
                fBuf := ""
                Loop Parse, content, "`n", "`r" {
                    ln := Trim(A_LoopField, " `t")
                    if RegExMatch(ln, "^\[FILE:(.+)\]$", &fm) {
                        if (curF != "") {
                            if FileExist(curF) {
                                FileDelete(curF)
                            }
                            FileAppend(RTrim(fBuf, "`n`r"), curF, "UTF-8")
                        }
                        curF := LOG_DIR . "\" . fm[1]
                        fBuf := ""
                    } else if (curF != "") {
                        fBuf .= A_LoopField . "`r`n"
                    }
                }
                if (curF != "") {
                    if FileExist(curF) {
                        FileDelete(curF)
                    }
                    FileAppend(RTrim(fBuf, "`n`r"), curF, "UTF-8")
                }
            }
        } else if (mode = "up") {
            payload := ""
            Loop Files, LOG_DIR . "\*.ini" {
                payload .= "[FILE:" . A_LoopFileName . "]`n" . FileRead(A_LoopFileFullPath) . "`n"
            }
            if (payload = "") {
                return
            }
            if FileExist(SERVER_LOG_FILE) {
                FileDelete(SERVER_LOG_FILE)
            }
            FileAppend(payload, SERVER_LOG_FILE, "UTF-8")
        }
    } catch Error as e {
        StatusText.Value := "Klaida: " . e.Message
    }
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
            idx := A_Index
            io := data.intervals[idx]
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
        req.Open("GET", url, true)
        req.Send()
        if (req.WaitForResponse(10)) {
            if (req.Status = 200) {
                return req.ResponseText
            }
        }
    }
    return ""
}

ParseFeeds(jStr) {
    feeds := []
    pos := 1
    while pos := RegExMatch(jStr, '\{"created_at":"[^"]+"[^}]*\}', &m, pos) {
        objStr := m[0]
        obj := Map()
        if RegExMatch(objStr, '"created_at":"([^"]+)"', &mm) {
            obj["created_at"] := mm[1]
        }
        Loop 8 {
            fN := "field" . A_Index
            if RegExMatch(objStr, '"' . fN . '":"?([^",}]*)"?', &mm) {
                obj[fN] := (mm[1] = "null") ? "" : mm[1]
            } else {
                obj[fN] := ""
            }
        }
        feeds.Push(obj)
        pos += m.Len
    }
    return feeds
}

CalculateDelta(feeds, field) {
    if (feeds.Length < 2) {
        return 0
    }
    vals := []
    for f in feeds {
        v := f.Has(field) ? f[field] : ""
        if (v != "" && v != "null") {
            try {
                vals.Push(Float(v))
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

GetLastVal(feeds, field) {
    idx := feeds.Length
    while (idx > 0) {
        val := feeds[idx].Has(field) ? feeds[idx][field] : ""
        if (val != "" && val != "null") {
            return val
        }
        idx--
    }
    return ""
}

GetLastActivityTS(feeds, field) {
    if (feeds.Length < 2) {
        return ""
    }
    idx := feeds.Length
    while (idx > 1) {
        cv := GetNum(feeds[idx].Has(field) ? feeds[idx][field] : "")
        pv := GetNum(feeds[idx-1].Has(field) ? feeds[idx-1][field] : "")
        if (cv > pv && cv > 0) {
            return feeds[idx]["created_at"]
        }
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
        if (ft >= s && ft <= e) {
            filtered.Push(f)
        }
    }
    return filtered
}

RefreshDataFromTS(target := "") {
    global Calendar, LINES, INTERVALS, Controls, StatusText
    tD := (target = "") ? FormatTime(Calendar.Value, "yyyy-MM-dd") : target
    StatusText.Value := "Kraunama..."
    chMap := Map()
    for l in LINES {
        if !chMap.Has(l.channel) {
            chMap[l.channel] := []
        }
        chMap[l.channel].Push(l)
    }
    today := FormatTime(A_Now, "yyyy-MM-dd")
    nowT := FormatTime(A_Now, "HH:mm")
    nowF := A_Now
    for ch, lines in chMap {
        lb := DateAdd(StrReplace(tD, "-", "") . "000000", -3, "Days")
        json := FetchTSData(ch, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), tD . " 16:00:00")
        if (json = "") {
            continue
        }
        allF := ParseFeeds(json)
        for l in lines {
            la := GetLastActivityTS(allF, "field" . l.fieldCount)
            if (la != "") {
                ts := StrReplace(StrReplace(StrReplace(SubStr(la, 1, 19), "-", ""), "T", ""), ":", "")
                diffMin := DateDiff(nowF, ts, "Minutes")
                if (diffMin <= 30) {
                    Controls[l.name].indicator.Opt("BackgroundGreen cGreen")
                } else {
                    Controls[l.name].indicator.Opt("BackgroundRed cRed")
                }
                if (diffMin < 0) {
                    diffMin := 0
                }
                hrs := Integer(diffMin / 60)
                mins := Mod(diffMin, 60)
                timeStr := (SubStr(ts, 1, 8) = SubStr(nowF, 1, 8)) ? FormatTime(ts, "HH:mm") : FormatTime(ts, "MM-dd HH:mm")
                elapsedStr := (hrs > 0) ? ("prieš " . hrs . " val. " . mins . " min.") : ("prieš " . mins . " min.")
                if Controls[l.name].HasOwnProp("lastTest") {
                    Controls[l.name].lastTest.Value := timeStr . "`r`n(" . elapsedStr . ")"
                }
            } else {
                Controls[l.name].indicator.Opt("BackgroundRed cRed")
                if Controls[l.name].HasOwnProp("lastTest") {
                    Controls[l.name].lastTest.Value := "-"
                }
            }
            for idx, iv in INTERVALS {
                if (tD = today && StrCompare(iv[1], nowT) > 0) {
                    continue
                }
                stT := tD . " " . iv[1] . ":00"
                enT := tD . " " . iv[2] . ":00"
                intF := FilterFeedsByTime(allF, stT, enT)
                p := CalculateDelta(intF, "field" . l.fieldCount)
                b := ""
                if (l.fieldBarcode > 0) {
                    uF := FilterFeedsByTime(allF, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), enT)
                    b := GetLastVal(uF, "field" . l.fieldBarcode)
                }
                if (l.origName = "UI perrašymas" || l.name = "UI perrašymas") {
                    b := "UI v5"
                } else if (b != "") {
                    b := "X-" . b
                }
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
    StatusText.Value := "Atnaujinta: " . FormatTime(, "HH:mm:ss")
}

OnRefreshBtn(*) {
    RefreshDataFromTS()
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
            if (io.Prod.Value != "" && (SubStr(io.Prod.Value, 1, 2) = "X-" || io.Prod.Value = "UI v5")) {
                io.Prod.Opt("+ReadOnly")
            } else {
                io.Prod.Opt("-ReadOnly")
            }
        }
    }
    UpdateCalculations()
    if (dStr = FormatTime(A_Now, "yyyy-MM-dd") || !FileExist(iPath) || force) {
        RefreshDataFromTS(dStr)
    }
}

; =======================================================
; UI HANDLERS
; =======================================================

OnMainSize(guiObj, minMax, width, height) {
    global Tabs, ActiveChild, ChildGuis
    if (minMax = -1) {
        return
    }
    if IsObject(Tabs) {
        Tabs.Move(,, width - 20)
    }
    if (ActiveChild != "" && ChildGuis.Has(ActiveChild)) {
        ChildGuis[ActiveChild].Show("x10 y85 w" . (width - 20) . " h" . (height - 90))
        UpdateScrollBars(ChildGuis[ActiveChild])
    }
}

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

HandleTabChange(ctrl, *) {
    global ActiveChild, ChildGuis, MainGui, Calendar
    if (ActiveChild != "") {
        ChildGuis[ActiveChild].Hide()
    }
    MainGui.GetClientPos(,, &guiW, &guiH)
    if ChildGuis.Has(ctrl.Text) {
        ChildGuis[ctrl.Text].Show("x10 y85 w" . (guiW - 20) . " h" . (guiH - 90))
        ActiveChild := ctrl.Text
        UpdateScrollBars(ChildGuis[ActiveChild], true)
        if IsObject(Calendar) {
            Calendar.Focus()
        }
    }
}

OnFieldLoseFocus(lName, iIdx, iType, ctrl, *) {
    SaveManualInput(lName, iIdx, iType, ctrl.Value)
    if (iType = "Plan") {
        UpdateCalculations()
    }
}

UpdateScrollBars(GuiObj, reset := false) {
    static SIF_ALL := 0x17
    GuiObj.GetClientPos(,, &guiW, &guiH)
    numLines := 0
    for l in LINES {
        if (ChildGuis.Has(l.tab) && ChildGuis[l.tab].Hwnd = GuiObj.Hwnd) {
            numLines++
        }
    }
    contentH := 5 + (numLines * 120) + 40 + 100 + 50
    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0)
    NumPut("UInt", SIF_ALL, si, 4)
    DllCall("GetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si)
    currPos := NumGet(si, 20, "Int")

    if (reset) {
        if (currPos > 0) {
            DllCall("ScrollWindowEx", "Ptr", GuiObj.Hwnd, "Int", 0, "Int", currPos, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
            currPos := 0
            DllCall("UpdateWindow", "Ptr", GuiObj.Hwnd)
        }
    } else {
        maxScroll := Max(0, contentH - guiH)
        if (currPos > maxScroll) {
            DllCall("ScrollWindowEx", "Ptr", GuiObj.Hwnd, "Int", 0, "Int", currPos - maxScroll, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
            currPos := maxScroll
            DllCall("UpdateWindow", "Ptr", GuiObj.Hwnd)
        }
    }

    NumPut("Int", 0, si, 8)
    NumPut("Int", contentH, si, 12)
    NumPut("UInt", guiH, si, 16)
    NumPut("Int", currPos, si, 20)
    DllCall("SetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si, "Int", 1)
}

OnScroll(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild = "" || hwnd != ChildGuis[ActiveChild].Hwnd) {
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
    if (action = 0) {
        newPos := nPos - 40
    } else if (action = 1) {
        newPos := nPos + 40
    } else if (action = 2) {
        newPos := nPos - nPage
    } else if (action = 3) {
        newPos := nPos + nPage
    } else if (action = 4 || action = 5) {
        newPos := wp >> 16
    } else {
        return
    }
    limit := Max(0, nMax - Integer(nPage))
    newPos := Max(nMin, Min(newPos, limit))
    if (newPos = nPos) {
        return
    }
    DllCall("ScrollWindowEx", "Ptr", hwnd, "Int", 0, "Int", nPos - newPos, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
    NumPut("Int", newPos, si, 20)
    DllCall("SetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si, "Int", 1)
    DllCall("UpdateWindow", "Ptr", hwnd)
}

OnWheel(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild = "") {
        return
    }
    delta := (wp >> 16) > 0x7FFF ? (wp >> 16) - 0x10000 : (wp >> 16)
    Loop Integer(Abs(delta) / 120) {
        SendMessage(0x0115, delta > 0 ? 0 : 1, 0, ChildGuis[ActiveChild].Hwnd)
    }
}

OnMouseMove(wParam, lParam, msg, hwnd) {
    global CommHwnds
    static LastH := 0
    if (hwnd = LastH) {
        return
    }
    LastH := hwnd
    try {
        if CommHwnds.Has(hwnd) {
            val := CommHwnds[hwnd].Value
            if (val != "") {
                ToolTip(val)
                SetTimer(CheckMousePos.Bind(hwnd), 100)
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

CheckMousePos(OHwnd) {
    global CommHwnds
    try {
        MouseGetPos(,, &THwnd, &CHwnd, 2)
        if (THwnd != OHwnd && CHwnd != OHwnd) {
            ToolTip()
            SetTimer(CheckMousePos.Bind(OHwnd), 0)
        } else if (CommHwnds.Has(OHwnd)) {
            ToolTip(CommHwnds[OHwnd].Value)
        }
    } catch {
        ToolTip()
        SetTimer(CheckMousePos.Bind(OHwnd), 0)
    }
}

; =======================================================
; EXCEL & SETTINGS
; =======================================================

ExportToExcel(*) {
    global Calendar, Controls, INTERVALS, LINES, EXCEL_PATH, CONFIG_FILE, StatusText
    sN := FormatTime(Calendar.Value, "MM.dd")
    if !FileExist(EXCEL_PATH) {
        return MsgBox("Failas nerastas")
    }
    xl := ""
    try {
        xl := ComObjActive("Excel.Application")
    } catch {
        try {
            xl := ComObject("Excel.Application")
        }
    }
    if !xl {
        return
    }
    xl.Visible := true
    xl.DisplayAlerts := false
    wb := ""
    rC := 0
    while (rC < 3) {
        try {
            Loop xl.Workbooks.Count {
                if (xl.Workbooks(A_Index).FullName = EXCEL_PATH) {
                    wb := xl.Workbooks(A_Index)
                    break
                }
            }
            if !wb {
                wb := xl.Workbooks.Open(EXCEL_PATH)
            }
            break
        } catch {
            rC++
            Sleep(2000)
        }
    }
    if !wb {
        return
    }
    try {
        ws := ""
        try {
            ws := wb.Sheets(sN)
            try {
                ws.Unprotect("gd2024")
            } catch {
                try {
                    ws.Unprotect()
                } catch {
                    ; ignore
                }
            }
            if (ws.ProtectContents) {
                ws.Delete()
                ws := wb.Sheets.Add()
                ws.Name := sN
            }
        } catch {
            ws := wb.Sheets.Add()
            ws.Name := sN
        }

        headers := ["Linija", "Laukas", "6:00-7:00", "7:00-8:00", "8:00-9:00", "9:10-10:00", "10:00-11:00", "11:00-12:00", "12:00-13:00", "13:00-14:00", "14:00-15:00", "15:00-16:00", "Viso"]
        Loop headers.Length {
            ws.Cells(1, A_Index).Value := headers[A_Index]
        }
        ws.Range("A1:M1").Font.Bold := true
        ws.Range("A1:M1").Font.Color := 0xFFFFFF
        ws.Range("A1:M1").Interior.Color := 0x333333
        ws.Range("A1:M1").HorizontalAlignment := -4108

        idx := 1
        maxR := 1
        factCells := ""
        for l in LINES {
            d := Controls[l.name]
            origKey := l.HasOwnProp("origName") ? l.origName : l.name
            dispName := l.HasOwnProp("displayName") ? l.displayName : l.name
            rVal := IniRead(CONFIG_FILE, "Mapping", origKey . "_Row", String(2 + (idx - 1) * 4))
            cVal := IniRead(CONFIG_FILE, "Mapping", origKey . "_Col", "1")
            r := Integer(GetNum(rVal))
            c := Integer(GetNum(cVal))
            if (idx > 1 && r <= 2) {
                r := 2 + (idx - 1) * 4
            }
            idx++
            if (r < 1) {
                r := 2
            }
            if (c < 1) {
                c := 1
            }
            if (r + 3 > maxR) {
                maxR := r + 3
            }

            ws.Cells(r, c).Value := dispName
            colLet := GetColLetter(c)
            rangeStr := colLet . r . ":" . colLet . (r + 3)
            try {
                ws.Range(rangeStr).Merge()
            } catch {
                ; merge might fail if cell is already merged
            }
            ws.Range(rangeStr).Font.Bold := true
            ws.Range(rangeStr).HorizontalAlignment := -4108
            ws.Range(rangeStr).VerticalAlignment := -4108
            ws.Range(rangeStr).Orientation := 90

            ws.Cells(r, c+1).Value := dispName . " Planas"
            ws.Cells(r+1, c+1).Value := dispName . " Faktas"
            ws.Cells(r+2, c+1).Value := "Gaminys"
            ws.Cells(r+3, c+1).Value := "Komentaras"

            ; Background color for mapping column B
            bgrCol := HexRGBtoBGR(l.color)
            ws.Range(GetColLetter(c+1) . r . ":" . GetColLetter(c+1) . (r+3)).Interior.Color := bgrCol

            Loop INTERVALS.Length {
                i := A_Index
                ws.Cells(r, c+1+i).Value := d.intervals[i].Plan.Value
                ws.Cells(r+1, c+1+i).Value := d.intervals[i].Fact.Value
                ws.Cells(r+1, c+1+i).Font.Color := 0xFF0000  ; Blue (BGR 0xFF0000 is Blue)
                ws.Cells(r+1, c+1+i).Font.Bold := true
                ws.Cells(r+2, c+1+i).Value := d.intervals[i].Prod.Value
                ws.Cells(r+3, c+1+i).Value := d.intervals[i].Comm.Value
            }

            ; Sum formulas for Plan and Fact in column M
            ws.Cells(r, 13).Formula := "=SUM(" . GetColLetter(c+2) . r . ":" . GetColLetter(c+11) . r . ")"
            ws.Cells(r+1, 13).Formula := "=SUM(" . GetColLetter(c+2) . (r+1) . ":" . GetColLetter(c+11) . (r+1) . ")"
            ws.Cells(r+1, 13).Font.Bold := true
            ws.Cells(r+1, 13).Font.Color := 0xFF0000

            factCells .= "M" . (r + 1) . ","
        }

        grandRow := maxR + 2
        factCells := RTrim(factCells, ",")
        ws.Cells(grandRow, 12).Value := "BENDRA SUMA:"
        ws.Cells(grandRow, 12).Font.Bold := true
        ws.Cells(grandRow, 12).HorizontalAlignment := -4108
        ws.Cells(grandRow, 13).Formula := "=SUM(" . factCells . ")"
        ws.Cells(grandRow, 13).Font.Bold := true
        ws.Cells(grandRow, 13).Font.Color := 0xFF0000
        ws.Cells(grandRow, 13).Font.Size := 14

        ; Apply thin continuous borders to the entire table
        ws.Range("A1:M" . grandRow).Borders.LineStyle := 1
        ws.Range("A1:M" . grandRow).Borders.Weight := 2

        ; AutoFit column widths
        ws.Columns("A:M").AutoFit()

        try {
            ws.Protect("gd2024")
        } catch {
            ; ignore
        }
        wb.Save()
        StatusText.Value := "Baigta."
    } catch Error as e {
        MsgBox("Excel klaida: " . e.Message . "`nEilutė: " . e.Line . "`nFunkcija: " . e.What)
    }
}

ToggleTheme(*) {
    global CURRENT_THEME, CONFIG_FILE, LOG_DIR
    CURRENT_THEME := (CURRENT_THEME = "Dark") ? "Light" : "Dark"
    if FileExist(CONFIG_FILE) || DirExist(LOG_DIR) {
        IniWrite(CURRENT_THEME, CONFIG_FILE, "Theme", "Mode")
    }
    ApplyTheme()
}

ApplyTheme() {
    global MainGui, ChildGuis, TextControls, BtnTheme, StatusText, Controls, TabFooters, CURRENT_THEME, INTERVALS
    isDark := (CURRENT_THEME = "Dark")
    if IsObject(BtnTheme) {
        BtnTheme.Text := "Tema: " . (isDark ? "Tamsi" : "Šviesi")
    }

    mainBg := isDark ? "1E1E1E" : "F0F0F0"
    childBg := isDark ? "252526" : "White"
    txtColor := isDark ? "cFFFFFF" : "cBlack"
    editBg := isDark ? "Background333333" : "BackgroundWhite"
    readOnlyBg := isDark ? "Background2D2D2D" : "BackgroundWhite"

    if IsObject(MainGui) {
        MainGui.BackColor := mainBg
    }

    for tName, cG in ChildGuis {
        cG.BackColor := childBg
    }

    for ctrl in TextControls {
        ctrl.Opt(txtColor)
        ctrl.Redraw()
    }

    if IsObject(StatusText) {
        StatusText.Opt(isDark ? "cE0E0E0" : "cBlack")
        StatusText.Redraw()
    }

    for name, data in Controls {
        for idx, io in data.intervals {
            io.Prod.Opt(editBg . " " . txtColor)
            io.Prod.Redraw()
            io.Comm.Opt(editBg . " " . (isDark ? "cFF6666" : "cRed"))
            io.Comm.Redraw()
        }
        data.planTotal.Opt(readOnlyBg . " " . txtColor)
        data.planTotal.Redraw()
        data.factTotal.Opt(readOnlyBg . " " . txtColor)
        data.factTotal.Redraw()
        data.planAvg.Opt(readOnlyBg . " " . txtColor)
        data.planAvg.Redraw()
        data.factAvg.Opt(readOnlyBg . " " . txtColor)
        data.factAvg.Redraw()
        if data.HasOwnProp("lastTest") && IsObject(data.lastTest) {
            data.lastTest.Opt(readOnlyBg . " " . txtColor)
            data.lastTest.Redraw()
        }
    }

    for tName, f in TabFooters {
        Loop INTERVALS.Length {
            i := A_Index
            f.Fact[i].Opt(readOnlyBg . " " . (isDark ? "cFF6666" : "cRed"))
            f.Fact[i].Redraw()
            f.Plan[i].Opt(readOnlyBg . " " . txtColor)
            f.Plan[i].Redraw()
            f.Pct[i].Opt(readOnlyBg . " " . txtColor)
            f.Pct[i].Redraw()
        }
        f.Grand.Opt(readOnlyBg . " " . txtColor)
        f.Grand.Redraw()
    }

    UpdateCalculations()
}

ShowSettings(*) {
    global CONFIG_FILE, SERVER_LOG_FILE, EXCEL_PATH, LINES, CONF_WIDTH, CONF_HEIGHT, CURRENT_THEME
    SGui := Gui("+AlwaysOnTop", "Nustatymai")
    if (CURRENT_THEME = "Dark") {
        SGui.BackColor := "1E1E1E"
    }
    SGui.Add("Text", "xm", "Log:")
    eL := SGui.Add("Edit", "w500", SERVER_LOG_FILE)
    SGui.Add("Button", "x+5", "...").OnEvent("Click", SelectLog)
    SelectLog(*) {
        f := FileSelect(3)
        if f {
            eL.Value := f
        }
    }
    SGui.Add("Text", "xm", "Excel:")
    eE := SGui.Add("Edit", "w500", EXCEL_PATH)
    SGui.Add("Button", "x+5", "...").OnEvent("Click", SelectExcel)
    SelectExcel(*) {
        f := FileSelect(3)
        if f {
            eE.Value := f
        }
    }
    LV := SGui.Add("ListView", "xm w530 h180 Grid", ["Originali linija", "Pavadinimas", "Row", "Col"])
    idx := 1
    for l in LINES {
        origN := l.HasOwnProp("origName") ? l.origName : l.name
        dispN := l.HasOwnProp("displayName") ? l.displayName : l.name
        rVal := IniRead(CONFIG_FILE, "Mapping", origN . "_Row", String(2 + (idx - 1) * 4))
        cVal := IniRead(CONFIG_FILE, "Mapping", origN . "_Col", "1")
        r := Integer(GetNum(rVal))
        c := Integer(GetNum(cVal))
        if (idx > 1 && r <= 2) {
            r := 2 + (idx - 1) * 4
        }
        LV.Add(, origN, dispN, String(r), String(c))
        idx++
    }

    LV.OnEvent("DoubleClick", DoubleClickLV)
    DoubleClickLV(ctrl, rowIdx) {
        if !rowIdx {
            return
        }
        p := Gui("+AlwaysOnTop", "Keisti liniją")
        p.Add("Text",, "Pavadinimas:")
        n := p.Add("Edit", "w150", LV.GetText(rowIdx, 2))
        p.Add("Text",, "Row:")
        r := p.Add("Edit", "w50", LV.GetText(rowIdx, 3))
        p.Add("Text",, "Col:")
        c := p.Add("Edit", "w50", LV.GetText(rowIdx, 4))

        btn := p.Add("Button", "Default", "OK")
        btn.OnEvent("Click", (*) => OnClickOK())
        OnClickOK() {
            LV.Modify(rowIdx,, LV.GetText(rowIdx, 1), n.Value, r.Value, c.Value)
            p.Destroy()
        }
        p.Show()
    }

    SGui.Add("Text", "xm", "Plotis (W):")
    eW := SGui.Add("Edit", "w100", String(CONF_WIDTH))
    SGui.Add("Text", "x+10", "Aukštis (H):")
    eH := SGui.Add("Edit", "w100", String(CONF_HEIGHT))

    SGui.Add("Button", "xm w100", "Išsaugoti").OnEvent("Click", (*) => OnSaveSettings())
    OnSaveSettings() {
        IniWrite(eL.Value, CONFIG_FILE, "Paths", "ServerLog")
        IniWrite(eE.Value, CONFIG_FILE, "Paths", "ExcelPath")
        IniWrite(eW.Value, CONFIG_FILE, "Resolution", "Width")
        IniWrite(eH.Value, CONFIG_FILE, "Resolution", "Height")
        Loop LV.GetCount() {
            i := A_Index
            origN := LV.GetText(i, 1)
            dispN := LV.GetText(i, 2)
            rowN := LV.GetText(i, 3)
            colN := LV.GetText(i, 4)
            IniWrite(dispN, CONFIG_FILE, "LineNames", origN)
            IniWrite(rowN, CONFIG_FILE, "Mapping", origN . "_Row")
            IniWrite(colN, CONFIG_FILE, "Mapping", origN . "_Col")
        }
        Reload()
    }
    SGui.Show()
}

; =======================================================
; MAIN EXECUTION
; =======================================================
LoadConfig()

MainGui := Gui("+Resize +MinimizeBox", "GD Dashboard v" . CURRENT_VERSION)
MainGui.SetFont("s9", "Segoe UI")
MainGui.OnEvent("Size", OnMainSize)
MainGui.OnEvent("Close", OnMainClose)
OnMainClose(*) {
    ExitApp()
}

TextControls.Push(MainGui.Add("Text", "x10 y15", "Data:"))
BtnPrev := MainGui.Add("Button", "x50 y10 w30 h24", "<")
BtnPrev.OnEvent("Click", GoPrevDay)

Calendar := MainGui.Add("DateTime", "x85 y10 w120", "yyyy-MM-dd")
Calendar.OnEvent("Change", OnCalendarChange)
OnCalendarChange(*) {
    LoadDateData()
}

BtnNext := MainGui.Add("Button", "x210 y10 w30 h24", ">")
BtnNext.OnEvent("Click", GoNextDay)

MainGui.Add("Button", "x250 y10 w100", "Atnaujinti").OnEvent("Click", OnRefreshBtn)
MainGui.Add("Button", "x360 y10 w120", "Saugoti").OnEvent("Click", SaveAndSync)
MainGui.Add("Button", "x490 y10 w100", "Excel").OnEvent("Click", ExportToExcel)
MainGui.Add("Button", "x600 y10 w100", "Nustatymai").OnEvent("Click", ShowSettings)
BtnTheme := MainGui.Add("Button", "x710 y10 w100", "Tema")
BtnTheme.OnEvent("Click", ToggleTheme)

StatusText := MainGui.Add("Text", "x820 y15 w600", "Kraunama...")
Tabs := MainGui.Add("Tab3", "x10 y50 w1520 h35", ["PLXE", "NOBO", "Kiti"])
Tabs.OnEvent("Change", HandleTabChange)

for tName in ["PLXE", "NOBO", "Kiti"] {
    cG := Gui("-Caption +Parent" . MainGui.Hwnd . " +0x00200000")
    cG.BackColor := "White"
    cG.Show("Hide w1520 h950")

    ; Header labels
    cG.SetFont("s9 bold")
    Loop INTERVALS.Length {
        idx := A_Index
        X := 230 + (idx-1) * 95
        TextControls.Push(cG.Add("Text", "x" . X . " y5 w90 h20 Center", INTERVALS[idx][1] . "-" . INTERVALS[idx][2]))
    }
    TextControls.Push(cG.Add("Text", "x" . (230 + INTERVALS.Length * 95) . " y5 w90 h20 Center", "Viso"))
    TextControls.Push(cG.Add("Text", "x" . (230 + (INTERVALS.Length + 1) * 95) . " y5 w120 h20 Center", "Vidurkis"))
    TextControls.Push(cG.Add("Text", "x1380 y5 w130 h20 Center", "Paskutinis testas"))
    cG.SetFont("s9 norm")

    curY := 35
    for l in LINES {
        if (l.tab = tName) {
            name := l.name
            dispName := l.HasOwnProp("displayName") ? l.displayName : name
            cG.SetFont("s10 bold")
            TextControls.Push(cG.Add("Text", "x15 y" . curY . " w100 h20", dispName))
            cInd := cG.Add("Progress", "x15 y" . curY+22 . " w100 h10 BackgroundRed cRed", 0)
            cG.SetFont("s9 bold")
            TextControls.Push(cG.Add("Text", "x125 y" . curY . " w95 h20", "Planas"))
            TextControls.Push(cG.Add("Text", "x125 y" . curY+23 . " w95 h20", "Faktas"))
            TextControls.Push(cG.Add("Text", "x125 y" . curY+46 . " w95 h20", "Gaminys"))
            TextControls.Push(cG.Add("Text", "x125 y" . curY+69 . " w95 h20", "Komentaras"))
            cG.SetFont("s9 norm")

            lineCtrls := []
            Loop INTERVALS.Length {
                idx := A_Index
                X := 230 + (idx-1) * 95
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
            cLT := cG.Add("Edit", "x1380 y" . (curY+18) . " w130 h42 Center +Multi ReadOnly")
            cG.SetFont("s9 norm")
            Controls[name] := {intervals: lineCtrls, planTotal: cPT, planAvg: cPA, factTotal: cFT, factAvg: cFA, lastTest: cLT, tab: l.tab, indicator: cInd}
            curY += 120
        }
    }

    fH := []
    pH := []
    pcH := []
    footerY := curY + 40
    cG.SetFont("s9 bold")
    TextControls.Push(cG.Add("Text", "x125 y" . footerY . " w95 h20", "Faktas"))
    TextControls.Push(cG.Add("Text", "x15 y" . footerY+23 . " w100 h20", "Tikslas:"))
    TextControls.Push(cG.Add("Text", "x125 y" . footerY+23 . " w95 h20", "Planas"))
    Loop INTERVALS.Length {
        idx := A_Index
        X := 230 + (idx-1) * 95
        fH.Push(cG.Add("Edit", "x" . X . " y" . footerY . " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(cG.Add("Edit", "x" . X . " y" . footerY+23 . " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(cG.Add("Edit", "x" . X . " y" . footerY+46 . " w90 h20 Center ReadOnly +0x800 BackgroundWhite"))
    }
    TextControls.Push(cG.Add("Text", "x1380 y" . footerY-25 . " w130 h20 Center", "Viso:"))
    cG.SetFont("s32 bold")
    cGr := cG.Add("Edit", "x1380 y" . footerY-5 . " w130 h80 Center ReadOnly Border")
    cG.SetFont("s9 norm")
    TabFooters[tName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGr}
    ChildGuis[tName] := cG
}

global CONF_WIDTH, CONF_HEIGHT
showW := CONF_WIDTH
showH := CONF_HEIGHT

if (showW < 100 || showH < 100) {
    ; Not configured yet or invalid, show a quick selection dialog
    RGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Pasirinkite rezoliuciją")
    RGui.SetFont("s9", "Segoe UI")
    RGui.Add("Text",, "Pasirinkite ekrano rezoliuciją pirmajam paleidimui:")

    opts := ["1280x720", "1366x768", "1540x1000", "Custom"]
    rad := []
    for opt in opts {
        chk := (A_Index = 2) ? "Checked" : ""
        rad.Push(RGui.Add("Radio", chk . " y+5", opt))
    }

    RGui.Add("Text", "y+10", "Arba įrašykite rankiniu būdu (Plotis x Aukštis):")
    customW := RGui.Add("Edit", "w70", "1366")
    RGui.Add("Text", "x+5", "x")
    customH := RGui.Add("Edit", "x+5 w70", "768")

    RGui.Add("Button", "xm y+15 w100 Default", "Išsaugoti").OnEvent("Click", (*) => OnSaveRes())
    OnSaveRes() {
        chosenW := 1366
        chosenH := 768
        if (rad[1].Value) {
            chosenW := 1280, chosenH := 720
        } else if (rad[2].Value) {
            chosenW := 1366, chosenH := 768
        } else if (rad[3].Value) {
            chosenW := 1540, chosenH := 1000
        } else if (rad[4].Value) {
            chosenW := GetNum(customW.Value)
            chosenH := GetNum(customH.Value)
        }
        if (chosenW < 400) {
            chosenW := 1280
        }
        if (chosenH < 400) {
            chosenH := 720
        }
        IniWrite(String(chosenW), CONFIG_FILE, "Resolution", "Width")
        IniWrite(String(chosenH), CONFIG_FILE, "Resolution", "Height")
        CONF_WIDTH := chosenW
        CONF_HEIGHT := chosenH
        RGui.Destroy()
        Reload()
    }
    RGui.Show("Center")
    ; We hold execution until selection is made or we fall back
    WinWaitClose(RGui.Hwnd)
    showW := CONF_WIDTH
    showH := CONF_HEIGHT
    if (showW < 100 || showH < 100) {
        showW := 1366
        showH := 768
    }
}

MainGui.Show("Center w" . showW . " h" . showH)
ApplyTheme()
HandleTabChange(Tabs)
if IsObject(Calendar) {
    Calendar.Focus()
}

OnMessage(0x0115, OnScroll)
OnMessage(0x020A, OnWheel)
OnMessage(0x0200, OnMouseMove)

StartupProcess(*) {
    SyncLocalServer("down")
    LoadDateData()
}
SetTimer(StartupProcess, -500)
SetTimer(() => RefreshDataFromTS(), 300000)

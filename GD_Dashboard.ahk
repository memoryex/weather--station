#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
Global CURRENT_VERSION := "2.1"
Global LOG_DIR := A_ScriptDir "\logs"
if !DirExist(LOG_DIR)
{
    DirCreate(LOG_DIR)
}

; Configuration (Loaded from config.ini)
Global CONFIG_FILE := A_ScriptDir "\config.ini"
Global GIST_ID := "bca7d49ac0724f650842b0e7c691a1c1"
Global GIST_TOKEN := IniRead(CONFIG_FILE, "Gist", "Token", "")

Global READ_KEYS := Map()
for ch in ["463450", "703669", "802414", "807602"]
    READ_KEYS[ch] := IniRead(CONFIG_FILE, "ThingSpeak", "Key_" ch, "")

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
; GUI CONSTRUCTION
; =======================================================
Global MainGui := Gui("+Resize +E0x02000000", "GD Gamybos Dashboard v" CURRENT_VERSION)
MainGui.SetFont("s9", "Segoe UI")
MainGui.BackColor := "White"

MainGui.Add("Text", "x10 y15", "Pasirinkite datą:")
Global Calendar := MainGui.Add("DateTime", "x110 y10 w150 vSelectedDate", "yyyy-MM-dd")
Calendar.OnEvent("Change", (ctrl, *) => LoadDateData())

BtnRefresh := MainGui.Add("Button", "x270 y10 w100", "Atnaujinti")
BtnRefresh.OnEvent("Click", (ctrl, *) => (SyncGist("down"), LoadDateData()))

BtnSaveAll := MainGui.Add("Button", "x380 y10 w120", "Saugoti viską")
BtnSaveAll.OnEvent("Click", (ctrl, *) => SaveAndSync())

Global StatusText := MainGui.Add("Text", "x515 y15 w600 vStatus", "Pasiruošęs")

Global Tabs := MainGui.Add("Tab3", "x10 y50 w1460 h980 vTabsMain", ["PLXE", "NOBO", "Kiti"])

; Store control references
Global Controls := Map()
Global TabFooters := Map() ; {TabName: {Fact: [], Plan: [], Pct: [], Grand: ctrl}}

AddIntervalHeaders(YPos)
{
    global MainGui, INTERVALS
    MainGui.SetFont("s9 bold")
    Loop (INTERVALS.Length)
    {
        X := 230 + (A_Index-1) * 95
        MainGui.Add("Text", "x" X " y" YPos " w90 h20 Center", INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2])
    }
    MainGui.Add("Text", "x" (230 + INTERVALS.Length * 95) " y" YPos " w90 h20 Center", "Viso")
    MainGui.Add("Text", "x" (230 + (INTERVALS.Length + 1) * 95) " y" YPos " w90 h20 Center", "Vidurkis")
    MainGui.SetFont("s9 norm")
}

CreateLineGrid(LineObj, YPos, TabIdx)
{
    global Controls, Tabs, MainGui, INTERVALS
    name := LineObj.name
    safeName := RegExReplace(name, "[ \-]", "_")

    Tabs.UseTab(TabIdx)

    MainGui.SetFont("s10 bold")
    MainGui.Add("Text", "x15 y" YPos " w100 h20", name)

    MainGui.SetFont("s9 bold")
    MainGui.Add("Text", "x125 y" YPos " w95 h20", "Planas")
    MainGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Faktas")
    MainGui.Add("Text", "x125 y" YPos+46 " w95 h20", "Gaminys")
    MainGui.Add("Text", "x125 y" YPos+69 " w95 h20", "Komentaras")
    MainGui.SetFont("s9 norm")

    lineCtrls := []
    Loop (INTERVALS.Length)
    {
        idx := A_Index
        X := 230 + (idx-1) * 95

        cPlan := MainGui.Add("Edit", "x" X " y" YPos " w90 h20 Center v" safeName "_P" idx)
        cFact := MainGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly v" safeName "_F" idx)
        cProd := MainGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center ReadOnly v" safeName "_G" idx)
        cComm := MainGui.Add("Edit", "x" X " y" YPos+69 " w90 h20 Center cRed v" safeName "_K" idx)

        lineCtrls.Push({Plan: cPlan, Fact: cFact, Prod: cProd, Comm: cComm})

        cPlan.OnEvent("LoseFocus", (ctrl, *) => (SaveManualInput(name, idx, "Plan", ctrl.Value), UpdateCalculations()))
        cComm.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Comm", ctrl.Value))
    }

    X := 230 + INTERVALS.Length * 95
    MainGui.SetFont("s9 bold")
    cTotal := MainGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly v" safeName "_Total")

    X_Avg := X + 95
    cAvg := MainGui.Add("Edit", "x" X_Avg " y" YPos+23 " w90 h20 Center ReadOnly v" safeName "_Avg")
    MainGui.SetFont("s9 norm")

    Controls[name] := {intervals: lineCtrls, total: cTotal, avg: cAvg, tab: LineObj.tab}
}

CreateTabFooter(TabName, YPos, TabIdx)
{
    global TabFooters, Tabs, MainGui, INTERVALS
    Tabs.UseTab(TabIdx)

    fH := [], pH := [], pcH := []

    MainGui.SetFont("s9 bold")
    MainGui.Add("Text", "x125 y" YPos " w95 h20", "Faktas")
    MainGui.Add("Text", "x15 y" YPos+23 " w100 h20", "Tikslas:")
    MainGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Planas")

    Loop (INTERVALS.Length)
    {
        idx := A_Index
        X := 230 + (idx-1) * 95

        fH.Push(MainGui.Add("Edit", "x" X " y" YPos " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(MainGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(MainGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center ReadOnly +0x800 BackgroundWhite")) ; Flat look
    }

    X_Total := 1285
    MainGui.Add("Text", "x" X_Total " y" YPos-25 " w140 h20 Center", "Visos dienos:")
    MainGui.SetFont("s32 bold")
    cGrand := MainGui.Add("Edit", "x" X_Total " y" YPos-5 " w140 h80 Center ReadOnly Border")
    MainGui.SetFont("s9 norm")

    TabFooters[TabName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGrand}
    MainGui.SetFont("norm")
}

; Populate Tabs
; In Tab3, coordinates are relative to the Tab control's client area.
headerY := 5
contentStartY := 15
lineStep := 120
footerGap := 40

; PLXE
Tabs.UseTab(1)
AddIntervalHeaders(headerY)
Y := contentStartY
for index, line in LINES {
    if (line.tab == "PLXE") {
        CreateLineGrid(line, Y, 1)
        Y += lineStep
    }
}
CreateTabFooter("PLXE", Y + footerGap, 1)

; NOBO
Tabs.UseTab(2)
AddIntervalHeaders(headerY)
Y := contentStartY
for index, line in LINES {
    if (line.tab == "NOBO") {
        CreateLineGrid(line, Y, 2)
        Y += lineStep
    }
}
CreateTabFooter("NOBO", Y + footerGap, 2)

; Kiti
Tabs.UseTab(3)
AddIntervalHeaders(headerY)
Y := contentStartY
for index, line in LINES {
    if (line.tab == "Kiti") {
        CreateLineGrid(line, Y, 3)
        Y += lineStep
    }
}
CreateTabFooter("Kiti", Y + footerGap, 3)

MainGui.Show("w1480 h1050")

OnMessage(0x0200, WM_MOUSEMOVE)
WM_MOUSEMOVE(wParam, lParam, msg, hwnd)
{
    static LastHwnd := 0
    if (hwnd == LastHwnd)
        return
    LastHwnd := hwnd

    try
    {
        ctrl := GuiCtrlFromHwnd(hwnd)
        if (ctrl && InStr(ctrl.Name, "_K"))
        {
            val := ctrl.Value
            if (val != "")
            {
                ToolTip(val)
                ; Set a timer to clear tooltip if mouse leaves the control area
                SetTimer(CheckMousePos.Bind(hwnd), 500)
            }
            else
                ToolTip()
        }
        else
        {
            ToolTip()
        }
    }
}

CheckMousePos(OriginalHwnd)
{
    try
    {
        MouseGetPos(,, &TargetHwnd, &ControlHwnd, 2)
        if (TargetHwnd != OriginalHwnd && ControlHwnd != OriginalHwnd)
        {
            ToolTip()
            SetTimer(CheckMousePos.Bind(OriginalHwnd), 0)
        }
    }
}

SyncGist("down")
LoadDateData()

SetTimer(AutoRefresh, 300000)
AutoRefresh()
{
    if (FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd") == FormatTime(A_Now, "yyyy-MM-dd"))
    {
        FetchTodayData()
    }
}

UpdateCalculations()
{
    global Controls, TabFooters, INTERVALS

    ; Initialize Tab Aggregates
    stats := Map("PLXE", {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0},
                 "NOBO", {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0},
                 "Kiti", {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0})

    for lineName, data in Controls
    {
        lineTotalFact := 0
        activeIntervals := 0
        tabName := data.tab

        for idx, interval in data.intervals
        {
            pVal := IsNumber(interval.Plan.Value) ? Integer(interval.Plan.Value) : 0
            fVal := IsNumber(interval.Fact.Value) ? Integer(interval.Fact.Value) : 0

            stats[tabName].Plan[idx] += pVal
            stats[tabName].Fact[idx] += fVal
            lineTotalFact += fVal

            if (fVal > 0 || pVal > 0)
                activeIntervals++

            ; Conditional Formatting
            if (pVal > 0)
            {
                if (fVal >= pVal)
                {
                    interval.Plan.Opt("Background0x90EE90")
                    interval.Fact.Opt("Background0x90EE90")
                }
                else
                {
                    interval.Plan.Opt("Background0xFF7F7F")
                    interval.Fact.Opt("Background0xFF7F7F")
                }
            }
            else
            {
                interval.Plan.Opt("BackgroundWhite")
                interval.Fact.Opt("BackgroundWhite")
            }
            interval.Plan.Redraw()
            interval.Fact.Redraw()
        }

        data.total.Value := lineTotalFact
        stats[tabName].Grand += lineTotalFact
        avg := activeIntervals > 0 ? Round(lineTotalFact / activeIntervals, 1) : 0
        data.avg.Value := avg
    }

    ; Update Tab Footers
    for tName, tData in stats
    {
        footer := TabFooters[tName]
        Loop (INTERVALS.Length)
        {
            i := A_Index
            fVal := tData.Fact[i]
            pVal := tData.Plan[i]
            footer.Fact[i].Value := fVal
            footer.Plan[i].Value := pVal

            pct := 0
            if (pVal > 0)
            {
                pct := Round((fVal / pVal - 1) * 100)
            }
            footer.Pct[i].Value := (pct >= 0 ? "+" pct : pct) "%"
        }
        footer.Grand.Value := tData.Grand
    }
}

SyncGist(mode)
{
    global GIST_ID, GIST_TOKEN, LOG_DIR, StatusText
    if (GIST_TOKEN == "" || GIST_TOKEN == "PLACEHOLDER_TOKEN")
        return

    StatusText.Value := (mode == "up" ? "Siunčiama į Gist..." : "Sinchronizuojama iš Gist...")
    url := "https://api.github.com/gists/" GIST_ID
    req := ComObject("WinHttp.WinHttpRequest.5.1")

    try
    {
        if (mode == "down")
        {
            req.Open("GET", url, false) ; Use synchronous for easier state management
            req.SetRequestHeader("Authorization", "token " GIST_TOKEN)
            req.Send()

            if (req.Status == 200)
            {
                res := req.ResponseText
                ; Improved RegEx to handle escaped quotes in content
                if RegExMatch(res, '"logas\.txt":\{"filename":"logas\.txt",.*?"content":"((?:[^"\\]|\\.)*)"\}', &m)
                {
                    content := m[1]
                    content := StrReplace(content, "\n", "`n")
                    content := StrReplace(content, "\r", "`r")
                    content := StrReplace(content, '\"', '"')
                    content := StrReplace(content, '\\', '\')

                    currentFile := ""
                    Loop Parse, content, "`n", "`r"
                    {
                        line := A_LoopField
                        if (line == "")
                            continue
                        if RegExMatch(line, "^\[FILE:(.+)\]$", &fm)
                        {
                            currentFile := LOG_DIR "\" fm[1]
                            if FileExist(currentFile)
                                FileDelete(currentFile)
                        }
                        else if (currentFile != "")
                            FileAppend(line "`n", currentFile)
                    }
                    StatusText.Value := "Duomenys atsisiųsti iš Gist."
                }
                else
                    StatusText.Value := "Gist failas nerastas."
            }
            else
                StatusText.Value := "Gist atsisiuntimo klaida: " req.Status
        }
        else if (mode == "up")
        {
            payload := ""
            Loop Files, LOG_DIR "\*.ini"
            {
                payload .= "[FILE:" A_LoopFileName "]`n"
                payload .= FileRead(A_LoopFileFullPath) "`n"
            }
            jsonPayload := StrReplace(payload, '\', '\\')
            jsonPayload := StrReplace(jsonPayload, '"', '\"')
            jsonPayload := StrReplace(jsonPayload, "`r`n", "\n")
            jsonPayload := StrReplace(jsonPayload, "`n", "\n")
            body := '{"files":{"logas.txt":{"content":"' jsonPayload '"}}}'

            req.Open("PATCH", url, false)
            req.SetRequestHeader("Authorization", "token " GIST_TOKEN)
            req.SetRequestHeader("Content-Type", "application/json")
            req.Send(body)

            if (req.Status == 200)
                StatusText.Value := "Duomenys išsiųsti į Gist."
            else
                StatusText.Value := "Gist išsiuntimo klaida: " req.Status
        }
    }
    catch Error as e
    {
        StatusText.Value := "Gist klaida: " e.Message
    }
}

SaveAndSync()
{
    SaveAll()
    SyncGist("up")
}

FetchTSData(channel, start_dt, end_dt)
{
    key := READ_KEYS.Has(channel) ? READ_KEYS[channel] : ""
    url := "https://api.thingspeak.com/channels/" channel "/feeds.json?api_key=" key "&start=" StrReplace(start_dt, " ", "T") "&end=" StrReplace(end_dt, " ", "T") "&timezone=Europe/Vilnius"
    StatusText.Value := "Kraunama iš ThingSpeak (" channel ")..."
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try
    {
        req.Open("GET", url, true)
        req.Send()
        req.WaitForResponse()
        if (req.Status == 200)
            return req.ResponseText
    }
    catch Error as e
        StatusText.Value := "Klaida: " e.Message
    return ""
}

ParseFeeds(jsonStr)
{
    feeds := []
    pos := 1
    while pos := RegExMatch(jsonStr, '\{"created_at":"[^"]+"[^}]*\}', &match, pos)
    {
        objStr := match[0], obj := Map()
        if RegExMatch(objStr, '"created_at":"([^"]+)"', &m)
            obj["created_at"] := m[1]
        Loop 8
        {
            fName := "field" A_Index
            if RegExMatch(objStr, '"' fName '":"?([^",}]*)"?', &m)
            {
                val := m[1]
                obj[fName] := (val == "null") ? "" : val
            }
            else
                obj[fName] := ""
        }
        feeds.Push(obj)
        pos += match.Len
    }
    return feeds
}

CalculateDelta(feeds, fieldName)
{
    if (feeds.Length < 2)
        return 0
    vals := []
    for index, f in feeds
    {
        val := f.Has(fieldName) ? f[fieldName] : ""
        if (val != "" && val != "null")
        {
            try
                vals.Push(Float(val))
            catch
                continue
        }
    }
    if (vals.Length < 2)
        return 0
    total := 0, loopCount := vals.Length - 1
    Loop loopCount
    {
        diff := vals[A_Index + 1] - vals[A_Index]
        if (diff > 0)
            total += diff
    }
    return Integer(total)
}

GetLastVal(feeds, fieldName)
{
    idx := feeds.Length
    while (idx > 0)
    {
        val := feeds[idx].Has(fieldName) ? feeds[idx][fieldName] : ""
        if (val != "" && val != "null")
            return val
        idx--
    }
    return ""
}

LoadDateData()
{
    global MainGui, StatusText, Controls, INTERVALS, LOG_DIR
    dateStr := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")
    StatusText.Value := "Kraunami duomenys datai: " dateStr
    iniPath := LOG_DIR "\" dateStr ".ini"
    for lineName, data in Controls
    {
        Loop (INTERVALS.Length)
        {
            idx := A_Index
            data.intervals[idx].Plan.Value := IniRead(iniPath, lineName, "Plan_" idx, "")
            data.intervals[idx].Fact.Value := IniRead(iniPath, lineName, "Fact_" idx, "")
            data.intervals[idx].Prod.Value := IniRead(iniPath, lineName, "Prod_" idx, "")
            data.intervals[idx].Comm.Value := IniRead(iniPath, lineName, "Comm_" idx, "")
        }
    }
    UpdateCalculations()
    if (dateStr == FormatTime(A_Now, "yyyy-MM-dd"))
        FetchTodayData()
    else
        StatusText.Value := "Duomenys užkrauti iš log (" dateStr ")."
}

FetchTodayData()
{
    global MainGui, StatusText, LINES, INTERVALS, Controls
    selDate := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")
    StatusText.Value := "Jungiamasi prie ThingSpeak..."
    channels := Map()
    for index, line in LINES
    {
        if !channels.Has(line.channel)
            channels[line.channel] := []
        channels[line.channel].Push(line)
    }
    for channel, linesInChannel in channels
    {
        rawSelDate := StrReplace(selDate, "-", ""), lookbackDate := DateAdd(rawSelDate "000000", -3, "Days")
        startDT := FormatTime(lookbackDate, "yyyy-MM-dd HH:mm:ss"), endDT := selDate " 16:00:00"
        json := FetchTSData(channel, startDT, endDT)
        if (json == "")
            continue
        allFeeds := ParseFeeds(json)
        for index, line in linesInChannel
        {
            for intIdx, interval in INTERVALS
            {
                iStart := selDate " " interval[1] ":00", iEnd := selDate " " interval[2] ":00"
                intFeeds := FilterFeedsByTime(allFeeds, iStart, iEnd)
                produced := CalculateDelta(intFeeds, "field" line.fieldCount)
                feedsUpToNow := FilterFeedsByTime(allFeeds, startDT, iEnd)
                barcode := (line.fieldBarcode) ? GetLastVal(feedsUpToNow, "field" line.fieldBarcode) : ""
                if (line.name == "UI perrašymas")
                    barcode := "UI v5"
                else if (barcode != "")
                    barcode := "X-" barcode
                Controls[line.name].intervals[intIdx].Fact.Value := produced
                if (barcode != "")
                    Controls[line.name].intervals[intIdx].Prod.Value := barcode
                SaveToCache(selDate, line.name, intIdx, "Fact", produced)
                if (barcode != "")
                    SaveToCache(selDate, line.name, intIdx, "Prod", barcode)
            }
        }
    }
    UpdateCalculations()
    StatusText.Value := "Atnaujinimas baigtas: " FormatTime(, "HH:mm:ss")
}

FilterFeedsByTime(feeds, startT, endT)
{
    filtered := [], s := StrReplace(StrReplace(StrReplace(startT, "-", ""), " ", ""), ":", ""), e := StrReplace(StrReplace(StrReplace(endT, "-", ""), " ", ""), ":", "")
    for index, f in feeds
    {
        ft := StrReplace(StrReplace(StrReplace(SubStr(f["created_at"], 1, 19), "-", ""), "T", ""), ":", "")
        if (ft >= s && ft <= e)
            filtered.Push(f)
    }
    return filtered
}

SaveToCache(dateStr, lineName, idx, type, value)
{
    IniWrite(value, LOG_DIR "\" dateStr ".ini", lineName, type "_" idx)
}

SaveManualInput(lineName, intervalIdx, type, value)
{
    SaveToCache(FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd"), lineName, intervalIdx, type, value)
}

SaveAll()
{
    global MainGui, StatusText, Controls, INTERVALS
    dateStr := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")
    StatusText.Value := "Saugoma..."
    for lineName, data in Controls
    {
        Loop (INTERVALS.Length)
        {
            idx := A_Index, ctrls := data.intervals[idx]
            SaveToCache(dateStr, lineName, idx, "Plan", ctrls.Plan.Value)
            SaveToCache(dateStr, lineName, idx, "Fact", ctrls.Fact.Value)
            SaveToCache(dateStr, lineName, idx, "Prod", ctrls.Prod.Value)
            SaveToCache(dateStr, lineName, idx, "Comm", ctrls.Comm.Value)
        }
    }
    StatusText.Value := "Visi duomenys išsaugoti (" dateStr ")."
    SoundBeep(750, 200)
}

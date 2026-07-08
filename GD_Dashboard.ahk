#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
Global CURRENT_VERSION := "1.3"
Global LOG_DIR := A_ScriptDir "\logs"
if !DirExist(LOG_DIR)
    DirCreate(LOG_DIR)

Global READ_KEYS := Map(
    "463450", "VAL3TD2W5LADX7K1", ; PLXE 1-4
    "703669", "S44OBKWC5C7FODZ5", ; NOBO 1-4
    "802414", "I6NIZAVZYLPVV1ME", ; NOBO 5-7, PLXE 5
    "807602", "WUO1DG7GXYNZP6SG"  ; QRAD, XLE, UI perrašymas
)

Global LINES := [
    {name: "PLXE 1",    channel: "463450", fieldCount: 1, fieldBarcode: 2, color: "C6EFCE"},
    {name: "PLXE 2",    channel: "463450", fieldCount: 3, fieldBarcode: 4, color: "FFCCFF"},
    {name: "PLXE 3",    channel: "463450", fieldCount: 5, fieldBarcode: 6, color: "FFCCFF"},
    {name: "PLXE 4",    channel: "463450", fieldCount: 7, fieldBarcode: 8, color: "FFCCFF"},
    {name: "QRAD 1",    channel: "807602", fieldCount: 3, fieldBarcode: 4, color: "CCFFFF"},
    {name: "NOBO 1",    channel: "703669", fieldCount: 1, fieldBarcode: 2, color: "E2EFDA"},
    {name: "NOBO 2",    channel: "703669", fieldCount: 3, fieldBarcode: 4, color: "E2EFDA"},
    {name: "NOBO 3",    channel: "703669", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA"},
    {name: "NOBO 4",    channel: "703669", fieldCount: 7, fieldBarcode: 8, color: "E2EFDA"},
    {name: "NOBO 5",    channel: "802414", fieldCount: 1, fieldBarcode: 2, color: "E2EFDA"},
    {name: "NOBO 6",    channel: "802414", fieldCount: 3, fieldBarcode: 4, color: "E2EFDA"},
    {name: "NOBO 7",    channel: "802414", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA"},
    {name: "PLXE 5",    channel: "802414", fieldCount: 7, fieldBarcode: 8, color: "C6EFCE"},
    {name: "XLE 1",     channel: "807602", fieldCount: 5, fieldBarcode: 6, color: "E2EFDA"},
    {name: "XLE ReWork",channel: "807602", fieldCount: 7, fieldBarcode: 8, color: "E2EFDA"},
    {name: "UI perrašymas", channel: "807602", fieldCount: 1, fieldBarcode: 0, color: "E2EFDA"}
]

Global INTERVALS := [
    ["06:00", "07:00"], ["07:00", "08:00"], ["08:00", "09:00"], ["09:10", "10:00"],
    ["10:00", "11:00"], ["11:30", "12:00"], ["12:00", "13:00"], ["13:00", "14:00"],
    ["14:10", "15:00"], ["15:00", "16:00"]
]

; Theme Definitions
Global THEMES := Map(
    "Šviesi", {bg: "White", txt: "cBlack", edit: "BackgroundWhite cBlack"},
    "Tamsi",  {bg: "1A1A1A", txt: "cWhite", edit: "Background333333 cWhite"},
    "Pilka",  {bg: "444444", txt: "cWhite", edit: "Background666666 cWhite"},
    "Mėlyna", {bg: "001F3F", txt: "cWhite", edit: "Background003366 cWhite"},
    "Žalia",  {bg: "1B3022", txt: "cWhite", edit: "Background2D4C38 cWhite"}
)

; =======================================================
; GUI CONSTRUCTION
; =======================================================
MainGui := Gui("+Resize", "GD Gamybos Dashboard v" CURRENT_VERSION)
MainGui.SetFont("s9", "Segoe UI")

MainGui.Add("Text", "x10 y15", "Pasirinkite datą:")
Calendar := MainGui.Add("DateTime", "x110 y10 w150 vSelectedDate", "yyyy-MM-dd")
Calendar.OnEvent("Change", (*) => LoadDateData())

BtnRefresh := MainGui.Add("Button", "x270 y10 w100", "Atnaujinti")
BtnRefresh.OnEvent("Click", (*) => FetchTodayData())

MainGui.Add("Text", "x380 y15", "Tema:")
ThemeList := ["Šviesi", "Tamsi", "Pilka", "Mėlyna", "Žalia"]
ThemeSelector := MainGui.Add("DropDownList", "x425 y10 w100 Choose1", ThemeList)
ThemeSelector.OnEvent("Change", (ctrl, *) => ApplyTheme(ctrl.Text))

BtnSaveAll := MainGui.Add("Button", "x535 y10 w120", "Saugoti viską")
BtnSaveAll.OnEvent("Click", (*) => SaveAll())

StatusText := MainGui.Add("Text", "x665 y15 w400 vStatus", "Pasiruošęs")

; Headers outside of tabs for visibility
MainGui.SetFont("s9 bold")
Loop INTERVALS.Length {
    X := 220 + (A_Index-1) * 88
    MainGui.Add("Text", "x" X " y" 55 " w85 h20 Center", INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2])
}
X := 220 + INTERVALS.Length * 88
MainGui.Add("Text", "x" X " y" 55 " w85 h20 Center", "Viso")
MainGui.SetFont("s9 norm")

Tabs := MainGui.Add("Tab3", "x10 y80 w1180 h900", ["PLXE", "NOBO", "Kiti"])

; Store control references for easy access
Global Controls := Map()

ApplyTheme(themeName) {
    global THEMES, MainGui
    if !THEMES.Has(themeName)
        return

    theme := THEMES[themeName]
    MainGui.BackColor := theme.bg

    for hwnd, ctrl in MainGui {
        try {
            if (ctrl is Gui.Text) {
                ctrl.Opt(theme.txt " Background" theme.bg)
            } else if (ctrl is Gui.Edit) {
                if InStr(ctrl.Name, "_F") || InStr(ctrl.Name, "_Total") {
                    ctrl.Opt("cBlack")
                } else {
                    ctrl.Opt(theme.edit)
                }
            } else if (ctrl is Gui.Tab) {
                ctrl.Opt(theme.txt)
            }
        }
        try ctrl.Redraw()
    }
}

CreateLineGrid(LineObj, YPos, TabIdx) {
    global Controls, Tabs
    name := LineObj.name
    safeName := RegExReplace(name, "[ \-]", "_")

    Tabs.UseTab(TabIdx)

    MainGui.SetFont("s10 bold")
    MainGui.Add("Text", "x20 y" YPos " w120 h20", name)
    MainGui.SetFont("s9 norm")

    MainGui.Add("Text", "x150 y" YPos " w60 h20", "Planas")
    MainGui.Add("Text", "x150 y" YPos+25 " w60 h20", "Faktas")
    MainGui.Add("Text", "x150 y" YPos+50 " w60 h20", "Gaminys")
    MainGui.Add("Text", "x150 y" YPos+75 " w60 h20", "Komment.")

    lineCtrls := []
    Loop INTERVALS.Length {
        idx := A_Index
        X := 220 + (idx-1) * 88

        cPlan := MainGui.Add("Edit", "x" X " y" YPos " w85 h22 Center v" safeName "_P" idx)
        cFact := MainGui.Add("Edit", "x" X " y" YPos+25 " w85 h22 Center ReadOnly v" safeName "_F" idx)
        cProd := MainGui.Add("Edit", "x" X " y" YPos+50 " w85 h22 Center ReadOnly v" safeName "_G" idx)
        cComm := MainGui.Add("Edit", "x" X " y" YPos+75 " w85 h22 Center v" safeName "_K" idx)

        cFact.Opt("Background" SubStr(LineObj.color, -6))

        lineCtrls.Push({Plan: cPlan, Fact: cFact, Prod: cProd, Comm: cComm})

        cPlan.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Plan", ctrl.Value))
        cComm.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Comm", ctrl.Value))
    }

    ; Add Total column
    X := 220 + INTERVALS.Length * 88
    MainGui.SetFont("bold")
    cTotal := MainGui.Add("Edit", "x" X " y" YPos+25 " w85 h22 Center ReadOnly v" safeName "_Total")
    MainGui.SetFont("norm")

    Controls[name] := {intervals: lineCtrls, total: cTotal}
}

; Populate Tabs
; PLXE (1-5)
Y := 20
for line in LINES {
    if InStr(line.name, "PLXE") {
        CreateLineGrid(line, Y, 1)
        Y += 120
    }
}

; NOBO (1-7)
Y := 20
for line in LINES {
    if InStr(line.name, "NOBO") {
        CreateLineGrid(line, Y, 2)
        Y += 120
    }
}

; Kiti (QRAD, XLE, UI)
Y := 20
for line in LINES {
    if !InStr(line.name, "PLXE") && !InStr(line.name, "NOBO") {
        CreateLineGrid(line, Y, 3)
        Y += 120
    }
}

MainGui.Show("w1200 h1000")
ApplyTheme("Šviesi")
LoadDateData()

; Auto-refresh every 5 minutes
SetTimer AutoRefresh, 300000

AutoRefresh() {
    dateStr := FormatTime(A_Now, "yyyy-MM-dd")
    selDate := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")

    ; Only auto-refresh if we are looking at today
    if (selDate == dateStr) {
        FetchTodayData()
    }
}

; =======================================================
; DATA FETCHING & PROCESSING
; =======================================================

FetchTSData(channel, start_dt, end_dt) {
    key := READ_KEYS.Has(channel) ? READ_KEYS[channel] : ""
    url := "https://api.thingspeak.com/channels/" channel "/feeds.json"
    url .= "?api_key=" key
    url .= "&start=" StrReplace(start_dt, " ", "T")
    url .= "&end=" StrReplace(end_dt, " ", "T")
    url .= "&timezone=Europe/Vilnius"

    StatusText.Value := "Kraunama iš ThingSpeak (Kanalas: " channel ")..."

    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, true)
        req.Send()
        req.WaitForResponse()
        if (req.Status == 200) {
            return req.ResponseText
        }
    } catch Error as e {
        StatusText.Value := "Klaida: " e.Message
    }
    return ""
}

; Improved JSON parser to extract feeds array using RegEx
ParseFeeds(jsonStr) {
    feeds := []
    pos := 1
    while pos := RegExMatch(jsonStr, '\{"created_at":"[^"]+"[^}]*\}', &match, pos) {
        objStr := match[0]
        obj := Map()

        if RegExMatch(objStr, '"created_at":"([^"]+)"', &m)
            obj["created_at"] := m[1]

        Loop 8 {
            fName := "field" A_Index
            if RegExMatch(objStr, '"' fName '":"?([^",}]*)"?', &m) {
                val := m[1]
                if (val == "null")
                    val := ""
                obj[fName] := val
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
    if (feeds.Length < 2)
        return 0

    vals := []
    for f in feeds {
        val := f.Has(fieldName) ? f[fieldName] : ""
        if (val != "" && val != "null") {
            try {
                vals.Push(Float(val))
            }
        }
    }

    if (vals.Length < 2)
        return 0

    total := 0
    Loop vals.Length - 1 {
        diff := vals[A_Index + 1] - vals[A_Index]
        if (diff > 0)
            total += diff
    }
    return Integer(total)
}

GetLastVal(feeds, fieldName) {
    idx := feeds.Length
    while (idx > 0) {
        val := feeds[idx].Has(fieldName) ? feeds[idx][fieldName] : ""
        if (val != "" && val != "null")
            return val
        idx--
    }
    return ""
}

; =======================================================
; UI UPDATE & CACHING
; =======================================================

LoadDateData() {
    dateStr := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")
    StatusText.Value := "Kraunami duomenys datai: " dateStr

    iniPath := LOG_DIR "\" dateStr ".ini"

    for lineName, data in Controls {
        totalFact := 0
        Loop INTERVALS.Length {
            idx := A_Index

            plan := IniRead(iniPath, lineName, "Plan_" idx, "")
            fact := IniRead(iniPath, lineName, "Fact_" idx, "")
            prod := IniRead(iniPath, lineName, "Prod_" idx, "")
            comm := IniRead(iniPath, lineName, "Comm_" idx, "")

            data.intervals[idx].Plan.Value := plan
            data.intervals[idx].Fact.Value := fact
            data.intervals[idx].Prod.Value := prod
            data.intervals[idx].Comm.Value := comm

            if (fact != "" && IsNumber(fact))
                totalFact += fact
        }
        data.total.Value := totalFact
    }

    today := FormatTime(A_Now, "yyyy-MM-dd")
    if (dateStr == today) {
        FetchTodayData()
    } else {
        StatusText.Value := "Duomenys užkrauti iš log (" dateStr ")."
    }
}

FetchTodayData() {
    dateStr := FormatTime(A_Now, "yyyy-MM-dd")
    selDate := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")

    if (selDate != dateStr) {
        if (MsgBox("Pasirinkta ne šiandienos data. Ar tikrai norite atnaujinti iš ThingSpeak?", "Patvirtinimas", 4) == "No")
            return
    }

    StatusText.Value := "Jungiamasi prie ThingSpeak..."

    channels := Map()
    for line in LINES {
        if !channels.Has(line.channel)
            channels[line.channel] := []
        channels[line.channel].Push(line)
    }

    for channel, linesInChannel in channels {
        rawSelDate := StrReplace(selDate, "-", "")
        lookbackDate := DateAdd(rawSelDate "000000", -3, "Days")
        startDT := FormatTime(lookbackDate, "yyyy-MM-dd HH:mm:ss")
        endDT := selDate " 16:00:00"

        json := FetchTSData(channel, startDT, endDT)
        if (json == "")
            continue

        allFeeds := ParseFeeds(json)

        for line in linesInChannel {
            StatusText.Value := "Apdorojama: " line.name

            for intIdx, interval in INTERVALS {
                iStart := selDate " " interval[1] ":00"
                iEnd := selDate " " interval[2] ":00"

                intFeeds := FilterFeedsByTime(allFeeds, iStart, iEnd)
                produced := CalculateDelta(intFeeds, "field" line.fieldCount)

                feedsUpToNow := FilterFeedsByTime(allFeeds, startDT, iEnd)
                barcode := ""
                if (line.fieldBarcode)
                    barcode := GetLastVal(feedsUpToNow, "field" line.fieldBarcode)

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

            total := 0
            for intInfo in Controls[line.name].intervals {
                val := intInfo.Fact.Value
                if (val != "" && IsNumber(val))
                    total += val
            }
            Controls[line.name].total.Value := total
        }
    }
    StatusText.Value := "Atnaujinimas baigtas: " FormatTime(, "HH:mm:ss")
}

FilterFeedsByTime(feeds, startT, endT) {
    filtered := []
    s := StrReplace(StrReplace(StrReplace(startT, "-", ""), " ", ""), ":", "")
    e := StrReplace(StrReplace(StrReplace(endT, "-", ""), " ", ""), ":", "")

    for f in feeds {
        ft := f["created_at"]
        ft := StrReplace(StrReplace(StrReplace(SubStr(ft, 1, 19), "-", ""), "T", ""), ":", "")
        if (ft >= s && ft <= e)
            filtered.Push(f)
    }
    return filtered
}

SaveToCache(dateStr, lineName, idx, type, value) {
    iniPath := LOG_DIR "\" dateStr ".ini"
    IniWrite(value, iniPath, lineName, type "_" idx)
}

SaveManualInput(lineName, intervalIdx, type, value) {
    dateStr := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")
    SaveToCache(dateStr, lineName, intervalIdx, type, value)
}

SaveAll() {
    dateStr := FormatTime(MainGui["SelectedDate"].Value, "yyyy-MM-dd")
    StatusText.Value := "Saugoma..."

    for lineName, data in Controls {
        Loop INTERVALS.Length {
            idx := A_Index
            ctrls := data.intervals[idx]

            SaveToCache(dateStr, lineName, idx, "Plan", ctrls.Plan.Value)
            SaveToCache(dateStr, lineName, idx, "Fact", ctrls.Fact.Value)
            SaveToCache(dateStr, lineName, idx, "Prod", ctrls.Prod.Value)
            SaveToCache(dateStr, lineName, idx, "Comm", ctrls.Comm.Value)
        }
    }
    StatusText.Value := "Visi duomenys išsaugoti (" dateStr ")."
    SoundBeep 750, 200
}

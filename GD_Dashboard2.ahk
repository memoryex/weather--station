#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
Global CURRENT_VERSION := "4.0 (Robust Sync)"
Global LOG_DIR := A_ScriptDir "\logs"
if !DirExist(LOG_DIR)
    DirCreate(LOG_DIR)

; Configuration (Loaded from config.ini)
Global CONFIG_FILE := A_ScriptDir "\config.ini"
Global GIST_ID := "bca7d49ac0724f650842b0e7c691a1c1"
Global GIST_TOKEN := ""
Global READ_KEYS := Map()

if FileExist(CONFIG_FILE)
{
    try
    {
        GIST_TOKEN := IniRead(CONFIG_FILE, "Gist", "Token", "")
        for ch in ["463450", "703669", "802414", "807602"]
            READ_KEYS[ch] := IniRead(CONFIG_FILE, "ThingSpeak", "Key_" ch, "")
    }
}

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
GetNum(Value)
{
    if IsNumber(Value)
        return Value
    str := String(Value)
    if (str == "")
        return 0
    clean := RegExReplace(str, "[^\d\.]")
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
Global MainGui := Gui("+Resize", "GD Gamybos Dashboard v" CURRENT_VERSION)
MainGui.SetFont("s9", "Segoe UI")

MainGui.Add("Text", "x10 y15", "Pasirinkite datą:")
Global Calendar := MainGui.Add("DateTime", "x110 y10 w150", "yyyy-MM-dd")
Calendar.OnEvent("Change", (ctrl, *) => LoadDateData())

BtnRefresh := MainGui.Add("Button", "x270 y10 w100", "Atnaujinti")
BtnRefresh.OnEvent("Click", (ctrl, *) => (SyncGist("down"), LoadDateData(true), RefreshDataFromTS()))

BtnSaveAll := MainGui.Add("Button", "x380 y10 w120", "Saugoti viską")
BtnSaveAll.OnEvent("Click", (ctrl, *) => SaveAndSync())

BtnExport := MainGui.Add("Button", "x510 y10 w120", "Eksportuoti Excel")
BtnExport.OnEvent("Click", (ctrl, *) => ExportToExcel())

Global StatusText := MainGui.Add("Text", "x645 y15 w600", "Pasiruošęs")

Global Tabs := MainGui.Add("Tab3", "x10 y50 w1520 h35", ["PLXE", "NOBO", "Kiti"])
Tabs.OnEvent("Change", OnTabChange)

Global ChildGuis := Map()
Global ActiveChild := ""
Global Controls := Map()
Global TabFooters := Map()
Global CommHwnds := Map()

AddIntervalHeaders(TargetGui, YPos)
{
    global INTERVALS
    TargetGui.SetFont("s9 bold")
    Loop (INTERVALS.Length)
    {
        X := 230 + (A_Index-1) * 95
        TargetGui.Add("Text", "x" X " y" YPos " w90 h20 Center", INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2])
    }
    TargetGui.Add("Text", "x" (230 + INTERVALS.Length * 95) " y" YPos " w90 h20 Center", "Viso")
    TargetGui.Add("Text", "x" (230 + (INTERVALS.Length + 1) * 95) " y" YPos " w90 h20 Center", "Vidurkis")
    TargetGui.SetFont("s9 norm")
}

CreateLineGrid(TargetGui, LineObj, YPos)
{
    global Controls, INTERVALS, CommHwnds
    name := LineObj.name

    TargetGui.SetFont("s10 bold")
    TargetGui.Add("Text", "x15 y" YPos " w100 h20", name)
    TargetGui.SetFont("s9 bold")
    TargetGui.Add("Text", "x125 y" YPos " w95 h20", "Planas")
    TargetGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Faktas")
    TargetGui.Add("Text", "x125 y" YPos+46 " w95 h20", "Gaminys")
    TargetGui.Add("Text", "x125 y" YPos+69 " w95 h20", "Komentaras")
    TargetGui.SetFont("s9 norm")

    lineCtrls := []
    Loop (INTERVALS.Length)
    {
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

    Controls[name] := {intervals: lineCtrls, planTotal: cPlanTotal, planAvg: cPlanAvg, factTotal: cFactTotal, factAvg: cFactAvg, tab: LineObj.tab}
}

CreateTabFooter(TargetGui, TabName, YPos)
{
    global TabFooters, INTERVALS
    fH := [], pH := [], pcH := []
    TargetGui.SetFont("s9 bold")
    TargetGui.Add("Text", "x125 y" YPos " w95 h20", "Faktas")
    TargetGui.Add("Text", "x15 y" YPos+23 " w100 h20", "Tikslas:")
    TargetGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Planas")

    Loop (INTERVALS.Length)
    {
        X := 230 + (A_Index-1) * 95
        fH.Push(TargetGui.Add("Edit", "x" X " y" YPos " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(TargetGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(TargetGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center ReadOnly +0x800 BackgroundWhite"))
    }
    TargetGui.SetFont("s32 bold")
    cGrand := TargetGui.Add("Edit", "x1380 y" YPos-5 " w130 h80 Center ReadOnly Border")
    TargetGui.SetFont("s9 norm")
    TabFooters[TabName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGrand}
}

headerY := 5, contentStartY := 35, lineStep := 120, footerGap := 40
for tName in ["PLXE", "NOBO", "Kiti"]
{
    cG := Gui("-Caption +Parent" MainGui.Hwnd " +0x00200000")
    cG.BackColor := "White"
    AddIntervalHeaders(cG, headerY)
    Y := contentStartY
    for line in LINES
    {
        if (line.tab == tName)
            CreateLineGrid(cG, line, Y), Y += lineStep
    }
    CreateTabFooter(cG, tName, Y + footerGap)
    ChildGuis[tName] := cG
}

OnTabChange(ctrl, *)
{
    global ActiveChild, ChildGuis
    if (ActiveChild != "")
        ChildGuis[ActiveChild].Hide()
    MainGui.GetClientPos(,, &guiW, &guiH)
    ChildGuis[ctrl.Text].Show("x10 y85 w" (guiW - 20) " h" (guiH - 90))
    ActiveChild := ctrl.Text
    UpdateScrollBars(ChildGuis[ActiveChild])
}

MainGui.OnEvent("Size", (guiObj, minMax, width, height) => (minMax != -1 && (Tabs.Move(,, width - 20), (ActiveChild != "" && (ChildGuis[ActiveChild].Show("w" (width - 20) " h" (height - 90)), UpdateScrollBars(ChildGuis[ActiveChild]))))))
MainGui.Show("w1540 h1040")
OnTabChange(Tabs)

OnMessage(0x0115, OnScroll), OnMessage(0x020A, OnWheel)

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

UpdateCalculations()
{
    global Controls, TabFooters, INTERVALS
    stats := Map()
    for t in ["PLXE", "NOBO", "Kiti"]
        stats[t] := {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0}

    for name, data in Controls
    {
        lineTotalFact := 0, lineTotalPlan := 0, activeFact := 0, activePlan := 0
        for idx, int in data.intervals
        {
            p := GetNum(int.Plan.Value), f := GetNum(int.Fact.Value)
            stats[data.tab].Plan[idx] += p, stats[data.tab].Fact[idx] += f
            lineTotalPlan += p, lineTotalFact += f
            if (f > 0) activeFact++
            if (p > 0) activePlan++
            if (p > 0) {
                int.Plan.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
                int.Fact.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
            } else {
                int.Plan.Opt("BackgroundWhite"), int.Fact.Opt("BackgroundWhite")
            }
            int.Plan.Redraw(), int.Fact.Redraw()
        }
        data.planTotal.Value := lineTotalPlan, data.factTotal.Value := lineTotalFact, stats[data.tab].Grand += lineTotalFact
        data.planAvg.Value := activePlan > 0 ? Round(lineTotalPlan / activePlan, 1) : 0
        data.factAvg.Value := activeFact > 0 ? Round(lineTotalFact / activeFact, 1) : 0
    }
    for t, d in stats {
        if TabFooters.Has(t) {
            f := TabFooters[t]
            Loop (INTERVALS.Length) {
                fv := d.Fact[A_Index], pv := d.Plan[A_Index]
                f.Fact[A_Index].Value := fv, f.Plan[A_Index].Value := pv
                pct := pv > 0 ? Round((fv/pv-1)*100) : 0
                f.Pct[A_Index].Value := (pct > 0 ? "+" : "") pct "%"
            }
            f.Grand.Value := d.Grand
        }
    }
}

SyncGist(mode)
{
    global GIST_ID, GIST_TOKEN, LOG_DIR, StatusText
    if (GIST_TOKEN == "") {
        StatusText.Value := "Gist Token nerastas config.ini"
        return
    }
    url := "https://api.github.com/gists/" GIST_ID
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        if (mode == "down") {
            StatusText.Value := "Siunčiama iš debesies..."
            req.Open("GET", url, false)
            req.SetRequestHeader("Authorization", "Bearer " GIST_TOKEN)
            req.Send()
            if (req.Status == 200) {
                res := req.ResponseText
                if RegExMatch(res, 's)"logas\.txt":\s*\{.*?"content":\s*"((?:[^"\\]|\\.)*)"', &m) {
                    content := m[1]
                    content := StrReplace(content, "\\", "[[BS]]"), content := StrReplace(content, "\n", "`n"), content := StrReplace(content, "\r", "`r")
                    content := StrReplace(content, "\t", "`t"), content := StrReplace(content, '\"', '"'), content := StrReplace(content, "[[BS]]", "\")
                    if (InStr(content, "[FILE:")) {
                        fileCount := 0, currentFile := "", fileBuffer := ""
                        Loop Parse, content, "`n", "`r" {
                            line := Trim(A_LoopField, " `t")
                            if RegExMatch(line, "^\[FILE:(.+)\]$", &fm) {
                                if (currentFile != "") {
                                    if FileExist(currentFile)
                                        FileDelete(currentFile)
                                    FileAppend(RTrim(fileBuffer, "`n`r"), currentFile, "UTF-8"), fileCount++
                                }
                                currentFile := LOG_DIR "\" fm[1], fileBuffer := ""
                            } else if (currentFile != "")
                                fileBuffer .= A_LoopField "`r`n"
                        }
                        if (currentFile != "") {
                            if FileExist(currentFile)
                                FileDelete(currentFile)
                            FileAppend(RTrim(fileBuffer, "`n`r"), currentFile, "UTF-8"), fileCount++
                        }
                        StatusText.Value := "Sinchronizuota (" fileCount " failai)."
                    } else StatusText.Value := "Gist turinys tuščias."
                } else StatusText.Value := "Gist failas nerastas."
            } else StatusText.Value := "Gist klaida: " req.Status
        } else if (mode == "up") {
            StatusText.Value := "Siunčiama į debesį..."
            payload := "", fileCount := 0
            Loop Files, LOG_DIR "\*.ini" {
                payload .= "[FILE:" A_LoopFileName "]`n" FileRead(A_LoopFileFullPath) "`n", fileCount++
            }
            if (fileCount == 0) {
                StatusText.Value := "Nėra duomenų logs aplanke."
                return
            }
            jsonPayload := StrReplace(payload, "\", "\\"), jsonPayload := StrReplace(jsonPayload, '"', '\"')
            jsonPayload := StrReplace(jsonPayload, "`r`n", "\n"), jsonPayload := StrReplace(jsonPayload, "`n", "\n")
            body := '{"files":{"logas.txt":{"content":"' jsonPayload '"}}}'
            req.Open("PATCH", url, false), req.SetRequestHeader("Authorization", "Bearer " GIST_TOKEN), req.SetRequestHeader("Content-Type", "application/json"), req.Send(body)
            if (req.Status == 200) StatusText.Value := "Įkelta į debesį (" fileCount ")."
            else StatusText.Value := "Įkėlimo klaida: " req.Status
        }
    } catch Error as e
        StatusText.Value := "Klaida: " e.Message
}

SaveAndSync() {
    SaveAll()
    SyncGist("up")
}

FetchTSData(channel, start_dt, end_dt) {
    global READ_KEYS
    key := READ_KEYS.Has(channel) ? READ_KEYS[channel] : ""
    url := "https://api.thingspeak.com/channels/" channel "/feeds.json?api_key=" key "&start=" StrReplace(start_dt, " ", "T") "&end=" StrReplace(end_dt, " ", "T") "&timezone=Europe/Vilnius"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, true), req.Send()
        if (req.WaitForResponse(10)) {
            if (req.Status == 200) return req.ResponseText
        }
    }
    return ""
}

ParseFeeds(jsonStr) {
    feeds := []
    pos := 1
    while pos := RegExMatch(jsonStr, '\{"created_at":"[^"]+"[^}]*\}', &match, pos) {
        objStr := match[0], obj := Map()
        if RegExMatch(objStr, '"created_at":"([^"]+)"', &m)
            obj["created_at"] := m[1]
        Loop 8 {
            fName := "field" A_Index
            if RegExMatch(objStr, '"' fName '":"?([^",}]*)"?', &m)
                obj[fName] := (m[1] == "null") ? "" : m[1]
            else obj[fName] := ""
        }
        feeds.Push(obj), pos += match.Len
    }
    return feeds
}

CalculateDelta(feeds, fieldName) {
    if (feeds.Length < 2) return 0
    vals := []
    for index, f in feeds {
        val := f.Has(fieldName) ? f[fieldName] : ""
        if (val != "" && val != "null") {
            try vals.Push(Float(val))
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

GetLastVal(feeds, fieldName) {
    idx := feeds.Length
    while (idx > 0) {
        val := feeds[idx].Has(fieldName) ? feeds[idx][fieldName] : ""
        if (val != "" && val != "null") return val
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
        if (ft >= s && ft <= e) filtered.Push(f)
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
            idx := A_Index, int := data.intervals[idx]
            int.Plan.Value := IniRead(iniPath, name, "Plan_" idx, "")
            int.Fact.Value := IniRead(iniPath, name, "Fact_" idx, "")
            int.Prod.Value := IniRead(iniPath, name, "Prod_" idx, "")
            int.Comm.Value := IniRead(iniPath, name, "Comm_" idx, "")
            if (int.Prod.Value != "" && (SubStr(int.Prod.Value, 1, 2) == "X-" || int.Prod.Value == "UI v5"))
                int.Prod.Opt("+ReadOnly")
            else int.Prod.Opt("-ReadOnly")
        }
    }
    UpdateCalculations()
    if (dateStr == FormatTime(A_Now, "yyyy-MM-dd") || !FileExist(iniPath) || forceRefresh)
        RefreshDataFromTS(dateStr)
}

RefreshDataFromTS(targetDate := "") {
    global Calendar, StatusText, LINES, INTERVALS, Controls
    targetDate := targetDate == "" ? FormatTime(Calendar.Value, "yyyy-MM-dd") : targetDate
    StatusText.Value := "Siunčiama iš ThingSpeak..."
    channels := Map()
    for l in LINES {
        if !channels.Has(l.channel) channels[l.channel] := []
        channels[l.channel].Push(l)
    }
    today := FormatTime(A_Now, "yyyy-MM-dd"), nowT := FormatTime(A_Now, "HH:mm")
    for ch, lines in channels {
        rawSelDate := StrReplace(targetDate, "-", ""), lookback := DateAdd(rawSelDate "000000", -3, "Days")
        startDT := FormatTime(lookback, "yyyy-MM-dd HH:mm:ss"), endDT := targetDate " 16:00:00"
        json := FetchTSData(ch, startDT, endDT)
        if (json == "") continue
        allF := ParseFeeds(json)
        for l in lines {
            for idx, int_v in INTERVALS {
                if (targetDate == today && StrCompare(int_v[1], nowT) > 0) continue
                iS := targetDate " " int_v[1] ":00", iE := targetDate " " int_v[2] ":00"
                intF := FilterFeedsByTime(allF, iS, iE), prod := CalculateDelta(intF, "field" l.fieldCount)
                upToNowF := FilterFeedsByTime(allF, startDT, iE)
                barcode := (l.fieldBarcode) ? GetLastVal(upToNowF, "field" l.fieldBarcode) : ""
                barcode := l.name == "UI perrašymas" ? "UI v5" : (barcode != "" ? "X-" barcode : "")
                guiInt := Controls[l.name].intervals[idx]
                guiInt.Fact.Value := prod, SaveToCache(targetDate, l.name, idx, "Fact", prod)
                if (barcode != "") {
                    guiInt.Prod.Value := barcode, guiInt.Prod.Opt("+ReadOnly"), SaveToCache(targetDate, l.name, idx, "Prod", barcode)
                } else guiInt.Prod.Opt("-ReadOnly")
            }
        }
    }
    UpdateCalculations(), StatusText.Value := "Užkrauta: " FormatTime(, "HH:mm:ss")
}

SaveToCache(date, line, idx, type, val) => IniWrite(val, LOG_DIR "\" date ".ini", line, type "_" idx)
SaveManualInput(line, idx, type, val) => SaveToCache(FormatTime(Calendar.Value, "yyyy-MM-dd"), line, idx, type, val)

SaveAll() {
    global Calendar, Controls, INTERVALS
    d := FormatTime(Calendar.Value, "yyyy-MM-dd")
    for name, data in Controls {
        Loop (INTERVALS.Length) {
            int_obj := data.intervals[A_Index]
            SaveToCache(d, name, A_Index, "Plan", int_obj.Plan.Value), SaveToCache(d, name, A_Index, "Fact", int_obj.Fact.Value)
            SaveToCache(d, name, A_Index, "Prod", int_obj.Prod.Value), SaveToCache(d, name, A_Index, "Comm", int_obj.Comm.Value)
        }
    }
    SoundBeep(750, 100)
}

ExportToExcel() {
    global Calendar, Controls, INTERVALS, LINES
    date := FormatTime(Calendar.Value, "yyyy-MM-dd")
    StatusText.Value := "Eksportuojama..."
    try {
        xl := ComObject("Excel.Application"), xl.Visible := true, wb := xl.Workbooks.Add(), ws := wb.ActiveSheet, ws.Name := date
        ws.Cells(1, 1).Value := "Laikas", ws.Cells(1, 1).Font.Bold := true, ws.Range(ws.Cells(1, 1), ws.Cells(1, 2)).Merge()
        Loop (INTERVALS.Length) {
            c := ws.Cells(1, A_Index + 2), c.Value := INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2], c.Font.Bold := true, c.HorizontalAlignment := -4108
        }
        ws.Cells(1, INTERVALS.Length + 3).Value := "Viso", ws.Cells(1, INTERVALS.Length + 3).Font.Bold := true
        ws.Cells(1, INTERVALS.Length + 4).Value := "Linijos vnt", ws.Cells(1, INTERVALS.Length + 4).Font.Bold := true
        ws.Cells(1, INTERVALS.Length + 5).Value := "Vnt/val", ws.Cells(1, INTERVALS.Length + 5).Font.Bold := true
        row := 2
        for l in LINES {
            d := Controls[l.name]
            ws.Cells(row, 1).Value := l.name, ws.Range(ws.Cells(row, 1), ws.Cells(row+3, 1)).Merge(), ws.Cells(row, 1).VerticalAlignment := -4108, ws.Cells(row, 1).HorizontalAlignment := -4108, ws.Cells(row, 1).Font.Bold := true
            ws.Cells(row, 2).Value := l.name " Planas", ws.Range(ws.Cells(row, 2), ws.Cells(row, INTERVALS.Length+2)).Interior.Color := 0x90EE90
            Loop (INTERVALS.Length) ws.Cells(row, A_Index+2).Value := d.intervals[A_Index].Plan.Value
            ws.Cells(row, INTERVALS.Length+3).Value := d.planTotal.Value, ws.Cells(row, INTERVALS.Length+3).Font.Bold := true, ws.Cells(row, INTERVALS.Length+3).Interior.Color := 0x90EE90
            hex := Integer("0x" l.color), r := (hex>>16)&0xFF, g := (hex>>8)&0xFF, b := hex&0xFF, bgr := (b<<16)|(g<<8)|r
            ws.Cells(row+1, 2).Value := l.name " Faktas", ws.Range(ws.Cells(row+1, 2), ws.Cells(row+1, INTERVALS.Length+2)).Interior.Color := bgr
            Loop (INTERVALS.Length) {
                c := ws.Cells(row+1, A_Index+2), c.Value := d.intervals[A_Index].Fact.Value, c.Font.Color := 0x0000FF
            }
            ws.Cells(row+1, INTERVALS.Length+3).Value := d.factTotal.Value, ws.Cells(row+1, INTERVALS.Length+3).Font.Bold := true, ws.Cells(row+1, INTERVALS.Length+3).Interior.Color := bgr
            ws.Cells(row+1, INTERVALS.Length+4).Value := d.factAvg.Value
            ws.Cells(row+2, 2).Value := "Gaminys", ws.Range(ws.Cells(row+2, 2), ws.Cells(row+2, INTERVALS.Length+2)).Interior.Color := bgr
            Loop (INTERVALS.Length) ws.Cells(row+2, A_Index+2).Value := d.intervals[A_Index].Prod.Value
            ws.Cells(row+3, 2).Value := "Komentaras", ws.Range(ws.Cells(row+3, 2), ws.Cells(row+3, INTERVALS.Length+2)).Interior.Color := bgr
            Loop (INTERVALS.Length) ws.Cells(row+3, A_Index+2).Value := d.intervals[A_Index].Comm.Value
            ws.Range(ws.Cells(row, 1), ws.Cells(row+3, INTERVALS.Length+5)).Borders.LineStyle := 1
            row += 4
        }
        ws.Columns.AutoFit(), StatusText.Value := "Baigta."
    } catch Error as e {
        MsgBox("Excel klaida: " e.Message), StatusText.Value := "Klaida."
    }
}

SetTimer(() => (SyncGist("down"), LoadDateData()), -500)
SetTimer(() => (RefreshDataFromTS()), 300000)

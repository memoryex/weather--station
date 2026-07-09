#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
Global CURRENT_VERSION := "3.4 (Excel)"
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
    catch
    {
        ; Silent fail
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
BtnRefresh.OnEvent("Click", (ctrl, *) => (SyncGist("down"), LoadDateData(true)))

BtnSaveAll := MainGui.Add("Button", "x380 y10 w120", "Saugoti viską")
BtnSaveAll.OnEvent("Click", (ctrl, *) => SaveAndSync())

BtnExport := MainGui.Add("Button", "x510 y10 w120", "Eksportuoti Excel")
BtnExport.OnEvent("Click", (ctrl, *) => ExportToExcel())

Global StatusText := MainGui.Add("Text", "x645 y15 w600", "Pasiruošęs")

; We use Tab only for the header, content is in Child GUIs
Global Tabs := MainGui.Add("Tab3", "x10 y50 w1520 h35", ["PLXE", "NOBO", "Kiti"])
Tabs.OnEvent("Change", OnTabChange)

; Child GUIs for scrollable content
Global ChildGuis := Map()
Global ActiveChild := ""

; Store control references
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
        cProd := TargetGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center ReadOnly")
        cComm := TargetGui.Add("Edit", "x" X " y" YPos+69 " w90 h20 Center cRed")

        lineCtrls.Push({Plan: cPlan, Fact: cFact, Prod: cProd, Comm: cComm})
        CommHwnds[cComm.Hwnd] := cComm

        cPlan.OnEvent("LoseFocus", (ctrl, *) => (SaveManualInput(name, idx, "Plan", ctrl.Value), UpdateCalculations()))
        cComm.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Comm", ctrl.Value))
    }

    X := 230 + INTERVALS.Length * 95
    TargetGui.SetFont("s9 bold")
    cPlanTotal := TargetGui.Add("Edit", "x" X " y" YPos " w90 h20 Center ReadOnly")
    cFactTotal := TargetGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly")

    X_Avg := X + 95
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
        idx := A_Index
        X := 230 + (idx-1) * 95

        fH.Push(TargetGui.Add("Edit", "x" X " y" YPos " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(TargetGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(TargetGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center ReadOnly +0x800 BackgroundWhite")) ; Flat look
    }

    X_Total := 1380
    TargetGui.Add("Text", "x" X_Total " y" YPos-25 " w130 h20 Center", "Visos dienos:")
    TargetGui.SetFont("s32 bold")
    cGrand := TargetGui.Add("Edit", "x" X_Total " y" YPos-5 " w130 h80 Center ReadOnly Border")
    TargetGui.SetFont("s9 norm")

    TabFooters[TabName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGrand}
}

; Build Content
headerY := 5
contentStartY := 35
lineStep := 120
footerGap := 40

for tName in ["PLXE", "NOBO", "Kiti"]
{
    cG := Gui("-Caption +Parent" MainGui.Hwnd " +0x00200000")
    cG.BackColor := "White"
    AddIntervalHeaders(cG, headerY)
    Y := contentStartY
    for line in LINES
    {
        if (line.tab == tName)
        {
            CreateLineGrid(cG, line, Y)
            Y += lineStep
        }
    }
    CreateTabFooter(cG, tName, Y + footerGap)
    ChildGuis[tName] := cG
}

OnTabChange(ctrl, *)
{
    global ActiveChild, ChildGuis
    tName := ctrl.Text
    if (ActiveChild != "")
        ChildGuis[ActiveChild].Hide()

    MainGui.GetClientPos(,, &guiW, &guiH)
    ChildGuis[tName].Show("x10 y85 w" (guiW - 20) " h" (guiH - 90))
    ActiveChild := tName
    UpdateScrollBars(ChildGuis[tName])
}

; Resize support
MainGui.OnEvent("Size", OnMainGuiSize)

; Initial show
MainGui.Show("w1540 h1040")
OnTabChange(Tabs)

; Scrolling support
OnMessage(0x0115, OnScroll) ; WM_VSCROLL
OnMessage(0x020A, OnWheel)  ; WM_MOUSEWHEEL

; =======================================================
; LOGIC
; =======================================================
OnMainGuiSize(guiObj, minMax, width, height)
{
    if (minMax == -1) ; Minimized
        return

    ; Resize Tabs header
    Tabs.Move(,, width - 20)

    ; Resize Active Child
    global ActiveChild, ChildGuis
    if (ActiveChild != "")
    {
        ChildGuis[ActiveChild].Show("w" (width - 20) " h" (height - 90))
        UpdateScrollBars(ChildGuis[ActiveChild])
    }
}

UpdateScrollBars(GuiObj) {
    static SIF_ALL := 0x17, OBJID_VSCROLL := 0xFFFFFFFB

    ; Get current window size
    GuiObj.GetClientPos(,, &guiW, &guiH)

    maxH := 0
    for hwnd, ctrl in GuiObj
    {
        ctrl.GetPos(, &y, , &h)
        if (y + h > maxH)
            maxH := y + h
    }
    contentH := maxH + 20

    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0) ; cbSize
    NumPut("UInt", SIF_ALL, si, 4) ; fMask

    DllCall("GetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si)
    currPos := NumGet(si, 20, "Int")

    NumPut("Int", 0, si, 8) ; nMin
    NumPut("Int", contentH, si, 12) ; nMax
    NumPut("UInt", guiH, si, 16) ; nPage
    NumPut("Int", currPos, si, 20) ; nPos

    DllCall("SetScrollInfo", "Ptr", GuiObj.Hwnd, "Int", 1, "Ptr", si, "Int", 1)
}

OnScroll(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild == "" || hwnd != ChildGuis[ActiveChild].Hwnd)
        return

    static SIF_ALL := 0x17, SCROLL_STEP := 40

    si := Buffer(28, 0)
    NumPut("UInt", 28, si, 0)
    NumPut("UInt", SIF_ALL, si, 4)
    DllCall("GetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si)

    nPos := NumGet(si, 20, "Int")
    nMin := NumGet(si, 8, "Int")
    nMax := NumGet(si, 12, "Int")
    nPage := NumGet(si, 16, "UInt")

    action := wp & 0xFFFF
    if (action == 0) ; SB_LINEUP
        newPos := nPos - SCROLL_STEP
    else if (action == 1) ; SB_LINEDOWN
        newPos := nPos + SCROLL_STEP
    else if (action == 2) ; SB_PAGEUP
        newPos := nPos - nPage
    else if (action == 3) ; SB_PAGEDOWN
        newPos := nPos + nPage
    else if (action == 4 || action == 5) ; SB_THUMBPOSITION or SB_THUMBTRACK
        newPos := wp >> 16
    else
        return

    newPos := Max(nMin, Min(newPos, nMax - Integer(nPage)))
    if (newPos == nPos)
        return

    ; SW_SCROLLCHILDREN | SW_INVALIDATE | SW_ERASE (0x1 | 0x2 | 0x4)
    DllCall("ScrollWindowEx", "Ptr", hwnd, "Int", 0, "Int", nPos - newPos, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0x7)
    NumPut("Int", newPos, si, 20)
    DllCall("SetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", si, "Int", 1)
    DllCall("UpdateWindow", "Ptr", hwnd)
}

OnWheel(wp, lp, msg, hwnd) {
    global ActiveChild, ChildGuis
    if (ActiveChild == "")
        return
    delta := (wp >> 16) > 0x7FFF ? (wp >> 16) - 0x10000 : (wp >> 16)
    Loop Integer(Abs(delta) / 120)
        SendMessage(0x0115, delta > 0 ? 0 : 1, 0, ChildGuis[ActiveChild].Hwnd)
}

OnMessage(0x0200, WM_MOUSEMOVE)
WM_MOUSEMOVE(wParam, lParam, msg, hwnd)
{
    static LastHwnd := 0
    if (hwnd == LastHwnd)
        return
    LastHwnd := hwnd

    try
    {
        if CommHwnds.Has(hwnd)
        {
            val := CommHwnds[hwnd].Value
            if (val != "")
            {
                ToolTip(val)
                ; Set a repeating timer to ensure tooltip doesn't fade
                SetTimer(CheckMousePos.Bind(hwnd), 100)
            }
            else
                ToolTip()
        }
        else
            ToolTip()
    }
    catch
        ToolTip()
}

CheckMousePos(OriginalHwnd)
{
    try
    {
        MouseGetPos(,, &TargetHwnd, &ControlHwnd, 2)
        if (TargetHwnd != OriginalHwnd && ControlHwnd != OriginalHwnd)
        {
            ToolTip()
            SetTimer(CheckMousePos.Bind(OriginalHwnd), 0) ; Turn off
        }
        else
        {
            ; Mouse still over, keep tooltip alive
            if (CommHwnds.Has(OriginalHwnd))
                ToolTip(CommHwnds[OriginalHwnd].Value)
        }
    }
    catch
    {
        ToolTip()
        SetTimer(CheckMousePos.Bind(OriginalHwnd), 0)
    }
}

UpdateCalculations()
{
    global Controls, TabFooters, INTERVALS

    stats := Map()
    stats["PLXE"] := {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0}
    stats["NOBO"] := {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0}
    stats["Kiti"] := {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0}

    for lineName, data in Controls
    {
        lineTotalFact := 0
        lineTotalPlan := 0
        activeIntervalsFact := 0
        activeIntervalsPlan := 0
        tabName := data.tab

        for idx, interval in data.intervals
        {
            pVal := GetNum(interval.Plan.Value)
            fVal := GetNum(interval.Fact.Value)

            stats[tabName].Plan[idx] += pVal
            stats[tabName].Fact[idx] += fVal

            lineTotalPlan += pVal
            lineTotalFact += fVal

            if (fVal > 0)
                activeIntervalsFact++
            if (pVal > 0)
                activeIntervalsPlan++

            try
            {
                if (pVal > 0)
                {
                    if (fVal >= pVal)
                    {
                        interval.Plan.Opt("Background90EE90")
                        interval.Fact.Opt("Background90EE90")
                    }
                    else
                    {
                        interval.Plan.Opt("BackgroundFF7F7F")
                        interval.Fact.Opt("BackgroundFF7F7F")
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
            catch
            {
            }
        }

        data.planTotal.Value := lineTotalPlan
        data.factTotal.Value := lineTotalFact

        stats[tabName].Grand += lineTotalFact

        data.planAvg.Value := activeIntervalsPlan > 0 ? Round(lineTotalPlan / activeIntervalsPlan, 1) : 0
        data.factAvg.Value := activeIntervalsFact > 0 ? Round(lineTotalFact / activeIntervalsFact, 1) : 0
    }

    for tName, tData in stats
    {
        if TabFooters.Has(tName)
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
                    pct := Round((fVal / pVal - 1) * 100)

                if (pct > 0)
                    footer.Pct[i].Value := "+" . pct . "%"
                else if (pct < 0)
                    footer.Pct[i].Value := pct . "%"
                else
                    footer.Pct[i].Value := "0%"
            }
            footer.Grand.Value := tData.Grand
        }
    }
}

SyncGist(mode)
{
    global GIST_ID, GIST_TOKEN, LOG_DIR, StatusText
    if (GIST_TOKEN == "" || GIST_TOKEN == "PLACEHOLDER_TOKEN")
    {
        StatusText.Value := "Gist Token nerastas config.ini"
        return
    }

    url := "https://api.github.com/gists/" GIST_ID
    req := ComObject("WinHttp.WinHttpRequest.5.1")

    try
    {
        if (mode == "down")
        {
            req.Open("GET", url, false)
            req.SetRequestHeader("Authorization", "token " GIST_TOKEN)
            req.Send()

            if (req.Status == 200)
            {
                res := req.ResponseText
                ; Use 's' option to allow dot to match newlines in res
                if RegExMatch(res, 's)"logas\.txt":\{.*?"content":"(.*?)"\s*\}', &m)
                {
                    content := m[1]
                    ; Unescape JSON: order is important
                    content := StrReplace(content, "\\", "\")
                    content := StrReplace(content, "\"", '"')
                    content := StrReplace(content, "\n", "`n")
                    content := StrReplace(content, "\r", "`r")
                    content := StrReplace(content, "\t", "`t")

                    if (InStr(content, "[FILE:"))
                    {
                        currentFile := ""
                        Loop Parse, content, "`n", "`r"
                        {
                            line := A_LoopField
                            if RegExMatch(line, "^\[FILE:(.+)\]$", &fm)
                            {
                                currentFile := LOG_DIR "\" fm[1]
                                if FileExist(currentFile)
                                    FileDelete(currentFile)
                                continue
                            }

                            if (currentFile != "")
                                FileAppend(line "`n", currentFile)
                        }
                        StatusText.Value := "Duomenys sinchronizuoti."
                    }
                }
            }
        }
        else if (mode == "up")
        {
            payload := ""
            Loop Files, LOG_DIR "\*.ini"
            {
                payload .= "[FILE:" A_LoopFileName "]`n"
                payload .= FileRead(A_LoopFileFullPath) "`n"
            }
            jsonPayload := StrReplace(payload, '\', '\\'), jsonPayload := StrReplace(jsonPayload, '"', '\"')
            jsonPayload := StrReplace(jsonPayload, "`r`n", "\n"), jsonPayload := StrReplace(jsonPayload, "`n", "\n")
            body := '{"files":{"logas.txt":{"content":"' jsonPayload '"}}}'

            req.Open("PATCH", url, false)
            req.SetRequestHeader("Authorization", "token " GIST_TOKEN)
            req.SetRequestHeader("Content-Type", "application/json")
            req.Send(body)
        }
    }
    catch Error as e
        StatusText.Value := "Gist klaida: " e.Message
}

SaveAndSync()
{
    SaveAll()
    SyncGist("up")
}

FetchTSData(channel, start_dt, end_dt)
{
    global READ_KEYS
    key := READ_KEYS.Has(channel) ? READ_KEYS[channel] : ""
    url := "https://api.thingspeak.com/channels/" channel "/feeds.json?api_key=" key "&start=" StrReplace(start_dt, " ", "T") "&end=" StrReplace(end_dt, " ", "T") "&timezone=Europe/Vilnius"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try
    {
        req.Open("GET", url, true)
        req.Send()
        req.WaitForResponse()
        if (req.Status == 200)
            return req.ResponseText
    }
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
            {
                vals.Push(Float(val))
            }
            catch
            {
                ; skip
            }
        }
    }
    if (vals.Length < 2)
        return 0
    total := 0
    Loop (vals.Length - 1)
    {
        v1 := vals[A_Index]
        v2 := vals[A_Index + 1]
        diff := v2 - v1
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

FilterFeedsByTime(feeds, startT, endT)
{
    filtered := []
    s := StrReplace(StrReplace(StrReplace(startT, "-", ""), " ", ""), ":", "")
    e := StrReplace(StrReplace(StrReplace(endT, "-", ""), " ", ""), ":", "")
    for index, f in feeds
    {
        ft := StrReplace(StrReplace(StrReplace(SubStr(f["created_at"], 1, 19), "-", ""), "T", ""), ":", "")
        if (ft >= s && ft <= e)
            filtered.Push(f)
    }
    return filtered
}

LoadDateData(forceRefresh := false)
{
    global Calendar, StatusText, Controls, INTERVALS, LOG_DIR
    dateStr := FormatTime(Calendar.Value, "yyyy-MM-dd")
    StatusText.Value := "Kraunama: " dateStr
    iniPath := LOG_DIR "\" dateStr ".ini"
    today := FormatTime(A_Now, "yyyy-MM-dd")
    nowTime := FormatTime(A_Now, "HH:mm")

    for lineName, data in Controls
    {
        Loop (INTERVALS.Length)
        {
            idx := A_Index
            intStart := INTERVALS[idx][1]

            isFuture := (dateStr == today && StrCompare(intStart, nowTime) > 0)

            data.intervals[idx].Plan.Value := isFuture ? "" : IniRead(iniPath, lineName, "Plan_" idx, "")
            data.intervals[idx].Fact.Value := isFuture ? "" : IniRead(iniPath, lineName, "Fact_" idx, "")
            data.intervals[idx].Prod.Value := isFuture ? "" : IniRead(iniPath, lineName, "Prod_" idx, "")
            data.intervals[idx].Comm.Value := isFuture ? "" : IniRead(iniPath, lineName, "Comm_" idx, "")
        }
    }
    UpdateCalculations()

    ; If today OR if cache is empty OR if forced - fetch from TS
    cacheExists := FileExist(iniPath)
    if (dateStr == today || !cacheExists || forceRefresh)
        RefreshDataFromTS(dateStr)
    else
        StatusText.Value := "Užkrauta: " dateStr
}

RefreshDataFromTS(targetDate := "")
{
    global Calendar, StatusText, LINES, INTERVALS, Controls
    if (targetDate == "")
        targetDate := FormatTime(Calendar.Value, "yyyy-MM-dd")

    StatusText.Value := "Siunčiamasi iš ThingSpeak (" targetDate ")..."
    channels := Map()
    for index, line in LINES
    {
        if !channels.Has(line.channel)
            channels[line.channel] := []
        channels[line.channel].Push(line)
    }
    today := FormatTime(A_Now, "yyyy-MM-dd")
    nowTime := FormatTime(A_Now, "HH:mm")

    for channel, linesInChannel in channels
    {
        rawSelDate := StrReplace(targetDate, "-", "")
        lookbackDate := DateAdd(rawSelDate "000000", -3, "Days")
        startDT := FormatTime(lookbackDate, "yyyy-MM-dd HH:mm:ss")
        endDT := targetDate " 16:00:00"
        json := FetchTSData(channel, startDT, endDT)
        if (json == "")
            continue
        allFeeds := ParseFeeds(json)

        for index, line in linesInChannel
        {
            for intIdx, interval in INTERVALS
            {
                ; Skip future intervals only if targetDate is today
                if (targetDate == today && StrCompare(interval[1], nowTime) > 0)
                    continue

                iStart := targetDate " " interval[1] ":00"
                iEnd := targetDate " " interval[2] ":00"
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

                SaveToCache(targetDate, line.name, intIdx, "Fact", produced)
                if (barcode != "")
                    SaveToCache(targetDate, line.name, intIdx, "Prod", barcode)
            }
        }
    }
    UpdateCalculations()
    StatusText.Value := "Užkrauta: " FormatTime(, "HH:mm:ss")
}

SaveToCache(dateStr, lineName, idx, type, value)
{
    IniWrite(value, LOG_DIR "\" dateStr ".ini", lineName, type "_" idx)
}

SaveManualInput(lineName, intervalIdx, type, value)
{
    global Calendar
    SaveToCache(FormatTime(Calendar.Value, "yyyy-MM-dd"), lineName, intervalIdx, type, value)
}

SaveAll()
{
    global Calendar, StatusText, Controls, INTERVALS
    dateStr := FormatTime(Calendar.Value, "yyyy-MM-dd")
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
    StatusText.Value := "Išsaugota (" dateStr ")."
    SoundBeep(750, 100)
}

ExportToExcel()
{
    global Calendar, Controls, INTERVALS, LINES
    dateStr := FormatTime(Calendar.Value, "yyyy-MM-dd")

    StatusText.Value := "Eksportuojama į Excel..."

    try {
        xl := ComObject("Excel.Application")
        xl.Visible := true
        wb := xl.Workbooks.Add()
        ws := wb.ActiveSheet
        ws.Name := dateStr

        ; Headers
        ws.Cells(1, 1).Value := "Linija"
        ws.Cells(1, 2).Value := "Laukas"
        Loop (INTERVALS.Length) {
            ws.Cells(1, A_Index + 2).Value := INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2]
        }
        ws.Cells(1, INTERVALS.Length + 3).Value := "Viso"
        ws.Cells(1, INTERVALS.Length + 4).Value := "Vidurkis"

        currentRow := 2
        for lineObj in LINES {
            name := lineObj.name
            data := Controls[name]

            ; Linija merge
            ws.Range(ws.Cells(currentRow, 1), ws.Cells(currentRow + 3, 1)).Merge()
            ws.Cells(currentRow, 1).Value := name
            ws.Cells(currentRow, 1).VerticalAlignment := -4108 ; xlCenter
            ws.Cells(currentRow, 1).HorizontalAlignment := -4108

            ; Row 1: Planas
            ws.Cells(currentRow, 2).Value := "Planas"
            Loop (INTERVALS.Length) {
                ws.Cells(currentRow, A_Index + 2).Value := data.intervals[A_Index].Plan.Value
            }
            ws.Cells(currentRow, INTERVALS.Length + 3).Value := data.planTotal.Value
            ws.Cells(currentRow, INTERVALS.Length + 4).Value := data.planAvg.Value

            ; Row 2: Faktas
            ws.Cells(currentRow + 1, 2).Value := "Faktas"
            Loop (INTERVALS.Length) {
                ws.Cells(currentRow + 1, A_Index + 2).Value := data.intervals[A_Index].Fact.Value
            }
            ws.Cells(currentRow + 1, INTERVALS.Length + 3).Value := data.factTotal.Value
            ws.Cells(currentRow + 1, INTERVALS.Length + 4).Value := data.factAvg.Value

            ; Row 3: Gaminys
            ws.Cells(currentRow + 2, 2).Value := "Gaminys"
            Loop (INTERVALS.Length) {
                ws.Cells(currentRow + 2, A_Index + 2).Value := data.intervals[A_Index].Prod.Value
            }

            ; Row 4: Komentaras
            ws.Cells(currentRow + 3, 2).Value := "Komentaras"
            Loop (INTERVALS.Length) {
                ws.Cells(currentRow + 3, A_Index + 2).Value := data.intervals[A_Index].Comm.Value
            }

            currentRow += 4
        }

        ws.Columns.AutoFit()
        StatusText.Value := "Eksportas baigtas."
    } catch Error as e {
        MsgBox("Excel eksporto klaida: " e.Message, "Klaida", "Iconx")
        StatusText.Value := "Eksporto klaida."
    }
}

; Startup
StatusText.Value := "Kraunami duomenys..."
SetTimer(() => (SyncGist("down"), LoadDateData()), -500)
SetTimer(() => (RefreshDataFromTS()), 300000)

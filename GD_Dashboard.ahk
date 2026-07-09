#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; CONFIGURATION & CONSTANTS
; =======================================================
Global CURRENT_VERSION := "2.9 (Sync & BGR Fix)"
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

GetNum(V) => IsNumber(V) ? V : (clean := RegExReplace(String(V), "[^\d\.]"), clean == "" || clean == "." ? 0 : Number(clean))

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

Global Tabs := MainGui.Add("Tab3", "x10 y50 w1520 h960", ["PLXE", "NOBO", "Kiti"])
Global Controls := Map(), TabFooters := Map(), CommHwnds := Map()

AddIntervalHeaders(YPos) {
    global MainGui, INTERVALS
    MainGui.SetFont("s9 bold")
    Loop (INTERVALS.Length) {
        X := 230 + (A_Index-1) * 95
        MainGui.Add("Text", "x" X " y" YPos " w90 h20 Center", INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2])
    }
    MainGui.Add("Text", "x" (230 + INTERVALS.Length * 95) " y" YPos " w90 h20 Center", "Viso")
    MainGui.Add("Text", "x" (230 + (INTERVALS.Length + 1) * 95) " y" YPos " w90 h20 Center", "Vidurkis")
    MainGui.SetFont("s9 norm")
}

CreateLineGrid(LineObj, YPos) {
    global Controls, MainGui, INTERVALS, CommHwnds
    name := LineObj.name
    MainGui.SetFont("s10 bold")
    MainGui.Add("Text", "x15 y" YPos " w100 h20", name)
    MainGui.SetFont("s9 bold")
    MainGui.Add("Text", "x125 y" YPos " w95 h20", "Planas")
    MainGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Faktas")
    MainGui.Add("Text", "x125 y" YPos+46 " w95 h20", "Gaminys")
    MainGui.Add("Text", "x125 y" YPos+69 " w95 h20", "Komentaras")
    MainGui.SetFont("s9 norm")
    lineCtrls := []
    Loop (INTERVALS.Length) {
        idx := A_Index, X := 230 + (idx-1) * 95
        cPlan := MainGui.Add("Edit", "x" X " y" YPos " w90 h20 Center")
        cFact := MainGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly")
        cProd := MainGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center")
        cComm := MainGui.Add("Edit", "x" X " y" YPos+69 " w90 h20 Center cRed")
        lineCtrls.Push({Plan: cPlan, Fact: cFact, Prod: cProd, Comm: cComm}), CommHwnds[cComm.Hwnd] := cComm
        cPlan.OnEvent("LoseFocus", (ctrl, *) => (SaveManualInput(name, idx, "Plan", ctrl.Value), UpdateCalculations()))
        cProd.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Prod", ctrl.Value))
        cComm.OnEvent("LoseFocus", (ctrl, *) => SaveManualInput(name, idx, "Comm", ctrl.Value))
    }
    X_T := 230 + INTERVALS.Length * 95, MainGui.SetFont("s9 bold")
    cPlanTotal := MainGui.Add("Edit", "x" X_T " y" YPos " w90 h20 Center ReadOnly")
    cFactTotal := MainGui.Add("Edit", "x" X_T " y" YPos+23 " w90 h20 Center ReadOnly")
    X_A := X_T + 95
    cPlanAvg := MainGui.Add("Edit", "x" X_A " y" YPos " w90 h20 Center ReadOnly")
    cFactAvg := MainGui.Add("Edit", "x" X_A " y" YPos+23 " w90 h20 Center ReadOnly")
    MainGui.SetFont("s9 norm")
    Controls[name] := {intervals: lineCtrls, planTotal: cPlanTotal, planAvg: cPlanAvg, factTotal: cFactTotal, factAvg: cFactAvg, tab: LineObj.tab}
}

CreateTabFooter(TabName, YPos) {
    global TabFooters, MainGui, INTERVALS
    fH := [], pH := [], pcH := []
    MainGui.SetFont("s9 bold")
    MainGui.Add("Text", "x125 y" YPos " w95 h20", "Faktas"), MainGui.Add("Text", "x15 y" YPos+23 " w100 h20", "Tikslas:"), MainGui.Add("Text", "x125 y" YPos+23 " w95 h20", "Planas")
    Loop (INTERVALS.Length) {
        X := 230 + (A_Index-1) * 95
        fH.Push(MainGui.Add("Edit", "x" X " y" YPos " w90 h20 Center ReadOnly cRed BackgroundWhite"))
        pH.Push(MainGui.Add("Edit", "x" X " y" YPos+23 " w90 h20 Center ReadOnly BackgroundWhite"))
        pcH.Push(MainGui.Add("Edit", "x" X " y" YPos+46 " w90 h20 Center ReadOnly +0x800 BackgroundWhite"))
    }
    MainGui.SetFont("s32 bold"), cGrand := MainGui.Add("Edit", "x1380 y" YPos-5 " w130 h80 Center ReadOnly Border"), MainGui.SetFont("s9 norm")
    TabFooters[TabName] := {Fact: fH, Plan: pH, Pct: pcH, Grand: cGrand}
}

for tName in ["PLXE", "NOBO", "Kiti"] {
    Tabs.UseTab(A_Index), AddIntervalHeaders(20), Y := 50
    for l in LINES
        if (l.tab == tName)
            CreateLineGrid(l, Y), Y += 120
    CreateTabFooter(tName, Y + 40)
}
Tabs.UseTab()
MainGui.Show("w1540 h1040")

; =======================================================
; LOGIC
; =======================================================
OnMessage(0x0200, WM_MOUSEMOVE)
WM_MOUSEMOVE(wp, lp, msg, hwnd) {
    static LastHwnd := 0
    if (hwnd == LastHwnd) return
    LastHwnd := hwnd
    try {
        if CommHwnds.Has(hwnd) {
            val := CommHwnds[hwnd].Value
            if (val != "") ToolTip(val), SetTimer(CheckMousePos.Bind(hwnd), 500)
            else ToolTip()
        } else ToolTip()
    } catch ToolTip()
}
CheckMousePos(OriginalHwnd) {
    try {
        MouseGetPos(,, &TH, &CH, 2)
        if (TH != OriginalHwnd && CH != OriginalHwnd) ToolTip(), SetTimer(CheckMousePos.Bind(OriginalHwnd), 0)
    } catch ToolTip(), SetTimer(CheckMousePos.Bind(OriginalHwnd), 0)
}

UpdateCalculations() {
    global Controls, TabFooters, INTERVALS
    stats := Map()
    for t in ["PLXE", "NOBO", "Kiti"] stats[t] := {Fact: [0,0,0,0,0,0,0,0,0,0], Plan: [0,0,0,0,0,0,0,0,0,0], Grand: 0}
    for name, data in Controls {
        lF := 0, lP := 0, aF := 0, aP := 0
        for idx, int in data.intervals {
            p := GetNum(int.Plan.Value), f := GetNum(int.Fact.Value)
            stats[data.tab].Plan[idx] += p, stats[data.tab].Fact[idx] += f, lP += p, lF += f
            if (f > 0) aF++
            if (p > 0) aP++
            if (p > 0) {
                int.Plan.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
                int.Fact.Opt(f >= p ? "Background90EE90" : "BackgroundFF7F7F")
            } else {
                int.Plan.Opt("BackgroundWhite"), int.Fact.Opt("BackgroundWhite")
            }
            int.Plan.Redraw(), int.Fact.Redraw()
        }
        data.planTotal.Value := lP, data.factTotal.Value := lF, stats[data.tab].Grand += lF
        data.planAvg.Value := aP > 0 ? Round(lP / aP, 1) : 0
        data.factAvg.Value := aF > 0 ? Round(lF / aF, 1) : 0
    }
    for t, d in stats {
        if TabFooters.Has(t) {
            f := TabFooters[t]
            Loop (INTERVALS.Length) {
                fv := d.Fact[A_Index], pv := d.Plan[A_Index], f.Fact[A_Index].Value := fv, f.Plan[A_Index].Value := pv
                pct := pv > 0 ? Round((fv/pv-1)*100) : 0
                f.Pct[A_Index].Value := (pct > 0 ? "+" : "") pct "%"
            }
            f.Grand.Value := d.Grand
        }
    }
}

SyncGist(mode) {
    global GIST_ID, GIST_TOKEN, LOG_DIR, StatusText
    if (GIST_TOKEN == "") return
    url := "https://api.github.com/gists/" GIST_ID
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        if (mode == "down") {
            req.Open("GET", url, false), req.SetRequestHeader("Authorization", "Bearer " GIST_TOKEN), req.Send()
            if (req.Status == 200 && RegExMatch(req.ResponseText, 's)"logas\.txt":\s*\{.*?"content":\s*"((?:[^"\\]|\\.)*)"', &m)) {
                content := m[1], content := StrReplace(content, "\\", "[[BS]]"), content := StrReplace(content, "\n", "`n"), content := StrReplace(content, "\r", "`r"), content := StrReplace(content, '\"', '"'), content := StrReplace(content, "[[BS]]", "\")
                cf := ""
                Loop Parse, content, "`n", "`r" {
                    if RegExMatch(A_LoopField, "^\[FILE:(.+)\]$", &fm) {
                        cf := LOG_DIR "\" fm[1]
                        if FileExist(cf) FileDelete(cf)
                    } else if (cf != "") FileAppend(A_LoopField "`n", cf)
                }
                StatusText.Value := "Sinchronizuota."
            }
        } else if (mode == "up") {
            payload := ""
            Loop Files, LOG_DIR "\*.ini" payload .= "[FILE:" A_LoopFileName "]`n" FileRead(A_LoopFileFullPath) "`n"
            jsonP := StrReplace(payload, "\", "\\"), jsonP := StrReplace(jsonP, '"', '\"'), jsonP := StrReplace(jsonP, "`r`n", "\n"), jsonP := StrReplace(jsonP, "`n", "\n")
            req.Open("PATCH", url, false), req.SetRequestHeader("Authorization", "Bearer " GIST_TOKEN), req.SetRequestHeader("Content-Type", "application/json"), req.Send('{"files":{"logas.txt":{"content":"' jsonP '"}}}')
        }
    } catch Error as e StatusText.Value := "Gist klaida: " e.Message
}

SaveAndSync() => (SaveAll(), SyncGist("up"))

FetchTSData(ch, start, end) {
    global READ_KEYS
    url := "https://api.thingspeak.com/channels/" ch "/feeds.json?api_key=" (READ_KEYS.Has(ch)?READ_KEYS[ch]:"") "&start=" StrReplace(start, " ", "T") "&end=" StrReplace(end, " ", "T") "&timezone=Europe/Vilnius"
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        req.Open("GET", url, true), req.Send()
        if (req.WaitForResponse(10) && req.Status == 200) return req.ResponseText
    }
    return ""
}

ParseFeeds(jsonStr) {
    feeds := [], pos := 1
    while pos := RegExMatch(jsonStr, '\{"created_at":"[^"]+"[^}]*\}', &m, pos) {
        obj := Map(), objStr := m[0]
        if RegExMatch(objStr, '"created_at":"([^"]+)"', &mm) obj["created_at"] := mm[1]
        Loop 8 {
            f := "field" A_Index
            if RegExMatch(objStr, '"' f '":"?([^",}]*)"?', &mm) obj[f] := mm[1]=="null"?"":mm[1]
            else obj[f] := ""
        }
        feeds.Push(obj), pos += m.Len
    }
    return feeds
}

CalculateDelta(feeds, field) {
    if (feeds.Length < 2) return 0
    vals := []
    for f in feeds {
        v := f.Has(field)?f[field]:""
        if (v != "" && v != "null") try vals.Push(Float(v))
    }
    if (vals.Length < 2) return 0
    total := 0
    Loop (vals.Length - 1) {
        d := vals[A_Index+1] - vals[A_Index]
        if (d > 0) total += d
    }
    return Integer(total)
}

GetLastVal(feeds, field) {
    idx := feeds.Length
    while (idx > 0) {
        v := feeds[idx].Has(field)?feeds[idx][field]:""
        if (v != "" && v != "null") return v
        idx--
    }
    return ""
}

FilterFeedsByTime(feeds, sT, eT) {
    filt := [], s := StrReplace(StrReplace(StrReplace(sT, "-", ""), " ", ""), ":", ""), e := StrReplace(StrReplace(StrReplace(eT, "-", ""), " ", ""), ":", "")
    for f in feeds {
        ft := StrReplace(StrReplace(StrReplace(SubStr(f["created_at"], 1, 19), "-", ""), "T", ""), ":", "")
        if (ft >= s && ft <= e) filt.Push(f)
    }
    return filt
}

LoadDateData(forceRefresh := false) {
    global Calendar, Controls, INTERVALS, LOG_DIR, StatusText
    dStr := FormatTime(Calendar.Value, "yyyy-MM-dd"), iniP := LOG_DIR "\" dStr ".ini"
    for name, data in Controls {
        Loop (INTERVALS.Length) {
            idx := A_Index, int := data.intervals[idx]
            int.Plan.Value := IniRead(iniP, name, "Plan_" idx, ""), int.Fact.Value := IniRead(iniP, name, "Fact_" idx, ""), int.Prod.Value := IniRead(iniP, name, "Prod_" idx, ""), int.Comm.Value := IniRead(iniP, name, "Comm_" idx, "")
            if (int.Prod.Value != "" && (SubStr(int.Prod.Value, 1, 2) == "X-" || int.Prod.Value == "UI v5")) int.Prod.Opt("+ReadOnly")
            else int.Prod.Opt("-ReadOnly")
        }
    }
    UpdateCalculations()
    if (dStr == FormatTime(A_Now, "yyyy-MM-dd") || forceRefresh) RefreshDataFromTS(dStr)
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
        lb := DateAdd(StrReplace(targetDate, "-", "") "000000", -3, "Days")
        json := FetchTSData(ch, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), targetDate " 16:00:00")
        if (json == "") continue
        allF := ParseFeeds(json)
        for l in lines {
            for idx, int_v in INTERVALS {
                if (targetDate == today && StrCompare(int_v[1], nowT) > 0) continue
                iS := targetDate " " int_v[1] ":00", iE := targetDate " " int_v[2] ":00"
                intF := FilterFeedsByTime(allF, iS, iE), prod := CalculateDelta(intF, "field" l.fieldCount)
                upToNowF := FilterFeedsByTime(allF, FormatTime(lb, "yyyy-MM-dd HH:mm:ss"), iE)
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

SaveToCache(d, l, i, t, v) => IniWrite(v, LOG_DIR "\" d ".ini", l, t "_" i)
SaveManualInput(l, i, t, v) => SaveToCache(FormatTime(Calendar.Value, "yyyy-MM-dd"), l, i, t, v)

SaveAll() {
    global Calendar, Controls, INTERVALS
    d := FormatTime(Calendar.Value, "yyyy-MM-dd")
    for n, data in Controls {
        Loop (INTERVALS.Length) {
            c := data.intervals[A_Index]
            SaveToCache(d, n, A_Index, "Plan", c.Plan.Value), SaveToCache(d, n, A_Index, "Fact", c.Fact.Value)
            SaveToCache(d, n, A_Index, "Prod", c.Prod.Value), SaveToCache(d, n, A_Index, "Comm", c.Comm.Value)
        }
    }
    SoundBeep(750, 100)
}

ExportToExcel() {
    global Calendar, Controls, INTERVALS, LINES
    date := FormatTime(Calendar.Value, "yyyy-MM-dd")
    try {
        xl := ComObject("Excel.Application"), xl.Visible := true, wb := xl.Workbooks.Add(), ws := wb.ActiveSheet, ws.Name := date
        ws.Cells(1,1).Value := "Laikas", ws.Range(ws.Cells(1,1), ws.Cells(1,2)).Merge(), ws.Cells(1,1).Font.Bold := true
        Loop (INTERVALS.Length) ws.Cells(1, A_Index+2).Value := INTERVALS[A_Index][1] "-" INTERVALS[A_Index][2], ws.Cells(1, A_Index+2).Font.Bold := true
        ws.Cells(1, INTERVALS.Length+3).Value := "Viso", ws.Cells(1, INTERVALS.Length+3).Font.Bold := true
        row := 2
        for l in LINES {
            d := Controls[l.name], ws.Cells(row, 1).Value := l.name, ws.Range(ws.Cells(row, 1), ws.Cells(row+3, 1)).Merge(), ws.Cells(row, 1).Font.Bold := true
            ws.Cells(row, 2).Value := l.name " Planas", ws.Range(ws.Cells(row, 2), ws.Cells(row, INTERVALS.Length+2)).Interior.Color := 0x90EE90
            Loop (INTERVALS.Length) ws.Cells(row, A_Index+2).Value := d.intervals[A_Index].Plan.Value
            hex := Integer("0x" l.color), r := (hex>>16)&0xFF, g := (hex>>8)&0xFF, b := hex&0xFF, bgr := (b<<16)|(g<<8)|r
            ws.Cells(row+1, 2).Value := l.name " Faktas", ws.Range(ws.Cells(row+1, 2), ws.Cells(row+1, INTERVALS.Length+2)).Interior.Color := bgr
            Loop (INTERVALS.Length) ws.Cells(row+1, A_Index+2).Value := d.intervals[A_Index].Fact.Value
            ws.Cells(row+2, 2).Value := "Gaminys", ws.Range(ws.Cells(row+2, 2), ws.Cells(row+2, INTERVALS.Length+2)).Interior.Color := bgr
            Loop (INTERVALS.Length) ws.Cells(row+2, A_Index+2).Value := d.intervals[A_Index].Prod.Value
            ws.Cells(row+3, 2).Value := "Komentaras", ws.Range(ws.Cells(row+3, 2), ws.Cells(row+3, INTERVALS.Length+2)).Interior.Color := bgr
            Loop (INTERVALS.Length) ws.Cells(row+3, A_Index+2).Value := d.intervals[A_Index].Comm.Value
            row += 4
        }
        ws.Columns.AutoFit()
    } catch Error as e MsgBox(e.Message)
}

SetTimer(() => (SyncGist("down"), LoadDateData()), -500)
SetTimer(() => (RefreshDataFromTS()), 300000)

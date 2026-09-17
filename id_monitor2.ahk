; ==============================================================================
; Appliance ID Slenkančio Ekrano (2 Skaitmenų Sekos) Stebėjimo ir Logavimo Programa
; Ver: 2.2 (AutoHotkey v2.0 - USB WebCam / 7-Segment Red Display & Blue LED Tracker)
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Global Kintamieji
global isMonitoring := false
global configFile := A_ScriptDir . "\config.ini"
global logFilePath := ""
global lastCapturedID := ""
global capturedCount := 0
global capturedHistory := Map()

; Ekrano (Display) Rėmelis
global overlayX := 300, overlayY := 200, overlayW := 200, overlayH := 100

; Mėlyno LED Indikatoriaus Rėmelis
global ledOverlayX := 520, ledOverlayY := 200, ledOverlayW := 40, ledOverlayH := 40
global isBlueLEDActive := false
global lastLEDCheckTime := 0

global isFlashing := false
global isScanningActive := false
global sbStatus := 0

; Sekos Surinkimo Buferis (Tik po "ID" pamatymo, kai mirksi Mėlynas LED)
global sequenceBuffer := []
global isCapturingID := false
global lastSeenToken := ""
global lastTokenTime := 0
global bufferTimeoutMs := 6000
global lastFrameHash := ""

; Konfigūruojamos Slenkstinės Reikšmės (Thresholds)
global threshRMin := 70
global threshRGDiff := 15
global threshRBDiff := 15
global threshBlueMin := 50
global threshBlueDiff := 20
global threshRedMin := 50
global threshRedDiff := 20

; Live Test Diagnostiniai Kintamieji GUI
global liveOCRText := ""
global liveLEDRGB := "R: - G: - B: -"
global liveLEDStateStr := "Nežinoma"
global liveDisplayRedBright := "R: 0 / 255"

; ==============================================================================
; GUI SĄSANAJOS KŪRIMAS
; ==============================================================================
MainGui := Gui("+AlwaysOnTop +MinSize380x570", "Slenkančio Ekrano ID Stebėjimas v2.2")
MainGui.SetFont("s10", "Segoe UI")
MainGui.BackColor := "0xF4F6F9"

; Viršutinė antraštė
MainGui.SetFont("s13 bold", "Segoe UI")
MainGui.Add("Text", "x15 y12 w350 c0x1A252C", "Slenkančio Ekrano (2-Digit) Stebėjimas")
MainGui.SetFont("s9 norm", "Segoe UI")

; Būsenos ir Skaitiklio Rėmelis
MainGui.Add("GroupBox", "x15 y42 w350 h105", "Būsena IR LED Indikatorius")

MainGui.Add("Text", "x30 y63 w120 c0x555555", "Pagauta naujų ID:")
MainGui.SetFont("s18 bold", "Segoe UI")
txtCount := MainGui.Add("Text", "x150 y56 w190 c0x2E7D32", "0 vnt.")
MainGui.SetFont("s9 norm", "Segoe UI")

MainGui.Add("Text", "x30 y93 w120 c0x555555", "Sistemos būsena:")
txtStatus := MainGui.Add("Text", "x150 y93 w190 c0xC62828", "Sustabdyta")
txtStatus.SetFont("bold")

MainGui.Add("Text", "x30 y118 w120 c0x555555", "Mėlynas LED:")
txtLEDStatus := MainGui.Add("Text", "x150 y118 w190 c0x7F8C8D", "Neaktyvus / Neaptiktas")
txtLEDStatus.SetFont("bold")

; Dabartinio Surinkimo Sekos Būsena (Live Sequence Buffer Progress)
MainGui.Add("GroupBox", "x15 y152 w350 h65", "Renkamas ID (Po 'ID' Trigerio)")
MainGui.SetFont("s11 bold", "Consolas")
txtSequenceProgress := MainGui.Add("Text", "x25 y175 w330 Center c0x1976D2", "Laukiama 'ID'...")
MainGui.SetFont("s9 norm", "Segoe UI")

; Paskutinio Pamatyto Pilno ID Langas (Su Sumirksėjimo Efektu)
MainGui.Add("GroupBox", "x15 y225 w350 h85", "Paskutinis Pilnas 12-Ženklų ID")

; Progress baras su Range0-100 žaliu užpildymu mirksėjimui
idBoxBg := MainGui.Add("Progress", "x30 y245 w320 h50 BackgroundFFFFFF c0x27AE60 Range0-100", 0)
MainGui.SetFont("s16 bold", "Consolas")
txtLastID := MainGui.Add("Text", "x35 y255 w310 Center BackgroundTrans c0x2C3E50", "------------")
MainGui.SetFont("s9 norm", "Segoe UI")

; Valdymo Mygtukai
btnStart := MainGui.Add("Button", "x15 y320 w80 h32", "▶ Pradėti")
btnStart.SetFont("bold")
btnOverlay := MainGui.Add("Button", "x100 y320 w80 h32", "🔲 Rėmeliai")
btnLogFile := MainGui.Add("Button", "x185 y320 w85 h32", "📁 Log Failas")
btnSettings := MainGui.Add("Button", "x275 y320 w90 h32", "⚙ Nustatymai")
btnSettings.SetFont("bold")

; Registruotų ID Sąrašas (ListView)
MainGui.SetFont("bold")
MainGui.Add("Text", "x15 y362 w200 c0x333333", "Pagautų ID Istorija:")
MainGui.SetFont("norm")
lvHistory := MainGui.Add("ListView", "x15 y382 w350 h135 Grid", ["Laikas", "Pilnas Appliance ID"])
lvHistory.ModifyCol(1, 140)
lvHistory.ModifyCol(2, 190)

; Apatinė juosta su informacija
sbStatus := MainGui.Add("StatusBar",, " Pasiruošęs. Užstumkite rėmelius ant ekranėlio ir mėlyno LED.")

; Event Handlers
btnStart.OnEvent("Click", ToggleMonitoring)
btnOverlay.OnEvent("Click", ToggleOverlays)
btnLogFile.OnEvent("Click", SelectLogFile)
btnSettings.OnEvent("Click", OpenSettingsGui)
MainGui.OnEvent("Close", (*) => ExitApp())
OnExit(SaveOverlayPositions)

; Įkeliame Slenkstinius Nustatymus (Thresholds) iš config.ini
LoadThresholdSettings()

; Inicijuojame / Patikriname Log Failą iš Nustatymų
InitLogFilePath()

; Įkeliame Rėmelių Pozicijas iš config.ini
LoadOverlayPositions()

; Sukuriame Stebėjimo Rėmelius Overlay (Display + LED)
CreateOverlayWindows()

; Įkeliame esamo logo duomenis
LoadExistingLog()

; Parodome pagrindinį langą
MainGui.Show("x100 y100 w380 h570")

; ==============================================================================
; NUSTATYMŲ IR TESTAVIMO LANGO LOGIKA (SETTINGS & LIVE TEST)
; ==============================================================================
global SettingsGui := 0
global txtTestOCRText := 0
global txtTestLEDRGB := 0
global txtTestLEDState := 0
global txtTestSegmentBright := 0

LoadThresholdSettings() {
    global configFile, threshRMin, threshRGDiff, threshRBDiff, threshBlueMin, threshBlueDiff, threshRedMin, threshRedDiff
    try {
        threshRMin := Integer(IniRead(configFile, "Thresholds2", "RMin", "70"))
        threshRGDiff := Integer(IniRead(configFile, "Thresholds2", "RGDiff", "15"))
        threshRBDiff := Integer(IniRead(configFile, "Thresholds2", "RBDiff", "15"))
        threshBlueMin := Integer(IniRead(configFile, "Thresholds2", "BlueMin", "50"))
        threshBlueDiff := Integer(IniRead(configFile, "Thresholds2", "BlueDiff", "20"))
        threshRedMin := Integer(IniRead(configFile, "Thresholds2", "RedMin", "50"))
        threshRedDiff := Integer(IniRead(configFile, "Thresholds2", "RedDiff", "20"))
    } catch {
        threshRMin := 70, threshRGDiff := 15, threshRBDiff := 15
        threshBlueMin := 50, threshBlueDiff := 20
        threshRedMin := 50, threshRedDiff := 20
    }
}

SaveThresholdSettings(edtRMin, edtRGDiff, edtRBDiff, edtBlueMin, edtBlueDiff, edtRedMin, edtRedDiff) {
    global configFile, threshRMin, threshRGDiff, threshRBDiff, threshBlueMin, threshBlueDiff, threshRedMin, threshRedDiff, sbStatus

    try {
        threshRMin := Integer(edtRMin.Value)
        threshRGDiff := Integer(edtRGDiff.Value)
        threshRBDiff := Integer(edtRBDiff.Value)
        threshBlueMin := Integer(edtBlueMin.Value)
        threshBlueDiff := Integer(edtBlueDiff.Value)
        threshRedMin := Integer(edtRedMin.Value)
        threshRedDiff := Integer(edtRedDiff.Value)

        IniWrite(threshRMin, configFile, "Thresholds2", "RMin")
        IniWrite(threshRGDiff, configFile, "Thresholds2", "RGDiff")
        IniWrite(threshRBDiff, configFile, "Thresholds2", "RBDiff")
        IniWrite(threshBlueMin, configFile, "Thresholds2", "BlueMin")
        IniWrite(threshBlueDiff, configFile, "Thresholds2", "BlueDiff")
        IniWrite(threshRedMin, configFile, "Thresholds2", "RedMin")
        IniWrite(threshRedDiff, configFile, "Thresholds2", "RedDiff")

        MsgBox("Nustatymai sėkmingai išsaugoti!", "Nustatymai", "Iconi")
        sbStatus.Text := " Slenkstiniai nustatymai išsaugoti."
    } catch as err {
        MsgBox("Klaida išsaugant nustatymus: " . err.Message, "Klaida", "Icon!")
    }
}

OpenSettingsGui(*) {
    global SettingsGui, txtTestOCRText, txtTestLEDRGB, txtTestLEDState
    global threshRMin, threshRGDiff, threshRBDiff, threshBlueMin, threshBlueDiff, threshRedMin, threshRedDiff
    global liveOCRText, liveLEDRGB, liveLEDStateStr, isMonitoring

    if (SettingsGui != 0 && WinExist(SettingsGui.Hwnd)) {
        SettingsGui.Show()
        return
    }

    ; Jei monitoringas neijungtas, paleidžiame 250 ms atnaujinimo laikmatį diagnostikai
    if (!isMonitoring) {
        SetTimer(ScanTargetRegionSequence, 250)
    }

    SettingsGui := Gui("+Owner" . MainGui.Hwnd . " +AlwaysOnTop", "Atpažinimo Nustatymai IR Live Testas")
    SettingsGui.SetFont("s9", "Segoe UI")
    SettingsGui.BackColor := "0xF4F6F9"

    ; 1. Grupinis Rėmelis: OCR Binarizacijos Slenksčiai
    SettingsGui.Add("GroupBox", "x15 y12 w370 h115", "7-Segmentų Raudonos Display Binarizacija")

    SettingsGui.Add("Text", "x30 y35 w150", "Min. Raudona (R >):")
    edtRMin := SettingsGui.Add("Edit", "x180 y32 w60 Center", threshRMin)
    SettingsGui.Add("UpDown", "Range0-255", threshRMin)

    SettingsGui.Add("Text", "x30 y62 w150", "R ir G skirtumas (R - G >):")
    edtRGDiff := SettingsGui.Add("Edit", "x180 y59 w60 Center", threshRGDiff)
    SettingsGui.Add("UpDown", "Range0-255", threshRGDiff)

    SettingsGui.Add("Text", "x30 y89 w150", "R ir B skirtumas (R - B >):")
    edtRBDiff := SettingsGui.Add("Edit", "x180 y86 w60 Center", threshRBDiff)
    SettingsGui.Add("UpDown", "Range0-255", threshRBDiff)

    ; 2. Grupinis Rėmelis: LED Indikatoriaus Slenksčiai
    SettingsGui.Add("GroupBox", "x15 y135 w370 h140", "LED Indikatoriaus Spalvų Aptikimas")

    SettingsGui.Add("Text", "x30 y158 w150", "Mėlyna Min (B >):")
    edtBlueMin := SettingsGui.Add("Edit", "x180 y155 w60 Center", threshBlueMin)
    SettingsGui.Add("UpDown", "Range0-255", threshBlueMin)

    SettingsGui.Add("Text", "x30 y185 w150", "Mėlynas Skirtumas (B-R/G):")
    edtBlueDiff := SettingsGui.Add("Edit", "x180 y182 w60 Center", threshBlueDiff)
    SettingsGui.Add("UpDown", "Range0-255", threshBlueDiff)

    SettingsGui.Add("Text", "x30 y212 w150", "Raudona Min (R >):")
    edtRedMin := SettingsGui.Add("Edit", "x180 y209 w60 Center", threshRedMin)
    SettingsGui.Add("UpDown", "Range0-255", threshRedMin)

    SettingsGui.Add("Text", "x30 y239 w150", "Raudonas Skirtumas (R-B/G):")
    edtRedDiff := SettingsGui.Add("Edit", "x180 y236 w60 Center", threshRedDiff)
    SettingsGui.Add("UpDown", "Range0-255", threshRedDiff)

    ; 3. Grupinis Rėmelis: LIVE TEST / DIAGNOSTIKA
    SettingsGui.Add("GroupBox", "x15 y283 w370 h130", "🔍 TESTINIS LANGELIS (Šalia matoma ką supranta AHK)")

    SettingsGui.SetFont("s10 bold", "Consolas")
    SettingsGui.Add("Text", "x30 y303 w140 c0x555555", "Šiuo metu mato OCR:")
    txtTestOCRText := SettingsGui.Add("Text", "x175 y303 w195 c0x1976D2", liveOCRText != "" ? liveOCRText : "[ -- ]")

    SettingsGui.SetFont("s9 norm", "Segoe UI")
    SettingsGui.Add("Text", "x30 y328 w140 c0x555555", "Display Raudona (R):")
    txtTestSegmentBright := SettingsGui.Add("Text", "x175 y328 w195 c0xC62828", liveDisplayRedBright)
    txtTestSegmentBright.SetFont("bold")

    SettingsGui.Add("Text", "x30 y353 w140 c0x555555", "LED Pikselio RGB:")
    txtTestLEDRGB := SettingsGui.Add("Text", "x175 y353 w195 c0x2C3E50", liveLEDRGB)

    SettingsGui.Add("Text", "x30 y378 w140 c0x555555", "LED Statusas:")
    txtTestLEDState := SettingsGui.Add("Text", "x175 y378 w195 c0x2E7D32", liveLEDStateStr)

    ; Mygtukai
    btnSaveSet := SettingsGui.Add("Button", "x80 y425 w110 h32", "💾 Išsaugoti")
    btnSaveSet.SetFont("bold")
    btnCloseSet := SettingsGui.Add("Button", "x210 y425 w110 h32", "Uždaryti")

    btnSaveSet.OnEvent("Click", (*) => SaveThresholdSettings(edtRMin, edtRGDiff, edtRBDiff, edtBlueMin, edtBlueDiff, edtRedMin, edtRedDiff))
    btnCloseSet.OnEvent("Click", (*) => CloseSettingsGui())
    SettingsGui.OnEvent("Close", (*) => CloseSettingsGui())

    SettingsGui.Show("w400 h475")
}

CloseSettingsGui() {
    global SettingsGui, isMonitoring
    if (SettingsGui != 0) {
        SettingsGui.Hide()
    }
    if (!isMonitoring) {
        SetTimer(ScanTargetRegionSequence, 0)
    }
}

; ==============================================================================
; LOG FAILO IR OVERLAY POS PERSISTENCE
; ==============================================================================
InitLogFilePath() {
    global configFile, logFilePath, sbStatus

    try {
        logFilePath := IniRead(configFile, "Settings2", "LogFilePath", "")
    } catch {
        logFilePath := ""
    }

    if (logFilePath == "" || !HasValidLogExtension(logFilePath)) {
        MsgBox("Prieš pradedant darbą, prašome pasirinkti arba sukurti log failą.", "Log Failo Nustatymas", "Iconi")
        selectedPath := FileSelect("S16", A_ScriptDir . "\id_log_seq.txt", "Pasirinkite arba sukurkite LOG failą", "Tekstiniai failai (*.txt; *.log)")
        if (selectedPath != "") {
            logFilePath := selectedPath
            try {
                IniWrite(logFilePath, configFile, "Settings2", "LogFilePath")
            }
        } else {
            ExitApp()
        }
    }

    sbStatus.Text := " Aktyvus Log failas: " . logFilePath
}

HasValidLogExtension(path) {
    return (RegExMatch(path, "i)\.(txt|log)$") > 0)
}

LoadOverlayPositions() {
    global configFile, overlayX, overlayY, overlayW, overlayH, ledOverlayX, ledOverlayY, ledOverlayW, ledOverlayH
    try {
        overlayX := Integer(IniRead(configFile, "Overlay2", "X", "300"))
        overlayY := Integer(IniRead(configFile, "Overlay2", "Y", "200"))
        overlayW := Integer(IniRead(configFile, "Overlay2", "W", "200"))
        overlayH := Integer(IniRead(configFile, "Overlay2", "H", "100"))

        ledOverlayX := Integer(IniRead(configFile, "LEDOverlay2", "X", "520"))
        ledOverlayY := Integer(IniRead(configFile, "LEDOverlay2", "Y", "200"))
        ledOverlayW := Integer(IniRead(configFile, "LEDOverlay2", "W", "40"))
        ledOverlayH := Integer(IniRead(configFile, "LEDOverlay2", "H", "40"))
    } catch {
        overlayX := 300, overlayY := 200, overlayW := 200, overlayH := 100
        ledOverlayX := 520, ledOverlayY := 200, ledOverlayW := 40, ledOverlayH := 40
    }
}

SaveOverlayPositions(*) {
    global configFile, OverlayGui, LEDOverlayGui
    if (WinExist(OverlayGui.Hwnd)) {
        try {
            OverlayGui.GetPos(&x, &y, &w, &h)
            if (w > 10 && h > 10) {
                IniWrite(x, configFile, "Overlay2", "X")
                IniWrite(y, configFile, "Overlay2", "Y")
                IniWrite(w, configFile, "Overlay2", "W")
                IniWrite(h, configFile, "Overlay2", "H")
            }
        } catch {
            return
        }
    }

    if (WinExist(LEDOverlayGui.Hwnd)) {
        try {
            LEDOverlayGui.GetPos(&lx, &ly, &lw, &lh)
            if (lw > 5 && lh > 5) {
                IniWrite(lx, configFile, "LEDOverlay2", "X")
                IniWrite(ly, configFile, "LEDOverlay2", "Y")
                IniWrite(lw, configFile, "LEDOverlay2", "W")
                IniWrite(lh, configFile, "LEDOverlay2", "H")
            }
        } catch {
            return
        }
    }
}

; ==============================================================================
; STEBĖJIMO RĖMELIŲ (OVERLAY) KŪRIMAS
; ==============================================================================
CreateOverlayWindows() {
    global OverlayGui, LEDOverlayGui, overlayX, overlayY, overlayW, overlayH, ledOverlayX, ledOverlayY, ledOverlayW, ledOverlayH

    ; 1. Display Overlay (Raudonas Rėmelis 2-jų skaitmenų ekranėliui)
    OverlayGui := Gui("+AlwaysOnTop +ToolWindow +Resize -Caption +E0x00080000", "Stebėjimo Rėmelis 2")
    OverlayGui.BackColor := "0xFF0000"
    WinSetTransColor("0xFE00FE 255", OverlayGui)
    OverlayGui.MarginX := 0
    OverlayGui.MarginY := 0
    OverlayGui.Add("Text", "x4 y4 w" . (overlayW-8) . " h" . (overlayH-8) . " Background0xFE00FE vInnerBox")
    OverlayGui.OnEvent("Size", OnOverlayResize)

    ; 2. Mėlyno LED Overlay (Mėlynas Rėmelis būsenos LED'ui)
    LEDOverlayGui := Gui("+AlwaysOnTop +ToolWindow +Resize -Caption +E0x00080000", "LED Stebėjimo Rėmelis")
    LEDOverlayGui.BackColor := "0x0088FF"
    WinSetTransColor("0xFE00FE 255", LEDOverlayGui)
    LEDOverlayGui.MarginX := 0
    LEDOverlayGui.MarginY := 0
    LEDOverlayGui.Add("Text", "x3 y3 w" . (ledOverlayW-6) . " h" . (ledOverlayH-6) . " Background0xFE00FE vLEDInnerBox")
    LEDOverlayGui.OnEvent("Size", OnLEDOverlayResize)

    OnMessage(0x0204, WM_RBUTTONDOWN)
    OnMessage(0x0232, WM_EXITSIZEMOVE)

    OverlayGui.Show("x" . overlayX . " y" . overlayY . " w" . overlayW . " h" . overlayH . " NoActivate")
    LEDOverlayGui.Show("x" . ledOverlayX . " y" . ledOverlayY . " w" . ledOverlayW . " h" . ledOverlayH . " NoActivate")
}

WM_RBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global OverlayGui, LEDOverlayGui
    if (WinExist(OverlayGui.Hwnd) && (hwnd == OverlayGui.Hwnd || DllCall("IsChild", "Ptr", OverlayGui.Hwnd, "Ptr", hwnd))) {
        PostMessage(0xA1, 2,,, OverlayGui.Hwnd)
    } else if (WinExist(LEDOverlayGui.Hwnd) && (hwnd == LEDOverlayGui.Hwnd || DllCall("IsChild", "Ptr", LEDOverlayGui.Hwnd, "Ptr", hwnd))) {
        PostMessage(0xA1, 2,,, LEDOverlayGui.Hwnd)
    }
}

WM_EXITSIZEMOVE(wParam, lParam, msg, hwnd) {
    global OverlayGui, LEDOverlayGui
    if ((WinExist(OverlayGui.Hwnd) && hwnd == OverlayGui.Hwnd) || (WinExist(LEDOverlayGui.Hwnd) && hwnd == LEDOverlayGui.Hwnd)) {
        SaveOverlayPositions()
    }
}

OnOverlayResize(thisGui, minMax, width, height) {
    global overlayW, overlayH
    if (minMax != -1 && width > 10 && height > 10) {
        overlayW := width
        overlayH := height
        try {
            thisGui["InnerBox"].Move(4, 4, width - 8, height - 8)
        } catch {
            ; Fallback
        }
        SaveOverlayPositions()
    }
}

OnLEDOverlayResize(thisGui, minMax, width, height) {
    global ledOverlayW, ledOverlayH
    if (minMax != -1 && width > 5 && height > 5) {
        ledOverlayW := width
        ledOverlayH := height
        try {
            thisGui["LEDInnerBox"].Move(3, 3, width - 6, height - 6)
        } catch {
            ; Fallback
        }
        SaveOverlayPositions()
    }
}

ToggleOverlays(*) {
    global OverlayGui, LEDOverlayGui, sbStatus
    if (WinExist(OverlayGui.Hwnd)) {
        if (DllCall("IsWindowVisible", "Ptr", OverlayGui.Hwnd)) {
            OverlayGui.Hide()
            if (WinExist(LEDOverlayGui.Hwnd))
                LEDOverlayGui.Hide()
            sbStatus.Text := " Stebėjimo rėmeliai paslėpti."
        } else {
            OverlayGui.Show("NoActivate")
            if (WinExist(LEDOverlayGui.Hwnd))
                LEDOverlayGui.Show("NoActivate")
            sbStatus.Text := " Stebėjimo rėmeliai rodomi (Dešinys mygtukas - stumdyti, Kairys mygtukas - didinti)."
        }
    }
}

; ==============================================================================
; MONITORINGO LOGIKA IR SCANNING TIMER (250 ms Ciklas)
; ==============================================================================
ToggleMonitoring(*) {
    global isMonitoring, btnStart, txtStatus, sbStatus

    isMonitoring := !isMonitoring

    if (isMonitoring) {
        btnStart.Text := "⏸ Pauzė"
        txtStatus.Text := "Stebima..."
        txtStatus.SetFont("c0x2E7D32")
        sbStatus.Text := " Aktyvus stebėjimas (LED būsena ir 2-skaitmenų sekos rinkimas)."
        SetTimer(ScanTargetRegionSequence, 250)
    } else {
        btnStart.Text := "▶ Pradėti"
        txtStatus.Text := "Sustabdyta"
        txtStatus.SetFont("c0xC62828")
        sbStatus.Text := " Stebėjimas pristabdytas."
        SetTimer(ScanTargetRegionSequence, 0)
    }
}

ScanTargetRegionSequence() {
    global OverlayGui, LEDOverlayGui, isMonitoring, isScanningActive, SettingsGui
    global sequenceBuffer, isCapturingID, lastSeenToken, lastTokenTime, bufferTimeoutMs
    global isBlueLEDActive, txtLEDStatus, lastFrameHash

    isSettingsOpen := (SettingsGui != 0 && WinExist(SettingsGui.Hwnd))
    if ((!isMonitoring && !isSettingsOpen) || !WinExist(OverlayGui.Hwnd) || isScanningActive)
        return

    isScanningActive := true

    ; 1. PATIKRINAME MĖLYNO LED INDIKATORIAUS BŪSENĄ
    checkBlueLEDState()

    now := A_TickCount

    ; Jei Mėlynas LED neaktyvus (nebemirksi / išėjo iš ID režimo) ARBA timeout'as (6 sek) -> atšaukiame ID rinkimą!
    if (isCapturingID && (!isBlueLEDActive || (now - lastTokenTime > bufferTimeoutMs))) {
        isCapturingID := false
        sequenceBuffer := []
        lastSeenToken := ""
        lastFrameHash := ""
        UpdateSequenceProgressUI()
    }

    ; 2. SKAITMENŲ EKRANĖLIO PROCESAVIMAS
    OverlayGui.GetPos(&x, &y, &w, &h)
    rx := x + 4
    ry := y + 4
    rw := w - 8
    rh := h - 8

    if (rw <= 0 || rh <= 0) {
        isScanningActive := false
        return
    }

    ; Gauname binarizuotą 7-segmentų vaizdo pavyzdį bei jo kontrolinę suma (Hash)
    frameData := CaptureAndBinarizeRedLED(rx, ry, rw, rh)

    ; Atnaujiname diagnostinį raudonos šviesumo tekstą kaskart atlikus kadrą
    if (SettingsGui != 0 && WinExist(SettingsGui.Hwnd)) {
        try {
            txtTestSegmentBright.Text := liveDisplayRedBright
        } catch {
            ; Fallback
        }
    }

    if (frameData.Has("hash") && frameData["hash"] != "") {
        currentHash := frameData["hash"]

        ; TIKRINAME CACHE: Jei vaizdas nepasikeitė nuo praėjusio tiko, NENAUDOJAME CPU ir nešaukiame OCR!
        if (currentHash == lastFrameHash) {
            if FileExist(frameData["imagePath"])
                try FileDelete(frameData["imagePath"])
            isScanningActive := false
            return
        }

        ; Vaizdas pasikeitė! Vykdome OCR tik naujam kadrui
        detectedText := RunNativeWinRTOCR(frameData["imagePath"])
        if FileExist(frameData["imagePath"])
            try FileDelete(frameData["imagePath"])

        liveOCRText := (detectedText != "") ? detectedText : "[ -- ]"
        if (SettingsGui != 0 && WinExist(SettingsGui.Hwnd)) {
            try {
                txtTestOCRText.Text := liveOCRText
            } catch {
                ; Fallback
            }
        }

        if (detectedText != "") {
            if RegExMatch(detectedText, "i)\b[A-Z0-9]{2}\b", &match) {
                token := StrUpper(match[0])

                if (token != lastSeenToken) {
                    lastSeenToken := token
                    lastTokenTime := now
                    lastFrameHash := currentHash

                    ; A. ID Pradžia
                    if (token == "ID" || token == "1D") {
                        if (isBlueLEDActive) {
                            isCapturingID := true
                            sequenceBuffer := []
                            UpdateSequenceProgressUI()
                        }
                    }
                    ; B. PN / Ne ID režimas
                    else if (token == "PN" || token == "1N" || token == "P1") {
                        isCapturingID := false
                        sequenceBuffer := []
                        UpdateSequenceProgressUI()
                    }
                    ; C. Sekos Porų Rinkimas
                    else if (isCapturingID && isBlueLEDActive) {
                        sequenceBuffer.Push(token)
                        UpdateSequenceProgressUI()

                        ; Kai surenkame 6 poras (12 simbolių ID)
                        if (sequenceBuffer.Length == 6) {
                            assembledID := ""
                            for pair in sequenceBuffer {
                                assembledID .= pair
                            }

                            if (!capturedHistory.Has(assembledID) && assembledID != lastCapturedID) {
                                ProcessNewID(assembledID)
                            }

                            isCapturingID := false
                            sequenceBuffer := []
                            UpdateSequenceProgressUI()
                        }
                    }
                }
            }
        } else {
            lastFrameHash := currentHash
        }
    }

    isScanningActive := false
}

; ==============================================================================
; MĖLYNO LED CHECK (PIXEL COLOR CHECKING)
; ==============================================================================
checkBlueLEDState() {
    global LEDOverlayGui, isBlueLEDActive, txtLEDStatus, lastLEDCheckTime
    global threshBlueMin, threshBlueDiff, threshRedMin, threshRedDiff
    global liveLEDRGB, liveLEDStateStr, txtTestLEDRGB, txtTestLEDState, SettingsGui

    if (!WinExist(LEDOverlayGui.Hwnd))
        return

    CoordMode("Pixel", "Screen")
    LEDOverlayGui.GetPos(&lx, &ly, &lw, &lh)

    bestR := 0, bestG := 0, bestB := 0
    maxVal := -1

    ; Mėginame 5x5 pikselių tinklelį LED overlay langelyje ryškiausiam spaudui surasti
    Loop 5 {
        stepY := A_Index
        sampleY := ly + (lh * stepY // 6)
        Loop 5 {
            stepX := A_Index
            sampleX := lx + (lw * stepX // 6)

            try {
                pixelColor := PixelGetColor(sampleX, sampleY, "RGB")
                rVal := (pixelColor >> 16) & 0xFF
                gVal := (pixelColor >> 8) & 0xFF
                bVal := pixelColor & 0xFF

                intensity := rVal + gVal + bVal
                if (intensity > maxVal) {
                    maxVal := intensity
                    bestR := rVal
                    bestG := gVal
                    bestB := bVal
                }
            } catch {
                ; Ignoruojame
            }
        }
    }

    ; Multi-frame persistence LED stebėjimas mirgantiems puslaidininkiams
    static ledRHistory := [], ledGHistory := [], ledBHistory := []

    ledRHistory.Push(bestR)
    ledGHistory.Push(bestG)
    ledBHistory.Push(bestB)

    if (ledRHistory.Length > 4) {
        ledRHistory.RemoveAt(1)
        ledGHistory.RemoveAt(1)
        ledBHistory.RemoveAt(1)
    }

    maxR := 0, maxG := 0, maxB := 0
    for val in ledRHistory
        if (val > maxR)
            maxR := val
    for val in ledGHistory
        if (val > maxG)
            maxG := val
    for val in ledBHistory
        if (val > maxB)
            maxB := val

    r := maxR, g := maxG, b := maxB
    liveLEDRGB := "R: " . r . "  G: " . g . "  B: " . b

    try {
        ; Tikriname LED spalvos būseną pagal konfigūruojamus slenksčius
        if (b > (r + threshBlueDiff) && b > (g + threshBlueDiff) && b >= threshBlueMin) {
            isBlueLEDActive := true
            liveLEDStateStr := "● Mirksi Mėlyna (Aktyvus)"
            txtLEDStatus.Text := "● Mirksi / Aktyvus"
            txtLEDStatus.SetFont("c0x1976D2 bold")
        } else if (r > (b + threshRedDiff) && r > (g + threshRedDiff) && r >= threshRedMin) {
            isBlueLEDActive := false
            liveLEDStateStr := "■ Dega Raudona (User rėžimas)"
            txtLEDStatus.Text := "User rėžimas, įjunkite BT"
            txtLEDStatus.SetFont("c0xC62828 bold")
        } else {
            isBlueLEDActive := false
            liveLEDStateStr := "○ Neaktyvus / Nežinoma"
            txtLEDStatus.Text := "○ Neaktyvus / Išėjo"
            txtLEDStatus.SetFont("c0x7F8C8D bold")
        }

        ; Atnaujiname Live Test langelį jei atidarytas
        if (SettingsGui != 0 && WinExist(SettingsGui.Hwnd)) {
            try {
                txtTestLEDRGB.Text := liveLEDRGB
                txtTestLEDState.Text := liveLEDStateStr
            } catch {
                ; Fallback
            }
        }
    } catch {
        isBlueLEDActive := false
    }
}

UpdateSequenceProgressUI() {
    global sequenceBuffer, isCapturingID, txtSequenceProgress
    if (!isCapturingID && sequenceBuffer.Length == 0) {
        txtSequenceProgress.Text := "Laukiama 'ID'..."
        return
    }

    displayStr := "[ "
    Loop 6 {
        if (A_Index <= sequenceBuffer.Length) {
            displayStr .= sequenceBuffer[A_Index] . " "
        } else {
            displayStr .= "__ "
        }
    }
    displayStr .= "]"
    txtSequenceProgress.Text := displayStr
}

; ==============================================================================
; RED 7-SEGMENT LED BINARIZATION (High-Contrast Black on White) & CACHING
; ==============================================================================
CaptureAndBinarizeRedLED(x, y, w, h) {
    global OverlayGui
    result := Map()
    tempImgPath := A_Temp . "\id_ocr_bin_" . A_TickCount . ".bmp"

    ; Paslepariame stebėjimo rėmelį milisekundei kadrų fotografavimo metu
    if (WinExist(OverlayGui.Hwnd))
        OverlayGui.Hide()

    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")

    ; Išsaugome tikrą RGB kadrą neperrašinėdami spalvų į nespalvotą
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020)

    if (WinExist(OverlayGui.Hwnd))
        OverlayGui.Show("NoActivate")

    ; GDI+ Binarizacija (Slenkstinis Raudonos Spalvos Atskyrimas)
    pGpBitmap := 0
    static pToken := 0
    if (!pToken) {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)
    }

    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &pGpBitmap)

    if (pGpBitmap) {
        ; Greitas pikselių apdorojimas per LockBits
        Rect := Buffer(16, 0)
        NumPut("Int", w, Rect, 8)
        NumPut("Int", h, Rect, 12)

        BitmapData := Buffer(32, 0)
        ; PixelFormat32bppARGB = 0x26200A
        DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pGpBitmap, "Ptr", Rect, "UInt", 3, "Int", 0x26200A, "Ptr", BitmapData)

        scan0 := NumGet(BitmapData, 16, "Ptr")
        stride := NumGet(BitmapData, 8, "Int")

        pixelCount := w * h
        hashVal := 0
        maxRedVal := 0

        ; Mėginių kaupimo (Anti-Flicker persistence) buferis kameros mirgėjimui suvaldyti
        static pixelHistory := Map()
        currentPixels := Map()

        Loop h {
            rowY := A_Index - 1
            rowPtr := scan0 + (rowY * stride)
            Loop w {
                colX := A_Index - 1
                pPtr := rowPtr + (colX * 4)

                bVal := NumGet(pPtr, 0, "UChar")
                gVal := NumGet(pPtr, 1, "UChar")
                rVal := NumGet(pPtr, 2, "UChar")

                if (rVal > maxRedVal)
                    maxRedVal := rVal

                pxIdx := rowY * w + colX

                ; Jei Raudonas LED elementas pagal konfigūruojamus slenksčius
                if (rVal >= threshRMin && rVal > (gVal + threshRGDiff) && rVal > (bVal + threshRBDiff)) {
                    currentPixels[pxIdx] := 3 ; Išlaikome pikselį 3 kadruose
                }
            }
        }

        global liveDisplayRedBright := "R: " . maxRedVal . " / 255"

        ; Atnaujiname ir sujungiame praėjusių kadrų atmintį su esamu kadru
        newHistory := Map()
        for idx, ttl in pixelHistory {
            if (ttl > 1)
                newHistory[idx] := ttl - 1
        }
        for idx, ttl in currentPixels {
            newHistory[idx] := ttl
        }
        pixelHistory := newHistory

        ; Įrašome binarizuotus pikselius (Juoda ant Balto)
        Loop h {
            rowY := A_Index - 1
            rowPtr := scan0 + (rowY * stride)
            Loop w {
                colX := A_Index - 1
                pPtr := rowPtr + (colX * 4)
                pxIdx := rowY * w + colX

                if pixelHistory.Has(pxIdx) {
                    NumPut("UChar", 0, pPtr, 0)
                    NumPut("UChar", 0, pPtr, 1)
                    NumPut("UChar", 0, pPtr, 2)
                    hashVal += pxIdx
                } else {
                    NumPut("UChar", 255, pPtr, 0)
                    NumPut("UChar", 255, pPtr, 1)
                    NumPut("UChar", 255, pPtr, 2)
                }
            }
        }

        DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pGpBitmap, "Ptr", BitmapData)

        ; Išsaugome į failą
        clsid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF400-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
        DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pGpBitmap, "WStr", tempImgPath, "Ptr", clsid, "Ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pGpBitmap)

        result["hash"] := String(hashVal)
        result["imagePath"] := tempImgPath
    }

    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld, "Ptr")
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    DllCall("DeleteObject", "Ptr", hbm)

    return result
}

RunNativeWinRTOCR(imagePath) {
    if (!FileExist(imagePath))
        return ""

    outPath := A_Temp . "\id_ocr_res2.txt"
    if FileExist(outPath)
        try FileDelete(outPath)

    ; 1. PIRMENYBĖ: Python + OpenCV 7-Segmentų LED Apdorojimo Pagalbininkas (led_ocr.py)
    pythonScript := A_ScriptDir . "\led_ocr.py"
    if FileExist(pythonScript) {
        try {
            pyCommand := 'python.exe "' . pythonScript . '" "' . imagePath . '" > "' . outPath . '"'
            RunWait('cmd.exe /c "' . pyCommand . '"', , "Hide")

            if FileExist(outPath) {
                pyOutput := Trim(FileRead(outPath, "UTF-8"))
                try FileDelete(outPath)
                if (pyOutput != "")
                    return pyOutput
            }
        } catch {
            ; Fallback į WinRT PowerShell OCR
        }
    }

    ; 2. FALLBACK: Windows Native WinRT OCR (PowerShell)
    try {
        psScript := "[void][Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]; "
            . "$file = [Windows.Storage.StorageFile, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]::GetFileFromPathAsync('" . imagePath . "').GetResults(); "
            . "$stream = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read).GetResults(); "
            . "$bmp = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]::CreateAsync($stream).GetResults(); "
            . "$sBmp = $bmp.GetSoftwareBitmapAsync().GetResults(); "
            . "$ocr = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages(); "
            . "$res = $ocr.RecognizeAsync($sBmp).GetResults(); "
            . "if ($res -and $res.Text) { $res.Text | Out-File -FilePath '" . outPath . "' -Encoding utf8 }"

        psCommand := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "' . psScript . '"'
        RunWait(psCommand, , "Hide")

        if FileExist(outPath) {
            ocrOutput := FileRead(outPath, "UTF-8")
            try FileDelete(outPath)
            return Trim(ocrOutput)
        }
        return ""
    } catch {
        return ""
    }
}

; ==============================================================================
; NAUJO ID APDOROJIMAS IR FLASH EFEKTAS
; ==============================================================================
ProcessNewID(newID) {
    global lastCapturedID, capturedCount, txtCount, txtLastID, lvHistory, logFilePath, capturedHistory, sbStatus

    lastCapturedID := newID
    capturedHistory[newID] := true
    capturedCount++
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    txtCount.Text := capturedCount . " vnt."
    txtLastID.Text := newID

    lvHistory.Insert(1,, timestamp, newID)
    AppendToLogFile(timestamp, newID)
    TriggerGreenFlash()

    sbStatus.Text := " [" . timestamp . "] Pagautas pilnas 12-skaitmenų ID: " . newID
}

AppendToLogFile(timestamp, id) {
    global logFilePath, sbStatus
    try {
        logLine := timestamp . " - " . id . "`n"
        FileAppend(logLine, logFilePath, "UTF-8")
    } catch as err {
        sbStatus.Text := " Klaida rašant į log failą: " . err.Message
    }
}

TriggerGreenFlash() {
    global idBoxBg, txtLastID, isFlashing

    if (isFlashing) {
        SetTimer(ResetFlashColor, 0)
    }

    isFlashing := true
    txtLastID.SetFont("cFFFFFF")
    idBoxBg.Value := 100
    WinRedraw(txtLastID.Hwnd)

    SetTimer(ResetFlashColor, -600)
}

ResetFlashColor() {
    global idBoxBg, txtLastID, isFlashing
    txtLastID.SetFont("c0x2C3E50")
    idBoxBg.Value := 0
    WinRedraw(txtLastID.Hwnd)
    isFlashing := false
}

; ==============================================================================
; PASIŪLYMAI IR NUSTATYMAI
; ==============================================================================
SelectLogFile(*) {
    global configFile, logFilePath, sbStatus
    selected := FileSelect("S16", logFilePath != "" ? logFilePath : A_ScriptDir . "\id_log_seq.txt", "Pasirinkite arba sukurkite log failą", "Tekstiniai failai (*.txt; *.log)")
    if (selected != "") {
        logFilePath := selected
        try {
            IniWrite(logFilePath, configFile, "Settings2", "LogFilePath")
        } catch {
            ; Fallback
        }
        sbStatus.Text := " Log failas pakeistas į: " . logFilePath
        LoadExistingLog()
    }
}

LoadExistingLog() {
    global logFilePath, lvHistory, capturedCount, capturedHistory, txtCount, txtLastID, sbStatus
    lvHistory.Delete()
    capturedCount := 0
    capturedHistory := Map()

    if (logFilePath == "" || !FileExist(logFilePath))
        return

    try {
        fileContent := FileRead(logFilePath, "UTF-8")
        Loop Parse, fileContent, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line == "")
                continue

            parts := StrSplit(line, " - ")
            if (parts.Length >= 2) {
                tStamp := parts[1]
                idCode := parts[2]
                lvHistory.Insert(1,, tStamp, idCode)
                capturedCount++
                capturedHistory[idCode] := true
            }
        }
        txtCount.Text := capturedCount . " vnt."
        sbStatus.Text := " Įkelta " . capturedCount . " įrašų iš logo failo: " . logFilePath
    } catch {
        sbStatus.Text := " Nepavyko įkelti esamo logo failo."
    }
}

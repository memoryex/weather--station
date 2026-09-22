; ==============================================================================
; Appliance ID Slenkančio Ekrano (2 Skaitmenų Sekos) Stebėjimo ir Logavimo Programa
; Ver: 2.2 (AutoHotkey v2.0 - USB WebCam / 7-Segment Red Display & Blue LED Tracker)
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Užtikriname Dpi Awareness V2, kad ekrano koordinatės atitiktų 1:1 physical pixels
try {
    DllCall("SetThreadDpiAwarenessContext", "Ptr", -4)
}

; Global Kintamieji
global isMonitoring := false
global isDirectLogMode := false
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
MainGui.Add("GroupBox", "x15 y152 w350 h65", "Rinkimo Režimas")
chkDirectLog := MainGui.Add("Checkbox", "x25 y170 w330 h20", "Tiesioginis registravimas (Be 'ID' sekos)")
chkDirectLog.OnEvent("Click", (*) => (isDirectLogMode := chkDirectLog.Value))
MainGui.SetFont("s11 bold", "Consolas")
txtSequenceProgress := MainGui.Add("Text", "x25 y190 w330 Center c0x1976D2", "Laukiama 'ID'...")
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
global picBinarizedPreview := 0
global txtRMinVal := 0
global txtRGDiffVal := 0
global txtRBDiffVal := 0

LoadThresholdSettings() {
    global configFile, threshRMin, threshRGDiff, threshRBDiff, threshBlueMin, threshBlueDiff, threshRedMin, threshRedDiff
    try {
        threshRMin := Integer(IniRead(configFile, "Thresholds2", "RMin", "45"))
        threshRGDiff := Integer(IniRead(configFile, "Thresholds2", "RGDiff", "10"))
        threshRBDiff := Integer(IniRead(configFile, "Thresholds2", "RBDiff", "10"))
        threshBlueMin := Integer(IniRead(configFile, "Thresholds2", "BlueMin", "50"))
        threshBlueDiff := Integer(IniRead(configFile, "Thresholds2", "BlueDiff", "20"))
        threshRedMin := Integer(IniRead(configFile, "Thresholds2", "RedMin", "45"))
        threshRedDiff := Integer(IniRead(configFile, "Thresholds2", "RedDiff", "10"))
    } catch {
        threshRMin := 45, threshRGDiff := 10, threshRBDiff := 10
        threshBlueMin := 50, threshBlueDiff := 20
        threshRedMin := 45, threshRedDiff := 10
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
    global SettingsGui, txtTestOCRText, txtTestLEDRGB, txtTestLEDState, picBinarizedPreview
    global txtRMinVal, txtRGDiffVal, txtRBDiffVal
    global threshRMin, threshRGDiff, threshRBDiff, threshBlueMin, threshBlueDiff, threshRedMin, threshRedDiff
    global liveOCRText, liveLEDRGB, liveLEDStateStr, isMonitoring

    if (SettingsGui != 0 && WinExist(SettingsGui.Hwnd)) {
        SettingsGui.Show()
        return
    }

    ; Jei monitoringas neijungtas, paleidžiame 80 ms atnaujinimo laikmatį diagnostikai
    if (!isMonitoring) {
        SetTimer(ScanTargetRegionSequence, 80)
    }

    SettingsGui := Gui("+Owner" . MainGui.Hwnd . " +AlwaysOnTop", "Atpažinimo Nustatymai, Šliaužikliai ir Binarizacijos Vaizdas")
    SettingsGui.SetFont("s9", "Segoe UI")
    SettingsGui.BackColor := "0xF4F6F9"

    ; 1. Grupinis Rėmelis: Interaktyvūs Binarizacijos Šliaužikliai
    SettingsGui.Add("GroupBox", "x15 y12 w370 h165", "🎚 7-Segmentų Display Raudonos Binarizacijos Šliaužikliai")

    SettingsGui.Add("Text", "x30 y35 w150", "Min. Raudona (R >):")
    txtRMinVal := SettingsGui.Add("Text", "x180 y35 w40 Right c0xC62828", threshRMin)
    txtRMinVal.SetFont("bold")
    sldRMin := SettingsGui.Add("Slider", "x225 y32 w140 h25 Range0-255 ToolTipBottom", threshRMin)

    SettingsGui.Add("Text", "x30 y75 w150", "R ir G skirtumas (R - G >):")
    txtRGDiffVal := SettingsGui.Add("Text", "x180 y75 w40 Right c0xC62828", threshRGDiff)
    txtRGDiffVal.SetFont("bold")
    sldRGDiff := SettingsGui.Add("Slider", "x225 y72 w140 h25 Range0-100 ToolTipBottom", threshRGDiff)

    SettingsGui.Add("Text", "x30 y115 w150", "R ir B skirtumas (R - B >):")
    txtRBDiffVal := SettingsGui.Add("Text", "x180 y115 w40 Right c0xC62828", threshRBDiff)
    txtRBDiffVal.SetFont("bold")
    sldRBDiff := SettingsGui.Add("Slider", "x225 y112 w140 h25 Range0-100 ToolTipBottom", threshRBDiff)

    ; 2. Vizualus OCR Binarizacijos Paveikslėlio Langas (Kaip OCR mato segmentus)
    SettingsGui.Add("GroupBox", "x395 y12 w210 h270", "🖼 OCR Binarizacijos Vaizdas")
    picBinarizedPreview := SettingsGui.Add("Picture", "x405 y35 w190 h200 +Border", "")
    SettingsGui.Add("Text", "x405 y240 w190 Center c0x555555 s8", "Binarizuotas vaizdas (Juoda/Balta)")

    ; 3. Grupinis Rėmelis: LED Indikatoriaus Slenksčiai
    SettingsGui.Add("GroupBox", "x15 y182 w370 h100", "LED Indikatoriaus Spalvų Aptikimas")

    SettingsGui.Add("Text", "x30 y205 w130", "Mėlyna Min (B >):")
    edtBlueMin := SettingsGui.Add("Edit", "x160 y202 w50 Center", threshBlueMin)
    SettingsGui.Add("UpDown", "Range0-255", threshBlueMin)

    SettingsGui.Add("Text", "x220 y205 w110", "Skirtumas (B-R/G):")
    edtBlueDiff := SettingsGui.Add("Edit", "x325 y202 w50 Center", threshBlueDiff)
    SettingsGui.Add("UpDown", "Range0-255", threshBlueDiff)

    SettingsGui.Add("Text", "x30 y242 w130", "Raudona Min (R >):")
    edtRedMin := SettingsGui.Add("Edit", "x160 y239 w50 Center", threshRedMin)
    SettingsGui.Add("UpDown", "Range0-255", threshRedMin)

    SettingsGui.Add("Text", "x220 y242 w110", "Skirtumas (R-B/G):")
    edtRedDiff := SettingsGui.Add("Edit", "x325 y239 w50 Center", threshRedDiff)
    SettingsGui.Add("UpDown", "Range0-255", threshRedDiff)

    ; 4. Grupinis Rėmelis: LIVE TEST / DIAGNOSTIKA
    SettingsGui.Add("GroupBox", "x15 y290 w590 h115", "🔍 TESTINIS LANGELIS (Live AHK būsena ir matomas tekstas)")

    SettingsGui.SetFont("s10 bold", "Consolas")
    SettingsGui.Add("Text", "x30 y310 w140 c0x555555", "Šiuo metu mato OCR:")
    txtTestOCRText := SettingsGui.Add("Text", "x175 y310 w410 c0x1976D2", liveOCRText != "" ? liveOCRText : "[ -- ]")

    SettingsGui.SetFont("s9 norm", "Segoe UI")
    SettingsGui.Add("Text", "x30 y335 w140 c0x555555", "Display Raudona (R):")
    txtTestSegmentBright := SettingsGui.Add("Text", "x175 y335 w410 c0xC62828", liveDisplayRedBright)
    txtTestSegmentBright.SetFont("bold")

    SettingsGui.Add("Text", "x30 y360 w140 c0x555555", "LED Pikselio RGB:")
    txtTestLEDRGB := SettingsGui.Add("Text", "x175 y360 w180 c0x2C3E50", liveLEDRGB)

    SettingsGui.Add("Text", "x360 y360 w90 c0x555555", "LED Statusas:")
    txtTestLEDState := SettingsGui.Add("Text", "x450 y360 w140 c0x2E7D32", liveLEDStateStr)

    ; Šliaužiklių event handlers realaus laiko binarizacijos vaizdo koregavimui
    sldRMin.OnEvent("Change", (*) => OnSliderThresholdChange(sldRMin, sldRGDiff, sldRBDiff))
    sldRGDiff.OnEvent("Change", (*) => OnSliderThresholdChange(sldRMin, sldRGDiff, sldRBDiff))
    sldRBDiff.OnEvent("Change", (*) => OnSliderThresholdChange(sldRMin, sldRGDiff, sldRBDiff))

    ; Mygtukai
    btnSaveSet := SettingsGui.Add("Button", "x180 y418 w120 h32", "💾 Išsaugoti")
    btnSaveSet.SetFont("bold")
    btnCloseSet := SettingsGui.Add("Button", "x320 y418 w120 h32", "Uždaryti")

    btnSaveSet.OnEvent("Click", (*) => SaveThresholdSettings(sldRMin, sldRGDiff, sldRBDiff, edtBlueMin, edtBlueDiff, edtRedMin, edtRedDiff))
    btnCloseSet.OnEvent("Click", (*) => CloseSettingsGui())
    SettingsGui.OnEvent("Close", (*) => CloseSettingsGui())

    SettingsGui.Show("w620 h465")
}

OnSliderThresholdChange(sldR, sldRG, sldRB) {
    global threshRMin, threshRGDiff, threshRBDiff
    global txtRMinVal, txtRGDiffVal, txtRBDiffVal

    threshRMin := Integer(sldR.Value)
    threshRGDiff := Integer(sldRG.Value)
    threshRBDiff := Integer(sldRB.Value)

    if (txtRMinVal != 0)
        txtRMinVal.Text := threshRMin
    if (txtRGDiffVal != 0)
        txtRGDiffVal.Text := threshRGDiff
    if (txtRBDiffVal != 0)
        txtRBDiffVal.Text := threshRBDiff
}

CloseSettingsGui() {
    global SettingsGui, isMonitoring
    if (SettingsGui != 0) {
        try {
            SettingsGui.Destroy()
        } catch {
            ; Fallback
        }
        SettingsGui := 0
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
    if (IsSet(OverlayGui) && WinExist(OverlayGui.Hwnd)) {
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

    if (IsSet(LEDOverlayGui) && WinExist(LEDOverlayGui.Hwnd)) {
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
; STEBĖJIMO RĖMELIŲ (OVERLAY) KŪRIMAS (Su Hollow Cutout Regionais)
; ==============================================================================
CreateOverlayWindows() {
    global OverlayGui, LEDOverlayGui, overlayX, overlayY, overlayW, overlayH, ledOverlayX, ledOverlayY, ledOverlayW, ledOverlayH

    ; 1. Display Overlay (Grynas Raudonas Hollow Rėmelis 2-jų skaitmenų ekranėliui)
    OverlayGui := Gui("+AlwaysOnTop +ToolWindow +Resize -Caption", "Stebėjimo Rėmelis 2")
    OverlayGui.BackColor := "Red"
    OverlayGui.OnEvent("Size", OnOverlayResize)

    ; 2. Mėlyno LED Overlay (Grynas Mėlynas Hollow Rėmelis būsenos LED'ui)
    LEDOverlayGui := Gui("+AlwaysOnTop +ToolWindow +Resize -Caption", "LED Stebėjimo Rėmelis")
    LEDOverlayGui.BackColor := "0x0088FF"
    LEDOverlayGui.OnEvent("Size", OnLEDOverlayResize)

    ; WM_NCCALCSIZE (0x0083) - Pašalina DWM baltus rėmelius išlaikant natūralų Windows resize palaikymą
    OnMessage(0x0083, WM_NCCALCSIZE2)

    ; WM_NCHITTEST (0x0084) - Įgalina 100% natūralų kraštinių ir kampų tempimą bei pelės kurso rodyklytes
    OnMessage(0x0084, WM_NCHITTEST_OVERLAY2)

    ; Perstumia langa desiniu peles mygtuku
    OnMessage(0x0204, WM_RBUTTONDOWN)

    OnMessage(0x0232, WM_EXITSIZEMOVE)
    OnMessage(0x0003, WM_MOVE)

    OverlayGui.Show("x" . overlayX . " y" . overlayY . " w" . overlayW . " h" . overlayH . " NoActivate")
    LEDOverlayGui.Show("x" . ledOverlayX . " y" . ledOverlayY . " w" . ledOverlayW . " h" . ledOverlayH . " NoActivate")

    UpdateOverlayRegion(OverlayGui, overlayW, overlayH, 6)
    UpdateOverlayRegion(LEDOverlayGui, ledOverlayW, ledOverlayH, 5)
}

WM_NCCALCSIZE2(wParam, lParam, msg, hwnd) {
    global OverlayGui, LEDOverlayGui
    if ((WinExist(OverlayGui.Hwnd) && hwnd == OverlayGui.Hwnd) || (WinExist(LEDOverlayGui.Hwnd) && hwnd == LEDOverlayGui.Hwnd))
        return 0 ; Pašalina DWM rėmelio apvadus
}

WM_NCHITTEST_OVERLAY2(wParam, lParam, msg, hwnd) {
    global OverlayGui, LEDOverlayGui
    targetGui := 0

    if (WinExist(OverlayGui.Hwnd) && hwnd == OverlayGui.Hwnd) {
        targetGui := OverlayGui
    } else if (WinExist(LEDOverlayGui.Hwnd) && hwnd == LEDOverlayGui.Hwnd) {
        targetGui := LEDOverlayGui
    } else {
        return
    }

    x := lParam & 0xFFFF
    if (x > 0x7FFF)
        x := x - 0x10000
    y := (lParam >> 16) & 0xFFFF
    if (y > 0x7FFF)
        y := y - 0x10000

    targetGui.GetPos(&winX, &winY, &winW, &winH)

    relX := x - winX
    relY := y - winY
    border := 8 ; 8px jautrumo zona visoms kraštinėms ir kampams

    left := (relX < border)
    right := (relX >= winW - border)
    top := (relY < border)
    bottom := (relY >= winH - border)

    if (top && left)
        return 13 ; HTTOPLEFT (↖)
    if (top && right)
        return 14 ; HTTOPRIGHT (↗)
    if (bottom && left)
        return 16 ; HTBOTTOMLEFT (↙)
    if (bottom && right)
        return 17 ; HTBOTTOMRIGHT (↘)
    if (left)
        return 10 ; HTLEFT (←)
    if (right)
        return 11 ; HTRIGHT (→)
    if (top)
        return 12 ; HTTOP (↑)
    if (bottom)
        return 15 ; HTBOTTOM (↓)

    return 2 ; HTCAPTION (vilkti kairiuoju mygtuku)
}

UpdateOverlayRegion(guiObj, width, height, borderWidth := 5) {
    if (!WinExist(guiObj.Hwnd) || width <= borderWidth * 2 || height <= borderWidth * 2)
        return

    try {
        rgnOuter := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr")
        rgnInner := DllCall("CreateRectRgn", "Int", borderWidth, "Int", borderWidth, "Int", width - borderWidth, "Int", height - borderWidth, "Ptr")

        ; RGN_DIFF = 3 (Atima vidinį stačiakampį iš išorinio, palikdamas tuščiavidurį rėmelį)
        DllCall("CombineRgn", "Ptr", rgnOuter, "Ptr", rgnOuter, "Ptr", rgnInner, "Int", 3)
        DllCall("DeleteObject", "Ptr", rgnInner)

        ; SetWindowRgn priskiria hRgn langui ir automatiškai perpiešia (bRedraw = 1)
        DllCall("SetWindowRgn", "Ptr", guiObj.Hwnd, "Ptr", rgnOuter, "Int", 1)
    } catch {
        ; Fallback
    }
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

WM_MOVE(wParam, lParam, msg, hwnd) {
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
        UpdateOverlayRegion(thisGui, width, height, 4)
        SaveOverlayPositions()
    }
}

OnLEDOverlayResize(thisGui, minMax, width, height) {
    global ledOverlayW, ledOverlayH
    if (minMax != -1 && width > 5 && height > 5) {
        ledOverlayW := width
        ledOverlayH := height
        UpdateOverlayRegion(thisGui, width, height, 3)
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
        SetTimer(ScanTargetRegionSequence, 80)
    } else {
        btnStart.Text := "▶ Pradėti"
        txtStatus.Text := "Sustabdyta"
        txtStatus.SetFont("c0xC62828")
        sbStatus.Text := " Stebėjimas pristabdytas."
        SetTimer(ScanTargetRegionSequence, 0)
    }
}

GetPhysicalWindowRect(hwnd, &x, &y, &w, &h) {
    rect := Buffer(16, 0)
    if DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect) {
        x := NumGet(rect, 0, "Int")
        y := NumGet(rect, 4, "Int")
        w := NumGet(rect, 8, "Int") - x
        h := NumGet(rect, 12, "Int") - y
        return true
    }
    return false
}

ScanTargetRegionSequence() {
    global OverlayGui, LEDOverlayGui, isMonitoring, isScanningActive, SettingsGui
    global sequenceBuffer, isCapturingID, lastSeenToken, lastTokenTime, bufferTimeoutMs
    global isBlueLEDActive, txtLEDStatus, lastFrameHash

    isSettingsOpen := (SettingsGui != 0 && WinExist(SettingsGui.Hwnd) && DllCall("IsWindowVisible", "Ptr", SettingsGui.Hwnd))
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

    ; 2. SKAITMENŲ EKRANĖLIO PROCESAVIMAS (Grynosios Vidinės Koordinatės)
    try {
        OverlayGui.GetPos(&x, &y, &w, &h)
    } catch {
        isScanningActive := false
        return
    }

    rx := x + 7
    ry := y + 7
    rw := w - 14
    rh := h - 14

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
            if (picBinarizedPreview != 0 && frameData.Has("imagePath") && FileExist(frameData["imagePath"])) {
                picBinarizedPreview.Value := "*w190 *h200 " . frameData["imagePath"]
            }
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
        detectedText := ""
        if (frameData.Has("native7Seg") && frameData["native7Seg"] != "") {
            detectedText := frameData["native7Seg"]
        }
        ; Vykdome pagalbinį OCR tik jei atpažinta raudona šviesa
        if (detectedText == "" && frameData.Has("hasRed") && frameData["hasRed"]) {
            detectedText := RunNativeWinRTOCR(frameData["imagePath"])
        }
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
            if RegExMatch(detectedText, "i)[A-Z0-9]{1,2}", &match) {
                token := StrUpper(match[0])

                if (token != lastSeenToken) {
                    lastSeenToken := token
                    lastTokenTime := now
                    lastFrameHash := currentHash

                    if (isDirectLogMode) {
                        ProcessNewID(token)
                    }
                    ; A. ID Pradžia
                    else if (token == "ID" || token == "1D") {
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
                            for idx, pair in sequenceBuffer {
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
    try {
        LEDOverlayGui.GetPos(&lx, &ly, &lw, &lh)
    } catch {
        return
    }

    ; Vidinė LED sritis be rėmelio (6px rėmelis)
    innerX := lx + 6
    innerY := ly + 6
    innerW := lw - 12
    innerH := lh - 12

    if (innerW <= 0 || innerH <= 0)
        return

    bestR := 0, bestG := 0, bestB := 0
    bestBlueProminence := -9999

    ; Mėginame 5x5 pikselių tinklelį vidinėje LED overlay srityje
    Loop 5 {
        stepY := A_Index
        sampleY := innerY + (innerH * stepY // 6)
        Loop 5 {
            stepX := A_Index
            sampleX := innerX + (innerW * stepX // 6)

            try {
                pixelColor := PixelGetColor(sampleX, sampleY, "RGB")
                rVal := (pixelColor >> 16) & 0xFF
                gVal := (pixelColor >> 8) & 0xFF
                bVal := pixelColor & 0xFF

                ; Ignoruojame permatomo/mėlyno rėmelio pakraščius
                if (rVal == 0 && gVal == 0x88 && bVal == 0xFF)
                    continue

                ; Iškaitome tašką su didžiausiu mėlynumo ryškumu ir santyku
                prominence := bVal - Max(rVal, gVal)
                if (prominence > bestBlueProminence || (prominence == bestBlueProminence && bVal > bestB)) {
                    bestBlueProminence := prominence
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
    for idx, val in ledRHistory
        if (val > maxR)
            maxR := val
    for idx, val in ledGHistory
        if (val > maxG)
            maxG := val
    for idx, val in ledBHistory
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

    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")

    ; Nuskaitome vaizdą po rėmeliu su CAPTUREBLT | SRCCOPY (0x40000000 | 0x00CC0020 = 0x40CC0020)
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x40CC0020)

    ; Win32 GDI Taisyklė: hbm BŪTINA atkabinti iš hdcMem prieš šaukiant GetDIBits!
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld, "Ptr")

    ; Nuskaitome žalius BGRX pikselius tiesiogiai iš GDI HBITMAP išvengiant GDI+ alpha zeroing problemos
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)       ; biSize
    NumPut("Int", w, bi, 4)         ; biWidth
    NumPut("Int", -h, bi, 8)        ; biHeight (negative = top-down)
    NumPut("UShort", 1, bi, 12)     ; biPlanes
    NumPut("UShort", 32, bi, 14)    ; biBitCount = 32
    NumPut("UInt", 0, bi, 16)       ; biCompression = BI_RGB

    pixelBuf := Buffer(w * h * 4, 0)
    ; NAUDOJAME hdcScreen vietoje hdcMem, kad GetDIBits gautų pilną 32-bit truecolor ekraną
    scanRes := DllCall("GetDIBits", "Ptr", hdcScreen, "Ptr", hbm, "UInt", 0, "UInt", h, "Ptr", pixelBuf, "Ptr", bi, "UInt", 0)

    hashVal := 0
    maxRedVal := 0

    static pixelHistory := Map()
    currentPixels := Map()

    CoordMode("Pixel", "Screen")

    Loop h {
        rowY := A_Index - 1
        Loop w {
            colX := A_Index - 1
            offset := (rowY * w + colX) * 4

            bVal := NumGet(pixelBuf, offset, "UChar")
            gVal := NumGet(pixelBuf, offset + 1, "UChar")
            rVal := NumGet(pixelBuf, offset + 2, "UChar")

            pxIdx := rowY * w + colX

            if (rVal > gVal && rVal > bVal && rVal > maxRedVal)
                maxRedVal := rVal

            if (rVal > (gVal + threshRGDiff) && rVal > (bVal + threshRBDiff) && rVal >= threshRMin) {
                currentPixels[pxIdx] := 3 ; Išlaikome pikselį 3 kadruose
            }
        }
    }

    ; TIESIOGINIS AHK SCREEN PIXEL READ: Nuskaitymas tiesiai per PixelGetColor užtikrina 100% matomumą visose GPU/DWM konfigūracijose
    gridCols := Min(w, 20)
    gridRows := Min(h, 15)
    if (gridCols > 0 && gridRows > 0) {
        Loop gridRows {
            rowIdx := A_Index
            sampleY := y + (h * rowIdx // (gridRows + 1))
            Loop gridCols {
                colIdx := A_Index
                sampleX := x + (w * colIdx // (gridCols + 1))
                try {
                    pCol := PixelGetColor(sampleX, sampleY, "RGB")
                    pR := (pCol >> 16) & 0xFF
                    pG := (pCol >> 8) & 0xFF
                    pB := pCol & 0xFF

                    if (pR > pG && pR > pB && pR > maxRedVal)
                        maxRedVal := pR

                    if (pR > (pG + threshRGDiff) && pR > (pB + threshRBDiff) && pR >= threshRMin) {
                        mapY := (h * rowIdx // (gridRows + 1))
                        mapX := (w * colIdx // (gridCols + 1))
                        pxIdx := (mapY * w) + mapX
                        currentPixels[pxIdx] := 3
                    }
                } catch {
                    ; Fallback
                }
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

    ; BENDROJI OCR BINARIZACIJA / SPALVŲ PALAIKYMAS (Raudona + Pilkumo/Bet kokių tekstų atpažinimas)
    binBuf := Buffer(w * h * 4, 0)
    useRedBinarization := (pixelHistory.Count > 0)

    Loop h {
        rowY := A_Index - 1
        Loop w {
            colX := A_Index - 1
            pxIdx := rowY * w + colX
            offset := pxIdx * 4

            bVal := NumGet(pixelBuf, offset, "UChar")
            gVal := NumGet(pixelBuf, offset + 1, "UChar")
            rVal := NumGet(pixelBuf, offset + 2, "UChar")

            if (useRedBinarization) {
                if pixelHistory.Has(pxIdx) {
                    NumPut("UChar", 255, binBuf, offset)     ; B
                    NumPut("UChar", 255, binBuf, offset + 1) ; G
                    NumPut("UChar", 255, binBuf, offset + 2) ; R
                    NumPut("UChar", 255, binBuf, offset + 3) ; Alpha = 255
                    hashVal += pxIdx
                } else {
                    NumPut("UChar", 0, binBuf, offset)       ; B
                    NumPut("UChar", 0, binBuf, offset + 1)   ; G
                    NumPut("UChar", 0, binBuf, offset + 2)   ; R
                    NumPut("UChar", 255, binBuf, offset + 3) ; Alpha = 255
                }
            } else {
                ; ATSARGINIS VISŲ SPALVŲ REŽIMAS: Išsaugome natūralią spalvų/kontrasto informaciją bendram OCR testavimui
                gray := Integer((rVal * 0.299) + (gVal * 0.587) + (bVal * 0.114))
                NumPut("UChar", gray, binBuf, offset)     ; B
                NumPut("UChar", gray, binBuf, offset + 1) ; G
                NumPut("UChar", gray, binBuf, offset + 2) ; R
                NumPut("UChar", 255, binBuf, offset + 3) ; Alpha = 255
                hashVal += (gray > 100 ? pxIdx : 0)
            }
        }
    }

    ; Išsaugome binarizuotą pavyzdį failui naudojant GDI+
    static pToken := 0
    if (!pToken) {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)
    }

    pGpBitmap := 0
    ; PixelFormat32bppARGB = 0x26200A
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", w * 4, "Int", 0x26200A, "Ptr", binBuf, "Ptr*", &pGpBitmap)

    if (pGpBitmap) {
        clsid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF400-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
        DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pGpBitmap, "WStr", tempImgPath, "Ptr", clsid, "Ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pGpBitmap)
    }

    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    DllCall("DeleteObject", "Ptr", hbm)

    result["hash"] := String(hashVal)
    result["imagePath"] := tempImgPath
    result["hasRed"] := (pixelHistory.Count > 0)
    result["native7Seg"] := DecodeAHK7Segment(pixelHistory, w, h)
    return result
}

RunNativeWinRTOCR(imagePath) {
    if (!FileExist(imagePath))
        return ""

    outPath := A_Temp . "\id_ocr_res2.txt"
    reqPath := A_Temp . "\id_ocr_req.txt"
    if FileExist(outPath)
        try FileDelete(outPath)

    ; 1. PIRMENYBĖ: Python + OpenCV 7-Segmentų LED Apdorojimo Pagalbininkas (led_ocr.py)
    pythonScript := A_ScriptDir . "\led_ocr.py"
    if FileExist(pythonScript) {
        try {
            ; Įrašome paveikslėlio kelią užklausos failui (UTF-8-RAW be BOM)
            FileOpen(reqPath, "w", "UTF-8-RAW").Write(imagePath)

            ; Jei Python fono langas ("7-Segment LED OCR") dar nepaleistas, paleidžiame ji matomame CMD lange fone
            if (!WinExist("7-Segment LED OCR") && !WinExist("ahk_exe python.exe")) {
                Run('cmd.exe /k "title 7-Segment LED OCR && python.exe `"' . pythonScript . '`" --watch"')
            }

            ; Laukiame iki 250 ms kol Python OCR servisas įrašys rezultatą
            loop 10 {
                if FileExist(outPath) {
                    pyOutput := Trim(FileRead(outPath, "UTF-8"))
                    try FileDelete(outPath)
                    if (pyOutput != "")
                        return pyOutput
                    break
                }
                Sleep(25)
            }
        } catch {
            ; Fallback jei nepasileido Python
        }

        ; Greitas grąžinimas nenaudojant lėtų PowerShell RunWait procesų
        return ""
    }

    return ""
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

; ==============================================================================
; PURE AHK NATIVE 7-SEGMENT GEOMETRIC DECODER (<1ms Real-time RAM Processing)
; ==============================================================================
DecodeAHK7Segment(pixelMap, w, h) {
    if (pixelMap.Count < 5 || w < 10 || h < 10)
        return ""

    minX := w, minY := h, maxX := 0, maxY := 0
    colCounts := Map()

    for idx, _ in pixelMap {
        rowY := idx // w
        colX := Mod(idx, w)
        if (colX < minX)
            minX := colX
        if (colX > maxX)
            maxX := colX
        if (rowY < minY)
            minY := rowY
        if (rowY > maxY)
            maxY := rowY

        colCounts[colX] := (colCounts.Has(colX) ? colCounts[colX] + 1 : 1)
    }

    bw := maxX - minX + 1
    bh := maxY - minY + 1

    if (bw < 4 || bh < 8)
        return ""

    digitROIs := []
    ; Tikriname stulpelių tankį (Vertical Projection Gap) tiksliam 2 skaitmenų atskyrimui
    if (bw > bh * 0.65 && bw > 20) {
        midStart := minX + Integer(bw * 0.25)
        midEnd := minX + Integer(bw * 0.75)

        minColVal := 999999
        splitCol := minX + (bw // 2)

        currC := midStart
        while (currC <= midEnd) {
            cnt := (colCounts.Has(currC) ? colCounts[currC] : 0)
            if (cnt < minColVal) {
                minColVal := cnt
                splitCol := currC
            }
            currC++
        }

        digitROIs.Push({x: minX, y: minY, w: Max(1, splitCol - minX), h: bh})
        digitROIs.Push({x: splitCol + 1, y: minY, w: Max(1, maxX - splitCol), h: bh})
    } else {
        digitROIs.Push({x: minX, y: minY, w: bw, h: bh})
    }

    resultStr := ""
    for _, roi in digitROIs {
        charVal := DecodeSingleDigitROI(pixelMap, w, roi.x, roi.y, roi.w, roi.h)
        if (charVal != "")
            resultStr .= charVal
    }

    if (resultStr == "1D" || resultStr == "TD" || resultStr == "LD")
        return "ID"
    if (resultStr == "1N" || resultStr == "P1")
        return "PN"

    return resultStr
}

DecodeSingleDigitROI(pixelMap, totalW, rx, ry, rw, rh) {
    if (rw < 3 || rh < 6)
        return ""

    ; Išskirtinė taisyklė siauram '1' skaitmeniui: jei plotis/aukštis < 0.48 ir aktyvūs pikseliai dešinėje pusėje
    if ((rw / rh) < 0.48) {
        leftPts := 0
        rightPts := 0
        midX := rx + (rw // 2)
        yCurr := ry
        while (yCurr <= ry + rh) {
            xCurr := rx
            while (xCurr <= rx + rw) {
                pxIdx := (yCurr * totalW) + xCurr
                if pixelMap.Has(pxIdx) {
                    if (xCurr >= midX)
                        rightPts++
                    else
                        leftPts++
                }
                xCurr++
            }
            yCurr++
        }
        totalPts := leftPts + rightPts
        if (totalPts >= 3 && rightPts >= totalPts * 0.65)
            return "1"
    }

    segments := [
        [0.15, 0.85, 0.00, 0.25], ; 0: Top
        [0.00, 0.40, 0.05, 0.50], ; 1: Top-Left
        [0.60, 1.00, 0.05, 0.50], ; 2: Top-Right
        [0.15, 0.85, 0.35, 0.65], ; 3: Middle
        [0.00, 0.40, 0.50, 0.95], ; 4: Bottom-Left
        [0.60, 1.00, 0.50, 0.95], ; 5: Bottom-Right
        [0.15, 0.85, 0.75, 1.00]  ; 6: Bottom
    ]

    patternStr := ""
    for _, seg in segments {
        x1 := rx + Integer(rw * seg[1])
        x2 := rx + Integer(rw * seg[2])
        y1 := ry + Integer(rh * seg[3])
        y2 := ry + Integer(rh * seg[4])

        totalPts := Max(1, (x2 - x1 + 1) * (y2 - y1 + 1))
        activePts := 0

        yCurr := y1
        while (yCurr <= y2) {
            xCurr := x1
            while (xCurr <= x2) {
                pxIdx := (yCurr * totalW) + xCurr
                if pixelMap.Has(pxIdx)
                    activePts++
                xCurr++
            }
            yCurr++
        }

        ratio := activePts / totalPts
        patternStr .= (ratio > 0.25 ? "1" : "0")
    }

    static map7Seg := Map(
        "1110111", "0",
        "0010010", "1",
        "1011101", "2",
        "1011011", "3",
        "0111010", "4",
        "1101011", "5",
        "1101111", "6",
        "1010010", "7",
        "1111111", "8",
        "1111011", "9",
        "1111110", "A",
        "0101111", "B",
        "1100101", "C",
        "0011111", "D",
        "1101101", "E",
        "1101100", "F",
        "0111110", "H",
        "0100100", "L",
        "0111100", "P",
        "0110110", "U",
        "0101101", "n",
        "0101100", "r",
        "0001111", "t",
        "0010100", "i"
    )

    if map7Seg.Has(patternStr)
        return map7Seg[patternStr]

    bestChar := ""
    minDiff := 8
    for segPat, charVal in map7Seg {
        diff := 0
        Loop 7 {
            if (SubStr(patternStr, A_Index, 1) != SubStr(segPat, A_Index, 1))
                diff++
        }
        if (diff < minDiff && diff <= 1) {
            minDiff := diff
            bestChar := charVal
        }
    }

    return bestChar
}

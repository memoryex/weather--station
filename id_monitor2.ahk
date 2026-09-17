; ==============================================================================
; Appliance ID Slenkančio Ekrano (2 Skaitmenų Sekos) Stebėjimo ir Logavimo Programa
; Ver: 2.0 (AutoHotkey v2.0 - USB WebCam / 7-Segment Red Display Sequence Tracker)
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
global overlayX := 300, overlayY := 200, overlayW := 200, overlayH := 100
global isFlashing := false
global isScanningActive := false
global sbStatus := 0

; Sekos Surinkimo Buferis (6 poros po 2 skaitmenis/raides = 12 simbolių ID)
global sequenceBuffer := []
global lastSeenToken := ""
global lastTokenTime := 0
global bufferTimeoutMs := 5000 ; Jei per 5 sek gautas neilnas kodas, buferis nusinulina

; ==============================================================================
; GUI SĄSANAJOS KŪRIMAS
; ==============================================================================
MainGui := Gui("+AlwaysOnTop +MinSize380x530", "Slenkančio Ekrano ID Stebėjimas v2.0")
MainGui.SetFont("s10", "Segoe UI")
MainGui.BackColor := "0xF4F6F9"

; Viršutinė antraštė
MainGui.SetFont("s13 bold", "Segoe UI")
MainGui.Add("Text", "x15 y12 w350 c0x1A252C", "Slenkančio Ekrano (2-Digit) Stebėjimas")
MainGui.SetFont("s9 norm", "Segoe UI")

; Būsenos ir Skaitiklio Rėmelis
MainGui.Add("GroupBox", "x15 y42 w350 h85", "Būsena IR Skaitiklis")

MainGui.Add("Text", "x30 y65 w120 c0x555555", "Pagauta naujų ID:")
MainGui.SetFont("s18 bold", "Segoe UI")
txtCount := MainGui.Add("Text", "x150 y58 w190 c0x2E7D32", "0 vnt.")
MainGui.SetFont("s9 norm", "Segoe UI")

MainGui.Add("Text", "x30 y98 w120 c0x555555", "Sistemos būsena:")
txtStatus := MainGui.Add("Text", "x150 y98 w190 c0xC62828", "Sustabdyta")
txtStatus.SetFont("bold")

; Dabartinio Surinkimo Sekos Būsena (Live Sequence Buffer Progress)
MainGui.Add("GroupBox", "x15 y135 w350 h65", "Renkamas Kodas (2-Simbolių Poros)")
MainGui.SetFont("s11 bold", "Consolas")
txtSequenceProgress := MainGui.Add("Text", "x25 y158 w330 Center c0x1976D2", "[ __ __ __ __ __ __ ]")
MainGui.SetFont("s9 norm", "Segoe UI")

; Paskutinio Pamatyto Pilno ID Langas (Su Sumirksėjimo Efektu)
MainGui.Add("GroupBox", "x15 y208 w350 h85", "Paskutinis Pilnas 12-Ženklų ID")

; Progress baras su Range0-100 žaliu užpildymu mirksėjimui
idBoxBg := MainGui.Add("Progress", "x30 y228 w320 h50 BackgroundFFFFFF c0x27AE60 Range0-100", 0)
MainGui.SetFont("s16 bold", "Consolas")
txtLastID := MainGui.Add("Text", "x35 y238 w310 Center BackgroundTrans c0x2C3E50", "------------")
MainGui.SetFont("s9 norm", "Segoe UI")

; Valdymo Mygtukai
btnStart := MainGui.Add("Button", "x15 y302 w110 h32", "▶ Pradėti")
btnStart.SetFont("bold")
btnOverlay := MainGui.Add("Button", "x135 y302 w110 h32", "🔲 Rėmelis")
btnLogFile := MainGui.Add("Button", "x255 y302 w110 h32", "📁 Log Failas")

; Registruotų ID Sąrašas (ListView)
MainGui.SetFont("bold")
MainGui.Add("Text", "x15 y345 w200 c0x333333", "Pagautų ID Istorija:")
MainGui.SetFont("norm")
lvHistory := MainGui.Add("ListView", "x15 y365 w350 h125 Grid", ["Laikas", "Pilnas Appliance ID"])
lvHistory.ModifyCol(1, 140)
lvHistory.ModifyCol(2, 190)

; Apatinė juosta su informacija
sbStatus := MainGui.Add("StatusBar",, " Pasiruošęs. Užstumkite rėmelį ant 2 skaitmenų ekranėlio.")

; Event Handlers
btnStart.OnEvent("Click", ToggleMonitoring)
btnOverlay.OnEvent("Click", ToggleOverlay)
btnLogFile.OnEvent("Click", SelectLogFile)
MainGui.OnEvent("Close", (*) => ExitApp())
OnExit(SaveOverlayPosition)

; Inicijuojame / Patikriname Log Failą iš Nustatymų
InitLogFilePath()

; Įkeliame Rėmelio Poziciją iš config.ini
LoadOverlayPosition()

; Sukuriame Stebėjimo Rėmelio Overlay
CreateOverlayWindow()

; Įkeliame esamo logo duomenis
LoadExistingLog()

; Parodome pagrindinį langą
MainGui.Show("x100 y100 w380 h530")

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
        MsgBox("Prieš pradedant darbą, prašome pasirinkti arba sukurti log failą.", "Log Failo Nustatymas", "OK Iconi")
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

LoadOverlayPosition() {
    global configFile, overlayX, overlayY, overlayW, overlayH
    try {
        overlayX := Integer(IniRead(configFile, "Overlay2", "X", "300"))
        overlayY := Integer(IniRead(configFile, "Overlay2", "Y", "200"))
        overlayW := Integer(IniRead(configFile, "Overlay2", "W", "200"))
        overlayH := Integer(IniRead(configFile, "Overlay2", "H", "100"))
    } catch {
        overlayX := 300, overlayY := 200, overlayW := 200, overlayH := 100
    }
}

SaveOverlayPosition(*) {
    global configFile, OverlayGui
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
}

; ==============================================================================
; STEBĖJIMO RĖMELIO (OVERLAY) KŪRIMAS
; ==============================================================================
CreateOverlayWindow() {
    global OverlayGui, overlayX, overlayY, overlayW, overlayH

    OverlayGui := Gui("+AlwaysOnTop +ToolWindow +Resize -Caption +E0x00080000", "Stebėjimo Rėmelis 2")
    OverlayGui.BackColor := "0xFF0000"
    WinSetTransColor("0xFE00FE 255", OverlayGui)

    OverlayGui.MarginX := 0
    OverlayGui.MarginY := 0

    OverlayGui.Add("Text", "x4 y4 w" . (overlayW-8) . " h" . (overlayH-8) . " Background0xFE00FE vInnerBox")

    OverlayGui.OnEvent("Size", OnOverlayResize)
    OnMessage(0x0204, WM_RBUTTONDOWN)
    OnMessage(0x0232, WM_EXITSIZEMOVE)

    OverlayGui.Show("x" . overlayX . " y" . overlayY . " w" . overlayW . " h" . overlayH . " NoActivate")
}

WM_RBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global OverlayGui
    if (WinExist(OverlayGui.Hwnd) && hwnd == OverlayGui.Hwnd) {
        PostMessage(0xA1, 2,,, OverlayGui.Hwnd)
    }
}

WM_EXITSIZEMOVE(wParam, lParam, msg, hwnd) {
    global OverlayGui
    if (WinExist(OverlayGui.Hwnd) && hwnd == OverlayGui.Hwnd) {
        SaveOverlayPosition()
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
        SaveOverlayPosition()
    }
}

ToggleOverlay(*) {
    global OverlayGui, sbStatus
    if (WinExist(OverlayGui.Hwnd)) {
        if (DllCall("IsWindowVisible", "Ptr", OverlayGui.Hwnd)) {
            OverlayGui.Hide()
            sbStatus.Text := " Stebėjimo rėmelis paslėptas."
        } else {
            OverlayGui.Show("NoActivate")
            sbStatus.Text := " Stebėjimo rėmelis rodomas (Dešinys mygtukas - stumdyti, Kairys mygtukas - didinti)."
        }
    }
}

; ==============================================================================
; MONITORINGO LOGIKA IR SCANNING TIMER (250 ms Greičio Ciklas)
; ==============================================================================
ToggleMonitoring(*) {
    global isMonitoring, btnStart, txtStatus, sbStatus

    isMonitoring := !isMonitoring

    if (isMonitoring) {
        btnStart.Text := "⏸ Pauzė"
        txtStatus.Text := "Stebima..."
        txtStatus.SetFont("c0x2E7D32")
        sbStatus.Text := " Aktyvus 2-skaitmenų ekranėlio stebėjimas (kas 250 ms)."
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
    global OverlayGui, isMonitoring, isScanningActive, sequenceBuffer, lastSeenToken, lastTokenTime, bufferTimeoutMs

    if (!isMonitoring || !WinExist(OverlayGui.Hwnd) || isScanningActive)
        return

    isScanningActive := true

    ; Tikriname buferio galiojimo laiką (jei ilgai nieko nepamatė, nusinulina buferis)
    now := A_TickCount
    if (sequenceBuffer.Length > 0 && (now - lastTokenTime > bufferTimeoutMs)) {
        sequenceBuffer := []
        lastSeenToken := ""
        UpdateSequenceProgressUI()
    }

    OverlayGui.GetPos(&x, &y, &w, &h)
    rx := x + 4
    ry := y + 4
    rw := w - 8
    rh := h - 8

    if (rw <= 0 || rh <= 0) {
        isScanningActive := false
        return
    }

    detectedText := CaptureAndOCRRedSegment(rx, ry, rw, rh)

    if (detectedText != "") {
        ; Ieškome 2-jų simbolių kodo (skaitmenys arba raidės, pvz., '12', '01', 'Pn', 'bt')
        if RegExMatch(detectedText, "i)\b[A-Z0-9]{2}\b", &match) {
            token := StrUpper(match[0])

            ; Ignoruojame tą patį simbolį, kol jis dar slenka/laikosi ekrane (~1 sek)
            if (token != lastSeenToken) {
                lastSeenToken := token
                lastTokenTime := now

                ; Jei matome pradinį headerį (pvz., 'BT' arba 'PN') ir buferis jau turi kažką, nusinuliname naujam kodui
                if ((token == "BT" || token == "PN") && sequenceBuffer.Length > 0) {
                    sequenceBuffer := []
                } else {
                    sequenceBuffer.Push(token)
                }

                UpdateSequenceProgressUI()

                ; Kai surenkame 6 poras (po 2 simbolius = 12 simbolių ID)
                if (sequenceBuffer.Length == 6) {
                    assembledID := ""
                    for pair in sequenceBuffer {
                        assembledID .= pair
                    }

                    ; Tikriname ar tai unikalus naujas ID
                    if (!capturedHistory.Has(assembledID) && assembledID != lastCapturedID) {
                        ProcessNewID(assembledID)
                    }

                    ; Resetiname buferį kitam įrenginiui
                    sequenceBuffer := []
                    UpdateSequenceProgressUI()
                }
            }
        }
    }

    isScanningActive := false
}

UpdateSequenceProgressUI() {
    global sequenceBuffer, txtSequenceProgress
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
; RED LED 7-SEGMENT IMAGE PROCESSING & OCR
; ==============================================================================
CaptureAndOCRRedSegment(rx, ry, rw, rh) {
    try {
        hBM := CaptureScreenRectWithRedContrast(rx, ry, rw, rh)
        if (!hBM)
            return ""

        ocrText := RunNativeWinRTOCR(hBM, rw, rh)
        DllCall("DeleteObject", "Ptr", hBM)
        return ocrText
    } catch {
        return ""
    }
}

CaptureScreenRectWithRedContrast(x, y, w, h) {
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")

    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020)

    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld, "Ptr")
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

    return hbm
}

RunNativeWinRTOCR(hBitmap, w, h) {
    try {
        tempImgPath := A_Temp . "\id_ocr_snap2.bmp"
        if (SaveHBitmapToFile(hBitmap, tempImgPath)) {
            extractedText := ReadOCRTextFromImage(tempImgPath)
            if FileExist(tempImgPath)
                try FileDelete(tempImgPath)
            return extractedText
        }
        return ""
    } catch {
        return ""
    }
}

SaveHBitmapToFile(hbm, filePath) {
    pGpBitmap := 0
    static pToken := 0
    if (!pToken) {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)
    }

    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &pGpBitmap)
    if (pGpBitmap) {
        clsid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "WStr", "{557CF400-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
        DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pGpBitmap, "WStr", filePath, "Ptr", clsid, "Ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pGpBitmap)
    }
    return FileExist(filePath)
}

ReadOCRTextFromImage(imagePath) {
    if (!FileExist(imagePath))
        return ""

    try {
        outPath := A_Temp . "\id_ocr_res2.txt"
        if FileExist(outPath)
            try FileDelete(outPath)

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

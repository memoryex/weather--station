; ==============================================================================
; Appliance ID Stebėjimo ir Logavimo Programa
; Ver: 2.4 (AutoHotkey v2.0 - Fully Stable OCR & Clean Mouse Interaction)
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
global overlayX := 300, overlayY := 200, overlayW := 260, overlayH := 60
global isFlashing := false
global isScanningActive := false
global sbStatus := 0

; ==============================================================================
; GUI SĄSANAJOS KŪRIMAS
; ==============================================================================
MainGui := Gui("+AlwaysOnTop +MinSize380x480", "Appliance ID Stebėjimas v2.4")
MainGui.SetFont("s10", "Segoe UI")
MainGui.BackColor := "0xF4F6F9"

; Viršutinė antraštė
MainGui.SetFont("s13 bold", "Segoe UI")
MainGui.Add("Text", "x15 y12 w350 c0x1A252C", "Appliance ID Stebėjimo Skydelis")
MainGui.SetFont("s9 norm", "Segoe UI")

; Būsenos ir Skaitiklio Rėmelis (Group)
MainGui.Add("GroupBox", "x15 y42 w350 h85", "Būsena IR Skaitiklis")

MainGui.Add("Text", "x30 y65 w120 c0x555555", "Pagauta naujų ID:")
MainGui.SetFont("s18 bold", "Segoe UI")
txtCount := MainGui.Add("Text", "x150 y58 w190 c0x2E7D32", "0 vnt.")
MainGui.SetFont("s9 norm", "Segoe UI")

MainGui.Add("Text", "x30 y98 w120 c0x555555", "Sistemos būsena:")
txtStatus := MainGui.Add("Text", "x150 y98 w190 c0xC62828", "Sustabdyta")
txtStatus.SetFont("bold")

; Paskutinio Pamatyto ID Langas (Su Sumirksėjimo Efektu)
MainGui.Add("GroupBox", "x15 y135 w350 h90", "Paskutinis Gautas ID")

; Progress baras su Range0-100 žaliu užpildymu mirksėjimui
idBoxBg := MainGui.Add("Progress", "x30 y158 w320 h52 BackgroundFFFFFF c0x27AE60 Range0-100", 0)
MainGui.SetFont("s16 bold", "Consolas")
txtLastID := MainGui.Add("Text", "x35 y170 w310 Center BackgroundTrans c0x2C3E50", "------------")
MainGui.SetFont("s9 norm", "Segoe UI")

; Valdymo Mygtukai
btnStart := MainGui.Add("Button", "x15 y235 w110 h32", "▶ Pradėti")
btnStart.SetFont("bold")
btnOverlay := MainGui.Add("Button", "x135 y235 w110 h32", "🔲 Rėmelis")
btnLogFile := MainGui.Add("Button", "x255 y235 w110 h32", "📁 Log Failas")

; Registruotų ID Sąrašas (ListView)
MainGui.SetFont("bold")
MainGui.Add("Text", "x15 y280 w200 c0x333333", "Pagautų ID Istorija:")
MainGui.SetFont("norm")
lvHistory := MainGui.Add("ListView", "x15 y300 w350 h135 Grid", ["Laikas", "Appliance ID"])
lvHistory.ModifyCol(1, 140)
lvHistory.ModifyCol(2, 190)

; Apatinė juosta su informacija
sbStatus := MainGui.Add("StatusBar",, " Pasiruošęs. Užstumkite raudoną rėmelį ant ID lauko.")

; Event Handlers
btnStart.OnEvent("Click", ToggleMonitoring)
btnOverlay.OnEvent("Click", ToggleOverlay)
btnLogFile.OnEvent("Click", SelectLogFile)
MainGui.OnEvent("Close", (*) => ExitApp())

; Inicijuojame / Patikriname Log Failą iš Nustatymų
InitLogFilePath()

; Sukuriame Stebėjimo Rėmelio Overlay
CreateOverlayWindow()

; Įkeliame esamo logo duomenis
LoadExistingLog()

; Parodome pagrindinį langą
MainGui.Show("x100 y100 w380 h480")

; ==============================================================================
; LOG FAILO NUSTATYMAI IR INI PERSISTENCE
; ==============================================================================
InitLogFilePath() {
    global configFile, logFilePath, sbStatus

    try {
        logFilePath := IniRead(configFile, "Settings", "LogFilePath", "")
    } catch {
        logFilePath := ""
    }

    if (logFilePath == "" || !HasValidLogExtension(logFilePath)) {
        MsgBox("Prieš pradedant darbą, prašome pasirinkti arba sukurti log failą.", "Log Failo Nustatymas", "OK Iconi")
        selectedPath := FileSelect("S16", A_ScriptDir . "\id_log.txt", "Pasirinkite arba sukurkite LOG failą", "Tekstiniai failai (*.txt; *.log)")
        if (selectedPath != "") {
            logFilePath := selectedPath
            try {
                IniWrite(logFilePath, configFile, "Settings", "LogFilePath")
            }
        } else {
            ; Jei vartotojas atšaukia pirmo paleidimo metu, baigiame darbą tvarkingai
            ExitApp()
        }
    }

    sbStatus.Text := " Aktyvus Log failas: " . logFilePath
}

HasValidLogExtension(path) {
    return (RegExMatch(path, "i)\.(txt|log)$") > 0)
}

; ==============================================================================
; STEBĖJIMO RĖMELIO (OVERLAY) KŪRIMAS
; ==============================================================================
CreateOverlayWindow() {
    global OverlayGui, overlayX, overlayY, overlayW, overlayH

    ; Overlay langas: Visada viršuje (+AlwaysOnTop), be antraštės (-Caption), keičiamo dydžio (+Resize)
    OverlayGui := Gui("+AlwaysOnTop +ToolWindow +Resize -Caption +E0x00080000", "Stebėjimo Rėmelis")
    OverlayGui.BackColor := "0xFF0000" ; Raudona spalva rėmeliui
    WinSetTransColor("0xFE00FE 255", OverlayGui) ; Vidinė dalis 100% permatoma

    OverlayGui.MarginX := 0
    OverlayGui.MarginY := 0

    ; InnerBox Gui elementas
    OverlayGui.Add("Text", "x4 y4 w" . (overlayW-8) . " h" . (overlayH-8) . " Background0xFE00FE vInnerBox")

    ; Resizing su kairiuoju pelės mygtuku ant kraštinių (+Resize)
    OverlayGui.OnEvent("Size", OnOverlayResize)

    ; Pastūmimas su DEŠINIUJU pelės mygtuku ant rėmelio krašto (WM_RBUTTONDOWN = 0x0204)
    OnMessage(0x0204, WM_RBUTTONDOWN)

    OverlayGui.Show("x" . overlayX . " y" . overlayY . " w" . overlayW . " h" . overlayH . " NoActivate")
}

WM_RBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global OverlayGui
    if (WinExist(OverlayGui.Hwnd) && hwnd == OverlayGui.Hwnd) {
        PostMessage(0xA1, 2,,, OverlayGui.Hwnd) ; WM_NCLBUTTONDOWN vilkimas
    }
}

OnOverlayResize(thisGui, minMax, width, height) {
    global overlayW, overlayH
    if (minMax != -1 && width > 10 && height > 10) {
        overlayW := width
        overlayH := height
        try {
            thisGui["InnerBox"].Move(4, 4, width - 8, height - 8)
        }
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
; MONITORINGO LOGIKA IR SCANNING TIMER
; ==============================================================================
ToggleMonitoring(*) {
    global isMonitoring, btnStart, txtStatus, sbStatus

    isMonitoring := !isMonitoring

    if (isMonitoring) {
        btnStart.Text := "⏸ Pauzė"
        txtStatus.Text := "Stebima..."
        txtStatus.SetFont("c0x2E7D32") ; Žalia
        sbStatus.Text := " Stebėjimas aktyvus - tikrinama kas 1 sek."
        SetTimer(ScanTargetRegion, 1000)
    } else {
        btnStart.Text := "▶ Pradėti"
        txtStatus.Text := "Sustabdyta"
        txtStatus.SetFont("c0xC62828") ; Raudona
        sbStatus.Text := " Stebėjimas pristabdytas."
        SetTimer(ScanTargetRegion, 0)
    }
}

ScanTargetRegion() {
    global OverlayGui, lastCapturedID, isMonitoring, capturedHistory, isScanningActive

    if (!isMonitoring || !WinExist(OverlayGui.Hwnd) || isScanningActive)
        return

    isScanningActive := true

    ; Gauname rėmelio vidines koordinates ekrane
    OverlayGui.GetPos(&x, &y, &w, &h)

    rx := x + 4
    ry := y + 4
    rw := w - 8
    rh := h - 8

    if (rw <= 0 || rh <= 0) {
        isScanningActive := false
        return
    }

    detectedText := CaptureTextFromRegion(rx, ry, rw, rh)

    if (detectedText != "") {
        ; RegEx ieško 12 ženklų alfanumerinio kodo (pvz. 010923E9001F)
        if RegExMatch(detectedText, "i)\b[A-Z0-9]{12}\b", &match) {
            foundID := StrUpper(match[0])

            ; Tikriname ar tai Naujas Unikalus ID
            if (!capturedHistory.Has(foundID) && foundID != lastCapturedID) {
                ProcessNewID(foundID)
            }
        }
    }

    isScanningActive := false
}

; ==============================================================================
; TEXT EXTRACTION / OCR & SCREEN CAPTURE
; ==============================================================================
CaptureTextFromRegion(rx, ry, rw, rh) {
    ; 1. Pirmas metodas: Nuskaitome po rėmeliu esančių langų valdymo elementus (0 CPU)
    textFromWin := GetTextFromWindowAtRegion(rx, ry, rw, rh)
    if (textFromWin != "")
        return textFromWin

    ; 2. Antras metodas: Visapusiškas Ekrano Vaizdo OCR
    return PerformNativeOCR(rx, ry, rw, rh)
}

GetTextFromWindowAtRegion(rx, ry, rw, rh) {
    global OverlayGui
    centerX := rx + (rw // 2)
    centerY := ry + (rh // 2)

    WinSetExStyle("+0x20", OverlayGui.Hwnd) ; WS_EX_TRANSPARENT permatomumui WindowFromPoint metu
    hwndUnder := DllCall("WindowFromPoint", "Int64", centerX | (centerY << 32), "Ptr")
    WinSetExStyle("-0x20", OverlayGui.Hwnd)

    if (!hwndUnder || hwndUnder == OverlayGui.Hwnd)
        return ""

    try {
        ctrlText := ControlGetText(hwndUnder)
        if RegExMatch(ctrlText, "i)\b[A-Z0-9]{12}\b", &m)
            return m[0]

        winText := WinGetText(hwndUnder)
        if RegExMatch(winText, "i)\b[A-Z0-9]{12}\b", &m)
            return m[0]
    }
    return ""
}

PerformNativeOCR(rx, ry, rw, rh) {
    try {
        hBM := CaptureScreenRectToBitmap(rx, ry, rw, rh)
        if (!hBM)
            return ""

        ocrText := RunNativeWinRTOCR(hBM, rw, rh)
        DllCall("DeleteObject", "Ptr", hBM)
        return ocrText
    } catch {
        return ""
    }
}

CaptureScreenRectToBitmap(x, y, w, h) {
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", w, "Int", h, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")

    ; BitBlt ekrano nukopijavimui tiesiogiai iš ekrano atminties
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020)

    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld, "Ptr")
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

    return hbm
}

RunNativeWinRTOCR(hBitmap, w, h) {
    try {
        tempImgPath := A_Temp . "\id_ocr_snap.bmp"
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
        outPath := A_Temp . "\id_ocr_res.txt"
        if FileExist(outPath)
            try FileDelete(outPath)

        psScript := "$null = [Reflection.Assembly]::LoadWithPartialName('System.Drawing'); "
            . "$bmp = [System.Drawing.Bitmap]::FromFile('" . imagePath . "'); "
            . "$ocr = [Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]::TryCreateFromUserProfileLanguages(); "
            . "if ($ocr -and $bmp) { "
            . "  $ms = New-Object System.IO.MemoryStream; "
            . "  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); "
            . "  $b = $ms.ToArray(); "
            . "  $ras = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream; "
            . "  $writer = New-Object Windows.Storage.Streams.DataWriter($ras.GetOutputStreamAt(0)); "
            . "  $writer.WriteBytes($b); "
            . "  $null = $writer.StoreAsync().GetResults(); "
            . "  $sBmp = [Windows.Graphics.Imaging.SoftwareBitmap]::CreateCopyFromBuffer($writer.DetachBuffer(), [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8, $bmp.Width, $bmp.Height); "
            . "  $res = $ocr.RecognizeAsync($sBmp).GetResults(); "
            . "  if ($res -and $res.Text) { $res.Text | Out-File -FilePath '" . outPath . "' -Encoding utf8 } "
            . "}"

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

    ; Atnaujiname skaitiklį UI
    txtCount.Text := capturedCount . " vnt."
    txtLastID.Text := newID

    ; Įrašome į ListView viršuje
    lvHistory.Insert(1,, timestamp, newID)

    ; Įrašome į Log failą (Kaupti žemin eilutėmis)
    AppendToLogFile(timestamp, newID)

    ; Paleidžiame žalio sumirksėjimo efektą langelyje!
    TriggerGreenFlash()

    sbStatus.Text := " [" . timestamp . "] Pagautas naujas ID: " . newID
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
    txtLastID.SetFont("cFFFFFF") ; Baltas tekstas mirksint
    idBoxBg.Value := 100 ; Užpildo progress barą žalia spalva 100%!
    WinRedraw(txtLastID.Hwnd) ; Perpiešia tekstą aiškiai ant viršaus per Control HWND

    SetTimer(ResetFlashColor, -600)
}

ResetFlashColor() {
    global idBoxBg, txtLastID, isFlashing
    txtLastID.SetFont("c0x2C3E50") ; Tamsus tekstas
    idBoxBg.Value := 0 ; Nulinis progress baras - permatomas/baltas fonas
    WinRedraw(txtLastID.Hwnd) ; Perpiešia tekstą aiškiai ant viršaus per Control HWND
    isFlashing := false
}

; ==============================================================================
; PASIŪLYMAI IR NUSTATYMAI
; ==============================================================================
SelectLogFile(*) {
    global configFile, logFilePath, sbStatus
    selected := FileSelect("S16", logFilePath != "" ? logFilePath : A_ScriptDir . "\id_log.txt", "Pasirinkite arba sukurkite log failą", "Tekstiniai failai (*.txt; *.log)")
    if (selected != "") {
        logFilePath := selected
        try {
            IniWrite(logFilePath, configFile, "Settings", "LogFilePath")
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

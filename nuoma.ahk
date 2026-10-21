#Requires AutoHotkey v2.0
; ==============================================================================
; Programos Pavadinimas: Priekabų ir Pastolių Nuomos Valdymas
; Aprašymas: AHK v2 sistema pastolių komplektų ir priekabų nuomai, likučių
;            sekimui, tarifų skaičiavimui minutės tikslumu ir grąžinimams.
; ==============================================================================

#SingleInstance Force

A_IconTip := "Priekabų ir Pastolių Nuoma"

; --- GLOBALŪS KINTAMIEJI IR STRUKTŪROS ---
global ConfigFile := A_ScriptDir . "\config.ini"
global OrdersFile := A_ScriptDir . "\orders.ini"
global ImagesDir  := A_ScriptDir . "\images"

; Parts[Code] -> {Code: "A1", Name: "Skersinis", TotalQty: 10, ImagePath: "...", PricePerHour: 0.50}
global Parts := Map()

; Orders[OrderID] -> {OrderID: "0", Tenant: "Jonas", StartTS: "20231021...", Status: "Aktyvus", EndTS: "", TotalCost: 0.0, Items: Map(Code -> RentedQty)}
global Orders := Map()

; Globalūs UI valdymo objektai
global MainGui := ""
global TabCtrl := ""

; Tab 1 Controls
global grpNewRental1 := "", grpNewRental2 := ""
global edtTenantName := ""
global lvNewRentalParts := ""
global edtRentalQty := ""
global picPartPreview1 := ""
global txtPartInfo1 := ""
global lblSelectedPart1 := ""
global btnStartRental := ""
global selectedPartCode1 := ""
global lblRentalQtyTitle := "", btnSetQty := ""

; Tab 2 Controls
global grpActive1 := ""
global lvActiveOrders := ""
global txtActiveTenantHeader := "", txtActiveTenant := ""
global txtActiveStartHeader := "", txtActiveStart := ""
global txtActiveDurationHeader := "", txtActiveDuration := ""
global txtActiveCostHeader := "", txtActiveCost := ""
global txtActiveItemsHeader := ""
global lvActiveItems := ""
global picPartPreview2 := ""
global btnReturnAll := ""
global btnCompleteReturn := ""
global selectedActiveOrderID := ""

; Tab 3 Controls (Settings)
global grpSettings1 := ""
global lvSettingsParts := ""
global lblSetCode := "", edtSetCode := ""
global lblSetName := "", edtSetName := ""
global lblSetQty := "", edtSetTotalQty := ""
global lblSetPrice := "", edtSetPricePerHour := ""
global lblSetImg := "", edtSetImagePath := "", btnBrowseImg := ""
global picPartPreview3 := ""
global btnAddPart := "", btnDeletePart := ""

; Tab 4 Controls (History)
global grpHistory1 := ""
global lvHistoryOrders := ""
global lvHistoryItems := ""
global txtHistoryTotalCost := ""
global btnExportHistory := ""

; Pasiruošimas direktorijoms ir duomenims
InitDirectories()
LoadPartsFromConfig()
LoadOrdersFromINI()

; Sukuriamas pagrindinis GUI
CreateMainGUI()

; Laikmatis aktyvių užsakymų trukmės bei kainos atnaujinimui
SetTimer(UpdateActiveDurations, 1000)

return


; ==============================================================================
; DUOMENŲ UŽKROVIMAS IR SAUGOJIMAS
; ==============================================================================

InitDirectories() {
    if !DirExist(ImagesDir)
        DirCreate(ImagesDir)
}

LoadPartsFromConfig() {
    global Parts, ConfigFile
    Parts.Clear()

    if !FileExist(ConfigFile) {
        CreateDefaultConfig()
    }

    try {
        partsData := IniRead(ConfigFile, "Parts")
    } catch {
        partsData := ""
    }

    if (partsData != "") {
        loop parse, partsData, "`n", "`r"
        {
            if (A_LoopField = "")
                continue
            eqPos := InStr(A_LoopField, "=")
            if (!eqPos)
                continue

            code := SubStr(A_LoopField, 1, eqPos - 1)
            val := SubStr(A_LoopField, eqPos + 1)

            partsArray := StrSplit(val, "|")
            if (partsArray.Length >= 3) {
                pCode := Trim(partsArray[1])
                pName := Trim(partsArray[2])
                pQty  := Integer(Trim(partsArray[3]))
                pImg  := (partsArray.Length >= 4) ? Trim(partsArray[4]) : ""
                pPrice := (partsArray.Length >= 5) ? Float(Trim(partsArray[5])) : 0.50

                Parts[pCode] := {Code: pCode, Name: pName, TotalQty: pQty, ImagePath: pImg, PricePerHour: pPrice}
            }
        }
    }
}

CreateDefaultConfig() {
    global ConfigFile
    defaultData := "
    (
    [Parts]
    A1=A1|Rėmas vertikalus 2.0m|12||0.40
    A2=A2|Skersinis diagonalinis 2.5m|10||0.30
    A3=A3|Skersinis horizontalus 2.5m|20||0.25
    B1=B1|Paklotas medinis 2.5m|15||0.50
    B2=B2|Paklotas aliumininis su liuku|4||0.80
    C1=C1|Reguliuojama koja (Sriegis)|16||0.20
    P1=P1|Lengvoji Priekaba 750kg|2||2.50
    P2=P2|Dvitėšė Priekaba Pastoliams|1||4.00
    )"
    FileAppend(Trim(defaultData), ConfigFile, "UTF-8")
}

SavePartsToConfig() {
    global Parts, ConfigFile
    if FileExist(ConfigFile)
        FileDelete(ConfigFile)

    IniWrite("", ConfigFile, "Parts")
    for code, pObj in Parts {
        valStr := pObj.Code . "|" . pObj.Name . "|" . pObj.TotalQty . "|" . pObj.ImagePath . "|" . pObj.PricePerHour
        IniWrite(valStr, ConfigFile, "Parts", code)
    }
}

LoadOrdersFromINI() {
    global Orders, OrdersFile
    Orders.Clear()

    if !FileExist(OrdersFile)
        return

    sections := IniRead(OrdersFile)
    if (sections = "")
        return

    for secName in StrSplit(sections, "`n") {
        secName := Trim(secName, "`r")
        if (secName = "")
            continue

        if (SubStr(secName, 1, 6) = "Order_") {
            orderID := SubStr(secName, 7)
            tenant := IniRead(OrdersFile, secName, "Tenant", "")
            startTS := IniRead(OrdersFile, secName, "StartTS", "")
            status := IniRead(OrdersFile, secName, "Status", "Aktyvus")
            endTS := IniRead(OrdersFile, secName, "EndTS", "")
            totCost := Float(IniRead(OrdersFile, secName, "TotalCost", "0.0"))

            itemsMap := Map()
            secContent := IniRead(OrdersFile, secName)
            loop parse, secContent, "`n", "`r"
            {
                line := Trim(A_LoopField)
                if (SubStr(line, 1, 5) = "Item_") {
                    eqPos := InStr(line, "=")
                    if (eqPos) {
                        itemCode := SubStr(line, 6, eqPos - 6)
                        itemQty := Integer(SubStr(line, eqPos + 1))
                        itemsMap[itemCode] := itemQty
                    }
                }
            }

            Orders[orderID] := {OrderID: orderID, Tenant: tenant, StartTS: startTS, Status: status, EndTS: endTS, TotalCost: totCost, Items: itemsMap}
        }
    }
}

SaveOrderToINI(orderObj) {
    global OrdersFile
    secName := "Order_" . orderObj.OrderID
    IniWrite(orderObj.Tenant, OrdersFile, secName, "Tenant")
    IniWrite(orderObj.StartTS, OrdersFile, secName, "StartTS")
    IniWrite(orderObj.Status, OrdersFile, secName, "Status")
    IniWrite(orderObj.EndTS, OrdersFile, secName, "EndTS")
    IniWrite(Format("{:.2f}", orderObj.TotalCost), OrdersFile, secName, "TotalCost")

    for code, qty in orderObj.Items {
        IniWrite(qty, OrdersFile, secName, "Item_" . code)
    }
}

GetAvailableQty(code) {
    global Parts, Orders
    if !Parts.Has(code)
        return 0

    tot := Parts[code].TotalQty
    rented := 0

    for ordID, ord in Orders {
        if (ord.Status = "Aktyvus") {
            if ord.Items.Has(code) {
                rented += ord.Items[code]
            }
        }
    }

    avail := tot - rented
    return (avail < 0) ? 0 : avail
}


; ==============================================================================
; GUI SĄSAJOS KŪRIMAS IR AUTORESIZE LOGIKA
; ==============================================================================

CreateMainGUI() {
    global MainGui, TabCtrl
    global edtTenantName, lvNewRentalParts, edtRentalQty, picPartPreview1, txtPartInfo1, lblSelectedPart1, btnStartRental, grpNewRental2, lblRentalQtyTitle, btnSetQty
    global lvActiveOrders, txtActiveTenantHeader, txtActiveTenant, txtActiveStartHeader, txtActiveStart, txtActiveDurationHeader, txtActiveDuration, txtActiveCostHeader, txtActiveCost, txtActiveItemsHeader, lvActiveItems, picPartPreview2, btnReturnAll, btnCompleteReturn, grpActive1
    global lvSettingsParts, grpSettings1, lblSetCode, edtSetCode, lblSetName, edtSetName, lblSetQty, edtSetTotalQty, lblSetPrice, edtSetPricePerHour, lblSetImg, edtSetImagePath, btnBrowseImg, picPartPreview3, btnAddPart, btnDeletePart
    global lvHistoryOrders, lvHistoryItems, txtHistoryTotalCost, grpHistory1

    MainGui := Gui("+Resize +MinSize920x660", "Priekabų ir Pastolių Nuomos Valdymas v1.3")
    MainGui.SetFont("s10", "Segoe UI")

    TabCtrl := MainGui.Add("Tab3", "x10 y10 w950 h640", ["Nauja Nuoma", "Aktyvios Nuomos ir Grąžinimas", "Detalių Nustatymai", "Užsakymų Istorija"])

    ; --------------------------------------------------------------------------
    ; TAB 1: NAUJA NUOMA
    ; --------------------------------------------------------------------------
    TabCtrl.UseTab(1)

    MainGui.SetFont("s11 bold")
    MainGui.Add("Text", "x30 y50", "1. Nuomininko informacija:")
    MainGui.SetFont("s10 norm")

    MainGui.Add("Text", "x30 y80", "Kliento / Įmonės pavadinimas:")
    edtTenantName := MainGui.Add("Edit", "x230 y77 w350 h26")

    MainGui.SetFont("s11 bold")
    MainGui.Add("Text", "x30 y120", "2. Detalių ir priekabų išsirinkimas nuomai:")
    MainGui.SetFont("s10 norm")

    ; Detalių ListView lentelė (Pervadinta "Lipdukas" -> "Numeris", "Imama Qty" -> "Įmama vnt.")
    lvNewRentalParts := MainGui.Add("ListView", "x30 y150 w570 h380 +Grid -Multi", ["Numeris", "Pavadinimas", "Tarifas (€/val)", "Laisva Nuomai", "Įmama vnt."])
    lvNewRentalParts.ModifyCol(1, 80)
    lvNewRentalParts.ModifyCol(2, 220)
    lvNewRentalParts.ModifyCol(3, 100)
    lvNewRentalParts.ModifyCol(4, 90)
    lvNewRentalParts.ModifyCol(5, 80)
    lvNewRentalParts.OnEvent("ItemSelect", OnNewRentalPartSelect)

    ; Dešinė pusė: Detalės kiekio įvedimas ir nuotraukos peržiūra
    grpNewRental2 := MainGui.Add("GroupBox", "x620 y140 w310 h390", "Detalės Peržiūra & Kiekis")

    lblSelectedPart1 := MainGui.Add("Text", "x635 y165 w280 h40", "Pasirinkite detalę iš sąrašo kairėje")
    lblSelectedPart1.SetFont("s10 bold")

    lblRentalQtyTitle := MainGui.Add("Text", "x635 y215", "Pasirenkamas kiekis:")
    edtRentalQty := MainGui.Add("Edit", "x755 y212 w70 h26 Number", "0")
    btnSetQty := MainGui.Add("Button", "x833 y211 w80 h28", "Nustatyti")
    btnSetQty.OnEvent("Click", OnSetRentalQtyClick)

    picPartPreview1 := MainGui.Add("Picture", "x635 y255 w280 h210 +Border")
    txtPartInfo1 := MainGui.Add("Text", "x635 y475 w280 h50", "")

    ; Apatinis mygtukas
    btnStartRental := MainGui.Add("Button", "x30 y545 w570 h50", "PRADĖTI NUOMĄ IR SKAIČIUOTI LAIKĄ & SUMĄ")
    btnStartRental.SetFont("s11 bold")
    btnStartRental.OnEvent("Click", OnStartRentalClick)


    ; --------------------------------------------------------------------------
    ; TAB 2: AKTYVIOS NUOMOS IR GRĄŽINIMAS
    ; --------------------------------------------------------------------------
    TabCtrl.UseTab(2)

    MainGui.SetFont("s11 bold")
    MainGui.Add("Text", "x30 y50", "Aktyvūs Nuomos Užsakymai:")
    MainGui.SetFont("s10 norm")

    lvActiveOrders := MainGui.Add("ListView", "x30 y80 w430 h480 +Grid -Multi", ["ID", "Nuomininkas", "Pradžia", "Trukmė", "Suma (€)"])
    lvActiveOrders.ModifyCol(1, 45)
    lvActiveOrders.ModifyCol(2, 140)
    lvActiveOrders.ModifyCol(3, 110)
    lvActiveOrders.ModifyCol(4, 75)
    lvActiveOrders.ModifyCol(5, 55)
    lvActiveOrders.OnEvent("ItemSelect", OnActiveOrderSelect)

    ; Dešinė pusė: Užsakymo detalės ir grąžinimo valdymas
    grpActive1 := MainGui.Add("GroupBox", "x480 y70 w450 h490", "Užsakymo Skaičiavimas ir Grąžinimas")

    txtActiveTenantHeader := MainGui.Add("Text", "x495 y95", "Nuomininkas:")
    txtActiveTenant := MainGui.Add("Text", "x600 y95 w310 h22", "-")
    txtActiveTenant.SetFont("s10 bold")

    txtActiveStartHeader := MainGui.Add("Text", "x495 y120", "Pradžios laikas:")
    txtActiveStart := MainGui.Add("Text", "x600 y120 w310 h22", "-")

    txtActiveDurationHeader := MainGui.Add("Text", "x495 y145", "Prabėgęs laikas:")
    txtActiveDuration := MainGui.Add("Text", "x600 y145 w310 h22", "0 d. 00:00:00")
    txtActiveDuration.SetFont("s10 bold cRed")

    txtActiveCostHeader := MainGui.Add("Text", "x495 y170", "Suma (minučių tikslumu):")
    txtActiveCost := MainGui.Add("Text", "x660 y170 w250 h22", "0.00 €")
    txtActiveCost.SetFont("s11 bold cGreen")

    txtActiveItemsHeader := MainGui.Add("Text", "x495 y200", "Paimtos detalės ir tarifai:")
    lvActiveItems := MainGui.Add("ListView", "x495 y225 w420 h175 +Grid -Multi", ["Numeris", "Pavadinimas", "Tarifas", "Paimta", "Grąžinama"])
    lvActiveItems.ModifyCol(1, 65)
    lvActiveItems.ModifyCol(2, 165)
    lvActiveItems.ModifyCol(3, 70)
    lvActiveItems.ModifyCol(4, 55)
    lvActiveItems.ModifyCol(5, 60)

    btnReturnAll := MainGui.Add("Button", "x495 y410 w200 h30", "Pažymėti viską grąžinta")
    btnReturnAll.OnEvent("Click", OnReturnAllClick)

    btnCompleteReturn := MainGui.Add("Button", "x495 y450 w420 h45", "UŽBAIGTI GRĄŽINIMĄ (Apskaičiuoti Kainą)")
    btnCompleteReturn.SetFont("s11 bold")
    btnCompleteReturn.OnEvent("Click", OnCompleteReturnClick)


    ; --------------------------------------------------------------------------
    ; TAB 3: DETALIŲ NUSTATYMAI
    ; --------------------------------------------------------------------------
    TabCtrl.UseTab(3)

    MainGui.SetFont("s11 bold")
    MainGui.Add("Text", "x30 y50", "Pastolių Detalių ir Priekabų Katalogas (Nustatymai):")
    MainGui.SetFont("s10 norm")

    lvSettingsParts := MainGui.Add("ListView", "x30 y80 w470 h480 +Grid -Multi", ["Numeris", "Pavadinimas", "Kiekis", "Tarifas (€/val)", "Foto"])
    lvSettingsParts.ModifyCol(1, 90)
    lvSettingsParts.ModifyCol(2, 180)
    lvSettingsParts.ModifyCol(3, 55)
    lvSettingsParts.ModifyCol(4, 90)
    lvSettingsParts.ModifyCol(5, 50)
    lvSettingsParts.OnEvent("ItemSelect", OnSettingsPartSelect)

    ; Forma dešinėje
    grpSettings1 := MainGui.Add("GroupBox", "x520 y70 w410 h490", "Redaguoti / Pridėti Detalę")

    lblSetCode := MainGui.Add("Text", "x540 y100", "Numeris (pvz. A1/P1):")
    edtSetCode := MainGui.Add("Edit", "x700 y97 w210 h26")

    lblSetName := MainGui.Add("Text", "x540 y140", "Pavadinimas:")
    edtSetName := MainGui.Add("Edit", "x700 y137 w210 h26")

    lblSetQty := MainGui.Add("Text", "x540 y180", "Visas Kiekis (Vnt):")
    edtSetTotalQty := MainGui.Add("Edit", "x700 y177 w100 h26 Number", "10")

    lblSetPrice := MainGui.Add("Text", "x540 y220", "Tarifas (EUR / val.):")
    edtSetPricePerHour := MainGui.Add("Edit", "x700 y217 w100 h26", "0.50")

    lblSetImg := MainGui.Add("Text", "x540 y260", "Nuotraukos failas:")
    edtSetImagePath := MainGui.Add("Edit", "x540 y285 w280 h26")
    btnBrowseImg := MainGui.Add("Button", "x828 y284 w82 h28", "Naršyti...")
    btnBrowseImg.OnEvent("Click", OnBrowseImageClick)

    picPartPreview3 := MainGui.Add("Picture", "x540 y325 w370 h150 +Border")

    btnAddPart := MainGui.Add("Button", "x540 y490 w175 h35", "Išsaugoti / Pridėti")
    btnAddPart.SetFont("s10 bold")
    btnAddPart.OnEvent("Click", OnSaveSettingsPartClick)

    btnDeletePart := MainGui.Add("Button", "x735 y490 w175 h35", "Ištrinti Detalę")
    btnDeletePart.OnEvent("Click", OnDeleteSettingsPartClick)


    ; --------------------------------------------------------------------------
    ; TAB 4: UŽSAKYMŲ ISTORIJA
    ; --------------------------------------------------------------------------
    TabCtrl.UseTab(4)

    MainGui.SetFont("s11 bold")
    MainGui.Add("Text", "x30 y50", "Užbaigtų Nuomų Istorija ir Įplaukos:")
    MainGui.SetFont("s10 norm")

    lvHistoryOrders := MainGui.Add("ListView", "x30 y80 w520 h440 +Grid -Multi", ["ID", "Nuomininkas", "Pradžia", "Pabaiga", "Viso (€)"])
    lvHistoryOrders.ModifyCol(1, 45)
    lvHistoryOrders.ModifyCol(2, 150)
    lvHistoryOrders.ModifyCol(3, 115)
    lvHistoryOrders.ModifyCol(4, 115)
    lvHistoryOrders.ModifyCol(5, 80)
    lvHistoryOrders.OnEvent("ItemSelect", OnHistoryOrderSelect)

    btnExportHistory := MainGui.Add("Button", "x30 y530 w520 h40", "Eksportuoti Istoriją į Excel (.xlsx / .csv)...")
    btnExportHistory.SetFont("s10 bold")
    btnExportHistory.OnEvent("Click", ExportHistoryToExcel)

    grpHistory1 := MainGui.Add("GroupBox", "x570 y70 w360 h490", "Užsakymo Detalizacija")
    lvHistoryItems := MainGui.Add("ListView", "x585 y100 w330 h390 +Grid", ["Numeris", "Pavadinimas", "Kiekis", "Tarifas (€/val)"])
    lvHistoryItems.ModifyCol(1, 65)
    lvHistoryItems.ModifyCol(2, 140)
    lvHistoryItems.ModifyCol(3, 50)
    lvHistoryItems.ModifyCol(4, 75)

    txtHistoryTotalCost := MainGui.Add("Text", "x585 y505 w330 h30", "Gauta suma: -")
    txtHistoryTotalCost.SetFont("s11 bold cGreen")


    TabCtrl.UseTab()

    RefreshNewRentalLV()
    RefreshActiveOrdersLV()
    RefreshSettingsLV()
    RefreshHistoryLV()

    MainGui.OnEvent("Size", OnMainGuiSize)
    MainGui.OnEvent("Close", (*) => ExitApp())
    MainGui.Show("w970 h670")
}


; ==============================================================================
; DINAMINIS LANGŲ IR VALDIKLIŲ DYDŽIO KEITIMAS (RESIZE)
; ==============================================================================

OnMainGuiSize(guiObj, minMax, guiW, guiH) {
    if (minMax = -1) ; Minimized
        return

    ; Pagrindinis TabCtrl apima visą langą
    tabW := guiW - 20
    tabH := guiH - 20
    TabCtrl.Move(10, 10, tabW, tabH)

    ; --- TAB 1 REPOSITION & RESIZE ---
    leftW1 := Integer((tabW - 60) * 0.65)
    rightW1 := tabW - 60 - leftW1

    lvH1 := tabH - 220
    if (lvH1 < 100)
        lvH1 := 100
    lvNewRentalParts.Move(30, 150, leftW1, lvH1)
    btnStartRental.Move(30, tabH - 60, leftW1, 50)

    rightX1 := 40 + leftW1
    grpNewRental2.Move(rightX1, 140, rightW1, tabH - 150)
    lblSelectedPart1.Move(rightX1 + 15, 165, rightW1 - 30, 40)
    lblRentalQtyTitle.Move(rightX1 + 15, 215, 130, 25)
    edtRentalQty.Move(rightX1 + 150, 212, 70, 26)
    btnSetQty.Move(rightX1 + 225, 211, rightW1 - 240, 28)

    picH1 := tabH - 320
    if (picH1 < 100)
        picH1 := 100
    picPartPreview1.Move(rightX1 + 15, 255, rightW1 - 30, picH1)
    txtPartInfo1.Move(rightX1 + 15, tabH - 60, rightW1 - 30, 50)

    ; --- TAB 2 REPOSITION & RESIZE ---
    leftW2 := Integer((tabW - 60) * 0.48)
    rightW2 := tabW - 60 - leftW2

    lvH2 := tabH - 95
    if (lvH2 < 100)
        lvH2 := 100
    lvActiveOrders.Move(30, 80, leftW2, lvH2)

    rightX2 := 40 + leftW2
    grpActive1.Move(rightX2, 70, rightW2, tabH - 85)

    txtActiveTenantHeader.Move(rightX2 + 15, 95, 100, 22)
    txtActiveTenant.Move(rightX2 + 120, 95, rightW2 - 135, 22)

    txtActiveStartHeader.Move(rightX2 + 15, 120, 100, 22)
    txtActiveStart.Move(rightX2 + 120, 120, rightW2 - 135, 22)

    txtActiveDurationHeader.Move(rightX2 + 15, 145, 100, 22)
    txtActiveDuration.Move(rightX2 + 120, 145, rightW2 - 135, 22)

    txtActiveCostHeader.Move(rightX2 + 15, 170, 160, 22)
    txtActiveCost.Move(rightX2 + 180, 170, rightW2 - 195, 22)

    txtActiveItemsHeader.Move(rightX2 + 15, 200, rightW2 - 30, 22)

    itemsH2 := tabH - 330
    if (itemsH2 < 80)
        itemsH2 := 80
    lvActiveItems.Move(rightX2 + 15, 225, rightW2 - 30, itemsH2)

    btnReturnAll.Move(rightX2 + 15, tabH - 98, Integer((rightW2 - 30) * 0.5), 32)
    btnCompleteReturn.Move(rightX2 + 15, tabH - 60, rightW2 - 30, 45)

    ; --- TAB 3 REPOSITION & RESIZE ---
    leftW3 := Integer((tabW - 60) * 0.52)
    rightW3 := tabW - 60 - leftW3

    lvH3 := tabH - 95
    if (lvH3 < 100)
        lvH3 := 100
    lvSettingsParts.Move(30, 80, leftW3, lvH3)

    rightX3 := 40 + leftW3
    grpSettings1.Move(rightX3, 70, rightW3, tabH - 85)

    lblSetCode.Move(rightX3 + 15, 100, 160, 22)
    edtSetCode.Move(rightX3 + 180, 97, rightW3 - 195, 26)

    lblSetName.Move(rightX3 + 15, 140, 160, 22)
    edtSetName.Move(rightX3 + 180, 137, rightW3 - 195, 26)

    lblSetQty.Move(rightX3 + 15, 180, 160, 22)
    edtSetTotalQty.Move(rightX3 + 180, 177, 100, 26)

    lblSetPrice.Move(rightX3 + 15, 220, 160, 22)
    edtSetPricePerHour.Move(rightX3 + 180, 217, 100, 26)

    lblSetImg.Move(rightX3 + 15, 260, rightW3 - 30, 22)
    edtSetImagePath.Move(rightX3 + 15, 285, rightW3 - 110, 26)
    btnBrowseImg.Move(rightX3 + rightW3 - 90, 284, 75, 28)

    picH3 := tabH - 385
    if (picH3 < 80)
        picH3 := 80
    picPartPreview3.Move(rightX3 + 15, 325, rightW3 - 30, picH3)

    btnW3 := Integer((rightW3 - 40) / 2)
    btnAddPart.Move(rightX3 + 15, tabH - 55, btnW3, 35)
    btnDeletePart.Move(rightX3 + 25 + btnW3, tabH - 55, btnW3, 35)

    ; --- TAB 4 REPOSITION & RESIZE ---
    leftW4 := Integer((tabW - 60) * 0.55)
    rightW4 := tabW - 60 - leftW4

    lvH4 := tabH - 145
    if (lvH4 < 100)
        lvH4 := 100
    lvHistoryOrders.Move(30, 80, leftW4, lvH4)
    btnExportHistory.Move(30, tabH - 55, leftW4, 40)

    rightX4 := 40 + leftW4
    grpHistory1.Move(rightX4, 70, rightW4, tabH - 85)

    itemsH4 := tabH - 150
    if (itemsH4 < 100)
        itemsH4 := 100
    lvHistoryItems.Move(rightX4 + 15, 100, rightW4 - 30, itemsH4)
    txtHistoryTotalCost.Move(rightX4 + 15, tabH - 45, rightW4 - 30, 30)
}


; ==============================================================================
; TAB 1: NAUJA NUOMA LOGIKA
; ==============================================================================

RefreshNewRentalLV() {
    global lvNewRentalParts, Parts
    lvNewRentalParts.Delete()

    for code, pObj in Parts {
        avail := GetAvailableQty(code)
        lvNewRentalParts.Add("", pObj.Code, pObj.Name, Format("{:.2f} €", pObj.PricePerHour), avail, 0)
    }
}

OnNewRentalPartSelect(guiCtrl, itemIndex, selected) {
    global lvNewRentalParts, lblSelectedPart1, edtRentalQty, picPartPreview1, txtPartInfo1, selectedPartCode1, Parts
    if (!selected || itemIndex = 0)
        return

    code := lvNewRentalParts.GetText(itemIndex, 1)
    pName := lvNewRentalParts.GetText(itemIndex, 2)
    avail := lvNewRentalParts.GetText(itemIndex, 4)
    currQty := lvNewRentalParts.GetText(itemIndex, 5)

    selectedPartCode1 := code
    lblSelectedPart1.Text := "[" . code . "] " . pName
    edtRentalQty.Value := currQty

    if Parts.Has(code) {
        imgPath := Parts[code].ImagePath
        if (imgPath != "" && FileExist(imgPath)) {
            try {
                picPartPreview1.Value := imgPath
            } catch {
                picPartPreview1.Value := ""
            }
        } else {
            picPartPreview1.Value := ""
        }
    }
    txtPartInfo1.Text := "Viso sandėlyje: " . Parts[code].TotalQty . " vnt.`nLaisva nuomai: " . avail . " vnt.`nTarifas: " . Format("{:.2f} €/val.", Parts[code].PricePerHour)
}

OnSetRentalQtyClick(guiCtrl, info) {
    global lvNewRentalParts, edtRentalQty, selectedPartCode1
    if (selectedPartCode1 = "") {
        MsgBox("Pirmiausia pasirinkite detalę iš sąrašo!", "Dėmesio", "48")
        return
    }

    itemIndex := lvNewRentalParts.GetNext(0)
    if (itemIndex = 0)
        return

    reqQty := Integer(edtRentalQty.Value = "" ? 0 : edtRentalQty.Value)
    availQty := Integer(lvNewRentalParts.GetText(itemIndex, 4))

    if (reqQty < 0) {
        MsgBox("Kiekis negali būti neigiamas!", "Klaida", "48")
        return
    }

    if (reqQty > availQty) {
        MsgBox("Negalima pasirinkti daugiau nei yra laisvų detalių (" . availQty . " vnt.)!", "Klaida", "48")
        return
    }

    lvNewRentalParts.Modify(itemIndex, "Col5", reqQty)
}

OnStartRentalClick(guiCtrl, info) {
    global edtTenantName, lvNewRentalParts, Orders, Parts
    tenant := Trim(edtTenantName.Value)
    if (tenant = "") {
        MsgBox("Įveskite nuomininko / įmonės vardą!", "Trūksta duomenų", "48")
        return
    }

    itemsMap := Map()
    rowCount := lvNewRentalParts.GetCount()

    loop rowCount {
        code := lvNewRentalParts.GetText(A_Index, 1)
        qty  := Integer(lvNewRentalParts.GetText(A_Index, 5))
        if (qty > 0) {
            itemsMap[code] := qty
        }
    }

    if (itemsMap.Count = 0) {
        MsgBox("Pasirinkite bent vieną detalę (kiekis > 0) nuomai!", "Trūksta detalių", "48")
        return
    }

    ; ID skaičiuojamas nuo 0 (pvz. 0, 1, 2...)
    maxID := -1
    for ordID, ordObj in Orders {
        if IsNumber(ordID) && Integer(ordID) > maxID
            maxID := Integer(ordID)
    }
    newID := String(maxID + 1)

    startTS := FormatTime(A_Now, "yyyyMMddHHmmss")

    newOrder := {OrderID: newID, Tenant: tenant, StartTS: startTS, Status: "Aktyvus", EndTS: "", TotalCost: 0.0, Items: itemsMap}
    Orders[newID] := newOrder
    SaveOrderToINI(newOrder)

    MsgBox("Užsakymas Nr. " . newID . " sėkmingai sukurtas!`nSkaičiuojama laiko trukmė ir kaina minučių tikslumu.", "Nuoma Pradėta", "64")

    edtTenantName.Value := ""
    RefreshNewRentalLV()
    RefreshActiveOrdersLV()
}


; ==============================================================================
; TAB 2: AKTYVIOS NUOMOS IR GRĄŽINIMAS LOGIKA
; ==============================================================================

RefreshActiveOrdersLV() {
    global lvActiveOrders, Orders
    lvActiveOrders.Delete()

    for ordID, ord in Orders {
        if (ord.Status = "Aktyvus") {
            formattedStart := FormatTimestamp(ord.StartTS)
            durStr := CalculateDuration(ord.StartTS, A_Now)
            costVal := CalculateRentalCost(ord.StartTS, A_Now, ord.Items)
            lvActiveOrders.Add("", ord.OrderID, ord.Tenant, formattedStart, durStr, Format("{:.2f} €", costVal))
        }
    }
}

UpdateActiveDurations() {
    global lvActiveOrders, Orders, txtActiveDuration, txtActiveCost, selectedActiveOrderID
    if (lvActiveOrders.GetCount() = 0)
        return

    loop lvActiveOrders.GetCount() {
        ordID := lvActiveOrders.GetText(A_Index, 1)
        if Orders.Has(ordID) {
            ord := Orders[ordID]
            durStr := CalculateDuration(ord.StartTS, A_Now)
            costVal := CalculateRentalCost(ord.StartTS, A_Now, ord.Items)

            lvActiveOrders.Modify(A_Index, "Col4", durStr)
            lvActiveOrders.Modify(A_Index, "Col5", Format("{:.2f} €", costVal))

            if (ordID = selectedActiveOrderID) {
                txtActiveDuration.Text := durStr
                txtActiveCost.Text := Format("{:.2f} €", costVal)
            }
        }
    }
}

OnActiveOrderSelect(guiCtrl, itemIndex, selected) {
    global lvActiveOrders, Orders, txtActiveTenant, txtActiveStart, txtActiveDuration, txtActiveCost, lvActiveItems, selectedActiveOrderID, Parts
    if (!selected || itemIndex = 0)
        return

    ordID := lvActiveOrders.GetText(itemIndex, 1)
    if !Orders.Has(ordID)
        return

    selectedActiveOrderID := ordID
    ord := Orders[ordID]

    txtActiveTenant.Text := ord.Tenant
    txtActiveStart.Text := FormatTimestamp(ord.StartTS)
    txtActiveDuration.Text := CalculateDuration(ord.StartTS, A_Now)
    txtActiveCost.Text := Format("{:.2f} €", CalculateRentalCost(ord.StartTS, A_Now, ord.Items))

    lvActiveItems.Delete()
    for code, qty in ord.Items {
        pName := Parts.Has(code) ? Parts[code].Name : "Detalė"
        priceStr := Parts.Has(code) ? Format("{:.2f} €/val.", Parts[code].PricePerHour) : "0.00 €"
        lvActiveItems.Add("", code, pName, priceStr, qty, qty)
    }
}

OnReturnAllClick(guiCtrl, info) {
    global lvActiveItems
    loop lvActiveItems.GetCount() {
        rentedQty := lvActiveItems.GetText(A_Index, 4)
        lvActiveItems.Modify(A_Index, "Col5", rentedQty)
    }
}

OnCompleteReturnClick(guiCtrl, info) {
    global selectedActiveOrderID, Orders, lvActiveItems
    if (selectedActiveOrderID = "" || !Orders.Has(selectedActiveOrderID)) {
        MsgBox("Pasirinkite aktyvų užsakymą iš sąrašo!", "Dėmesio", "48")
        return
    }

    ord := Orders[selectedActiveOrderID]
    nowTS := FormatTime(A_Now, "yyyyMMddHHmmss")

    finalCost := CalculateRentalCost(ord.StartTS, nowTS, ord.Items)
    durStr := CalculateDuration(ord.StartTS, nowTS)

    allReturned := true
    loop lvActiveItems.GetCount() {
        rented := Integer(lvActiveItems.GetText(A_Index, 4))
        ret    := Integer(lvActiveItems.GetText(A_Index, 5))
        if (ret < rented) {
            allReturned := false
            break
        }
    }

    msg := "Užsakymo Nr. " . selectedActiveOrderID . " grąžinimo suvestinė:`n"
    msg .= "Nuomos trukmė: " . durStr . "`n"
    msg .= "APSKAIČIUOTA KAINA (minučių tikslumu): " . Format("{:.2f} EUR", finalCost) . "`n`n"
    msg .= "Ar norite užbaigti užsakymą ir grąžinti detales į sandėlį?"

    if (!allReturned) {
        msg .= "`n`nDĖMESIO: Kai kurių detalių grąžinamas kiekis yra mažesnis nei paimtas!"
    }

    res := MsgBox(msg, "Nuomos Grąžinimas ir Apmokėjimas", "36")
    if (res != "Yes")
        return

    ord.Status := "Grąžintas"
    ord.EndTS := nowTS
    ord.TotalCost := finalCost
    SaveOrderToINI(ord)

    MsgBox("Užsakymas Nr. " . selectedActiveOrderID . " sėkmingai užbaigtas!`nUžregistruota apmokėjimo suma: " . Format("{:.2f} EUR", finalCost), "Sėkmingai Užbaigta", "64")

    selectedActiveOrderID := ""
    txtActiveTenant.Text := "-"
    txtActiveStart.Text := "-"
    txtActiveDuration.Text := "0 d. 00:00:00"
    txtActiveCost.Text := "0.00 €"
    lvActiveItems.Delete()

    RefreshActiveOrdersLV()
    RefreshNewRentalLV()
    RefreshHistoryLV()
}


; ==============================================================================
; TAB 3: DETALIŲ NUSTATYMAI LOGIKA
; ==============================================================================

RefreshSettingsLV() {
    global lvSettingsParts, Parts
    lvSettingsParts.Delete()

    for code, pObj in Parts {
        hasImg := (pObj.ImagePath != "" && FileExist(pObj.ImagePath)) ? "Taip" : "Ne"
        lvSettingsParts.Add("", pObj.Code, pObj.Name, pObj.TotalQty, Format("{:.2f} €", pObj.PricePerHour), hasImg)
    }
}

OnSettingsPartSelect(guiCtrl, itemIndex, selected) {
    global lvSettingsParts, edtSetCode, edtSetName, edtSetTotalQty, edtSetPricePerHour, edtSetImagePath, picPartPreview3, Parts
    if (!selected || itemIndex = 0)
        return

    code := lvSettingsParts.GetText(itemIndex, 1)
    if !Parts.Has(code)
        return

    pObj := Parts[code]
    edtSetCode.Value := pObj.Code
    edtSetName.Value := pObj.Name
    edtSetTotalQty.Value := pObj.TotalQty
    edtSetPricePerHour.Value := Format("{:.2f}", pObj.PricePerHour)
    edtSetImagePath.Value := pObj.ImagePath

    if (pObj.ImagePath != "" && FileExist(pObj.ImagePath)) {
        try {
            picPartPreview3.Value := pObj.ImagePath
        } catch {
            picPartPreview3.Value := ""
        }
    } else {
        picPartPreview3.Value := ""
    }
}

OnBrowseImageClick(guiCtrl, info) {
    global edtSetImagePath, picPartPreview3
    selectedFile := FileSelect(1, ImagesDir, "Pasirinkite detalės nuotrauką", "Paveikslėliai (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selectedFile != "") {
        edtSetImagePath.Value := selectedFile
        try {
            picPartPreview3.Value := selectedFile
        } catch {
            picPartPreview3.Value := ""
        }
    }
}

OnSaveSettingsPartClick(guiCtrl, info) {
    global edtSetCode, edtSetName, edtSetTotalQty, edtSetPricePerHour, edtSetImagePath, Parts
    code := Trim(edtSetCode.Value)
    pName := Trim(edtSetName.Value)
    pQty := Integer(edtSetTotalQty.Value = "" ? 0 : edtSetTotalQty.Value)
    pPrice := Float(edtSetPricePerHour.Value = "" ? 0.0 : edtSetPricePerHour.Value)
    pImg := Trim(edtSetImagePath.Value)

    if (code = "" || pName = "") {
        MsgBox("Užpildykite detalės kodą ir pavadinimą!", "Klaida", "48")
        return
    }

    Parts[code] := {Code: code, Name: pName, TotalQty: pQty, ImagePath: pImg, PricePerHour: pPrice}
    SavePartsToConfig()

    MsgBox("Detalė [" . code . "] išsaugota sėkmingai!", "Informacija", "64")

    RefreshSettingsLV()
    RefreshNewRentalLV()
}

OnDeleteSettingsPartClick(guiCtrl, info) {
    global edtSetCode, Parts
    code := Trim(edtSetCode.Value)
    if (code = "" || !Parts.Has(code)) {
        MsgBox("Pasirinkite egzistuojančią detalę ištrinimui!", "Klaida", "48")
        return
    }

    res := MsgBox("Ar tikrai norite ištrinti detalę [" . code . "]?", "Ištrinimo Patvirtinimas", "36")
    if (res = "Yes") {
        Parts.Delete(code)
        SavePartsToConfig()

        edtSetCode.Value := ""
        edtSetName.Value := ""
        edtSetTotalQty.Value := "10"
        edtSetPricePerHour.Value := "0.50"
        edtSetImagePath.Value := ""

        RefreshSettingsLV()
        RefreshNewRentalLV()
    }
}


; ==============================================================================
; TAB 4: UŽSAKYMŲ ISTORIJA LOGIKA
; ==============================================================================

RefreshHistoryLV() {
    global lvHistoryOrders, Orders
    lvHistoryOrders.Delete()

    for ordID, ord in Orders {
        if (ord.Status = "Grąžintas") {
            fStart := FormatTimestamp(ord.StartTS)
            fEnd   := FormatTimestamp(ord.EndTS)
            lvHistoryOrders.Add("", ord.OrderID, ord.Tenant, fStart, fEnd, Format("{:.2f} €", ord.TotalCost))
        }
    }
}

OnHistoryOrderSelect(guiCtrl, itemIndex, selected) {
    global lvHistoryOrders, lvHistoryItems, txtHistoryTotalCost, Orders, Parts
    if (!selected || itemIndex = 0)
        return

    ordID := lvHistoryOrders.GetText(itemIndex, 1)
    if !Orders.Has(ordID)
        return

    ord := Orders[ordID]
    lvHistoryItems.Delete()

    for code, qty in ord.Items {
        pName := Parts.Has(code) ? Parts[code].Name : "Detalė"
        pPriceStr := Parts.Has(code) ? Format("{:.2f} €", Parts[code].PricePerHour) : "0.00 €"
        lvHistoryItems.Add("", code, pName, qty, pPriceStr)
    }

    txtHistoryTotalCost.Text := "Gauta nuomos suma: " . Format("{:.2f} EUR", ord.TotalCost)
}

ExportHistoryToExcel(guiCtrl, info) {
    global Orders, Parts

    completedOrders := []
    for ordID, ord in Orders {
        if (ord.Status = "Grąžintas") {
            completedOrders.Push(ord)
        }
    }

    if (completedOrders.Length = 0) {
        MsgBox("Nėra užbaigtų užsakymų istorijos eksportavimui!", "Dėmesio", "48")
        return
    }

    defaultFileName := "Uzsakymu_Istorija_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".csv"
    savePath := FileSelect(16, defaultFileName, "Išsaugoti užsakymų istoriją", "Excel CSV failas (*.csv);;Tekstinis failas (*.txt)")
    if (savePath = "")
        return

    if (!InStr(savePath, "."))
        savePath .= ".csv"

    csvContent := "Užsakymo ID;Nuomininkas;Pradžios Laikas;Pabaigos Laikas;Trukmė;Paimtos Detalės;Viso Suma (€)`n"

    for ord in completedOrders {
        fStart := FormatTimestamp(ord.StartTS)
        fEnd   := FormatTimestamp(ord.EndTS)
        durStr := CalculateDuration(ord.StartTS, ord.EndTS)

        itemsStr := ""
        for code, qty in ord.Items {
            pName := Parts.Has(code) ? Parts[code].Name : code
            itemsStr .= (itemsStr = "" ? "" : ", ") . pName . " (" . code . "): " . qty . " vnt."
        }

        rowStr := ord.OrderID . ";"
        rowStr .= '"' . StrReplace(ord.Tenant, '"', '""') . '";'
        rowStr .= '"' . fStart . '";'
        rowStr .= '"' . fEnd . '";'
        rowStr .= '"' . durStr . '";'
        rowStr .= '"' . StrReplace(itemsStr, '"', '""') . '";'
        rowStr .= '"' . Format("{:.2f}", ord.TotalCost) . '"`n'

        csvContent .= rowStr
    }

    try {
        if FileExist(savePath)
            FileDelete(savePath)

        fileObj := FileOpen(savePath, "w", "UTF-8")
        if fileObj {
            fileObj.Write(csvContent)
            fileObj.Close()

            res := MsgBox("Istorija sėkmingai eksportuota į failą:`n" . savePath . "`n`nAr norite atidaryti šį failą?", "Eksportas Baigtas", "36")
            if (res = "Yes") {
                Run(savePath)
            }
        } else {
            MsgBox("Nepavyko atidaryti failo įrašymui!", "Klaida", "48")
        }
    } catch err {
        MsgBox("Įvyko klaida eksportuojant istoriją: " . err.Message, "Klaida", "48")
    }
}


; ==============================================================================
; PAGALBINĖS FUNKCIJOS
; ==============================================================================

FormatTimestamp(ts) {
    if (StrLen(ts) < 14)
        return ts
    y := SubStr(ts, 1, 4)
    m := SubStr(ts, 5, 2)
    d := SubStr(ts, 7, 2)
    hh := SubStr(ts, 9, 2)
    mm := SubStr(ts, 11, 2)
    return y . "-" . m . "-" . d . " " . hh . ":" . mm
}

CalculateDuration(startTS, endTS) {
    if (startTS = "" || StrLen(startTS) < 14)
        return "0 d. 00:00:00"

    secDiff := DateDiff(endTS, startTS, "Seconds")
    if (secDiff < 0)
        secDiff := 0

    days := secDiff // 86400
    remSec := Mod(secDiff, 86400)

    hours := remSec // 3600
    remSec := Mod(remSec, 3600)

    mins := remSec // 60
    secs := Mod(remSec, 60)

    return Format("{1} d. {2:02}:{3:02}:{4:02}", days, hours, mins, secs)
}

CalculateRentalCost(startTS, endTS, itemsMap) {
    global Parts
    if (startTS = "" || StrLen(startTS) < 14 || itemsMap.Count = 0)
        return 0.0

    secDiff := DateDiff(endTS, startTS, "Seconds")
    if (secDiff < 0)
        secDiff := 0

    minutes := secDiff / 60.0
    hours := minutes / 60.0

    totalCost := 0.0
    for code, qty in itemsMap {
        if Parts.Has(code) {
            itemRate := Parts[code].PricePerHour
            totalCost += qty * itemRate * hours
        }
    }

    return totalCost
}

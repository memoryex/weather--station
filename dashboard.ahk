#Requires AutoHotkey v2.0
#SingleInstance Force

; =======================================================
; GLOBALAI IR PRODUCT MAP
; =======================================================
Global ServerPath := "\\10.12.24.50\fgt_hal\FGT_log"
Global ResultPaths := []

Global ProductMap := Map(
    "080554", "HSDS050 500w InteliStore Heater",
    "080561", "HSDS070 700w InteliStore Heater",
    "080578", "HSDS125 1250w InteliStore Heater",
    "080585", "HSDS150 1500w InteliStore Heater",
    "080592", "DESE050 0.5kW Slim Dyn Strge Htr",
    "080608", "DESE070 0.7kW Slim Dyn Strge Htr",
    "080615", "DESE125 1.25kW Slim Dyn Strge Htr",
    "080752", "NLSH070 0.70kW Newlec Storage Htr",
    "080769", "NLSH125 1.25kW Newlec Storage Htr",
    "080776", "NLSH150 1.50kW Newlec Storage Htr",
    "080783", "SSHE050 0.50kW Sunhouse Storage Htr",
    "080790", "SSHE070 0.70kW Sunhouse Storage Htr",
    "080806", "SSHE125 1.25kW Sunhouse Storage Htr",
    "080813", "SSHE150 1.50kW Sunhouse Storage Htr",
    "080820", "TSRE050 0.50kW Creda Storage Heater",
    "080837", "TSRE070 0.70kW Creda Storage Heater",
    "080844", "TSRE125 1.25kW Creda Storage Heater",
    "080851", "TSRE150 1.50kW Creda Storage Heater",
    "080905", "XLE050 0.50kW Dimplex (Case Only)",
    "080912", "XLE070 0.70KW Dimplex (Case Only)",
    "080929", "XLE125 1.25kW Dimplex (Case Only)",
    "080936", "XLE150 1.50kW Dimplex (Case Only)",
    "080998", "XLE100 1.00kW Dimplex (Case Only)",
    "081056", "TSRE100 1.00kW Creda Storage Heater",
    "081063", "HSDS100 1000w InteliStore Heater",
    "081070", "DESE150 1.5kW Slim Dyn Strge Htr",
    "081087", "NLSH100 1.00kW Newlec Storage Htr",
    "081094", "NLSH050 0.50kW Newlec Storage Htr",
    "081223", "DESE100 1kW Slim Dyn Strge Htr",
    "081254", "SSHE100 1.00kW Sunhouse Storage Htr",
    "081353", "QRAD050RF 500W Quantum Electric Rad",
    "081360", "QRAD075RF 750W Quantum Electric Rad",
    "081377", "QRAD100RF 1000W Quantum Electric Rad",
    "081384", "QRAD150RF 1500W Quantum Electric Rad",
    "081391", "QRAD200RF 2000W Quantum Electric Rad",
    "081407", "QM050RF QUANTUM STORAGE CASE ONLY",
    "081414", "QM100RF QUANTUM STORAGE CASE ONLY",
    "081421", "QM125RF QUANTUM STORAGE CASE ONLY",
    "081438", "QM150RF QUANTUM STORAGE CASE ONLY",
    "081520", "QM070RF QUANTUM STORAGE CASE ONLY",
    "082367", "QRAD050E 500W RF Quantum Electric Rad",
    "082374", "QRAD075E 750W RF Quantum Electric Rad",
    "082381", "QRAD100E 100W RF Quantum Electric Rad",
    "082398", "QRAD150E 1500W RF Quantum Electric Rad",
    "082404", "QRAD200E 2000W RF Quantum Electric Rad",
    "082411", "HSDHHR050",
    "082428", "HSDHHR070",
    "082435", "HSDHHR100",
    "082442", "HSDHHR125",
    "082459", "HSDHHR150",
    "090355", "HSDP1000 1000W  InteliPanel Heater",
    "090362", "HSDP1500 1500W InteliPanel Heater",
    "090379", "HSDP2000 2000W  InteliPanel Heater",
    "090386", "HSDP3000 3000W InteliPanel Heater",
    "090393", "HSDP750 750W  InteliPanel Heater",
    "090713", "PLX100E 1.00kW Dimplex Panel Heater",
    "090720", "PLX125E 1.25kW Dimplex Panel Heater",
    "090737", "PLX150E 1.50kW Dimplex Panel Heater",
    "090744", "PLX200E 2.00kW Dimplex Panel Heater",
    "090751", "PLXC300E 3.00kW Dimplex Panel Heater",
    "090768", "PLX050E 0.50kW Dimplex Panel Heater",
    "090775", "PLX075E 0.75kW Dimplex Panel Heater",
    "091178", "LST075E 750W Low Surface Temperature",
    "091185", "LST100E 1000W Low Surface Temperature",
    "091192", "LST150E 1500W Low Surface Temperature",
    "091208", "LST050E 500W Low Surface Temperature",
    "091291", "HSDP500 500W INTELIPANEL HEATER",
    "091741", "PLX050ENC 0.50kW Panel No Controls",
    "091758", "PLX075ENC 0.75kW Panel No Controls",
    "091765", "PLX100ENC 1.00kW Panel No Controls",
    "091772", "PLX125ENC 1.25kW Panel No Controls",
    "091789", "PLX150ENC 1.50kW Panel No Controls",
    "091796", "PLX200ENC 2.00kW Panel No Controls",
    "371880", "RCE 050 GDD (QRAD050)",
    "371890", "RCE 100 GDD (QRAD100)",
    "371900", "RCE 150 GDD (QRAD150)",
    "371910", "RCE 200 GDD (QRAD200)",
    "376180", "PLX050E 0.5kW Dimplex Panel Heater EU",
    "376190", "PLX075E 0.75kW Dimplex Panel Heater EU",
    "376200", "PLX100E 1.0 kW Dimplex Panel Heater EU",
    "376210", "PLX150E 1.5kW Dimplex Panel Heater EU",
    "376220", "PLX200E 2.0kW Dimplex Panel Heater EU",
    "376230", "PLX300E 3.0kW Dimplex Panel Heater EU",
    "377610", "PLX025E 0.25kW Dimplex Panel Heater EU",
    "400000452", "NCPT15 1.5kW Compact II Panel Heater",
    "400000453", "NCPT20 2kW Compact II Panel Heater",
    "400000465", "NCPT10 1kW Compact II Panel Heater",
    "400000466", "NCPT24 2.4kW Compact II Panel Heater",
    "400000613", "FLB 750W/1000W Panel Convector",
    "400000614", "FLB 1175W/1500W Panel Convector",
    "400000615", "FLB 1560W/2000W Panel Convector",
    "400000616", "FLB+ 390W/500W Convector w Thermostat",
    "400000617", "FLB+ 780W/1000W Convector w Thermostat",
    "400000618", "FLB+ 1175W/1500W Convector w Thermostat",
    "400000619", "FLB+ 1560W/2000W Convector w Thermostat",
    "400000625", "FLB 500W/375W Panel Convector",
    "400000649", "DTD4R 15 1500w 230-240V DX WiFi Alta",
    "400000660", "DTD4R 20 2000w 230-240V DX WiFi Alta",
    "400000775", "XLE070 0.70kW Dimplex Storage Heater EU",
    "400000776", "XLE100 1.00kW Dimplex Storage Heater EU",
    "400000777", "XLE125 1.25kW Dimplex Storage Heater EU",
    "400000778", "XLE150 1.50kW Dimplex Storage Heater EU",
    "400000800", "XLE050 0.50kW Dimplex Storage Heater EU",
    "400001217", "DTD2R 05 500W 230-240V Alta WiFi",
    "400001218", "DTD2R 07 750W 230-240V Alta WiFi",
    "400001219", "DTD2R 10 1000w 230-240V Alta WiFi",
    "400001220", "DTD2R 12 1250w 230-240V Alta WiFi",
    "400001221", "DTD4R 05 500w 230-240V Alta WiFi",
    "400001222", "DTD4R 07 750w 230-240V Alta WiFi",
    "400001223", "DTD4R 10 1000w 230-240V Alta WiFi",
    "400001224", "DTD4R 15 1500w 230-240V Alta WiFi",
    "400001225", "DTD4R 20 2000w 230-240V Alta WiFi",
    "400001297", "CPH05T Creda Compact Panel w/7 Timer",
    "400001298", "CPH10T Creda Compact Panel w/7 Timer",
    "400001299", "CPH15T Creda Compact Panel w/7 Timer",
    "400001300", "CPH20T Creda Compact Panel w/7 Timer",
    "400001301", "CPH24T Creda Compact Panel w/7 Timer",
    "400001354", "NUL4T2 0.5kW NOBO Compact Panel EU",
    "400001360", "NUL4T2 1.5kW NOBO Compact Panel EU",
    "400001361", "NUL4T2 2kW NOBO Compact Panel EU",
    "400001363", "PLX125E 1.25kW Dimplex Panel Heater TL",
    "400001368", "NTL4R 10 1kW 230-240v AUS EX WIFI",
    "400001370", "PLX125E 1.25kW Dimplex Panel Heater SDM",
    "400001391", "NTL4R 15 1.5kW 230-240v AUS EX WIFI",
    "400001392", "NTL4R 2kW 230-240v AUS EX WIFI",
    "400001393", "NTL4R 24 2.4kW 230-240v AUS EX WIFI",
    "400001591", "NUL4T2 2.4kW NOBO Compact Panel EU",
    "400001592", "DESPH05T 0.5Kw Denmans Panel Heater",
    "400001602", "DESPH10T 1.0Kw Denmans Panel Heater",
    "400001603", "DESPH15T 1.5Kw Denmans Panel Heater",
    "400001604", "DESPH20T 2.0Kw Denmans Panel Heater",
    "400001605", "DESPH24T 2.4Kw Denmans Panel Heater",
    "400001618", "SPH050 500W Sunhouse Panel Heater",
    "400001619", "SPH100 1Kw Sunhouse Panel Heater",
    "400001620", "SPH150 1.5Kw Sunhouse Panel Heater",
    "400001621", "SPH200 2Kw Sunhouse Panel Heater",
    "400001692", "NTL2N 05 500W 230-240V DX Black",
    "400001693", "NTL2N 07 750W 230-240V DX Black",
    "400001694", "NTL2N 10 1000W 230-240V DX Black",
    "400001695", "NTL4N 02 250W 230-240V DX Black",
    "400001696", "NTL4N 05 500W 230-240V DX Black",
    "400001697", "NTL4N 07 750W 230-240V DX Black",
    "400001706", "NTL4N 10 1000W 230-240V DX Black",
    "400001726", "HSDPD750WiFi INTELLIPANEL DESIGNER HTR",
    "400001727", "HSDPD1000WiFi INTELLIPANEL DESIGNER HTR",
    "400001728", "HSDPD1500WiFi INTELLIPANEL DESIGNER HTR",
    "400001729", "HSDPD2000WiFi INTELLIPANEL DESIGNER HTR",
    "400001734", "HSDPD500WiFi INTELLIPANEL DESIGNER HTR",
    "400001741", "NFK2T 05 500W 230-240V EX EU",
    "400001742", "NFK2T 07 750W 230-240V EX EU",
    "400001748", "NLPH05T 0.5kW Newlec Panel Heater",
    "400001749", "NLPH10T 1.0kW Newlec Panel Heater",
    "400001760", "NLPH15T 1.5kW Newlec Panel Heater",
    "400001761", "NLPH20T 2.0kW Newlec Panel Heater",
    "400001762", "NLPH24T 2.4kW Newlec Panel Heater",
    "400001772", "NTL4R 05 500W 230-240V DX EU",
    "400001773", "NTL4R 10 1000W 230-240V DX EU",
    "400001774", "NTL4R 15 1500w 230-240V DX EU",
    "400001775", "NTL4R 20 2000w 230-240V DX EU",
    "82320005", "NFK2N 05 500W 230-240V DX",
    "82320007", "NFK2N 07 750W 230-240V DX",
    "82320010", "NFK2N 10 1000W 230-240V DX",
    "82320012", "NFK2N 12 1250W 230-240V DX",
    "82320310", "NFK2S 10 1000w 230-240V RU EX",
    "82320312", "NFK2S 12 1250W 230-240v RU EX",
    "82320405", "NFK2N 05 500W 400V DX",
    "82320407", "NFK2N 07 750W 400V DX",
    "82320410", "NFK2N 10 1000W 400V DX",
    "82320412", "NFK2N 12 1250W 400V DX",
    "82320705", "NFK2X 05 500W 230-240V DX",
    "82320707", "NFK2X 07 750W 230-240V DX",
    "82320710", "NFK2X 10 1000W 230-240V  DX",
    "82320712", "NFK2X 12 1250W 230-240V  DX",
    "82340002", "NFK4N 02 250W 230-240V DX",
    "82340005", "NFK4N 05 500W 230-240V DX",
    "82340007", "NFK4N 07 750W 230-240V DX",
    "82340010", "NFK4N 10 1000W 230-240V DX",
    "82340012", "NFK4N 12 1250W 230-240V DX",
    "82340015", "NFK4N 15 1500W 230-240V DX",
    "82340020", "NFK4N 20 2000W 230-240V DX",
    "82340305", "NFK4S 05 500W 230-240V EX INT",
    "82340310", "NFK4S 10 1000W 230-240V EX INT",
    "82340315", "NFK4S 15 1500W 230-240V EX INT",
    "82340320", "NFK4S 20 2000W 230-240V EX INT",
    "82340405", "NFK4N 05 500W 400V DX",
    "82340407", "NFK4N 07 750W 400V DX",
    "82340410", "NFK4N 10 1000W 400V DX",
    "82340412", "NFK4N 12 1250W  400V DX",
    "82340415", "NFK4N 15 1500W 400V  DX",
    "82340705", "NFK4X 05 500W 230-240V DX",
    "82340707", "NFK4X 07 750W 230-240V DX",
    "82340710", "NFK4X 10 1000W 230-240V  DX",
    "82340712", "NFK4X 12 1250W 230-240V  D",
    "82340715", "NFK4X 15 1500W 230-240V DX",
    "82341307", "NFK4T 07 750W 230-240V EX EU",
    "82341310", "NFK4T 10 1000W 230-240V EX EU",
    "82341312", "NFK4T 12 1250W 230-240V EX EU",
    "82341315", "NFK4T 15 1500W 230V EX EU",
    "82341320", "NFK4T 20 2000W 230V EX EU",
    "82420005", "NTL2N 05 500W 230-240V DX",
    "82420007", "NTL2N 07 750W 230-240V DX",
    "82420010", "NTL2N 10 1000W 230-240V DX",
    "82420012", "NTL2N 12 1250W 230-240V DX",
    "82420405", "NTL2N 05 500W 400V DX",
    "82420407", "NTL2N 07 750W 400V DX",
    "82420410", "NTL2N 10 1000W 400V DX",
    "82440002", "NTL4N 02 250W 230-240V DX",
    "82440005", "NTL4N 05 500W 230-240V DX",
    "82440007", "NTL4N 07 750W 230-240V DX",
    "82440010", "NTL4N 10 1000W 230-240V DX",
    "82440012", "NTL4N 12 1250W 230-240V DX",
    "82440015", "NTL4N 15 1500W 230-240V DX",
    "82440020", "NTL4N 20 2000W 230-240V DX",
    "82440402", "NTL4N 02 250W 400V DX",
    "82440404", "NTL4N 04 400W 400V D  (05b)",
    "82440405", "NTL4N 05 500W 400V DX",
    "82440407", "NTL4N 07 750W 400V DX",
    "82440410", "NTL4N 10 1000W 400V DX",
    "82440412", "NTL4N 12 1250W 400V DX",
    "82440605", "NTL4T 05 500W 230-240V EU EX",
    "82440607", "NTL4T 07 750W  230-240V EX EU",
    "82440610", "NTL4T 10 1000W 230-240V EX EU",
    "82440612", "NTL4T 12 1200W  230-240V EX EU",
    "82440615", "NTL4T 15 1500W 230-240V EX EU",
    "82440620", "NTL4T 20 2000W 230V EX EU",
    "82440704", "NTL4L 04 400W 230V DX (10b)",
    "82440706", "NTL4L 06 600W 230V DX (12b)",
    "82440708", "NTL4L 08 800W 230V DX (20b)",
    "82440710", "NTL4L 10 1000W 230V DX (24b)",
    "82440804", "NTL4L 04 400W 400V DX (10b)",
    "82440806", "NTL4L 06 600W 400V DX (12b)",
    "82440808", "NTL4L 08 800W 400V DX (20b)",
    "82440810", "NTL4L 10 1000W 400V  DX (24b)",
    "82440908", "NTL4Y 08 800W 230V DX  (20b)",
    "82440910", "NTL4Y 10 1000W 230V DX (24b)",
    "82441107", "NTL4S 07 750W 230-240V AUS EX",
    "82441110", "NTL4S 10 1000W 230-240V AUS EX",
    "82441115", "NTL4S 15 1500W 230-240V AUS EX",
    "82441120", "NTL4S 20 2000W 230-240V AUS EX",
    "82441124", "NTL4S 24 2400w 230-240V AUS EX",
    "82720005", "DFB2T 05 500W 230-240V Pria DX",
    "82720007", "DFB2T 07 750W 230-240V Pria DX",
    "82722105", "OFB2T 05 500W 230-240V Ahlsell DX",
    "82722107", "OFB2T 07 750W 230-240V Ahlsell DX",
    "82722110", "OFB2T 10 1000W 230-240V Ahlsell DX",
    "82722505", "OFB2T 05 500W 400V Ahlsell DX",
    "82722507", "OFB2T 07 750W 400V Ahlsell DX",
    "82722510", "OFB2T 10 1000W 400V DX Ahlsell",
    "82740005", "DFB4T 05 500W 230-240V DX Pria",
    "82740007", "DFB4T 07 750W 230-240V DX Pria",
    "82740010", "DFB4T 10 1000W 230-240V DX Pria",
    "82740012", "DFB4T 12 1250W 230-240V DX Pria",
    "82740015", "DFB4T 15 1500W 230-240V DX  Pria",
    "82742105", "OFB4T 05 500W 230-240V DX Ahlsell",
    "82742107", "OFB4T 07 750W 230-240V DX Ahlsell",
    "82742110", "OFB4T 10 1000W 230-240V DX Ahlsell",
    "82742112", "OFB4T 12 1250W 230-240V DX Ahlsell",
    "82742115", "OFB4T 15 1500W 230-240V DX Ahlsell",
    "82742505", "OFB4T 05 500W 400V DX Ahlsell",
    "82742507", "OFB4T 07 750W 400V DX Ahlsell",
    "82742510", "OFB4T 10 1000W 400V DX  Ahlsell",
    "82742512", "OFB4T 12 1250W 400V DX  Ahlsell",
    "82742515", "OFB4T 15 1500W 400V DX Ahlsell",
    "82820005", "DTD2R 05 500W 230-240V DX  WiFi Alta",
    "82820007", "DTD2R 07 750W 230-240V DX WiFi Alta",
    "82820010", "DTD2R 10 1000W 230-240V DX WiFi Alta",
    "82820610", "DTD2T 10 1000w 230-240V EU DX",
    "82822007", "OTD2T 07 750W 230-240V DX  Solar",
    "82822010", "OTD2T 10 1000W 230-240V DX Solar",
    "82840002", "DTD4R 02 250W 230-240V DX WiFi Alta",
    "82840005", "DTD4R 05 500W 230-240V DX WiFi Alta",
    "82840007", "DTD4R 07 750W 230-240V DX WiFi Alta",
    "82840010", "DTD4R 10 1000W 230-240V DX WiFi Alta",
    "82840012", "DTD4R 12 1250W 230-240V DX WiFi Alta",
    "82840605", "DTD4T 05 500w 230-240V EU  DX",
    "82840607", "DTD4T 07 750w 230-240V EU DX",
    "82840610", "DTD4T 10 1000w 230-240V EU DX",
    "82840612", "DTD4T 12 1250w 230-240V EU DX",
    "82840615", "DTD4T 15 1500w 230-240V EU DX",
    "82840620", "DTD4T 20 2000w 240V EU DX",
    "82842005", "OTD4T 05 500W 230-240V DX Solar",
    "82842007", "OTD4T 07 750W 230-240V DX Solar",
    "82842010", "OTD4T 10 1000W 230-240V Solar DX",
    "82920005", "OTJ2T 05 500W 230-240V DX Zebra",
    "82920007", "OTJ2T 07 750W 230-240V DX Zebra",
    "82920407", "OTJ2T 07 750W 400V DX Zebra",
    "82920410", "OTJ2T 10 1000W 400V DX Zebra",
    "82940005", "OTJ4T 05 500W 230-240V Zebra",
    "82940007", "OTJ4T 07 750W 230-240V Zebra",
    "82940010", "OTJ4T 10 1000W 230-240V Zebra",
    "82940012", "OTJ4T 12 1250W 230-240V Zebra",
    "82940405", "OTJ4T 05 500W 400V  Zebra",
    "82940407", "OTJ4T 07 750W 400V  Zebra",
    "82940410", "OTJ4T 10 1000W 400V  Zebra",
    "82940412", "OTJ4T 12 1250W 400V  Zebra"
)

; Build product list for DropDownList
GetProductList() {
    list := ["Visi"]
    for num, name in ProductMap {
        list.Push(num " - " name)
    }
    return list
}

; =======================================================
; GUI SŪKŪRIMAS IR KONFIGŪRACIJA
; =======================================================
MainGui := Gui("+Resize", "Testavimo logų paieška ir filtracija - Dashboard v1.0")
MainGui.SetFont("s9", "Segoe UI")

; Top controls: Path, Dates, Status, Product, Catalog
MainGui.Add("Text", "x10 y15 w110", "Serverio katalogas:")
pathEdit := MainGui.Add("Edit", "x125 y12 w560 vServerPath", ServerPath)
btnBrowse := MainGui.Add("Button", "x+5 y11 w40 h26", "...")
btnBrowse.OnEvent("Click", SelectServerDir)

MainGui.Add("Text", "x10 y48 w110", "Nuo datos:")
startMonthDate := SubStr(A_Now, 1, 6) "01000000"
dtFrom := MainGui.Add("DateTime", "x125 y45 w140 Choose" startMonthDate, "yyyy-MM-dd")

MainGui.Add("Text", "x280 y48 w70", "Iki datos:")
dtTo := MainGui.Add("DateTime", "x355 y45 w140 Choose" A_Now, "yyyy-MM-dd")

MainGui.Add("Text", "x510 y48 w60", "Būsena:")
statusChoice := MainGui.Add("DropDownList", "x575 y45 w155 Choose1", ["Visi", "Passed", "Failed"])

MainGui.Add("Text", "x10 y81 w110", "Gaminio filtras:")
prodChoice := MainGui.Add("DropDownList", "x125 y78 w605 Choose1", GetProductList())

MainGui.Add("Text", "x10 y114 w110", "Katalogo pav.:")
catEdit := MainGui.Add("Edit", "x125 y111 w300 vCatFilter", "")

btnSearch := MainGui.Add("Button", "x440 y110 w140 h28 Default", "🔍 Ieškoti")
btnSearch.SetFont("bold")
btnSearch.OnEvent("Click", PerformSearch)

btnReset := MainGui.Add("Button", "x590 y110 w140 h28", "🔄 Išvalyti")
btnReset.OnEvent("Click", ResetFilters)

; ListView Results
lvResults := MainGui.Add("ListView", "x10 y150 w960 h480 +Grid", ["#", "Data / Laikas", "Gaminio Nr.", "Gaminio Pavadinimas", "Būsena", "Katalogas", "Failo Pavadinimas"])
lvResults.ModifyCol(1, 40)
lvResults.ModifyCol(2, 130)
lvResults.ModifyCol(3, 110)
lvResults.ModifyCol(4, 280)
lvResults.ModifyCol(5, 80)
lvResults.ModifyCol(6, 140)
lvResults.ModifyCol(7, 160)

lvResults.OnEvent("DoubleClick", ShowFileDetails)

; Status bar
sbStatus := MainGui.Add("StatusBar",, "Pasiruošęs paieškai")

MainGui.OnEvent("Size", OnGuiSize)
MainGui.Show("w980 h670")

; =======================================================
; VALDYMO ĮVYKIAI IR HELPERIAI
; =======================================================

SelectServerDir(*) {
    chosen := DirSelect("*" pathEdit.Value, 3, "Pasirinkite logų serverio katalogą")
    if (chosen != "") {
        pathEdit.Value := chosen
    }
}

ResetFilters(*) {
    startMonthDate := SubStr(A_Now, 1, 6) "01000000"
    dtFrom.Value := startMonthDate
    dtTo.Value := A_Now
    statusChoice.Choose(1)
    prodChoice.Choose(1)
    catEdit.Value := ""
    lvResults.Delete()
    ResultPaths := []
    sbStatus.SetText("Filtrai išvalyti.")
}

OnGuiSize(guiObj, minMax, width, height) {
    if (minMax == -1)
        return
    lvResults.Move(10, 150, width - 20, height - 180)
}

; Parse Production ID, TimeStamp, and Test Result from JSON content
ParseJsonLogInfo(filePath, &prodNum, &logTimeStr, &statusVal) {
    prodNum := ""
    logTimeStr := ""
    statusVal := ""

    content := ""
    try {
        content := FileRead(filePath, "UTF-8")
    } catch {
        return
    }

    if (content == "")
        return

    ; 1. Production ID from JSON ("production_id": "82722105")
    if (RegExMatch(content, 'i)"production_id"\s*:\s*"(?:X-)?([A-Za-z0-9]+)"', &mProd)) {
        prodNum := mProd[1]
    } else {
        ; Fallback logic if production_id field is not present
        firstLine := StrSplit(content, "`n")[1]
        cleaned := RegExReplace(firstLine, '[\{\}"\,\:\s]')
        if (SubStr(cleaned, 1, 2) = "X-" || SubStr(cleaned, 1, 2) = "x-")
            cleaned := SubStr(cleaned, 3)
        if (RegExMatch(cleaned, "\b\d{6,9}\b", &mFallback)) {
            prodNum := mFallback[0]
        } else if (RegExMatch(content, "(?:X-)?(\d{6,9})", &mFallback2)) {
            prodNum := mFallback2[1]
        }
    }

    ; 2. Time Stamp from JSON ("time_stamp": "2026-09-25T08:05:51.117161")
    if (RegExMatch(content, 'i)"time_stamp"\s*:\s*"(\d{4})[-/](\d{2})[-/](\d{2})[T\s](\d{2}):(\d{2}):(\d{2})', &mTime)) {
        logTimeStr := mTime[1] mTime[2] mTime[3] mTime[4] mTime[5] mTime[6]
    }

    ; 3. Test Result from JSON ("test_result": "passed")
    if (RegExMatch(content, 'i)"test_result"\s*:\s*"([^"]+)"', &mRes)) {
        resRaw := StrLower(Trim(mRes[1]))
        if InStr(resRaw, "pass")
            statusVal := "Passed"
        else if InStr(resRaw, "fail")
            statusVal := "Failed"
        else
            statusVal := resRaw
    }
}

PerformSearch(*) {
    global ResultPaths

    targetDir := Trim(pathEdit.Value)
    if (!DirExist(targetDir)) {
        MsgBox("Nurodytas serverio katalogas neegzistuoja arba nepasiekiamas:`n" targetDir, "Klaida", "Iconx")
        return
    }

    ; Dates YYYYMMDD
    fromDateStr := SubStr(dtFrom.Value, 1, 8) "000000"
    toDateStr := SubStr(dtTo.Value, 1, 8) "235959"

    selectedStatus := statusChoice.Text
    selectedProdText := prodChoice.Text
    selectedProdNum := ""
    if (selectedProdText != "Visi") {
        selectedProdNum := Trim(StrSplit(selectedProdText, " - ")[1])
    }
    catFilter := Trim(catEdit.Value)

    lvResults.Delete()
    ResultPaths := []

    sbStatus.SetText("Ieškoma failų...")

    matchCount := 0
    passedCount := 0
    failedCount := 0

    Loop Files, targetDir "\*.json", "R" {
        filePath := A_LoopFileFullPath
        fileDir := A_LoopFileDir
        fileName := A_LoopFileName

        prodNum := ""
        logTimeStr := ""
        statusVal := ""

        ParseJsonLogInfo(filePath, &prodNum, &logTimeStr, &statusVal)

        ; Fallback for timestamp if missing in JSON
        if (logTimeStr == "") {
            try fileTime := FileGetTime(filePath, "M")
            catch
                fileTime := A_Now
            logTimeStr := fileTime
        }

        ; Fallback for status if missing in JSON
        if (statusVal == "") {
            if (InStr(fileDir, "\Passed") || SubStr(fileDir, -6) == "Passed" || InStr(fileDir, "Passed"))
                statusVal := "Passed"
            else if (InStr(fileDir, "\Failed") || SubStr(fileDir, -6) == "Failed" || InStr(fileDir, "Failed"))
                statusVal := "Failed"
            else
                statusVal := "Nenurodyta"
        }

        ; File timestamp check from JSON
        if (logTimeStr < fromDateStr || logTimeStr > toDateStr)
            continue

        ; Status filter check from JSON
        if (selectedStatus == "Passed" && statusVal != "Passed")
            continue
        if (selectedStatus == "Failed" && statusVal != "Failed")
            continue

        ; Catalog name filter
        if (catFilter != "" && !InStr(fileDir, catFilter))
            continue

        ; Product number extraction filter
        if (selectedProdNum != "" && prodNum != selectedProdNum)
            continue

        ; Product Name lookup
        prodName := ProductMap.Has(prodNum) ? ProductMap[prodNum] : "Nežinomas gaminys (" prodNum ")"

        if (statusVal == "Passed")
            passedCount++
        else if (statusVal == "Failed")
            failedCount++

        matchCount++
        ResultPaths.Push(filePath)

        formattedTime := FormatTime(logTimeStr, "yyyy-MM-dd HH:mm:ss")

        ; Subfolder relative catalog name
        relCatalog := RegExReplace(fileDir, "^\Q" targetDir "\E\\?", "")
        if (relCatalog == "")
            relCatalog := "\"

        lvResults.Add(, matchCount, formattedTime, prodNum, prodName, statusVal, relCatalog, fileName)
    }

    sbStatus.SetText("Paieška baigta. Rasta įrašų: " matchCount " (Passed: " passedCount ", Failed: " failedCount ")")
}

ShowFileDetails(LV, RowNum) {
    if (RowNum <= 0 || RowNum > ResultPaths.Length)
        return

    filePath := ResultPaths[RowNum]
    if (!FileExist(filePath)) {
        MsgBox("Failas nebeegzistuoja:`n" filePath, "Klaida", "Iconx")
        return
    }

    try {
        Run('notepad.exe "' filePath '"')
    } catch Error as e {
        MsgBox("Nepavyko atidaryti failo su Notepad:`n" e.Message, "Klaida", "Iconx")
    }
}

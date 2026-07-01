import re

with open('NOBO_Line_Monitor_utf8.ahk', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Pridedame Global LastProcessedTimestamp
if 'Global LastProcessedTimestamp := 0' not in content:
    content = content.replace('Global LastFileCount := -1', 'Global LastFileCount := -1\nGlobal LastProcessedTimestamp := 0')

# 2. Atnaujiname LoadSettings, kad užkrautų tstamp
if 'LastProcessedTimestamp := IniRead(IniFile, "State", Selected_Line "_LastTS", 0)' not in content:
    content = content.replace(
        'NewFilesCount := IniRead(IniFile, "State", Selected_Line "_Count", 0)',
        'NewFilesCount := IniRead(IniFile, "State", Selected_Line "_Count", 0)\n    Global LastProcessedTimestamp := IniRead(IniFile, "State", Selected_Line "_LastTS", 0)'
    )

# 3. Atnaujiname SaveState
if 'IniWrite(LastProcessedTimestamp, IniFile, "State", Selected_Line "_LastTS")' not in content:
    content = content.replace(
        'IniWrite(NewFilesCount, IniFile, "State", Selected_Line "_Count")',
        'IniWrite(NewFilesCount, IniFile, "State", Selected_Line "_Count")\n    IniWrite(LastProcessedTimestamp, IniFile, "State", Selected_Line "_LastTS")'
    )

# 4. Atnaujiname Nunulinti
content = content.replace(
    'NewFilesCount := 0',
    'NewFilesCount := 0\n    Global LastProcessedTimestamp := 0'
)

# 5. Atnaujiname TikrintiKataloga, kad atnaujintų tstamp
check_katalog_pattern = r'TikrintiKataloga\(\) \{.*?\}'
check_katalog_replacement = """TikrintiKataloga() {
    global NewFilesCount, LastFileCount, CountText, Stebimas_Katalogas, LastProcessedTimestamp
    CurrentCount := 0
    MaxTS := LastProcessedTimestamp

    Loop Files, Stebimas_Katalogas "\\*.*" {
        CurrentCount++
        try {
            ctime := FileGetTime(A_LoopFileFullPath, "C")
            if (ctime > MaxTS)
                MaxTS := ctime
        }
    }

    if (LastFileCount == -1) {
        LastFileCount := CurrentCount
        LastProcessedTimestamp := MaxTS
        return
    }

    if (CurrentCount > LastFileCount) {
        Diff := CurrentCount - LastFileCount
        NewFilesCount += Diff
        LastProcessedTimestamp := MaxTS
        Loop Diff {
            RelayPulse()
        }
        UpdateCountDisplay()
        LogCount(NewFilesCount)
        TSQueueCount(NewFilesCount)
        SaveState()
    }
    LastFileCount := CurrentCount
}"""

content = re.sub(check_katalog_pattern, check_katalog_replacement, content, flags=re.DOTALL)

# 6. Pridedame KontrolinisPatikrinimas funkciją ir taimerį
if 'KontrolinisPatikrinimas()' not in content:
    kontrolinis_logic = """
KontrolinisPatikrinimas() {
    global NewFilesCount, Stebimas_Katalogas, LastProcessedTimestamp, CountText
    MissedCount := 0
    CurrentMaxTS := LastProcessedTimestamp

    Loop Files, Stebimas_Katalogas "\\*.*" {
        try {
            ctime := FileGetTime(A_LoopFileFullPath, "C")
            ; Jei failas naujesnis nei mūsų paskutinis užfiksuotas laikas
            if (ctime > LastProcessedTimestamp) {
                MissedCount++
                if (ctime > CurrentMaxTS)
                    CurrentMaxTS := ctime
            }
        }
    }

    if (MissedCount > 0) {
        ; Tikriname ar tai nėra tas pats "TikrintiKataloga" ką tik pagautas pokytis
        ; Jei bendras failų kiekis sutampa su LastFileCount, vadinasi TikrintiKataloga dar nespėjo suveikti arba buvo klaida
        ; Bet saugiausia tiesiog pridėti skirtumą jei radome naujesnių laiko atžvilgiu failų kurių nesame matę

        ; Kadangi TikrintiKataloga bėga kas 1s, o šitas kas 2min,
        ; šita logika suveiks tik jei TikrintiKataloga kažkodėl pražiopsojo (pvz. ištrynė/pridėjo vienu metu)

        NewFilesCount += MissedCount
        LastProcessedTimestamp := CurrentMaxTS

        UpdateCountDisplay()
        LogAppend(FormatTS() " Kontrolinis patikrinimas rado praleistų failų: " MissedCount)
        TSQueueCount(NewFilesCount)
        SaveState()

        Loop MissedCount {
            RelayPulse()
        }
    }
}
"""
    content += kontrolinis_logic
    content = content.replace('SetTimer CheckExternalUpdate, 10000', 'SetTimer CheckExternalUpdate, 10000\nSetTimer KontrolinisPatikrinimas, 120000 ; Kas 2 minutes')

with open('NOBO_Line_Monitor_utf8.ahk', 'w', encoding='utf-8') as f:
    f.write(content)

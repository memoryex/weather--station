# Kaip sukurti GD_Linijos.exe

Norint sugeneruoti vieną vykdomąjį failą (.exe), reikia naudoti `PyInstaller`.

## 1. Įdiekite Python ir PyInstaller

Jei dar neturite Python:
1. Atsisiųskite ir įdiekite Python (pvz., 3.10 ar naujesnę versiją) iš python.org.
2. Diegimo metu pažymėkite varnelę **"Add Python to PATH"**.

Atsidarykite terminalą (Command Prompt arba PowerShell) ir įdiekite PyInstaller:
```bash
pip install pyinstaller
```

## 2. Sugeneruokite .exe failą

Atsisiųskite `GD_Linijos.html` ir `main.py` į vieną aplanką.
Tame aplanke atidarykite terminalą ir įvykdykite:

```bash
pyinstaller --onefile --noconsole --name "GD_Linijos" --add-data "GD_Linijos.html;." main.py
```

### Paaiškinimas:
- `--onefile`: Supakuoja viską į vieną .exe failą.
- `--noconsole`: Paslepia juodą konsolės langą paleidžiant programą.
- `--name "GD_Linijos"`: Pavadina išvesties failą `GD_Linijos.exe`.
- `--add-data "GD_Linijos.html;."`: Įtraukia HTML failą į .exe vidų (Windows sistemoje skyriklis yra `;`, Linux/Mac – `:`).

## 3. Paleidimas

Po sėkmingo generavimo, `dist` aplanke rasite `GD_Linijos.exe`.
Šis failas veiks savarankiškai, tačiau jam vis tiek reikės interneto ryšio, kad užkrautų bibliotekas (XLSX, ExcelJS) ir gautų duomenis iš ThingSpeak.

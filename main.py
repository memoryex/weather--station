import os
import webbrowser
import sys
import ctypes

def show_error(message):
    """Shows an error message. Uses a GUI message box on Windows if possible."""
    try:
        if os.name == 'nt':
            ctypes.windll.user32.MessageBoxW(0, message, "Klaida", 0x10)
        else:
            print(f"ERROR: {message}")
            if sys.stdin and sys.stdin.isatty():
                input("Press Enter to exit...")
    except Exception:
        pass # Better to exit silently than crash in the error handler

def main():
    target_file = "GD_Linijos.html"
    found_path = None

    # Locations to search for the HTML file
    search_paths = []

    # 1. Bundled location (PyInstaller --onefile)
    if hasattr(sys, '_MEIPASS'):
        search_paths.append(os.path.join(sys._MEIPASS, target_file))

    # 2. Next to the executable/script
    if getattr(sys, 'frozen', False):
        # Running as compiled exe
        exe_dir = os.path.dirname(sys.executable)
        search_paths.append(os.path.join(exe_dir, target_file))
    else:
        # Running as python script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        search_paths.append(os.path.join(script_dir, target_file))

    # Find the file
    for path in search_paths:
        if os.path.exists(path):
            found_path = path
            break

    if not found_path:
        locs_str = "\n".join(search_paths)
        show_error(f"Nepavyko rasti '{target_file}'.\nIeškota čia:\n{locs_str}")
        return

    # Open the file
    try:
        webbrowser.open(f"file://{found_path}")
    except Exception as e:
        show_error(f"Nepavyko atidaryti naršyklės:\n{e}")

if __name__ == "__main__":
    main()

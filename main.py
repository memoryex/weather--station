import os
import webbrowser
import sys

def main():
    # Get the directory where the script is running
    if getattr(sys, 'frozen', False):
        # If run as exe
        base_dir = os.path.dirname(sys.executable)
    else:
        # If run as script
        base_dir = os.path.dirname(os.path.abspath(__file__))

    html_file = os.path.join(base_dir, "GD_Linijos.html")

    if not os.path.exists(html_file):
        print(f"Error: {html_file} not found.")
        input("Press Enter to exit...")
        return

    print(f"Opening {html_file} in your default browser...")
    webbrowser.open(f"file://{html_file}")

if __name__ == "__main__":
    main()

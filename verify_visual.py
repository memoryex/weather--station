import os
import time
from playwright.sync_api import sync_playwright

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        # Capture console logs
        page.on("console", lambda msg: print(f"CONSOLE: {msg.text}"))
        page.on("pageerror", lambda err: print(f"PAGE ERROR: {err}"))

        file_path = os.path.abspath("GD_Linijos.html")
        page.goto(f"file://{file_path}")

        # Switch to Visual Tab
        print("Switching to Visual tab...")
        page.click("button[onclick=\"openTab('visual')\"]")
        time.sleep(1) # wait for fade

        tab = page.locator("#tab-visual")
        classes = tab.get_attribute("class")
        print(f"Tab classes: {classes}")

        if not tab.is_visible():
            print("Error: #tab-visual is not visible")
            exit(1)

        page.screenshot(path="/home/jules/verification/visual_tab.png")
        print("Screenshot taken.")

        browser.close()

if __name__ == "__main__":
    run()

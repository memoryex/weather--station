import os
from playwright.sync_api import sync_playwright

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        cwd = os.getcwd()
        file_path = f"file://{cwd}/report.html"

        print(f"Opening {file_path}")
        try:
            page.goto(file_path)
            page.wait_for_selector("#lineFilter option", timeout=5000)
        except Exception as e:
            print(f"Failed to load: {e}")
            return

        # Screenshot the checkbox area
        screenshot_path = "/home/jules/verification/report_checkbox_final.png"

        # Locate the card or the specific div to screenshot
        card = page.locator(".card").first
        if card.count() > 0:
            card.screenshot(path=screenshot_path)
        else:
            page.screenshot(path=screenshot_path)

        print(f"Screenshot saved to {screenshot_path}")
        browser.close()

if __name__ == "__main__":
    run()

import os
from playwright.sync_api import sync_playwright

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        cwd = os.getcwd()
        file_path = f"file://{cwd}/GD_Linijos.html"

        print(f"Opening {file_path}")
        try:
            page.goto(file_path)
            # Wait for any tab button
            page.wait_for_selector(".tab-btn", timeout=5000)
        except Exception as e:
            print(f"Failed to load: {e}")
            return

        # Screenshot the tab navigation bar
        screenshot_path = "/home/jules/verification/gd_tabs_renamed.png"

        # Locate the nav
        nav = page.locator(".tab-nav").first
        if nav.count() > 0:
            nav.screenshot(path=screenshot_path)
        else:
            page.screenshot(path=screenshot_path)

        print(f"Screenshot saved to {screenshot_path}")

        # Verify text
        btn_text = page.locator("button[onclick=\"openTab('ai')\"]").inner_text()
        print(f"AI Button Text: '{btn_text}'")

        browser.close()

if __name__ == "__main__":
    run()

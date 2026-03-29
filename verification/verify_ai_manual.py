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
            # Wait for tab buttons
            page.wait_for_selector(".tab-btn", timeout=5000)
        except Exception as e:
            print(f"Failed to load: {e}")
            return

        # Click AI tab
        page.click("button[onclick=\"openTab('ai')\"]")

        # Verify Manual Config Section exists
        section = page.locator("text=Pertraukų grafikas (Mokymui)")
        if section.count() > 0:
            print("PASS: Manual configuration section found.")
        else:
            print("FAIL: Manual configuration section not found.")

        # Verify expanded table height
        # We can check the style attribute or visual
        table_div = page.locator("#aiProductTable").locator("xpath=..")
        style = table_div.get_attribute("style")
        if "max-height:600px" in style.replace(" ", ""):
             print("PASS: Table max-height is 600px.")
        else:
             print(f"FAIL: Table style is {style}")

        # Screenshot the AI tab
        screenshot_path = "/home/jules/verification/gd_ai_manual_config.png"
        page.screenshot(path=screenshot_path)
        print(f"Screenshot saved to {screenshot_path}")

        browser.close()

if __name__ == "__main__":
    run()

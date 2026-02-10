import os
import sys
from playwright.sync_api import sync_playwright

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        # Determine absolute path to report.html
        cwd = os.getcwd()
        file_path = f"file://{cwd}/report.html"

        print(f"Opening {file_path}")
        try:
            page.goto(file_path)
            # Wait for JS to run (options are populated by JS)
            page.wait_for_selector("#lineFilter option", timeout=5000)
        except Exception as e:
            print(f"Failed to load page or wait for options: {e}")
            return

        # Verify Checkbox is checked
        checkbox = page.locator("#selectAllLines")
        is_checked = checkbox.is_checked()
        print(f"Checkbox checked: {is_checked}")

        # Verify Options are selected
        options = page.locator("#lineFilter option")
        count = options.count()
        print(f"Found {count} options")

        if count == 0:
            print("Error: No options found in select list!")

        all_selected = True
        for i in range(count):
            is_sel = options.nth(i).evaluate("el => el.selected")
            if not is_sel:
                all_selected = False
                print(f"Option {i} is not selected")

        print(f"All options selected: {all_selected}")

        # Screenshot
        screenshot_path = "/home/jules/verification/report_checkbox.png"
        page.screenshot(path=screenshot_path)
        print(f"Screenshot saved to {screenshot_path}")

        browser.close()

if __name__ == "__main__":
    run()

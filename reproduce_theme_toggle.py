from playwright.sync_api import sync_playwright
import os
import time

def reproduce_theme_toggle_issue():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Load local file
        file_path = os.path.abspath("GD_Linijos.html")
        page.goto(f"file://{file_path}")

        print("Page loaded.")

        # Check initial state
        has_light = page.locator("body").evaluate("el => el.classList.contains('light-mode')")
        print(f"Initial State: Light Mode = {has_light}")

        # Click Toggle Button
        toggle_btn = page.locator("#themeToggle")
        toggle_btn.click()
        print("Clicked Theme Toggle (1st time).")

        # Check immediate state
        has_light_1 = page.locator("body").evaluate("el => el.classList.contains('light-mode')")
        print(f"State 1: Light Mode = {has_light_1}")

        # Try rapid click (should be ignored by debounce)
        toggle_btn.click()
        print("Clicked Theme Toggle (rapidly).")

        has_light_2 = page.locator("body").evaluate("el => el.classList.contains('light-mode')")
        print(f"State 2 (should be same): Light Mode = {has_light_2}")

        if has_light_1 != has_light_2:
             print("WARNING: Rapid click toggled state! Debounce failed?")
        else:
             print("Rapid click ignored (Debounce working).")

        # Wait > 500ms
        time.sleep(1)

        # Click again to toggle back
        toggle_btn.click()
        print("Clicked Theme Toggle (after wait).")
        has_light_3 = page.locator("body").evaluate("el => el.classList.contains('light-mode')")
        print(f"State 3 (should be toggled): Light Mode = {has_light_3}")

        browser.close()

if __name__ == "__main__":
    try:
        reproduce_theme_toggle_issue()
    except Exception as e:
        print(f"Test Error: {e}")

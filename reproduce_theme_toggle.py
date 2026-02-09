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

        # Check initial state (should be dark mode by default unless saved)
        # We can check body class
        has_light = page.locator("body").evaluate("el => el.classList.contains('light-mode')")
        print(f"Initial State: Light Mode = {has_light}")

        # Click Toggle Button
        toggle_btn = page.locator("#themeToggle")
        toggle_btn.click()
        print("Clicked Theme Toggle.")

        # Check immediate state
        has_light = page.locator("body").evaluate("el => el.classList.contains('light-mode')")
        print(f"Immediate Post-Click State: Light Mode = {has_light}")

        if not has_light:
            print("ERROR: Light mode not applied immediately.")

        # Wait 5 seconds (to check for revert)
        print("Waiting 5 seconds...")
        time.sleep(5)

        # Check state again
        has_light_after = page.locator("body").evaluate("el => el.classList.contains('light-mode')")
        print(f"State after 5s: Light Mode = {has_light_after}")

        if has_light and not has_light_after:
            print("REPRODUCED: Theme reverted to dark mode!")
        elif has_light and has_light_after:
            print("Not Reproduced: Theme remained light.")
        else:
            print("Inconclusive state.")

        browser.close()

if __name__ == "__main__":
    try:
        reproduce_theme_toggle_issue()
    except Exception as e:
        print(f"Test Error: {e}")

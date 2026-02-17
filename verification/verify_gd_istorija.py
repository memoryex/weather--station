from playwright.sync_api import sync_playwright
import os

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Load the file
        filepath = os.path.abspath("GD_istorija.html")
        page.goto(f"file://{filepath}")

        print("Page loaded.")

        # Check checkbox exists
        chk = page.locator("#selectAllLines")
        if chk.count() == 0:
            print("FAIL: Checkbox #selectAllLines not found.")
            browser.close()
            return

        print("Checkbox found.")

        # Verify default state: Checked
        if not chk.is_checked():
            print("FAIL: Checkbox should be checked by default.")
        else:
            print("PASS: Checkbox is checked by default.")

        # Verify all options selected
        options = page.locator("#lineFilter option")
        count = options.count()
        print(f"Found {count} options.")

        all_selected = True
        for i in range(count):
            # ElementHandle approach for multi-select checking
            opt = options.nth(i)
            # Evaluate property 'selected'
            is_sel = opt.evaluate("el => el.selected")
            if not is_sel:
                all_selected = False
                break

        if not all_selected:
            print("FAIL: All options should be selected by default.")
        else:
            print("PASS: All options selected by default.")

        # Uncheck "Select All"
        chk.uncheck()
        print("Unchecked 'Select All'.")

        # Verify all deselected
        any_selected = False
        for i in range(count):
            opt = options.nth(i)
            is_sel = opt.evaluate("el => el.selected")
            if is_sel:
                any_selected = True
                break

        if any_selected:
            print("FAIL: All options should be deselected.")
        else:
            print("PASS: All options deselected.")

        # Check "Select All" again
        chk.check()
        print("Checked 'Select All' again.")

        # Verify all selected
        all_selected = True
        for i in range(count):
            opt = options.nth(i)
            is_sel = opt.evaluate("el => el.selected")
            if not is_sel:
                all_selected = False
                break

        if not all_selected:
            print("FAIL: All options should be selected again.")
        else:
            print("PASS: All options selected again.")

        # Uncheck one option manually
        # Since it is a multi-select, clicking an option without Ctrl might deselect others depending on browser behavior,
        # but usually with 'multiple', clicking toggles or selects only one.
        # Playwright's select_option on multiple select replaces selection unless updated.
        # Let's use evaluate to simulate user deselecting one option while keeping others?
        # Or just use select_option to select all BUT one.

        # Let's try just unselecting the first one via JS to be safe about exact behavior simulation
        page.evaluate("document.getElementById('lineFilter').options[0].selected = false")
        # Trigger change event manually because setting property doesn't trigger it
        page.evaluate("document.getElementById('lineFilter').dispatchEvent(new Event('change'))")
        print("Unselected first option manually.")

        # Check logic: Checkbox should be unchecked now
        if chk.is_checked():
             print("FAIL: Checkbox should be unchecked when one option is deselected.")
        else:
             print("PASS: Checkbox unchecked correctly.")

        # Take screenshot
        page.screenshot(path="verification/gd_istorija_verified.png")
        print("Screenshot saved to verification/gd_istorija_verified.png")

        browser.close()

if __name__ == "__main__":
    run()

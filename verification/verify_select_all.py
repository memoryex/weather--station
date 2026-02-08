import os
from playwright.sync_api import sync_playwright

def run(playwright):
    browser = playwright.chromium.launch(headless=True)
    page = browser.new_page()

    # Load the local HTML file
    cwd = os.getcwd()
    file_path = f"file://{cwd}/GD_Linijos.html"
    print(f"Loading: {file_path}")
    page.goto(file_path)

    # 1. Open the "Report" tab
    print("Clicking Report tab...")
    # The tab button text is "Istorijos ataskaita"
    page.click("button:has-text('Istorijos ataskaita')")

    # Wait for the tab content to be visible
    page.wait_for_selector("#tab-report.active")

    # 2. Check initial state
    checkbox = page.locator("#selectAllLines")
    line_filter = page.locator("#lineFilter")

    print("Verifying initial state...")
    # Checkbox should be unchecked
    assert not checkbox.is_checked(), "Checkbox should be unchecked initially"

    # No options should be selected (or check specifically)
    selected_count = page.evaluate("document.getElementById('lineFilter').selectedOptions.length")
    assert selected_count == 0, f"Expected 0 selected lines, got {selected_count}"

    # 3. Click "Select All"
    print("Clicking Select All...")
    checkbox.check()

    # Verify all options are selected
    total_options = page.evaluate("document.getElementById('lineFilter').options.length")
    selected_count = page.evaluate("document.getElementById('lineFilter').selectedOptions.length")
    print(f"Total options: {total_options}, Selected: {selected_count}")
    assert selected_count == total_options, "Not all options were selected!"
    assert total_options > 0, "No options found in lineFilter!"

    # Take screenshot of the selected state
    page.screenshot(path="verification/select_all_checked.png")

    # 4. Uncheck "Select All"
    print("Unchecking Select All...")
    checkbox.uncheck()

    # Verify no options are selected
    selected_count = page.evaluate("document.getElementById('lineFilter').selectedOptions.length")
    assert selected_count == 0, "Options should be deselected!"

    # Take screenshot of the unchecked state
    page.screenshot(path="verification/select_all_unchecked.png")

    print("Verification successful!")
    browser.close()

with sync_playwright() as playwright:
    run(playwright)

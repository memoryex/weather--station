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
    page.click("button:has-text('Istorijos ataskaita')")
    page.wait_for_selector("#tab-report.active")

    # 2. Check #chartLines attributes
    print("Checking #chartLines style...")
    chart_lines = page.locator("#chartLines")
    size_attr = chart_lines.get_attribute("size")
    style_attr = chart_lines.get_attribute("style")

    print(f"Size attribute: {size_attr}")
    print(f"Style attribute: {style_attr}")

    if size_attr != "4":
        print("WARNING: size attribute is not 4")
    if "height:auto" not in style_attr:
        print("WARNING: height:auto not found in style")

    # 3. Check Chart Type selector
    print("Checking #chartType selector...")
    chart_type = page.locator("#chartType")
    assert chart_type.is_visible(), "Chart Type selector not visible!"

    options = chart_type.locator("option").all_inner_texts()
    print(f"Chart Type Options: {options}")
    assert "Bar (Horizontal)" in options, "Bar option missing!"

    # 4. Change Chart Type
    print("Selecting 'bar' chart type...")
    chart_type.select_option("bar")

    # 5. Take screenshot
    page.screenshot(path="verification/chart_ui_verification.png")
    print("Screenshot saved to verification/chart_ui_verification.png")

    browser.close()

with sync_playwright() as playwright:
    run(playwright)

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

    # 2. Check "Select All" for Chart
    print("Checking Select All functionality for Chart...")
    select_all_chart = page.locator("#selectAllChartLines")
    chart_lines = page.locator("#chartLines")

    # Ensure unchecked initially
    assert not select_all_chart.is_checked()
    selected_count = page.evaluate("document.getElementById('chartLines').selectedOptions.length")
    assert selected_count == 0

    # Check it
    select_all_chart.check()
    total_options = page.evaluate("document.getElementById('chartLines').options.length")
    selected_count = page.evaluate("document.getElementById('chartLines').selectedOptions.length")
    print(f"Selected: {selected_count} / {total_options}")
    assert selected_count == total_options

    # Uncheck it
    select_all_chart.uncheck()
    selected_count = page.evaluate("document.getElementById('chartLines').selectedOptions.length")
    assert selected_count == 0

    # 3. Check "Cumulative" toggle presence and default
    print("Checking Cumulative toggle...")
    cumulative_toggle = page.locator("#chartCumulative")
    assert cumulative_toggle.is_visible()
    assert not cumulative_toggle.is_checked() # Should be unchecked by default per plan

    # 4. Take UI Screenshot
    page.screenshot(path="verification/chart_controls_updated.png")
    print("UI Screenshot saved.")

    browser.close()

with sync_playwright() as playwright:
    run(playwright)

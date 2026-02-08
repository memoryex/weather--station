import os
import time
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

    # 2. Select lines for the chart
    print("Selecting lines for chart...")
    # Select NOBO 7 as a test case (known data source in previous traces)
    page.select_option("#chartLines", ["NOBO 7"])

    # 3. Set a wide date range to ensure we get some data (default is today 00:00 to now)
    # Let's trust the default range first, or set it if needed.
    # The default JS sets it to today. Let's try to set it to last 30 days to be sure.

    # 4. Click "Update Chart"
    print("Clicking Update Chart...")
    page.click("#updateChartBtn")

    # 5. Wait for status update
    print("Waiting for chart update...")
    # Status changes from "Kraunami duomenys..." to "Grafikas atnaujintas." or "Klaida..."
    # We wait for the specific success message or a timeout
    try:
        page.wait_for_function("document.getElementById('chartStatus').textContent.includes('Grafikas atnaujintas') || document.getElementById('chartStatus').textContent.includes('Klaida') || document.getElementById('chartStatus').textContent.includes('Nėra duomenų')", timeout=10000)
    except:
        print("Timeout waiting for chart status update.")

    status = page.text_content("#chartStatus")
    print(f"Final Chart Status: {status}")

    # 6. Take screenshot
    page.screenshot(path="verification/chart_update_test.png")

    # 7. Check debug log if available (it's hidden but we can read text)
    debug_text = page.text_content("#debugLog")
    print("Debug Log Content (first 500 chars):")
    print(debug_text[:500])

    browser.close()

with sync_playwright() as playwright:
    run(playwright)

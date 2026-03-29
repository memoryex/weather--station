import os
from playwright.sync_api import sync_playwright

def verify(page, file_path, screenshot_path):
    print(f"Loading {file_path}")
    page.goto(f"file://{file_path}")
    page.wait_for_load_state("networkidle")

    # Click beta tab
    print("Switching to beta tab...")
    page.click("button[onclick=\"openTab('ai')\"]")
    page.wait_for_timeout(1000)

    # Take screenshot
    page.screenshot(path=screenshot_path, full_page=True)
    print(f"Screenshot saved to {screenshot_path}")

def run():
    cwd = os.getcwd()
    gd_path = os.path.join(cwd, "GD_Linijos.html")

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1920, "height": 1080})

        # Verify GD_Linijos beta Tab
        verify(page, gd_path, "verification/gd_beta.png")

        browser.close()

if __name__ == "__main__":
    run()

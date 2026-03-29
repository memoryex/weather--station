import os
from playwright.sync_api import sync_playwright

def verify(page, file_path, screenshot_path):
    print(f"Loading {file_path}")
    page.goto(f"file://{file_path}")
    page.wait_for_load_state("networkidle")

    # Take screenshot
    page.screenshot(path=screenshot_path, full_page=True)
    print(f"Screenshot saved to {screenshot_path}")

def run():
    cwd = os.getcwd()
    gd_path = os.path.join(cwd, "GD_Linijos.html")
    report_path = os.path.join(cwd, "report.html")

    with sync_playwright() as p:
        browser = p.chromium.launch()
        # Viewport large enough to see everything
        page = browser.new_page(viewport={"width": 1920, "height": 1080})

        # 1. Verify GD_Linijos Status Tab
        verify(page, gd_path, "verification/gd_status.png")

        # 2. Verify GD_Linijos Visualization Tab
        # Click the tab button
        print("Switching to Visual tab...")
        page.click("button[onclick=\"openTab('visual')\"]")
        page.wait_for_timeout(1000) # Wait for tab switch animation
        page.screenshot(path="verification/gd_viz.png", full_page=True)
        print("Screenshot saved to verification/gd_viz.png")

        # 3. Verify Report HTML
        verify(page, report_path, "verification/report.png")

        browser.close()

if __name__ == "__main__":
    run()

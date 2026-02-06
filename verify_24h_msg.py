from playwright.sync_api import sync_playwright
import json
import os
from datetime import datetime, timedelta

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Mock API responses
        def handle_route(route):
            url = route.request.url
            now = datetime.utcnow()

            # PLXE 1 is channel 463450
            if "463450" in url:
                # Make it OLD (25 hours ago)
                old_time = (now - timedelta(hours=25)).isoformat() + "Z"

                if "last.json" in url:
                    data = {
                        "created_at": old_time,
                        "field1": "100", # Count
                        "field2": "090775", # Barcode
                        "field3": "10",
                        "field4": "090775",
                        "field5": "10",
                        "field6": "090775",
                        "field7": "10",
                        "field8": "090775"
                    }
                    route.fulfill(status=200, body=json.dumps(data))
                else:
                    # History request
                    feeds = []
                    # Create some old feeds
                    for i in range(5):
                        t = (now - timedelta(hours=25, minutes=i*10)).isoformat() + "Z"
                        feeds.append({
                            "created_at": t,
                            "field1": str(100 + i),
                            "field2": "090775",
                            "field3": str(100 + i),
                            "field4": "090775",
                            "field5": str(100 + i),
                            "field6": "090775",
                            "field7": str(100 + i),
                            "field8": "090775"
                        })
                    route.fulfill(status=200, body=json.dumps({"channel": {}, "feeds": feeds}))

            elif "thingspeak.com" in url:
                # Other channels - Recent data
                recent_time = now.isoformat() + "Z"
                if "last.json" in url:
                    data = {
                        "created_at": recent_time,
                        "field1": "50",
                        "field2": "090775",
                        "field3": "50",
                        "field4": "090775",
                        "field5": "50",
                        "field6": "090775",
                        "field7": "50",
                        "field8": "090775"
                    }
                    route.fulfill(status=200, body=json.dumps(data))
                else:
                    # History
                    feeds = []
                    for i in range(5):
                        t = (now - timedelta(minutes=i*10)).isoformat() + "Z"
                        feeds.append({
                            "created_at": t,
                            "field1": str(50 + i),
                            "field2": "090775",
                            "field3": str(50 + i),
                            "field4": "090775",
                            "field5": str(50 + i),
                            "field6": "090775",
                            "field7": str(50 + i),
                            "field8": "090775"
                        })
                    route.fulfill(status=200, body=json.dumps({"channel": {}, "feeds": feeds}))
            else:
                route.continue_()

        page.route("**/*", handle_route)

        cwd = os.getcwd()
        page.goto(f"file://{cwd}/GD_Linijos.html")

        # Wait for data
        page.wait_for_selector("table", timeout=5000)
        page.wait_for_timeout(2000) # Wait for refresh async calls

        content = page.content()
        target_text = "Nėra naujų duomenų >24h"

        if target_text in content:
            print("SUCCESS: Found warning text.")
            # Verify it's for PLXE 1 (optional, but good)
        else:
            print("FAILURE: Warning text not found.")

        browser.close()

if __name__ == "__main__":
    run()

import json

def update_hipot():
    # Use the filtered DTD4R file as base
    with open('DTD4R_750W_Safety_Power_MinBLE.json', 'r') as f:
        data = json.load(f)

    # 1. Update Step 517 (High Potential)
    # Target: 2500 V
    # Low: 0.250 mA (was 0.350)
    # High: 35.000 mA
    # Ramp Up: 5
    # Hold: 15
    # Ramp Down: 5

    new_hipot = {
        "step_id": "517",
        "test_name": "High Potential",
        "test_description": "High Potential Flash Test",
        "test_type": "NEW_HAL",
        "test_subtype": "safety",
        "test_delay": "0",
        "test_visible": "1",
        "test_underline": "0",
        "test_params": {
            "start_request": "1",
            "target": "2500",
            "ramp_up": "5",
            "hold": "15",
            "low_limit": "0.250",
            "high_limit": "35.000",
            "measure_string": "Leakage",
            "unit": "mA",
            "channel": "1",
            "arc_detect": "0",
            "ramp_down": "5",
            "write": "1",
            "read": "1",
            "id": "22"
        }
    }

    tests = data['data']['tests']
    updated_tests = []

    for test in tests:
        if test['step_id'] == "517":
            updated_tests.append(new_hipot)
        else:
            updated_tests.append(test)

    data['data']['tests'] = updated_tests

    # 2. Save as 7502300.json (replacing previous)
    with open('7502300.json', 'w') as f:
        json.dump(data, f, indent=4)

    print("Updated Step 517 and saved as 7502300.json")

if __name__ == "__main__":
    update_hipot()

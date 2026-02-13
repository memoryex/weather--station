import json

def filter_json():
    with open('hsdp.json', 'r') as f:
        data = json.load(f)

    original_tests = data['data']['tests']
    new_tests = []

    # Define the specific step IDs or names to keep
    # Based on analysis:
    # 1545: Earth Bond
    # 1546: High Potential
    # 1547: DCIR
    # 1548: Product Start (Appliance On)
    # 1550: BLE Discovery (Essential for connection)
    # 1551: BLE Connection (Essential for control)
    # 1556: TRIAC On (Heater On)
    # 1557: Current Test (Power Check - Heater On)
    # 1558: TRIAC Off (Heater Off)
    # 1559: Current Test (Power Check - Standby)
    # 1578: Product Stop (Appliance Off)

    keep_ids = [
        "1545", "1546", "1547", "1548",
        "1550", "1551",
        "1556", "1557",
        "1558", "1559",
        "1578"
    ]

    for test in original_tests:
        if test['step_id'] in keep_ids:
            new_tests.append(test)

    # Update the data structure
    data['data']['tests'] = new_tests
    data['data']['test_script_name'] += "_Safety_Power_MinBLE"

    # Save to new file
    with open('HSDP1000_Safety_Power_MinBLE.json', 'w') as f:
        json.dump(data, f, indent=4)

    print(f"Filtered JSON saved. Kept {len(new_tests)} tests.")

if __name__ == "__main__":
    filter_json()

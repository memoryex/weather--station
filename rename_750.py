import json

def modify_json():
    filename = 'HSDP1000_Safety_Power_MinBLE.json'
    with open(filename, 'r') as f:
        data = json.load(f)

    # 1. Update Script Name
    data['data']['test_script_name'] = "750W/230V no earth"
    data['data']['product'] = "750W NO EARTH" # Also update product field for clarity

    tests = data['data']['tests']
    new_tests = []

    for test in tests:
        # 2. Remove Earth Bond (Step 1545)
        if test['step_id'] == "1545":
            print("Removed Step 1545: Earth Bond (per 'no earth' request)")
            continue

        # 3. Update Power Limits (Step 1557)
        if test['step_id'] == "1557": # Current Test / Power
            print(f"Updating Power Test (Step 1557) limits from {test['test_params']['low_limit']}-{test['test_params']['high_limit']} to 0.675-0.825 kW")
            test['test_params']['low_limit'] = "0.675"
            test['test_params']['high_limit'] = "0.825"

        new_tests.append(test)

    data['data']['tests'] = new_tests

    # 4. Save as 7502300.json
    output_filename = '7502300.json'
    with open(output_filename, 'w') as f:
        json.dump(data, f, indent=4)

    print(f"Saved modified JSON to {output_filename}")

if __name__ == "__main__":
    modify_json()

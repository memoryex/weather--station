import json

def filter_dtd4r():
    with open('dtd4r_raw.json', 'r') as f:
        data = json.load(f)

    original_tests = data['data']['tests']
    new_tests = []

    # Keep:
    # 517: High Potential (Safety)
    # 518: DCIR (Safety)
    # 519: Product Start (Power)
    # 521: BLE Discovery (BLE Infra)
    # 522: BLE Connection (BLE Infra)
    # 527: TRIAC On (BLE Control)
    # 528: Current Test (Power Measure)
    # 529: TRIAC Off (BLE Control)
    # 530: Current Test (Power Measure - Off)
    # 536: Product Stop (Power)

    keep_ids = [
        "517", "518", "519",
        "521", "522",
        "527", "528",
        "529", "530",
        "536"
    ]

    for test in original_tests:
        if test['step_id'] in keep_ids:
            new_tests.append(test)

    # Update the data structure
    data['data']['tests'] = new_tests
    data['data']['test_script_name'] += "_Safety_Power_MinBLE"

    # Save to new file
    with open('DTD4R_750W_Safety_Power_MinBLE.json', 'w') as f:
        json.dump(data, f, indent=4)

    print(f"Filtered DTD4R JSON saved. Kept {len(new_tests)} tests.")

if __name__ == "__main__":
    filter_dtd4r()

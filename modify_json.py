import json

filepath = '7502300.json'

with open(filepath, 'r') as f:
    data = json.load(f)

tests = data['data']['tests']

# 1. Remove SEGMENT OCR (id 31)
# Find step with test_name 'SEGMENT OCR'
ocr_index = -1
for i, test in enumerate(tests):
    if test.get('test_name') == 'SEGMENT OCR':
        ocr_index = i
        break

if ocr_index != -1:
    print(f"Removing SEGMENT OCR at index {ocr_index}")
    del tests[ocr_index]

# 2. Update BLE Discovery (id 32)
# Find step with test_name 'BLE Discovery'
discovery_step = None
for test in tests:
    if test.get('test_name') == 'BLE Discovery':
        discovery_step = test
        break

if discovery_step:
    print("Updating BLE Discovery")
    discovery_step['test_delay'] = "10"
    # Add target parameters
    if 'test_params' not in discovery_step:
        discovery_step['test_params'] = {}
    discovery_step['test_params']['target_name'] = "PH3312"
    discovery_step['test_params']['target_id'] = "12" # Also try this
    discovery_step['test_params']['id'] = "32" # Ensure ID is preserved

# 3. Add Disable EOLT (id 98)
# Create the step object
disable_eolt = {
    "step_id": "535", # Arbitrary ID before stop
    "test_name": "Disable EOLT",
    "test_description": "Exit Factory Test Mode",
    "test_type": "BLE",
    "test_subtype": "EXIT_EOLT",
    "test_delay": "0",
    "test_visible": "1",
    "test_underline": "1",
    "test_params": {
        "ble_characteristic": "00001010-0000-1000-8000-00805f9b34fb",
        "write_to_read": "0",
        "reset_hal": "0",
        "check_single_byte_index": "",
        "low_value": "0.000",
        "high_value": "0.000",
        "ble_value": {"data": [71]},
        "write": "1",
        "read": "0",
        "christening_function": "",
        "result_comparison": "",
        "id": "98"
    }
}

# Insert before Product Stop (id 100)
stop_index = -1
for i, test in enumerate(tests):
    if test.get('test_name') == 'Product Stop':
        stop_index = i
        break

if stop_index != -1:
    print(f"Inserting Disable EOLT before Product Stop at index {stop_index}")
    tests.insert(stop_index, disable_eolt)
else:
    print("Product Stop not found, appending Disable EOLT")
    tests.append(disable_eolt)

# Renumber step_ids sequentially starting from 517 (first step ID in original)
# Original first step ID was 517.
current_id = 517
for test in tests:
    test['step_id'] = str(current_id)
    current_id += 1

# Write back
data['data']['tests'] = tests
with open(filepath, 'w') as f:
    json.dump(data, f, indent=4)

print("Done")

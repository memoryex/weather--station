#!/usr/bin/env python3
"""
OpenCV 7-Segment LED & Character Recognition Helper for AutoHotkey ID Monitor
Usage:
  1. Standalone watcher service: python led_ocr.py --watch
  2. Single file execution:     python led_ocr.py <image_path>
"""

import sys
import os
import time
import tempfile

# Print startup header
print("============================================================")
print("  7-Segment LED OCR Python Helper Service (v2.2)")
print("============================================================")

try:
    import cv2
    import numpy as np
    print("[INFO] OpenCV and NumPy successfully loaded.")
except ImportError as e:
    print(f"[ERROR] Required Python module missing: {e}")
    print("[INSTRUCTION] Please install dependencies using: pip install opencv-python numpy")

# Standard 7-segment display digit/letter lookup map
# Segments order: (top, top-left, top-right, middle, bottom-left, bottom-right, bottom)
DIGIT_MAP = {
    (1, 1, 1, 0, 1, 1, 1): "0",
    (0, 0, 1, 0, 0, 1, 0): "1",
    (1, 0, 1, 1, 1, 0, 1): "2",
    (1, 0, 1, 1, 0, 1, 1): "3",
    (0, 1, 1, 1, 0, 1, 0): "4",
    (1, 1, 0, 1, 0, 1, 1): "5",
    (1, 1, 0, 1, 1, 1, 1): "6",
    (1, 0, 1, 0, 0, 1, 0): "7",
    (1, 1, 1, 1, 1, 1, 1): "8",
    (1, 1, 1, 1, 0, 1, 1): "9",
    (1, 1, 1, 1, 1, 1, 0): "A",
    (0, 1, 0, 1, 1, 1, 1): "B",
    (1, 1, 0, 0, 1, 0, 1): "C",
    (0, 0, 1, 1, 1, 1, 1): "D",
    (1, 1, 0, 1, 1, 0, 1): "E",
    (1, 1, 0, 1, 1, 0, 0): "F",
    (0, 1, 1, 1, 1, 1, 0): "H",
    (0, 0, 0, 1, 1, 1, 1): "t",
    (0, 1, 0, 1, 1, 0, 0): "r",
    (0, 1, 1, 0, 1, 1, 0): "U",
    (0, 1, 1, 1, 1, 0, 0): "P",
    (0, 1, 0, 1, 1, 0, 1): "n",
    (0, 0, 1, 0, 1, 0, 0): "i",
    (0, 1, 0, 0, 1, 0, 0): "l",
}

def decode_7segment(roi):
    """
    Decodes a single 7-segment digit/letter box using segment intensity checks.
    """
    h, w = roi.shape[:2]
    if h < 8 or w < 4:
        return ""

    # Segment sampling bounding boxes (y_start, y_end, x_start, x_end)
    segments = [
        (0, int(h * 0.25), int(w * 0.2), int(w * 0.8)),         # Top
        (int(h * 0.1), int(h * 0.5), 0, int(w * 0.35)),         # Top-Left
        (int(h * 0.1), int(h * 0.5), int(w * 0.65), w),         # Top-Right
        (int(h * 0.4), int(h * 0.6), int(w * 0.2), int(w * 0.8)), # Middle
        (int(h * 0.5), int(h * 0.9), 0, int(w * 0.35)),         # Bottom-Left
        (int(h * 0.5), int(h * 0.9), int(w * 0.65), w),         # Bottom-Right
        (int(h * 0.75), h, int(w * 0.2), int(w * 0.8)),         # Bottom
    ]

    on_segments = []
    for (y1, y2, x1, x2) in segments:
        seg_roi = roi[y1:y2, x1:x2]
        if seg_roi.size == 0:
            on_segments.append(0)
            continue
        total_pixels = seg_roi.size
        active_pixels = cv2.countNonZero(seg_roi)
        ratio = active_pixels / total_pixels
        on_segments.append(1 if ratio > 0.35 else 0)

    pattern = tuple(on_segments)
    if pattern in DIGIT_MAP:
        return DIGIT_MAP[pattern]

    # Fuzzy segment fallback
    best_char = ""
    min_diff = 8
    for seg_pat, char_val in DIGIT_MAP.items():
        diff = sum(abs(a - b) for a, b in zip(on_segments, seg_pat))
        if diff < min_diff and diff <= 1:
            min_diff = diff
            best_char = char_val

    return best_char

# Global cached TensorFlow / TFLite / OpenCV DNN model handle
_TF_MODEL = None
_TF_TYPE = None  # 'tflite', 'tf', 'onnx_dnn'
_CLASSES = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "H", "I", "N", "P", "R", "U"]

def load_tf_dnn_model():
    """
    Attempts to load a TensorFlow / TFLite or ONNX model if present in script directory.
    Supported model filenames: model.tflite, model.onnx, model.h5, model.pb
    """
    global _TF_MODEL, _TF_TYPE
    if _TF_TYPE is not None:
        return _TF_MODEL, _TF_TYPE

    script_dir = os.path.dirname(os.path.realpath(__file__))
    tflite_path = os.path.join(script_dir, "model.tflite")
    onnx_path = os.path.join(script_dir, "model.onnx")
    h5_path = os.path.join(script_dir, "model.h5")

    # 1. Try TFLite
    if os.path.exists(tflite_path):
        try:
            try:
                import tflite_runtime.interpreter as tflite
                interpreter = tflite.Interpreter(model_path=tflite_path)
            except ImportError:
                import tensorflow.lite as tflite
                interpreter = tflite.Interpreter(model_path=tflite_path)
            interpreter.allocate_tensors()
            _TF_MODEL = interpreter
            _TF_TYPE = "tflite"
            return _TF_MODEL, _TF_TYPE
        except Exception:
            pass

    # 2. Try OpenCV DNN ONNX
    if os.path.exists(onnx_path):
        try:
            net = cv2.dnn.readNetFromONNX(onnx_path)
            _TF_MODEL = net
            _TF_TYPE = "onnx_dnn"
            return _TF_MODEL, _TF_TYPE
        except Exception:
            pass

    # 3. Try Full TensorFlow Keras Model
    if os.path.exists(h5_path):
        try:
            import tensorflow as tf
            model = tf.keras.models.load_model(h5_path)
            _TF_MODEL = model
            _TF_TYPE = "tf"
            return _TF_MODEL, _TF_TYPE
        except Exception:
            pass

    _TF_TYPE = "none"
    return None, "none"

def classify_digit_tf_dnn(roi):
    """
    Classifies a 7-segment digit ROI using loaded TensorFlow / TFLite / ONNX model.
    Falls back to geometric 7-segment decoding.
    """
    model, model_type = load_tf_dnn_model()

    if model_type != "none" and model is not None:
        try:
            gray_roi = cv2.resize(roi, (28, 28))
            norm_roi = gray_roi.astype("float32") / 255.0

            if model_type == "tflite":
                input_details = model.get_input_details()
                output_details = model.get_output_details()
                input_data = np.expand_dims(norm_roi, axis=(0, -1))
                model.set_tensor(input_details[0]['index'], input_data)
                model.invoke()
                preds = model.get_tensor(output_details[0]['index'])[0]
                idx = np.argmax(preds)
                if preds[idx] > 0.45 and idx < len(_CLASSES):
                    return _CLASSES[idx]

            elif model_type == "onnx_dnn":
                blob = cv2.dnn.blobFromImage(gray_roi, 1.0/255.0, (28, 28))
                model.setInput(blob)
                preds = model.forward()[0]
                idx = np.argmax(preds)
                if preds[idx] > 0.45 and idx < len(_CLASSES):
                    return _CLASSES[idx]

            elif model_type == "tf":
                input_data = np.expand_dims(norm_roi, axis=(0, -1))
                preds = model.predict(input_data, verbose=0)[0]
                idx = np.argmax(preds)
                if preds[idx] > 0.45 and idx < len(_CLASSES):
                    return _CLASSES[idx]
        except Exception:
            pass

    return decode_7segment(roi)

def process_led_image(image_path):
    if not os.path.exists(image_path):
        return ""

    img = cv2.imread(image_path)
    if img is None:
        return ""

    h, w = img.shape[:2]

    # 1. Direct Red-Channel Prominence Binarization
    b_chan, g_chan, r_chan = cv2.split(img)
    red_prominent = (r_chan >= 50) & ((r_chan.astype(int) - g_chan.astype(int)) >= 15) & ((r_chan.astype(int) - b_chan.astype(int)) >= 15)
    mask = np.zeros((h, w), dtype=np.uint8)
    mask[red_prominent] = 255

    # 2. HSV Fallback
    if cv2.countNonZero(mask) < 15:
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        lower_red1 = np.array([0, 30, 30])
        upper_red1 = np.array([15, 255, 255])
        lower_red2 = np.array([160, 30, 30])
        upper_red2 = np.array([180, 255, 255])

        mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
        mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
        mask = cv2.bitwise_or(mask1, mask2)

    # 3. White-on-black or pre-binarized grayscale fallback
    if cv2.countNonZero(mask) < 15:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        white_pixels = np.sum(gray > 200)
        black_pixels = np.sum(gray < 50)
        if white_pixels > 10 and black_pixels > (img.size * 0.4):
            mask = np.where(gray > 150, 255, 0).astype(np.uint8)
        else:
            mask = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.dilate(mask, kernel, iterations=1)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    digit_boxes = []

    for cnt in contours:
        x, y, bw, bh = cv2.boundingRect(cnt)
        if bh > h * 0.25 and bw > w * 0.08:
            if (bw / float(bh)) >= 1.1 and bw > w * 0.35:
                half_w = bw // 2
                digit_boxes.append((x, y, half_w, bh))
                digit_boxes.append((x + half_w, y, bw - half_w, bh))
            elif bw < w * 0.85:
                digit_boxes.append((x, y, bw, bh))

    digit_boxes.sort(key=lambda b: b[0])

    recognized_chars = []
    for (x, y, bw, bh) in digit_boxes:
        roi = mask[y:y+bh, x:x+bw]
        char = classify_digit_tf_dnn(roi)
        if char:
            recognized_chars.append(char)

    result = "".join(recognized_chars).upper()

    if result in ["1D", "TD", "LD", "ID"]:
        return "ID"
    if result in ["PN", "1N", "P1"]:
        return "PN"

    return result

def run_watcher_service():
    temp_dir = tempfile.gettempdir()
    req_file = os.path.join(temp_dir, "id_ocr_req.txt")
    res_file = os.path.join(temp_dir, "id_ocr_res2.txt")

    print(f"[STATUS] Watching for requests at: {req_file}")
    print("[STATUS] Service is ready. Press Ctrl+C to stop.\n")

    while True:
        try:
            if os.path.exists(req_file):
                t_start = time.time()
                try:
                    with open(req_file, "r", encoding="utf-8") as f:
                        img_path = f.read().strip()
                except Exception:
                    img_path = ""

                # Remove request trigger
                try:
                    os.remove(req_file)
                except Exception:
                    pass

                if img_path and os.path.exists(img_path):
                    res = process_led_image(img_path)
                    elapsed_ms = int((time.time() - t_start) * 1000)
                    t_stamp = time.strftime("%H:%M:%S")
                    print(f"[{t_stamp}] Processed: '{os.path.basename(img_path)}' -> Output: '{res}' ({elapsed_ms} ms)")

                    with open(res_file, "w", encoding="utf-8") as f:
                        f.write(res)
                else:
                    with open(res_file, "w", encoding="utf-8") as f:
                        f.write("")
            else:
                time.sleep(0.05)
        except KeyboardInterrupt:
            print("\n[STATUS] Service stopped by user.")
            break
        except Exception as e:
            print(f"[ERROR] Exception in watcher loop: {e}")
            time.sleep(0.1)

def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--watch":
        run_watcher_service()
    elif len(sys.argv) >= 2:
        image_path = sys.argv[1]
        res = process_led_image(image_path)
        print(res, end="")
    else:
        run_watcher_service()

if __name__ == "__main__":
    main()

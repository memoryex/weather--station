#!/usr/bin/env python3
"""
OpenCV 7-Segment LED & Character Recognition Helper for AutoHotkey ID Monitor
Usage: python led_ocr.py <image_path>
Outputs recognized 2-character token (e.g. ID, PN, or digits 00-99/A-F) to stdout.
"""

import sys
import os
import cv2
import numpy as np

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

def process_led_image(image_path):
    if not os.path.exists(image_path):
        return ""

    img = cv2.imread(image_path)
    if img is None:
        return ""

    h, w = img.shape[:2]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # Red LED HSV range (relaxed thresholds for camera glare/dark background)
    lower_red1 = np.array([0, 30, 30])
    upper_red1 = np.array([15, 255, 255])
    lower_red2 = np.array([160, 30, 30])
    upper_red2 = np.array([180, 255, 255])

    mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
    mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
    mask = cv2.bitwise_or(mask1, mask2)

    # If HSV mask yields low activation, check if image is pre-binarized black-on-white by AHK
    if cv2.countNonZero(mask) < 15:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        # Check if already black-on-white (black digits on white background)
        black_pixels = np.sum(gray < 50)
        white_pixels = np.sum(gray > 200)
        if white_pixels > (img.size * 0.4) and black_pixels > 10:
            # Pre-binarized black-on-white from AHK: invert so digits become white on black mask
            mask = cv2.bitwise_not(gray)
        else:
            mask = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 11, 2)

    # Morphological cleanup and dilation to bridge LED flicker line gaps
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.dilate(mask, kernel, iterations=1)

    # Find contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    digit_boxes = []

    for cnt in contours:
        x, y, bw, bh = cv2.boundingRect(cnt)
        if bh > h * 0.3 and bw > w * 0.1 and bw < w * 0.8:
            digit_boxes.append((x, y, bw, bh))

    # Sort boxes left-to-right
    digit_boxes.sort(key=lambda b: b[0])

    recognized_chars = []
    for (x, y, bw, bh) in digit_boxes:
        roi = mask[y:y+bh, x:x+bw]
        char = decode_7segment(roi)
        if char:
            recognized_chars.append(char)

    result = "".join(recognized_chars).upper()

    # Alias mapping for standard tokens
    if result in ["1D", "TD", "LD", "ID"]:
        return "ID"
    if result in ["PN", "1N", "P1"]:
        return "PN"

    return result

def main():
    if len(sys.argv) < 2:
        sys.exit(0)

    image_path = sys.argv[1]
    res = process_led_image(image_path)
    print(res, end="")

if __name__ == "__main__":
    main()

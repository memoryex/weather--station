#!/usr/bin/env python3
import os
import re
import time
import tkinter as tk
from pathlib import Path
import urllib.request
import urllib.parse
from threading import Thread

# =======================================================
# NUSTATYMAI (CONFIG)
# =======================================================
# Pakeiskite šį kelią į savo logų aplanką
ROOT_DIR = Path.home() / "Desktop" / "WIFI ALTA 5.0"

WINDOW_TRANSPARENCY = 0.78  # 0.0 iki 1.0 (atitinka AHK 200/255)
PRIMARY_COLOR = "#0055AA"
WINDOW_SIZE = 220

START_X = 300
START_Y = 800

BTN_WIDTH = 160
BTN_HEIGHT = 38

# -------- THINGSPEAK --------
TS_API_KEY = "O7IB88R7L2ELXR3Q"
TS_FIELD_COUNT = "field1"
TS_ENDPOINT = "https://api.thingspeak.com/update"
TS_MIN_INTERVAL = 15  # sekundėmis (AHK buvo 15000 ms)

# =======================================================
# GLOBALŪS KINTAMIEJI
# =======================================================
total_count = 0
new_count = 0
scanned_logs = {}  # file_path: last_count
ts_last_send = 0

reset_pending = False
reset_countdown = 5

class ThingSpeakClient:
    def __init__(self, api_key, endpoint, field):
        self.api_key = api_key
        self.endpoint = endpoint
        self.field = field
        self.last_send_time = 0

    def send(self, value):
        current_time = time.time()
        if current_time - self.last_send_time < TS_MIN_INTERVAL:
            return False

        data = urllib.parse.urlencode({
            'api_key': self.api_key,
            self.field: value
        }).encode('utf-8')

        try:
            req = urllib.request.Request(self.endpoint, data=data)
            with urllib.request.urlopen(req) as response:
                if response.status == 200:
                    self.last_send_time = current_time
                    return True
        except Exception as e:
            print(f"Error sending to ThingSpeak: {e}")
        return False

class LogMonitor:
    def __init__(self, root_dir, pattern=r"INFO.*OTA.*Exit"):
        self.root_dir = Path(root_dir)
        self.pattern = re.compile(pattern)
        self.scanned_logs = {}  # path: count
        self.total_count = 0
        self.new_count = 0

    def count_matches(self, file_path):
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                return len(self.pattern.findall(content))
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return 0

    def initialize_counts(self):
        if not self.root_dir.exists():
            return

        for log_file in self.root_dir.rglob("*.log"):
            cnt = self.count_matches(log_file)
            self.scanned_logs[str(log_file)] = cnt
            self.total_count += cnt
        self.new_count = 0

    def check_for_updates(self):
        if not self.root_dir.exists():
            return 0

        diff_total = 0
        for log_file in self.root_dir.rglob("*.log"):
            file_str = str(log_file)
            prev_cnt = self.scanned_logs.get(file_str, 0)
            curr_cnt = self.count_matches(log_file)

            if curr_cnt > prev_cnt:
                diff = curr_cnt - prev_cnt
                diff_total += diff
                self.total_count += diff
                self.new_count += diff
                self.scanned_logs[file_str] = curr_cnt
            elif file_str not in self.scanned_logs:
                self.scanned_logs[file_str] = curr_cnt

        return diff_total

    def reset_new_count(self):
        self.new_count = 0

class OverlayWindow(tk.Toplevel):
    def __init__(self, master):
        super().__init__(master)
        self.overrideredirect(True)
        self.attributes("-topmost", True)
        self.attributes("-alpha", WINDOW_TRANSPARENCY)
        self.configure(bg=PRIMARY_COLOR)
        self.geometry(f"{WINDOW_SIZE}x{WINDOW_SIZE}+{START_X}+{START_Y}")

        # Labels
        self.total_label = tk.Label(self, text="Viso: 0", font=("Arial", 28, "bold"),
                                    fg="white", bg=PRIMARY_COLOR)
        self.total_label.place(relx=0.5, y=70, anchor="center")

        self.new_label = tk.Label(self, text="Nauji: 0", font=("Arial", 28, "bold"),
                                  fg="white", bg=PRIMARY_COLOR)
        self.new_label.place(relx=0.5, y=150, anchor="center")

    def update_counts(self, total, new):
        self.total_label.config(text=f"Viso: {total}")
        self.new_label.config(text=f"Nauji: {new}")

class ControlWindow(tk.Toplevel):
    def __init__(self, master, on_reset_callback):
        super().__init__(master)
        self.on_reset_callback = on_reset_callback
        self.overrideredirect(True)
        self.attributes("-topmost", True)
        self.attributes("-alpha", WINDOW_TRANSPARENCY)
        self.configure(bg=PRIMARY_COLOR)

        width = BTN_WIDTH + 20
        height = BTN_HEIGHT + 20
        self.geometry(f"{width}x{height}+{START_X + 10}+{START_Y - 60}")

        self.reset_btn = tk.Button(self, text="RESET", font=("Verdana", 10, "bold"),
                                   fg="white", bg="red", activebackground="darkred",
                                   activeforeground="white", bd=0,
                                   command=self.on_reset_click)
        self.reset_btn.place(x=10, y=10, width=BTN_WIDTH, height=BTN_HEIGHT)

        self.reset_pending = False
        self.reset_countdown = 5

    def on_reset_click(self):
        if not self.reset_pending:
            self.start_reset()
        else:
            self.cancel_reset()

    def start_reset(self):
        self.reset_pending = True
        self.reset_countdown = 5
        self.update_btn_text()
        self.tick_reset()

    def tick_reset(self):
        if not self.reset_pending:
            return

        if self.reset_countdown > 0:
            self.update_btn_text()
            self.reset_countdown -= 1
            self.after(1000, self.tick_reset)
        else:
            self.do_reset()

    def update_btn_text(self):
        self.reset_btn.config(text=f"ATŠAUKTI ({self.reset_countdown})")

    def cancel_reset(self):
        self.reset_pending = False
        self.reset_btn.config(text="RESET")

    def do_reset(self):
        self.reset_pending = False
        self.reset_btn.config(text="RESET")
        self.on_reset_callback()

class WifiAltaMonitorApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.withdraw()  # Hide main window

        self.monitor = LogMonitor(ROOT_DIR)
        self.ts_client = ThingSpeakClient(TS_API_KEY, TS_ENDPOINT, TS_FIELD_COUNT)

        self.overlay = OverlayWindow(self.root)
        self.control = ControlWindow(self.root, self.perform_reset)

        self.monitor.initialize_counts()
        self.update_gui_counts()

        # Bind Escape key to exit
        self.root.bind("<Escape>", lambda e: self.root.destroy())
        self.overlay.bind("<Escape>", lambda e: self.root.destroy())
        self.control.bind("<Escape>", lambda e: self.root.destroy())

        # Start timers
        self.check_logs_loop()
        self.ensure_topmost_loop()

    def perform_reset(self):
        self.monitor.reset_new_count()
        self.update_gui_counts()

    def update_gui_counts(self):
        self.overlay.update_counts(self.monitor.total_count, self.monitor.new_count)

    def check_logs_loop(self):
        diff = self.monitor.check_for_updates()
        if diff > 0:
            self.update_gui_counts()
            # Send to ThingSpeak in a separate thread to avoid GUI freeze
            Thread(target=self.ts_client.send, args=(self.monitor.new_count,), daemon=True).start()

        self.root.after(10000, self.check_logs_loop)

    def ensure_topmost_loop(self):
        self.overlay.attributes("-topmost", True)
        self.control.attributes("-topmost", True)
        self.root.after(500, self.ensure_topmost_loop)

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = WifiAltaMonitorApp()
    app.run()

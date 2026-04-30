import os
import shutil
import unittest
from pathlib import Path
from wifi_alta_monitor import LogMonitor

class TestLogMonitor(unittest.TestCase):
    def setUp(self):
        self.test_dir = Path("test_logs")
        self.test_dir.mkdir(exist_ok=True)
        self.log_file1 = self.test_dir / "test1.log"
        self.log_file2 = self.test_dir / "subdir" / "test2.log"
        self.log_file2.parent.mkdir(exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_initial_counting(self):
        with open(self.log_file1, "w") as f:
            f.write("INFO some data OTA more Exit\n")
            f.write("INFO second OTA Exit\n")

        monitor = LogMonitor(self.test_dir)
        monitor.initialize_counts()

        self.assertEqual(monitor.total_count, 2)
        self.assertEqual(monitor.new_count, 0)
        self.assertEqual(monitor.scanned_logs[str(self.log_file1)], 2)

    def test_updates(self):
        with open(self.log_file1, "w") as f:
            f.write("INFO some data OTA more Exit\n")

        monitor = LogMonitor(self.test_dir)
        monitor.initialize_counts()
        self.assertEqual(monitor.total_count, 1)

        # Add new match to existing file
        with open(self.log_file1, "a") as f:
            f.write("INFO new OTA Exit\n")

        diff = monitor.check_for_updates()
        self.assertEqual(diff, 1)
        self.assertEqual(monitor.total_count, 2)
        self.assertEqual(monitor.new_count, 1)

        # Add new file
        with open(self.log_file2, "w") as f:
            f.write("INFO nested OTA Exit\n")
            f.write("INFO nested OTA Exit\n")

        diff = monitor.check_for_updates()
        self.assertEqual(diff, 2)
        self.assertEqual(monitor.total_count, 4)
        self.assertEqual(monitor.new_count, 3)

    def test_reset(self):
        monitor = LogMonitor(self.test_dir)
        monitor.new_count = 10
        monitor.reset_new_count()
        self.assertEqual(monitor.new_count, 0)

if __name__ == "__main__":
    unittest.main()

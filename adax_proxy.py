import http.server
import urllib.request
import urllib.parse
import sys
import threading
import time
import json
import socket

# ADAX Proxy Server
# This script helps to bypass browser security restrictions (CORS and Mixed Content)
# when the dashboard is running on HTTPS but needs to access ADAX API on a local HTTP IP.
#
# NEW: Background fetching and data aggregation for all ADAX lines (1, 2, 3, 4, 6, 7)

PORT = 8081
ADAX_LIDS = [1, 2, 3, 4, 6, 7]
ADAX_BASE_URL = "http://10.12.24.51:8088/api/index.php"

# Thread-safe global cache
cache_lock = threading.Lock()
adax_cache = {
    "last_update": None,
    "lines": {lid: {"data": None, "error": "Laukiama duomenų...", "timestamp": None} for lid in ADAX_LIDS}
}

import re

def parse_php_var_dump(content):
    # Pattern to find the array(5) blocks which represent individual records
    record_pattern = re.compile(r'array\(\d+\)\s*\{([^}]+)\}', re.DOTALL)

    # Patterns for fields within a record
    field_patterns = {
        "Produktas": re.compile(r'\["Produktas"\]=>\s*string\(\d+\)\s*"([^"]+)"'),
        "Linija": re.compile(r'\["Linija"\]=>\s*string\(\d+\)\s*"([^"]+)"'),
        "PusgaminioNr": re.compile(r'\["PusgaminioNr"\]=>\s*string\(\d+\)\s*"([^"]+)"'),
        "TestavimoLaikas": re.compile(r'\["TestavimoLaikas"\]=>\s*string\(\d+\)\s*"([^"]+)"'),
        "NuskanavimoLaikas": re.compile(r'\["NuskanavimoLaikas"\]=>\s*string\(\d+\)\s*"([^"]+)"')
    }

    results = []
    for record_match in record_pattern.finditer(content):
        record_text = record_match.group(1)
        record_data = {}
        for field, pattern in field_patterns.items():
            field_match = pattern.search(record_text)
            if field_match:
                record_data[field] = field_match.group(1).strip()

        if record_data:
            results.append(record_data)
    return results

def fetch_adax_data(lid):
    url = f"{ADAX_BASE_URL}?lid={lid}&group=1"
    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0 ADAX-Proxy-Background')
        with urllib.request.urlopen(req, timeout=15) as response:
            content = response.read().decode('utf-8', errors='ignore')

            # 1. Try standard JSON parsing
            start = content.find('[')
            end = content.rfind(']')

            if start != -1 and end > start:
                json_str = content[start:end+1]
                try:
                    data = json.loads(json_str)
                    return data, None
                except json.JSONDecodeError:
                    pass

            # 2. Try PHP var_dump parsing
            if "array(" in content:
                data = parse_php_var_dump(content)
                if data:
                    return data, None

            return None, "No valid JSON or var_dump found in response"
    except socket.timeout:
        return None, "Timeout (15s)"
    except Exception as e:
        return None, str(e)

def background_fetcher():
    print(f"Background fetcher started. Targeting LIDs: {ADAX_LIDS}")
    while True:
        for lid in ADAX_LIDS:
            # print(f"Background fetching LID {lid}...")
            data, error = fetch_adax_data(lid)

            with cache_lock:
                adax_cache["lines"][lid]["data"] = data
                adax_cache["lines"][lid]["error"] = error
                adax_cache["lines"][lid]["timestamp"] = time.strftime("%Y-%m-%d %H:%M:%S")

            # Small delay between lines to avoid overwhelming the target server
            time.sleep(2)

        with cache_lock:
            adax_cache["last_update"] = time.strftime("%Y-%m-%d %H:%M:%S")
            # print(f"ADAX cache updated at {adax_cache['last_update']}")

        # Wait 60 seconds before next full cycle
        time.sleep(60)

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/adax/all":
            self.send_aggregated_data()
            return

        if "?url=" not in self.path:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Missing 'url' parameter. Usage: http://localhost:8081/?url=TARGET_URL or /adax/all")
            return

        # Extract everything after the first occurrence of ?url=
        target_url = self.path.split("?url=", 1)[1]
        target_url = urllib.parse.unquote(target_url)

        # print(f"[{self.date_time_string()}] Proxying to: {target_url}")

        try:
            req = urllib.request.Request(target_url)
            req.add_header('User-Agent', 'Mozilla/5.0 ADAX-Proxy')

            with urllib.request.urlopen(req, timeout=15) as response:
                content = response.read()
                self.send_response(200)
                self.send_cors_headers()
                ctype = response.info().get_content_type() or 'application/json'
                self.send_header('Content-Type', ctype)
                self.end_headers()
                self.wfile.write(content)
        except (ConnectionAbortedError, BrokenPipeError):
            # Client closed the connection prematurely, ignore
            pass
        except Exception as e:
            # print(f"Error proxying request: {e}")
            try:
                self.send_response(500)
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(str(e).encode())
            except (ConnectionAbortedError, BrokenPipeError):
                pass

    def send_aggregated_data(self):
        try:
            with cache_lock:
                response_json = json.dumps(adax_cache)

            self.send_response(200)
            self.send_cors_headers()
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(response_json.encode())
        except (ConnectionAbortedError, BrokenPipeError):
            pass

    def send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def log_message(self, format, *args):
        # Quiet mode for proxy logs
        return

class AdaxProxyServer(http.server.HTTPServer):
    def handle_error(self, request, client_address):
        # Suppress ConnectionAbortedError tracebacks in console
        exc_type, exc_value, _ = sys.exc_info()
        if exc_type in [ConnectionAbortedError, BrokenPipeError]:
            return
        super().handle_error(request, client_address)

if __name__ == "__main__":
    # Start background fetcher thread
    fetcher_thread = threading.Thread(target=background_fetcher, daemon=True)
    fetcher_thread.start()

    try:
        server = AdaxProxyServer(('127.0.0.1', PORT), ProxyHandler)
        print("========================================")
        print(f" ADAX Proxy + Aggregator started on port {PORT}")
        print("========================================")
        print(f"Aggregated endpoint: http://localhost:{PORT}/adax/all")
        print(f"Legacy proxy: http://localhost:{PORT}/?url=")
        print("\nKeep this window open while using the ADAX lines.")
        print("Press Ctrl+C to stop.")
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping proxy server...")
        sys.exit(0)
    except Exception as e:
        print(f"Failed to start server: {e}")
        sys.exit(1)

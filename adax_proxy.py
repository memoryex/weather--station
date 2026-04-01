import http.server
import urllib.request
import urllib.parse
import sys

# ADAX Proxy Server
# This script helps to bypass browser security restrictions (CORS and Mixed Content)
# when the dashboard is running on HTTPS but needs to access ADAX API on a local HTTP IP.

PORT = 8081

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Improved URL extraction: Get everything after "?url="
        # This handles cases where target_url has its own unencoded query parameters
        path = self.path
        if "?url=" not in path:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Missing 'url' parameter. Usage: http://localhost:8081/?url=TARGET_URL")
            return

        # Extract everything after the first occurrence of ?url=
        target_url = path.split("?url=", 1)[1]
        # Unquote once just in case the browser encoded the whole thing
        target_url = urllib.parse.unquote(target_url)

        print(f"[{self.date_time_string()}] Proxying to: {target_url}")

        try:
            # 2. Fetch the target data
            req = urllib.request.Request(target_url)
            # Some servers might require a User-Agent
            req.add_header('User-Agent', 'Mozilla/5.0 ADAX-Proxy')

            with urllib.request.urlopen(req, timeout=10) as response:
                content = response.read()

                # 3. Send response back with CORS headers
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', '*')

                # Try to preserve Content-Type if possible, otherwise default to json
                ctype = response.info().get_content_type() or 'application/json'
                self.send_header('Content-Type', ctype)

                self.end_headers()
                self.wfile.write(content)

        except Exception as e:
            print(f"Error proxying request: {e}")
            self.send_response(500)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(str(e).encode())

    # Handle preflight CORS requests (automatically sent by browsers)
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()

    # Enable logging for debugging
    # def log_message(self, format, *args):
    #     return

if __name__ == "__main__":
    try:
        # Binding to 127.0.0.1 for security - accessibility limited to local machine
        server = http.server.HTTPServer(('127.0.0.1', PORT), ProxyHandler)
        print("========================================")
        print(f" ADAX Proxy Server started on port {PORT}")
        print("========================================")
        print(f"Dashboard setting: http://localhost:{PORT}/?url=")
        print("\nKeep this window open while using the ADAX lines.")
        print("Press Ctrl+C to stop.")
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping proxy server...")
        sys.exit(0)
    except Exception as e:
        print(f"Failed to start server: {e}")
        sys.exit(1)

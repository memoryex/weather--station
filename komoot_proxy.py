import http.server
import urllib.request
import urllib.parse
import json
import ssl

PORT = 5050

class KomootProxyHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200, "ok")
        self.end_headers()

    def do_GET(self):
        # Allow requests to /proxy?url=...
        if self.path.startswith('/proxy?'):
            qs = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(qs)

            if 'url' in params:
                target_url = params['url'][0]

                # Forward authorization header if present
                headers = {'User-Agent': 'KomootProxy/1.0'}
                auth_header = self.headers.get('Authorization')
                if auth_header:
                    headers['Authorization'] = auth_header

                req = urllib.request.Request(target_url, headers=headers)
                try:
                    # Ignore SSL certificate errors to be safe locally
                    ctx = ssl.create_default_context()
                    ctx.check_hostname = False
                    ctx.verify_mode = ssl.CERT_NONE

                    with urllib.request.urlopen(req, context=ctx) as response:
                        self.send_response(response.status)
                        for k, v in response.getheaders():
                            if k.lower() not in ['access-control-allow-origin', 'access-control-allow-methods', 'access-control-allow-headers', 'content-length', 'connection']:
                                self.send_header(k, v)
                        body = response.read()
                        if body:
                            self.send_header('Content-Length', str(len(body)))
                        self.end_headers()
                        self.wfile.write(body)
                except urllib.error.HTTPError as e:
                    self.send_response(e.code)
                    self.send_header('Content-Type', 'application/json')
                    body = e.read()
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                except Exception as e:
                    print("Proxy error:", str(e))
                    self.send_response(500)
                    self.send_header('Content-Type', 'text/plain')
                    self.end_headers()
                    self.wfile.write(str(e).encode('utf-8'))
                return

        # Serve local files (like index.html)
        return super().do_GET()

if __name__ == '__main__':
    with http.server.ThreadingHTTPServer(("", PORT), KomootProxyHandler) as httpd:
        print(f"===========================================================")
        print(f" Komoot Vietinis Proxy Serveris Paleistas!")
        print(f" Klausomasi prievado: {PORT}")
        print(f"===========================================================")
        print(f" -> Palikite šį langą atidarytą kol naudojatės Komoot funkcija.")
        print(f" -> Eikite į naršyklę ir atidarykite savo index.html failą.")
        httpd.serve_forever()

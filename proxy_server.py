#!/usr/bin/env python3
"""
Firebase Functions Proxy Server
組織ポリシーでallUsersアクセスが禁止されているCloud Functionsへのプロキシ
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import json
import sys

PORT = 8080

# Cloud Functions URL
GENERATE_TOKEN_URL = "https://generateagoratoken-eyix4hluza-uc.a.run.app"
SEND_PUSH_URL = "https://sendpushnotification-eyix4hluza-uc.a.run.app"

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.send_header('Access-Control-Max-Age', '3600')
        self.end_headers()
    
    def do_POST(self):
        """Proxy POST requests to Cloud Functions"""
        try:
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            request_body = self.rfile.read(content_length) if content_length > 0 else b''
            
            # Determine target URL based on path
            if self.path == '/generateAgoraToken' or self.path == '/generateAgoraToken/':
                target_url = GENERATE_TOKEN_URL
            elif self.path == '/sendPushNotification' or self.path == '/sendPushNotification/':
                target_url = SEND_PUSH_URL
            else:
                self.send_error(404, "Endpoint not found")
                return
            
            print(f"[Proxy] Forwarding request to: {target_url}")
            print(f"[Proxy] Request body length: {len(request_body)}")
            
            # Get Authorization header from client
            auth_header = self.headers.get('Authorization')
            
            # Prepare headers for Cloud Functions
            headers = {
                'Content-Type': 'application/json',
            }
            if auth_header:
                headers['Authorization'] = auth_header
                print(f"[Proxy] Authorization header included")
            else:
                print(f"[Proxy] WARNING: No Authorization header")
            
            # Forward request to Cloud Functions
            req = urllib.request.Request(
                target_url,
                data=request_body,
                headers=headers,
                method='POST'
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                response_body = response.read()
                response_status = response.status
                
                print(f"[Proxy] Response status: {response_status}")
                
                # Send response to client
                self.send_response(response_status)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(response_body)))
                self.end_headers()
                self.wfile.write(response_body)
                
                print(f"[Proxy] ✅ Request successful")
                
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8')
            print(f"[Proxy] ❌ HTTP Error {e.code}: {error_body}")
            
            self.send_response(e.code)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(error_body.encode('utf-8'))
            
        except Exception as e:
            print(f"[Proxy] ❌ Error: {str(e)}")
            
            self.send_response(500)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = json.dumps({
                'error': f'Proxy error: {str(e)}'
            })
            self.wfile.write(error_response.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Custom log format"""
        sys.stdout.write(f"[Proxy] {format % args}\n")

if __name__ == "__main__":
    print(f"🚀 Starting Firebase Functions Proxy Server on port {PORT}")
    print(f"📍 Proxy endpoints:")
    print(f"   POST /generateAgoraToken → {GENERATE_TOKEN_URL}")
    print(f"   POST /sendPushNotification → {SEND_PUSH_URL}")
    print(f"")
    
    with socketserver.TCPServer(("0.0.0.0", PORT), ProxyHandler) as httpd:
        print(f"✅ Proxy server running at http://0.0.0.0:{PORT}")
        print(f"   Press Ctrl+C to stop")
        print(f"")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 Shutting down proxy server...")
            httpd.shutdown()

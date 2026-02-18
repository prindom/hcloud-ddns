#!/usr/bin/env python3
# ==============================================================================
# Hetzner DNS DDNS Addon
# Minimal HTTP server exposing a "Force Update Now" button via HA ingress
# ==============================================================================

import http.server
import os
import signal

PID_FILE = "/var/run/hcloud-ddns.pid"
PORT = 8099

_HTML_PAGE = """\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Hetzner DNS DDNS</title>
  <style>
    body { font-family: sans-serif; max-width: 480px; margin: 3rem auto; padding: 0 1rem; }
    h1   { font-size: 1.4rem; margin-bottom: 0.4rem; }
    p    { color: #555; margin-bottom: 1.5rem; }
    button {
      background: #1976d2; color: #fff; border: none;
      padding: 0.6rem 1.4rem; font-size: 1rem;
      border-radius: 4px; cursor: pointer;
    }
    button:hover { background: #1565c0; }
  </style>
</head>
<body>
  <h1>Hetzner DNS DDNS</h1>
  <p>Trigger an immediate DNS update check without waiting for the next scheduled interval.</p>
  <form method="post">
    <button type="submit">Force Update Now</button>
  </form>
</body>
</html>"""

_HTML_TRIGGERED = """\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="2;url=.">
  <title>Hetzner DNS DDNS</title>
  <style>
    body { font-family: sans-serif; max-width: 480px; margin: 3rem auto; padding: 0 1rem; }
    h1   { font-size: 1.4rem; }
    p    { color: #555; }
  </style>
</head>
<body>
  <h1>Update triggered</h1>
  <p>Redirecting back&hellip;</p>
</body>
</html>"""


class _Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # suppress default access log
        pass

    def _send_html(self, body, status=200):
        encoded = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        self._send_html(_HTML_PAGE)

    def do_POST(self):
        try:
            with open(PID_FILE) as fh:
                pid = int(fh.read().strip())
            os.kill(pid, signal.SIGUSR1)
        except Exception:
            pass
        self._send_html(_HTML_TRIGGERED)


http.server.HTTPServer(("", PORT), _Handler).serve_forever()

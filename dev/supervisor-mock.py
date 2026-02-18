#!/usr/bin/env python3
"""
Minimal mock of the Home Assistant Supervisor HTTP API.
Serves config from /data/options.json so the addon can run outside HA.
"""

import http.server
import json

OPTIONS_FILE = "/data/options.json"


def _load_options():
    with open(OPTIONS_FILE) as fh:
        return json.load(fh)


class _Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # silence access log

    def _json(self, data):
        body = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        options = _load_options()
        path = self.path.split("?")[0]

        if path == "/addons/self/options/config":
            self._json({"result": "ok", "data": options})
        elif path == "/addons/self/info":
            self._json({
                "result": "ok",
                "data": {
                    "name": "Hetzner DNS DDNS (dev)",
                    "slug": "hcloud-ddns",
                    "version": "dev",
                    "log_level": options.get("log_level", "info"),
                    "state": "started",
                    "boot": "auto",
                    "options": options,
                },
            })
        else:
            # Generic fallback for banner, core/info, supervisor/info, etc.
            self._json({"result": "ok", "data": {"version": "dev", "channel": "stable"}})


http.server.HTTPServer(("", 80), _Handler).serve_forever()

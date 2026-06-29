#!/usr/bin/env python3
"""Lightweight private-room registry for Monster & Hunter.

A standalone, in-memory registry that lists Noray-hosted PRIVATE rooms — deliberately kept
SEPARATE from the public-lobby (maomao-public) room registry so the two never mix. A private
host POSTs its room (name + noray:<code> share code + player count) and re-POSTs periodically
as a heartbeat; the private-server browser GETs the list across the internet and joins a room
by its share code.

Design notes:
- In-memory only. Rooms are ephemeral and self-expire after ROOM_TTL_SEC without a heartbeat,
  so a crashed/closed host drops off without any cleanup job.
- Binds to 127.0.0.1 only; exposed through the existing nginx (port 80) under /private_rooms/,
  so it needs no new firewall/security-group port.
- No auth: the payload is just public room metadata + the already-public Open ID share code.
  The private id is never sent here. room_name/host_name are length-clamped and the share code
  must look like noray:<id>, so a malformed or oversized body is rejected at the boundary.
"""

import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 8088
ROOM_TTL_SEC = 20.0          # drop a room this long after its last heartbeat
MAX_ROOMS = 500              # hard cap so a flood can't exhaust memory
MAX_NAME_LEN = 32
MAX_BODY_BYTES = 4096

_rooms = {}                  # share_code -> room dict (incl. "_last_seen")
_lock = threading.Lock()


def _now():
    return time.time()


def _clamp_str(value, max_len):
    return str(value)[:max_len] if value is not None else ""


def _sanitize_room(payload):
    share_code = str(payload.get("share_code", "")).strip()
    # The share code is the join handle AND the registry key; require the noray: form.
    if not share_code.lower().startswith("noray:") or len(share_code) > 128:
        return None
    name = _clamp_str(payload.get("room_name", "Room"), MAX_NAME_LEN).strip() or "Room"
    return {
        "share_code": share_code,
        "room_name": name,
        "host_name": _clamp_str(payload.get("host_name", ""), MAX_NAME_LEN),
        "player_count": max(0, min(int(payload.get("player_count", 1) or 0), 64)),
        "max_players": max(1, min(int(payload.get("max_players", 24) or 24), 64)),
        "locked": bool(payload.get("locked", False)),
        "build": _clamp_str(payload.get("build", ""), 48),
    }


def _live_rooms():
    cutoff = _now() - ROOM_TTL_SEC
    out = []
    with _lock:
        for code in list(_rooms.keys()):
            room = _rooms[code]
            if room["_last_seen"] < cutoff:
                del _rooms[code]
                continue
            public = {k: v for k, v in room.items() if k != "_last_seen"}
            out.append(public)
    out.sort(key=lambda r: r.get("room_name", "").lower())
    return out


class Handler(BaseHTTPRequestHandler):
    server_version = "MaomaoPrivateRegistry/1.0"

    def _send_json(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length <= 0 or length > MAX_BODY_BYTES:
            return None
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return None

    def do_GET(self):
        if self.path.rstrip("/") in ("/private_rooms/list", "/private_rooms"):
            self._send_json(200, {"rooms": _live_rooms(), "ttl": ROOM_TTL_SEC})
        elif self.path.rstrip("/") == "/private_rooms/health":
            self._send_json(200, {"ok": True, "rooms": len(_rooms)})
        else:
            self._send_json(404, {"error": "not_found"})

    def do_POST(self):
        path = self.path.rstrip("/")
        payload = self._read_json()
        if payload is None or not isinstance(payload, dict):
            self._send_json(400, {"error": "bad_body"})
            return
        if path == "/private_rooms/register":
            room = _sanitize_room(payload)
            if room is None:
                self._send_json(400, {"error": "bad_share_code"})
                return
            with _lock:
                if room["share_code"] not in _rooms and len(_rooms) >= MAX_ROOMS:
                    self._send_json(503, {"error": "registry_full"})
                    return
                room["_last_seen"] = _now()
                _rooms[room["share_code"]] = room
            self._send_json(200, {"ok": True, "ttl": ROOM_TTL_SEC})
        elif path == "/private_rooms/remove":
            code = str(payload.get("share_code", "")).strip()
            with _lock:
                _rooms.pop(code, None)
            self._send_json(200, {"ok": True})
        else:
            self._send_json(404, {"error": "not_found"})

    def log_message(self, fmt, *args):
        # Quiet by default; systemd/journald captures stderr if needed.
        pass


def main():
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print("[private-registry] listening on %s:%d (ttl=%.0fs)" % (HOST, PORT, ROOM_TTL_SEC), flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        httpd.shutdown()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Central score and ghost car storage service for SPPPD."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import time
from urllib.parse import parse_qs, urlparse

HOST = os.environ.get("HOST", "127.0.0.1")
PORT = int(os.environ.get("PORT", "3842"))
DATA_DIR = Path(os.environ.get("SPPPD_DATA_DIR", Path(__file__).resolve().parent / "data"))
DB_PATH = Path(os.environ.get("SPPPD_DB", DATA_DIR / "leaderboard.db"))
TOP_LIMIT = 5
KEEP_LIMIT = 10
MAX_BODY_BYTES = 262144
MAX_GHOST_NUMS = 18000
ID_RE = re.compile(r"^[a-z0-9_-]{1,40}$")


def open_db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=5.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            track TEXT NOT NULL,
            rules TEXT NOT NULL DEFAULT 'open',
            car TEXT NOT NULL DEFAULT 'hot_hatch',
            hue INTEGER NOT NULL DEFAULT 1,
            name TEXT NOT NULL DEFAULT 'YOU',
            time REAL NOT NULL,
            ghost TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_records_track_time
        ON records (track, time ASC, id ASC)
        """
    )
    return conn


def clean_name(raw) -> str:
    text = str(raw or "YOU").strip().upper()
    cleaned = "".join(ch for ch in text if 32 <= ord(ch) <= 95 and ch not in '\\"')
    return (cleaned[:16] or "YOU").strip() or "YOU"


def parse_submission(payload: dict):
    if not isinstance(payload, dict):
        return None
    track = str(payload.get("track") or "").strip().lower()
    car = str(payload.get("car") or "hot_hatch").strip().lower()
    rules = "open" if str(payload.get("rules") or "").strip().lower() == "open" else "clean"
    if not ID_RE.match(track) or not ID_RE.match(car):
        return None
    try:
        lap_time = float(payload.get("time"))
        hue = int(payload.get("hue", 1))
    except (TypeError, ValueError):
        return None
    if not math.isfinite(lap_time) or lap_time < 0.2 or lap_time > 3600.0:
        return None
    hue = max(1, min(16, hue))
    name = clean_name(payload.get("name"))
    raw_ghost = payload.get("ghost")
    if not isinstance(raw_ghost, list) or len(raw_ghost) < 6 or len(raw_ghost) > MAX_GHOST_NUMS:
        return None
    ghost_nums = []
    for item in raw_ghost:
        if isinstance(item, (int, float)):
            val = float(item)
            if not math.isfinite(val):
                return None
            ghost_nums.append(round(val, 3))
        elif isinstance(item, list):
            for sub in item:
                if not isinstance(sub, (int, float)) or not math.isfinite(float(sub)):
                    return None
                ghost_nums.append(round(float(sub), 3))
        else:
            return None
    usable = (len(ghost_nums) // 3) * 3
    if usable < 6 or usable > MAX_GHOST_NUMS:
        return None
    ghost_nums = ghost_nums[:usable]
    return {
        "track": track,
        "car": car,
        "rules": rules,
        "time": round(lap_time, 4),
        "hue": hue,
        "name": name,
        "ghost": ghost_nums,
    }


def fetch_tracks(conn: sqlite3.Connection, only_track: str = "") -> dict:
    tracks = {}
    if only_track:
        track_rows = [{"track": only_track}]
    else:
        track_rows = conn.execute("SELECT DISTINCT track FROM records ORDER BY track ASC").fetchall()
    for trow in track_rows:
        tname = trow["track"]
        rows = conn.execute(
            """
            SELECT track, rules, car, hue, name, time, ghost
            FROM records
            WHERE track = ?
            ORDER BY time ASC, id ASC
            LIMIT ?
            """,
            (tname, TOP_LIMIT),
        ).fetchall()
        entries = []
        for row in rows:
            try:
                ghost = json.loads(row["ghost"])
            except Exception:
                ghost = []
            if isinstance(ghost, list) and len(ghost) >= 6:
                entries.append(
                    {
                        "time": round(float(row["time"]), 4),
                        "car": row["car"],
                        "hue": int(row["hue"]),
                        "name": row["name"],
                        "rules": row["rules"],
                        "ghost": ghost,
                    }
                )
        if entries:
            tracks[tname] = entries
    return tracks


def store_submission(conn: sqlite3.Connection, entry: dict) -> None:
    existing = conn.execute(
        """
        SELECT id FROM records
        WHERE track = ? AND car = ? AND ABS(time - ?) < 0.0001
        LIMIT 1
        """,
        (entry["track"], entry["car"], entry["time"]),
    ).fetchone()
    if not existing:
        conn.execute(
            """
            INSERT INTO records (track, rules, car, hue, name, time, ghost, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                entry["track"],
                entry["rules"],
                entry["car"],
                entry["hue"],
                entry["name"],
                entry["time"],
                json.dumps(entry["ghost"], separators=(",", ":")),
                int(time.time()),
            ),
        )
        conn.execute(
            """
            DELETE FROM records
            WHERE track = ?
              AND id NOT IN (
                  SELECT id FROM records
                  WHERE track = ?
                  ORDER BY time ASC, id ASC
                  LIMIT ?
              )
            """,
            (entry["track"], entry["track"], KEEP_LIMIT),
        )
        conn.commit()


def lua_quote(val: str) -> str:
    escaped = (
        str(val or "")
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )
    return f'"{escaped}"'


def tracks_to_lua(tracks: dict) -> str:
    lines = ["return {"]
    for track_name in sorted(tracks.keys()):
        entries = tracks.get(track_name) or []
        lines.append(f"  [{lua_quote(track_name)}] = {{")
        for idx, entry in enumerate(entries, start=1):
            ghost_vals = ", ".join(str(v) for v in (entry.get("ghost") or []))
            lines.append(
                f"    [{idx}] = {{ "
                f'["time"] = {float(entry.get("time", 0)):.4f}, '
                f'["car"] = {lua_quote(entry.get("car", "hot_hatch"))}, '
                f'["hue"] = {int(entry.get("hue", 1))}, '
                f'["name"] = {lua_quote(entry.get("name", "YOU"))}, '
                f'["rules"] = {lua_quote(entry.get("rules", "clean"))}, '
                f'["ghost"] = {{ {ghost_vals} }} }},'
            )
        lines.append("  },")
    lines.append("}\n")
    return "\n".join(lines)


class Handler(BaseHTTPRequestHandler):
    server_version = "SPPPDLeaderboard/1.0"

    def send_json(self, status: int, data: dict) -> None:
        raw = json.dumps(data, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def send_lua(self, status: int, tracks: dict) -> None:
        raw = tracks_to_lua(tracks).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path not in ("/api/records", "/spppd/api/records", "/api/health"):
            self.send_json(404, {"error": "not found"})
            return
        if parsed.path == "/api/health":
            self.send_json(200, {"ok": True})
            return
        qs = parse_qs(parsed.query)
        only_track = (qs.get("track") or [""])[0].strip().lower()
        fmt = (qs.get("format") or [""])[0].strip().lower()
        with open_db() as conn:
            tracks = fetch_tracks(conn, only_track if ID_RE.match(only_track) else "")
        if fmt == "lua":
            self.send_lua(200, tracks)
        else:
            self.send_json(200, {"ok": True, "tracks": tracks})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path not in ("/api/records", "/spppd/api/records"):
            self.send_json(404, {"error": "not found"})
            return
        qs = parse_qs(parsed.query)
        fmt = (qs.get("format") or [""])[0].strip().lower()
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY_BYTES:
            self.send_json(400, {"error": "invalid body size"})
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception:
            self.send_json(400, {"error": "invalid json"})
            return

        items = payload.get("entries") if isinstance(payload, dict) and isinstance(payload.get("entries"), list) else [payload]
        parsed_entries = []
        for item in items[:4]:
            entry = parse_submission(item)
            if entry:
                parsed_entries.append(entry)
        if not parsed_entries:
            self.send_json(400, {"error": "invalid record payload"})
            return

        with open_db() as conn:
            for entry in parsed_entries:
                store_submission(conn, entry)
            tracks = fetch_tracks(conn)
        if fmt == "lua":
            self.send_lua(200, tracks)
        else:
            self.send_json(200, {"ok": True, "tracks": tracks})

    def log_message(self, fmt: str, *args) -> None:
        return


def main() -> None:
    open_db().close()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"SPPPD central leaderboard + ghost server listening on http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()

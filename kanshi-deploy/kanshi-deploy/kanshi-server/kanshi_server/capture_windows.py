import ctypes
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
import os
import sys
import time
import socket
import platform
import logging

# Logging setup
log_dir = Path(os.environ.get("LOCALAPPDATA", "")) / "kanshi" / "kanshi" / "Logs"
log_dir.mkdir(parents=True, exist_ok=True)
log_file = log_dir / "capture_windows.log"
logging.basicConfig(filename=str(log_file), level=logging.INFO, format='%(asctime)s - %(message)s')

if platform.system() == "Windows":
    DATA_DIR = Path(os.environ.get("LOCALAPPDATA", "")) / "kanshi" / "kanshi" / "kanshi-server"
else:
    DATA_DIR = Path.home() / ".local" / "share" / "kanshi" / "kanshi-server"

DB_PATH = DATA_DIR / "peewee-sqlite.v2.db"
HOSTNAME = socket.gethostname()
BUCKET_NAME = f"kanshi-watcher-window_{HOSTNAME}"

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

def extract_app_name_from_title(title: str) -> str:
    """Extract app name from window title."""
    if not title or not isinstance(title, str):
        return "unknown"
    
    title = title.strip()
    if not title:
        return "unknown"
    
    # Try extracting from "App - Title" format
    if " - " in title:
        parts = title.rsplit(" - ", 1)
        app_candidate = parts[-1].strip()
        if app_candidate and len(app_candidate) < 80 and app_candidate.lower() not in ["untitled", "new tab"]:
            return app_candidate
        app_candidate = parts[0].strip()
        if app_candidate and len(app_candidate) < 80:
            return app_candidate
    
    # Use first part before special characters
    for sep in [" | ", " :: ", " ~ ", ": "]:
        if sep in title:
            app_candidate = title.split(sep)[0].strip()
            if app_candidate and len(app_candidate) < 80:
                return app_candidate
    
    # Fallback to full title if reasonable length
    if len(title) < 80:
        return title
    
    return title[:80]


def get_active_window():
    """Get title and app name of active window."""
    try:
        hwnd = user32.GetForegroundWindow()
        if not hwnd:
            return "unknown", ""
        
        # Get window title - use the correct API function
        title_length = user32.GetWindowTextLengthW(hwnd)
        if title_length > 0:
            title_buffer = ctypes.create_unicode_buffer(title_length + 1)
            user32.GetWindowTextW(hwnd, title_buffer, title_length + 1)
            title = title_buffer.value or ""
        else:
            title = ""
        
        pid = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if not pid.value:
            # Fallback to title if no PID
            return extract_app_name_from_title(title), title
        
        PROCESS_QUERY_INFORMATION = 0x0400
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        PROCESS_VM_READ = 0x0010
        access = PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ
        handle = kernel32.OpenProcess(access, False, pid.value)
        if not handle:
            access = PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
            handle = kernel32.OpenProcess(access, False, pid.value)

        app_name = "unknown"
        if handle:
            try:
                exe_path = None
                path_buffer = ctypes.create_unicode_buffer(260)
                length = ctypes.c_ulong(len(path_buffer))
                if kernel32.QueryFullProcessImageNameW(handle, 0, path_buffer, ctypes.byref(length)):
                    exe_path = path_buffer.value
                else:
                    try:
                        psapi = ctypes.windll.psapi
                        if psapi.GetModuleFileNameExW(handle, None, path_buffer, len(path_buffer)):
                            exe_path = path_buffer.value
                    except Exception:
                        try:
                            psapi = ctypes.windll.psapi
                            path_buffer_a = ctypes.create_string_buffer(260)
                            if psapi.GetProcessImageFileNameA(handle, path_buffer_a, 260):
                                exe_path = path_buffer_a.value.decode('utf-8', errors='ignore')
                        except Exception:
                            pass

                if exe_path:
                    app_name = Path(exe_path).name or "unknown"
                    if app_name == "unknown" and title:
                        app_name = extract_app_name_from_title(title)
                elif title:
                    # If process path cannot be resolved, use window title fallback
                    app_name = extract_app_name_from_title(title)
            except Exception as err:
                logging.error(f"Error reading process image name: {err}")
                if title:
                    app_name = extract_app_name_from_title(title)
            finally:
                if handle:
                    kernel32.CloseHandle(handle)
        else:
            # No handle - use title as fallback
            if title:
                app_name = extract_app_name_from_title(title)
        
        return app_name, title
    except Exception as e:
        logging.error(f"Error getting active window: {e}")
        return "unknown", ""


def _format_timestamp(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")


def ensure_bucket_exists(conn, cursor):
    """Ensure window capture bucket exists in database."""
    cursor.execute("SELECT rowid FROM bucketmodel WHERE id = ?", (BUCKET_NAME,))
    result = cursor.fetchone()
    if result:
        return result[0]
    
    cursor.execute(
        "INSERT INTO bucketmodel (id, type, hostname, client) VALUES (?, ?, ?, ?)",
        (BUCKET_NAME, "currentwindow", HOSTNAME, "auto-capture")
    )
    conn.commit()
    cursor.execute("SELECT rowid FROM bucketmodel WHERE id = ?", (BUCKET_NAME,))
    return cursor.fetchone()[0]

def capture_windows(duration=300, interval=1000):
    """Capture active windows and write to database."""
    if not DB_PATH.exists():
        logging.error(f"Database not found: {DB_PATH}")
        return 1
    
    try:
        conn = sqlite3.connect(str(DB_PATH), timeout=10)
        cursor = conn.cursor()
        bucket_id = ensure_bucket_exists(conn, cursor)
        
        logging.info(f"Starting capture for {duration}s")
        start_time = time.time()
        last_app = None
        last_title = ""
        last_ts = None
        last_rowid = None
        event_count = 0
        
        while (time.time() - start_time) < duration:
            app_name, window_title = get_active_window()
            now = datetime.now(timezone.utc)
            
            # Debug logging
            if event_count % 10 == 0:
                logging.info(f"Captured: app={app_name}, title={window_title[:60] if window_title else 'EMPTY'}")

            if last_app is None:
                last_app = app_name
                last_title = window_title
                last_ts = now
                data = {"app": last_app, "title": last_title}
                cursor.execute(
                    "INSERT INTO eventmodel (bucket_id, timestamp, duration, datastr) VALUES (?, ?, ?, ?)",
                    (bucket_id, _format_timestamp(last_ts), 0, json.dumps(data))
                )
                last_rowid = cursor.lastrowid
                conn.commit()
                event_count += 1
            elif app_name != last_app:
                duration_secs = int((now - last_ts).total_seconds())
                if duration_secs <= 0:
                    duration_secs = 1
                cursor.execute(
                    "UPDATE eventmodel SET duration = ? WHERE rowid = ?",
                    (duration_secs, last_rowid)
                )
                conn.commit()

                last_app = app_name
                last_title = window_title
                last_ts = now
                data = {"app": last_app, "title": last_title}
                cursor.execute(
                    "INSERT INTO eventmodel (bucket_id, timestamp, duration, datastr) VALUES (?, ?, ?, ?)",
                    (bucket_id, _format_timestamp(last_ts), 0, json.dumps(data))
                )
                last_rowid = cursor.lastrowid
                conn.commit()
                event_count += 1

            time.sleep(interval / 1000.0)

        if last_rowid is not None and last_ts is not None:
            now = datetime.now(timezone.utc)
            duration_secs = int((now - last_ts).total_seconds())
            if duration_secs <= 0:
                duration_secs = 1
            cursor.execute(
                "UPDATE eventmodel SET duration = ? WHERE rowid = ?",
                (duration_secs, last_rowid)
            )
            conn.commit()

        conn.close()
        logging.info(f"Recorded {event_count} events")
        return 0
    except Exception as e:
        logging.error(f"Fatal error: {e}")
        return 1

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", type=int, default=300)
    parser.add_argument("--interval", type=int, default=1000)
    args = parser.parse_args()
    sys.exit(capture_windows(args.duration, args.interval))

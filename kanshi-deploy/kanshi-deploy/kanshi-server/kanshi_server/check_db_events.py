import sqlite3
from pathlib import Path
import os
from datetime import datetime, timezone

DATA_DIR = Path(os.environ.get("LOCALAPPDATA", "")) / "kanshi" / "kanshi" / "kanshi-server"
DB_PATH = DATA_DIR / "peewee-sqlite.v2.db"

conn = sqlite3.connect(str(DB_PATH))
cursor = conn.cursor()

# Get all window capture events for today
cursor.execute("""
    SELECT 
        b.id as bucket_id,
        e.timestamp,
        e.duration,
        e.datastr
    FROM eventmodel e
    JOIN bucketmodel b ON e.bucket_id = b.rowid
    WHERE b.type = 'currentwindow' 
      AND e.timestamp >= '2026-04-28'
    ORDER BY e.timestamp
    LIMIT 50
""")

rows = cursor.fetchall()
print(f"Total window capture events for 2026-04-28: {len(rows)}\n")

total_duration = 0
for i, (bucket_id, timestamp, duration, datastr) in enumerate(rows, 1):
    print(f"{i:2d}. TS: {timestamp}  |  Duration: {duration:3d}s  |  Data: {datastr}")
    total_duration += duration

print(f"\nSum of all durations: {total_duration} seconds = {total_duration // 60}m {total_duration % 60}s")

conn.close()

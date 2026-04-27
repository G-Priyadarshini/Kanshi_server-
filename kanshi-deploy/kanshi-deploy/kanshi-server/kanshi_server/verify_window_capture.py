import json
import os
import sqlite3
import socket
import platform
from datetime import date, timedelta
from pathlib import Path

def get_db_path() -> Path:
    if platform.system() == 'Windows':
        return Path(os.environ.get('LOCALAPPDATA', '')) / 'kanshi' / 'kanshi' / 'kanshi-server' / 'peewee-sqlite.v2.db'
    return Path.home() / '.local' / 'share' / 'kanshi' / 'kanshi-server' / 'peewee-sqlite.v2.db'


def main() -> int:
    db = get_db_path()
    print('DB path:', db)
    print('Exists:', db.exists())
    if not db.exists():
        return 1

    conn = sqlite3.connect(str(db))
    cursor = conn.cursor()

    cursor.execute('SELECT COUNT(*) FROM bucketmodel')
    print('bucketmodel rows:', cursor.fetchone()[0])
    cursor.execute('SELECT COUNT(*) FROM eventmodel')
    print('eventmodel rows:', cursor.fetchone()[0])

    hostname = socket.gethostname()
    nid = f'kanshi-watcher-window_{hostname}'
    print('\nExpected window-capture bucket id:', nid)

    cursor.execute('SELECT rowid, id, type, hostname, client FROM bucketmodel WHERE id = ?', (nid,))
    bucket = cursor.fetchone()
    if not bucket:
        print('Window capture bucket not found.')
        conn.close()
        return 1

    print('Window capture bucket:', bucket)

    cursor.execute('SELECT rowid, bucket_id, timestamp, duration, datastr FROM eventmodel WHERE bucket_id = ? ORDER BY rowid DESC LIMIT 50', (bucket[0],))
    rows = cursor.fetchall()
    print('Recent window-capture events:', len(rows))
    for row in rows:
        rowid, bucket_id, ts, duration, datastr = row
        try:
            data = json.loads(datastr or '{}')
        except Exception:
            data = {}
        app = data.get('app')
        title = data.get('title')
        print(rowid, duration, ts, app, title[:60] if title else '')

    today = date.today().isoformat()
    cursor.execute(
        'SELECT COUNT(*) FROM eventmodel WHERE bucket_id = ? AND substr(timestamp, 1, 10) = ?',
        (bucket[0], today)
    )
    print('\nEvents today:', cursor.fetchone()[0])

    conn.close()
    return 0

if __name__ == '__main__':
    raise SystemExit(main())

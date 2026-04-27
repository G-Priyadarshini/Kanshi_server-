import os
import sqlite3
import platform
from pathlib import Path

local = os.environ.get('LOCALAPPDATA', '')
if platform.system() == 'Windows':
    db = Path(local) / 'kanshi' / 'kanshi' / 'kanshi-server' / 'peewee-sqlite.v2.db'
else:
    db = Path.home() / '.local' / 'share' / 'kanshi' / 'kanshi-server' / 'peewee-sqlite.v2.db'
print('DB', db)
print('exists', db.exists())
if not db.exists():
    raise SystemExit(1)
conn = sqlite3.connect(str(db))
c = conn.cursor()
for t in ['bucketmodel', 'eventmodel']:
    try:
        c.execute(f'SELECT count(*) FROM {t}')
        print(t, c.fetchone()[0])
    except Exception as e:
        print('ERR', t, e)
print('\nbucket sample:')
c.execute('SELECT rowid, id, type, hostname, client FROM bucketmodel LIMIT 20')
for r in c.fetchall():
    print(r)
print('\nevent sample:')
c.execute('SELECT rowid, bucket_id, timestamp, duration, datastr FROM eventmodel ORDER BY rowid DESC LIMIT 20')
for r in c.fetchall():
    print(r)
conn.close()

#!/usr/bin/env python
"""Generate and save the encryption key for KanshiReports."""

from cryptography.fernet import Fernet
from pathlib import Path
import os

# Determine the correct Documents folder (OneDrive or local)
def get_documents_dir():
    import platform
    if platform.system() == "Windows":
        onedrive = os.environ.get("OneDrive", "")
        if onedrive:
            od_docs = Path(onedrive) / "Documents"
            if od_docs.exists():
                return od_docs
    return Path.home() / "Documents"

# Create key directory and file
docs_dir = get_documents_dir()
key_dir = docs_dir / "KanshiReports"
key_dir.mkdir(parents=True, exist_ok=True)

key_path = key_dir / ".key"

# Generate and save the key
key = Fernet.generate_key()
with open(key_path, "wb") as f:
    f.write(key)

print(f"✓ Key generated successfully!")
print(f"✓ Saved to: {key_path}")
print(f"")
print(f"You can now run: python setup_and_run.py")

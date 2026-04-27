import sys
import os
from datetime import date

os.chdir(r'C:\Users\Priya Darshini\Desktop\kanshi-deploy (2)\kanshi-deploy\kanshi-deploy\kanshi-server\kanshi_server')
sys.path.insert(0, os.getcwd())

from capture_windows import capture_windows
from setup_and_run import collect_and_send_report

print("=" * 60)
print("Running capture for 30 seconds...")
print("=" * 60)
result = capture_windows(duration=30, interval=1000)
print(f"Capture result: {result}\n")

# Use today's date for the report (same as when capture runs)
today = str(date.today())
print("=" * 60)
print(f"Generating report for {today}...")
print("=" * 60)
result = collect_and_send_report('LAPTOP-Q2S1QR7J', today)
print(f"Report result: {result}")

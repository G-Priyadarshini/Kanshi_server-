@echo off
REM Install the daily report task for this user.
REM Run this file as Administrator to register the scheduled task.

powershell -NoProfile -Command "If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) { Write-Host 'ERROR: Please run this script as Administrator.'; exit 1 }"
if %errorlevel% neq 0 pause & exit /b 1

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ScriptDir = '%~dp0'; " ^
  "$setupScript = Join-Path $ScriptDir 'setup_and_run.py'; " ^
  "$Python = 'C:\\Program Files\\Python314\\python.exe'; " ^
  "$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest; " ^
  "$NightAction = New-ScheduledTaskAction -Execute $Python -Argument ('"' + $setupScript + '" --send-night'); " ^
  "$DayAction   = New-ScheduledTaskAction -Execute $Python -Argument ('"' + $setupScript + '" --send-day'); " ^
  "$NightTrigger = New-ScheduledTaskTrigger -Daily -At 6:00AM; " ^
  "$DayTrigger   = New-ScheduledTaskTrigger -Daily -At 11:55PM; " ^
  "$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -RestartCount 0; " ^
  "Get-ScheduledTask -TaskName 'KanshiReportSendLogon' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue; " ^
  "Get-ScheduledTask -TaskName 'KanshiReportSendNight' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue; " ^
  "Get-ScheduledTask -TaskName 'KanshiReportSendDay' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue; " ^
  "Register-ScheduledTask -TaskName 'KanshiReportSendNight' -Action $NightAction -Trigger $NightTrigger -Settings $Settings -Principal $Principal | Out-Null; " ^
  "Register-ScheduledTask -TaskName 'KanshiReportSendDay' -Action $DayAction -Trigger $DayTrigger -Settings $Settings -Principal $Principal | Out-Null; " ^
  "Get-ScheduledTask -TaskName 'KanshiReportSendNight','KanshiReportSendDay' | Select-Object TaskName, State"

echo [OK] Scheduled tasks created successfully!
echo A nightly report will be generated each morning for yesterday,
echo and a day report will be generated each night for today.

echo Task Details:
powershell -NoProfile -Command "Get-ScheduledTask -TaskName 'KanshiReportSendNight','KanshiReportSendDay' | Select-Object TaskName, State"

pause


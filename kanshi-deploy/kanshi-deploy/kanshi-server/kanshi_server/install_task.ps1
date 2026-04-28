# Kanshi Task Installer
# Run ONCE on the employee machine as Administrator.
# Creates THREE scheduled tasks:
#   1. KanshiAgent       - starts the recording agent at every login (silent)
#   2. KanshiDailyReport - sends encrypted daily report to admin at 11 PM
#   3. KanshiWindowCapture - captures active window usage hourly

$ServerUrl = "http://192.168.1.133:5700/api/reports/upload"

$PythonW = (Get-Command pythonw.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
if (-not $PythonW) { $PythonW = (Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source) }
if (-not $PythonW) { Write-Error "Python not found."; exit 1 }

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ScriptPath = Join-Path $ScriptDir "setup_and_run.py"
if (-not (Test-Path $ScriptPath)) { Write-Error "setup_and_run.py not found at: $ScriptPath"; exit 1 }

$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

# Task 1: KanshiAgent - start recording at every login
$existing = Get-ScheduledTask -TaskName "KanshiAgent" -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName "KanshiAgent" -Confirm:$false }

Register-ScheduledTask -TaskName "KanshiAgent" -Principal $Principal `
    -Action   (New-ScheduledTaskAction -Execute $PythonW -Argument "`"$ScriptPath`" --server" -WorkingDirectory $ScriptDir) `
    -Trigger  (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) `
    -Settings (New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)) | Out-Null

Write-Host "[OK] KanshiAgent created - starts recording at every login"

# Task 2: KanshiDailyReport - send report to admin at 11 PM
$existing = Get-ScheduledTask -TaskName "KanshiDailyReport" -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName "KanshiDailyReport" -Confirm:$false }

Register-ScheduledTask -TaskName "KanshiDailyReport" -Principal $Principal `
    -Action   (New-ScheduledTaskAction -Execute $PythonW -Argument "`"$ScriptPath`" --send-today `"$ServerUrl`"" -WorkingDirectory $ScriptDir) `
    -Trigger  @(
        (New-ScheduledTaskTrigger -Daily -At "23:00");
        (New-ScheduledTaskTrigger -Daily -At "07:00")
    ) `
    -Settings (New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -StartWhenAvailable -RunOnlyIfNetworkAvailable) | Out-Null

Write-Host "[OK] KanshiDailyReport created - sends report daily at 11:00 PM"
Write-Host "     Server: $ServerUrl"
Write-Host ""
Write-Host "Test immediately: Start-ScheduledTask -TaskName 'KanshiDailyReport'"

# Task 3: KanshiWindowCapture - capture active window/app usage hourly with periodic snapshots
$windowScript = Join-Path $ScriptDir "capture_windows.py"
$existing = Get-ScheduledTask -TaskName "KanshiWindowCapture" -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName "KanshiWindowCapture" -Confirm:$false }

Register-ScheduledTask -TaskName "KanshiWindowCapture" -Principal $Principal `
    -Action (New-ScheduledTaskAction -Execute $PythonW -Argument "`"$windowScript`" --duration 3300 --interval 1000 --snapshot-interval 60" -WorkingDirectory $ScriptDir) `
    -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)) `
    -Settings (New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)) | Out-Null

Write-Host "[OK] KanshiWindowCapture created - captures windows hourly with 60-second snapshots"
Write-Host "     Script: $windowScript"
Write-Host "     Duration: 55 minutes per hour (3300s) with 60-second snapshots"
Write-Host "     First run: in 2 minutes, then every 1 hour for 365 days"
Write-Host ""
Write-Host "Test immediately: Start-ScheduledTask -TaskName 'KanshiWindowCapture'"

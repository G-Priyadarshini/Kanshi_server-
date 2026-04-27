# Add KanshiWindowCapture Task
# Creates a scheduled task to run window capture every hour without requiring elevation

$PythonW = (Get-Command pythonw.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
if (-not $PythonW) { $PythonW = (Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source) }
if (-not $PythonW) { Write-Error "Python not found."; exit 1 }

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ScriptPath = Join-Path $ScriptDir "capture_windows.py"
if (-not (Test-Path $ScriptPath)) { Write-Error "capture_windows.py not found at: $ScriptPath"; exit 1 }

# Task: KanshiWindowCapture - run once in 2 minutes, then repeat hourly for 1 year
$existing = Get-ScheduledTask -TaskName "KanshiWindowCapture" -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName "KanshiWindowCapture" -Confirm:$false }

$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$action = New-ScheduledTaskAction -Execute $PythonW -Argument "`"$ScriptPath`" --duration 3300 --interval 1000" -WorkingDirectory $ScriptDir
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "KanshiWindowCapture" -Action $action -Trigger $trigger -Principal $Principal -Settings $settings | Out-Null

Write-Host "[OK] KanshiWindowCapture created - captures windows hourly"
Write-Host "     Script: $ScriptPath"
Write-Host "     First run: in 2 minutes, then every 1 hour for 365 days"
Write-Host ""
Write-Host "Test immediately: Start-ScheduledTask -TaskName 'KanshiWindowCapture'"
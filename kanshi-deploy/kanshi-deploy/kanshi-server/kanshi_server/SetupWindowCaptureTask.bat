@echo off
REM Run this file as Administrator to create the KanshiWindowCapture scheduled task
REM Right-click this file and select "Run as administrator"

cd /d "C:\Users\Priya Darshini\Desktop\kanshi-deploy (2)\kanshi-deploy\kanshi-deploy\kanshi-server\kanshi_server"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ScriptDir = 'C:\Users\Priya Darshini\Desktop\kanshi-deploy (2)\kanshi-deploy\kanshi-deploy\kanshi-server\kanshi_server'; " ^
  "$windowScript = Join-Path $ScriptDir 'capture_windows.py'; " ^
  "$PythonW = 'C:\Program Files\Python314\pythonw.exe'; " ^
  "$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest; " ^
  "$existing = Get-ScheduledTask -TaskName 'KanshiWindowCapture' -ErrorAction SilentlyContinue; " ^
  "if ($existing) { Unregister-ScheduledTask -TaskName 'KanshiWindowCapture' -Confirm:$false; Write-Host 'Removed old task' }; " ^
  "Register-ScheduledTask -TaskName 'KanshiWindowCapture' -Principal $Principal " ^
  "-Action (New-ScheduledTaskAction -Execute $PythonW -Argument '`"`"$windowScript`"`" --duration 3300 --interval 1000 --snapshot-interval 60' -WorkingDirectory $ScriptDir) " ^
  "-Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)) " ^
  "-Settings (New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)) | Out-Null; " ^
  "Write-Host '[OK] KanshiWindowCapture task created successfully!'; " ^
  "Write-Host ''; " ^
  "Write-Host 'Task Details:'; " ^
  "Get-ScheduledTask -TaskName 'KanshiWindowCapture' | Select-Object TaskName, State, @{N='Next Run';E={$_.Triggers[0].StartBoundary}}"

pause

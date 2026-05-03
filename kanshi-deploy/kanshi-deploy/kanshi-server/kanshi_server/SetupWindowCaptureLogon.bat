@echo off
REM Run this file as Administrator to set up window capture on user logon
REM Right-click this file and select "Run as administrator"

cd /d "C:\Users\Priya Darshini\Desktop\kanshi-deploy (2)\kanshi-deploy\kanshi-deploy\kanshi-server\kanshi_server"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ScriptDir = 'C:\Users\Priya Darshini\Desktop\kanshi-deploy (2)\kanshi-deploy\kanshi-deploy\kanshi-server\kanshi_server'; " ^
  "$windowScript = Join-Path $ScriptDir 'capture_windows.py'; " ^
  "$Python = 'C:\Program Files\Python314\python.exe'; " ^
  "$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest; " ^
  "$existing = Get-ScheduledTask -TaskName 'KanshiWindowCaptureLogon' -ErrorAction SilentlyContinue; " ^
  "if ($existing) { Unregister-ScheduledTask -TaskName 'KanshiWindowCaptureLogon' -Confirm:$false; Write-Host 'Removed old logon task' }; " ^
  "$Action = New-ScheduledTaskAction -Execute $Python -Argument ('\"' + $windowScript + '\" --duration 86400 --interval 1000') -WorkingDirectory $ScriptDir; " ^
  "$Trigger = New-ScheduledTaskTrigger -AtLogon; " ^
  "$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 24) -RestartCount 0; " ^
  "Register-ScheduledTask -TaskName 'KanshiWindowCaptureLogon' -Principal $Principal -Action $Action -Trigger $Trigger -Settings $Settings | Out-Null; " ^
  "Write-Host '[OK] KanshiWindowCaptureLogon task created successfully!'; " ^
  "Write-Host 'Task will start capturing data when you log in'; " ^
  "Write-Host ''; " ^
  "Write-Host 'Task Details:'; " ^
  "Get-ScheduledTask -TaskName 'KanshiWindowCaptureLogon' | Select-Object TaskName, State"

pause

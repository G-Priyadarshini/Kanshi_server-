# Create KanshiWindowCapture task with periodic snapshots
# Run this as Administrator

$ScriptDir = "C:\Users\Priya Darshini\Desktop\kanshi-deploy (2)\kanshi-deploy\kanshi-deploy\kanshi-server\kanshi_server"
$windowScript = Join-Path $ScriptDir "capture_windows.py"
$PythonW = "C:\Program Files\Python314\pythonw.exe"

# Check if script exists
if (-not (Test-Path $windowScript)) { 
    Write-Error "capture_windows.py not found at: $windowScript"
    exit 1 
}

$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

# Remove existing task if it exists
$existing = Get-ScheduledTask -TaskName "KanshiWindowCapture" -ErrorAction SilentlyContinue
if ($existing) { 
    Write-Host "Removing existing KanshiWindowCapture task..."
    Unregister-ScheduledTask -TaskName "KanshiWindowCapture" -Confirm:$false
}

# Create new task: runs 55 minutes per hour with 60-second periodic snapshots
Register-ScheduledTask -TaskName "KanshiWindowCapture" -Principal $Principal `
    -Action (New-ScheduledTaskAction -Execute $PythonW -Argument "`"$windowScript`" --duration 3300 --interval 1000 --snapshot-interval 60" -WorkingDirectory $ScriptDir) `
    -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)) `
    -Settings (New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)) | Out-Null

Write-Host "[OK] KanshiWindowCapture task created successfully!"
Write-Host "     Duration: 55 minutes per hour (3300s) with 60-second snapshots"
Write-Host "     Starts: in 2 minutes"
Write-Host "     Repeats: every 1 hour for 365 days"
Write-Host ""
Write-Host "To test immediately, run:"
Write-Host "  Start-ScheduledTask -TaskName 'KanshiWindowCapture'"

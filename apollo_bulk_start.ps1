[string]$exePath = "C:\Program Files\Apollo\sunshine.exe"
[string]$apolloDirectory = "C:\Program Files\Apollo\"

[string]$workingDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
[string[]]$exeParams = @(".\config\sunshine_1.conf", ".\config\sunshine_2.conf", ".\config\sunshine_3.conf")

[string]$ahkExe = "C:\Program Files\AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe"
[string]$ahkScript = "$workingDirectory\SyncMasterVolume.ahk"

# Function to kill all processes named sunshine.exe
function Kill-SunshineProcesses {
    Write-Host "Checking for existing sunshine.exe processes..."
    try {
        $processes = Get-Process -Name "sunshine" -ErrorAction SilentlyContinue
        if ($processes) {
            foreach ($process in $processes) {
                try {
                    Write-Host "Killing process ID: $($process.Id)"
                    Stop-Process -Id $process.Id -Force
                } catch {
                    Write-Host "Failed to kill process ID: $($process.Id). Error: $_"
                }
            }
        } else {
            Write-Host "No sunshine.exe processes found."
        }
    } catch {
        Write-Host "Error checking processes: $_"
    }
}
function Kill-AHKProcess {
    Write-Host "Checking for existing sunshine.exe processes..."
    try {
        $processes = Get-Process -Name "AutoHotkeyU64" -ErrorAction SilentlyContinue
        if ($processes) {
            foreach ($process in $processes) {
                try {
                    Write-Host "Killing process ID: $($process.Id)"
                    Stop-Process -Id $process.Id -Force
                } catch {
                    Write-Host "Failed to kill process ID: $($process.Id). Error: $_"
                }
            }
        } else {
            Write-Host "No AutoHotkeyU64.exe processes found."
        }
    } catch {
        Write-Host "Error checking processes: $_"
    }
}
# Kill existing sunshine.exe processes
Write-Host "Step 1: Killing existing sunshine processes."
Kill-SunshineProcesses
# Kill existing AutoHotkey processes
Write-Host "Step 2: Killing existing AutoHotkey processes."
Kill-AHKProcess
# Debug the input parameters
Write-Host "Executable path: $exePath"
Write-Host "Working directory: $workingDirectory"
Write-Host "Executable parameters: $exeParams"

# Generate and execute commands dynamically
Write-Host "Step 3: Executing commands..."
foreach ($param in $exeParams) {
    $fullCommand = "$exePath $param"
    Write-Host "Executing command: $fullCommand"
    try {
        Start-Job -ScriptBlock {
            param ($exePath, $param, $apolloDirectory)
            Start-Process -FilePath $exePath `
                          -ArgumentList $param `
                          -WorkingDirectory $apolloDirectory `
                          -WindowStyle Hidden
        } -ArgumentList $exePath, $param, $apolloDirectory
        Start-Sleep -Milliseconds 500  # Optional: Add a delay to avoid conflicts
    } catch {
        Write-Host "Error executing command: $_"
    }
}

# Check for SyncVolume.ahk and execute if present
if (Test-Path $ahkScript) {
    Write-Host "SyncVolume.ahk found. Executing..."
    
    if (Test-Path $ahkExe) {
        try {
            Start-Process -FilePath $ahkExe -ArgumentList "`"$ahkScript`"" -WindowStyle Hidden 
            Write-Host "SyncVolume.ahk executed successfully."
        } catch {
            Write-Host "Error executing SyncVolume.ahk: $_"
        }
    } else {
        Write-Host "Error: AutoHotkey.exe not found at '$ahkExe'. Please check the installation path."
    }
} else {
    Write-Host "SyncVolume.ahk not found. Skipping execution."
}


Write-Host "Script execution completed. Waiting 5 seconds before exit..."
Start-Sleep -Seconds 5

Write-Host "Exiting script now."

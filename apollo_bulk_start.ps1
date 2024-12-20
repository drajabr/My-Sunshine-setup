[string]$exePath = "C:\Program Files\Apollo\sunshine.exe"
[string]$workingDirectory = "C:\Program Files\Apollo\"
[string[]]$exeParams = @(".\config\sunshine_1.conf", ".\config\sunshine_2.conf", ".\config\sunshine_3.conf")

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

# Kill existing sunshine.exe processes
Write-Host "Step 1: Killing existing sunshine processes."
Kill-SunshineProcesses

# Debug the input parameters
Write-Host "Executable path: $exePath"
Write-Host "Working directory: $workingDirectory"
Write-Host "Executable parameters: $exeParams"

# Generate and execute commands dynamically
Write-Host "Step 2: Executing commands..."
foreach ($param in $exeParams) {
    $fullCommand = "$exePath $param"
    Write-Host "Executing command: $fullCommand"
    try {
        Start-Job -ScriptBlock {
            param ($exePath, $param, $workingDirectory)
            Start-Process -FilePath $exePath `
                          -ArgumentList $param `
                          -WorkingDirectory $workingDirectory `
                          -WindowStyle Hidden
        } -ArgumentList $exePath, $param, $workingDirectory
        Start-Sleep -Milliseconds 500  # Optional: Add a delay to avoid conflicts
    } catch {
        Write-Host "Error executing command: $_"
    }
}

Write-Host "Script execution completed. Waiting 5 seconds before exit..."
Start-Sleep -Seconds 5

Write-Host "Exiting script now."

[string]$exePath = "C:\Program Files\Apollo\sunshine.exe"
[string]$workingDirectory = "C:\Program Files\Apollo\"
[string[]]$exeParams = @(".\config\sunshine_1.conf", ".\config\sunshine_2.conf", ".\config\sunshine_3.conf")

# Function to kill all processes named sunshine.exe
function Kill-SunshineProcesses {
    Write-Host "Checking for existing sunshine.exe processes..."
    $processes = Get-Process -Name "sunshine" -ErrorAction SilentlyContinue
    if ($processes) {
        foreach ($process in $processes) {
            Write-Host "Killing process ID: $($process.Id)"
            Stop-Process -Id $process.Id -Force
        }
    } else {
        Write-Host "No sunshine.exe processes found."
    }
}

# Kill existing sunshine.exe processes
Write-Host "Step 1: Killing existing sunshine processes."
Kill-SunshineProcesses

# Path to PsExec
$psexecPath = "C:\Tools\PSTools\PsExec.exe"
Write-Host "PsExec path: $psexecPath"

# Debug the input parameters
Write-Host "Executable path: $exePath"
Write-Host "Working directory: $workingDirectory"
Write-Host "Executable parameters: $exeParams"

# Generate commands dynamically
$commands = $exeParams | ForEach-Object {
    $command = "powershell -Command `"start '$exePath' '$_' -WorkingDirectory '$workingDirectory' -WindowStyle Hidden`""
    Write-Host "Generated command: $command"
    return $command
}

# Get the first non-zero session ID
Write-Host "Step 2: Getting session ID..."
$users = query user
$sessionId = $users | Select-String -Pattern "\s\d+\s" | ForEach-Object {
    $temp = $_.Matches.Value.Trim()
    if ($temp -ne '0') { 
        Write-Host "Found session ID: $temp"
        return $temp 
    }
} | Select-Object -First 1

if ($sessionId) {
    Write-Host "Using session ID: $sessionId"
} else {
    Write-Host "No valid session ID found! Exiting..."
    exit 1
}

# Execute each command
Write-Host "Step 3: Executing commands..."
foreach ($command in $commands) {
    Write-Host "Executing: $command"
    Start-Process -FilePath $psexecPath -ArgumentList "-accepteula -i $sessionId -s $command" -WindowStyle Hidden
    Start-Sleep -Seconds 0  # Optional: Add a delay to avoid conflicts
}

Write-Host "Script execution completed. Waiting 5 seconds before exit..."
Start-Sleep -Seconds 5

Write-Host "Exiting script now."

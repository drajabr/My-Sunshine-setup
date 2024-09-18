param (
    [string]$exePath = "C:\Program Files\Apollo\sunshine.exe",
    [string]$workingDirectory = "C:\Program Files\Apollo\",
    [string[]]$exeParams = @(".\config\sunshine_1.conf", ".\config\sunshine_2.conf", ".\config\sunshine_3.conf")
)


# Function to kill all processes named sunshine.exe
function Kill-SunshineProcesses {
    $processes = Get-Process -Name "sunshine" -ErrorAction SilentlyContinue
    foreach ($process in $processes) {
        Write-Host "Killing process ID: $($process.Id)"
        Stop-Process -Id $process.Id -Force
    }
}

# Kill existing sunshine.exe processes
Kill-SunshineProcesses


# Path to PsExec
$psexecPath = "C:\Tools\PSTools\PsExec.exe"

# Generate commands dynamically
$commands = $exeParams | ForEach-Object {
    "powershell -Command `"start '$exePath' '$_' -WorkingDirectory '$workingDirectory' -WindowStyle Hidden`""
}

# Get the first non-zero session ID
$users = query user
$sessionId = $users | Select-String -Pattern "\s\d+\s" | ForEach-Object {
    $temp = $_.Matches.Value.Trim()
    if ($temp -ne '0') { return $temp }
} | Select-Object -First 1

# Execute each command
foreach ($command in $commands) {
    Start-Process -FilePath $psexecPath -ArgumentList "-accepteula -i $sessionId -s $command" -WindowStyle Hidden
    Start-Sleep -Seconds 0  # Optional: Add a delay to avoid conflicts
}

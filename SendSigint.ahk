; SendSigint.ahk
#NoTrayIcon
SetWorkingDir %A_ScriptDir%
logFilePath := A_ScriptDir . "\debug_log.txt"
debugLevel := 1

; Get the PID and log file path from the command line arguments
pid := A_Args[1]

DllCall("AttachConsole", "uint", pid)
LogMessage(1, "HELPER SCRIPT: Sending SIGINT to PID: " . pid)
DllCall("GenerateConsoleCtrlEvent", "uint", 0, "uint", 0)
LogMessage(2, "Freeing console from PID: " . pid)
DllCall("FreeConsole")

ExitApp

LogMessage(level, message) {
    global logFilePath, debugLevel
    if (level <= debugLevel) {
        FileAppend, %A_Now% - %message%`n, %logFilePath%
    }
}

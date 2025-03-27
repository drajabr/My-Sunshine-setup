; SendSigint.ahk
#NoTrayIcon
SetWorkingDir %A_ScriptDir%


configFile := A_ScriptDir . "\vars.cfg"
config := {}

Loop, Read, %configFile%
{
    StringSplit, keyValue, A_LoopReadLine, =
    if (keyValue0 = 2)
    {
        config[keyValue1] := keyValue2
    }
}

debugLevel := config["debugLevel"]

if !debugLevel
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

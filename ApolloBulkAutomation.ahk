#Persistent
#NoEnv

SetWorkingDir %A_ScriptDir%
SetBatchLines, -1

#Include %A_ScriptDir%/VA.ahk

; conf and log file names (by default inside the config directory)
confFiles := ["sunshine_1.conf", "sunshine_2.conf", "sunshine_3.conf"]
logFiles := ["sunshine_1.log", "sunshine_2.log", "sunshine_3.log"]

; User-configurable booleans to enable/disable features
autoExitOnDisconnect := true
autoSyncVolume := true






; Paths, don't change unless you know what you're doing
exeDirectory := "C:\Program Files\Apollo"
confDirectory := "C:\Program Files\Apollo\config"



logFilePath := A_ScriptDir . "\debug_log.txt"
debugLevel := 1
exePath := exeDirectory . "\sunshine.exe"
firstRun := true




LogMessage(level, message) {
    global logFilePath, debugLevel
    if (level <= debugLevel) {
        FileAppend, %A_Now% - %message%`n, %logFilePath%
    }
}

BulkStartApollo() {
    global exePath, exeDirectory, confDirectory, confFiles, pids, debugLevel, firstRun
    processKilled := false
    LogMessage(2, "Starting BulkStartApollo()")

    if (firstRun) {
        LogMessage(1, "First run of the script")
        firstRun := false
    }

    pids := []
    Loop {
        Process, Exist, sunshine.exe
        if (ErrorLevel = 0)
            break
        pids.Push(ErrorLevel)
        Process, Close, %ErrorLevel%
    }

    loggedPIDs := {}

    for index, pid in pids {
        if (!loggedPIDs.HasKey(pid)) {
            LogMessage(1, "Attempting to terminate existing process with PID: " . pid)
            loggedPIDs[pid] := true
        }
        RunWait, % "SendSigint.ahk " . pid, , Hide
        Sleep, 100
        Process, Exist, %pid%
        if (ErrorLevel != 0) {
            LogMessage(0, "Failed to terminate process with PID: " . pid . ", attempting force kill")
            processKilled := true
            Process, Close, %pid%
            Sleep, 100
            Process, Exist, %pid%
            if (ErrorLevel != 0) {
                LogMessage(0, "Failed to force kill process with PID: " . pid)
                break
            }
        }
    }
    if (processKilled)
        Sleep, 3000

    pids := []

    Loop, % confFiles.MaxIndex() {
        param := confDirectory . "\" . confFiles[A_Index]
        LogMessage(1, "Starting new process with param: " . param)
        Run, "%exePath%" "%param%", %exeDirectory%, Hide, newPid
        pids[A_Index] := newPid
        LogMessage(1, "Started process with PID: " . newPid . " for param: " . param)
    }
    LogMessage(2, "BulkStartApollo() completed")
}

WatchLogFiles() {
    global exePath, logFiles, exeDirectory, confDirectory, confFiles, pids, debugLevel
    processKilled := false
    killedIndexes := []
    LogMessage(2, "Starting WatchLogFiles()")

    static lastReadPositions := {}
    Loop, % logFiles.MaxIndex() {
        logFile := confDirectory . "\" . logFiles[A_Index]
        if (!lastReadPositions.HasKey(logFile)) {
            lastReadPositions[logFile] := 0
        }
        FileGetSize, fileSize, %logFile%
        if (fileSize > lastReadPositions[logFile]) {
            FileRead, logContent, %logFile%
            logContent := SubStr(logContent, lastReadPositions[logFile] + 1)
            lastReadPositions[logFile] := fileSize
            LogMessage(2, "Checking log file: " . logFile)
            if InStr(logContent, "CLIENT DISCONNECTED") {
                pid := pids[A_Index]
                if (pid) {
                    LogMessage(1, "Found 'CLIENT DISCONNECTED' in log file: " . logFile . " for PID: " . pid)
                    RunWait, % "SendSigint.ahk " . pid, , Hide
                    processKilled := true
                    killedIndexes.Push(A_Index)
                }
            }
        }
    }
    if (processKilled) {
        Sleep, 1000
        LogMessage(1, "Processes terminated, restarting again")
        for index, killedIndex in killedIndexes {
            param := confDirectory . "\" . confFiles[killedIndex]
            LogMessage(1, "Restarting process with param: " . param)
            Run, "%exePath%" "%param%", %exeDirectory%, Hide, newPid
            pids[killedIndex] := newPid
            LogMessage(1, "Restarted process with PID: " . newPid . " for param: " . param)
        }
    } else {
        LogMessage(2, "No process sent SIGINT")
    }
    LogMessage(2, "WatchLogFiles() completed")
}

SyncVolume() {
    global pids
    LogMessage(2, "Starting SyncVolume()")

    if (!pids || pids.MaxIndex() = 0)
        return

    static lastVolume := -1
    static lastMute := -1

    masterVolume := VA_GetMasterVolume()
    isMuted := VA_GetMasterMute()

    if (masterVolume != lastVolume || isMuted != lastMute) {
        LogMessage(2, "Master volume changed to: " . masterVolume)
        LogMessage(2, "Master mute status changed to: " . isMuted)

        for index, PID in pids {
            VA_SetAppVolume(PID, masterVolume)
            LogMessage(2, "Set volume for PID: " . PID . " to " . masterVolume)
            if (isMuted)
                VA_SetAppMute(PID, 1)
            else
                VA_SetAppMute(PID, 0)
            LogMessage(1, "Set mute status for PID: " . PID . " to " . isMuted)
        }

        lastVolume := masterVolume
        lastMute := isMuted
    }
    LogMessage(2, "SyncVolume() completed")
}

ScriptPath := A_ScriptFullPath

LogMessage(2, "Script started")
BulkStartApollo()

if (autoExitOnDisconnect) {
    SetTimer, WatchLogFiles, 100
}

if (autoSyncVolume) {
    SetTimer, SyncVolume, 100
}

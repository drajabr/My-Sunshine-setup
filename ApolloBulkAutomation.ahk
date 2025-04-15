#Persistent
#NoEnv
#Requires AutoHotkey v1.1.33+

SetWorkingDir %A_ScriptDir%
SetBatchLines, -1

#Include %A_ScriptDir%/VA.ahk

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

; Access the configuration values
autoExitOnDisconnect := config["autoExitOnDisconnect"]
autoSyncVolume := config["autoSyncVolume"]
autoCaptureAndroidMic := config["autoCaptureAndroidMic"]
androidMicDeviceID := config["androidMicDeviceID"]
autoStartAndroidCamera := config["autoStartAndroidCamera"]
androidCamDeviceID := config["androidCamDeviceID"]
exeDirectory := config["exeDirectory"]
confDirectory := config["confDirectory"]
platformToolsDirectory := config["platformToolsDirectory"]
debugLevel := config["debugLevel"]

; Parse confFiles and logFiles as arrays
confFiles := ParseArray(config["confFiles"])
logFiles := ParseArray(config["logFiles"])
; Default values if not overridden by config.txt
if !confFiles
    confFiles := ["sunshine.conf"]
if !logFiles
    logFiles := ["sunshine.log"]
if !autoExitOnDisconnect
    autoExitOnDisconnect := true
if !autoSyncVolume
    autoSyncVolume := true
if !autoCaptureAndroidMic
    autoCaptureAndroidMic := false
if !androidMicDeviceID
    androidMicDeviceID := ""
if !autoStartAndroidCamera
    autoStartAndroidCamera := true
if !androidCamDeviceID
    androidCamDeviceID := ""
if !exeDirectory
    exeDirectory := "C:\Program Files\Apollo"
if !confDirectory
    confDirectory := "C:\Program Files\Apollo\config"
if !platformToolsDirectory
    platformToolsDirectory := "C:\platform-tools"
if !debugLevel
    debugLevel := 1

logFilePath := A_ScriptDir . "\debug_log.txt"
apolloExePath := exeDirectory . "\sunshine.exe"
adbExePath := platformToolsDirectory . "\adb.exe"
scrCpyPath := platformToolsDirectory . "\scrcpy.exe"


LogMessage(level, message) {
    global logFilePath, debugLevel
    if (level <= debugLevel) {
        FileAppend, %A_Now% - %message%`n, %logFilePath%
    }
}

ParseArray(str) {
    array := []
    Loop, Parse, str, `,
    {
        array.Push(A_LoopField)
    }
    return array
}
JoinArray(arr, delimiter) {
    result := ""
    Loop, % arr.MaxIndex() {
        result .= arr[A_Index] . (A_Index < arr.MaxIndex() ? delimiter : "")
    }
    return result
}

; https://www.autohotkey.com/boards/viewtopic.php?style=19&t=84976
CmdRetWithTimeout(sCmd, timeout, callBackFuncObj := "", encoding := "") {
    static HANDLE_FLAG_INHERIT := 0x00000001, flags := HANDLE_FLAG_INHERIT
        , STARTF_USESTDHANDLES := 0x100, CREATE_NO_WINDOW := 0x08000000

    (encoding = "" && encoding := "cp" . DllCall("GetOEMCP", "UInt"))
    DllCall("CreatePipe", "PtrP", hPipeRead, "PtrP", hPipeWrite, "Ptr", 0, "UInt", 0)
    DllCall("SetHandleInformation", "Ptr", hPipeWrite, "UInt", flags, "UInt", HANDLE_FLAG_INHERIT)

    VarSetCapacity(STARTUPINFO , siSize :=    A_PtrSize*4 + 4*8 + A_PtrSize*5, 0)
    NumPut(siSize              , STARTUPINFO)
    NumPut(STARTF_USESTDHANDLES, STARTUPINFO, A_PtrSize*4 + 4*7)
    NumPut(hPipeWrite          , STARTUPINFO, A_PtrSize*4 + 4*8 + A_PtrSize*3)
    NumPut(hPipeWrite          , STARTUPINFO, A_PtrSize*4 + 4*8 + A_PtrSize*4)

    VarSetCapacity(PROCESS_INFORMATION, A_PtrSize*2 + 4*2, 0)

    if !DllCall("CreateProcess", "Ptr", 0, "Str", sCmd, "Ptr", 0, "Ptr", 0, "UInt", true, "UInt", CREATE_NO_WINDOW
                              , "Ptr", 0, "Ptr", 0, "Ptr", &STARTUPINFO, "Ptr", &PROCESS_INFORMATION)
    {
        DllCall("CloseHandle", "Ptr", hPipeRead)
        DllCall("CloseHandle", "Ptr", hPipeWrite)
        throw "CreateProcess failed"
    }
    DllCall("CloseHandle", "Ptr", hPipeWrite)

    VarSetCapacity(sTemp, 4096), nSize := 0, sOutput := ""
    startTime := A_TickCount
    while (A_TickCount - startTime < timeout) {
        if DllCall("ReadFile", "Ptr", hPipeRead, "Ptr", &sTemp, "UInt", 4096, "UIntP", nSize, "UInt", 0) {
            sOutput .= stdOut := StrGet(&sTemp, nSize, encoding)
            ( callBackFuncObj && callBackFuncObj.Call(stdOut) )
        } else {
            break
        }
    }
    DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION))
    DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION, A_PtrSize))
    DllCall("CloseHandle", "Ptr", hPipeRead)
    return sOutput
}


; todo, single function to watch log files writing to global vars accessed by functions needing it, currently this causes issues or delays..

BulkStartApollo() {
    global apolloExePath, exeDirectory, confDirectory, logFiles, confFiles, pids, debugLevel, logFilePath
    static firstRunApollo := true
    processTerminated := false
    LogMessage(2, "Starting BulkStartApollo()")

    if (firstRunApollo) {
        ; Clear the log file before restarting
        logFile := confDirectory . "\" . logFiles[TerminatedIndexes[A_Index]]
        FileDelete, %logFilePath%
        FileAppend,, %logFilePath%  ; Create an empty log file
        LogMessage(1, "Cleared debug_logfile: " . logFilePath . " before starting")
        sleep, 100
        LogMessage(1, "First run of the script")
        firstRunApollo := false
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
        processTerminated := true
        Process, Exist, %pid%
    }
    if (processTerminated)
        Sleep, 3000
    pids := []

    Loop, % confFiles.MaxIndex() {
        ; Clear the log file before restarting
        logFile := confDirectory . "\" . logFiles[TerminatedIndexes[A_Index]]
        FileDelete, %logFile%
        FileAppend,, %logFile%  ; Create an empty log file
        LogMessage(1, "Cleared logfile: " . logFile . " before restarting")
        sleep, 100
        param := confDirectory . "\" . confFiles[A_Index]
        LogMessage(1, "Starting new process with param: " . param)
        Run, "%apolloExePath%" "%param%", %exeDirectory%, Hide, newPid
        pids[A_Index] := newPid
        LogMessage(1, "Started process with PID: " . newPid . " for param: " . param)
    }
    LogMessage(2, "BulkStartApollo() completed")
}

WatchLogFiles() {
    global apolloExePath, logFiles, exeDirectory, confDirectory, confFiles, pids, debugLevel
    processTerminated := false
    TerminatedIndexes := []
    static running := False
    
    if (running)
        return 
    running := True
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
                    processTerminated := true
                    TerminatedIndexes.Push(A_Index)
                }
            }
        }
    }
    if (processTerminated) {
        Sleep, 500
        LogMessage(1, "Processes terminated, restarting again")
        Loop, % TerminatedIndexes.MaxIndex() {
            ; Clear the log file before restarting
            logFile := confDirectory . "\" . logFiles[TerminatedIndexes[A_Index]]
            FileDelete, %logFile%
            FileAppend,, %logFile%  ; Create an empty log file
            LogMessage(1, "Cleared logfile: " . logFile . " before restarting")
            sleep, 100
            param := confDirectory . "\" . confFiles[TerminatedIndexes[A_Index]]
            LogMessage(1, "Restarting process with param: " . param)
            Run, "%apolloExePath%" "%param%", %exeDirectory%, Hide, newPid
            pids[TerminatedIndexes[A_Index]] := newPid
            LogMessage(1, "Restarted process with PID: " . newPid . " for param: " . param)
        }
        Sleep, 500
    } else {
        LogMessage(2, "No process sent SIGINT")
    }
    LogMessage(2, "WatchLogFiles() completed")
    running := False
}

SyncVolume() {
    global pids, logFiles, confDirectory, debugLevel
    static lastVolume := -1
    static lastMute := -1
    static lastReadPositions := {}

    static running := False
    if (running)
        return
    if (!pids || pids.MaxIndex() = 0)
        return
    LogMessage(2, "Starting SyncVolume()")
    running := True

    masterVolume := VA_GetMasterVolume()
    isMuted := VA_GetMasterMute()

    clientConnected := false

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
            if InStr(logContent, "Opus initialized") {
                LogMessage(1, "Found 'Opus initialized' in log file: " . logFile . " Syncing volume level")
                clientConnected := true
            }
            
        }
    }

    updatedVolumePIDs := []
    updatedMutePIDs := []
    if (clientConnected) {
        Loop, 60 {
            for index, PID in pids {
            VA_SetAppVolume(PID, masterVolume)
            if (isMuted != lastMute) 
                VA_SetAppMute(PID, isMuted ? 1 : 0)
            LogMessage(3, "Retrying to set volume/mute for PID: " . PID . " (Current Volume: " . currentVolume . ", Expected: " . masterVolume . ", Current Mute: " . currentMute . ", Expected: " . isMuted . ")")
            }
            Sleep, 100
        }
        for index, PID in pids {
            updatedVolumePIDs.Push(PID)
            updatedMutePIDs.Push(PID)
        }
        lastVolume := masterVolume
        lastMute := isMuted
        LogMessage(1, "Synced Volume: " . masterVolume . " for PIDs: " . JoinArray(updatedVolumePIDs, ", "))
        LogMessage(1, "Synced mute state: " . (isMuted ? "Muted" : "Unmuted") . " for PIDs: " . JoinArray(updatedMutePIDs, ", "))
    }
    else if ( isMuted != lastMute) {
        LogMessage(2, "Syncing mute settings")
        for index, PID in pids {
            if (isMuted != lastMute) 
                VA_SetAppMute(PID, isMuted ? 1 : 0)
            updatedMutePIDs.Push(PID)
        }
        lastMute := isMuted
    }
    else if ( masterVolume != lastVolume) {
        LogMessage(2, "Syncing volume settings")
        for index, PID in pids {
            VA_SetAppVolume(PID, masterVolume)
            updatedVolumePIDs.Push(PID)
        }
        lastVolume := masterVolume
    }

    if (updatedMutePIDs.MaxIndex() > 0) 
        LogMessage(1, "Sync mute state: " . (isMuted ? "Muted" : "Unmuted") . " for PIDs: " . JoinArray(updatedMutePIDs, ", "))
    if (updatedVolumePIDs.MaxIndex() > 0) 
        LogMessage(1, "Sync Volume: " . masterVolume . " for PIDs: " . JoinArray(updatedVolumePIDs, ", "))
    LogMessage(2, "Volume and mute settings synced for all updated processes")
    LogMessage(2, "SyncVolume() completed")
    running := False
}

MaintainMicConnectivity() {
    global adbExePath, scrCpyPath, androidMicDeviceID, micOutputDevice, LogMessage, CmdRetWithTimeout
    static lastStatus := "", firstRunMic := true, scrcpyPID := ""

    command := adbExePath . " devices"
    adbOutput := CmdRetWithTimeout(command, 3000) ; 3 seconds timeout

    ; Log the output
    LogMessage(3, "ADB Command: " command "`nADB Devices Output:`n" adbOutput)

    ; Check the device status
    deviceStatus := "disconnected"
    Loop, Parse, adbOutput, `n, `r
    {
        if (RegExMatch(A_LoopField, "^\s*" androidMicDeviceID "\s+device")) {
            deviceStatus := "connected"
            break
        }
    }
    if (deviceStatus != lastStatus) {
        pids := []
        Loop {
            Process, Exist, scrcpy.exe
            if (ErrorLevel = 0)
                break
            pids.Push(ErrorLevel)
            Process, Close, %ErrorLevel%
        }
        lastStatus := deviceStatus
    }
    if (deviceStatus = "connected") {
        ; Check if there are any existing scrcpy processes
        if (firstRunMic){
            if (pids.MaxIndex()>0){
                LogMessage(1, "Killing all existing scrcpy processes for the first run")
                for index, pid in pids {
                    LogMessage(1, "Attempting to terminate existing scrcpy process with PID: " . pid)
                    RunWait, %comspec% /c "taskkill /F /PID " pid,, Hide
                    Sleep, 100
                    Process, Exist, %pid%
                    if (ErrorLevel != 0)
                        LogMessage(0, "Failed to terminate scrcpy process with PID: " . pid)
                    else 
                        LogMessage(1, "Successfully terminated scrcpy process with PID: " . pid)
                }
            }
            else {
                LogMessage(1, "No existing scrcpy processes found for the first run")
            }
            firstRunMic := false
        }
        else { 
            if (!scrcpyPID){
                LogMessage(1, "Device is connected, Starting scrcpy process")
                Run, %comspec% /c ""%scrCpyPath%" -s %androidMicDeviceID% --no-video --no-window --audio-source=mic --window-borderless",, Hide, scrcpyPID
                ; Set the output audio device for the scrcpy process
                LogMessage(1, "Starting scrcpy with PID: " scrcpyPID " for device: " androidMicDeviceID)
                ;Sleep, 2000 ; Wait a moment for processes to be killed
                ;VA_SetAppVolume(scrcpyPID, micOutputDevice)
                ;LogMessage(2, "SetAppVolume called for PID: " scrcpyPID " with device: " micOutputDevice)
            }
            else {
                Process, Exist, scrcpy.exe
                if (ErrorLevel = 0){
                    LogMessage(1, "scrcpy proccess PID: " scrcpyPID " is no longer running! reviving next run" )
                    scrcpyPID := ""
                }
                else {
                    LogMessage(2, "scrcpy proccess already running with PID: " scrcpyPID)
                }
            }
        }
    } 
    else {
        If (scrcpyPID) {
            ; Kill the scrcpy process by PID if the device is disconnected
            LogMessage(1, "Device " androidMicDeviceID " disconnected, killing scrcpy process with PID: " scrcpyPID)
            Run, %comspec% /c "taskkill /F /PID " scrcpyPID,, Hide
            scrcpyPID := ""
        }
    }
}


LogMessage(1, "Script started at " . A_Now) 

BulkStartApollo()

if (autoExitOnDisconnect) 
    SetTimer, WatchLogFiles, 50

if (autoSyncVolume) 
    SetTimer, SyncVolume, 50

if (autoCaptureAndroidMic) 
    SetTimer, MaintainMicConnectivity, 50
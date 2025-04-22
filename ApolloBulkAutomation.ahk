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
autoReverseTethering := config["autoReverseTethering"]
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
    autoStartAndroidCamera := false
if !androidCamDeviceID
    androidCamDeviceID := ""
if !autoReverseTethering
    autoReverseTethering := false
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
gnirehtetExecPath := platformToolsDirectory . "\gnirehtet.exe"


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
CmdRetWithTimeout(sCmd, callBackFuncObj := "", encoding := ""){
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
      throw "CreateProcess is failed"
   }
   DllCall("CloseHandle", "Ptr", hPipeWrite)
   VarSetCapacity(sTemp, 4096), nSize := 0
   while DllCall("ReadFile", "Ptr", hPipeRead, "Ptr", &sTemp, "UInt", 4096, "UIntP", nSize, "UInt", 0) {
      sOutput .= stdOut := StrGet(&sTemp, nSize, encoding)
      ( callBackFuncObj && callBackFuncObj.Call(stdOut) )
   }
   DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION))
   DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION, A_PtrSize))
   DllCall("CloseHandle", "Ptr", hPipeRead)
   Return sOutput
}


; todo, single function to watch log files writing to global vars accessed by functions needing it, currently this causes issues or delays..

BulkStartApollo() {
    global apolloExePath, exeDirectory, confDirectory, logFiles, confFiles, pids, debugLevel, logFilePath
    static firstRunApollo := true
    processTerminated := false
    LogMessage(3, "Starting BulkStartApollo()")

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
        RunWait, %comspec% /c "tskill " pid,, Hide
        processTerminated := true
        Process, Exist, %pid%
    }
    if (processTerminated)
        Sleep, 3000
    pids := []

    Loop, % confFiles.MaxIndex() {
        ;logFile := confDirectory . "\" . logFiles[TerminatedIndexes[A_Index]]
        ;FileDelete, %logFile%
        ;FileAppend,, %logFile%  ; Create an empty log file
        ;LogMessage(1, "Cleared logfile: " . logFile . " before restarting")
        ;sleep, 100
        param := confDirectory . "\" . confFiles[A_Index]
        LogMessage(1, "Starting new process with param: " . param)
        Run, "%apolloExePath%" "%param%", %exeDirectory%, Hide, newPid
        pids[A_Index] := newPid
        LogMessage(1, "Started process with PID: " . newPid . " for param: " . param)
    }
    LogMessage(3, "BulkStartApollo() completed")
}

WatchLogFiles() {
    global apolloExePath, logFiles, exeDirectory, confDirectory, confFiles, pids, debugLevel
    processTerminated := false
    TerminatedIndexes := []
    static running := False
    
    if (running)
        return 
    running := True
    LogMessage(3, "Starting WatchLogFiles()")

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
                    RunWait, %comspec% /c "tskill " pid,, Hide
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
        LogMessage(3, "No process terminated")
    }
    LogMessage(3, "WatchLogFiles() completed")
    running := False
}

SyncVolume() {
    global pids, logFiles, confDirectory, debugLevel
    static lastVolume := -1
    static lastMute := -1

    static running := False
    if (running)
        return
    if (!pids || pids.MaxIndex() = 0)
        return
    LogMessage(3, "Starting SyncVolume()")
    running := True

    masterVolume := VA_GetMasterVolume()
    isMuted := VA_GetMasterMute()

    clientConnected := false
    
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
            if InStr(logContent, "CLIENT CONNECTED") {
                LogMessage(1, "Found 'CLIENT CONNECTED' in log file: " . logFile . " Syncing volume level")
                clientConnected := true
            }
        }
    }

    updatedVolumePIDs := []
    updatedMutePIDs := []

    if (clientConnected) {
        Loop, 150 {
            masterVolume := VA_GetMasterVolume()
            isMuted := VA_GetMasterMute()        
            for index, PID in pids {
            VA_SetAppVolume(PID, masterVolume)
            if (isMuted != lastMute) 
                VA_SetAppMute(PID, isMuted ? 1 : 0)
            LogMessage(3, "Retrying to set volume/mute for PID: " . PID . " (Current Volume: " . currentVolume . ", Expected: " . masterVolume . ", Current Mute: " . currentMute . ", Expected: " . isMuted . ")")
            }
            Sleep, 50
        }
        for index, PID in pids {
            updatedVolumePIDs.Push(PID)
            updatedMutePIDs.Push(PID)
        }
        lastVolume := masterVolume
        lastMute := isMuted
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
        LogMessage(1, "Synced mute state: " . (isMuted ? "Muted" : "Unmuted") . " for PIDs: " . JoinArray(updatedMutePIDs, ", "))
    if (updatedVolumePIDs.MaxIndex() > 0) 
        LogMessage(1, "Synced Volume: " . masterVolume . " for PIDs: " . JoinArray(updatedVolumePIDs, ", "))

    LogMessage(3, "Volume and mute settings synced for all updated processes")
    running := False
}

watchAndroidADBDevices(){
    global adbExePath, LogMessage, CmdRetWithTimeout, CurrentlyConnectedIDs
    static firstRun := true
    ;if (firstRun) {
        ;LogMessage(1, "First run of ADB watchdog killing previous ADB server")
        ;RunWait, %comspec% /c """" . adbExePath . """ kill-server",, Hide
        ;firstRun := false
;}
    command := adbExePath . " devices"
    adbOutput := CmdRetWithTimeout(command, 5000) ; 5 seconds timeout
    static lastConnectedIDs := {}

    CurrentlyConnectedIDs := {}

    Loop, Parse, adbOutput, `n, `r
    {
        if (RegExMatch(A_LoopField, "^\s*(\S+)\s+device", match)) {
            CurrentlyConnectedIDs[match1] := true
        }
    }

    ; Compare with the last connected IDs and log changes
    for deviceID in CurrentlyConnectedIDs {
        if (!lastConnectedIDs.HasKey(deviceID)) {
            LogMessage(1, "New device connected: " . deviceID)
        }
    }

    for deviceID in lastConnectedIDs {
        if (!CurrentlyConnectedIDs.HasKey(deviceID)) {
            LogMessage(1, "Device disconnected: " . deviceID)
        }
    }

    ; Update the last connected IDs
    lastConnectedIDs := CurrentlyConnectedIDs.Clone()
}


MaintainMicConnectivity() {
    global adbExePath, LogMessage, CurrentlyConnectedIDs, androidMicDeviceID, scrCpyPath
    static lastStatus := "", ShouldRunMic := true, scrcpyPID := "", consolePID := "", firstRun := true
     
    ; Kill any existing scrcpy.exe process on the first run
    if (firstRun) {
        Loop 10 {
            Process, Exist, scrcpy.exe
            if (ErrorLevel = 0)
                break
            LogMessage(2, "Terminating scrcpy process with PID: " . ErrorLevel)
            RunWait, %comspec% /c "tskill " ErrorLevel,, Hide
            Sleep, 50
        }
        firstRun := false
    }

    ; Determine device status
    deviceStatus := CurrentlyConnectedIDs.HasKey(androidMicDeviceID) ? "connected" : "disconnected"

    if (deviceStatus != lastStatus) {
        LogMessage(1, "Mic Device " androidMicDeviceID " status changed to: " deviceStatus)
        lastStatus := deviceStatus
    }

    if (deviceStatus = "connected") {
        if (ShouldRunMic) {
            RunWait, %comspec% /c ""%adbExePath%" -s %androidMicDeviceID% shell input keyevent KEYCODE_WAKEUP",, Hide
            Sleep, 50
            Run, %comspec% /c ""%scrCpyPath%" -s %androidMicDeviceID% --no-video --no-window --audio-source=mic --window-borderless",, Hide, consolePID
            Loop, 100 {
                Sleep, 100
                Process, Exist, scrcpy.exe
                if (ErrorLevel != 0) {
                    scrcpyPID := ErrorLevel
                    LogMessage(1, "Started scrcpy with PID: " scrcpyPID " for device: " androidMicDeviceID)
                    break
                }
            }
            if (!scrcpyPID) {
                LogMessage(0, "Failed to start scrcpy for device: " androidMicDeviceID)
                RunWait, %comspec% /c "tskill " consolePID,, Hide
            }
            ShouldRunMic := false
        } else {
            Process, Exist, %scrcpyPID%
            if (ErrorLevel = 0) {
                LogMessage(1, "scrcpy process " . scrcpyPID . " is not running, restarting.")
                ShouldRunMic := true
                scrcpyPID := ""
            }
        }
    } else if (scrcpyPID) {
        ; Terminate scrcpy process if the device is disconnected
        LogMessage(1, "Device " androidMicDeviceID " disconnected, terminating scrcpy process with PID: " scrcpyPID)
        RunWait, %comspec% /c "tskill " scrcpyPID,, Hide
        scrcpyPID := ""
        if (consolePID) {
            LogMessage(1, "Terminating residual console process with PID: " . consolePID)
            RunWait, %comspec% /c "tskill " consolePID,, Hide
            consolePID := ""
        }
    }
}
MaintainReverseTethering() {
    global gnirehtetExecPath, LogMessage, platformToolsDirectory
    static gnirehtetRelayPID := "", consolePID := "", lastStatus := ""

    SetWorkingDir, %platformToolsDirectory%
    Process, Exist, gnirehtet.exe
    gnirehtetRunning := (ErrorLevel != 0)

    if (gnirehtetRunning) {
        if (gnirehtetRelayPID != ErrorLevel) {
            gnirehtetRelayPID := ErrorLevel
            LogMessage(1, "gnirehtet relay process is already running with PID: " . gnirehtetRelayPID)
        }
    } else {
        LogMessage(1, "Starting gnirehtet relay process in autorun mode")
        Run, %comspec% /c ""%gnirehtetExecPath%" autorun",, Hide, consolePID
        Sleep, 500
        Process, Exist, gnirehtet.exe
        if (ErrorLevel != 0) {
            gnirehtetRelayPID := ErrorLevel
            LogMessage(1, "Started gnirehtet relay process with PID: " . gnirehtetRelayPID)
        } else {
            LogMessage(0, "Failed to start gnirehtet relay process")
            RunWait, %comspec% /c "tskill " consolePID,, Hide
        }
    }
}



LogMessage(1, "Script started at " . A_Now) 

BulkStartApollo()


;if (autoExitOnDisconnect || autoSyncVolume)
;    SetTimer, watchApolloLogfiles, 100

if (autoExitOnDisconnect) 
    SetTimer, WatchLogFiles, 100

if (autoSyncVolume) 
    SetTimer, SyncVolume, 100

if (autoReverseTethering || autoCaptureAndroidMic)
    SetTimer, watchAndroidADBDevices, 100

if (autoCaptureAndroidMic) 
    SetTimer, MaintainMicConnectivity, 100

if (autoReverseTethering) 
    SetTimer, MaintainReverseTethering, 100


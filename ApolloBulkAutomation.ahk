#Persistent
#NoEnv
#Requires AutoHotkey v1.1.33+

SetWorkingDir %A_ScriptDir%
SetBatchLines, -1

#Include %A_ScriptDir%\lib\VA.ahk ; Volume Automation library

configFile := A_ScriptDir . "\automation.config"
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


pidListFromName(name) {
    static wmi := ComObjGet("winmgmts:\\.\root\cimv2")
    
    if (name == "")
        return

    PIDs := []
    for Process in wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" name "'")
        PIDs.Push(Process.processId)

    return PIDs 
}

ArrayHasValue(array, value) {
    for index, item in array {
        if (item == value) {
            return true
        }
    }
    return false
}

global ConfiguredApolloPIDs := [], firstRunApollo := true

BulkStartApollo() {
    global apolloExePath, exeDirectory, confDirectory, logFiles, confFiles, debugLevel, logFilePath , ConfiguredApolloPIDs , firstRunApollo, processTerminated, processKilled, TerminatedPIDs
    static running := false
    if (running)
        return
    running := true
    LogMessage(3, "Starting BulkStartApollo()")
    ; Populate PIDs for every sunshine.exe process currently running
    CurrentPIDs := pidListFromName("sunshine.exe") 
    if (firstRunApollo) {
        Terminated := false, Killed := false
        ; Clear the log file before restarting
        logFile := confDirectory . "\" . logFiles[TerminatedIndexes[A_Index]]
        FileDelete, %logFilePath%
        FileAppend,, %logFilePath%  ; Create an empty log file
        LogMessage(1, "Cleared debug_logfile: " . logFilePath . " before starting")
        Sleep, 50
        Loop , % CurrentPIDs.MaxIndex() {
            pid := CurrentPIDs[A_Index]
            LogMessage(2, "Trying to terminate residual apollo process PID: " . pid)
            RunWait, %ComSpec% /c taskkill /PID %pid% /T /FI "SIGNAL=SIGINT",, Hide
            sleep, 50
            Process, Exist, %pid%
            if (ErrorLevel != 0) {
                LogMessage(1, "Failed to terminate residual process with PID: " . pid . " trying force kill")
                RunWait, %ComSpec% /c tskill %pid%,, Hide
                Sleep, 50
                Process, Exist, %pid%
                if (ErrorLevel != 0) {
                    LogMessage(1, "Failed to force kill residual process with PID: " . pid)
                } else {
                    LogMessage(1, "Force killed residual apollo process with PID: " . pid)
                    Killed := true
                }
            } else {
                LogMessage(1, "Terminated residual process with PID: " . pid)
                Terminated := true
            }
        }
        if (Killed)
            Sleep, 3000
        else if (Terminated)
            Sleep, 500
    } else if (CurrentPIDs.MaxIndex() > configuredApolloPIDs.MaxIndex()) {
        LogMessage(1, "Current PIDs: " . JoinArray(CurrentPIDs, ", "))
        LogMessage(1, "Configured PIDs: " . JoinArray(ConfiguredApolloPIDs, ", "))
        Loop, % CurrentPIDs.MaxIndex() {
            pid := CurrentPIDs[A_Index]
            LogMessage(2, "Checking if PID: " . pid . " is orphaned")
            if !(ArrayHasValue(ConfiguredApolloPIDs, pid)) {
                LogMessage(1, "Orphan Apollo process PID: " . pid . " is not started by script, trying to terminate it..")
                RunWait, %ComSpec% /c taskkill /PID %pid% /T /FI "SIGNAL=SIGINT",, Hide
                Sleep, 50
                Process, Exist, %pid%
                if (ErrorLevel != 0) {
                    LogMessage(1, "Failed to terminate orphan Apollo process PID: " . pid . " trying force kill")
                    RunWait, %ComSpec% /c tskill %pid%,, Hide
                    Sleep, 50
                    Process, Exist, %pid%
                    if (ErrorLevel != 0) {
                        LogMessage(1, "Failed to force kill orphan Apollo process PID: " . pid)
                    } else {
                        LogMessage(1, "Force killed orphan Apollo process PID: " . pid)
                    }
                } else {
                    LogMessage(1, "Terminated orphan Apollo process PID: " . pid . " successfully")
                }
            }
        }
    }
    Loop, % confFiles.MaxIndex() {
        ;logFile := confDirectory . "\" . logFiles[TerminatedIndexes[A_Index]]
        ;FileDelete, %logFile%
        ;FileAppend,, %logFile%  ; Create an empty log file
        ;LogMessage(1, "Cleared logfile: " . logFile . " before restarting")
        ;Sleep, 50
        param := confDirectory . "\" . confFiles[A_Index]
        if (firstRunApollo){
            LogMessage(1, "Starting Apollo instance: " . A_Index . " process with param: " . param)
            Run, "%apolloExePath%" "%param%", %exeDirectory%, Hide, newPid
            Sleep , 100
            Process, Exist, %newPid%
            if (ErrorLevel = 0) {
                LogMessage(1, "Failed to start Apollo instance: " . A_Index . " process with param: " . param)
            } else {
                ConfiguredApolloPIDs[A_Index] := newPid
                LogMessage(1, "Started Apollo instance: " . A_Index . " process with PID: " . newPid . " for param: " . param)
            }
        } else {
            pid := ConfiguredApolloPIDs[A_Index]
            Process, Exist, %pid%
            if (ErrorLevel = 0 || pid = "") {
                if (pid in TerminatedPIDs) {
                    LogMessage(1, "Apollo PID: " . pid . " instance: " . A_Index . " terminated by script for disconnection")
                    if (processKilled)
                        Sleep, 3000
                    else 
                        Sleep, 50
                    TerminatedPIDs.__Delete(pid)
                } else {
                    LogMessage(1, "Apollo PID: " . pid . " instance: " . JoinArray(TerminatedPIDs, ", ") . " terminated externally")
                }
                LogMessage(1, "Starting Apollo instance: " . A_Index . " process with param: " . param)
                Run, "%apolloExePath%" "%param%", %exeDirectory%, Hide, newPid
                Sleep , 100
                Process, Exist, %newPid%
                if (ErrorLevel = 0) {
                    LogMessage(1, "Failed to restart Apollo instance: " . A_Index . " process with param: " . param)
                } else {
                    LogMessage(1, "Restarted Apollo instance: " . A_Index . " successfully with new PID: " . newPid . " for param: " . param)
                    ConfiguredApolloPIDs[A_Index] := newPid
                }
            }
            else {
                LogMessage(2, "Checked Apollo instance: " . A_Index . " process with PID: " . pid . " is running okay")
            }
        }
    }
    if ((processTerminated || processKilled) && TerminatedPIDs.MaxIndex() = 0) {
        processKilled := false
        processTerminated := false
    }
    if (firstRunApollo) 
        firstRunApollo := false
    running := false
}

global processTerminated := false, processKilled := false, TerminatedPIDs := []
WatchLogFiles() {
    global apolloExePath, logFiles, exeDirectory, confDirectory, confFiles, debugLevel, ConfiguredApolloPIDs, processKilled, processTerminated, TerminatedIndexes
    static running := False
    
    if (running)
        return 
    running := True
    LogMessage(3, "Starting WatchLogFiles()")

    static lastReadPositions := {}
    Loop, % ConfiguredApolloPIDs.MaxIndex() {
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
                pid := ConfiguredApolloPIDs[A_Index]
                if (pid) {
                    LogMessage(1, "Found 'CLIENT DISCONNECTED' in log file: " . logFile . " for Apollo instance: " . A_Index . " with PID: " . pid)
                    Sleep, 50
                    LogMessage(2, "Trying to Terminate Apollo instance: " . A_Index . " with PID: " . pid)
                    RunWait, %ComSpec% /c taskkill /PID %pid% /T /FI "SIGNAL=SIGINT",, Hide
                    Sleep, 50
                    Process, Exist, %pid%
                    if (ErrorLevel != 0) {
                        LogMessage(1, "Failed to terminate Apollo instance: " . A_Index . " with PID: " . pid . " trying force kill")
                        RunWait, %ComSpec% /c tskill %pid%,, Hide
                        Sleep, 50
                        Process, Exist, %pid%
                        if (ErrorLevel != 0) {
                            LogMessage(1, "Failed to force kill Apollo instance: " . A_Index . " with PID: " . pid)
                        } else {
                            LogMessage(1, "Force killed Apollo instance: " . A_Index . " with PID: " . pid)
                            processKilled := true
                            TerminatedPIDs.Push(pid)
                        }
                    } else {
                        LogMessage(1, "Terminated Apollo Apollo instance: " . A_Index . " with PID: " . pid)
                        processTerminated := true
                        TerminatedPIDs.Push(pid)
                    }
                }
            }
        }
    }
    LogMessage(3, "WatchLogFiles() completed")
    running := False
}

SyncVolume() {
    global logFiles, confDirectory, debugLevel, pids
    static lastVolume := -1
    static lastMute := -1

    static running := False
    if (running)
        return
    if (!ConfiguredApolloPIDs || ConfiguredApolloPIDs.MaxIndex() = 0)
        return
    LogMessage(3, "Starting SyncVolume()")
    running := True

    masterVolume := VA_GetMasterVolume()
    isMuted := VA_GetMasterMute()

    clientConnected := false
    
    static lastReadPositions := {}
    Loop, % ConfiguredApolloPIDs.MaxIndex() {
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
            for index, PID in ConfiguredApolloPIDs {
            VA_SetAppVolume(PID, masterVolume)
            if (isMuted != lastMute) 
                VA_SetAppMute(PID, isMuted ? 1 : 0)
            LogMessage(3, "Retrying to set volume/mute for PID: " . PID . " (Current Volume: " . currentVolume . ", Expected: " . masterVolume . ", Current Mute: " . currentMute . ", Expected: " . isMuted . ")")
            }
            Sleep, 50
        }
        for index, PID in ConfiguredApolloPIDs {
            updatedVolumePIDs.Push(PID)
            updatedMutePIDs.Push(PID)
        }
        lastVolume := masterVolume
        lastMute := isMuted
    }
    else if ( isMuted != lastMute) {
        LogMessage(2, "Syncing mute settings")
        for index, PID in ConfiguredApolloPIDs {
            if (isMuted != lastMute) 
                VA_SetAppMute(PID, isMuted ? 1 : 0)
            updatedMutePIDs.Push(PID)
        }
        lastMute := isMuted
    }
    else if ( masterVolume != lastVolume) {
        LogMessage(2, "Syncing volume settings")
        for index, PID in ConfiguredApolloPIDs {
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

global CurrentlyConnectedIDs

watchAndroidADBDevices(){
    global adbExePath, LogMessage, CmdRetWithTimeout, CurrentlyConnectedIDs
    static firstRun := true, running:= false
    if (firstRun) {
        firstRun := false
        Loop {
            Process, Exist, adb.exe
            if (ErrorLevel = 0){
                LogMessage(1, "No more residual ADB process found")
                break
            }
            pid := ErrorLevel
            RunWait, %ComSpec% /c taskkill /PID %pid% /T /FI "SIGNAL=SIGINT",, Hide
            Sleep, 50
            Process, Exist, adb.exe
            if (ErrorLevel != 0) {
                LogMessage(1, "Failed to terminate existing ADB process with PID: " . pid . " trying force kill")
                RunWait, %ComSpec% /c tskill %pid%,, Hide
                Sleep, 50
                Process, Exist, adb.exe
                if (ErrorLevel != 0) {
                    LogMessage(1, "Failed to force kill existing ADB process with PID: " . pid)
                } else {
                    LogMessage(1, "Force killed existing ADB process with PID: " . pid)
                }
            } else {
                LogMessage(1, "Terminated existing ADB process with PID: " . pid)
            }
        }
    }
    else if (running) {
        sleep, 500
        LogMessage(2, "Already running ADB device watcher, skipping this run")
        return
    }
    command := adbExePath . " devices"
    running := true
    adbOutput := CmdRetWithTimeout(command, 5000) ; 5 seconds timeout
    running := false
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
            LogMessage(1, "New ADB device connected: " . deviceID)
        }
    }

    for deviceID in lastConnectedIDs {
        if (!CurrentlyConnectedIDs.HasKey(deviceID)) {
            LogMessage(1, "ADB Device disconnected: " . deviceID)
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
        firstRun := false
        Loop {
            Process, Exist, scrcpy.exe
            if (ErrorLevel = 0){
                LogMessage(1, "No more residual scrcpy process found")
                break
            }
            pid := ErrorLevel
            RunWait, %ComSpec% /c taskkill /PID %pid% /T /FI "SIGNAL=SIGINT",, Hide
            Sleep, 50
            Process, Exist, scrcpy.exe
            if (ErrorLevel != 0) {
                LogMessage(1, "Failed to terminate existing scrcpy process with PID: " . pid . " trying force kill")
                RunWait, %ComSpec% /c tskill %pid%,, Hide
                Sleep, 50
                Process, Exist, scrcpy.exe
                if (ErrorLevel != 0) {
                    LogMessage(1, "Failed to force kill existing scrcpy process with PID: " . pid)
                } else {
                    LogMessage(1, "Force killed existing scrcpy process with PID: " . pid)
                    break
                }
            } else {
                LogMessage(1, "Terminated existing scrcpy process with PID: " . pid)
                break
            }
        }
    }

    ; Determine device status
    deviceStatus := CurrentlyConnectedIDs.HasKey(androidMicDeviceID) ? "connected" : "disconnected"

    if (deviceStatus != lastStatus) {
        LogMessage(1, "Mic Device " androidMicDeviceID " status changed to: " deviceStatus)
        ShouldRunMic := true
        lastStatus := deviceStatus
    }

    if (deviceStatus = "connected") {
        if (ShouldRunMic) {
            Process, Exist, scrcpyPID
            if (ErrorLevel != 0) {
                LogMessage(1, "scrcpy process " . scrcpyPID . " is already running, skipping restart.")
                ShouldRunMic := false
            } else {
                Run, "%adbExePath%" -s %androidMicDeviceID% shell input keyevent KEYCODE_WAKEUP,, Hide
                Sleep, 50
                Run, "%scrCpyPath%" -s %androidMicDeviceID% --no-video --no-window --audio-source=mic --window-borderless,, Hide, consolePID
                Loop, 100 {
                    Sleep, 50
                    Process, Exist, scrcpy.exe
                    if (ErrorLevel != 0) {
                        scrcpyPID := ErrorLevel
                        LogMessage(1, "Started scrcpy with PID: " scrcpyPID " for device: " androidMicDeviceID)
                        ShouldRunMic := false
                        break
                    }
                }
                if (!scrcpyPID) {
                    LogMessage(0, "Failed to start scrcpy for device: " androidMicDeviceID)
                    RunWait, %ComSpec% /c taskkill /PID %consolePID% /T /FI "SIGNAL=SIGINT",, Hide
                }
            }
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
        RunWait, %ComSpec% /c taskkill /PID %scrcpyPID% /T /FI "SIGNAL=SIGINT",, Hide
        scrcpyPID := ""
        if (consolePID) {
            LogMessage(1, "Terminating residual console process with PID: " . consolePID)
            RunWait, %ComSpec% /c taskkill /PID %consolePID% /T /FI "SIGNAL=SIGINT",, Hide
            consolePID := ""
        }
    }
}
MaintainReverseTethering() {
    global gnirehtetExecPath, LogMessage, platformToolsDirectory, CurrentlyConnectedIDs
    static gnirehtetRelayPID := "", gnirehtetRunning, lastConnectedDevices := 0 , firstRun := true
    if (firstRun) {
        firstRun := false
        Loop {
            Process, Exist, gnirehtet.exe
            if (ErrorLevel = 0){
                LogMessage(1, "No more residual gnirehtet process found")
                gnirehtetRunning := false
                break
            }
            pid := ErrorLevel
            RunWait, %ComSpec% /c taskkill /PID %consolePID% /T /FI "SIGNAL=SIGINT",, Hide
            Sleep, 50
            Process, Exist, gnirehtet.exe
            if (ErrorLevel != 0) {
                LogMessage(1, "Failed to terminate existing gnirehtet process with PID: " . pid . " trying force kill")
                RunWait, %ComSpec% /c tskill %pid%,, Hide
                Sleep, 50
                Process, Exist, gnirehtet.exe
                if (ErrorLevel != 0) {
                    LogMessage(1, "Failed to force kill existing gnirehtet process with PID: " . pid)
                } else {
                    LogMessage(1, "Force killed existing gnirehtet process with PID: " . pid)
                    gnirehtetRunning := false
                    break
                }
            } else {
                LogMessage(1, "Terminated existing gnirehtet process with PID: " . pid)
                gnirehtetRunning := false
                break
            }
        }
    }
    connectedDevices := CurrentlyConnectedIDs.Count()
    LogMessage(3, "Number of currently connected devices: " . connectedDevices)
    if (connectedDevices != lastConnectedDevices){
        if ( connectedDevices > 0) {
            if (gnirehtetRunning) {
                    LogMessage(1, "Gnirehtet already running with PID: " . gnirehtetRelayPID . " for currently connected " . connectedDevices . " device" . (connectedDevices > 1 ? "s" : ""))
            } else {
                LogMessage(1, "Starting gnirehtet relay process in autorun mode")
                Run, "%gnirehtetExecPath%" autorun, %platformToolsDirectory%, Hide, gnirehtetRelayPID
                Sleep, 500
                Process, Exist, gnirehtet.exe
                if (ErrorLevel != 0) {
                    gnirehtetRelayPID := ErrorLevel
                    LogMessage(1, "Started gnirehtet relay process with PID: " . gnirehtetRelayPID . " for currently connected " . connectedDevices . " device" . (connectedDevices > 1 ? "s" : ""))
                } else {
                    LogMessage(0, "Failed to start gnirehtet relay process")
                }
            }
        }
        else {
            if (gnirehtetRunning) {
                LogMessage(1, "All ADB devices disconnected, terminating gnirehtet with PID: " . gnirehtetRelayPID)
                RunWait, %ComSpec% /c taskkill /PID %gnirehtetRelayPID% /T /FI "SIGNAL=SIGINT",, Hide
                gnirehtetRelayPID := ""
            } else 
                LogMessage(1, "No devices connected and gnirehtet relay process is not running")
        }
    }
    lastConnectedDevices := connectedDevices
    
    Process, Exist, gnirehtet.exe
    gnirehtetRelayPID := ErrorLevel
    gnirehtetRunning := (ErrorLevel != 0)
}
MaintainCamConnectivity(){
    
}





LogMessage(1, "Script started at " . A_Now) 

SetTimer, BulkStartApollo, 1000

; Wait for BulkStartApollo to finish
Loop {
    Sleep, 50
    if (!firstrunApollo) {
        LogMessage(1, "Initializing Apollo has finished, procceding to auxilairy scripts.")
        break
    }
}

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


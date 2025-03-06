#NoEnv
#Persistent  ; Keeps the script running
#Include VA.ahk			;I could find it at https://github.com/komingshyu/MyScript/blob/8b65542851b62acb334cf299997fd1b53c76d982/Lib/VA.ahk#L990

targetApp := "sunshine.exe"
global PIDs

SyncVolume() {
    global targetApp, PIDs
    
    if (!PIDs || PIDs.MaxIndex() = 0) 
        return
    
    masterVolume := VA_GetMasterVolume()
    
    isMuted := VA_GetMasterMute()  ; Check if the master volume is muted

    for index, PID in PIDs {
        VA_SetAppVolume(PID, masterVolume)  ; Sync volume
        if (isMuted)
            VA_SetAppMute(PID, 1)  ; Unmute the app if system is muted
		else
			VA_SetAppMute(PID, 0)  ; Unmute the app if system is muted
	}
}

GetPIDsByProcessName(processName) {
    PIDs := []
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where Name='" processName "'") 
        PIDs.Push(process.ProcessId)
	
    return PIDs
}

SetTimer, UpdatePIDs, 5000  ; Update PIDs every 5 seconds
SetTimer, SyncVolume, 100     ; Run SyncVolume every 50ms

UpdatePIDs:
PIDs := GetPIDsByProcessName(targetApp)
return
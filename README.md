# My-Sunshine-setup
Config and scripts used in my multi monitor Apollo "fork of Sunshine" setup.

### Preview
![image](https://github.com/user-attachments/assets/c7448d48-f867-4103-9baa-a1fa30e5bf48)

### Motivation
Many thanks to [ClassicOldSong](https://github.com/ClassicOldSong) for the great work making this easily possible out of the box.

Want to keep many windows opened at same time, but Ultrawide monitors are way out of my budget, Portable 15" displays are still expensive even I can't connect more than 1 "unless they're super the expensive Thunderbolt daisychain thing", and I had one extra 10" tablet that I rarely find myself using it.
I found it useful as external display, and quite like the idea of multiple small monitors instead of big one, its more travel friendly, easier to manage windows alignment, and with touch input as a bonus "which turned out to be really useful in many cases". 

### Alternatives
Spacedesk and superDisplay are the only two good alternatives I found, but they're lagging behind sunshine in terms of performance and are not opensource. 

## Setup
1. Install Apollo
Download and install sunshine's fork Apollo from https://github.com/ClassicOldSong/Apollo/releases.
2. Clone the repo to local folder
3. Edit the paths inside the powershell script
   ```ini
      [string]$exePath = "C:\Program Files\Apollo\sunshine.exe"
      [string]$apolloDirectory = "C:\Program Files\Apollo\"
      
      [string]$workingDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
      [string[]]$exeParams = @(".\config\sunshine_1.conf", ".\config\sunshine_2.conf", ".\config\sunshine_3.conf")
      
      [string]$ahkExe = "C:\Program Files\AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe"
      [string]$ahkScript = "$workingDirectory\SyncMasterVolume.ahk"
   ```
4. Open task schduler: Win+R `taskschd.msc` and create new basic task.
5. Name: Whatever > Trigger: When I log on > Action: Start a program.
6. Program: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
7. Add arguments: ` -ExecutionPolicy Bypass -File  "C:\Path\to\apollo.ps1"`
8. Open the task and check: `Run with highest privileges` "idk what happened recently stopped working without admin, please submit a PR if you have a fix to run without privileges.

> [!Note]
> If you don't want to change Apollo installation path, or add read permissions for cert/key to normal user, you will need to set the shortcut to run as adminstrator.

9. Run the task manually to make sure its working.

    
## Bonus
### Connect android devices via USB
Using https://github.com/cotzhang/app.Cot-Hypernet2 to automatically enable "reverse" tethering for android devices via ADB, it actually runs proxy on laptop and use kinda VPN interface on Android to pass the connections over that proxy via ADB forward, it works better than WiFi on old/cheapo android tablets, and I need to keep usb connected for charging anyway.

> [!Note]
> You can replace gnirehtet.apk with the https://github.com/Linus789/gnirehtetx as it has some quality of life enhancments, mainly for me its auto exit on tablet, which made it easier to use the big tablet as normal when I'm not working "just disconnect and it'll automaticall stop the gnirehtet vpn, so you don't have to ;)

Anopther option is to use native hardware tethering as a workaround to have a network between PC and Android, I noticed slight better performance than the ADB method, so here it is:
1. Enable USB tethering from android settings
2. Check the IP your computer acquired via DHCP
3. Set it to static IP in the same range
4. Use that IP to connect from the android tablet to the PC
   I noticed my 2 tablets gave diffrent IP range for the laptop one gave 192.168.42.x, and the other gave 192.168.98.x range, I have no clue if it will work if both gave same range "as the android device itself will usually have the .1 IP in the range, so having 2 devices with same IP in same subnet doesn't sound good, but further testing needed.
   Advantages: No internet connection to Android devices, No need for ADB, More stable connection, and no need extra software.

### Auto launch and connect to hosts from android tablet clients
This may not be easy to setup for first time Automate App users, but ther result deserve the setup pain
  1. Download and install "Automate" App
  2. Create launcher shortcut for the desktop from Moonlight app "or better, Artimis from ClassicOldSong"
  3. Enable "App start inspect" flow in Automate app
  4. Now go back to home screen, and connect to host from the shortcut, then long-click home button to get the prameters which the app launched with, we're looking for the Extras section for example:
```ini
• Package: com.limelight.noir
• Activity class: com.limelight.Game
• Action: 
• Data URI: 
• MIME type: 
• Categories: 
• Extras: HttpsPort as Int: 17982, PcName as String: Left, UniqueId as String: b368efbc98069085, HDR as Boolean: 0, Host as String: 192.168.1.130, Port as Int: 17987, UUID as String: BBA3F7D5-7DA2-7B02-4C0E-681A7131C02B, AppId as Int: 881448767, VirtualDisplay as Boolean: 0, AppName as String: Desktop
```
     
  5. Edit "App start" block, in "Extras" field need to do little work, to match the parameters with Automate sytax, mainly the brackets and the quotation marks, something like this:
     ```ini
      {
      "HttpsPort": 17982,
      "PcName": "Left",
      "UniqueId": "b368efbc98069085",
      "HDR": false,
      "Host": "192.168.1.130",
      "Port": 17987,
      "UUID": "BBA3F7D5-7DA2-7B02-4C0E-681A7131C02B",
      "AppId": 881448767,
      "VirtualDisplay": false,
      "AppName": "Desktop"
      } 
      ```
     Doing that on touchscreen is annoying, so I used chatGPT to help me in this task and it didn't complain. UPDATE: you can use https://appstart-extrasparameters.pages.dev/ to auto extract the extras part.
     
  6. Now, remaining the "HTTPS request" block, which is responsible to ping the url of sunshine WebUI to auto launch or close app, in my case it was `https://192.168.1.130:17988` edit according to each instance webUI url, hint: WebUI Port = sunshine port - 1.

### Seperate Audio output device for each display
UPDATE: I'm not using this setup anymore, Its a PITA and not worth it. I now use FxSound to manually switch audio output, and still keep 1 dummy virtual audio device "not configured in apollo" but if I select it the host won't output any actual sound, but apollo can still capture it. So its my option when I want to mute the host while keeping clients audio "this is my daily usage now", also, AutoHotkey to keep the audio levels synced.


To make use of the speaker in each of these devices, in such a way each display outputs audio of the thing beinng displayed on it. While audio multitasking may not always be practical, but most of the time I have background music playing even if I'm in a meeting 😆 even for watching multiple live streams.

If you need Audio multitasking, and your brain can handle it "not easy", this section is for you. the idea is to create multiple virtual audio devices, and set each one as a sink for each instance, also, disable "Play audio on PC" on android clients using artemis or monlight and enable "Mute host PC speakers while streaming" on windows clients using moonlight-qt, this is important so each Apollo/sunshine instace doesn't playback its captured stream to the main playback device again, thus combining what we want to seperate :) .

1. Prepare virtual audio devices: In the host I used VAC "virtual audio cable" (paid) to create 3 virtual audio devices, you can also use ab-cable or any other virtual audio device app you like.
2. Rename each virtual device: from windows audio control panell, you can rename each device to your like, for me I set these 3 names "left" "bottom" "right" so I can put them in configuration using their name, also when switching apps I have conventional names for audio outputs.
3. Configure each instance: In **Virtual Sink** option for each instance add the corrosponding virtual device name. this is the device apollo/sunshine will capture and send to the client AND not play it back to default audio output.
4. Now the annoying part, each time apollo/sunshine gets connection it'll override the default audio output to the device set for it to capture, sadly we don't have built in setting to disable this behaviour, but I personally use app called "SoundSwitch" with default force profile set to speaker "my main output" so its always set from there. Anyway, when you configure your setup in a specific way, windows remeber which apps are assigned to which output.

Now, to route audio output from windows apps, use windows control panel, and to route audio output from diffrent browser tabs, I found extension "AudioPick" as I'm using soundcloud, youtube, and others as PWA, and I can set each one to output specfic device by default and it remebers them too.

### Control volume level from inside the host
The issue is Apollo captures digital audio (raw), and the only way to control volume level is from the client, which is not suitable for my daily usage.

Using windows volume mixer, I figured out we can control Apollo app volume level from there, and it actually worked! (no one knows how). anyway, in the repo the AHK V1 script (also called from the powershell script) that mainly keep volume level and mute status in sync between the master level and apollo app level inside the windows mixer.



> [!NOTE]
> This is guide is made using https://github.com/ClassicOldSong/Apollo repo.
> Apollo is a fork that despite being backed by only one dev, it recently got more fixes/features implemented in a faster pace than mainstream sunshine, and probably the two won't be compatible in the near future.

> [!CAUTION]
> If you decided to use Apollo, please, don't ask for support on moonlight-stream discord server or open issues related to Apollo in sunshine mainstream repo.

> [!TIP]
> If you want support or have issues you're welcome to open discussion or create an issue in Apollo's repo, but again, don't mix between both.


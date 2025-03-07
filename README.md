# My-Sunshine-setup
Config and AutoHotKey script used in my multi monitor Apollo "fork of Sunshine" setup.

## What it is
Mainly the AutoHotKey script has 3 features:
1. Launch as many apollo instances as configured "has conf file inside apollo folder, and entry inside the script"
2. If client disconnect, kill the instance so windows deattach the display, and restart it.
3. Sync master volume level (and mute status) from windows to all apollo instances currently running.

### Motivation
Many thanks to [ClassicOldSong](https://github.com/ClassicOldSong) for the great work making this easily possible out of the box.

Achieve multi-monitor streaming solution usable for office usage, using the most performant setup.

### Preview
![image](https://github.com/user-attachments/assets/c7448d48-f867-4103-9baa-a1fa30e5bf48)

### Alternatives
Spacedesk and superDisplay are possible alternatives and maybe more suitable for your needs "and less headache to setup" 

## Setup
1. Install Apollo
Download and install sunshine's fork Apollo from https://github.com/ClassicOldSong/Apollo/releases.

2. install AutoHotKey 
Download and install v1, and v2 from https://www.autohotkey.com/

3. Clone the repo to local folder, last update ditched powershell script in favour of AutoHotKey script doing everything.

Now, inside config directory `C:\Program Files\Apollo\config`
4. Add '.conf files', you can use mine from repo as starting point, just make sure you create the '.json' files for each instance.
5. Add json state files: create as many empty `.json` files to be used as state file, like `sunshine_1.josn`, `sunshine_3.josn`, and `sunshine_3.josn`.

6. Check inside the AHK script `ApolloBulkAutomation.ahk` for filenames and paths
7. Run script as adminstrator, check log file inside script folder for errors..
8. If everything is fine, add the script as schduled task on startup

> [!Tip] To create a task to auto run the script at login
> 1. Open task schduler: `Win+R` > `taskschd.msc` > `create new basic task`.
> 2. Name: Whatever > Trigger: When I log on > Action: Start a program.
> 3. Program: Browse for `ApolloBulkAutomation.ahk`
> 4. Check open-dialog or just Open the task and check: `Run with highest privilege`
> 5. Exit any other instance of AHK script and check run the task: `Select task` > `Right-Mouse Button click` > `Run`


##Bonus
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
     Doing that on touchscreen maybe annoying, so I created a simple webpage to extract the extras part we need: https://appstart-extrasparameters.pages.dev/
  6. Now, remaining the "HTTPS request" block, which is responsible to ping the url of sunshine WebUI to auto launch or close app, in my case it was `https://192.168.1.130:17988` edit according to each instance webUI url, hint: WebUI Port = sunshine port - 1.

### Seperate Audio output device for each display
UPDATE: I'm not using this setup anymore, Its a PITA and not worth it. I now use FxSound to manually switch audio output, and still keep 1 dummy virtual audio device "not configured in apollo" but if I select it the host won't output any actual sound, but apollo can still capture it. So its my option when I want to mute the host while keeping clients audio "this is my daily usage now", also, AutoHotkey to keep the audio levels synced.


To make use of the speaker in each of these devices, in such a way each display outputs audio of the thing beinng displayed on it. While audio multitasking may not always be practical, but most of the time I have background music playing even if I'm in a meeting 😆 even for watching multiple live streams.

If you need Audio multitasking, and your brain can handle it "not easy", this section is for you. the idea is to create multiple virtual audio devices, and set each one as a sink for each instance, also, disable "Play audio on PC" on android clients using artemis or monlight and enable "Mute host PC speakers while streaming" on windows clients using moonlight-qt, this is important so each Apollo/sunshine instace doesn't playback its captured stream to the main playback device again, thus combining what we want to seperate :) .

1. Prepare virtual audio devices: In the host I used VAC "virtual audio cable" (paid) to create 3 virtual audio devices, you can also use ab-cable or any other virtual audio device app you like.
2. Rename each virtual device: from windows audio control panell, you can rename each device to your like, for me I set these 3 names "left" "bottom" "right" so I can put them in configuration using their name, also when switching apps I have conventional names for audio outputs.
3. Configure each instance: In **Virtual Sink** option for each instance add the corrosponding virtual device name. this is the device apollo/sunshine will capture and send to the client AND not play it back to default audio output.


> [!NOTE]
> Now, I no longer use multi audio device setup, and the AHK script has part to sync audio level for all instances with tha master volume level, that may interfere with your needs if multi audio output is critical for you


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




> [!CAUTION]
> I'm not a programmer, most of the actual script was written with help from copilot and deepseek.

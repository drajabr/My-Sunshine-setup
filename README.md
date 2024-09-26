# My-Sunshine-setup
Config and scripts used in my multi monitor sunshine setup.

### Preview
![image](https://github.com/user-attachments/assets/c7448d48-f867-4103-9baa-a1fa30e5bf48)

### Motivation
Want to keep many windows opened at same time, but Ultrawide monitors are way out of my budget, Portable 15" displays are still expensive even I can't connect more than 1 "unless they're super the expensive Thunderbolt daisychain thing", and I had one extra 10" tablet that I rarely find myself using it.
I found it useful as external display, and quite like the idea of multiple small monitors instead of big one, its more travel friendly, easier to manage windows alignment, and with touch input as a bonus "which turned out to be really useful in many cases". 

### Alternatives
Spacedesk and superDisplay are the only two good alternatives I found, but they're lagging behind sunshine in terms of performance and are not opensource. 

## Setup
1. Install Apollo
Download and install sunshine's fork Apollo from https://github.com/ClassicOldSong/Apollo/releases.
2. Add conf files
In Apollo's config folder `C:\Program Files\Apollo\config` , create as many `.conf` files as you want, in my setup I created `sunshine_1.conf`, `sunshine_2.conf`, and `sunshine_3.conf`.
3. Edit conf files
For each conf file, you want to basically add the following configuration to be unique for each instance:

```ini
sunshine_name = x
port = x
log_path = x.log
file_state = x.json
```

For example, to have 2 instances you can set:

1. `sunshine_1.conf` has:
    ```ini
    sunshine_name = sunshine_1
    port = 1987
    log_path = sunshine_1.log
    file_state = sunshine_1.json
    headless_mode = enabled
    ```

2. `sunshine_2.conf` has:
    ```ini
    sunshine_name = sunshine_2
    port = 2987
    log_path = sunshine_2.log
    file_state = sunshine_2.json
    headless_mode = enabled
    ```
4. Copy the launch script `apollo_bulk_start.ps1`, I like to keep all my script in one folder, for example I'll place it in `C:\Tools\sunshine-tools`.
5. Download and extract PsExec tool from https://download.sysinternals.com/files/PSTools.zip, and place it wherever you like, for example I keep it in `C:\Tools\PSTools\PsExec.exe`.
6. Edit the script and check the paths for sunshine:
   ```ini
   param (
    [string]$exePath = "C:\Program Files\Apollo\sunshine.exe", 
    [string]$workingDirectory = "C:\Program Files\Apollo\",
    [string[]]$exeParams = @(".\config\sunshine_1.conf", ".\config\sunshine_2.conf")
   )
   ```
   and the path for PsExec tool:
   ```ini
    # Path to PsExec
    $psexecPath = "C:\Tools\PSTools\PsExec.exe"
   ```
7. Test run the script, ideally it should start the 2 instances for example and you will see icon in status area, also, open each instance webUI "from the icon you can open the webui for example" and pair your devices one to each instance "Note that you can't keep logged in in 2 instances at same time in same browser".
8. Create shortcut: `Select the script > Right click > Create shortcut`.
9. Edit shortcut target to bypass excution policy: `Select the shortcut > Right click > Properties` then in target field add `powershell.exe -ExecutionPolicy Bypass -File ` before the existing script target, for example it will be something like this: `powershell.exe -ExecutionPolicy Bypass -File  "C:\Tools\Sunshine-tools\apollo_bulk_start.ps1"`.
10. Optionally, copy the shortcut to startup folders so it automatically run at startup: `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup`.

## Bonus
### Connect android devices via USB
Using https://github.com/cotzhang/app.Cot-Hypernet2 to automatically enable reverse tethering for android devices via ADB, it works better than WiFi on old/cheapo android tablets, and I need to keep usb connected for charging anyway.
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
     Doing that on touchscreen is annoying, so I used chatGPT to help me in this task and it didn't complain.
  6. Now, remaining the "HTTPS request" block, which is responsible to ping the url of sunshine WebUI to auto launch or close app, in my case it was `https://192.168.1.130:17988` edit according to each instance webUI url, hint: WebUI Port = sunshine port - 1.

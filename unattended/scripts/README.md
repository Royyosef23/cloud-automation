# SetupComplete.cmd Configuration

## Overview
This script provides automatic restart functionality after OOBE (Out-of-Box Experience) completes but before the end user signs in. This is perfect for Azure AD Join/Autopilot scenarios where you want a clean restart after device enrollment.

## How It Works

### Execution Timeline
1. Windows setup starts
2. Region, keyboard, network setup during OOBE
3. User is prompted to sign in with Azure AD/Microsoft account
4. Device enrollment/Azure AD join occurs
5. **SetupComplete.cmd runs automatically** ⬅️ This is where our script executes
6. PC restarts automatically
7. End user sees clean Windows login screen
8. End user logs in and starts using the device

### File Locations

#### In Your Project
```
unattended/
└── scripts/
    └── SetupComplete.cmd
```

#### Required ISO Structure
For Windows to execute the script, your ISO must include it at:
```
$OEM$/
└── $$/
    └── Setup/
        └── Scripts/
            └── SetupComplete.cmd
```

#### Where Windows Copies It
During setup, Windows copies it to:
```
C:\Windows\Setup\Scripts\SetupComplete.cmd
```

## ISO Integration

### Manual Method
1. Extract your Windows ISO
2. Create the folder structure: `$OEM$\$$\Setup\Scripts\`
3. Copy `SetupComplete.cmd` to that location
4. Rebuild your ISO

### Automated Method (Recommended)
Use your existing ISO customization scripts to:
1. Mount the ISO
2. Copy the script to the correct location
3. Rebuild the ISO

Example PowerShell:
```powershell
# After mounting ISO to drive letter (e.g., X:)
$destPath = "X:\$OEM$\`$`$\Setup\Scripts"
New-Item -Path $destPath -ItemType Directory -Force
Copy-Item "unattended\scripts\SetupComplete.cmd" -Destination $destPath
```

## Features

### Logging
- Creates detailed logs at: `C:\Windows\Temp\CloudIT-Setup\setup-log.txt`
- Timestamps all activities
- Helps with troubleshooting

### Safe Restart
- 5-second delay before restart
- Forces closure of running applications
- Shows user-friendly restart message

### Error Handling
- Graceful exit on completion
- Creates log directory if missing
- Non-blocking timeout commands

## Customization

### Restart Delay
Change the delay by modifying the `/t` parameter:
```cmd
shutdown.exe /r /t 10 /f /c "Your message"  # 10 second delay
```

### Restart Message
Modify the `/c` parameter:
```cmd
shutdown.exe /r /t 5 /f /c "Your custom restart message"
```

### Additional Setup Tasks
Add your custom commands before the restart:
```cmd
REM Your custom setup tasks here
reg add "HKLM\SOFTWARE\YourCompany\Setup" /v "Completed" /t REG_SZ /d "true" /f

REM Then restart
shutdown.exe /r /t 5 /f /c "Setup complete, restarting..."
```

## Troubleshooting

### Script Not Running
1. Verify the ISO contains the script at: `$OEM$\$$\Setup\Scripts\SetupComplete.cmd`
2. Check Windows event logs for setup-related errors
3. Verify script syntax with: `cmd /c "SetupComplete.cmd"`

### No Restart Occurring
1. Check the log file: `C:\Windows\Temp\CloudIT-Setup\setup-log.txt`
2. Verify the shutdown command syntax
3. Check if any processes are preventing shutdown

### Permissions Issues
- The script runs in SYSTEM context automatically
- No additional permissions needed
- Avoid using network resources (may not be available)

## Important Notes

⚠️ **Timing**: This script runs AFTER OOBE, not during it
⚠️ **Context**: Runs as SYSTEM, not as any user
⚠️ **Network**: Network connectivity may be limited
⚠️ **User Profile**: No user profiles are loaded yet

✅ **Perfect for**: Device enrollment, policy application, system configuration
✅ **Not suitable for**: User-specific settings, profile customization

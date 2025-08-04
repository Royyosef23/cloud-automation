@echo off
REM ===========================================================================
REM SetupComplete.cmd - Post-OOBE restart script
REM This script runs after OOBE completes but before the first user signs in
REM ===========================================================================

REM Create log directory if it doesn't exist
if not exist "C:\Windows\Temp\CloudIT-Setup" mkdir "C:\Windows\Temp\CloudIT-Setup"

REM Log the execution
echo [%date% %time%] SetupComplete.cmd started >> "C:\Windows\Temp\CloudIT-Setup\setup-log.txt"
echo [%date% %time%] OOBE completed, preparing for automatic restart >> "C:\Windows\Temp\CloudIT-Setup\setup-log.txt"

REM Optional: Wait a few seconds to ensure all OOBE processes are complete
timeout /t 3 /nobreak >nul

REM Log before restart
echo [%date% %time%] Initiating automatic restart in 5 seconds >> "C:\Windows\Temp\CloudIT-Setup\setup-log.txt"

REM Restart the computer
REM /r = restart, /t 5 = 5 second delay, /f = force close applications
REM /c = comment shown to user during restart
shutdown.exe /r /t 5 /f /c "CloudIT Setup: Restarting after Azure AD enrollment. Please wait..."

REM Log completion
echo [%date% %time%] Restart command issued successfully >> "C:\Windows\Temp\CloudIT-Setup\setup-log.txt"

exit /b 0

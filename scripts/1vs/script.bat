@echo off
:: ====================================================================
:: UBDEN TEKNOLOJISI A.S - Management Script (Hide Only Shut Down Hack)
:: ====================================================================

:: Check for admin rights. If not admin, re-run as admin.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Admin privileges required. Please confirm UAC prompt.
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~fnx0\"' -Verb RunAs"
    exit
)

:: We avoid special Turkish chars, but set codepage to 437 for safety
chcp 437 >nul

:: Title, color, clear screen
title UBDEN TEKNOLOJISI A.S - Management Script
color 0A
cls

:MENU
echo =======================================================
echo              UBDEN TEKNOLOJISI A.S
echo                MANAGEMENT TOOL
echo =======================================================
echo.
echo [1] Apply Policy (Hide Shut Down, Add Custom Restart)
echo [2] Remove Policy (Restore Shut Down)
echo [3] Reset RDS GracePeriod
echo [4] Install WinRAR
echo [5] BGInfo Settings and Desktop (Startup)
echo [6] RDP Settings (Enable and Add User)
echo [7] Exit
echo.
set /p secim=Please select (1-7): 

if "%secim%"=="1" goto APPLY_POLICY
if "%secim%"=="2" goto REMOVE_POLICY
if "%secim%"=="3" goto RESET_GRACE
if "%secim%"=="4" goto INSTALL_WINRAR
if "%secim%"=="5" goto CONFIG_BGINFO
if "%secim%"=="6" goto RDP_SETTINGS
if "%secim%"=="7" goto EXIT

echo Invalid selection!
pause
cls
goto MENU

:APPLY_POLICY
cls
echo *** Applying policy: hide Shut Down in Start menu...
echo Note: This also hides the native Restart button.

:: Hide Shut Down & Restart from Start menu
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoClose /t REG_DWORD /d 1 /f >nul
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoClose /t REG_DWORD /d 1 /f >nul

:: Provide a custom "RestartServer.lnk" on Desktop
set SHORTCUT_PATH=%USERPROFILE%\Desktop\RestartServer.lnk

echo Creating custom "Restart" shortcut on Desktop...
powershell -NoProfile -Command ^
  "$WScriptShell = New-Object -ComObject WScript.Shell; ^
   $Shortcut = $WScriptShell.CreateShortcut('%SHORTCUT_PATH%'); ^
   $Shortcut.TargetPath = 'C:\\Windows\\System32\\shutdown.exe'; ^
   $Shortcut.Arguments = '/r /t 0'; ^
   $Shortcut.WindowStyle = 1; ^
   $Shortcut.IconLocation = 'C:\\Windows\\System32\\shell32.dll,238'; ^
   $Shortcut.Description = 'Restart Server'; ^
   $Shortcut.WorkingDirectory = 'C:\\Windows\\System32'; ^
   $Shortcut.Save()"

:: gpupdate
gpupdate /force >nul

echo.
echo *** Shut Down hidden. Built-in Restart also hidden.
echo A custom "RestartServer" shortcut has been placed on the desktop.
echo Use that to restart this server.
pause
cls
goto MENU

:REMOVE_POLICY
cls
echo *** Restoring Shut Down (and built-in Restart) in Start menu...
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoClose /f >nul
reg delete "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoClose /f >nul

:: Remove the custom shortcut if desired
if exist "%USERPROFILE%\Desktop\RestartServer.lnk" del "%USERPROFILE%\Desktop\RestartServer.lnk" >nul 2>&1

gpupdate /force >nul
echo.
echo *** Shut Down and Restart are restored in the Start menu.
pause
cls
goto MENU

:RESET_GRACE
cls
echo *** Resetting RDS GracePeriod...
powershell -Command ^
"try { ^
  Set-ExecutionPolicy Bypass -Scope Process -Force; ^
  Write-Host 'Resetting RDS GracePeriod...' -ForegroundColor Yellow; ^
  $RegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod'; ^
  $adminCheck = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()); ^
  if (-not $adminCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { ^
    Write-Host 'You must run this script as admin!' -ForegroundColor Red; ^
    exit 1; ^
  } ^
  if (!(Test-Path $RegPath)) { ^
    Write-Host 'GracePeriod key not found! Possibly already removed or not expired yet.' -ForegroundColor Red; ^
    exit 1; ^
  } ^
  Write-Host 'Taking ownership of registry...'; ^
  Start-Process -FilePath 'cmd.exe' -ArgumentList '/c takeown /f ""C:\Windows\System32\config\SYSTEM"" /a /r /d Y' -NoNewWindow -Wait; ^
  Write-Host 'Changing registry permissions...'; ^
  Start-Process -FilePath 'cmd.exe' -ArgumentList '/c icacls ""C:\Windows\System32\config\SYSTEM"" /grant Administrators:F /t' -NoNewWindow -Wait; ^
  Write-Host 'Removing GracePeriod key...' -ForegroundColor Yellow; ^
  Remove-Item -Path $RegPath -Recurse -Force; ^
  if (!(Test-Path $RegPath)) { ^
    Write-Host 'GracePeriod successfully reset! Please reboot the server.' -ForegroundColor Green; ^
  } else { ^
    Write-Host 'Failed to remove GracePeriod key! Ensure you are admin.' -ForegroundColor Red; ^
  } ^
  Write-Host 'Done!' -ForegroundColor Cyan; ^
} catch { ^
  Write-Host 'An error occurred in the GracePeriod reset script.' -ForegroundColor Red; ^
  exit 1; ^
}"

if %errorlevel% neq 0 (
    echo.
    echo The GracePeriod reset script encountered an error.
    echo Please ensure you are running as administrator.
    pause
)
cls
goto MENU

:INSTALL_WINRAR
cls
echo *** Downloading and installing WinRAR...
:: Adjust WinRAR URL/version if needed
set "WINRAR_URL=https://www.rarlab.com/rar/winrar-x64-622.exe"
set "WINRAR_TEMP=%TEMP%\winrar.exe"

echo Downloading from: %WINRAR_URL%
powershell -Command "try { Invoke-WebRequest -Uri '%WINRAR_URL%' -OutFile '%WINRAR_TEMP%' } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo.
    echo Failed to download WinRAR. Check the URL or your internet connection.
    pause
    cls
    goto MENU
)

echo Installing WinRAR silently...
start /wait "" "%WINRAR_TEMP%" /S
del "%WINRAR_TEMP%" /f /q

echo WinRAR installed successfully!
pause
cls
goto MENU

:CONFIG_BGINFO
cls
echo *** BGInfo Settings and Desktop configuration...
if not exist "C:\bginfo" mkdir "C:\bginfo"

echo 1/4 - Downloading wallpaper...
powershell -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ubdencom/.github/main/scripts/1vsco.jpg' -OutFile 'C:\bginfo\1vsco.jpg' } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo Failed to download 1vsco.jpg
    pause
    cls
    goto MENU
)

echo 2/4 - Downloading Bginfo.exe...
powershell -Command "try { Invoke-WebRequest -Uri 'https://github.com/ubdencom/.github/raw/main/scripts/1vs/Bginfo.exe' -OutFile 'C:\bginfo\Bginfo.exe' } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo Failed to download Bginfo.exe
    pause
    cls
    goto MENU
)

echo 3/4 - Downloading Bginfo64.exe...
powershell -Command "try { Invoke-WebRequest -Uri 'https://github.com/ubdencom/.github/raw/main/scripts/1vs/Bginfo64.exe' -OutFile 'C:\bginfo\Bginfo64.exe' } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo Failed to download Bginfo64.exe
    pause
    cls
    goto MENU
)

echo 4/4 - Downloading Config.bgi...
powershell -Command "try { Invoke-WebRequest -Uri 'https://github.com/ubdencom/.github/raw/main/scripts/1vs/Config.bgi' -OutFile 'C:\bginfo\Config.bgi' } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo Failed to download Config.bgi
    pause
    cls
    goto MENU
)

echo Running BGInfo once...
"C:\bginfo\Bginfo64.exe" "C:\bginfo\Config.bgi" /TIMER:0 /SILENT /NOLICPROMPT

echo Setting wallpaper to C:\bginfo\1vsco.jpg...
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "C:\bginfo\1vsco.jpg" /f >nul
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters

echo Locking wallpaper (prevent user from changing)...
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" /v NoChangingWallPaper /t REG_DWORD /d 1 /f >nul

echo Creating BGInfo Startup shortcut so it runs on each login...
powershell -NoProfile -Command ^
  "$WScriptShell = New-Object -ComObject WScript.Shell; ^
   $StartupFolder = $WScriptShell.SpecialFolders('Startup'); ^
   $ShortcutFile = Join-Path $StartupFolder 'BGInfo.lnk'; ^
   $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile); ^
   $Shortcut.TargetPath = 'C:\\bginfo\\Bginfo64.exe'; ^
   $Shortcut.Arguments = 'C:\\bginfo\\Config.bgi /TIMER:0 /SILENT /NOLICPROMPT'; ^
   $Shortcut.IconLocation = 'C:\\bginfo\\Bginfo64.exe,0'; ^
   $Shortcut.Description = 'BGInfo on Startup'; ^
   $Shortcut.WorkingDirectory = 'C:\\bginfo'; ^
   $Shortcut.Save()"

echo.
echo *** BGInfo setup completed! It will run automatically each login.
pause
cls
goto MENU

:RDP_SETTINGS
cls
echo *** RDP Settings ***
echo Enabling RDP in registry...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >nul

echo Opening firewall for Remote Desktop...
netsh advfirewall firewall set rule group="remote desktop" new enable=yes >nul

echo.
set /p RDPUSER=Enter a username to add to Remote Desktop Users group: 
if "%RDPUSER%"=="" (
    echo No username entered, skipping.
) else (
    echo Adding user %RDPUSER% to "Remote Desktop Users" group...
    net localgroup "Remote Desktop Users" "%RDPUSER%" /add
    if %errorlevel% neq 0 (
        echo Failed to add user. Check if the user exists or if you typed it correctly.
    ) else (
        echo User %RDPUSER% added successfully!
    )
)

echo.
echo RDP is enabled. You may connect via Remote Desktop now.
pause
cls
goto MENU

:EXIT
cls
echo Exiting...
timeout /t 2 >nul
exit

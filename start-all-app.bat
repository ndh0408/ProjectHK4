@echo off
title LUMA - Start All Services (Mobile App Mode)
color 0A

echo ============================================
echo     LUMA - Starting All Services (APP MODE)
echo ============================================
echo.

:: Get the directory where this script is located
set "PROJECT_DIR=%~dp0"
set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

echo Project Directory: %PROJECT_DIR%
echo.

:: Find Flutter path
set "FLUTTER_PATH="
call :FindFlutter

if "%FLUTTER_PATH%"=="" (
    echo [ERROR] Flutter not found! Please install Flutter and add to PATH.
    echo         Or set FLUTTER_HOME environment variable.
    pause
    exit /b 1
)

echo [OK] Flutter found at: %FLUTTER_PATH%
echo.

echo [0/4] Clearing stale caches to force fresh build...
echo.
if exist "%PROJECT_DIR%\admin\node_modules\.cache" (
    echo      - Removing admin React dev-server cache
    rmdir /s /q "%PROJECT_DIR%\admin\node_modules\.cache" 2>nul
)
if exist "%PROJECT_DIR%\admin\build" (
    echo      - Removing stale admin production build
    rmdir /s /q "%PROJECT_DIR%\admin\build" 2>nul
)
echo.

echo [1/5] Checking for connected Android device / emulator...
echo.

set "ADB="
if exist "%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe"
if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
if not defined ADB for %%a in (adb.exe) do if not "%%~$PATH:a"=="" set "ADB=%%~$PATH:a"

if not defined ADB (
    echo      [!] adb not found - skipping detection, will try to launch AVD anyway.
    goto :tryStartAvd
)

"%ADB%" devices > "%TEMP%\luma_devices.txt" 2>&1
type "%TEMP%\luma_devices.txt"
echo.

set "ANDROID_DEVICE="
set "ANDROID_DEVICE_ID="
for /f "usebackq tokens=1,2 delims=	 " %%a in ("%TEMP%\luma_devices.txt") do if /i "%%b"=="device" if not defined ANDROID_DEVICE_ID set "ANDROID_DEVICE_ID=%%a" & set "ANDROID_DEVICE=found"

if not defined ANDROID_DEVICE goto :tryStartAvd
goto :androidReady

:tryStartAvd
echo      [!] No Android device detected. Looking for an AVD to launch...
echo.

set "EMU_EXE="
if exist "%LOCALAPPDATA%\Android\sdk\emulator\emulator.exe" set "EMU_EXE=%LOCALAPPDATA%\Android\sdk\emulator\emulator.exe"
if defined ANDROID_HOME if exist "%ANDROID_HOME%\emulator\emulator.exe" set "EMU_EXE=%ANDROID_HOME%\emulator\emulator.exe"

set "AVD_ID="
if not defined EMU_EXE goto :noAvd

"%EMU_EXE%" -list-avds > "%TEMP%\luma_avds.txt" 2>&1
type "%TEMP%\luma_avds.txt"
echo.
set /p AVD_ID=<"%TEMP%\luma_avds.txt"

if not defined AVD_ID goto :noAvd

echo      Launching emulator: %AVD_ID%
start "LUMA Android Emulator" cmd /c ""%FLUTTER_PATH%" emulators --launch %AVD_ID%"
echo      Waiting up to 90s for emulator to boot...

set /a _tries=0
:waitAvd
timeout /t 5 /nobreak > nul
set /a _tries+=1
"%ADB%" devices > "%TEMP%\luma_devices.txt" 2>&1
set "ANDROID_DEVICE_ID="
for /f "usebackq tokens=1,2 delims=	 " %%a in ("%TEMP%\luma_devices.txt") do if /i "%%b"=="device" if not defined ANDROID_DEVICE_ID set "ANDROID_DEVICE_ID=%%a"
if defined ANDROID_DEVICE_ID (
    set "ANDROID_DEVICE=found"
    goto :androidReady
)
if %_tries% lss 18 goto :waitAvd
goto :noAvd

:noAvd
echo      [!] No AVD configured or emulator failed to boot.
echo          Create one: Android Studio ^> Device Manager ^> Create Virtual Device
echo          Or plug in a physical Android phone with USB debugging enabled.
echo.
echo ============================================
echo   [ERROR] No Android device available.
echo   Start an emulator or connect a phone, then re-run this script.
echo ============================================
pause
exit /b 1

:androidReady
echo      [OK] Android device ready.
echo.

echo [2/5] Starting Backend (Spring Boot - Maven)...
echo      Note: Backend requires MANUAL RESTART when Java code changes
echo.
start "LUMA Backend" cmd /k "cd /d "%PROJECT_DIR%\backend" && mvnw spring-boot:run"

timeout /t 5 /nobreak > nul

echo [3/5] Starting Admin Frontend (React) on port 3000 - fresh dev server...
echo      Note: Frontend has HOT RELOAD - changes auto-refresh in browser
echo.
start "LUMA Admin Frontend" cmd /k "cd /d "%PROJECT_DIR%\admin" && set BROWSER=none && set FAST_REFRESH=true && npm start"

timeout /t 2 /nobreak > nul

echo [4/5] Launching Mobile App on Android (flutter run)...
echo      Hot Reload: press 'r' in the Flutter console to reload, 'R' for full restart.
echo.
start "LUMA Mobile App" cmd /k "cd /d "%PROJECT_DIR%\mobile" && "%FLUTTER_PATH%" pub get && "%FLUTTER_PATH%" run -d %ANDROID_DEVICE_ID%"

timeout /t 2 /nobreak > nul

echo [5/5] Launching Flutter Web (user-facing) on port 5000...
echo      Opens in Chrome. Same codebase as the mobile app, compiled to web.
echo.
start "LUMA Flutter Web (User)" cmd /k "cd /d "%PROJECT_DIR%\mobile" && "%FLUTTER_PATH%" run -d chrome --web-port=5000"

echo.
echo ============================================
echo           All Services Starting!
echo ============================================
echo.
echo Backend:        http://localhost:8080
echo Admin (React):  http://localhost:3000
echo User Web:       http://localhost:5000   (Flutter web, opens in Chrome)
echo Mobile:         Running as native app on Android device/emulator
echo Swagger:        http://localhost:8080/swagger-ui.html
echo.
echo ============================================
echo                 IMPORTANT
echo ============================================
echo - Admin (React):     Auto-reload on file save (dev cache auto-cleared at startup)
echo - User Web (Flutter):Chrome opens automatically; press 'r' in its console for hot reload
echo - Mobile (Flutter):  Native app - press 'r' in its console to hot reload
echo                      Make sure emulator/device is running BEFORE this step
echo - Backend (Java):    RESTART REQUIRED on code change
echo ============================================
echo.
echo Press any key to close this window...
pause > nul
exit /b 0

:FindFlutter
:: Method 1: Check if flutter is in PATH
where flutter >nul 2>&1
if %errorlevel%==0 (
    for /f "delims=" %%i in ('where flutter') do (
        set "FLUTTER_PATH=%%i"
        goto :eof
    )
)

:: Method 2: Check FLUTTER_HOME environment variable
if defined FLUTTER_HOME (
    if exist "%FLUTTER_HOME%\bin\flutter.bat" (
        set "FLUTTER_PATH=%FLUTTER_HOME%\bin\flutter.bat"
        goto :eof
    )
)

:: Method 3: Check common Flutter installation paths
set "COMMON_PATHS=C:\flutter\bin\flutter.bat;C:\src\flutter\bin\flutter.bat;C:\dev\flutter\bin\flutter.bat;D:\flutter\bin\flutter.bat;D:\src\flutter\bin\flutter.bat;D:\dev\flutter\bin\flutter.bat;%USERPROFILE%\flutter\bin\flutter.bat;%LOCALAPPDATA%\flutter\bin\flutter.bat"

for %%p in (%COMMON_PATHS%) do (
    if exist "%%p" (
        set "FLUTTER_PATH=%%p"
        goto :eof
    )
)

:: Method 4: Search in Program Files
for /d %%d in ("%ProgramFiles%\flutter*" "%ProgramFiles(x86)%\flutter*") do (
    if exist "%%d\bin\flutter.bat" (
        set "FLUTTER_PATH=%%d\bin\flutter.bat"
        goto :eof
    )
)

:: Method 5: Search entire C: and D: drives (slower, but thorough)
echo Searching for Flutter installation... This may take a moment.
for %%d in (C D E) do (
    if exist "%%d:\" (
        for /f "delims=" %%i in ('dir /s /b "%%d:\flutter.bat" 2^>nul ^| findstr /i "\\bin\\flutter.bat$"') do (
            set "FLUTTER_PATH=%%i"
            goto :eof
        )
    )
)

goto :eof

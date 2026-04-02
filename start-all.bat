@echo off
title LUMA - Start All Services
color 0A

echo ============================================
echo           LUMA - Starting All Services
echo ============================================
echo.

:: Get the directory where this script is located
set "PROJECT_DIR=%~dp0"
set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

echo Project Directory: %PROJECT_DIR%
echo.

:: Set CocCoc as Chrome executable for Flutter web (if Chrome not found)
if not defined CHROME_EXECUTABLE (
    if exist "C:\Program Files\CocCoc\Browser\Application\browser.exe" (
        set "CHROME_EXECUTABLE=C:\Program Files\CocCoc\Browser\Application\browser.exe"
        echo [OK] Using CocCoc as Chrome browser for Flutter web.
    )
)

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

echo [1/3] Starting Backend (Spring Boot - Maven)...
echo      Note: Backend requires MANUAL RESTART when Java code changes
echo.
start "LUMA Backend" cmd /k "cd /d "%PROJECT_DIR%\backend" && mvnw spring-boot:run"

timeout /t 5 /nobreak > nul

echo [2/3] Starting Admin Frontend (React)...
echo      Note: Frontend has HOT RELOAD - changes auto-refresh in browser
echo.
start "LUMA Admin Frontend" cmd /k "cd /d "%PROJECT_DIR%\admin" && npm start"

timeout /t 2 /nobreak > nul

echo [3/3] Starting Mobile App (Flutter on Chrome - Port 5000)...
echo      Note: Mobile runs on Chrome Web browser at http://localhost:5000
echo.
start "LUMA Mobile (Chrome)" cmd /k "cd /d "%PROJECT_DIR%\mobile" && "%FLUTTER_PATH%" pub get && "%FLUTTER_PATH%" run -d chrome --web-port=5000"

echo.
echo ============================================
echo           All Services Started!
echo ============================================
echo.
echo Backend:  http://localhost:8080
echo Admin:    http://localhost:3000
echo Mobile:   http://localhost:5000
echo Swagger:  http://localhost:8080/swagger-ui.html
echo.
echo ============================================
echo                 IMPORTANT
echo ============================================
echo - Frontend (React): Auto-reload on file save
echo - Mobile (Flutter): Hot reload with 'r' in terminal
echo - Backend (Java):   RESTART REQUIRED on code change
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

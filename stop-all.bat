@echo off
title LUMA - Stop All Services
color 0C

echo ============================================
echo           LUMA - Stopping All Services
echo ============================================
echo.

echo Stopping Java processes (Backend)...
taskkill /F /IM java.exe 2>nul
if %errorlevel%==0 (
    echo [OK] Backend stopped
) else (
    echo [INFO] No Java process found
)

echo.
echo Stopping Node processes (React)...
taskkill /F /IM node.exe 2>nul
if %errorlevel%==0 (
    echo [OK] Frontend stopped
) else (
    echo [INFO] No Node process found
)

echo.
echo Stopping Dart/Flutter processes (Mobile + Flutter Web)...
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM flutter.exe 2>nul
echo [OK] Flutter/Dart processes stopped

echo.
echo ============================================
echo           All Services Stopped!
echo ============================================
echo.
pause

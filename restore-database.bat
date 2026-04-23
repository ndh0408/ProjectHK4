@echo off
setlocal EnableDelayedExpansion
title LUMA - Restore Database (one-time setup)
color 0B

echo ============================================
echo   LUMA - Restore Database from luma_db.bak
echo ============================================
echo.
echo This script restores the SQL Server database ONLY.
echo Run this ONCE on first setup (or when you want to reset the DB).
echo After that, use start-all-app.bat to run the project.
echo.

set "PROJECT_DIR=%~dp0"
set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
set "BAK_FILE=%PROJECT_DIR%\backend\backups\luma_db.bak"

if not exist "%BAK_FILE%" (
    echo [ERROR] Backup file not found:
    echo         %BAK_FILE%
    echo.
    pause
    exit /b 1
)

echo Backup file: %BAK_FILE%
echo.

rem ---- Find sqlcmd.exe ----
set "SQLCMD="
call :FindSqlcmd
if "%SQLCMD%"=="" goto :noSqlcmd
echo [OK] sqlcmd: %SQLCMD%
echo.

rem ---- Try each candidate server one by one ----
echo Searching for SQL Server instance ^(sa / password '1'^) ...

set "SQL_SERVER="
call :TrySql "localhost,1433"
if not "!SQL_SERVER!"=="" goto :sqlFound
call :TrySql "localhost"
if not "!SQL_SERVER!"=="" goto :sqlFound
call :TrySql ".\SQLEXPRESS"
if not "!SQL_SERVER!"=="" goto :sqlFound
call :TrySql "localhost\SQLEXPRESS"
if not "!SQL_SERVER!"=="" goto :sqlFound
goto :noSql

:sqlFound
echo.

rem ---- Check if luma_db already exists ----
"%SQLCMD%" -S %SQL_SERVER% -U sa -P 1 -C -h -1 -W -Q "SET NOCOUNT ON; IF DB_ID('luma_db') IS NOT NULL PRINT 'EXISTS';" > "%TEMP%\luma_check.txt" 2>&1
findstr /C:"EXISTS" "%TEMP%\luma_check.txt" >nul
if errorlevel 1 goto :doRestore

echo [WARN] Database 'luma_db' already exists on this server.
set "CONFIRM=N"
set /p CONFIRM="    Overwrite it with the backup? [y/N]: "
if /i not "!CONFIRM!"=="y" (
    echo     Aborted. Database left untouched.
    pause
    exit /b 0
)
echo     Dropping existing luma_db ...
"%SQLCMD%" -S %SQL_SERVER% -U sa -P 1 -C -Q "ALTER DATABASE [luma_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [luma_db];"
if errorlevel 1 (
    echo [ERROR] Failed to drop existing database.
    pause
    exit /b 1
)

:doRestore
echo.
echo [INFO] Restoring luma_db from backup ...
echo.

"%SQLCMD%" -S %SQL_SERVER% -U sa -P 1 -C -Q "DECLARE @data NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260)); DECLARE @log NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260)); DECLARE @bak NVARCHAR(400) = N'%BAK_FILE%'; DECLARE @sql NVARCHAR(MAX) = N'RESTORE DATABASE [luma_db] FROM DISK = N''' + @bak + N''' WITH MOVE N''luma_db'' TO N''' + @data + N'luma_db.mdf'', MOVE N''luma_db_log'' TO N''' + @log + N'luma_db_log.ldf'', REPLACE, STATS = 10;'; EXEC (@sql);"
if errorlevel 1 goto :restoreFailed

echo.
echo ============================================
echo   [SUCCESS] Database 'luma_db' restored.
echo ============================================
echo.
echo You can now run start-all-app.bat to launch the project.
echo.
pause
exit /b 0

:noSqlcmd
echo [ERROR] sqlcmd.exe not found. Install SQL Server or "SQL Server Command Line Utilities".
echo         Typical locations:
echo           C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe
echo           C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\sqlcmd.exe
echo.
pause
exit /b 1

:noSql
echo.
echo ============================================
echo [ERROR] Cannot connect to any SQL Server instance with user 'sa' / password '1'.
echo.
echo Please make sure:
echo   1. SQL Server ^(Express or Developer^) is installed and running.
echo   2. TCP/IP is enabled in "SQL Server Configuration Manager".
echo   3. Mixed Mode authentication is enabled.
echo   4. Login 'sa' is enabled with password '1'.
echo        ALTER LOGIN sa WITH PASSWORD = '1'; ALTER LOGIN sa ENABLE;
echo ============================================
pause
exit /b 1

:restoreFailed
echo.
echo [ERROR] Restore failed. See messages above.
pause
exit /b 1

rem ================ subroutines ================

:TrySql
rem %~1 = server string
"%SQLCMD%" -S %~1 -U sa -P 1 -C -l 5 -Q "SELECT 1" >nul 2>&1
if errorlevel 1 (
    echo    [..] Not available: %~1
    goto :eof
)
set "SQL_SERVER=%~1"
echo    [OK] Connected at: %~1
goto :eof

:FindSqlcmd
where sqlcmd >nul 2>&1
if %errorlevel%==0 (
    for /f "delims=" %%i in ('where sqlcmd') do (
        set "SQLCMD=%%i"
        goto :eof
    )
)

set "CAND=C:\Program Files\SqlCmd\sqlcmd.exe;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\sqlcmd.exe;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\160\Tools\Binn\sqlcmd.exe;C:\Program Files (x86)\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"

for %%p in ("%CAND:;=";"%") do (
    if exist %%p (
        set "SQLCMD=%%~p"
        goto :eof
    )
)

for /d %%d in ("C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\*") do (
    if exist "%%d\Tools\Binn\sqlcmd.exe" (
        set "SQLCMD=%%d\Tools\Binn\sqlcmd.exe"
        goto :eof
    )
)
goto :eof

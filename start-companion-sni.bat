@echo off
REM Pokemon Companion Tool - SNI Version Startup Script

title Pokemon Companion SNI Launcher

echo ======================================================
echo     Pokemon Emerald Companion Tool - SNI Version
echo ======================================================
echo.

REM Check if we're in the right directory
if not exist "server\package.json" (
    echo ERROR: This script must be run from the pokemon-companion folder!
    pause
    exit /b 1
)

echo [✓] Using SNI connector on port 65398
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed!
    pause
    exit /b 1
)

REM Check dependencies
if not exist "server\node_modules" (
    echo Installing server dependencies...
    cd server
    call npm install
    cd ..
)

if not exist "client\node_modules" (
    echo Installing client dependencies...
    cd client
    call npm install
    cd ..
)

echo.
echo ======================================================
echo Starting Services...
echo ======================================================
echo.

REM Start the server (connects to SNI)
echo Starting companion server (SNI mode)...
start "Pokemon Companion - SNI Server" cmd /k "cd /d %cd%\server && npm start"

timeout /t 3 /nobreak >nul

REM Start the client
echo Starting React client...
start "Pokemon Companion - Client" cmd /k "cd /d %cd%\client && npm start"

echo.
echo ======================================================
echo [✓] All services started!
echo ======================================================
echo.
echo IMPORTANT: Make sure SNI is running on port 65398
echo.
echo Setup checklist:
echo   1. SNI is running
echo   2. BizHawk has Connector.lua loaded
echo   3. Pokemon Emerald ROM is loaded
echo   4. React app opened in your browser
echo.
echo The companion tool will show battle data when you enter a battle!
echo.
pause

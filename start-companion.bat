@echo off
REM Pokemon Companion Tool - Direct Connection Startup Script

title Pokemon Companion Launcher

echo ======================================================
echo     Pokemon Emerald Companion Tool - Direct Mode
echo ======================================================
echo.

REM Check if we're in the right directory
if not exist "server\package.json" (
    echo ERROR: This script must be run from the pokemon-companion folder!
    pause
    exit /b 1
)

echo [✓] Direct connection mode (no SNI required)
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed!
    echo Please install Node.js from https://nodejs.org/
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

REM Start the server
echo Starting companion server...
start "Pokemon Companion - Server" cmd /k "cd /d %cd%\server && node server.js"

timeout /t 3 /nobreak >nul

REM Start the client
echo Starting React client...
start "Pokemon Companion - Client" cmd /k "cd /d %cd%\client && npm start"

echo.
echo ======================================================
echo [✓] All services started!
echo ======================================================
echo.
echo Setup checklist:
echo   1. BizHawk is running with Pokemon Emerald loaded
echo   2. Load pokemon_companion.lua in BizHawk Lua Console
echo   3. React app will open in your browser automatically
echo.
echo The Lua script connects directly to the server on port 17242.
echo No SNI or additional connectors needed!
echo.
echo The companion tool will show battle data when you enter a battle!
echo.
pause
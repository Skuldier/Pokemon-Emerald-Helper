# Pokemon Companion Tool - SNI Version

This installation has been updated to use SNI (SNES Network Interface).

## Quick Start

1. **Start SNI** (if not already running)
   - SNI should be running on port 65398

2. **Load Connector.lua in BizHawk**
   - This connects BizHawk to SNI

3. **Run the companion tool**
   - Double-click: start-companion-sni.bat
   - Or manually: cd server && npm start

4. **Load Pokemon Emerald** and enter a battle!

## Architecture

BizHawk → Connector.lua → SNI → Companion Server → React UI

## Reverting to Direct Connection

If you need to revert to the direct connection version:
- Restore server.js from the backup file
- Use the original start-companion.bat

## Environment Variables

- SNI_HOST: SNI host (default: 127.0.0.1)
- SNI_PORT: SNI port (default: 65398)

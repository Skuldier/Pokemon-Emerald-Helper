#!/usr/bin/env python3
"""
Update Pokemon Companion Tool to use SNI
This script updates your existing installation to use SNI instead of direct connection
"""

import os
import shutil
import json
from pathlib import Path

# New SNI-based server code
SNI_SERVER_CODE = '''// Pokemon Companion Tool - SNI-based Server
// Connects to SNI instead of creating its own TCP server

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const net = require('net');
const cors = require('cors');
const pokemonData = require('./pokemon-data');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

// Configuration
const SNI_HOST = process.env.SNI_HOST || '127.0.0.1';
const SNI_PORT = process.env.SNI_PORT || 65398;
const HTTP_PORT = 3001;

// State
let sniClient = null;
let battleState = null;
let connectionStatus = 'disconnected';
let messageBuffer = '';

// Pokemon Emerald Memory Addresses
const MEMORY = {
  IN_BATTLE: 0x02022FEC,
  BATTLE_TYPE: 0x02022FEE,
  PARTY_PLAYER: 0x02024284,
  PARTY_ENEMY: 0x02024744
};

// Pokemon data offsets
const POKEMON_SIZE = 100;
const POKEMON_OFFSETS = {
  species: 0x20,
  held_item: 0x22,
  moves: 0x2C,
  level: 0x54,
  hp_current: 0x56,
  hp_max: 0x58,
  attack: 0x5A,
  defense: 0x5C,
  speed: 0x5E,
  sp_attack: 0x60,
  sp_defense: 0x62,
  nature: 0x64
};

// Connect to SNI
function connectToSNI() {
  console.log(`Connecting to SNI at ${SNI_HOST}:${SNI_PORT}...`);
  
  sniClient = new net.Socket();
  
  sniClient.connect(SNI_PORT, SNI_HOST, () => {
    console.log('Connected to SNI!');
    connectionStatus = 'connected';
    io.emit('connection-status', { status: 'connected' });
    
    // Identify ourselves
    sendSNICommand('SetName', 'PokemonCompanion');
    
    // Start monitoring
    startBattleMonitoring();
  });
  
  sniClient.on('data', (data) => {
    messageBuffer += data.toString();
    processMessages();
  });
  
  sniClient.on('close', () => {
    console.log('SNI connection closed');
    connectionStatus = 'disconnected';
    battleState = null;
    io.emit('connection-status', { status: 'disconnected' });
    io.emit('battle-update', null);
    
    // Reconnect after 5 seconds
    setTimeout(connectToSNI, 5000);
  });
  
  sniClient.on('error', (err) => {
    console.error('SNI error:', err.message);
  });
}

// Process messages from SNI
function processMessages() {
  let lines = messageBuffer.split('\\n');
  messageBuffer = lines.pop() || ''; // Keep incomplete line in buffer
  
  for (const line of lines) {
    if (line.trim()) {
      processMessage(line.trim());
    }
  }
}

// Process a single message from SNI
function processMessage(message) {
  // SNI sends hex data as response to Read commands
  if (message.match(/^[0-9a-fA-F]+$/)) {
    handleReadResponse(message);
  } else if (message.startsWith('Version|')) {
    console.log('SNI Version:', message);
  }
}

// Send command to SNI
function sendSNICommand(command, ...args) {
  if (!sniClient || connectionStatus !== 'connected') return;
  
  const message = [command, ...args].join('|') + '\\n';
  sniClient.write(message);
}

// Read memory from SNI
function readMemory(address, length, callback) {
  // Store callback for when we get the response
  pendingReads.push({ address, length, callback });
  
  // SNI format: Read|address|length|domain
  sendSNICommand('Read', address, length, 'System Bus');
}

// Pending read callbacks
const pendingReads = [];
let currentRead = null;

// Handle hex data response from SNI
function handleReadResponse(hexData) {
  if (pendingReads.length === 0) return;
  
  const read = pendingReads.shift();
  const bytes = [];
  
  // Convert hex string to byte array
  for (let i = 0; i < hexData.length; i += 2) {
    bytes.push(parseInt(hexData.substr(i, 2), 16));
  }
  
  if (read.callback) {
    read.callback(bytes);
  }
}

// Parse Pokemon data from bytes
function parsePokemonData(bytes, slot = 0) {
  const offset = slot * POKEMON_SIZE;
  
  if (offset + POKEMON_SIZE > bytes.length) return null;
  
  // Read species (2 bytes, little endian)
  const species = bytes[offset + POKEMON_OFFSETS.species] | 
                  (bytes[offset + POKEMON_OFFSETS.species + 1] << 8);
  
  if (species === 0) return null;
  
  // Read other data
  const pokemon = {
    species,
    level: bytes[offset + POKEMON_OFFSETS.level],
    hp: {
      current: bytes[offset + POKEMON_OFFSETS.hp_current] | 
               (bytes[offset + POKEMON_OFFSETS.hp_current + 1] << 8),
      max: bytes[offset + POKEMON_OFFSETS.hp_max] | 
           (bytes[offset + POKEMON_OFFSETS.hp_max + 1] << 8)
    },
    stats: {
      attack: bytes[offset + POKEMON_OFFSETS.attack] | 
              (bytes[offset + POKEMON_OFFSETS.attack + 1] << 8),
      defense: bytes[offset + POKEMON_OFFSETS.defense] | 
               (bytes[offset + POKEMON_OFFSETS.defense + 1] << 8),
      speed: bytes[offset + POKEMON_OFFSETS.speed] | 
             (bytes[offset + POKEMON_OFFSETS.speed + 1] << 8),
      sp_attack: bytes[offset + POKEMON_OFFSETS.sp_attack] | 
                 (bytes[offset + POKEMON_OFFSETS.sp_attack + 1] << 8),
      sp_defense: bytes[offset + POKEMON_OFFSETS.sp_defense] | 
                  (bytes[offset + POKEMON_OFFSETS.sp_defense + 1] << 8)
    },
    nature: bytes[offset + POKEMON_OFFSETS.nature],
    held_item: bytes[offset + POKEMON_OFFSETS.held_item] | 
               (bytes[offset + POKEMON_OFFSETS.held_item + 1] << 8),
    moves: []
  };
  
  // Read moves (4 moves, 2 bytes each)
  for (let i = 0; i < 4; i++) {
    const move = bytes[offset + POKEMON_OFFSETS.moves + i * 2] | 
                 (bytes[offset + POKEMON_OFFSETS.moves + i * 2 + 1] << 8);
    if (move > 0) {
      pokemon.moves.push(move);
    }
  }
  
  return pokemon;
}

// Monitor battle state
let monitoringInterval = null;

function startBattleMonitoring() {
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
  }
  
  monitoringInterval = setInterval(checkBattleState, 500);
}

function checkBattleState() {
  if (connectionStatus !== 'connected') return;
  
  // First check if we're in battle
  readMemory(MEMORY.IN_BATTLE, 1, (bytes) => {
    const inBattle = bytes[0];
    
    if (inBattle !== 0) {
      // We're in battle, read party data
      readPartyData();
    } else {
      // Not in battle
      if (battleState) {
        battleState = null;
        io.emit('battle-update', null);
      }
    }
  });
}

function readPartyData() {
  // Read enemy party (6 Pokemon * 100 bytes = 600 bytes)
  readMemory(MEMORY.PARTY_ENEMY, 600, (enemyBytes) => {
    // Read player party
    readMemory(MEMORY.PARTY_PLAYER, 600, (playerBytes) => {
      const enemyPokemon = parsePokemonData(enemyBytes, 0);
      const playerPokemon = parsePokemonData(playerBytes, 0);
      
      if (enemyPokemon && playerPokemon) {
        processBattleData({
          enemy: { active: enemyPokemon },
          player: { active: playerPokemon }
        });
      }
    });
  });
}

function processBattleData(rawData) {
  const enemyPokemon = rawData.enemy.active;
  const playerPokemon = rawData.player.active;
  
  // Get Pokemon info from data files
  const enemyInfo = pokemonData.getPokemonInfo(enemyPokemon.species);
  const playerInfo = pokemonData.getPokemonInfo(playerPokemon.species);
  
  // Calculate tier rating
  const tierRating = pokemonData.calculateTierRating(enemyPokemon, enemyInfo);
  
  // Calculate type effectiveness
  const effectiveness = pokemonData.calculateTypeEffectiveness(
    playerInfo.types,
    enemyInfo.types
  );
  
  battleState = {
    enemy: {
      ...enemyPokemon,
      info: enemyInfo,
      tierRating
    },
    player: {
      ...playerPokemon,
      info: playerInfo
    },
    effectiveness,
    timestamp: Date.now()
  };
  
  io.emit('battle-update', battleState);
}

// REST API endpoints
app.get('/api/status', (req, res) => {
  res.json({
    connection: connectionStatus,
    sniConnection: sniClient ? 'connected' : 'disconnected',
    hasBattleData: battleState !== null
  });
});

app.get('/api/battle', (req, res) => {
  res.json(battleState);
});

// Socket.IO for real-time updates
io.on('connection', (socket) => {
  console.log('Web client connected');
  
  // Send current state
  socket.emit('connection-status', { status: connectionStatus });
  if (battleState) {
    socket.emit('battle-update', battleState);
  }
  
  socket.on('disconnect', () => {
    console.log('Web client disconnected');
  });
});

// Start servers
server.listen(HTTP_PORT, () => {
  console.log(`HTTP server listening on port ${HTTP_PORT} for web clients`);
  console.log(`Connecting to SNI at ${SNI_HOST}:${SNI_PORT}...`);
  connectToSNI();
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\\nShutting down...');
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
  }
  if (sniClient) {
    sniClient.end();
  }
  process.exit(0);
});
'''

SNI_START_SCRIPT = '''@echo off
REM Pokemon Companion Tool - SNI Version Startup Script

title Pokemon Companion SNI Launcher

echo ======================================================
echo     Pokemon Emerald Companion Tool - SNI Version
echo ======================================================
echo.

REM Check if we're in the right directory
if not exist "server\\package.json" (
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
if not exist "server\\node_modules" (
    echo Installing server dependencies...
    cd server
    call npm install
    cd ..
)

if not exist "client\\node_modules" (
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
start "Pokemon Companion - SNI Server" cmd /k "cd /d %cd%\\server && npm start"

timeout /t 3 /nobreak >nul

REM Start the client
echo Starting React client...
start "Pokemon Companion - Client" cmd /k "cd /d %cd%\\client && npm start"

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
'''

def find_project_directory():
    """Find the pokemon-companion project directory"""
    # Check current directory
    if Path("server/server.js").exists():
        return Path(".")
    
    # Check subdirectory
    if Path("pokemon-companion/server/server.js").exists():
        return Path("pokemon-companion")
    
    # Ask user
    print("Cannot find pokemon-companion project automatically.")
    user_path = input("Enter path to pokemon-companion folder: ").strip()
    if user_path and Path(user_path).exists():
        return Path(user_path)
    
    return None

def backup_file(file_path):
    """Create a backup of a file"""
    if file_path.exists():
        backup_path = file_path.with_suffix(file_path.suffix + '.backup')
        counter = 1
        while backup_path.exists():
            backup_path = file_path.with_suffix(f'{file_path.suffix}.backup{counter}')
            counter += 1
        shutil.copy(file_path, backup_path)
        return backup_path
    return None

def update_to_sni():
    """Update Pokemon Companion Tool to use SNI"""
    print("Pokemon Companion Tool - Update to SNI")
    print("=" * 50)
    
    # Find project directory
    project_dir = find_project_directory()
    if not project_dir:
        print("\n❌ Could not find pokemon-companion project!")
        return False
    
    print(f"\n✓ Found project at: {project_dir}")
    
    # Backup original files
    print("\n📦 Creating backups...")
    
    server_file = project_dir / "server" / "server.js"
    if server_file.exists():
        backup_path = backup_file(server_file)
        if backup_path:
            print(f"✓ Backed up server.js to {backup_path.name}")
    
    # Update server.js
    print("\n📝 Updating server to use SNI...")
    try:
        with open(server_file, 'w', encoding='utf-8') as f:
            f.write(SNI_SERVER_CODE)
        print("✓ Updated server.js to SNI version")
    except Exception as e:
        print(f"❌ Failed to update server.js: {e}")
        return False
    
    # Create SNI startup script
    print("\n🚀 Creating SNI startup script...")
    start_script = project_dir / "start-companion-sni.bat"
    try:
        with open(start_script, 'w', encoding='utf-8') as f:
            f.write(SNI_START_SCRIPT)
        print(f"✓ Created {start_script.name}")
    except Exception as e:
        print(f"❌ Failed to create startup script: {e}")
    
    # Create README for SNI
    readme_content = '''# Pokemon Companion Tool - SNI Version

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
'''
    
    readme_file = project_dir / "README-SNI.md"
    try:
        with open(readme_file, 'w', encoding='utf-8') as f:
            f.write(readme_content)
        print(f"✓ Created {readme_file.name}")
    except Exception as e:
        print(f"⚠️  Could not create README: {e}")
    
    print("\n" + "=" * 50)
    print("✅ Successfully updated to SNI version!")
    print("\n📋 Next steps:")
    print("1. Make sure SNI is running on port 65398")
    print("2. Load Connector.lua in BizHawk")
    print("3. Run start-companion-sni.bat")
    print("\n💡 The original server.js has been backed up")
    print("   You can restore it if needed")
    
    return True

def main():
    """Main entry point"""
    try:
        print("This will update your Pokemon Companion Tool to use SNI")
        print("Your original files will be backed up")
        response = input("\nProceed? (y/n): ").lower().strip()
        
        if response == 'y':
            update_to_sni()
        else:
            print("\nUpdate cancelled")
            
    except KeyboardInterrupt:
        print("\n\n❌ Update cancelled by user")
    except Exception as e:
        print(f"\n\n❌ Unexpected error: {e}")
    
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()
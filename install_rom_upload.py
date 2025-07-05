#!/usr/bin/env python3
"""
Pokemon Companion Tool - ROM Upload Feature Installer
This script automatically updates your project with the ROM upload feature.
"""

import os
import json
import shutil
from pathlib import Path

# ANSI color codes for pretty output
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_status(message, status="info"):
    """Print colored status messages"""
    if status == "success":
        print(f"{GREEN}✓ {message}{RESET}")
    elif status == "warning":
        print(f"{YELLOW}⚠ {message}{RESET}")
    elif status == "error":
        print(f"{RED}✗ {message}{RESET}")
    else:
        print(f"{BLUE}→ {message}{RESET}")

def create_file(filepath, content):
    """Create or update a file with the given content"""
    try:
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        
        # Check if file exists
        exists = os.path.exists(filepath)
        
        # Write the file
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        if exists:
            print_status(f"Updated: {filepath}", "success")
        else:
            print_status(f"Created: {filepath}", "success")
        return True
    except Exception as e:
        print_status(f"Failed to create {filepath}: {str(e)}", "error")
        return False

def update_package_json(filepath, new_deps):
    """Update package.json with new dependencies"""
    try:
        with open(filepath, 'r') as f:
            package = json.load(f)
        
        if 'dependencies' not in package:
            package['dependencies'] = {}
        
        for dep, version in new_deps.items():
            package['dependencies'][dep] = version
        
        with open(filepath, 'w') as f:
            json.dump(package, f, indent=2)
        
        print_status(f"Updated dependencies in {filepath}", "success")
        return True
    except Exception as e:
        print_status(f"Failed to update {filepath}: {str(e)}", "error")
        return False

# File contents
FILES = {
    'server/rom-analyzer.js': '''// server/rom-analyzer.js
// Pokemon Emerald ROM Analyzer for companion tool optimization

const crypto = require('crypto');

class ROMAnalyzer {
  constructor() {
    // Known ROM hashes
    this.knownROMs = {
      'f3ae088181bf583e55daf962a92bb46f4f1d07b7': {
        name: 'Pokemon Emerald (US)',
        version: '1.0',
        region: 'USA'
      },
      '1f1c08fb4e80f2d78e1c9e8f1e557b73b3f6f8f5': {
        name: 'Pokemon Emerald (EU)',
        version: '1.0',
        region: 'Europe'
      }
    };

    // DMA protection patterns
    this.dmaPatterns = {
      // Pattern that indicates DMA protection is active
      active: Buffer.from([0x00, 0x4A, 0x10, 0x68, 0x00, 0x28]),
      // Common anti-DMA patch patterns
      disabled: [
        Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
        Buffer.from([0x70, 0x47, 0x00, 0x00, 0x00, 0x00]),
        Buffer.from([0xC0, 0x46, 0xC0, 0x46, 0xC0, 0x46])
      ]
    };

    // Memory address signatures
    this.addressSignatures = {
      partyPokemon: {
        pattern: Buffer.from([0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF]),
        expectedOffset: 0x02024284,
        searchRange: [0x02020000, 0x02030000]
      },
      enemyPokemon: {
        pattern: Buffer.from([0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF]),
        expectedOffset: 0x02024744,
        searchRange: [0x02020000, 0x02030000]
      },
      battleState: {
        pattern: Buffer.from([0x00, 0x00, 0x00, 0x00]),
        expectedOffset: 0x02022FEC,
        searchRange: [0x02020000, 0x02025000]
      }
    };

    // Common patch signatures
    this.patchSignatures = {
      'Physical/Special Split': {
        offset: 0x1F2574,
        pattern: Buffer.from([0x00, 0x00, 0x00, 0x00])
      },
      'Fairy Type': {
        offset: 0x24F1A0,
        pattern: Buffer.from([0x09, 0x09, 0x09, 0x09])
      },
      'Infinite TMs': {
        offset: 0x124F78,
        pattern: Buffer.from([0x00, 0x00, 0x00, 0x00])
      },
      'National Dex': {
        offset: 0x0C0824,
        pattern: Buffer.from([0x00, 0x00, 0x00, 0x00])
      }
    };
  }

  async analyzeROM(buffer) {
    const results = {
      gameId: null,
      version: null,
      size: buffer.length,
      hash: null,
      dmaStatus: null,
      memoryAddresses: {},
      patches: [],
      warnings: [],
      recommendations: []
    };

    try {
      // Calculate ROM hash
      const hash = crypto.createHash('sha1').update(buffer).digest('hex');
      results.hash = hash;

      // Check if it's a known ROM
      if (this.knownROMs[hash]) {
        const romInfo = this.knownROMs[hash];
        results.gameId = romInfo.name;
        results.version = romInfo.version;
      } else {
        // Try to identify by header
        const gameId = buffer.slice(0xAC, 0xB0).toString('ascii');
        results.gameId = gameId;
        
        if (!gameId.startsWith('BPE')) {
          results.warnings.push('This may not be a Pokemon Emerald ROM');
        }
      }

      // Check DMA protection status
      results.dmaStatus = this.checkDMAProtection(buffer);

      // Find memory addresses
      results.memoryAddresses = this.findMemoryAddresses(buffer);

      // Detect common patches
      results.patches = this.detectPatches(buffer);

      // Generate recommendations
      results.recommendations = this.generateRecommendations(results);

      return results;
    } catch (error) {
      console.error('ROM analysis error:', error);
      throw error;
    }
  }

  checkDMAProtection(buffer) {
    const dmaCheckOffset = 0x080000; // Common location for DMA routines
    const searchSize = 0x100000; // Search first 1MB

    // Look for DMA protection patterns
    for (let i = dmaCheckOffset; i < Math.min(dmaCheckOffset + searchSize, buffer.length - 6); i++) {
      // Check for active DMA pattern
      if (this.comparePattern(buffer, i, this.dmaPatterns.active)) {
        // Now check if it's been patched
        for (const disabledPattern of this.dmaPatterns.disabled) {
          if (this.comparePattern(buffer, i, disabledPattern)) {
            return {
              disabled: true,
              pattern: 'Anti-DMA patch detected',
              offset: i,
              confidence: 'high'
            };
          }
        }
        
        return {
          disabled: false,
          pattern: 'DMA protection active',
          offset: i,
          confidence: 'high'
        };
      }
    }

    // Check alternative DMA locations
    const altOffsets = [0x08000400, 0x08001000, 0x08002000];
    for (const offset of altOffsets) {
      if (offset + 0x100 > buffer.length) continue;
      
      // Look for NOP sleds or return instructions that indicate patching
      let nopCount = 0;
      for (let i = 0; i < 0x100; i += 2) {
        const instruction = buffer.readUInt16LE(offset + i);
        if (instruction === 0x46C0 || instruction === 0x0000) { // NOP or zero
          nopCount++;
        }
      }
      
      if (nopCount > 20) {
        return {
          disabled: true,
          pattern: 'Likely DMA bypass detected',
          offset: offset,
          confidence: 'medium'
        };
      }
    }

    return {
      disabled: false,
      pattern: 'No DMA modifications detected',
      confidence: 'low'
    };
  }

  findMemoryAddresses(buffer) {
    const addresses = {};
    
    // For patched ROMs, memory addresses might be remapped
    // Check for common address redirections
    
    // Look for pointer tables that might indicate custom memory layout
    const pointerTableOffset = 0x3A0000; // Common location for pointer tables
    
    if (pointerTableOffset + 0x1000 < buffer.length) {
      // Scan for potential address remapping
      for (let i = 0; i < 0x1000; i += 4) {
        const value = buffer.readUInt32LE(pointerTableOffset + i);
        
        // Check if it looks like a GBA memory address
        if (value >= 0x02000000 && value < 0x03000000) {
          // Found a potential memory address
          const nextValue = buffer.readUInt32LE(pointerTableOffset + i + 4);
          
          // Check for patterns
          if (nextValue === value + 0x64) { // Pokemon struct size
            addresses.customPartyBase = value;
          } else if (nextValue === value + 0x4C0) { // Party size
            addresses.partyPokemon = value;
          }
        }
      }
    }

    // If no custom addresses found, use defaults
    if (!addresses.partyPokemon) {
      addresses.partyPokemon = 0x02024284;
      addresses.enemyPokemon = 0x02024744;
      addresses.battleState = 0x02022FEC;
      addresses.pcBoxes = 0x02FE9888;
    }

    return addresses;
  }

  detectPatches(buffer) {
    const detectedPatches = [];

    // Check for common ROM hacks/patches
    for (const [patchName, signature] of Object.entries(this.patchSignatures)) {
      if (signature.offset + signature.pattern.length > buffer.length) continue;
      
      let isPatched = true;
      for (let i = 0; i < signature.pattern.length; i++) {
        if (buffer[signature.offset + i] !== signature.pattern[i]) {
          isPatched = false;
          break;
        }
      }
      
      if (isPatched) {
        detectedPatches.push(patchName);
      }
    }

    // Check for expanded ROM size (indicates significant modifications)
    if (buffer.length > 16 * 1024 * 1024) {
      detectedPatches.push('ROM Expansion');
    }

    // Check for custom header indicating specific patches
    const customHeader = buffer.slice(0xB0, 0xBC).toString('ascii').trim();
    if (customHeader && customHeader !== '\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0\\0') {
      detectedPatches.push(`Custom Header: ${customHeader}`);
    }

    return detectedPatches;
  }

  generateRecommendations(results) {
    const recommendations = [];

    if (results.dmaStatus && results.dmaStatus.disabled) {
      recommendations.push({
        type: 'positive',
        message: 'DMA protection is disabled. Memory addresses should be stable.',
        action: 'Use static memory addresses for faster performance'
      });
    } else {
      recommendations.push({
        type: 'warning',
        message: 'DMA protection is active. Memory addresses may shift.',
        action: 'Use pattern matching or pointer tracking for reliability'
      });
    }

    if (results.patches.includes('ROM Expansion')) {
      recommendations.push({
        type: 'info',
        message: 'Expanded ROM detected. May contain custom features.',
        action: 'Test thoroughly for compatibility'
      });
    }

    if (!results.gameId || !results.gameId.startsWith('BPE')) {
      recommendations.push({
        type: 'error',
        message: 'ROM may not be Pokemon Emerald',
        action: 'Verify you uploaded the correct ROM'
      });
    }

    return recommendations;
  }

  comparePattern(buffer, offset, pattern) {
    if (offset + pattern.length > buffer.length) return false;
    
    for (let i = 0; i < pattern.length; i++) {
      if (buffer[offset + i] !== pattern[i]) {
        return false;
      }
    }
    return true;
  }
}

module.exports = ROMAnalyzer;
''',

    'server/server.js': '''// server/server.js
// Pokemon Companion Tool - SNI Server with ROM Analysis

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const net = require('net');
const cors = require('cors');
const multer = require('multer');
const pokemonData = require('./pokemon-data');
const ROMAnalyzer = require('./rom-analyzer');

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
let romAnalysisResults = null;

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 32 * 1024 * 1024 // 32MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.originalname.toLowerCase().endsWith('.gba')) {
      cb(null, true);
    } else {
      cb(new Error('Only .gba files are allowed'));
    }
  }
});

const analyzer = new ROMAnalyzer();

// Pokemon Emerald Memory Addresses
let MEMORY = {
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

// Read queue
const readQueue = [];
let currentReadCallback = null;
let isProcessingRead = false;

// Connection management
let isConnecting = false;
let reconnectTimer = null;

function connectToSNI() {
  if (isConnecting || (sniClient && connectionStatus === 'connected')) {
    return;
  }
  
  isConnecting = true;
  
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  
  console.log(`Connecting to SNI at ${SNI_HOST}:${SNI_PORT}...`);
  
  if (sniClient) {
    sniClient.destroy();
    sniClient = null;
  }
  
  sniClient = new net.Socket();
  
  sniClient.connect(SNI_PORT, SNI_HOST, () => {
    console.log('Connected to SNI!');
    connectionStatus = 'connected';
    isConnecting = false;
    io.emit('connection-status', { status: 'connected' });
    
    // Start polling
    startPolling();
  });
  
  sniClient.on('data', (data) => {
    messageBuffer += data.toString();
    
    let newlineIndex;
    while ((newlineIndex = messageBuffer.indexOf('\\n')) !== -1) {
      const message = messageBuffer.slice(0, newlineIndex);
      messageBuffer = messageBuffer.slice(newlineIndex + 1);
      
      if (message.trim()) {
        handleSNIMessage(message.trim());
      }
    }
  });
  
  sniClient.on('close', () => {
    console.log('SNI connection closed');
    connectionStatus = 'disconnected';
    isConnecting = false;
    sniClient = null;
    io.emit('connection-status', { status: 'disconnected' });
    
    // Reconnect after delay
    reconnectTimer = setTimeout(() => {
      connectToSNI();
    }, 5000);
  });
  
  sniClient.on('error', (err) => {
    console.error('SNI connection error:', err.message);
    isConnecting = false;
  });
}

function handleSNIMessage(message) {
  // Handle read responses
  if (message.startsWith('0x') && currentReadCallback) {
    const hexData = message.substring(2);
    handleReadResponse(hexData);
    return;
  }
  
  // Ignore other common messages
  if (message.includes('SNES') || message.includes('Version') || 
      message.includes('device') || message.includes('ROM')) {
    return;
  }
  
  console.log('SNI message:', message);
}

function sendCommand(command) {
  if (!sniClient || connectionStatus !== 'connected') {
    return false;
  }
  
  try {
    sniClient.write(command + '\\n');
    return true;
  } catch (err) {
    console.error('Send error:', err);
    return false;
  }
}

function readMemory(address, length, callback) {
  if (connectionStatus !== 'connected') {
    callback(null);
    return;
  }
  
  readQueue.push({
    address: address,
    length: length,
    callback: callback
  });
  
  processReadQueue();
}

function processReadQueue() {
  if (isProcessingRead || readQueue.length === 0) {
    return;
  }
  
  const request = readQueue.shift();
  isProcessingRead = true;
  currentReadCallback = request.callback;
  
  // Send read command
  const command = `Read|${request.address}|${request.length}|System Bus`;
  
  if (!sendCommand(command)) {
    if (currentReadCallback) {
      currentReadCallback(null);
      currentReadCallback = null;
    }
    isProcessingRead = false;
    setTimeout(processReadQueue, 100);
  }
}

function handleReadResponse(hexData) {
  if (!currentReadCallback) {
    isProcessingRead = false;
    return;
  }
  
  const bytes = [];
  
  // Convert hex to bytes
  for (let i = 0; i < hexData.length; i += 2) {
    bytes.push(parseInt(hexData.substr(i, 2), 16));
  }
  
  const callback = currentReadCallback;
  currentReadCallback = null;
  isProcessingRead = false;
  
  callback(bytes);
  
  // Process next read
  setTimeout(processReadQueue, 50);
}

function parsePokemonData(bytes, slot = 0) {
  if (!bytes || bytes.length < POKEMON_SIZE) return null;
  
  const offset = slot * POKEMON_SIZE;
  
  if (offset + POKEMON_SIZE > bytes.length) return null;
  
  const species = bytes[offset + POKEMON_OFFSETS.species] | 
                  (bytes[offset + POKEMON_OFFSETS.species + 1] << 8);
  
  if (species === 0 || species > 500) return null;
  
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
      spAttack: bytes[offset + POKEMON_OFFSETS.sp_attack] | 
                (bytes[offset + POKEMON_OFFSETS.sp_attack + 1] << 8),
      spDefense: bytes[offset + POKEMON_OFFSETS.sp_defense] | 
                 (bytes[offset + POKEMON_OFFSETS.sp_defense + 1] << 8)
    },
    moves: []
  };
  
  // Read moves
  for (let i = 0; i < 4; i++) {
    const moveId = bytes[offset + POKEMON_OFFSETS.moves + (i * 2)] |
                   (bytes[offset + POKEMON_OFFSETS.moves + (i * 2) + 1] << 8);
    if (moveId > 0) {
      pokemon.moves.push(moveId);
    }
  }
  
  return pokemon;
}

function checkBattleState() {
  // Check based on ROM analysis
  if (romAnalysisResults?.dmaStatus?.disabled) {
    // DMA disabled - use direct address
    readMemory(MEMORY.IN_BATTLE, 1, (bytes) => {
      if (bytes && bytes[0] !== 0) {
        readBattleData();
      } else {
        if (battleState) {
          battleState = null;
          io.emit('battle-update', null);
        }
      }
    });
  } else {
    // DMA active - use pattern matching (simplified for now)
    readMemory(MEMORY.IN_BATTLE, 1, (bytes) => {
      if (bytes && bytes[0] !== 0) {
        readBattleData();
      } else {
        if (battleState) {
          battleState = null;
          io.emit('battle-update', null);
        }
      }
    });
  }
}

function readBattleData() {
  // Read player and enemy Pokemon
  readMemory(MEMORY.PARTY_PLAYER, POKEMON_SIZE * 6, (playerBytes) => {
    if (!playerBytes) return;
    
    readMemory(MEMORY.PARTY_ENEMY, POKEMON_SIZE * 6, (enemyBytes) => {
      if (!enemyBytes) return;
      
      const playerPokemon = parsePokemonData(playerBytes, 0);
      const enemyPokemon = parsePokemonData(enemyBytes, 0);
      
      if (playerPokemon && enemyPokemon) {
        battleState = processBattleData({
          player: { active: playerPokemon },
          enemy: { active: enemyPokemon }
        });
        
        io.emit('battle-update', battleState);
      }
    });
  });
}

function processBattleData(rawData) {
  if (!rawData || !rawData.enemy || !rawData.enemy.active) {
    return null;
  }
  
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
  
  return {
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
}

function startPolling() {
  setInterval(() => {
    if (connectionStatus === 'connected') {
      checkBattleState();
    }
  }, 1000); // Poll every second
}

// ROM upload and analysis endpoint
app.post('/api/analyze-rom', upload.single('rom'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    console.log(`Analyzing ROM: ${req.file.originalname} (${req.file.size} bytes)`);

    // Analyze the ROM
    const results = await analyzer.analyzeROM(req.file.buffer);
    
    // Store results for use in memory reading
    romAnalysisResults = results;
    
    // Update memory addresses if custom ones were found
    if (results.memoryAddresses && results.dmaStatus?.disabled) {
      // Update MEMORY object with optimized addresses
      if (results.memoryAddresses.partyPokemon) {
        MEMORY.PARTY_PLAYER = results.memoryAddresses.partyPokemon;
      }
      if (results.memoryAddresses.enemyPokemon) {
        MEMORY.PARTY_ENEMY = results.memoryAddresses.enemyPokemon;
      }
      if (results.memoryAddresses.battleState) {
        MEMORY.IN_BATTLE = results.memoryAddresses.battleState;
      }
      console.log('Updated memory addresses for optimized access');
    }

    // Send results to client
    res.json(results);
    
    // Notify connected clients
    io.emit('rom-analyzed', {
      dmaDisabled: results.dmaStatus?.disabled || false,
      customAddresses: results.memoryAddresses
    });

  } catch (error) {
    console.error('ROM analysis error:', error);
    res.status(500).json({ 
      error: 'Failed to analyze ROM',
      details: error.message 
    });
  }
});

// Get current ROM analysis status
app.get('/api/rom-status', (req, res) => {
  if (romAnalysisResults) {
    res.json({
      analyzed: true,
      dmaDisabled: romAnalysisResults.dmaStatus?.disabled || false,
      gameId: romAnalysisResults.gameId,
      patches: romAnalysisResults.patches
    });
  } else {
    res.json({ analyzed: false });
  }
});

// REST API endpoints
app.get('/api/status', (req, res) => {
  res.json({
    connection: connectionStatus,
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

// Start initial connection
connectToSNI();

// Start server
server.listen(HTTP_PORT, () => {
  console.log(`HTTP server listening on port ${HTTP_PORT} for web clients`);
  console.log(`Attempting to connect to SNI on ${SNI_HOST}:${SNI_PORT}`);
});
''',

    'client/src/components/ROMUpload.js': '''// client/src/components/ROMUpload.js
import React, { useState } from 'react';
import './ROMUpload.css';

function ROMUpload({ onAnalysisComplete }) {
  const [uploading, setUploading] = useState(false);
  const [analysis, setAnalysis] = useState(null);
  const [error, setError] = useState(null);
  const [dragActive, setDragActive] = useState(false);

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileInput = (e) => {
    if (e.target.files && e.target.files[0]) {
      handleFile(e.target.files[0]);
    }
  };

  const handleFile = async (file) => {
    // Validate file
    if (!file.name.endsWith('.gba')) {
      setError('Please upload a .gba ROM file');
      return;
    }

    if (file.size > 32 * 1024 * 1024) { // 32MB max
      setError('File too large. Maximum size is 32MB');
      return;
    }

    setUploading(true);
    setError(null);
    setAnalysis(null);

    const formData = new FormData();
    formData.append('rom', file);

    try {
      const response = await fetch('http://localhost:3001/api/analyze-rom', {
        method: 'POST',
        body: formData
      });

      if (!response.ok) {
        throw new Error(`Analysis failed: ${response.statusText}`);
      }

      const result = await response.json();
      setAnalysis(result);
      
      if (onAnalysisComplete) {
        onAnalysisComplete(result);
      }
    } catch (err) {
      setError(err.message);
      console.error('ROM analysis error:', err);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="rom-upload-container">
      <h3>ROM Analysis Tool</h3>
      <p className="upload-description">
        Upload your patched Pokemon Emerald ROM to analyze memory modifications and optimize the companion tool.
      </p>

      <div 
        className={`upload-zone ${dragActive ? 'drag-active' : ''}`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <input
          type="file"
          id="rom-file"
          accept=".gba"
          onChange={handleFileInput}
          className="file-input"
          disabled={uploading}
        />
        <label htmlFor="rom-file" className="file-label">
          {uploading ? (
            <div className="uploading">
              <div className="spinner"></div>
              <span>Analyzing ROM...</span>
            </div>
          ) : (
            <>
              <div className="upload-icon">📁</div>
              <span>Drop your .gba ROM here or click to browse</span>
              <span className="file-hint">Pokemon Emerald ROM (patched or original)</span>
            </>
          )}
        </label>
      </div>

      {error && (
        <div className="error-message">
          ⚠️ {error}
        </div>
      )}

      {analysis && (
        <div className="analysis-results">
          <h4>Analysis Results</h4>
          
          <div className="result-section">
            <h5>ROM Information</h5>
            <div className="info-grid">
              <span>Game ID:</span>
              <span>{analysis.gameId}</span>
              <span>Version:</span>
              <span>{analysis.version}</span>
              <span>Size:</span>
              <span>{(analysis.size / 1024 / 1024).toFixed(2)} MB</span>
            </div>
          </div>

          {analysis.dmaStatus && (
            <div className="result-section">
              <h5>DMA Protection Status</h5>
              <div className={`dma-status ${analysis.dmaStatus.disabled ? 'disabled' : 'active'}`}>
                {analysis.dmaStatus.disabled ? '✓ DMA Protection Disabled' : '⚠️ DMA Protection Active'}
              </div>
              {analysis.dmaStatus.pattern && (
                <div className="pattern-info">
                  Pattern found at: 0x{analysis.dmaStatus.offset.toString(16).toUpperCase()}
                </div>
              )}
            </div>
          )}

          {analysis.memoryAddresses && (
            <div className="result-section">
              <h5>Detected Memory Addresses</h5>
              <div className="address-list">
                {Object.entries(analysis.memoryAddresses).map(([name, addr]) => (
                  <div key={name} className="address-item">
                    <span className="address-name">{name}:</span>
                    <span className="address-value">0x{addr.toString(16).toUpperCase()}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {analysis.patches && analysis.patches.length > 0 && (
            <div className="result-section">
              <h5>Detected Patches</h5>
              <ul className="patch-list">
                {analysis.patches.map((patch, idx) => (
                  <li key={idx}>{patch}</li>
                ))}
              </ul>
            </div>
          )}

          <button 
            className="apply-button"
            onClick={() => onAnalysisComplete && onAnalysisComplete(analysis)}
          >
            Apply Analysis to Companion Tool
          </button>
        </div>
      )}
    </div>
  );
}

export default ROMUpload;
''',

    'client/src/components/ROMUpload.css': '''/* client/src/components/ROMUpload.css */
.rom-upload-container {
  background-color: rgba(0, 0, 0, 0.3);
  border-radius: 12px;
  padding: 2rem;
  margin: 2rem 0;
  max-width: 600px;
  margin-left: auto;
  margin-right: auto;
}

.rom-upload-container h3 {
  color: #f39c12;
  margin-top: 0;
  margin-bottom: 1rem;
  text-align: center;
  font-size: 1.5rem;
}

.upload-description {
  text-align: center;
  color: #bbb;
  margin-bottom: 2rem;
  line-height: 1.5;
}

.upload-zone {
  border: 3px dashed rgba(255, 255, 255, 0.3);
  border-radius: 12px;
  padding: 3rem;
  text-align: center;
  transition: all 0.3s ease;
  position: relative;
  background-color: rgba(0, 0, 0, 0.2);
}

.upload-zone.drag-active {
  border-color: #f39c12;
  background-color: rgba(243, 156, 18, 0.1);
  transform: scale(1.02);
}

.file-input {
  display: none;
}

.file-label {
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

.upload-icon {
  font-size: 3rem;
  opacity: 0.7;
}

.file-hint {
  font-size: 0.875rem;
  color: #888;
  margin-top: 0.5rem;
}

.uploading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid rgba(255, 255, 255, 0.1);
  border-top-color: #f39c12;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.error-message {
  background-color: rgba(231, 76, 60, 0.2);
  border: 1px solid #e74c3c;
  border-radius: 8px;
  padding: 1rem;
  margin-top: 1rem;
  color: #e74c3c;
  text-align: center;
}

.analysis-results {
  margin-top: 2rem;
  background-color: rgba(0, 0, 0, 0.4);
  border-radius: 12px;
  padding: 1.5rem;
  animation: fadeIn 0.5s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.analysis-results h4 {
  color: #f39c12;
  margin-top: 0;
  margin-bottom: 1.5rem;
  text-align: center;
}

.result-section {
  margin-bottom: 1.5rem;
  padding: 1rem;
  background-color: rgba(255, 255, 255, 0.05);
  border-radius: 8px;
}

.result-section h5 {
  color: #3498db;
  margin-top: 0;
  margin-bottom: 1rem;
}

.info-grid {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0.5rem 1rem;
  font-size: 0.9rem;
}

.info-grid span:nth-child(odd) {
  color: #888;
}

.info-grid span:nth-child(even) {
  color: #fff;
  font-family: monospace;
}

.dma-status {
  padding: 0.75rem;
  border-radius: 6px;
  text-align: center;
  font-weight: bold;
}

.dma-status.disabled {
  background-color: rgba(46, 204, 113, 0.2);
  border: 1px solid #2ecc71;
  color: #2ecc71;
}

.dma-status.active {
  background-color: rgba(241, 196, 15, 0.2);
  border: 1px solid #f1c40f;
  color: #f1c40f;
}

.pattern-info {
  margin-top: 0.5rem;
  font-size: 0.875rem;
  color: #888;
  font-family: monospace;
}

.address-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.address-item {
  display: flex;
  justify-content: space-between;
  padding: 0.5rem;
  background-color: rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  font-size: 0.9rem;
}

.address-name {
  color: #bbb;
}

.address-value {
  color: #3498db;
  font-family: monospace;
}

.patch-list {
  margin: 0;
  padding-left: 1.5rem;
  color: #bbb;
}

.patch-list li {
  margin-bottom: 0.5rem;
}

.apply-button {
  width: 100%;
  padding: 1rem;
  background-color: #f39c12;
  color: #1a1a1a;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s ease;
  margin-top: 1rem;
}

.apply-button:hover {
  background-color: #e67e22;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(243, 156, 18, 0.3);
}

.apply-button:active {
  transform: translateY(0);
}
''',

    'client/src/App.js': '''// client/src/App.js
// Updated to include ROM upload functionality

import React, { useState, useEffect } from 'react';
import io from 'socket.io-client';
import './App.css';
import ConnectionStatus from './components/ConnectionStatus';
import BattleDisplay from './components/BattleDisplay';
import ROMUpload from './components/ROMUpload';

const socket = io('http://localhost:3001');

function App() {
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const [battleData, setBattleData] = useState(null);
  const [showROMUpload, setShowROMUpload] = useState(true);
  const [romAnalyzed, setRomAnalyzed] = useState(false);
  const [analysisResults, setAnalysisResults] = useState(null);

  useEffect(() => {
    // Socket event listeners
    socket.on('connect', () => {
      console.log('Connected to companion server');
    });

    socket.on('disconnect', () => {
      console.log('Disconnected from companion server');
    });

    socket.on('connection-status', (data) => {
      setConnectionStatus(data.status);
    });

    socket.on('battle-update', (data) => {
      setBattleData(data);
    });

    socket.on('rom-analyzed', (data) => {
      console.log('ROM analysis complete:', data);
      if (data.dmaDisabled) {
        console.log('DMA protection is disabled - using optimized memory access');
      }
    });

    // Check if ROM was already analyzed
    fetch('http://localhost:3001/api/rom-status')
      .then(res => res.json())
      .then(data => {
        if (data.analyzed) {
          setRomAnalyzed(true);
          setShowROMUpload(false);
        }
      })
      .catch(err => console.error('Failed to check ROM status:', err));

    return () => {
      socket.off('connect');
      socket.off('disconnect');
      socket.off('connection-status');
      socket.off('battle-update');
      socket.off('rom-analyzed');
    };
  }, []);

  const handleROMAnalysis = (results) => {
    setAnalysisResults(results);
    setRomAnalyzed(true);
    
    // Auto-hide upload after successful analysis
    setTimeout(() => {
      setShowROMUpload(false);
    }, 3000);
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Pokemon Emerald Companion</h1>
        <ConnectionStatus status={connectionStatus} />
      </header>

      <main className="App-main">
        {!romAnalyzed && (
          <div className="initial-setup">
            <h2>Welcome to Pokemon Companion Tool</h2>
            <p>For best performance, upload your Pokemon Emerald ROM to optimize memory reading.</p>
          </div>
        )}

        {showROMUpload && (
          <ROMUpload onAnalysisComplete={handleROMAnalysis} />
        )}

        {romAnalyzed && analysisResults && (
          <div className="analysis-summary">
            <h3>ROM Analysis Complete</h3>
            <div className="summary-content">
              <div className="summary-item">
                <span className="label">Game:</span>
                <span className="value">{analysisResults.gameId || 'Pokemon Emerald'}</span>
              </div>
              <div className="summary-item">
                <span className="label">DMA Status:</span>
                <span className={`value ${analysisResults.dmaStatus?.disabled ? 'good' : 'warning'}`}>
                  {analysisResults.dmaStatus?.disabled ? 'Disabled ✓' : 'Active ⚠️'}
                </span>
              </div>
              {analysisResults.patches.length > 0 && (
                <div className="summary-item">
                  <span className="label">Patches:</span>
                  <span className="value">{analysisResults.patches.length} detected</span>
                </div>
              )}
            </div>
          </div>
        )}

        {battleData ? (
          <BattleDisplay battleData={battleData} />
        ) : (
          <div className="no-battle">
            <h2>No Battle Active</h2>
            <p>Enter a Pokemon battle to see companion data</p>
            {!romAnalyzed && (
              <button 
                className="setup-button"
                onClick={() => setShowROMUpload(true)}
              >
                Upload ROM for Better Performance
              </button>
            )}
          </div>
        )}

        {romAnalyzed && !showROMUpload && (
          <div className="rom-controls">
            <button 
              className="reanalyze-button"
              onClick={() => setShowROMUpload(true)}
            >
              Upload Different ROM
            </button>
          </div>
        )}
      </main>
    </div>
  );
}

export default App;
''',

    'client/src/App.css': '''/* client/src/App.css */
/* Updated styles for ROM upload integration */

.App {
  min-height: 100vh;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
  color: #fff;
  display: flex;
  flex-direction: column;
}

.App-header {
  background-color: rgba(0, 0, 0, 0.5);
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 2px solid rgba(243, 156, 18, 0.3);
}

.App-header h1 {
  margin: 0;
  font-size: 2rem;
  color: #f39c12;
  text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
}

.App-main {
  flex: 1;
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
  width: 100%;
}

.initial-setup {
  text-align: center;
  margin-bottom: 2rem;
  padding: 2rem;
  background-color: rgba(0, 0, 0, 0.3);
  border-radius: 12px;
}

.initial-setup h2 {
  color: #3498db;
  margin-bottom: 1rem;
}

.initial-setup p {
  color: #bbb;
  font-size: 1.1rem;
}

.analysis-summary {
  background-color: rgba(46, 204, 113, 0.1);
  border: 1px solid #2ecc71;
  border-radius: 12px;
  padding: 1.5rem;
  margin-bottom: 2rem;
  animation: slideIn 0.5s ease;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.analysis-summary h3 {
  color: #2ecc71;
  margin-top: 0;
  margin-bottom: 1rem;
}

.summary-content {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
}

.summary-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem;
  background-color: rgba(0, 0, 0, 0.2);
  border-radius: 6px;
}

.summary-item .label {
  color: #888;
  font-size: 0.9rem;
}

.summary-item .value {
  font-weight: bold;
  font-family: monospace;
}

.summary-item .value.good {
  color: #2ecc71;
}

.summary-item .value.warning {
  color: #f1c40f;
}

.no-battle {
  text-align: center;
  padding: 4rem 2rem;
  background-color: rgba(0, 0, 0, 0.3);
  border-radius: 12px;
  margin-top: 2rem;
}

.no-battle h2 {
  color: #95a5a6;
  margin-bottom: 1rem;
}

.no-battle p {
  color: #7f8c8d;
  font-size: 1.1rem;
  margin-bottom: 2rem;
}

.setup-button {
  padding: 1rem 2rem;
  background-color: #3498db;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1.1rem;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s ease;
}

.setup-button:hover {
  background-color: #2980b9;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(52, 152, 219, 0.3);
}

.rom-controls {
  position: fixed;
  bottom: 2rem;
  right: 2rem;
  z-index: 100;
}

.reanalyze-button {
  padding: 0.75rem 1.5rem;
  background-color: rgba(52, 73, 94, 0.9);
  color: #ecf0f1;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  font-size: 0.9rem;
  cursor: pointer;
  transition: all 0.3s ease;
  backdrop-filter: blur(10px);
}

.reanalyze-button:hover {
  background-color: rgba(52, 73, 94, 1);
  border-color: rgba(255, 255, 255, 0.3);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

/* Responsive design */
@media (max-width: 768px) {
  .App-header {
    flex-direction: column;
    gap: 1rem;
  }

  .App-header h1 {
    font-size: 1.5rem;
  }

  .App-main {
    padding: 1rem;
  }

  .summary-content {
    grid-template-columns: 1fr;
  }

  .rom-controls {
    bottom: 1rem;
    right: 1rem;
  }
}
'''
}

def main():
    print(f"\n{BLUE}Pokemon Companion Tool - ROM Upload Feature Installer{RESET}")
    print(f"{BLUE}{'='*50}{RESET}\n")
    
    # Check if we're in the right directory
    if not os.path.exists('server') or not os.path.exists('client'):
        print_status("This script must be run from the pokemon-companion directory!", "error")
        print_status("Current directory: " + os.getcwd(), "info")
        return
    
    # Create backup directory
    backup_dir = "backup_before_rom_upload"
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)
        print_status(f"Created backup directory: {backup_dir}", "success")
    
    # Files to backup
    backup_files = [
        'server/server.js',
        'client/src/App.js',
        'client/src/App.css'
    ]
    
    # Backup existing files
    print(f"\n{BLUE}Backing up existing files...{RESET}")
    for file in backup_files:
        if os.path.exists(file):
            backup_path = os.path.join(backup_dir, file.replace('/', '_'))
            shutil.copy2(file, backup_path)
            print_status(f"Backed up: {file}", "success")
    
    # Create/update all files
    print(f"\n{BLUE}Installing ROM upload feature...{RESET}")
    success_count = 0
    total_files = len(FILES)
    
    for filepath, content in FILES.items():
        if create_file(filepath, content):
            success_count += 1
    
    # Update package.json for server
    print(f"\n{BLUE}Updating dependencies...{RESET}")
    server_package = 'server/package.json'
    if os.path.exists(server_package):
        update_package_json(server_package, {'multer': '^1.4.5-lts.1'})
    
    # Final summary
    print(f"\n{BLUE}{'='*50}{RESET}")
    print(f"{GREEN}Installation Complete!{RESET}")
    print(f"Files updated: {success_count}/{total_files}")
    
    if success_count == total_files:
        print(f"\n{GREEN}✓ All files successfully updated!{RESET}")
        print(f"\n{YELLOW}Next steps:{RESET}")
        print("1. cd server && npm install    (to install multer)")
        print("2. npm start                   (in server directory)")
        print("3. npm start                   (in client directory)")
        print(f"\n{BLUE}The ROM upload feature is now available in your companion tool!{RESET}")
    else:
        print(f"\n{RED}Some files failed to update. Please check the errors above.{RESET}")

if __name__ == "__main__":
    main()
// server/server-sni.js
// Pokemon Companion Tool - SNI Server with Proper Handshake

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
    isConnecting = false;
    connectionStatus = 'connected';
    messageBuffer = '';
    
    // Send SetName immediately
    console.log('Sending: SetName|PokemonCompanion');
    sniClient.write('SetName|PokemonCompanion\n');
    
    io.emit('connection-status', { status: 'connected' });
    
    // Start monitoring after handshake completes
    setTimeout(() => {
      if (connectionStatus === 'connected') {
        startBattleMonitoring();
      }
    }, 1000);
  });
  
  sniClient.on('data', (data) => {
    messageBuffer += data.toString();
    processMessages();
  });
  
  sniClient.on('close', () => {
    console.log('SNI connection closed');
    cleanup();
  });
  
  sniClient.on('error', (err) => {
    console.error('SNI error:', err.message);
    isConnecting = false;
    cleanup();
  });
}

function cleanup() {
  connectionStatus = 'disconnected';
  isConnecting = false;
  battleState = null;
  readQueue.length = 0;
  isProcessingRead = false;
  currentReadCallback = null;
  
  if (sniClient) {
    sniClient.destroy();
    sniClient = null;
  }
  
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
    monitoringInterval = null;
  }
  
  io.emit('connection-status', { status: 'disconnected' });
  io.emit('battle-update', null);
  
  if (!reconnectTimer) {
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null;
      connectToSNI();
    }, 5000);
  }
}

function processMessages() {
  const lines = messageBuffer.split('\n');
  messageBuffer = lines.pop() || '';
  
  for (const line of lines) {
    if (line.trim()) {
      processMessage(line.trim());
    }
  }
}

function processMessage(message) {
  // Handle hex data response
  if (message.match(/^[0-9a-fA-F]+$/)) {
    handleReadResponse(message);
    return;
  }
  
  // Handle Version request from SNI
  if (message === 'Version') {
    console.log('SNI version request received - responding...');
    // Respond with our version info
    const versionResponse = 'Version|PokemonCompanion|1.0|NodeJS\n';
    sniClient.write(versionResponse);
    console.log('Sent:', versionResponse.trim());
    return;
  }
  
  // Handle Version responses from other clients
  if (message.startsWith('Version|')) {
    console.log('Version info from other client:', message);
    return;
  }
  
  // Log other messages
  console.log('SNI message:', message);
}

function sendCommand(command) {
  if (!sniClient || connectionStatus !== 'connected') {
    return false;
  }
  
  try {
    sniClient.write(command + '\n');
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
  
  if (pokemon.level === 0 || pokemon.level > 100) return null;
  if (pokemon.hp.max === 0) return null;
  
  for (let i = 0; i < 4; i++) {
    const move = bytes[offset + POKEMON_OFFSETS.moves + i * 2] | 
                 (bytes[offset + POKEMON_OFFSETS.moves + i * 2 + 1] << 8);
    if (move > 0 && move < 1000) {
      pokemon.moves.push(move);
    }
  }
  
  return pokemon;
}

let monitoringInterval = null;

function startBattleMonitoring() {
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
  }
  
  console.log('Starting battle monitoring...');
  
  monitoringInterval = setInterval(() => {
    if (connectionStatus === 'connected' && !isProcessingRead) {
      checkBattleState();
    }
  }, 1000);
}

function checkBattleState() {
  readMemory(MEMORY.IN_BATTLE, 1, (bytes) => {
    if (!bytes || bytes.length === 0) return;
    
    const inBattle = bytes[0];
    
    if (inBattle !== 0) {
      readBattleData();
    } else {
      if (battleState) {
        console.log('Battle ended');
        battleState = null;
        io.emit('battle-update', null);
      }
    }
  });
}

function readBattleData() {
  readMemory(MEMORY.PARTY_ENEMY, 600, (enemyBytes) => {
    if (!enemyBytes) return;
    
    readMemory(MEMORY.PARTY_PLAYER, 600, (playerBytes) => {
      if (!playerBytes) return;
      
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
  
  const enemyInfo = pokemonData.getPokemonInfo(enemyPokemon.species);
  const playerInfo = pokemonData.getPokemonInfo(playerPokemon.species);
  
  const tierRating = pokemonData.calculateTierRating(enemyPokemon, enemyInfo);
  
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
  
  console.log(`Battle: ${playerInfo.name} vs ${enemyInfo.name}`);
  io.emit('battle-update', battleState);
}

// REST API
app.get('/api/status', (req, res) => {
  res.json({
    connection: connectionStatus,
    hasBattleData: battleState !== null
  });
});

app.get('/api/battle', (req, res) => {
  res.json(battleState);
});

// Socket.IO
io.on('connection', (socket) => {
  console.log('Web client connected');
  
  socket.emit('connection-status', { status: connectionStatus });
  if (battleState) {
    socket.emit('battle-update', battleState);
  }
  
  socket.on('disconnect', () => {
    console.log('Web client disconnected');
  });
});

// Start server
server.listen(HTTP_PORT, () => {
  console.log(`HTTP server listening on port ${HTTP_PORT}`);
  console.log('Connecting to SNI...');
  
  setTimeout(connectToSNI, 1000);
});

// Cleanup
process.on('SIGINT', () => {
  console.log('\nShutting down...');
  
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
  }
  
  if (monitoringInterval) {
    clearInterval(monitoringInterval);
  }
  
  if (sniClient) {
    sniClient.destroy();
  }
  
  server.close();
  process.exit(0);
});
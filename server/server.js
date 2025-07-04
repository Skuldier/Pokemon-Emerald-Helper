// server/server.js
// Pokemon Companion Tool - Direct Server (No SNI)

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
const TCP_PORT = 17242;  // For BizHawk Lua script connections
const HTTP_PORT = 3001;  // For web UI

// State
let bizhawkClient = null;
let battleState = null;
let connectionStatus = 'disconnected';

// Create TCP server for BizHawk connection
const tcpServer = net.createServer((socket) => {
  console.log('BizHawk connected from:', socket.remoteAddress);
  bizhawkClient = socket;
  connectionStatus = 'connected';
  
  // Notify web clients
  io.emit('connection-status', { status: 'connected' });
  
  let buffer = '';
  
  socket.on('data', (data) => {
    buffer += data.toString();
    
    // Process line-based protocol from your Lua script
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';
    
    for (const line of lines) {
      if (line.trim()) {
        handleBizHawkMessage(line.trim());
      }
    }
  });
  
  socket.on('end', () => {
    console.log('BizHawk disconnected');
    bizhawkClient = null;
    connectionStatus = 'disconnected';
    battleState = null;
    io.emit('connection-status', { status: 'disconnected' });
    io.emit('battle-update', null);
  });
  
  socket.on('error', (err) => {
    console.error('BizHawk socket error:', err);
  });
});

// Handle messages from BizHawk Lua script
function handleBizHawkMessage(message) {
  console.log('BizHawk message:', message);
  
  const parts = message.split('|');
  const command = parts[0];
  
  switch (command) {
    case 'Hello':
      // Handshake from Lua script
      const [_, name, platform, rom] = parts;
      console.log(`Hello from ${name} on ${platform}, playing ${rom}`);
      sendToBizHawk('Version|PokemonCompanion|1.0|Server');
      break;
      
    case 'Version':
      // Version info from Lua script
      console.log('BizHawk version:', parts.slice(1).join('|'));
      break;
      
    case 'PokemonData':
      // Battle data update: PokemonData|count|species|inBattle|frame
      const [_cmd, count, species, inBattle, frame] = parts;
      console.log(`Pokemon data: ${count} pokemon, species ${species}, battle: ${inBattle}`);
      
      // You can expand this to send full battle data
      if (inBattle === '1') {
        sendToBizHawk('RequestData');
      }
      break;
      
    case 'BattleUpdate':
      // Detailed battle data (you'll need to expand the Lua script for this)
      try {
        const battleData = JSON.parse(parts[1]);
        processBattleData(battleData);
      } catch (e) {
        console.error('Failed to parse battle data:', e);
      }
      break;
      
    case 'Read':
      // Handle read requests from Lua if needed
      const [_r, address, length] = parts;
      console.log(`Read request: ${address} for ${length} bytes`);
      // For now, just acknowledge
      sendToBizHawk('ReadResponse|OK');
      break;
      
    case 'BattleEnd':
      // Battle ended
      console.log('\n=== BATTLE ENDED ===\n');
      battleState = null;
      io.emit('battle-update', null);
      break;
      
    case 'Goodbye':
      console.log('BizHawk said goodbye');
      break;
      
    default:
      console.log('Unknown command:', command);
  }
}

// Send message to BizHawk
function sendToBizHawk(message) {
  if (bizhawkClient && bizhawkClient.writable) {
    bizhawkClient.write(message + '\n');
    console.log('Sent to BizHawk:', message);
  }
}

// Process battle data
function processBattleData(rawData) {
  if (!rawData || !rawData.enemy || !rawData.player) {
    console.log('Invalid battle data received');
    return;
  }
  
  const enemyPokemon = rawData.enemy;
  const playerPokemon = rawData.player;
  
  // Get Pokemon info from data files
  const enemyInfo = pokemonData.getPokemonInfo(enemyPokemon.species);
  const playerInfo = pokemonData.getPokemonInfo(playerPokemon.species);
  
  console.log(`\n=== BATTLE UPDATE ===`);
  console.log(`Player: ${playerInfo.name} (Lv.${playerPokemon.level}) HP: ${playerPokemon.hp_current}/${playerPokemon.hp_max}`);
  console.log(`Enemy: ${enemyInfo.name} (Lv.${enemyPokemon.level}) HP: ${enemyPokemon.hp_current}/${enemyPokemon.hp_max}`);
  
  // Calculate tier rating
  const tierRating = pokemonData.calculateTierRating(enemyPokemon, enemyInfo);
  console.log(`Enemy Tier: ${tierRating.overall} (Total Stats: ${tierRating.totalStats})`);
  
  // Calculate type effectiveness
  const effectiveness = pokemonData.calculateTypeEffectiveness(
    playerInfo.types,
    enemyInfo.types
  );
  
  console.log(`Type Matchup: Player ${effectiveness.attacking}x damage, Enemy ${effectiveness.defending}x damage`);
  console.log(`====================\n`);
  
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
  
  // Send to web UI
  io.emit('battle-update', battleState);
}

// REST API endpoints
app.get('/api/status', (req, res) => {
  res.json({
    bizhawkConnected: bizhawkClient !== null,
    hasBattleData: battleState !== null
  });
});

app.get('/api/battle', (req, res) => {
  res.json(battleState);
});

// Socket.IO for web UI
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

// Start TCP server for BizHawk
tcpServer.listen(TCP_PORT, () => {
  console.log(`TCP server listening on port ${TCP_PORT} for BizHawk connections`);
});

// Start HTTP server for web UI
server.listen(HTTP_PORT, () => {
  console.log(`HTTP server listening on port ${HTTP_PORT} for web UI`);
  console.log('');
  console.log('Ready for connections!');
  console.log('1. Make sure BizHawk is running with Pokemon Emerald');
  console.log('2. Load pokemon_companion.lua in BizHawk');
  console.log('3. Open http://localhost:3000 in your browser');
});

// Cleanup on exit
process.on('SIGINT', () => {
  console.log('\nShutting down...');
  
  if (bizhawkClient) {
    sendToBizHawk('Goodbye|Server');
    bizhawkClient.destroy();
  }
  
  tcpServer.close();
  server.close();
  process.exit(0);
});
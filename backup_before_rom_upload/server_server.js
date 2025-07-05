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
const TCP_PORT = 17242;
const HTTP_PORT = 3001;

// State
let bizhawkClient = null;
let battleState = null;
let connectionStatus = 'disconnected';

// Create TCP server for BizHawk connection
const tcpServer = net.createServer((socket) => {
  console.log('BizHawk attempting to connect...');
  bizhawkClient = socket;
  
  let buffer = '';
  
  socket.on('data', (data) => {
    buffer += data.toString();
    
    // Process complete lines
    const lines = buffer.split('\n');
    buffer = lines.pop(); // Keep incomplete line in buffer
    
    lines.forEach(line => {
      if (line.trim()) {
        handleBizHawkMessage(line.trim());
      }
    });
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
    console.error('TCP Socket error:', err);
  });
  
  // Send version info when client connects
  socket.write('Version|PokemonCompanion|1.0|Server\n');
});

function handleBizHawkMessage(message) {
  console.log('Received from BizHawk:', message);
  
  // Split message by pipe
  const parts = message.split('|');
  const command = parts[0];
  
  switch (command) {
    case 'Hello':
      console.log('BizHawk connected successfully');
      connectionStatus = 'connected';
      io.emit('connection-status', { status: 'connected' });
      break;
      
    case 'BattleUpdate':
      try {
        const jsonData = parts.slice(1).join('|'); // Rejoin in case JSON contains pipes
        const battleData = JSON.parse(jsonData);
        processBattleData(battleData);
      } catch (e) {
        console.error('Failed to parse battle data:', e);
      }
      break;
      
    case 'BattleEnd':
      console.log('Battle ended');
      battleState = null;
      io.emit('battle-update', null);
      break;
      
    case 'PartyUpdate':
      try {
        const jsonData = parts.slice(1).join('|');
        const partyData = JSON.parse(jsonData);
        console.log('Party update received:', partyData.party.length, 'Pokemon');
        // Handle party data if needed
      } catch (e) {
        console.error('Failed to parse party data:', e);
      }
      break;
      
    case 'Goodbye':
      console.log('BizHawk disconnecting gracefully');
      break;
      
    default:
      console.log('Unknown command:', command);
  }
}

function processBattleData(data) {
  if (!data || !data.enemy || !data.player) {
    console.log('Invalid battle data');
    return;
  }
  
  try {
    // Get Pokemon info from data files
    const enemyInfo = pokemonData.getPokemonInfo(data.enemy.species);
    const playerInfo = pokemonData.getPokemonInfo(data.player.species);
    
    // Calculate tier rating for enemy
    const enemyTierRating = pokemonData.calculateTierRating(data.enemy, enemyInfo);
    
    // Calculate type effectiveness
    const effectiveness = pokemonData.calculateTypeEffectiveness(
      playerInfo.types,
      enemyInfo.types
    );
    
    // Build complete battle state
    battleState = {
      enemy: {
        ...data.enemy,
        info: enemyInfo,
        tierRating: enemyTierRating
      },
      player: {
        ...data.player,
        info: playerInfo
      },
      effectiveness,
      timestamp: Date.now()
    };
    
    console.log(`Battle: ${playerInfo.name} (Lv.${data.player.level}) vs ${enemyInfo.name} (Lv.${data.enemy.level})`);
    console.log(`Enemy Tier: ${enemyTierRating.tier} (Score: ${enemyTierRating.score})`);
    
    // Send to all connected web clients
    io.emit('battle-update', battleState);
  } catch (e) {
    console.error('Error processing battle data:', e);
  }
}

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

app.get('/api/pokemon/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const info = pokemonData.getPokemonInfo(id);
  res.json(info);
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
tcpServer.listen(TCP_PORT, () => {
  console.log(`TCP server listening on port ${TCP_PORT} for BizHawk connection`);
});

server.listen(HTTP_PORT, () => {
  console.log(`HTTP server listening on port ${HTTP_PORT} for web clients`);
  console.log('\nWaiting for BizHawk to connect...');
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down...');
  
  if (bizhawkClient) {
    bizhawkClient.end();
  }
  
  tcpServer.close();
  server.close();
  
  process.exit(0);
});
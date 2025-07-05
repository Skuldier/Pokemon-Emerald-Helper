// server/server.js
// Pokemon Companion Tool - Direct TCP Mode Only

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
const TCP_PORT = 17242; // BizHawk connection port
const HTTP_PORT = 3001; // Web client port

// State
let tcpServer = null;
let bizhawkClient = null;
let battleState = null;
let connectionStatus = 'disconnected';
let romAnalysisResults = null;

// Configure multer for ROM uploads
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

// Create TCP server for BizHawk
tcpServer = net.createServer((socket) => {
  console.log('BizHawk connected via TCP!');
  bizhawkClient = socket;
  connectionStatus = 'connected';
  
  // Notify web clients
  io.emit('connection-status', { status: 'connected' });
  
  // Buffer for incomplete messages
  let buffer = '';
  
  socket.on('data', (data) => {
    buffer += data.toString();
    
    // Process complete messages (ending with newline)
    let lines = buffer.split('\n');
    buffer = lines.pop(); // Keep incomplete line in buffer
    
    for (const line of lines) {
      if (line.trim()) {
        try {
          const message = JSON.parse(line);
          console.log('Received:', message.type);
          handleBizhawkMessage(message);
        } catch (err) {
          console.error('Parse error:', err.message);
          console.error('Raw data:', line);
        }
      }
    }
  });
  
  socket.on('close', () => {
    console.log('BizHawk disconnected');
    bizhawkClient = null;
    connectionStatus = 'disconnected';
    battleState = null;
    
    // Notify web clients
    io.emit('connection-status', { status: 'disconnected' });
    io.emit('battle-update', null);
  });
  
  socket.on('error', (err) => {
    console.error('TCP error:', err.message);
  });
});

// Handle messages from BizHawk
function handleBizhawkMessage(message) {
  switch (message.type) {
    case 'battle_update':
      if (message.data) {
        battleState = processBattleData(message.data);
        io.emit('battle-update', battleState);
      }
      break;
      
    case 'heartbeat':
      // Keep connection alive
      if (message.data && !message.data.in_battle) {
        if (battleState) {
          battleState = null;
          io.emit('battle-update', null);
        }
      }
      break;
      
    case 'disconnect':
      console.log('BizHawk closing:', message.data?.reason || 'unknown');
      break;
      
    case 'test':
      console.log('Test message:', message.data);
      break;
      
    default:
      console.log('Unknown message type:', message.type);
  }
}

// Process battle data
function processBattleData(rawData) {
  if (!rawData || !rawData.enemy || !rawData.enemy.active) {
    return null;
  }
  
  const enemyPokemon = rawData.enemy.active;
  const playerPokemon = rawData.player.active;
  
  // Get Pokemon info
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

// ROM Analysis endpoint
app.post('/api/analyze-rom', upload.single('rom'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    console.log(`Analyzing ROM: ${req.file.originalname} (${req.file.size} bytes)`);

    const results = await analyzer.analyzeROM(req.file.buffer);
    romAnalysisResults = results;
    
    // Update memory addresses if DMA is disabled
    if (results.memoryAddresses && results.dmaStatus?.disabled) {
      if (results.memoryAddresses.partyPokemon) {
        MEMORY.PARTY_PLAYER = results.memoryAddresses.partyPokemon;
      }
      if (results.memoryAddresses.enemyPokemon) {
        MEMORY.PARTY_ENEMY = results.memoryAddresses.enemyPokemon;
      }
      console.log('Updated memory addresses based on ROM analysis');
    }

    res.json(results);
    
    // Notify clients
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

// ROM status endpoint
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

// Status endpoint
app.get('/api/status', (req, res) => {
  res.json({
    connection: connectionStatus,
    hasBattleData: battleState !== null,
    mode: 'direct'
  });
});

// Battle data endpoint
app.get('/api/battle', (req, res) => {
  res.json(battleState);
});

// Socket.IO for real-time web updates
io.on('connection', (socket) => {
  console.log('Web client connected');
  
  // Send current status
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
  console.log('======================================');
  console.log('Pokemon Companion Server - Direct Mode');
  console.log('======================================');
  console.log(`TCP server listening on port ${TCP_PORT} for BizHawk`);
  console.log(`HTTP server will start on port ${HTTP_PORT} for web clients`);
});

server.listen(HTTP_PORT, () => {
  console.log(`HTTP server started on port ${HTTP_PORT}`);
  console.log('');
  console.log('Ready for connections!');
  console.log('- Load pokemon_companion.lua in BizHawk');
  console.log('- Open http://localhost:3000 in your browser');
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down...');
  
  if (bizhawkClient) {
    bizhawkClient.end();
  }
  
  tcpServer.close(() => {
    console.log('TCP server closed');
  });
  
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});
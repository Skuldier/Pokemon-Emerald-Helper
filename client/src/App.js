import React, { useState, useEffect } from 'react';
import io from 'socket.io-client';
import './App.css';
import ConnectionStatus from './components/ConnectionStatus';
import BattleDisplay from './components/BattleDisplay';
import PokemonStats from './components/PokemonStats';
import TierRating from './components/TierRating';
import TypeEffectiveness from './components/TypeEffectiveness';

const SOCKET_URL = 'http://localhost:3001';

function App() {
  const [socket, setSocket] = useState(null);
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const [battleData, setBattleData] = useState(null);

  useEffect(() => {
    // Initialize socket connection
    const newSocket = io(SOCKET_URL);
    setSocket(newSocket);

    // Socket event handlers
    newSocket.on('connection-status', (data) => {
      setConnectionStatus(data.status);
    });

    newSocket.on('battle-update', (data) => {
      setBattleData(data);
    });

    // Cleanup on unmount
    return () => {
      newSocket.close();
    };
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>Pokemon Emerald Companion</h1>
        <ConnectionStatus status={connectionStatus} />
      </header>

      <main className="App-main">
        {battleData ? (
          <div className="battle-container">
            <div className="enemy-section">
              <h2>Wild {battleData.enemy.info.name}</h2>
              <BattleDisplay pokemon={battleData.enemy} />
              <TierRating rating={battleData.enemy.tierRating} />
            </div>

            <div className="info-section">
              <TypeEffectiveness effectiveness={battleData.effectiveness} />
              <PokemonStats 
                pokemon={battleData.enemy} 
                showDetails={true}
              />
            </div>

            <div className="player-section">
              <h3>Your {battleData.player.info.name}</h3>
              <PokemonStats 
                pokemon={battleData.player} 
                showDetails={false}
              />
            </div>
          </div>
        ) : (
          <div className="no-battle">
            {connectionStatus === 'connected' ? (
              <p>Waiting for battle...</p>
            ) : (
              <p>Connect BizHawk to start</p>
            )}
          </div>
        )}
      </main>
    </div>
  );
}

export default App;

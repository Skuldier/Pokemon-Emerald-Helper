// client/src/App.js
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

import React from 'react';
import './ConnectionStatus.css';

function ConnectionStatus({ status }) {
  const isConnected = status === 'connected';
  
  return (
    <div className={`connection-status ${isConnected ? 'connected' : 'disconnected'}`}>
      <span className="status-indicator"></span>
      <span className="status-text">
        {isConnected ? 'BizHawk Connected' : 'BizHawk Disconnected'}
      </span>
    </div>
  );
}

export default ConnectionStatus;
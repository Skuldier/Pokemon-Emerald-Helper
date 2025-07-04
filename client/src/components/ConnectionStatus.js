import React from 'react';
import './ConnectionStatus.css';

function ConnectionStatus({ status }) {
  return (
    <div className={`connection-status ${status}`}>
      <span className="status-dot"></span>
      <span className="status-text">
        {status === 'connected' ? 'BizHawk Connected' : 'BizHawk Disconnected'}
      </span>
    </div>
  );
}

export default ConnectionStatus;

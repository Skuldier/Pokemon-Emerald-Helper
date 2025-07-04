import React from 'react';
import './TypeEffectiveness.css';

function TypeEffectiveness({ effectiveness }) {
  // Safety check
  if (!effectiveness) {
    return <div className="type-effectiveness">Loading type matchup...</div>;
  }

  const { attacking = {}, defending = {} } = effectiveness;
  const { weakTo = [], resists = [], immuneTo = [] } = defending;

  return (
    <div className="type-effectiveness">
      <h3>Type Matchup</h3>
      
      {Object.keys(attacking).length > 0 && (
        <div className="effectiveness-section">
          <h4>Your Attack Effectiveness</h4>
          {Object.entries(attacking).map(([type, multiplier]) => (
            <div key={type} className="effectiveness-item">
              <span className={`type-badge type-${type}`}>{type}</span>
              <span className={`multiplier mult-${multiplier}`}>
                {multiplier === 0 ? 'No Effect' : `${multiplier}x`}
              </span>
            </div>
          ))}
        </div>
      )}

      <div className="effectiveness-section">
        <h4>Enemy Weaknesses</h4>
        {weakTo.length > 0 ? (
          <div className="type-list">
            {weakTo.map(type => (
              <span key={type} className={`type-badge type-${type}`}>
                {type}
              </span>
            ))}
          </div>
        ) : (
          <p className="no-types">No weaknesses</p>
        )}
      </div>

      <div className="effectiveness-section">
        <h4>Enemy Resistances</h4>
        {resists.length > 0 ? (
          <div className="type-list">
            {resists.map(type => (
              <span key={type} className={`type-badge type-${type}`}>
                {type}
              </span>
            ))}
          </div>
        ) : (
          <p className="no-types">No resistances</p>
        )}
      </div>

      {immuneTo.length > 0 && (
        <div className="effectiveness-section">
          <h4>Enemy Immunities</h4>
          <div className="type-list">
            {immuneTo.map(type => (
              <span key={type} className={`type-badge type-${type}`}>
                {type}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default TypeEffectiveness;
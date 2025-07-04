import React from 'react';
import './TypeEffectiveness.css';

function TypeEffectiveness({ effectiveness }) {
  const { attacking, defending } = effectiveness;

  return (
    <div className="type-effectiveness">
      <h3>Type Matchup</h3>
      
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

      <div className="effectiveness-section">
        <h4>Enemy Weaknesses</h4>
        {defending.weakTo.length > 0 ? (
          <div className="type-list">
            {defending.weakTo.map(type => (
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
        {defending.resists.length > 0 ? (
          <div className="type-list">
            {defending.resists.map(type => (
              <span key={type} className={`type-badge type-${type}`}>
                {type}
              </span>
            ))}
          </div>
        ) : (
          <p className="no-types">No resistances</p>
        )}
      </div>

      {defending.immuneTo.length > 0 && (
        <div className="effectiveness-section">
          <h4>Enemy Immunities</h4>
          <div className="type-list">
            {defending.immuneTo.map(type => (
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

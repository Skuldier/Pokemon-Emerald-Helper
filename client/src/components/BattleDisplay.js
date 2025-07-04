import React from 'react';
import './BattleDisplay.css';

function BattleDisplay({ pokemon }) {
  const hpPercentage = (pokemon.hp.current / pokemon.hp.max) * 100;
  const hpColor = hpPercentage > 50 ? '#2ecc71' : hpPercentage > 20 ? '#f39c12' : '#e74c3c';

  return (
    <div className="battle-display">
      <div className="pokemon-sprite">
        {/* Placeholder for sprite - you can add actual sprite loading here */}
        <div className="sprite-placeholder">
          #{pokemon.species}
        </div>
      </div>

      <div className="pokemon-info">
        <div className="level">Lv. {pokemon.level}</div>
        <div className="types">
          {pokemon.info.types.map(type => (
            <span key={type} className={`type-badge type-${type}`}>
              {type}
            </span>
          ))}
        </div>
      </div>

      <div className="hp-bar">
        <div className="hp-text">
          HP: {pokemon.hp.current} / {pokemon.hp.max}
        </div>
        <div className="hp-bar-container">
          <div 
            className="hp-bar-fill"
            style={{ 
              width: `${hpPercentage}%`,
              backgroundColor: hpColor
            }}
          />
        </div>
      </div>

      <div className="moves">
        <h4>Moves:</h4>
        <div className="move-list">
          {pokemon.moves.map((moveId, index) => (
            <div key={index} className="move">
              Move #{moveId}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default BattleDisplay;

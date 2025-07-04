import React from 'react';
import './BattleDisplay.css';

function BattleDisplay({ pokemon }) {
  // Safety checks
  if (!pokemon || !pokemon.hp) {
    return <div className="battle-display">Loading...</div>;
  }

  const hpPercentage = (pokemon.hp.current / pokemon.hp.max) * 100;
  const hpColor = hpPercentage > 50 ? '#2ecc71' : hpPercentage > 20 ? '#f39c12' : '#e74c3c';

  // Safely get types array
  const types = pokemon.info?.types || ['unknown'];
  
  // Safely get moves array
  const moves = pokemon.moves || [];

  return (
    <div className="battle-display">
      <div className="pokemon-sprite">
        {/* Placeholder for sprite - you can add actual sprite loading here */}
        <div className="sprite-placeholder">
          #{pokemon.species}
        </div>
      </div>

      <div className="pokemon-info">
        <h3>{pokemon.info?.name || `Pokemon #${pokemon.species}`}</h3>
        <div className="level">Lv. {pokemon.level}</div>
        <div className="types">
          {types.map(type => (
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

      {moves.length > 0 && (
        <div className="moves">
          <h4>Moves:</h4>
          <div className="move-list">
            {moves.map((moveId, index) => (
              <div key={index} className="move">
                Move #{moveId}
              </div>
            ))}
          </div>
        </div>
      )}

      {pokemon.stats && (
        <div className="stats">
          <h4>Stats:</h4>
          <div className="stat-list">
            <div className="stat">ATK: {pokemon.stats.attack || pokemon.attack}</div>
            <div className="stat">DEF: {pokemon.stats.defense || pokemon.defense}</div>
            <div className="stat">SPD: {pokemon.stats.speed || pokemon.speed}</div>
            <div className="stat">S.ATK: {pokemon.stats.sp_attack || pokemon.sp_attack}</div>
            <div className="stat">S.DEF: {pokemon.stats.sp_defense || pokemon.sp_defense}</div>
          </div>
        </div>
      )}
    </div>
  );
}

export default BattleDisplay;
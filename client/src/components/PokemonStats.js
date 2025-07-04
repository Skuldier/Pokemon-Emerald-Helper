import React from 'react';
import './PokemonStats.css';

function PokemonStats({ pokemon, showDetails = true }) {
  const stats = pokemon.stats || pokemon.info.stats;
  const maxStat = 255; // Max stat value in Gen 3

  const statNames = {
    hp: 'HP',
    attack: 'Attack',
    defense: 'Defense',
    spAttack: 'Sp. Atk',
    spDefense: 'Sp. Def',
    speed: 'Speed'
  };

  return (
    <div className="pokemon-stats">
      <h4>Stats</h4>
      <div className="stats-grid">
        {Object.entries(stats).map(([stat, value]) => (
          <div key={stat} className="stat-row">
            <span className="stat-name">{statNames[stat] || stat}</span>
            <span className="stat-value">{value}</span>
            {showDetails && (
              <div className="stat-bar">
                <div 
                  className="stat-fill"
                  style={{ 
                    width: `${(value / maxStat) * 100}%`,
                    backgroundColor: getStatColor(value)
                  }}
                />
              </div>
            )}
          </div>
        ))}
      </div>
      {showDetails && (
        <div className="stat-total">
          <span>Base Stat Total:</span>
          <span className="total-value">
            {Object.values(stats).reduce((sum, stat) => sum + stat, 0)}
          </span>
        </div>
      )}
    </div>
  );
}

function getStatColor(value) {
  if (value >= 150) return '#e74c3c';
  if (value >= 100) return '#f39c12';
  if (value >= 70) return '#f1c40f';
  if (value >= 50) return '#3498db';
  return '#95a5a6';
}

export default PokemonStats;

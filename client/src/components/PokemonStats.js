import React from 'react';
import './PokemonStats.css';

function PokemonStats({ pokemon, showDetails }) {
  if (!pokemon) {
    return <div className="pokemon-stats">No data</div>;
  }

  // Get stats from either nested stats object or flat properties
  const stats = pokemon.stats || {
    hp: pokemon.hp_max,
    attack: pokemon.attack,
    defense: pokemon.defense,
    speed: pokemon.speed,
    sp_attack: pokemon.sp_attack,
    sp_defense: pokemon.sp_defense
  };

  return (
    <div className="pokemon-stats">
      <h4>{showDetails ? 'Detailed Stats' : 'Quick Stats'}</h4>
      
      <div className="stat-item">
        <span className="stat-label">HP</span>
        <span className="stat-value">{stats.hp || stats.hp_max || '?'}</span>
      </div>

      <div className="stat-item">
        <span className="stat-label">Attack</span>
        <span className="stat-value">{stats.attack || '?'}</span>
      </div>

      <div className="stat-item">
        <span className="stat-label">Defense</span>
        <span className="stat-value">{stats.defense || '?'}</span>
      </div>

      <div className="stat-item">
        <span className="stat-label">Speed</span>
        <span className="stat-value">{stats.speed || '?'}</span>
      </div>

      {showDetails && (
        <>
          <div className="stat-item">
            <span className="stat-label">Sp. Attack</span>
            <span className="stat-value">{stats.sp_attack || stats.spAttack || '?'}</span>
          </div>

          <div className="stat-item">
            <span className="stat-label">Sp. Defense</span>
            <span className="stat-value">{stats.sp_defense || stats.spDefense || '?'}</span>
          </div>

          {pokemon.nature !== undefined && (
            <div className="stat-item">
              <span className="stat-label">Nature</span>
              <span className="stat-value">#{pokemon.nature}</span>
            </div>
          )}

          {pokemon.ability_slot !== undefined && (
            <div className="stat-item">
              <span className="stat-label">Ability Slot</span>
              <span className="stat-value">{pokemon.ability_slot + 1}</span>
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default PokemonStats;
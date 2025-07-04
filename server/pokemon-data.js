// Pokemon data and calculations for Generation 3

const pokemonBaseStats = {
  // Sample data - you'll need to add all 386 Pokemon
  1: { name: "Bulbasaur", types: ["grass", "poison"], stats: { hp: 45, attack: 49, defense: 49, spAttack: 65, spDefense: 65, speed: 45 }},
  4: { name: "Charmander", types: ["fire"], stats: { hp: 39, attack: 52, defense: 43, spAttack: 60, spDefense: 50, speed: 65 }},
  7: { name: "Squirtle", types: ["water"], stats: { hp: 44, attack: 48, defense: 65, spAttack: 50, spDefense: 64, speed: 43 }},
  25: { name: "Pikachu", types: ["electric"], stats: { hp: 35, attack: 55, defense: 40, spAttack: 50, spDefense: 50, speed: 90 }},
  // Add more Pokemon...
};

const typeChart = {
  normal: { weak: ["fighting"], resist: [], immune: ["ghost"] },
  fire: { weak: ["water", "ground", "rock"], resist: ["fire", "grass", "ice", "bug", "steel", "fairy"], immune: [] },
  water: { weak: ["electric", "grass"], resist: ["fire", "water", "ice", "steel"], immune: [] },
  electric: { weak: ["ground"], resist: ["electric", "flying", "steel"], immune: [] },
  grass: { weak: ["fire", "ice", "poison", "flying", "bug"], resist: ["water", "electric", "grass", "ground"], immune: [] },
  ice: { weak: ["fire", "fighting", "rock", "steel"], resist: ["ice"], immune: [] },
  fighting: { weak: ["flying", "psychic", "fairy"], resist: ["bug", "rock", "dark"], immune: [] },
  poison: { weak: ["ground", "psychic"], resist: ["grass", "fighting", "poison", "bug", "fairy"], immune: [] },
  ground: { weak: ["water", "grass", "ice"], resist: ["poison", "rock"], immune: ["electric"] },
  flying: { weak: ["electric", "ice", "rock"], resist: ["grass", "fighting", "bug"], immune: ["ground"] },
  psychic: { weak: ["bug", "ghost", "dark"], resist: ["fighting", "psychic"], immune: [] },
  bug: { weak: ["fire", "flying", "rock"], resist: ["grass", "fighting", "ground"], immune: [] },
  rock: { weak: ["water", "grass", "fighting", "ground", "steel"], resist: ["normal", "fire", "poison", "flying"], immune: [] },
  ghost: { weak: ["ghost", "dark"], resist: ["poison", "bug"], immune: ["normal", "fighting"] },
  dragon: { weak: ["ice", "dragon", "fairy"], resist: ["fire", "water", "electric", "grass"], immune: [] },
  dark: { weak: ["fighting", "bug", "fairy"], resist: ["ghost", "dark"], immune: ["psychic"] },
  steel: { weak: ["fire", "fighting", "ground"], resist: ["normal", "grass", "ice", "flying", "psychic", "bug", "rock", "dragon", "steel", "fairy"], immune: ["poison"] },
  fairy: { weak: ["poison", "steel"], resist: ["fighting", "bug", "dark"], immune: ["dragon"] }
};

const moveData = {
  // Sample move data
  1: { name: "Pound", type: "normal", power: 40, category: "physical" },
  33: { name: "Tackle", type: "normal", power: 40, category: "physical" },
  // Add more moves...
};

function getPokemonInfo(speciesId) {
  const baseInfo = pokemonBaseStats[speciesId] || {
    name: `Unknown (${speciesId})`,
    types: ["normal"],
    stats: { hp: 50, attack: 50, defense: 50, spAttack: 50, spDefense: 50, speed: 50 }
  };
  
  return {
    ...baseInfo,
    speciesId
  };
}

function calculateBST(stats) {
  return Object.values(stats).reduce((sum, stat) => sum + stat, 0);
}

function calculateTierRating(pokemon, pokemonInfo) {
  // Build stats object from either pokemon data or base stats
  let stats;
  if (pokemon.stats) {
    // If pokemon has a stats object, use it
    stats = pokemon.stats;
  } else if (pokemon.hp_max) {
    // If pokemon has individual stat fields from Lua script
    stats = {
      hp: pokemon.hp_max,
      attack: pokemon.attack,
      defense: pokemon.defense,
      spAttack: pokemon.sp_attack,
      spDefense: pokemon.sp_defense,
      speed: pokemon.speed
    };
  } else {
    // Fall back to base stats
    stats = pokemonInfo.stats;
  }
  
  const bst = calculateBST(stats);
  
  // Weight different aspects for randomizer play
  const bstScore = Math.min(bst / 600, 1.0) * 100; // Normalize to 100
  const hpWeight = (stats.hp / 255) * 150; // HP is crucial in randomizers
  const speedWeight = (stats.speed / 200) * 130; // Speed for survival
  const defenseWeight = ((stats.defense + stats.spDefense) / 400) * 120;
  
  // Move pool score - handle missing moves data
  let moveScore = 50; // Default score if no move data
  if (pokemon.moves && Array.isArray(pokemon.moves)) {
    moveScore = pokemon.moves.length * 25;
  } else if (pokemon.moves && typeof pokemon.moves === 'object') {
    // Handle moves as object (from Lua table)
    moveScore = Object.keys(pokemon.moves).length * 25;
  }
  
  // Type defensive score
  const typeScore = calculateTypeDefensiveScore(pokemonInfo.types) * 100;
  
  // Calculate weighted total
  const totalScore = (
    bstScore * 0.25 +
    hpWeight * 0.20 +
    speedWeight * 0.15 +
    defenseWeight * 0.15 +
    moveScore * 0.15 +
    typeScore * 0.10
  );
  
  // Convert to tier
  let tier, rating;
  if (totalScore >= 90) {
    tier = 'S';
    rating = 5;
  } else if (totalScore >= 75) {
    tier = 'A';
    rating = 4;
  } else if (totalScore >= 60) {
    tier = 'B';
    rating = 3;
  } else if (totalScore >= 45) {
    tier = 'C';
    rating = 2;
  } else {
    tier = 'D';
    rating = 1;
  }
  
  return {
    tier,
    rating,
    score: Math.round(totalScore),
    details: {
      bst: Math.round(bstScore),
      hp: Math.round(hpWeight),
      speed: Math.round(speedWeight),
      defense: Math.round(defenseWeight),
      moves: Math.round(moveScore),
      typing: Math.round(typeScore)
    }
  };
}

function calculateTypeDefensiveScore(types) {
  let weaknesses = 0;
  let resistances = 0;
  let immunities = 0;
  
  // Check all type matchups
  Object.keys(typeChart).forEach(attackType => {
    const effectiveness = getTypeEffectiveness(attackType, types);
    if (effectiveness > 1) weaknesses++;
    else if (effectiveness < 1 && effectiveness > 0) resistances++;
    else if (effectiveness === 0) immunities++;
  });
  
  // Score based on defensive profile
  return (resistances * 2 + immunities * 4 - weaknesses * 3) / 20 + 0.5;
}

function getTypeEffectiveness(attackType, defenderTypes) {
  let multiplier = 1;
  
  defenderTypes.forEach(defType => {
    const chart = typeChart[defType];
    if (chart.weak.includes(attackType)) multiplier *= 2;
    else if (chart.resist.includes(attackType)) multiplier *= 0.5;
    else if (chart.immune.includes(attackType)) multiplier *= 0;
  });
  
  return multiplier;
}

function calculateTypeEffectiveness(attackerTypes, defenderTypes) {
  const effectiveness = {};
  
  attackerTypes.forEach(atkType => {
    effectiveness[atkType] = getTypeEffectiveness(atkType, defenderTypes);
  });
  
  // Also calculate what the defender is weak/resistant to
  const defensiveProfile = {
    weakTo: [],
    resists: [],
    immuneTo: []
  };
  
  Object.keys(typeChart).forEach(type => {
    const eff = getTypeEffectiveness(type, defenderTypes);
    if (eff > 1) defensiveProfile.weakTo.push(type);
    else if (eff < 1 && eff > 0) defensiveProfile.resists.push(type);
    else if (eff === 0) defensiveProfile.immuneTo.push(type);
  });
  
  return {
    attacking: effectiveness,
    defending: defensiveProfile
  };
}

module.exports = {
  getPokemonInfo,
  calculateTierRating,
  calculateTypeEffectiveness,
  pokemonBaseStats,
  typeChart,
  moveData
};
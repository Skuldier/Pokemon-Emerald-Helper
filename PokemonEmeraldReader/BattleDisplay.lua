-- BattleDisplay.lua
-- Enhanced battle information display for randomizers

local Memory = require("Memory")
local Pointers = require("Pointers")
local ROMData = require("ROMData")
local PokemonReader = require("PokemonReader")

local BattleDisplay = {}

-- Read enemy Pokemon in battle
function BattleDisplay.readEnemyPokemon()
    local battleState = Pointers.getBattleState()
    if not battleState or not battleState.inBattle then
        return nil
    end
    
    -- For wild battles, enemy is in first slot of enemy party
    local enemyPartyAddr = Pointers.getEnemyPartyAddress()
    if not enemyPartyAddr then return nil end
    
    local enemyPokemon = PokemonReader.readPokemon(enemyPartyAddr + 4, false)
    if enemyPokemon then
        -- Add tier rating
        enemyPokemon.tierRating = ROMData.calculateRandomizerTier(enemyPokemon.species)
    end
    
    return enemyPokemon, battleState
end

-- Display wild Pokemon encounter
function BattleDisplay.displayWildEncounter(pokemon)
    console.log("\n=== WILD POKEMON ENCOUNTER ===")
    console.log(string.rep("═", 50))
    
    -- Pokemon name and level
    local name = pokemon.baseData and pokemon.baseData.name or "???"
    console.log(string.format("Wild %s appeared! (Lv.%d)", name, pokemon.battleStats.level or 0))
    
    -- Types
    if pokemon.baseData then
        local type1 = ROMData.getTypeName(pokemon.baseData.type1) or "???"
        local type2 = ROMData.getTypeName(pokemon.baseData.type2) or "???"
        if type1 == type2 then
            console.log(string.format("Type: %s", type1))
        else
            console.log(string.format("Types: %s / %s", type1, type2))
        end
    end
    
    -- Tier rating with visual stars
    if pokemon.tierRating then
        local stars = string.rep("★", pokemon.tierRating.stars) .. string.rep("☆", 5 - pokemon.tierRating.stars)
        console.log(string.format("\nRANDOMIZER TIER: %s %s", pokemon.tierRating.tier, stars))
        console.log(string.format("Overall Score: %d/100", pokemon.tierRating.score))
        
        -- Tier breakdown
        console.log("\nTier Analysis:")
        console.log(string.format("  BST:     %3d [%s]", 
            pokemon.tierRating.details.bst,
            BattleDisplay.makeBar(pokemon.tierRating.details.bst, 100, 20)))
        console.log(string.format("  HP:      %3d [%s]", 
            pokemon.tierRating.details.hp,
            BattleDisplay.makeBar(pokemon.tierRating.details.hp, 150, 20)))
        console.log(string.format("  Speed:   %3d [%s]", 
            pokemon.tierRating.details.speed,
            BattleDisplay.makeBar(pokemon.tierRating.details.speed, 130, 20)))
        console.log(string.format("  Defense: %3d [%s]", 
            pokemon.tierRating.details.defense,
            BattleDisplay.makeBar(pokemon.tierRating.details.defense, 120, 20)))
        console.log(string.format("  Typing:  %3d [%s]", 
            pokemon.tierRating.details.typing,
            BattleDisplay.makeBar(pokemon.tierRating.details.typing, 100, 20)))
        
        -- Recommendation
        console.log("\n" .. BattleDisplay.getTierRecommendation(pokemon.tierRating.tier))
    end
    
    -- Stats
    if pokemon.battleStats then
        console.log("\nStats:")
        console.log(string.format("  HP:  %3d | ATK: %3d | DEF: %3d",
            pokemon.battleStats.maxHP or 0,
            pokemon.battleStats.attack or 0,
            pokemon.battleStats.defense or 0))
        console.log(string.format("  SPE: %3d | SPA: %3d | SPD: %3d",
            pokemon.battleStats.speed or 0,
            pokemon.battleStats.spAttack or 0,
            pokemon.battleStats.spDefense or 0))
    end
    
    -- Ability
    local abilityName = ROMData.getAbilityName(pokemon.ability) or "???"
    console.log(string.format("\nAbility: %s", abilityName))
    
    console.log(string.rep("═", 50))
end

-- Create a visual bar
function BattleDisplay.makeBar(value, max, width)
    local filled = math.floor((value / max) * width)
    filled = math.min(filled, width)
    filled = math.max(filled, 0)
    
    return string.rep("█", filled) .. string.rep("░", width - filled)
end

-- Get tier recommendation
function BattleDisplay.getTierRecommendation(tier)
    local recommendations = {
        S = "⭐ EXCELLENT CATCH! Top-tier Pokemon for randomizers!",
        A = "✨ Great Pokemon! Highly recommended for your team.",
        B = "👍 Solid choice. Will perform well with good moves.",
        C = "⚡ Usable, but may need replacement later.",
        D = "⚠️  Low tier. Only use if no better options available."
    }
    return recommendations[tier] or "❓ Unknown tier"
end

-- Display type effectiveness
function BattleDisplay.displayTypeEffectiveness(attackerTypes, defenderTypes)
    console.log("\n=== TYPE EFFECTIVENESS ===")
    
    -- Your attacks vs enemy
    console.log("Your attacks:")
    for _, atkType in ipairs(attackerTypes) do
        local effectiveness = 10  -- Normal
        
        for _, defType in ipairs(defenderTypes) do
            if ROMData.data.typeChart[atkType] and ROMData.data.typeChart[atkType][defType] then
                local eff = ROMData.data.typeChart[atkType][defType]
                effectiveness = (effectiveness * eff) / 10
            end
        end
        
        local typeName = ROMData.getTypeName(atkType) or "???"
        local effectStr = ""
        
        if effectiveness >= 20 then
            effectStr = "SUPER EFFECTIVE! (x" .. (effectiveness / 10) .. ")"
        elseif effectiveness <= 5 and effectiveness > 0 then
            effectStr = "Not very effective (x" .. (effectiveness / 10) .. ")"
        elseif effectiveness == 0 then
            effectStr = "NO EFFECT!"
        else
            effectStr = "Normal damage (x1)"
        end
        
        console.log(string.format("  %s: %s", typeName, effectStr))
    end
end

-- Display trainer battle
function BattleDisplay.displayTrainerBattle(pokemon, trainerName)
    console.log("\n=== TRAINER BATTLE ===")
    console.log(string.rep("═", 50))
    
    -- Trainer info
    console.log(string.format("Trainer %s sent out %s!", 
        trainerName or "???", 
        pokemon.baseData and pokemon.baseData.name or "???"))
    
    -- Continue with similar display as wild
    BattleDisplay.displayWildEncounter(pokemon)
end

return BattleDisplay

-- clean_investigation.lua
-- Simplified investigation without deprecation warnings

local Memory = require("Memory")
local Pointers = require("Pointers")
local ROMData = require("ROMData")

-- Use modern operators
local function bxor(a, b) return a ~ b end
local function band(a, b) return a & b end
local function bor(a, b) return a | b end
local function lshift(a, b) return a << b end
local function rshift(a, b) return a >> b end

console.clear()
console.log("=== POKEMON & ABILITY INVESTIGATION ===\n")

-- Initialize ROM data
if not ROMData.data.initialized then
    ROMData.init()
end

-- Get party
local partyAddr = Pointers.getPartyAddress()
if not partyAddr then
    console.log("ERROR: Cannot find party!")
    return
end

local partyCount = Memory.read_u32_le(partyAddr)
console.log(string.format("Found %d Pokemon in party\n", partyCount))

-- Simple substructure order lookup
local SUBSTRUCTURE_ORDERS = {
    {0, 1, 2, 3}, {0, 1, 3, 2}, {0, 2, 1, 3}, {0, 2, 3, 1}, {0, 3, 1, 2}, {0, 3, 2, 1},
    {1, 0, 2, 3}, {1, 0, 3, 2}, {1, 2, 0, 3}, {1, 2, 3, 0}, {1, 3, 0, 2}, {1, 3, 2, 0},
    {2, 0, 1, 3}, {2, 0, 3, 1}, {2, 1, 0, 3}, {2, 1, 3, 0}, {2, 3, 0, 1}, {2, 3, 1, 0},
    {3, 0, 1, 2}, {3, 0, 2, 1}, {3, 1, 0, 2}, {3, 1, 2, 0}, {3, 2, 0, 1}, {3, 2, 1, 0}
}

-- Analyze each Pokemon (simplified)
for i = 0, math.min(partyCount - 1, 5) do
    local pokemonAddr = partyAddr + 4 + (i * 100)
    console.log(string.format("=== POKEMON #%d ===", i + 1))
    
    -- Read basic data
    local personality = Memory.read_u32_le(pokemonAddr + 0) or 0
    local otId = Memory.read_u32_le(pokemonAddr + 4) or 0
    local key = bxor(personality, otId)
    
    -- Get nickname
    local nickname = ""
    for j = 0, 9 do
        local char = Memory.read_u8(pokemonAddr + 8 + j)
        if char == 0xFF then break end
        if char >= 0xBB and char <= 0xD4 then
            nickname = nickname .. string.char(char - 0xBB + 65)
        elseif char >= 0xD5 and char <= 0xEE then
            nickname = nickname .. string.char(char - 0xD5 + 97)
        end
    end
    
    console.log("Nickname: " .. (nickname ~= "" and nickname or "(none)"))
    
    -- Determine substructure order
    local orderIndex = personality % 24
    local order = SUBSTRUCTURE_ORDERS[orderIndex + 1]
    
    -- Find where each substructure is
    local growthPos = -1
    local attacksPos = -1
    local miscPos = -1
    
    for pos = 1, 4 do
        if order[pos] == 0 then growthPos = pos - 1
        elseif order[pos] == 1 then attacksPos = pos - 1
        elseif order[pos] == 3 then miscPos = pos - 1
        end
    end
    
    -- Read species from Growth substructure
    local speciesOffset = 32 + (growthPos * 12)
    local encSpecies1 = Memory.read_u8(pokemonAddr + speciesOffset) or 0
    local encSpecies2 = Memory.read_u8(pokemonAddr + speciesOffset + 1) or 0
    local encSpeciesWord = bor(encSpecies1, lshift(encSpecies2, 8))
    local species = bxor(encSpeciesWord, band(key, 0xFFFF))
    
    console.log(string.format("Species ID: %d", species))
    
    -- Get species data
    if species > 0 and species < 500 then
        local speciesData = ROMData.getPokemon(species)
        if speciesData then
            console.log(string.format("Species Name: %s", speciesData.name or "Unknown"))
            
            -- Show abilities
            local ability1 = ROMData.getAbilityName(speciesData.ability1) or 
                           string.format("#%d", speciesData.ability1 or 0)
            local ability2 = "None"
            if speciesData.ability2 then
                ability2 = ROMData.getAbilityName(speciesData.ability2) or 
                          string.format("#%d", speciesData.ability2)
            end
            console.log(string.format("Possible Abilities: %s / %s", ability1, ability2))
            
            -- Get ability bit from Misc substructure
            if miscPos >= 0 then
                local miscOffset = 32 + (miscPos * 12) + 4
                local ivBytes = {}
                for j = 0, 3 do
                    ivBytes[j + 1] = Memory.read_u8(pokemonAddr + miscOffset + j) or 0
                end
                
                -- Decrypt
                local ivWord = bor(ivBytes[1], lshift(ivBytes[2], 8), 
                                 lshift(ivBytes[3], 16), lshift(ivBytes[4], 24))
                local decryptedIV = bxor(ivWord, key)
                local abilityBit = band(rshift(decryptedIV, 31), 0x1)
                
                local activeAbility = abilityBit == 0 and speciesData.ability1 or 
                                    (speciesData.ability2 or speciesData.ability1)
                local activeAbilityName = ROMData.getAbilityName(activeAbility) or 
                                        string.format("#%d", activeAbility or 0)
                
                console.log(string.format("Active Ability: %s (bit=%d)", activeAbilityName, abilityBit))
            end
        end
    end
    
    -- Read moves from Attacks substructure
    if attacksPos >= 0 then
        local movesOffset = 32 + (attacksPos * 12)
        console.log("Moves:")
        
        for j = 0, 3 do
            local moveOffset = movesOffset + (j * 2)
            local encMove1 = Memory.read_u8(pokemonAddr + moveOffset) or 0
            local encMove2 = Memory.read_u8(pokemonAddr + moveOffset + 1) or 0
            local encMoveWord = bor(encMove1, lshift(encMove2, 8))
            local moveId = bxor(encMoveWord, band(key, 0xFFFF))
            
            if moveId > 0 then
                local moveName = "Unknown"
                if moveId <= 354 then
                    local moveData = ROMData.getMove(moveId)
                    moveName = moveData and moveData.name or string.format("#%d", moveId)
                else
                    moveName = string.format("Custom#%d", moveId)
                end
                console.log(string.format("  %d. %s", j + 1, moveName))
            end
        end
    end
    
    -- Battle stats
    local level = Memory.read_u8(pokemonAddr + 84) or 0
    local currentHP = Memory.read_u16_le(pokemonAddr + 86) or 0
    local maxHP = Memory.read_u16_le(pokemonAddr + 88) or 0
    console.log(string.format("Level: %d, HP: %d/%d", level, currentHP, maxHP))
    
    console.log("")
end

-- Quick ability test
console.log("=== ABILITY TEST ===")
console.log("Testing if abilities load correctly...")
local testAbilities = {1, 5, 10, 22, 33, 65, 66, 67}
local loaded = 0
for _, id in ipairs(testAbilities) do
    if ROMData.getAbilityName(id) then
        loaded = loaded + 1
    end
end
console.log(string.format("Loaded %d/%d test abilities", loaded, #testAbilities))

console.log("\n=== INVESTIGATION COMPLETE ===")
console.log("Key findings:")
console.log("- Each Pokemon has possible abilities defined by species")
console.log("- The ability bit (0/1) in the IV data determines active ability")
console.log("- Custom moves (ID > 354) are Archipelago-specific")
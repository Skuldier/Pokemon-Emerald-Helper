#!/usr/bin/env python3
"""
Pokemon Emerald Reader - Battle Display Update Deployment Script
This script updates your existing files with battle display and tier rating features
"""

import os
import shutil
import datetime
from pathlib import Path

# Define all file updates
FILE_UPDATES = {
    'PokemonEmeraldReader/Pointers.lua': '''-- Pointers.lua
-- IWRAM pointer management for Pokemon Emerald
-- Handles stable pointers that survive DMA relocations

local Memory = require("Memory")

local Pointers = {}

-- Critical IWRAM pointers for Pokemon Emerald
-- These addresses are in IWRAM and contain pointers to data in EWRAM
Pointers.addresses = {
    -- Save data pointers
    gSaveBlock1 = 0x03005008,      -- Points to save block 1 (player, party, PC, etc.)
    gSaveBlock2 = 0x0300500C,      -- Points to save block 2 (played time, etc.)
    gSaveBlock2PTR = 0x03005010,   -- Another pointer to save block 2
    
    -- Pokemon data pointers
    gPlayerParty = 0x03004360,     -- Player's party Pokemon
    gEnemyParty = 0x030045C0,      -- Enemy party in battle
    
    -- Battle pointers
    gBattleMons = 0x03004324,      -- Battle Pokemon data
    gBattleTypeFlags = 0x02022FEC,  -- Battle type (wild, trainer, etc.)
    gBattleMainFunc = 0x03004300,  -- Current battle function
    gBattleResults = 0x03004318,   -- Battle results
    
    -- Battle state pointers (NEW)
    gBattleScriptingBank = 0x02023FC4,  -- Current battling bank
    gBattleStructPtr = 0x02023FF4,      -- Pointer to battle struct
    gEnemyMonIndex = 0x02023D6C,        -- Current enemy mon index
    gActiveBattler = 0x02023BC4,        -- Active battler
    gBattlersCount = 0x02023BC5,        -- Number of battlers
    
    -- Game state
    gMain = 0x030022C0,            -- Main game structure
    gTasks = 0x03005090,           -- Task system
    gSprites = 0x03007420,         -- Sprite data
    
    -- Special variables
    gSpecialVar_0x8000 = 0x0300481C,
    gSpecialVar_0x8001 = 0x0300481E,
    gSpecialVar_0x8002 = 0x03004820,
    gSpecialVar_0x8003 = 0x03004822,
    gSpecialVar_0x8004 = 0x03004824,
    gSpecialVar_0x8005 = 0x03004826,
    gSpecialVar_0x8006 = 0x03004828,
    gSpecialVar_0x8007 = 0x0300482A,
    gSpecialVar_Result = 0x0300481C,  -- Same as 0x8000
    
    -- DMA control
    gDMA3SAD = 0x030000D4,         -- DMA3 source address
    gDMA3DAD = 0x030000D8,         -- DMA3 destination address
    gDMA3CNT = 0x030000DC,         -- DMA3 control
    
    -- RNG
    gRngValue = 0x03005000,        -- RNG seed
    
    -- Map data
    gMapHeader = 0x0300500C,       -- Current map header
    gObjectEvents = 0x030048E0,    -- NPCs and objects
}

-- SaveBlock1 structure offsets
Pointers.saveBlock1Offsets = {
    playerName = 0x0000,           -- 8 bytes
    playerGender = 0x0008,         -- 1 byte
    playerTrainerId = 0x000A,      -- 2 bytes
    playerSecretId = 0x000C,       -- 2 bytes
    playTimeHours = 0x000E,        -- 2 bytes
    playTimeFrames = 0x0010,       -- 1 byte
    options = 0x0014,              -- 3 bytes
    
    teamAndItems = 0x0234,         -- Party and items start
    teamCount = 0x0234,            -- Party count (4 bytes)
    teamPokemon = 0x0238,          -- Party Pokemon (600 bytes, 6 * 100)
    
    money = 0x0490,                -- 4 bytes
    coins = 0x0494,                -- 2 bytes
    
    pcItems = 0x0498,              -- PC items (120 bytes, 30 * 4)
    itemPocket = 0x0560,           -- Item pocket (120 bytes, 30 * 4)
    keyItemPocket = 0x05B0,        -- Key items (120 bytes, 30 * 4)
    ballPocket = 0x0600,           -- Pokeballs (64 bytes, 16 * 4)
    tmCase = 0x0640,               -- TMs/HMs (232 bytes, 58 * 4)
    berryPocket = 0x0740,          -- Berries (172 bytes, 43 * 4)
    
    rivalName = 0x0BCC,            -- 8 bytes
    
    mapDataSize = 0x09C8,          -- Map data size
    mapData = 0x0C64,              -- Map data
    
    flags = 0x1220,                -- Game flags (300 bytes)
    vars = 0x1340,                 -- Game variables (256 bytes)
    
    gameStats = 0x1540,            -- Game statistics
    
    pcBoxes = 0x4D84,              -- PC boxes start (33600 bytes, 14 * 30 * 80)
}

-- SaveBlock2 structure offsets
Pointers.saveBlock2Offsets = {
    encryptionKey = 0x0000,        -- 4 bytes
    
    -- Pokedex data
    pokedexOwned = 0x0018,         -- 52 bytes (bit flags)
    pokedexSeen = 0x0044,          -- 52 bytes (bit flags)
}

-- Cache for frequently accessed pointers
local cache = {
    saveBlock1 = nil,
    saveBlock2 = nil,
    lastCacheTime = 0
}

-- Cache lifetime in frames (5 seconds at 60fps)
local CACHE_LIFETIME = 300

-- Bitwise operations compatibility
local band = _VERSION >= "Lua 5.3" and function(a,b) return a & b end or bit.band

-- Read and validate a pointer
function Pointers.readPointer(name)
    local addr = Pointers.addresses[name]
    if not addr then 
        return nil, "Unknown pointer: " .. tostring(name)
    end
    
    local pointer = Memory.read_u32_le(addr)
    if not pointer then
        return nil, "Failed to read pointer at " .. string.format("0x%08X", addr)
    end
    
    -- Validate pointer is in valid EWRAM range
    if pointer < 0x02000000 or pointer >= 0x02040000 then
        return nil, "Invalid pointer value: " .. string.format("0x%08X", pointer)
    end
    
    return pointer
end

-- Get SaveBlock1 with caching
function Pointers.getSaveBlock1()
    local currentFrame = emu.framecount()
    
    -- Check cache
    if cache.saveBlock1 and (currentFrame - cache.lastCacheTime) < CACHE_LIFETIME then
        return cache.saveBlock1
    end
    
    -- Read pointer
    local ptr, err = Pointers.readPointer("gSaveBlock1")
    if not ptr then
        return nil, err
    end
    
    -- Create SaveBlock1 structure
    local saveBlock1 = {
        pointer = ptr,
        -- Add all offsets to the base pointer
        playerName = ptr + Pointers.saveBlock1Offsets.playerName,
        playerGender = ptr + Pointers.saveBlock1Offsets.playerGender,
        playerTrainerId = ptr + Pointers.saveBlock1Offsets.playerTrainerId,
        playerSecretId = ptr + Pointers.saveBlock1Offsets.playerSecretId,
        playTimeHours = ptr + Pointers.saveBlock1Offsets.playTimeHours,
        playTimeFrames = ptr + Pointers.saveBlock1Offsets.playTimeFrames,
        teamAndItems = ptr + Pointers.saveBlock1Offsets.teamAndItems,
        teamCount = ptr + Pointers.saveBlock1Offsets.teamCount,
        teamPokemon = ptr + Pointers.saveBlock1Offsets.teamPokemon,
        money = ptr + Pointers.saveBlock1Offsets.money,
        coins = ptr + Pointers.saveBlock1Offsets.coins,
        pcItems = ptr + Pointers.saveBlock1Offsets.pcItems,
        itemPocket = ptr + Pointers.saveBlock1Offsets.itemPocket,
        keyItemPocket = ptr + Pointers.saveBlock1Offsets.keyItemPocket,
        ballPocket = ptr + Pointers.saveBlock1Offsets.ballPocket,
        tmCase = ptr + Pointers.saveBlock1Offsets.tmCase,
        berryPocket = ptr + Pointers.saveBlock1Offsets.berryPocket,
        rivalName = ptr + Pointers.saveBlock1Offsets.rivalName,
        flags = ptr + Pointers.saveBlock1Offsets.flags,
        vars = ptr + Pointers.saveBlock1Offsets.vars,
        gameStats = ptr + Pointers.saveBlock1Offsets.gameStats,
        pcBoxes = ptr + Pointers.saveBlock1Offsets.pcBoxes
    }
    
    -- Update cache
    cache.saveBlock1 = saveBlock1
    cache.lastCacheTime = currentFrame
    
    return saveBlock1
end

-- Get SaveBlock2 with caching
function Pointers.getSaveBlock2()
    local currentFrame = emu.framecount()
    
    -- Check cache
    if cache.saveBlock2 and (currentFrame - cache.lastCacheTime) < CACHE_LIFETIME then
        return cache.saveBlock2
    end
    
    -- Read pointer
    local ptr, err = Pointers.readPointer("gSaveBlock2")
    if not ptr then
        return nil, err
    end
    
    -- Create SaveBlock2 structure
    local saveBlock2 = {
        pointer = ptr,
        encryptionKey = ptr + Pointers.saveBlock2Offsets.encryptionKey,
        pokedexOwned = ptr + Pointers.saveBlock2Offsets.pokedexOwned,
        pokedexSeen = ptr + Pointers.saveBlock2Offsets.pokedexSeen
    }
    
    -- Update cache
    cache.saveBlock2 = saveBlock2
    cache.lastCacheTime = currentFrame
    
    return saveBlock2
end

-- Clear cache (useful when game state changes significantly)
function Pointers.clearCache()
    cache.saveBlock1 = nil
    cache.saveBlock2 = nil
    cache.lastCacheTime = 0
end

-- Get party address
function Pointers.getPartyAddress()
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil, "Failed to get SaveBlock1"
    end
    
    return saveBlock1.teamAndItems
end

-- Get party count
function Pointers.getPartyCount()
    local partyAddr = Pointers.getPartyAddress()
    if not partyAddr then
        return 0
    end
    
    local count = Memory.read_u32_le(partyAddr)
    if not count or count > 6 then
        return 0
    end
    
    return count
end

-- Get Pokemon address in party
function Pointers.getPartyPokemonAddress(slot)
    if slot < 0 or slot > 5 then
        return nil, "Invalid slot: " .. slot
    end
    
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil, "Failed to get SaveBlock1"
    end
    
    -- Each Pokemon is 100 bytes
    return saveBlock1.teamPokemon + (slot * 100)
end

-- Get PC box address
function Pointers.getPCBoxAddress(box, slot)
    if box < 0 or box > 13 then
        return nil, "Invalid box: " .. box
    end
    
    if slot < 0 or slot > 29 then
        return nil, "Invalid slot: " .. slot
    end
    
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil, "Failed to get SaveBlock1"
    end
    
    -- Each box has 30 Pokemon, each Pokemon is 80 bytes in PC
    local boxOffset = box * 30 * 80
    local slotOffset = slot * 80
    
    return saveBlock1.pcBoxes + boxOffset + slotOffset
end

-- Get player info
function Pointers.getPlayerInfo()
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil
    end
    
    return {
        name = Memory.readbytes(saveBlock1.playerName, 8),
        gender = Memory.read_u8(saveBlock1.playerGender),
        trainerId = Memory.read_u16_le(saveBlock1.playerTrainerId),
        secretId = Memory.read_u16_le(saveBlock1.playerSecretId),
        playTimeHours = Memory.read_u16_le(saveBlock1.playTimeHours),
        playTimeFrames = Memory.read_u8(saveBlock1.playTimeFrames),
        money = Memory.read_u32_le(saveBlock1.money),
        coins = Memory.read_u16_le(saveBlock1.coins)
    }
end

-- NEW: Get battle state
function Pointers.getBattleState()
    local battleFlags = Memory.read_u16_le(Pointers.addresses.gBattleTypeFlags)
    if not battleFlags or battleFlags == 0 then
        return nil  -- Not in battle
    end
    
    return {
        inBattle = true,
        isWildBattle = band(battleFlags, 0x01) ~= 0,
        isTrainerBattle = band(battleFlags, 0x08) ~= 0,
        isDoubleBattle = band(battleFlags, 0x02) ~= 0,
        flags = battleFlags
    }
end

-- NEW: Get enemy party address
function Pointers.getEnemyPartyAddress()
    -- Enemy party is at fixed offset from player party
    local playerParty = Pointers.getPartyAddress()
    if not playerParty then return nil end
    
    -- Enemy party is typically 0x4C0 bytes after player party
    return playerParty + 0x4C0
end

-- Test function
function Pointers.test()
    console.log("=== Pointers Module Test ===\\n")
    
    -- Test reading main pointers
    console.log("Main pointers:")
    local mainPointers = {"gSaveBlock1", "gSaveBlock2", "gMain", "gPlayerParty"}
    
    for _, name in ipairs(mainPointers) do
        local ptr, err = Pointers.readPointer(name)
        if ptr then
            console.log(string.format("✓ %s: 0x%08X", name, ptr))
        else
            console.log(string.format("✗ %s: %s", name, err or "Unknown error"))
        end
    end
    
    -- Test SaveBlock access
    console.log("\\nSaveBlock1 test:")
    local sb1 = Pointers.getSaveBlock1()
    if sb1 then
        console.log(string.format("✓ SaveBlock1 at 0x%08X", sb1.pointer))
        console.log(string.format("  Party data: 0x%08X", sb1.teamAndItems))
        console.log(string.format("  PC boxes: 0x%08X", sb1.pcBoxes))
    else
        console.log("✗ Failed to get SaveBlock1")
    end
    
    -- Test player info
    console.log("\\nPlayer info test:")
    local playerInfo = Pointers.getPlayerInfo()
    if playerInfo then
        console.log("✓ Player info retrieved")
        console.log(string.format("  Trainer ID: %d", playerInfo.trainerId or 0))
        console.log(string.format("  Money: $%d", playerInfo.money or 0))
        console.log(string.format("  Play time: %d:%02d", 
            playerInfo.playTimeHours or 0, 
            math.floor((playerInfo.playTimeFrames or 0) * 60 / 3600)))
    else
        console.log("✗ Failed to get player info")
    end
    
    -- Test party access
    console.log("\\nParty test:")
    local partyCount = Pointers.getPartyCount()
    console.log(string.format("Party count: %d", partyCount))
    
    for i = 0, math.min(partyCount - 1, 2) do  -- Test first 3 Pokemon
        local addr = Pointers.getPartyPokemonAddress(i)
        if addr then
            console.log(string.format("  Slot %d: 0x%08X", i + 1, addr))
        end
    end
end

return Pointers
''',

    'PokemonEmeraldReader/ROMData.lua': '''-- ROMData.lua
-- Static data extraction from Pokemon Emerald ROM
-- All data here is read once from ROM and cached, avoiding DMA issues

local Memory = require("Memory")

local ROMData = {}

-- ROM addresses for Pokemon Emerald (US version)
-- Bitwise operation compatibility
local band = _VERSION >= "Lua 5.3" and function(a,b) return a & b end or bit.band
local bor = _VERSION >= "Lua 5.3" and function(a,b) return a | b end or bit.bor
local bxor = _VERSION >= "Lua 5.3" and function(a,b) return a ~ b end or bit.bxor
local bnot = _VERSION >= "Lua 5.3" and function(a) return ~a end or bit.bnot
local lshift = _VERSION >= "Lua 5.3" and function(a,b) return a << b end or bit.lshift
local rshift = _VERSION >= "Lua 5.3" and function(a,b) return a >> b end or bit.rshift


ROMData.addresses = {
    -- Pokemon data
    pokemonStats = 0x083203CC,      -- Base stats
    pokemonNames = 0x08318608,      -- Species names
    pokemonDexData = 0x0831E898,    -- Pokedex data
    evolutionData = 0x08326A8C,     -- Evolution data
    learnsets = 0x0832937C,         -- Level-up learnsets
    eggMoves = 0x08329560,          -- Egg moves
    
    -- Move data
    moveData = 0x0831C898,          -- Move stats
    moveNames = 0x0831977C,         -- Move names
    moveDescriptions = 0x08319C98,  -- Move descriptions
    
    -- Item data
    itemData = 0x083C5A68,          -- Item stats
    itemNames = 0x0831DFD4,         -- Item names (not used in Emerald)
    
    -- Type data
    typeNames = 0x0831AE38,         -- Type names
    typeEffectiveness = 0x0831ACE0, -- Type matchup chart
    
    -- Ability data
    abilityNames = 0x0831B6DB,      -- Ability names
    abilityDescriptions = 0x0831BAD4, -- Ability descriptions
    
    -- Nature data
    natureNames = 0x0831E818,       -- Nature names
    natureStats = 0x0831E898,       -- Nature stat modifiers
    
    -- Trainer data
    trainerData = 0x08352080,       -- Trainer battles
    trainerClasses = 0x0831F53C,    -- Trainer class names
    
    -- Map data
    mapHeaders = 0x08486578,        -- Map headers
    mapNames = 0x0831DFD4,          -- Map names
    
    -- Text
    gameText = 0x08470E6C,          -- General game text
}

-- Type effectiveness values
ROMData.typeEffectiveness = {
    NO_EFFECT = 0,
    NOT_VERY_EFFECTIVE = 5,
    NORMAL_DAMAGE = 10,
    SUPER_EFFECTIVE = 20
}

-- Pokemon stat indices
ROMData.statIndex = {
    HP = 0,
    ATTACK = 1,
    DEFENSE = 2,
    SPEED = 3,
    SP_ATTACK = 4,
    SP_DEFENSE = 5
}

-- Type indices
ROMData.types = {
    NORMAL = 0,
    FIGHTING = 1,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    ROCK = 5,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 10,
    WATER = 11,
    GRASS = 12,
    ELECTRIC = 13,
    PSYCHIC = 14,
    ICE = 15,
    DRAGON = 16,
    DARK = 17
}

-- Storage for loaded data
ROMData.data = {
    pokemon = nil,
    moves = nil,
    items = nil,
    abilities = nil,
    natures = nil,
    types = nil,
    typeChart = nil,
    initialized = false
}

-- Initialize all ROM data
function ROMData.init()
    if ROMData.data.initialized then
        return true
    end
    
    console.log("Loading ROM data...")
    
    -- Load all static data
    ROMData.data.pokemon = ROMData.loadPokemonData()
    ROMData.data.moves = ROMData.loadMoveData()
    ROMData.data.items = ROMData.loadItemData()
    ROMData.data.abilities = ROMData.loadAbilityNames()
    ROMData.data.natures = ROMData.loadNatureData()
    ROMData.data.types = ROMData.loadTypeNames()
    ROMData.data.typeChart = ROMData.loadTypeChart()
    
    -- Check for patches
    ROMData.data.patchInfo = ROMData.detectPatch()
    
    ROMData.data.initialized = true
    console.log("ROM data loaded successfully")
    
    return true
end

-- Load Pokemon base stats and data
function ROMData.loadPokemonData()
    local data = {}
    local baseAddr = ROMData.addresses.pokemonStats
    
    -- Load base stats for all 411 Pokemon (including ???/Egg)
    for i = 0, 410 do
        local addr = baseAddr + (i * 28)  -- Each Pokemon is 28 bytes
        
        local pokemon = {
            -- Stats
            stats = {
                hp = Memory.read_u8(addr + 0),
                attack = Memory.read_u8(addr + 1),
                defense = Memory.read_u8(addr + 2),
                speed = Memory.read_u8(addr + 3),
                spAttack = Memory.read_u8(addr + 4),
                spDefense = Memory.read_u8(addr + 5)
            },
            
            -- Type
            type1 = Memory.read_u8(addr + 6),
            type2 = Memory.read_u8(addr + 7),
            
            -- Misc data
            catchRate = Memory.read_u8(addr + 8),
            expYield = Memory.read_u8(addr + 9),
            evYield = Memory.read_u16_le(addr + 10),
            
            -- Held items
            item1 = Memory.read_u16_le(addr + 12),
            item2 = Memory.read_u16_le(addr + 14),
            
            -- Gender ratio (0 = always male, 254 = always female, 255 = genderless)
            genderRatio = Memory.read_u8(addr + 16),
            
            -- Breeding
            eggCycles = Memory.read_u8(addr + 17),
            baseFriendship = Memory.read_u8(addr + 18),
            growthRate = Memory.read_u8(addr + 19),
            eggGroup1 = Memory.read_u8(addr + 20),
            eggGroup2 = Memory.read_u8(addr + 21),
            
            -- Abilities
            ability1 = Memory.read_u8(addr + 22),
            ability2 = Memory.read_u8(addr + 23),
            
            -- Safari Zone
            safariRate = Memory.read_u8(addr + 24),
            
            -- Pokedex color
            color = Memory.read_u8(addr + 25)
        }
        
        -- Calculate base stat total
        pokemon.bst = pokemon.stats.hp + pokemon.stats.attack + pokemon.stats.defense +
                     pokemon.stats.speed + pokemon.stats.spAttack + pokemon.stats.spDefense
        
        data[i] = pokemon
    end
    
    -- Load Pokemon names
    local nameAddr = ROMData.addresses.pokemonNames
    for i = 0, 410 do
        local name = ROMData.readPokemonString(nameAddr + (i * 11), 11)
        if data[i] then
            data[i].name = name
        end
    end
    
    return data
end

-- Load move data
function ROMData.loadMoveData()
    local data = {}
    local baseAddr = ROMData.addresses.moveData
    
    -- Load data for all 355 moves
    for i = 0, 354 do
        local addr = baseAddr + (i * 12)  -- Each move is 12 bytes
        
        local move = {
            effect = Memory.read_u8(addr + 0),
            power = Memory.read_u8(addr + 1),
            type = Memory.read_u8(addr + 2),
            accuracy = Memory.read_u8(addr + 3),
            pp = Memory.read_u8(addr + 4),
            effectChance = Memory.read_u8(addr + 5),
            target = Memory.read_u8(addr + 6),
            priority = Memory.read_s8(addr + 7),  -- Signed
            flags = Memory.read_u8(addr + 8),
            argument = Memory.read_u8(addr + 9),
            -- Padding: 2 bytes
        }
        
        -- Decode flags
        move.makesContact = band(move.flags, 0x01) ~= 0
        move.isProtectable = band(move.flags, 0x02) ~= 0
        move.isMagicCoatAffected = band(move.flags, 0x04) ~= 0
        move.isSnatchable = band(move.flags, 0x08) ~= 0
        move.canMetronome = band(move.flags, 0x10) ~= 0
        move.cannotSketch = band(move.flags, 0x20) ~= 0
        
        data[i] = move
    end
    
    -- Load move names
    local nameAddr = ROMData.addresses.moveNames
    for i = 0, 354 do
        local name = ROMData.readPokemonString(nameAddr + (i * 13), 13)
        if data[i] then
            data[i].name = name
        end
    end
    
    return data
end

-- Load item data
function ROMData.loadItemData()
    local data = {}
    local baseAddr = ROMData.addresses.itemData
    
    -- Load data for items (up to 377 in Emerald)
    for i = 0, 376 do
        local addr = baseAddr + (i * 44)  -- Each item is 44 bytes
        
        local item = {
            name = ROMData.readPokemonString(addr + 0, 14),
            index = Memory.read_u16_le(addr + 14),
            price = Memory.read_u16_le(addr + 16),
            holdEffect = Memory.read_u8(addr + 18),
            parameter = Memory.read_u8(addr + 19),
            description = Memory.read_u32_le(addr + 20),  -- Pointer to description
            mysteryValue = Memory.read_u16_le(addr + 24),
            pocket = Memory.read_u8(addr + 26),
            type = Memory.read_u8(addr + 27),
            fieldEffect = Memory.read_u32_le(addr + 28),  -- Pointer
            battleUsage = Memory.read_u32_le(addr + 32),  -- Pointer
            battleEffect = Memory.read_u32_le(addr + 36), -- Pointer
            extraParameter = Memory.read_u32_le(addr + 40) -- Pointer
        }
        
        data[i] = item
    end
    
    return data
end

-- Load ability names
function ROMData.loadAbilityNames()
    local data = {}
    local baseAddr = ROMData.addresses.abilityNames
    
    -- Load 78 abilities (0-77)
    for i = 0, 77 do
        local name = ROMData.readPokemonString(baseAddr + (i * 13), 13)
        data[i] = name
    end
    
    return data
end

-- Load nature data
function ROMData.loadNatureData()
    local data = {}
    local nameAddr = ROMData.addresses.natureNames
    
    -- Nature stat modifiers (hardcoded in game)
    local natureModifiers = {
        -- [increased stat][decreased stat] = nature index
        [1] = {[2] = 0, [3] = 1, [4] = 2, [5] = 3},  -- Attack+
        [2] = {[1] = 4, [3] = 5, [4] = 6, [5] = 7},  -- Defense+
        [3] = {[1] = 8, [2] = 9, [4] = 10, [5] = 11}, -- Speed+
        [4] = {[1] = 12, [2] = 13, [3] = 14, [5] = 15}, -- Sp.Atk+
        [5] = {[1] = 16, [2] = 17, [3] = 18, [4] = 19}  -- Sp.Def+
    }
    
    -- Load 25 natures
    for i = 0, 24 do
        local name = ROMData.readPokemonString(nameAddr + (i * 7), 7)
        
        -- Calculate stat modifiers
        local increased = nil
        local decreased = nil
        
        -- Find which stats are affected
        for inc = 1, 5 do
            for dec = 1, 5 do
                if natureModifiers[inc] and natureModifiers[inc][dec] == i then
                    increased = inc
                    decreased = dec
                    break
                end
            end
        end
        
        data[i] = {
            name = name,
            increased = increased,  -- 1=Atk, 2=Def, 3=Spe, 4=SpA, 5=SpD
            decreased = decreased   -- Same indices
        }
    end
    
    return data
end

-- Load type names
function ROMData.loadTypeNames()
    local data = {}
    local baseAddr = ROMData.addresses.typeNames
    
    -- Load 18 types (includes ???)
    for i = 0, 17 do
        local name = ROMData.readPokemonString(baseAddr + (i * 7), 7)
        data[i] = name
    end
    
    return data
end

-- Load type effectiveness chart
function ROMData.loadTypeChart()
    local data = {}
    local baseAddr = ROMData.addresses.typeEffectiveness
    
    -- Read type chart until terminator
    local offset = 0
    while true do
        local attacker = Memory.read_u8(baseAddr + offset)
        local defender = Memory.read_u8(baseAddr + offset + 1)
        local effectiveness = Memory.read_u8(baseAddr + offset + 2)
        
        -- Terminator: 0xFE 0xFE 0x00
        if attacker == 0xFE and defender == 0xFE then
            break
        end
        
        -- Store effectiveness
        if not data[attacker] then
            data[attacker] = {}
        end
        data[attacker][defender] = effectiveness
        
        offset = offset + 3
    end
    
    return data
end

-- Read Pokemon text encoding
function ROMData.readPokemonString(addr, maxLength)
    local str = ""
    for i = 0, maxLength - 1 do
        local char = Memory.read_u8(addr + i)
        if char == 0xFF then break end  -- Terminator
        
        -- Basic character mapping (simplified)
        if char == 0x00 then
            str = str .. " "
        elseif char >= 0xBB and char <= 0xD4 then
            str = str .. string.char(char - 0xBB + 65)  -- A-Z
        elseif char >= 0xD5 and char <= 0xEE then
            str = str .. string.char(char - 0xD5 + 97)  -- a-z
        elseif char >= 0xA1 and char <= 0xAA then
            str = str .. string.char(char - 0xA1 + 48)  -- 0-9
        elseif char == 0xAE then
            str = str .. "-"
        elseif char == 0xAF then
            str = str .. "."
        elseif char == 0xB0 then
            str = str .. "..."  -- Ellipsis
        elseif char == 0xB1 then
            str = str .. "\\""   -- Left double quote
        elseif char == 0xB2 then
            str = str .. "\\""   -- Right double quote
        elseif char == 0xB3 then
            str = str .. "'"    -- Left single quote
        elseif char == 0xB4 then
            str = str .. "'"    -- Right single quote
        elseif char == 0xB5 then
            str = str .. "M"    -- Male symbol
        elseif char == 0xB6 then
            str = str .. "F"    -- Female symbol
        elseif char == 0xBA then
            str = str .. "e"    -- e with accent
        end
    end
    return str
end

-- Detect ROM patches
function ROMData.detectPatch()
    local patches = {
        -- Common patch signatures and locations
        {addr = 0x08F00000, name = "Archipelago", sig = "ARCH"},
        {addr = 0x08E00000, name = "Randomizer", sig = "RAND"},
        {addr = 0x08D00000, name = "Custom", sig = nil}
    }
    
    for _, patch in ipairs(patches) do
        local data = Memory.readbytes(patch.addr, 16)
        if data and data[1] ~= 0xFF then  -- Not empty ROM space
            -- Check for signature if specified
            if patch.sig then
                local sig = ""
                for i = 1, #patch.sig do
                    sig = sig .. string.char(data[i] or 0)
                end
                if sig == patch.sig then
                    return {
                        type = patch.name,
                        address = patch.addr,
                        signature = sig
                    }
                end
            else
                -- No specific signature, just check for data
                return {
                    type = patch.name,
                    address = patch.addr,
                    signature = "Unknown"
                }
            end
        end
    end
    
    return nil
end

-- NEW: Calculate randomizer tier for a Pokemon
function ROMData.calculateRandomizerTier(pokemonId)
    local pokemon = ROMData.getPokemon(pokemonId)
    if not pokemon then return nil end
    
    -- Base stat total weight
    local bstScore = math.min(pokemon.bst / 600, 1.0) * 100
    
    -- HP is crucial in randomizers
    local hpScore = (pokemon.stats.hp / 255) * 150
    
    -- Speed for survival
    local speedScore = (pokemon.stats.speed / 200) * 130
    
    -- Defensive stats
    local defenseScore = ((pokemon.stats.defense + pokemon.stats.spDefense) / 400) * 120
    
    -- Type defensive score
    local typeScore = ROMData.calculateTypeDefensiveScore(pokemon.type1, pokemon.type2) * 100
    
    -- Calculate weighted total
    local totalScore = (
        bstScore * 0.30 +
        hpScore * 0.20 +
        speedScore * 0.15 +
        defenseScore * 0.20 +
        typeScore * 0.15
    )
    
    -- Determine tier
    local tier, stars
    if totalScore >= 90 then
        tier = "S"
        stars = 5
    elseif totalScore >= 75 then
        tier = "A"
        stars = 4
    elseif totalScore >= 60 then
        tier = "B"
        stars = 3
    elseif totalScore >= 45 then
        tier = "C"
        stars = 2
    else
        tier = "D"
        stars = 1
    end
    
    return {
        tier = tier,
        stars = stars,
        score = math.floor(totalScore),
        details = {
            bst = math.floor(bstScore),
            hp = math.floor(hpScore),
            speed = math.floor(speedScore),
            defense = math.floor(defenseScore),
            typing = math.floor(typeScore)
        }
    }
end

-- NEW: Calculate defensive type score
function ROMData.calculateTypeDefensiveScore(type1, type2)
    if not ROMData.data.initialized then return 0.5 end
    
    local weaknesses = 0
    local resistances = 0
    local immunities = 0
    
    -- Check all type matchups
    for atkType = 0, 17 do
        local effectiveness = 10  -- Normal damage
        
        -- Check vs type1
        if ROMData.data.typeChart[atkType] and ROMData.data.typeChart[atkType][type1] then
            effectiveness = ROMData.data.typeChart[atkType][type1]
        end
        
        -- Check vs type2 if different
        if type2 ~= type1 and ROMData.data.typeChart[atkType] and ROMData.data.typeChart[atkType][type2] then
            local eff2 = ROMData.data.typeChart[atkType][type2]
            effectiveness = (effectiveness * eff2) / 10
        end
        
        if effectiveness > 10 then
            weaknesses = weaknesses + 1
        elseif effectiveness < 10 and effectiveness > 0 then
            resistances = resistances + 1
        elseif effectiveness == 0 then
            immunities = immunities + 1
        end
    end
    
    -- Score based on defensive profile (0.0 to 1.0)
    return math.min(1.0, math.max(0.0, 0.5 + (resistances * 0.05) + (immunities * 0.1) - (weaknesses * 0.08)))
end

-- Getter functions
function ROMData.getPokemon(species)
    if not ROMData.data.initialized then ROMData.init() end
    return ROMData.data.pokemon[species]
end

function ROMData.getMove(moveId)
    if not ROMData.data.initialized then ROMData.init() end
    return ROMData.data.moves[moveId]
end

function ROMData.getItem(itemId)
    if not ROMData.data.initialized then ROMData.init() end
    return ROMData.data.items[itemId]
end

function ROMData.getAbilityName(abilityId)
    if not ROMData.data.initialized then ROMData.init() end
    return ROMData.data.abilities[abilityId]
end

function ROMData.getNature(natureId)
    if not ROMData.data.initialized then ROMData.init() end
    return ROMData.data.natures[natureId]
end

function ROMData.getTypeName(typeId)
    if not ROMData.data.initialized then ROMData.init() end
    return ROMData.data.types[typeId]
end

function ROMData.getTypeEffectiveness(attackType, defenseType)
    if not ROMData.data.initialized then ROMData.init() end
    
    if ROMData.data.typeChart[attackType] then
        return ROMData.data.typeChart[attackType][defenseType] or 10  -- Default to normal damage
    end
    return 10
end

-- Test function
function ROMData.test()
    console.log("=== ROM Data Module Test ===\\n")
    
    -- Initialize
    ROMData.init()
    
    -- Test Pokemon data
    console.log("Pokemon data test:")
    local bulbasaur = ROMData.getPokemon(1)
    if bulbasaur then
        console.log(string.format("✓ #001 %s", bulbasaur.name or "???"))
        console.log(string.format("  BST: %d (HP:%d ATK:%d DEF:%d SPE:%d SPA:%d SPD:%d)",
            bulbasaur.bst,
            bulbasaur.stats.hp,
            bulbasaur.stats.attack,
            bulbasaur.stats.defense,
            bulbasaur.stats.speed,
            bulbasaur.stats.spAttack,
            bulbasaur.stats.spDefense
        ))
        console.log(string.format("  Types: %s/%s", 
            ROMData.getTypeName(bulbasaur.type1) or "???",
            bulbasaur.type1 == bulbasaur.type2 and "—" or (ROMData.getTypeName(bulbasaur.type2) or "???")))
    else
        console.log("✗ Failed to load Pokemon data")
    end
    
    -- Test move data
    console.log("\\nMove data test:")
    local tackle = ROMData.getMove(33)  -- Tackle
    if tackle then
        console.log(string.format("✓ Move #33: %s", tackle.name or "???"))
        console.log(string.format("  Power: %d, Accuracy: %d, PP: %d",
            tackle.power, tackle.accuracy, tackle.pp))
        console.log(string.format("  Type: %s", ROMData.getTypeName(tackle.type) or "???"))
    else
        console.log("✗ Failed to load move data")
    end
    
    -- Test type effectiveness
    console.log("\\nType effectiveness test:")
    local waterVsFire = ROMData.getTypeEffectiveness(11, 10)  -- Water vs Fire
    console.log(string.format("Water vs Fire: %d (should be 20 for super effective)", waterVsFire))
    
    -- Test patch detection
    console.log("\\nPatch detection:")
    if ROMData.data.patchInfo then
        console.log(string.format("✓ Patch detected: %s at 0x%08X", 
            ROMData.data.patchInfo.type,
            ROMData.data.patchInfo.address))
    else
        console.log("✓ No patches detected (vanilla ROM)")
    end
end

return ROMData
''',

    'PokemonEmeraldReader/BattleDisplay.lua': '''-- BattleDisplay.lua
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
    console.log("\\n=== WILD POKEMON ENCOUNTER ===")
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
        console.log(string.format("\\nRANDOMIZER TIER: %s %s", pokemon.tierRating.tier, stars))
        console.log(string.format("Overall Score: %d/100", pokemon.tierRating.score))
        
        -- Tier breakdown
        console.log("\\nTier Analysis:")
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
        console.log("\\n" .. BattleDisplay.getTierRecommendation(pokemon.tierRating.tier))
    end
    
    -- Stats
    if pokemon.battleStats then
        console.log("\\nStats:")
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
    console.log(string.format("\\nAbility: %s", abilityName))
    
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
    console.log("\\n=== TYPE EFFECTIVENESS ===")
    
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
    console.log("\\n=== TRAINER BATTLE ===")
    console.log(string.rep("═", 50))
    
    -- Trainer info
    console.log(string.format("Trainer %s sent out %s!", 
        trainerName or "???", 
        pokemon.baseData and pokemon.baseData.name or "???"))
    
    -- Continue with similar display as wild
    BattleDisplay.displayWildEncounter(pokemon)
end

return BattleDisplay
''',

    'PokemonEmeraldReader/main.lua': '''-- main.lua
-- Pokemon Emerald Memory Reader for BizHawk
-- Modified to work with Archipelago and other patched ROMs
-- Now with battle display and tier ratings!

-- Load modules
local Memory = require("Memory")
local ROMData = require("ROMData")
local Pointers = require("Pointers")
local PokemonReader = require("PokemonReader")
local BattleDisplay = require("BattleDisplay")

-- Optional JSON library for external output
local hasJson, json = pcall(require, "json")

-- Configuration
local Config = {
    -- Update intervals (in frames)
    updateInterval = 30,        -- Update display every 0.5 seconds (30 frames)
    fullUpdateInterval = 300,   -- Full update every 5 seconds
    battleCheckInterval = 10,   -- Check for battles every 10 frames
    
    -- External output
    enableExternalOutput = false,
    outputFile = "pokemon_data.json",
    
    -- Display options
    showDetailedStats = true,
    showMoves = true,
    showIVsEVs = false,
    showBattleInfo = true,
    showTypeEffectiveness = true,
    showTierBreakdown = true,
    
    -- Performance
    cacheLifetime = 300,        -- 5 seconds
    
    -- Archipelago mode
    archipelagoMode = false,    -- Set to true if patch detected
    
    -- Tier symbols
    tierSymbols = {
        S = "⭐",
        A = "✨",
        B = "👍",
        C = "⚡",
        D = "⚠️"
    }
}

-- State tracking
local State = {
    frameCount = 0,
    lastUpdate = 0,
    lastFullUpdate = 0,
    lastBattleCheck = 0,
    isInitialized = false,
    
    -- Current data
    party = nil,
    playerInfo = nil,
    currentBattle = nil,
    
    -- Statistics
    startTime = os.clock(),
    totalReads = 0,
}

-- Initialize the system
function init()
    console.clear()
    console.log("==============================================")
    console.log("Pokemon Emerald Memory Reader v1.0")
    console.log("(Archipelago Compatible)")
    console.log("==============================================")
    console.log("Initializing...")
    
    -- Try multiple methods to verify Pokemon Emerald
    local isEmerald = false
    local gameInfo = "Unknown"
    
    -- Method 1: Standard game code location
    local gameCode = Memory.readbytes(0x080000AC, 4)
    if gameCode then
        local codeStr = ""
        for i, byte in ipairs(gameCode) do
            if byte then
                codeStr = codeStr .. string.char(byte)
            end
        end
        
        if codeStr == "BPEE" then
            isEmerald = true
            gameInfo = "Pokemon Emerald (Vanilla)"
        else
            console.log("Game code: " .. codeStr .. " (not standard BPEE)")
        end
    else
        console.log("Warning: Could not read game code at standard location")
    end
    
    -- Method 2: Check ROM title
    local romTitle = Memory.readstring(0x080000A0, 12)
    if romTitle and romTitle:find("POKEMON EMER") then
        isEmerald = true
        if gameInfo == "Unknown" then
            gameInfo = "Pokemon Emerald (Modified Header)"
        end
    end
    
    -- Method 3: Check for known data patterns
    if not isEmerald then
        -- Check for Pokemon base stats table signature
        local statsCheck = Memory.read_u32_le(0x083203CC)
        if statsCheck == 0x2D2D0803 then  -- Bulbasaur's stats pattern
            isEmerald = true
            gameInfo = "Pokemon Emerald (Pattern Match)"
        end
    end
    
    -- Method 4: Check for Archipelago signature
    local archSig = Memory.readbytes(0x08F00000, 4)
    if archSig then
        local sigStr = ""
        for i, byte in ipairs(archSig) do
            if byte and byte ~= 0xFF then
                sigStr = sigStr .. string.char(byte)
            end
        end
        
        if sigStr == "ARCH" then
            isEmerald = true
            gameInfo = "Pokemon Emerald (Archipelago)"
            Config.archipelagoMode = true
            console.log("✓ Archipelago patch detected!")
        end
    end
    
    if not isEmerald then
        console.log("\\nWARNING: Pokemon Emerald not detected!")
        console.log("The tool may not work correctly.")
        console.log("Continuing anyway...")
        gameInfo = "Unknown GBA ROM"
    else
        console.log("✓ " .. gameInfo .. " detected")
    end
    
    -- Load ROM data
    console.log("\\nLoading ROM data...")
    local romInitSuccess = ROMData.init()
    if not romInitSuccess then
        console.log("WARNING: Failed to load some ROM data")
        console.log("Basic features will still work")
    else
        console.log("✓ ROM data loaded")
    end
    
    -- Check for patches
    if ROMData.data.patchInfo then
        console.log("✓ Patch detected: " .. ROMData.data.patchInfo.type)
    end
    
    -- Test memory access
    console.log("\\nTesting memory access...")
    local saveBlock1Ptr = Memory.read_u32_le(0x03005008)
    if saveBlock1Ptr and saveBlock1Ptr >= 0x02000000 and saveBlock1Ptr < 0x02040000 then
        console.log("✓ Save data accessible at 0x" .. string.format("%08X", saveBlock1Ptr))
        
        -- Test System Bus for addresses beyond 32KB
        if saveBlock1Ptr >= 0x02008000 then
            console.log("✓ Using System Bus for extended EWRAM access")
        end
    else
        console.log("⚠ Save data not found - load a save file")
    end
    
    State.isInitialized = true
    console.log("\\nInitialization complete!")
    console.log("==============================================\\n")
    
    return true
end

-- Check for battles
function checkBattle()
    -- Only check periodically
    if State.frameCount - State.lastBattleCheck < Config.battleCheckInterval then
        return
    end
    
    State.lastBattleCheck = State.frameCount
    
    local enemyPokemon, battleState = BattleDisplay.readEnemyPokemon()
    
    if enemyPokemon and battleState then
        -- New battle detected
        if not State.currentBattle or State.currentBattle.species ~= enemyPokemon.species then
            State.currentBattle = enemyPokemon
            
            -- Clear console and show battle info
            console.clear()
            
            if battleState.isWildBattle then
                BattleDisplay.displayWildEncounter(enemyPokemon)
                
                -- Show type effectiveness if we have a lead Pokemon
                if State.party and State.party.pokemon[1] then
                    local playerPokemon = State.party.pokemon[1]
                    if playerPokemon.baseData and enemyPokemon.baseData then
                        BattleDisplay.displayTypeEffectiveness(
                            {playerPokemon.baseData.type1, playerPokemon.baseData.type2},
                            {enemyPokemon.baseData.type1, enemyPokemon.baseData.type2}
                        )
                    end
                end
                
                -- Add a divider before regular party display
                console.log("\\n" .. string.rep("-", 50) .. "\\n")
            elseif battleState.isTrainerBattle then
                BattleDisplay.displayTrainerBattle(enemyPokemon)
            end
        end
    else
        State.currentBattle = nil
    end
end

-- Update game data
function update()
    State.frameCount = State.frameCount + 1
    
    -- Check for battles
    if Config.showBattleInfo then
        checkBattle()
    end
    
    -- Quick update (every updateInterval frames)
    if State.frameCount - State.lastUpdate >= Config.updateInterval then
        State.lastUpdate = State.frameCount
        quickUpdate()
    end
    
    -- Full update (every fullUpdateInterval frames)
    if State.frameCount - State.lastFullUpdate >= Config.fullUpdateInterval then
        State.lastFullUpdate = State.frameCount
        fullUpdate()
    end
end

-- Quick update - just refresh current party
function quickUpdate()
    -- Read party
    State.party = PokemonReader.readParty()
    State.totalReads = State.totalReads + 1
    
    -- Update display (only if not in battle)
    if not State.currentBattle then
        displayParty()
    end
    
    -- External output if enabled
    if Config.enableExternalOutput and hasJson then
        outputData()
    end
end

-- Full update - refresh everything including player info
function fullUpdate()
    -- Clear pointer cache to ensure fresh data
    Pointers.clearCache()
    
    -- Read player info
    State.playerInfo = Pointers.getPlayerInfo()
    
    -- Perform quick update too
    quickUpdate()
end

-- Display party information
function displayParty()
    console.clear()
    
    -- Header
    console.log("=== Pokemon Party Monitor ===")
    if Config.archipelagoMode then
        console.log("(Archipelago Mode)")
    end
    
    -- Player info
    if State.playerInfo then
        local hours = State.playerInfo.playTimeHours or 0
        local minutes = math.floor((State.playerInfo.playTimeFrames or 0) * 60 / 3600)
        console.log(string.format("Trainer ID: %05d | Money: $%d | Time: %d:%02d",
            State.playerInfo.trainerId or 0,
            State.playerInfo.money or 0,
            hours, minutes))
    end
    
    console.log("-----------------------------")
    
    -- Party Pokemon
    if State.party and State.party.count > 0 then
        console.log(string.format("Party: %d/6 Pokemon\\n", State.party.count))
        
        for i, pokemon in ipairs(State.party.pokemon) do
            if pokemon then
                displayPokemon(i, pokemon)
            end
        end
    else
        console.log("No Pokemon in party")
    end
    
    -- Footer stats
    console.log("\\n-----------------------------")
    local stats = Memory.getStats()
    local runtime = os.clock() - State.startTime
    console.log(string.format("Runtime: %.1fs | Updates: %d | Memory reads: %d",
        runtime, State.totalReads, stats.reads))
    
    if stats.systemBusFallbacks > 0 then
        console.log(string.format("System Bus used: %d times (extended EWRAM access)",
            stats.systemBusFallbacks))
    end
end

-- Display individual Pokemon
function displayPokemon(slot, pokemon)
    local info = PokemonReader.formatPokemon(pokemon)
    
    -- Basic info line
    console.log(string.format("%d. %s (Lv.%s %s) %s",
        slot,
        info.name,
        info.level,
        info.species,
        info.status and "[" .. info.status .. "]" or ""))
    
    -- HP bar
    local hpPercent = 0
    if pokemon.battleStats and pokemon.battleStats.maxHP > 0 then
        hpPercent = pokemon.battleStats.currentHP / pokemon.battleStats.maxHP
    end
    
    local barLength = 20
    local filledBars = math.floor(hpPercent * barLength)
    local hpBar = string.rep("█", filledBars) .. string.rep("░", barLength - filledBars)
    
    console.log(string.format("   HP: [%s] %s", hpBar, info.hp))
    
    -- Type, ability, nature, item
    console.log(string.format("   %s | %s | %s | Item: %s",
        info.types, info.ability, info.nature, info.item))
    
    -- Detailed stats if enabled
    if Config.showDetailedStats and pokemon.battleStats then
        console.log(string.format("   Stats: ATK %d | DEF %d | SPE %d | SPA %d | SPD %d",
            pokemon.battleStats.attack,
            pokemon.battleStats.defense,
            pokemon.battleStats.speed,
            pokemon.battleStats.spAttack,
            pokemon.battleStats.spDefense))
    end
    
    -- Moves if enabled
    if Config.showMoves and pokemon.moves then
        local moveNames = {}
        for j, moveId in ipairs(pokemon.moves) do
            if moveId > 0 then
                local move = ROMData.getMove(moveId)
                if move then
                    table.insert(moveNames, string.format("%s(%d/%d)", 
                        move.name, pokemon.pp[j] or 0, move.pp))
                end
            end
        end
        if #moveNames > 0 then
            console.log("   Moves: " .. table.concat(moveNames, " | "))
        end
    end
    
    -- IVs/EVs if enabled
    if Config.showIVsEVs and pokemon.parsedIVs and pokemon.evs then
        console.log(string.format("   IVs: %d/%d/%d/%d/%d/%d",
            pokemon.parsedIVs.hp,
            pokemon.parsedIVs.attack,
            pokemon.parsedIVs.defense,
            pokemon.parsedIVs.speed,
            pokemon.parsedIVs.spAttack,
            pokemon.parsedIVs.spDefense))
        console.log(string.format("   EVs: %d/%d/%d/%d/%d/%d",
            pokemon.evs.hp,
            pokemon.evs.attack,
            pokemon.evs.defense,
            pokemon.evs.speed,
            pokemon.evs.spAttack,
            pokemon.evs.spDefense))
    end
    
    console.log("")  -- Blank line between Pokemon
end

-- Output data for external tools
function outputData()
    if not hasJson then return end
    
    local data = {
        timestamp = os.time(),
        frameCount = State.frameCount,
        player = State.playerInfo,
        party = State.party,
        archipelago = Config.archipelagoMode,
        battle = State.currentBattle
    }
    
    local success, jsonStr = pcall(json.encode, data)
    if success then
        local file = io.open(Config.outputFile, "w")
        if file then
            file:write(jsonStr)
            file:close()
        end
    end
end

-- Handle user input
function handleInput()
    local keys = input.get()
    
    -- Toggle options with keyboard
    if keys["D"] then
        Config.showDetailedStats = not Config.showDetailedStats
        console.log("Detailed stats: " .. (Config.showDetailedStats and "ON" or "OFF"))
    end
    
    if keys["M"] then
        Config.showMoves = not Config.showMoves
        console.log("Move display: " .. (Config.showMoves and "ON" or "OFF"))
    end
    
    if keys["I"] then
        Config.showIVsEVs = not Config.showIVsEVs
        console.log("IV/EV display: " .. (Config.showIVsEVs and "ON" or "OFF"))
    end
    
    if keys["E"] then
        Config.enableExternalOutput = not Config.enableExternalOutput
        console.log("External output: " .. (Config.enableExternalOutput and "ON" or "OFF"))
    end
    
    if keys["B"] then
        Config.showBattleInfo = not Config.showBattleInfo
        console.log("Battle display: " .. (Config.showBattleInfo and "ON" or "OFF"))
    end
    
    if keys["R"] then
        -- Force refresh
        State.lastFullUpdate = 0
        console.log("Forcing full refresh...")
    end
end

-- Main loop
function main()
    -- Initialize
    if not init() then
        console.log("\\nPress any key to exit...")
        while not input.get() do
            emu.frameadvance()
        end
        return
    end
    
    console.log("\\nControls:")
    console.log("D - Toggle detailed stats")
    console.log("M - Toggle move display")
    console.log("I - Toggle IV/EV display")
    console.log("E - Toggle external output")
    console.log("B - Toggle battle display")
    console.log("R - Force refresh")
    console.log("\\nStarting in 3 seconds...")
    
    -- Wait 3 seconds
    for i = 1, 180 do
        emu.frameadvance()
    end
    
    -- Main loop
    while true do
        handleInput()
        update()
        emu.frameadvance()
    end
end

-- Error handling
local success, err = pcall(main)
if not success then
    console.log("\\n=== ERROR ===")
    console.log(tostring(err))
    console.log("\\nPress any key to exit...")
    while true do
        if next(input.get()) then break end
        emu.frameadvance()
    end
end
'''
}

def create_backup(directory):
    """Create a backup of existing files"""
    backup_dir = Path(directory) / f"backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    if any(Path(directory).glob("*.lua")):
        print(f"Creating backup in: {backup_dir}")
        backup_dir.mkdir(exist_ok=True)
        
        for lua_file in Path(directory).glob("*.lua"):
            shutil.copy2(lua_file, backup_dir)
        
        print(f"Backed up {len(list(backup_dir.glob('*.lua')))} files")
        return backup_dir
    return None

def deploy_updates(base_dir=""):
    """Deploy all updated files"""
    print("=" * 60)
    print("Pokemon Emerald Reader - Battle Display Update Deployment")
    print("=" * 60)
    
    # Determine base directory
    if not base_dir:
        if Path("PokemonEmeraldReader").exists():
            base_dir = "."
        elif Path("../PokemonEmeraldReader").exists():
            base_dir = ".."
        else:
            base_dir = input("Enter the path to your project directory: ")
    
    base_path = Path(base_dir)
    
    # Create backup
    backup_dir = create_backup(base_path / "PokemonEmeraldReader")
    
    print("\nDeploying updates...")
    
    # Deploy each file
    deployed = 0
    for filepath, content in FILE_UPDATES.items():
        full_path = base_path / filepath
        
        # Create directory if needed
        full_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Write file
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"✓ Updated: {filepath}")
        deployed += 1
    
    print(f"\n✅ Successfully deployed {deployed} files!")
    
    # Create a rollback script
    if backup_dir:
        rollback_script = base_path / "PokemonEmeraldReader" / "rollback.py"
        with open(rollback_script, 'w') as f:
            f.write(f'''#!/usr/bin/env python3
"""Rollback to backup created on {backup_dir.name}"""
import shutil
from pathlib import Path

backup = Path("{backup_dir.name}")
current = Path(".")

if backup.exists():
    for lua_file in backup.glob("*.lua"):
        shutil.copy2(lua_file, current / lua_file.name)
        print(f"Restored: {{lua_file.name}}")
    print("\\nRollback complete!")
else:
    print("Backup directory not found!")
''')
        print(f"\n📋 Created rollback script: {rollback_script}")
    
    print("\n🎮 To use the updated tool:")
    print("1. Open Pokemon Emerald in BizHawk")
    print("2. Load the Lua Console (Tools → Lua Console)")
    print("3. Run: dofile('run.lua')")
    print("\n🌟 New features:")
    print("- Wild Pokemon encounters with tier ratings")
    print("- Randomizer-specific tier system (S-D)")
    print("- Type effectiveness display")
    print("- Visual tier breakdown in console")
    print("- Press 'B' to toggle battle display")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        deploy_updates(sys.argv[1])
    else:
        deploy_updates()
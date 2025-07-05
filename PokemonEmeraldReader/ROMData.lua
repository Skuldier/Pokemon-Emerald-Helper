-- ROMData.lua
-- Static data extraction from Pokemon Emerald ROM
-- All data here is read once from ROM and cached, avoiding DMA issues

local Memory = require("Memory")

local ROMData = {}

-- ROM addresses for Pokemon Emerald (US version)
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
        move.makesContact = bit.band(move.flags, 0x01) ~= 0
        move.isProtectable = bit.band(move.flags, 0x02) ~= 0
        move.isMagicCoatAffected = bit.band(move.flags, 0x04) ~= 0
        move.isSnatchable = bit.band(move.flags, 0x08) ~= 0
        move.canMetronome = bit.band(move.flags, 0x10) ~= 0
        move.cannotSketch = bit.band(move.flags, 0x20) ~= 0
        
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
            str = str .. "…"
        elseif char == 0xB1 then
            str = str .. """
        elseif char == 0xB2 then
            str = str .. """
        elseif char == 0xB3 then
            str = str .. "'"
        elseif char == 0xB4 then
            str = str .. "'"
        elseif char == 0xB5 then
            str = str .. "♂"
        elseif char == 0xB6 then
            str = str .. "♀"
        elseif char == 0xBA then
            str = str .. "é"
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
    console.log("=== ROM Data Module Test ===\n")
    
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
    console.log("\nMove data test:")
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
    console.log("\nType effectiveness test:")
    local waterVsFire = ROMData.getTypeEffectiveness(11, 10)  -- Water vs Fire
    console.log(string.format("Water vs Fire: %d (should be 20 for super effective)", waterVsFire))
    
    -- Test patch detection
    console.log("\nPatch detection:")
    if ROMData.data.patchInfo then
        console.log(string.format("✓ Patch detected: %s at 0x%08X", 
            ROMData.data.patchInfo.type,
            ROMData.data.patchInfo.address))
    else
        console.log("✓ No patches detected (vanilla ROM)")
    end
end

return ROMData
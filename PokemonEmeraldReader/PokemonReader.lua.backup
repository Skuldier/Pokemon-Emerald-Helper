-- PokemonReader.lua
-- Pokemon data reading module combining ROM and RAM data
-- Handles decryption and complete Pokemon structure

local Memory = require("Memory")
local Pointers = require("Pointers")
local ROMData = require("ROMData")

local PokemonReader = {}

-- Pokemon data structure constants
-- Bitwise operation compatibility
local band = _VERSION >= "Lua 5.3" and function(a,b) return a & b end or bit.band
local bor = _VERSION >= "Lua 5.3" and function(a,b) return a | b end or bit.bor
local bxor = _VERSION >= "Lua 5.3" and function(a,b) return a ~ b end or bit.bxor
local bnot = _VERSION >= "Lua 5.3" and function(a) return ~a end or bit.bnot
local lshift = _VERSION >= "Lua 5.3" and function(a,b) return a << b end or bit.lshift
local rshift = _VERSION >= "Lua 5.3" and function(a,b) return a >> b end or bit.rshift


PokemonReader.POKEMON_SIZE = 100        -- Size in party
PokemonReader.POKEMON_PC_SIZE = 80      -- Size in PC
PokemonReader.PARTY_SIZE = 6
PokemonReader.SUBSTRUCTURE_SIZE = 12    -- Each encrypted substructure
PokemonReader.ENCRYPTED_SIZE = 48       -- Total encrypted data

-- Substructure order based on personality value
PokemonReader.substructureOrders = {
    {0, 1, 2, 3}, {0, 1, 3, 2}, {0, 2, 1, 3}, {0, 2, 3, 1}, {0, 3, 1, 2}, {0, 3, 2, 1},
    {1, 0, 2, 3}, {1, 0, 3, 2}, {1, 2, 0, 3}, {1, 2, 3, 0}, {1, 3, 0, 2}, {1, 3, 2, 0},
    {2, 0, 1, 3}, {2, 0, 3, 1}, {2, 1, 0, 3}, {2, 1, 3, 0}, {2, 3, 0, 1}, {2, 3, 1, 0},
    {3, 0, 1, 2}, {3, 0, 2, 1}, {3, 1, 0, 2}, {3, 1, 2, 0}, {3, 2, 0, 1}, {3, 2, 1, 0}
}

-- Status condition flags
PokemonReader.statusFlags = {
    SLEEP = 0x07,      -- 0-7 sleep counter
    POISON = 0x08,
    BURN = 0x10,
    FREEZE = 0x20,
    PARALYSIS = 0x40,
    BAD_POISON = 0x80
}

-- Calculate checksum for Pokemon data
function PokemonReader.calculateChecksum(data)
    local sum = 0
    -- Sum all 16-bit values in the encrypted data
    for i = 0, 23 do  -- 48 bytes = 24 16-bit values
        sum = sum + Memory.read_u16_le(data + 32 + (i * 2))
    end
    return band(sum, 0xFFFF)
end

-- Decrypt Pokemon data substructure
function PokemonReader.decryptSubstructure(address, key, index)
    local decrypted = {}
    
    for i = 0, 5 do  -- 12 bytes = 6 16-bit values
        local offset = index * 12 + (i * 2)
        local encrypted = Memory.read_u16_le(address + 32 + offset)
        if not encrypted then return nil end
        
        -- XOR with key
        local decryptedValue = bxor(encrypted, key)
        decrypted[i * 2 + 1] = band(decryptedValue, 0xFF)
        decrypted[i * 2 + 2] = rshift(decryptedValue, 8)
    end
    
    return decrypted
end

-- Read and decrypt Pokemon data
function PokemonReader.readPokemon(address, isInPC)
    if not address or address < 0x02000000 then
        return nil
    end
    
    -- Initialize ROM data if needed
    if not ROMData.data.initialized then
        ROMData.init()
    end
    
    local pokemon = {}
    
    -- Read unencrypted data (first 32 bytes)
    pokemon.personality = Memory.read_u32_le(address + 0)
    pokemon.otId = Memory.read_u32_le(address + 4)
    pokemon.nickname = PokemonReader.readPokemonString(address + 8, 10)
    pokemon.language = Memory.read_u16_le(address + 18)
    pokemon.otName = PokemonReader.readPokemonString(address + 20, 7)
    pokemon.markings = Memory.read_u8(address + 27)
    pokemon.checksum = Memory.read_u16_le(address + 28)
    
    -- Validate basic data
    if not pokemon.personality or pokemon.personality == 0 then
        return nil  -- Empty slot
    end
    
    -- Calculate encryption key
    local key = bxor(pokemon.personality, pokemon.otId)
    
    -- Determine substructure order
    local orderIndex = pokemon.personality % 24
    local order = PokemonReader.substructureOrders[orderIndex + 1]
    
    -- Decrypt substructures
    local substructures = {}
    for i = 0, 3 do
        substructures[i] = PokemonReader.decryptSubstructure(address, key, order[i + 1])
        if not substructures[i] then
            return nil  -- Decryption failed
        end
    end
    
    -- Parse Growth substructure (G)
    local growth = substructures[0]
    pokemon.species = growth[1] + (growth[2] * 256)
    pokemon.heldItem = growth[3] + (growth[4] * 256)
    pokemon.experience = growth[5] + (growth[6] * 256) + (growth[7] * 65536) + (growth[8] * 16777216)
    pokemon.ppBonuses = growth[9]
    pokemon.friendship = growth[10]
    
    -- Parse Attacks substructure (A)
    local attacks = substructures[1]
    pokemon.moves = {
        attacks[1] + (attacks[2] * 256),
        attacks[3] + (attacks[4] * 256),
        attacks[5] + (attacks[6] * 256),
        attacks[7] + (attacks[8] * 256)
    }
    pokemon.pp = {attacks[9], attacks[10], attacks[11], attacks[12]}
    
    -- Parse EVs & Condition substructure (E)
    local evs = substructures[2]
    pokemon.evs = {
        hp = evs[1],
        attack = evs[2],
        defense = evs[3],
        speed = evs[4],
        spAttack = evs[5],
        spDefense = evs[6]
    }
    pokemon.contest = {
        cool = evs[7],
        beauty = evs[8],
        cute = evs[9],
        smart = evs[10],
        tough = evs[11],
        feel = evs[12]
    }
    
    -- Parse Miscellaneous substructure (M)
    local misc = substructures[3]
    pokemon.pokerus = misc[1]
    pokemon.metLocation = misc[2]
    pokemon.origins = misc[3] + (misc[4] * 256)
    pokemon.ivs = misc[5] + (misc[6] * 256) + (misc[7] * 65536) + (misc[8] * 16777216)
    pokemon.ribbons = misc[9] + (misc[10] * 256) + (misc[11] * 65536) + (misc[12] * 16777216)
    
    -- Parse IVs (stored as 32-bit value)
    pokemon.parsedIVs = {
        hp = band(pokemon.ivs, 0x1F),
        attack = band(rshift(pokemon.ivs, 5), 0x1F),
        defense = band(rshift(pokemon.ivs, 10), 0x1F),
        speed = band(rshift(pokemon.ivs, 15), 0x1F),
        spAttack = band(rshift(pokemon.ivs, 20), 0x1F),
        spDefense = band(rshift(pokemon.ivs, 25), 0x1F),
        isEgg = band(rshift(pokemon.ivs, 30), 0x1) == 1,
        isNicknamed = band(rshift(pokemon.ivs, 31), 0x1) == 1
    }
    
    -- Parse origins info
    pokemon.metLevel = band(pokemon.origins, 0x7F)
    pokemon.gameOfOrigin = band(rshift(pokemon.origins, 7), 0xF)
    pokemon.ball = band(rshift(pokemon.origins, 11), 0xF)
    pokemon.otGender = band(rshift(pokemon.origins, 15), 0x1)
    
    -- Calculate nature from personality
    pokemon.nature = pokemon.personality % 25
    
    -- Get ability (personality bit determines which ability if Pokemon has two)
    local romData = ROMData.getPokemon(pokemon.species)
    if romData then
        if band(pokemon.personality, 1) == 0 then
            pokemon.ability = romData.ability1
        else
            pokemon.ability = romData.ability2 or romData.ability1
        end
    end
    
    -- Read battle stats if in party (not in PC)
    if not isInPC then
        local battleStatsAddr = address + 80
        pokemon.battleStats = {
            status = Memory.read_u32_le(battleStatsAddr + 0),
            level = Memory.read_u8(battleStatsAddr + 4),
            pokerusRemaining = Memory.read_u8(battleStatsAddr + 5),
            currentHP = Memory.read_u16_le(battleStatsAddr + 6),
            maxHP = Memory.read_u16_le(battleStatsAddr + 8),
            attack = Memory.read_u16_le(battleStatsAddr + 10),
            defense = Memory.read_u16_le(battleStatsAddr + 12),
            speed = Memory.read_u16_le(battleStatsAddr + 14),
            spAttack = Memory.read_u16_le(battleStatsAddr + 16),
            spDefense = Memory.read_u16_le(battleStatsAddr + 18),
        }
        
        -- Parse status
        if pokemon.battleStats.status > 0 then
            pokemon.battleStats.statusCondition = PokemonReader.parseStatus(pokemon.battleStats.status)
        end
    else
        -- For PC Pokemon, calculate stats
        pokemon.battleStats = PokemonReader.calculateStats(pokemon)
    end
    
    -- Add ROM data
    pokemon.baseData = romData
    
    return pokemon
end

-- Calculate stats for PC Pokemon
function PokemonReader.calculateStats(pokemon)
    local romData = ROMData.getPokemon(pokemon.species)
    if not romData then return nil end
    
    -- Calculate level from experience
    local level = PokemonReader.calculateLevel(pokemon.experience, romData.growthRate)
    
    -- Calculate stats
    local stats = {
        level = level,
        currentHP = 0,  -- Unknown for PC Pokemon
        maxHP = PokemonReader.calculateHP(romData.stats.hp, pokemon.parsedIVs.hp, pokemon.evs.hp, level),
        attack = PokemonReader.calculateStat(romData.stats.attack, pokemon.parsedIVs.attack, pokemon.evs.attack, level, pokemon.nature, 1),
        defense = PokemonReader.calculateStat(romData.stats.defense, pokemon.parsedIVs.defense, pokemon.evs.defense, level, pokemon.nature, 2),
        speed = PokemonReader.calculateStat(romData.stats.speed, pokemon.parsedIVs.speed, pokemon.evs.speed, level, pokemon.nature, 3),
        spAttack = PokemonReader.calculateStat(romData.stats.spAttack, pokemon.parsedIVs.spAttack, pokemon.evs.spAttack, level, pokemon.nature, 4),
        spDefense = PokemonReader.calculateStat(romData.stats.spDefense, pokemon.parsedIVs.spDefense, pokemon.evs.spDefense, level, pokemon.nature, 5)
    }
    
    return stats
end

-- Calculate HP stat
function PokemonReader.calculateHP(base, iv, ev, level)
    if base == 1 then return 1 end  -- Shedinja
    return math.floor((2 * base + iv + math.floor(ev / 4)) * level / 100) + level + 10
end

-- Calculate other stats
function PokemonReader.calculateStat(base, iv, ev, level, nature, statIndex)
    local stat = math.floor((2 * base + iv + math.floor(ev / 4)) * level / 100) + 5
    
    -- Apply nature modifier
    local natureData = ROMData.getNature(nature)
    if natureData then
        if natureData.increased == statIndex then
            stat = math.floor(stat * 1.1)
        elseif natureData.decreased == statIndex then
            stat = math.floor(stat * 0.9)
        end
    end
    
    return stat
end

-- Calculate level from experience
function PokemonReader.calculateLevel(exp, growthRate)
    -- Simplified - would need full experience tables
    -- For now, return estimate
    if exp < 8 then return 1 end
    if exp < 27 then return 2 end
    if exp < 64 then return 3 end
    if exp < 125 then return 4 end
    if exp < 216 then return 5 end
    
    -- Rough approximation for higher levels
    return math.min(100, math.floor(math.pow(exp / 100, 1/3) * 10))
end

-- Parse status condition
function PokemonReader.parseStatus(status)
    local conditions = {}
    
    -- Sleep counter (0-7)
    local sleepCounter = band(status, PokemonReader.statusFlags.SLEEP)
    if sleepCounter > 0 then
        conditions.sleep = sleepCounter
    end
    
    -- Other conditions
    if band(status, PokemonReader.statusFlags.POISON) > 0 then
        conditions.poison = true
    end
    if band(status, PokemonReader.statusFlags.BURN) > 0 then
        conditions.burn = true
    end
    if band(status, PokemonReader.statusFlags.FREEZE) > 0 then
        conditions.freeze = true
    end
    if band(status, PokemonReader.statusFlags.PARALYSIS) > 0 then
        conditions.paralysis = true
    end
    if band(status, PokemonReader.statusFlags.BAD_POISON) > 0 then
        conditions.badPoison = true
    end
    
    return conditions
end

-- Read entire party
function PokemonReader.readParty()
    local partyAddr = Pointers.getPartyAddress()
    if not partyAddr then return nil end
    
    local party = {
        count = Memory.read_u32_le(partyAddr),
        pokemon = {}
    }
    
    -- Validate party count
    if not party.count or party.count > 6 then
        party.count = 0
        return party
    end
    
    -- Read each Pokemon
    for i = 0, party.count - 1 do
        local pokemonAddr = partyAddr + 4 + (i * PokemonReader.POKEMON_SIZE)
        party.pokemon[i + 1] = PokemonReader.readPokemon(pokemonAddr, false)
    end
    
    return party
end

-- Read PC box
function PokemonReader.readPCBox(boxNumber)
    if boxNumber < 0 or boxNumber > 13 then
        return nil
    end
    
    local box = {
        number = boxNumber,
        pokemon = {}
    }
    
    -- Read all 30 slots
    for i = 0, 29 do
        local addr = Pointers.getPCBoxAddress(boxNumber, i)
        if addr then
            local pokemon = PokemonReader.readPokemon(addr, true)
            if pokemon and pokemon.species > 0 then
                box.pokemon[i + 1] = pokemon
            end
        end
    end
    
    return box
end

-- Read Pokemon string (Gen 3 encoding)
function PokemonReader.readPokemonString(address, maxLength)
    local str = ""
    for i = 0, maxLength - 1 do
        local char = Memory.read_u8(address + i)
        if not char or char == 0xFF then break end
        
        -- Character mapping (simplified)
        if char == 0x00 then
            str = str .. " "
        elseif char >= 0xBB and char <= 0xD4 then
            str = str .. string.char(char - 0xBB + 65)  -- A-Z
        elseif char >= 0xD5 and char <= 0xEE then
            str = str .. string.char(char - 0xD5 + 97)  -- a-z
        elseif char >= 0xA1 and char <= 0xAA then
            str = str .. string.char(char - 0xA1 + 48)  -- 0-9
        else
            -- Special characters would go here
        end
    end
    return str
end

-- Format Pokemon info for display
function PokemonReader.formatPokemon(pokemon)
    if not pokemon then return "Empty" end
    
    local info = {}
    
    -- Basic info
    info.name = pokemon.nickname ~= "" and pokemon.nickname or 
               (pokemon.baseData and pokemon.baseData.name or "???")
    info.species = pokemon.baseData and pokemon.baseData.name or "???"
    info.level = pokemon.battleStats and pokemon.battleStats.level or "?"
    
    -- HP
    if pokemon.battleStats then
        info.hp = string.format("%d/%d", 
            pokemon.battleStats.currentHP or 0,
            pokemon.battleStats.maxHP or 0)
    else
        info.hp = "???/???"
    end
    
    -- Status
    if pokemon.battleStats and pokemon.battleStats.statusCondition then
        local status = pokemon.battleStats.statusCondition
        if status.sleep then info.status = "SLP"
        elseif status.poison then info.status = "PSN"
        elseif status.badPoison then info.status = "TOX"
        elseif status.burn then info.status = "BRN"
        elseif status.freeze then info.status = "FRZ"
        elseif status.paralysis then info.status = "PAR"
        end
    end
    
    -- Types
    if pokemon.baseData then
        info.types = ROMData.getTypeName(pokemon.baseData.type1) or "???"
        if pokemon.baseData.type1 ~= pokemon.baseData.type2 then
            info.types = info.types .. "/" .. (ROMData.getTypeName(pokemon.baseData.type2) or "???")
        end
    end
    
    -- Ability
    info.ability = ROMData.getAbilityName(pokemon.ability) or "???"
    
    -- Nature
    local natureData = ROMData.getNature(pokemon.nature)
    info.nature = natureData and natureData.name or "???"
    
    -- Item
    info.item = pokemon.heldItem > 0 and 
               (ROMData.getItem(pokemon.heldItem) and ROMData.getItem(pokemon.heldItem).name or "Unknown") 
               or "None"
    
    return info
end

-- Test function
function PokemonReader.test()
    console.log("=== Pokemon Reader Module Test ===\n")
    
    -- Initialize ROM data
    ROMData.init()
    
    -- Read party
    console.log("Reading party...")
    local party = PokemonReader.readParty()
    
    if party and party.count > 0 then
        console.log(string.format("✓ Party has %d Pokemon:", party.count))
        
        for i, pokemon in ipairs(party.pokemon) do
            if pokemon then
                local info = PokemonReader.formatPokemon(pokemon)
                console.log(string.format("\n%d. %s (Lv.%s %s)", 
                    i, info.name, info.level, info.species))
                console.log(string.format("   HP: %s%s", 
                    info.hp, info.status and " [" .. info.status .. "]" or ""))
                console.log(string.format("   Type: %s | Ability: %s | Nature: %s",
                    info.types, info.ability, info.nature))
                console.log(string.format("   Item: %s", info.item))
                
                -- Show moves
                if pokemon.moves then
                    local moveStr = "   Moves: "
                    for j, moveId in ipairs(pokemon.moves) do
                        if moveId > 0 then
                            local move = ROMData.getMove(moveId)
                            if move then
                                moveStr = moveStr .. move.name .. " "
                            end
                        end
                    end
                    console.log(moveStr)
                end
                
                -- Show stats
                if pokemon.battleStats then
                    console.log(string.format("   Stats: ATK:%d DEF:%d SPE:%d SPA:%d SPD:%d",
                        pokemon.battleStats.attack,
                        pokemon.battleStats.defense,
                        pokemon.battleStats.speed,
                        pokemon.battleStats.spAttack,
                        pokemon.battleStats.spDefense))
                end
            end
        end
    else
        console.log("✗ No party Pokemon found (game not loaded?)")
    end
end

return PokemonReader
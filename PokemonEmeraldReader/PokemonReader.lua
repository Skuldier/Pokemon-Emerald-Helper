-- PokemonReader.lua
-- Fixed version with proper move decryption for Archipelago ROMs

local Memory = require("Memory")
local Pointers = require("Pointers")
local ROMData = require("ROMData")

local PokemonReader = {}

-- Bitwise operations
local band = bit.band or function(a,b) return a & b end
local bor = bit.bor or function(a,b) return a | b end
local bxor = bit.bxor or function(a,b) return a ~ b end
local bnot = bit.bnot or function(a) return ~a end
local lshift = bit.lshift or function(a,b) return a << b end
local rshift = bit.rshift or function(a,b) return a >> b end

-- Constants
PokemonReader.POKEMON_SIZE = 100
PokemonReader.POKEMON_PC_SIZE = 80
PokemonReader.PARTY_SIZE = 6

-- Substructure order tables (24 possible orders)
PokemonReader.SUBSTRUCTURE_ORDERS = {
    {0, 1, 2, 3}, {0, 1, 3, 2}, {0, 2, 1, 3}, {0, 2, 3, 1}, {0, 3, 1, 2}, {0, 3, 2, 1},
    {1, 0, 2, 3}, {1, 0, 3, 2}, {1, 2, 0, 3}, {1, 2, 3, 0}, {1, 3, 0, 2}, {1, 3, 2, 0},
    {2, 0, 1, 3}, {2, 0, 3, 1}, {2, 1, 0, 3}, {2, 1, 3, 0}, {2, 3, 0, 1}, {2, 3, 1, 0},
    {3, 0, 1, 2}, {3, 0, 2, 1}, {3, 1, 0, 2}, {3, 1, 2, 0}, {3, 2, 0, 1}, {3, 2, 1, 0}
}

-- Substructure types
local GROWTH = 0
local ATTACKS = 1
local EVS = 2
local MISC = 3

-- Decrypt a 12-byte substructure
function PokemonReader.decryptSubstructure(data, key)
    local decrypted = {}
    for i = 1, 12, 4 do
        local word = 0
        for j = 0, 3 do
            word = bor(word, lshift(data[i + j] or 0, j * 8))
        end
        local decryptedWord = bxor(word, key)
        for j = 0, 3 do
            decrypted[i + j] = band(rshift(decryptedWord, j * 8), 0xFF)
        end
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
    
    -- Read unencrypted header (32 bytes)
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
    
    -- Read encrypted data (48 bytes)
    local encryptedData = Memory.readbytes(address + 32, 48)
    if not encryptedData then
        return nil
    end
    
    -- Determine substructure order
    local orderIndex = pokemon.personality % 24
    local order = PokemonReader.SUBSTRUCTURE_ORDERS[orderIndex + 1]
    
    -- Decrypt each 12-byte substructure
    local substructures = {}
    for i = 0, 3 do
        local offset = i * 12 + 1
        local subData = {}
        for j = 0, 11 do
            subData[j + 1] = encryptedData[offset + j]
        end
        local decrypted = PokemonReader.decryptSubstructure(subData, key)
        local subType = order[i + 1]
        substructures[subType] = decrypted
    end
    
    -- Extract data from decrypted substructures
    -- Growth substructure
    if substructures[GROWTH] then
        local growth = substructures[GROWTH]
        pokemon.species = bor(growth[1] or 0, lshift(growth[2] or 0, 8))
        pokemon.heldItem = bor(growth[3] or 0, lshift(growth[4] or 0, 8))
        pokemon.experience = bor(growth[5] or 0, lshift(growth[6] or 0, 8), 
                                lshift(growth[7] or 0, 16), lshift(growth[8] or 0, 24))
        pokemon.ppBonuses = growth[9] or 0
        pokemon.friendship = growth[10] or 0
    end
    
    -- Attacks substructure - THIS IS WHERE MOVES ARE!
    if substructures[ATTACKS] then
        local attacks = substructures[ATTACKS]
        pokemon.moves = {}
        pokemon.pp = {}
        
        -- Read 4 moves (2 bytes each)
        for i = 0, 3 do
            local offset = i * 2 + 1
            local moveId = bor(attacks[offset] or 0, lshift(attacks[offset + 1] or 0, 8))
            
            -- Archipelago might have extended move IDs, but let's validate them
            if moveId > 0 and moveId < 50000 then
                pokemon.moves[i + 1] = moveId
            else
                pokemon.moves[i + 1] = 0
            end
        end
        
        -- Read PP (1 byte each) with validation
        for i = 0, 3 do
            local pp = attacks[9 + i] or 0
            -- Normal max PP is usually under 64, but with PP Ups it can go to 61*1.6 = ~97
            -- Archipelago might have different values, so be lenient
            if pp > 0 and pp <= 255 then
                pokemon.pp[i + 1] = pp
            else
                pokemon.pp[i + 1] = 0
            end
        end
    end
    
    -- EVs substructure
    if substructures[EVS] then
        local evs = substructures[EVS]
        pokemon.evs = {
            hp = evs[1] or 0,
            attack = evs[2] or 0,
            defense = evs[3] or 0,
            speed = evs[4] or 0,
            spAttack = evs[5] or 0,
            spDefense = evs[6] or 0
        }
        pokemon.cool = evs[7] or 0
        pokemon.beauty = evs[8] or 0
        pokemon.cute = evs[9] or 0
        pokemon.smart = evs[10] or 0
        pokemon.tough = evs[11] or 0
        pokemon.feel = evs[12] or 0
    end
    
    -- Misc substructure
    if substructures[MISC] then
        local misc = substructures[MISC]
        pokemon.pokerus = misc[1] or 0
        pokemon.metLocation = misc[2] or 0
        local origins = bor(misc[3] or 0, lshift(misc[4] or 0, 8))
        pokemon.metLevel = band(origins, 0x7F)
        pokemon.metGame = band(rshift(origins, 7), 0xF)
        pokemon.pokeball = band(rshift(origins, 11), 0xF)
        pokemon.otGender = band(rshift(origins, 15), 0x1)
        
        local ivEggAbility = bor(misc[5] or 0, lshift(misc[6] or 0, 8), 
                                lshift(misc[7] or 0, 16), lshift(misc[8] or 0, 24))
        
        -- Parse IVs
        pokemon.parsedIVs = {
            hp = band(ivEggAbility, 0x1F),
            attack = band(rshift(ivEggAbility, 5), 0x1F),
            defense = band(rshift(ivEggAbility, 10), 0x1F),
            speed = band(rshift(ivEggAbility, 15), 0x1F),
            spAttack = band(rshift(ivEggAbility, 20), 0x1F),
            spDefense = band(rshift(ivEggAbility, 25), 0x1F)
        }
        
        pokemon.isEgg = band(rshift(ivEggAbility, 30), 0x1)
        pokemon.abilityBit = band(rshift(ivEggAbility, 31), 0x1)
    end
    
    -- Read battle stats (unencrypted, only for party Pokemon)
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
    end
    
    -- Get ROM data for the species
    if pokemon.species and pokemon.species > 0 and pokemon.species < 500 then
        pokemon.baseData = ROMData.getPokemon(pokemon.species)
    end
    
    -- Calculate nature from personality
    pokemon.nature = pokemon.personality % 25
    
    return pokemon
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

-- Read Pokemon string (Gen 3 encoding)
function PokemonReader.readPokemonString(address, maxLength)
    local str = ""
    for i = 0, maxLength - 1 do
        local char = Memory.read_u8(address + i)
        if not char or char == 0xFF then break end
        
        -- Character mapping
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
        elseif char == 0xBA then
            str = str .. "!"
        elseif char == 0xBF then
            str = str .. "?"
        end
    end
    return str
end

-- Format Pokemon info for display
function PokemonReader.formatPokemon(pokemon)
    if not pokemon then return {
        name = "Empty",
        species = "???",
        level = "?",
        hp = "???/???",
        types = "???",
        ability = "???",
        nature = "???",
        item = "None"
    } end
    
    local info = {}
    
    -- Basic info
    info.name = pokemon.nickname ~= "" and pokemon.nickname or 
               (pokemon.baseData and pokemon.baseData.name or "???")
    info.species = pokemon.baseData and pokemon.baseData.name or 
                  (pokemon.species and string.format("Species #%d", pokemon.species) or "???")
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
    if pokemon.battleStats and pokemon.battleStats.status and pokemon.battleStats.status > 0 then
        local status = pokemon.battleStats.status
        if band(status, 0x07) > 0 then info.status = "SLP"
        elseif band(status, 0x08) > 0 then info.status = "PSN"
        elseif band(status, 0x10) > 0 then info.status = "BRN"
        elseif band(status, 0x20) > 0 then info.status = "FRZ"
        elseif band(status, 0x40) > 0 then info.status = "PAR"
        elseif band(status, 0x80) > 0 then info.status = "TOX"
        end
    end
    
    -- Types
    if pokemon.baseData then
        info.types = ROMData.getTypeName(pokemon.baseData.type1) or "???"
        if pokemon.baseData.type1 ~= pokemon.baseData.type2 then
            info.types = info.types .. "/" .. (ROMData.getTypeName(pokemon.baseData.type2) or "???")
        end
    else
        info.types = "???/???"
    end
    
    -- Ability
    if pokemon.baseData and pokemon.abilityBit then
        local abilityId = pokemon.abilityBit == 0 and pokemon.baseData.ability1 or pokemon.baseData.ability2
        local abilityData = ROMData.getAbility(abilityId)
        info.ability = abilityData and abilityData.name or "???"
    else
        info.ability = "???"
    end
    
    -- Nature
    local natureData = ROMData.getNature(pokemon.nature)
    info.nature = natureData and natureData.name or "???"
    
    -- Item
    if pokemon.heldItem and pokemon.heldItem > 0 then
        local itemData = ROMData.getItem(pokemon.heldItem)
        info.item = itemData and itemData.name or string.format("Item #%d", pokemon.heldItem)
    else
        info.item = "None"
    end
    
    return info
end

return PokemonReader
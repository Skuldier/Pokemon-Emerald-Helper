-- Comprehensive Pokemon Memory Search
-- This will find your Pokemon data no matter where it is!

memory.usememorydomain("System Bus")

console.clear()
console.log("===========================================")
console.log("COMPREHENSIVE POKEMON MEMORY SEARCH")
console.log("===========================================")
console.log("")
console.log("Make sure you are IN A BATTLE before running!")
console.log("")

-- Check if in battle
local in_battle = memory.readbyte(0x02022FEC)
if in_battle == 0 then
    console.log("ERROR: Not in battle! Enter a battle first.")
    return
end

console.log("Battle detected (flag = " .. in_battle .. "). Starting search...")
console.log("")

-- Known Gen 3 Pokemon that commonly appear
local common_pokemon = {
    -- Hoenn Pokemon
    261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275,
    276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290,
    -- Common early game
    16, 17, 19, 20, 21, 22, 25, 26, 27, 28, 29, 30, 41, 42, 43, 44, 45,
    -- Your starter
    252, 253, 254, 255, 256, 257, 258, 259, 260
}

-- Convert to lookup table
local valid_species = {}
for _, id in ipairs(common_pokemon) do
    valid_species[id] = true
end

-- Function to check if this looks like Pokemon data
function check_pokemon_structure(addr)
    -- Read potential species ID
    local species = memory.read_u16_le(addr + 0x20)
    
    -- Quick validation
    if species == 0 or species > 411 then
        return false, nil
    end
    
    -- Read other fields for validation
    local level = memory.readbyte(addr + 0x54)
    local hp_current = memory.read_u16_le(addr + 0x56)
    local hp_max = memory.read_u16_le(addr + 0x58)
    local attack = memory.read_u16_le(addr + 0x5A)
    local defense = memory.read_u16_le(addr + 0x5C)
    
    -- Validate data
    if level < 2 or level > 100 then return false, nil end
    if hp_max == 0 or hp_max > 999 then return false, nil end
    if hp_current > hp_max then return false, nil end
    if attack == 0 or attack > 999 then return false, nil end
    if defense == 0 or defense > 999 then return false, nil end
    
    -- Extra validation - check if stats make sense
    local total_stats = attack + defense + memory.read_u16_le(addr + 0x5E) + 
                       memory.read_u16_le(addr + 0x60) + memory.read_u16_le(addr + 0x62)
    
    if total_stats < 50 or total_stats > 3000 then return false, nil end
    
    -- This looks like valid Pokemon data!
    return true, {
        species = species,
        level = level,
        hp_current = hp_current,
        hp_max = hp_max,
        attack = attack,
        defense = defense,
        known = valid_species[species] or false
    }
end

-- Search memory ranges
local found_pokemon = {}
local search_ranges = {
    {start = 0x02000000, size = 0x40000, name = "EWRAM"},  -- 256KB
    {start = 0x03000000, size = 0x8000, name = "IWRAM"}    -- 32KB
}

console.log("Searching for Pokemon structures...")
console.log("This may take a few seconds...")
console.log("")

for _, range in ipairs(search_ranges) do
    console.log("Searching " .. range.name .. "...")
    
    -- Search in 4-byte aligned addresses
    for addr = range.start, range.start + range.size - 0x100, 4 do
        local valid, data = check_pokemon_structure(addr)
        
        if valid then
            table.insert(found_pokemon, {
                address = addr,
                data = data
            })
            
            local known_text = data.known and " (KNOWN SPECIES)" or ""
            console.log(string.format("Found Pokemon at 0x%08X: Species %d, Lv%d, HP %d/%d%s",
                addr, data.species, data.level, data.hp_current, data.hp_max, known_text))
        end
    end
end

console.log("")
console.log("Search complete! Found " .. #found_pokemon .. " Pokemon structures")
console.log("")

-- Analyze results
if #found_pokemon >= 2 then
    console.log("ANALYSIS:")
    
    -- Look for party patterns (6 Pokemon in sequence)
    local party_candidates = {}
    
    for i = 1, #found_pokemon do
        local base_addr = found_pokemon[i].address
        local count = 1
        
        -- Check if there are more Pokemon at 100-byte intervals
        for j = i + 1, #found_pokemon do
            if found_pokemon[j].address == base_addr + (count * 100) then
                count = count + 1
            end
        end
        
        if count >= 2 then  -- At least 2 Pokemon in sequence
            table.insert(party_candidates, {
                base = base_addr,
                count = count
            })
        end
    end
    
    if #party_candidates > 0 then
        console.log("")
        console.log("Found " .. #party_candidates .. " possible party structures:")
        for _, party in ipairs(party_candidates) do
            console.log(string.format("  - Base: 0x%08X (%d Pokemon in sequence)", 
                party.base, party.count))
        end
    end
    
    -- Guess player vs enemy
    console.log("")
    console.log("RECOMMENDED ADDRESSES:")
    
    if #found_pokemon >= 12 then
        -- Probably found both parties
        console.log(string.format("PARTY_PLAYER = 0x%08X", found_pokemon[1].address))
        console.log(string.format("PARTY_ENEMY = 0x%08X", found_pokemon[7].address))
    elseif #found_pokemon >= 2 then
        -- Just found active Pokemon
        console.log(string.format("PARTY_PLAYER = 0x%08X", found_pokemon[1].address))
        console.log(string.format("PARTY_ENEMY = 0x%08X", found_pokemon[2].address))
    end
    
    console.log("")
    console.log("Add these addresses to your script!")
else
    console.log("ERROR: Could not find enough Pokemon structures")
    console.log("Make sure you're in a battle with visible Pokemon")
end

-- Extra diagnostics
console.log("")
console.log("DIAGNOSTICS:")
console.log("Battle flag value: " .. in_battle)
console.log("Total structures found: " .. #found_pokemon)

if #found_pokemon > 0 then
    console.log("")
    console.log("First few Pokemon found:")
    for i = 1, math.min(5, #found_pokemon) do
        local p = found_pokemon[i]
        console.log(string.format("%d. 0x%08X - Species %d Lv%d", 
            i, p.address, p.data.species, p.data.level))
    end
end
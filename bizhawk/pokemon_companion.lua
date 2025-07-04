-- Pokemon Companion Connector for BizHawk
-- Enhanced version with data decryption and tier rating support
-- 
-- Requirements:
-- - BizHawk with Lua 5.3+ support (for modern bitwise operators)
-- - Pokemon Emerald US ROM
-- 
-- Features:
-- - Full Pokemon data decryption (XOR decryption of substructures)
-- - Comprehensive battle detection (wild and trainer battles)
-- - Party monitoring with EVs, IVs, moves, and abilities
-- - Shiny detection and nature calculation
-- - Game progress estimation for tier weighting
-- - DMA-aware memory reading
--
-- Place this script in BizHawk/Lua folder and run from Lua Console

-- Load socket library
local socket = require("socket.core")

-- Check Lua version for bitwise operators
if _VERSION < "Lua 5.3" then
    print("WARNING: This script requires Lua 5.3+ for bitwise operators")
    print("Your version: " .. _VERSION)
    print("Script may not work correctly!")
end

-- Configuration
local SERVER_HOST = "127.0.0.1"
local SERVER_PORT = 17242
local RECONNECT_DELAY = 300
local UPDATE_INTERVAL = 30

-- State
local connection = nil
local connected = false
local reconnect_timer = 0
local update_timer = 0
local last_battle_state = {enemy_species = 0, is_trainer_battle = false}
local EWRAM_OFFSET = 0x02000000

-- Substructure order lookup table
local SUBSTRUCTURE_ORDERS = {
    {0, 1, 2, 3}, {0, 1, 3, 2}, {0, 2, 1, 3}, {0, 3, 1, 2}, {0, 2, 3, 1}, {0, 3, 2, 1},
    {1, 0, 2, 3}, {1, 0, 3, 2}, {2, 0, 1, 3}, {3, 0, 1, 2}, {2, 0, 3, 1}, {3, 0, 2, 1},
    {1, 2, 0, 3}, {1, 3, 0, 2}, {2, 1, 0, 3}, {3, 1, 0, 2}, {2, 3, 0, 1}, {3, 2, 0, 1},
    {1, 2, 3, 0}, {1, 3, 2, 0}, {2, 1, 3, 0}, {3, 1, 2, 0}, {2, 3, 1, 0}, {3, 2, 1, 0}
}

-- Set up memory domain for GBA
if emu.getsystemid() == "GBA" then
    -- Check available domains
    local domains = memory.getmemorydomainlist()
    local has_ewram = false
    
    for _, domain in ipairs(domains) do
        if domain == "EWRAM" then
            has_ewram = true
            break
        end
    end
    
    if has_ewram then
        memory.usememorydomain("EWRAM")
        print("Using EWRAM memory domain")
    else
        -- If no EWRAM, we'll use mainmemory functions instead
        print("EWRAM not available, using mainmemory functions")
        EWRAM_OFFSET = 0
    end
end

-- Pokemon Emerald US Memory Addresses (with DMA-aware offsets)
local POKE_ADDR = {
    -- Party Pokemon
    party_count = 0x020244E9 - EWRAM_OFFSET,
    party_base = 0x0202402C - EWRAM_OFFSET,
    
    -- Battle data (active Pokemon in battle)
    player_active = 0x02024284 - EWRAM_OFFSET,  -- Battle struct for player's active
    enemy_active = 0x02024744 - EWRAM_OFFSET,   -- Battle struct for enemy's active
    
    -- Wild Pokemon encounter data
    wild_species = 0x02024AD8 - EWRAM_OFFSET,
    wild_level = 0x02024AFC - EWRAM_OFFSET,
    wild_hp_current = 0x02024B00 - EWRAM_OFFSET,
    wild_moves_base = 0x02024AE4 - EWRAM_OFFSET,
    
    -- Battle state indicators
    battle_state = 0x02022FEC - EWRAM_OFFSET,    -- 0 = no battle, 1+ = in battle
    battle_type = 0x02022FEE - EWRAM_OFFSET,     -- 0 = wild, 1 = trainer, etc.
    
    -- ROM Base Stats offset (for tier calculations)
    rom_base_stats = 0x254784,  -- Base stats table in ROM
}

-- Pokemon data structure sizes
local PARTY_POKEMON_SIZE = 100  -- Full party structure
local BOX_POKEMON_SIZE = 80     -- PC storage structure

-- Memory read functions that work with both approaches
local function read_byte(addr)
    if EWRAM_OFFSET == 0 then
        return mainmemory.readbyte(addr + 0x02000000)
    else
        return memory.readbyte(addr)
    end
end

local function read_u16(addr)
    if EWRAM_OFFSET == 0 then
        return mainmemory.read_u16_le(addr + 0x02000000)
    else
        return memory.read_u16_le(addr)
    end
end

local function read_u32(addr)
    if EWRAM_OFFSET == 0 then
        return mainmemory.read_u32_le(addr + 0x02000000)
    else
        return memory.read_u32_le(addr)
    end
end

-- Simple JSON encoder
local function to_json(t)
    if type(t) == "table" then
        local parts = {}
        for k, v in pairs(t) do
            table.insert(parts, '"' .. k .. '":' .. to_json(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(t) == "number" then
        return tostring(t)
    elseif type(t) == "boolean" then
        return tostring(t)
    elseif type(t) == "nil" then
        return "null"
    else
        return '"' .. tostring(t) .. '"'
    end
end

-- Check if Pokemon is shiny
local function is_shiny(personality, otid)
    local p1 = personality & 0xFFFF
    local p2 = personality >> 16
    local t1 = otid & 0xFFFF
    local t2 = otid >> 16
    
    local xor_value = (p1 ~ p2) ~ (t1 ~ t2)
    return xor_value < 8
end

-- Calculate gender (simplified - would need species gender ratios)
local function calculate_gender(personality, species)
    -- This is simplified - actual implementation needs species gender ratios
    local gender_value = personality & 0xFF
    return gender_value < 127 and "female" or "male"
end

-- Decrypt Pokemon data
local function decrypt_substructure(data, personality, otid)
    local key = personality ~ otid
    local decrypted = {}
    
    -- Decrypt 48 bytes of substructure data
    for i = 0, 47 do
        local encrypted_byte = data[i + 1] or 0
        local key_byte = (key >> ((i & 3) * 8)) & 0xFF
        decrypted[i + 1] = encrypted_byte ~ key_byte
    end
    
    return decrypted
end

-- Get substructure order based on personality value
local function get_substructure_order(personality)
    local order_index = personality % 24
    return SUBSTRUCTURE_ORDERS[order_index + 1]
end

-- Read Pokemon data with decryption
local function read_pokemon_full(base_addr)
    -- Read basic unencrypted data
    local personality = read_u32(base_addr)
    local otid = read_u32(base_addr + 0x04)
    
    -- Read encrypted data block
    local encrypted_data = {}
    for i = 0, 47 do
        encrypted_data[i + 1] = read_byte(base_addr + 0x28 + i)
    end
    
    -- Decrypt the data
    local decrypted = decrypt_substructure(encrypted_data, personality, otid)
    
    -- Get substructure order
    local order = get_substructure_order(personality)
    
    -- Extract data from substructures
    -- Growth substructure (contains species)
    local growth_offset = order[1] * 12
    local species = decrypted[growth_offset + 1] + (decrypted[growth_offset + 2] * 256)
    local held_item = decrypted[growth_offset + 3] + (decrypted[growth_offset + 4] * 256)
    local experience = decrypted[growth_offset + 5] + (decrypted[growth_offset + 6] * 256) + 
                      (decrypted[growth_offset + 7] * 65536) + (decrypted[growth_offset + 8] * 16777216)
    
    -- Attacks substructure (contains moves and PP)
    local attacks_offset = order[2] * 12
    local moves = {}
    local pps = {}
    for i = 0, 3 do
        moves[i + 1] = decrypted[attacks_offset + (i * 2) + 1] + 
                       (decrypted[attacks_offset + (i * 2) + 2] * 256)
        pps[i + 1] = decrypted[attacks_offset + 8 + i + 1]
    end
    
    -- EVs substructure
    local evs_offset = order[3] * 12
    local evs = {
        hp = decrypted[evs_offset + 1],
        attack = decrypted[evs_offset + 2],
        defense = decrypted[evs_offset + 3],
        speed = decrypted[evs_offset + 4],
        sp_attack = decrypted[evs_offset + 5],
        sp_defense = decrypted[evs_offset + 6]
    }
    
    -- Misc substructure (contains IVs and ability bit)
    local misc_offset = order[4] * 12
    local ivs_egg_ability = decrypted[misc_offset + 5] + (decrypted[misc_offset + 6] * 256) + 
                           (decrypted[misc_offset + 7] * 65536) + (decrypted[misc_offset + 8] * 16777216)
    
    -- Extract IVs (5 bits each)
    local ivs = {
        hp = ivs_egg_ability & 0x1F,
        attack = (ivs_egg_ability >> 5) & 0x1F,
        defense = (ivs_egg_ability >> 10) & 0x1F,
        speed = (ivs_egg_ability >> 15) & 0x1F,
        sp_attack = (ivs_egg_ability >> 20) & 0x1F,
        sp_defense = (ivs_egg_ability >> 25) & 0x1F
    }
    
    -- Read battle stats (unencrypted, at end of party structure)
    local pokemon = {
        personality = personality,
        otid = otid,
        species = species,
        held_item = held_item,
        experience = experience,
        moves = moves,
        pp = pps,
        evs = evs,
        ivs = ivs,
        ability_bit = personality & 1,  -- 0 or 1 for ability slot
        nature = personality % 25,
        
        -- Battle stats (only available for party Pokemon)
        level = read_byte(base_addr + 0x54),
        status = read_u32(base_addr + 0x50),
        current_hp = read_u16(base_addr + 0x56),
        max_hp = read_u16(base_addr + 0x58),
        attack = read_u16(base_addr + 0x5A),
        defense = read_u16(base_addr + 0x5C),
        speed = read_u16(base_addr + 0x5E),
        sp_attack = read_u16(base_addr + 0x60),
        sp_defense = read_u16(base_addr + 0x62),
    }
    
    -- Calculate additional properties
    pokemon.is_shiny = is_shiny(personality, otid)
    pokemon.gender = calculate_gender(personality, species)
    
    return pokemon
end

-- Read wild Pokemon data (during encounters)
local function read_wild_pokemon()
    local species = read_u16(POKE_ADDR.wild_species)
    
    if species == 0 or species > 386 then
        return nil
    end
    
    return {
        species = species,
        level = read_byte(POKE_ADDR.wild_level),
        hp_current = read_u16(POKE_ADDR.wild_hp_current),
        -- Wild Pokemon don't have full stats readily available in memory
        -- They're calculated on the fly from base stats + IVs + EVs
    }
end

-- Connect to server
local function connect()
    print("Connecting to " .. SERVER_HOST .. ":" .. SERVER_PORT .. "...")
    
    local sock = socket.tcp()
    sock:settimeout(1)
    
    local success, err = sock:connect(SERVER_HOST, SERVER_PORT)
    if not success then
        print("Connection failed: " .. tostring(err))
        return false
    end
    
    sock:settimeout(0)
    connection = sock
    connected = true
    
    print("Connected to Pokemon Companion!")
    
    -- Send handshake
    connection:send("Hello|BizHawk|BizHawk|" .. gameinfo.getromname() .. "\n")
    
    return true
end

-- Disconnect
local function disconnect()
    if connection then
        pcall(function()
            connection:send("Goodbye|BizHawk\n")
            connection:close()
        end)
        connection = nil
    end
    connected = false
end

-- Send message
local function send_message(msg)
    if not connected then return false end
    
    local success, err = pcall(function()
        connection:send(msg .. "\n")
    end)
    
    if not success then
        print("Send error: " .. tostring(err))
        disconnect()
        return false
    end
    
    return true
end

-- Get approximate game progress for tier calculations
local function get_game_progress()
    -- This would need more sophisticated logic based on flags/badges
    -- For now, estimate based on party levels
    local party_count = read_byte(POKE_ADDR.party_count)
    if party_count == 0 then return 0 end
    
    local total_level = 0
    for i = 0, math.min(party_count - 1, 5) do
        local addr = POKE_ADDR.party_base + (i * PARTY_POKEMON_SIZE) + 0x54
        total_level = total_level + read_byte(addr)
    end
    
    local avg_level = total_level / party_count
    -- Rough progress estimate
    if avg_level < 15 then return 0.1
    elseif avg_level < 30 then return 0.25
    elseif avg_level < 45 then return 0.5
    elseif avg_level < 60 then return 0.75
    else return 0.9 end
end

-- Enhanced battle detection
local function check_battle_state()
    local battle_state = read_byte(POKE_ADDR.battle_state)
    local battle_type = read_byte(POKE_ADDR.battle_type)
    
    if battle_state == 0 then
        -- Not in battle
        if last_battle_state.enemy_species ~= 0 then
            print("Battle ended")
            send_message("BattleEnd")
            last_battle_state = {enemy_species = 0, is_trainer_battle = false}
        end
        return
    end
    
    -- In battle - determine type
    local is_wild = (battle_type == 0)
    local battle_data = {
        type = is_wild and "wild" or "trainer",
        turn = read_byte(POKE_ADDR.battle_state)  -- Can indicate turn number
    }
    
    -- Read player's active Pokemon
    local player_pokemon = read_pokemon_full(POKE_ADDR.player_active)
    if player_pokemon and player_pokemon.species > 0 then
        battle_data.player = {
            species = player_pokemon.species,
            level = player_pokemon.level,
            hp = {current = player_pokemon.current_hp, max = player_pokemon.max_hp},
            stats = {
                attack = player_pokemon.attack,
                defense = player_pokemon.defense,
                speed = player_pokemon.speed,
                sp_attack = player_pokemon.sp_attack,
                sp_defense = player_pokemon.sp_defense
            },
            moves = player_pokemon.moves,
            ability_slot = player_pokemon.ability_bit,
            nature = player_pokemon.nature,
            evs = player_pokemon.evs,
            ivs = player_pokemon.ivs,
            is_shiny = player_pokemon.is_shiny
        }
    end
    
    -- Read enemy Pokemon
    local enemy_pokemon = nil
    if is_wild then
        -- For wild battles, use the simplified wild Pokemon data
        local wild = read_wild_pokemon()
        if wild then
            enemy_pokemon = {
                species = wild.species,
                level = wild.level,
                hp = {current = wild.hp_current, max = wild.hp_current}, -- Approximate
                is_wild = true
            }
        end
    else
        -- For trainer battles, read from enemy active slot
        enemy_pokemon = read_pokemon_full(POKE_ADDR.enemy_active)
        if enemy_pokemon and enemy_pokemon.species > 0 then
            enemy_pokemon = {
                species = enemy_pokemon.species,
                level = enemy_pokemon.level,
                hp = {current = enemy_pokemon.current_hp, max = enemy_pokemon.max_hp},
                stats = {
                    attack = enemy_pokemon.attack,
                    defense = enemy_pokemon.defense,
                    speed = enemy_pokemon.speed,
                    sp_attack = enemy_pokemon.sp_attack,
                    sp_defense = enemy_pokemon.sp_defense
                },
                moves = enemy_pokemon.moves,
                ability_slot = enemy_pokemon.ability_bit,
                nature = enemy_pokemon.nature,
                is_shiny = enemy_pokemon.is_shiny,
                is_wild = false
            }
        end
    end
    
    -- Check if this is a new encounter
    if enemy_pokemon and enemy_pokemon.species ~= last_battle_state.enemy_species then
        battle_data.enemy = enemy_pokemon
        
        print(string.format("%s battle detected! Enemy: #%d Lv.%d", 
            battle_data.type, enemy_pokemon.species, enemy_pokemon.level))
        
        -- Send comprehensive battle data
        local json = to_json(battle_data)
        send_message("BattleUpdate|" .. json)
        print("Sent battle update to server")
        
        last_battle_state = {
            enemy_species = enemy_pokemon.species,
            is_trainer_battle = not is_wild
        }
    end
end

-- Check and send full party data
local function check_party()
    local party_count = read_byte(POKE_ADDR.party_count)
    if party_count > 0 and party_count <= 6 then
        local party = {}
        for i = 0, party_count - 1 do
            local pokemon = read_pokemon_full(POKE_ADDR.party_base + (i * PARTY_POKEMON_SIZE))
            if pokemon and pokemon.species > 0 and pokemon.species <= 386 then
                -- Prepare data for companion tool
                local party_member = {
                    species = pokemon.species,
                    level = pokemon.level,
                    hp = {current = pokemon.current_hp, max = pokemon.max_hp},
                    stats = {
                        attack = pokemon.attack,
                        defense = pokemon.defense,
                        speed = pokemon.speed,
                        sp_attack = pokemon.sp_attack,
                        sp_defense = pokemon.sp_defense
                    },
                    moves = pokemon.moves,
                    pp = pokemon.pp,
                    evs = pokemon.evs,
                    ivs = pokemon.ivs,
                    ability_slot = pokemon.ability_bit,
                    nature = pokemon.nature,
                    held_item = pokemon.held_item,
                    is_shiny = pokemon.is_shiny,
                    slot = i + 1
                }
                table.insert(party, party_member)
            end
        end
        return party
    end
    return nil
end

-- Send full party update with tier calculations
local function send_party_update()
    local party = check_party()
    if party and #party > 0 then
        -- Include tier rating request flag for server-side calculation
        local data = {
            party = party,
            request_tiers = true,  -- Server will calculate randomizer tiers
            game_progress = get_game_progress()  -- For tier weighting
        }
        local json = to_json(data)
        send_message("PartyUpdate|" .. json)
        print("Sent party update (" .. #party .. " Pokemon)")
    end
end

-- Initialize
print("========================================")
print("Pokemon Companion Connector v5.0 Enhanced")
print("========================================")
print("ROM: " .. gameinfo.getromname())
print("Features: Full decryption, tier support, enhanced battle detection")
print("========================================")
print("Note: Deprecation warnings about bit operations are normal")
print("This script uses modern Lua 5.3+ bitwise operators")

-- Initial connection
if not connect() then
    print("Failed to connect. Will retry every 5 seconds.")
end

-- Main loop
local party_update_timer = 0
local PARTY_UPDATE_INTERVAL = 300  -- Every 10 seconds

while true do
    -- Handle reconnection
    if not connected then
        if reconnect_timer <= 0 then
            if connect() then
                reconnect_timer = 0
                -- Send initial party data on reconnect
                send_party_update()
            else
                reconnect_timer = RECONNECT_DELAY
            end
        else
            reconnect_timer = reconnect_timer - 1
        end
    end
    
    -- Check for server messages
    if connected then
        local success, data = pcall(function()
            return connection:receive('*l')
        end)
        
        if success and data then
            print("Server: " .. data)
            -- Handle server commands if needed
            if data == "RequestParty" then
                send_party_update()
            end
        elseif not success and string.find(tostring(data), "closed") then
            print("Server disconnected")
            disconnect()
        end
    end
    
    -- Update battle state
    if connected then
        update_timer = update_timer + 1
        if update_timer >= UPDATE_INTERVAL then
            update_timer = 0
            check_battle_state()  -- Use enhanced battle checking
        end
        
        -- Also periodically update party
        party_update_timer = party_update_timer + 1
        if party_update_timer >= PARTY_UPDATE_INTERVAL then
            party_update_timer = 0
            send_party_update()
        end
    end
    
    -- GUI display
    local color = connected and 0xFF00FF00 or 0xFFFF0000
    local status = connected and "Connected" or "Disconnected"
    gui.pixelText(2, 2, "Companion: " .. status, color)
    
    if not connected and reconnect_timer > 0 then
        gui.pixelText(2, 12, string.format("Retry in %d", math.floor(reconnect_timer/60)), 0xFFFFFF00)
    elseif last_battle_state.enemy_species > 0 then
        local battle_type = last_battle_state.is_trainer_battle and "Trainer" or "Wild"
        gui.pixelText(2, 12, battle_type .. " Battle: #" .. last_battle_state.enemy_species, 0xFFFFFF00)
    else
        local party_count = read_byte(POKE_ADDR.party_count)
        if party_count > 0 and party_count <= 6 then
            gui.pixelText(2, 12, "Party: " .. party_count .. " Pokemon", 0xFF00FFFF)
        end
    end
    
    emu.frameadvance()
end
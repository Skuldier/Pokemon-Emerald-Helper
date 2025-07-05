-- Pokemon Companion Tool - Custom Addresses for Your ROM
-- Uses the addresses found by memory search

local socket = require("socket.core")

-- Configuration
local COMPANION_PORT = 17242
local tcp_socket = nil
local connected = false
local frame_count = 0
local last_send = 0

-- YOUR CUSTOM MEMORY ADDRESSES (found by search)
local MEMORY = {
    IN_BATTLE = 0x02022FEC,      -- Battle flag (standard)
    PARTY_PLAYER = 0x0200EB5C,   -- Your custom player address
    PARTY_ENEMY = 0x0200EBE8     -- Your custom enemy address
}

-- Pokemon data offsets (standard for all Gen 3)
local POKEMON_OFFSETS = {
    species = 0x20,
    level = 0x54,
    hp_current = 0x56,
    hp_max = 0x58,
    attack = 0x5A,
    defense = 0x5C,
    speed = 0x5E,
    sp_attack = 0x60,
    sp_defense = 0x62,
    moves = 0x2C
}

memory.usememorydomain("System Bus")

-- Connect to server
function connect()
    tcp_socket = socket.tcp()
    tcp_socket:settimeout(1)
    
    if tcp_socket:connect("localhost", COMPANION_PORT) then
        tcp_socket:settimeout(0)
        connected = true
        console.log("Connected to companion server!")
        return true
    else
        console.log("Failed to connect")
        return false
    end
end

-- Send JSON message
function send_json(msg_type, data)
    if not connected then return false end
    
    local json = '{"type":"' .. msg_type .. '","data":' .. table_to_json(data) .. '}\n'
    local ok = tcp_socket:send(json)
    
    if not ok then
        connected = false
        console.log("Disconnected")
        return false
    end
    return true
end

-- JSON encoder
function table_to_json(t)
    local json = "{"
    local first = true
    for k,v in pairs(t) do
        if not first then json = json .. "," end
        first = false
        json = json .. '"' .. k .. '":'
        if type(v) == "table" then
            json = json .. table_to_json(v)
        elseif type(v) == "string" then
            json = json .. '"' .. v .. '"'
        elseif type(v) == "boolean" then
            json = json .. (v and "true" or "false")
        else
            json = json .. tostring(v)
        end
    end
    return json .. "}"
end

-- Read Pokemon data
function read_pokemon(addr)
    local species = memory.read_u16_le(addr + POKEMON_OFFSETS.species)
    
    -- Validate
    if species == 0 or species > 411 then
        return nil
    end
    
    local level = memory.readbyte(addr + POKEMON_OFFSETS.level)
    if level == 0 or level > 100 then
        return nil
    end
    
    -- Read all data
    local pokemon = {
        species = species,
        level = level,
        hp = {
            current = memory.read_u16_le(addr + POKEMON_OFFSETS.hp_current),
            max = memory.read_u16_le(addr + POKEMON_OFFSETS.hp_max)
        },
        stats = {
            attack = memory.read_u16_le(addr + POKEMON_OFFSETS.attack),
            defense = memory.read_u16_le(addr + POKEMON_OFFSETS.defense),
            speed = memory.read_u16_le(addr + POKEMON_OFFSETS.speed),
            spAttack = memory.read_u16_le(addr + POKEMON_OFFSETS.sp_attack),
            spDefense = memory.read_u16_le(addr + POKEMON_OFFSETS.sp_defense)
        },
        moves = {}
    }
    
    -- Read moves
    for i = 0, 3 do
        local move = memory.read_u16_le(addr + POKEMON_OFFSETS.moves + (i * 2))
        if move > 0 and move < 500 then
            table.insert(pokemon.moves, move)
        end
    end
    
    return pokemon
end

-- Main frame handler
function on_frame()
    frame_count = frame_count + 1
    
    -- Reconnect if needed
    if not connected and frame_count % 300 == 0 then
        console.log("Reconnecting...")
        connect()
    end
    
    if not connected then return end
    
    -- Send data every 30 frames (0.5 seconds)
    if frame_count - last_send < 30 then return end
    last_send = frame_count
    
    -- Check if in battle
    local in_battle = memory.readbyte(MEMORY.IN_BATTLE) ~= 0
    
    if in_battle then
        -- Read Pokemon data
        local player = read_pokemon(MEMORY.PARTY_PLAYER)
        local enemy = read_pokemon(MEMORY.PARTY_ENEMY)
        
        if player and enemy then
            -- Send battle update
            send_json("battle_update", {
                in_battle = true,
                player = { active = player },
                enemy = { active = enemy }
            })
            
            -- Log occasionally for debugging
            if frame_count % 300 == 0 then
                console.log(string.format("Battle: Player %d vs Enemy %d", 
                    player.species, enemy.species))
            end
        else
            console.log("Failed to read Pokemon data")
        end
    else
        -- Not in battle - send heartbeat
        if frame_count % 120 == 0 then
            send_json("heartbeat", { in_battle = false })
        end
    end
end

-- Cleanup on exit
function on_exit()
    console.log("Shutting down...")
    if connected then
        send_json("disconnect", { reason = "script_stopped" })
        tcp_socket:close()
    end
end

-- Initialize
console.clear()
console.log("==============================================")
console.log("Pokemon Companion Tool - CUSTOM ADDRESSES")
console.log("==============================================")
console.log("")
console.log("Using addresses found by memory search:")
console.log(string.format("  Player: 0x%08X", MEMORY.PARTY_PLAYER))
console.log(string.format("  Enemy: 0x%08X", MEMORY.PARTY_ENEMY))
console.log("")

-- Verify system
if emu.getsystemid() ~= "GBA" then
    console.log("ERROR: This is for GBA only!")
    return
end

-- Connect
if connect() then
    console.log("Ready! Battle data will appear in companion tool.")
else
    console.log("Make sure server is running!")
end

-- Register handlers
event.onframestart(on_frame)
event.onexit(on_exit)

console.log("")
console.log("Enter a Pokemon battle to see data!")
-- Pokemon Companion Tool for BizHawk
-- Works alongside Archipelago without conflicts

local socket = require("socket.core")  -- This is what works!

-- Configuration
local COMPANION_PORT = 17242
local SEND_INTERVAL = 30  -- frames

-- State
local tcp_socket = nil
local connected = false
local frame_counter = 0
local last_send_frame = 0

-- Pokemon Emerald Memory Addresses
local MEMORY = {
    IN_BATTLE = 0x02022FEC,
    PARTY_PLAYER = 0x02024284,
    PARTY_ENEMY = 0x02024744
}

-- Simple JSON encoder
local function encode_json(t)
    if type(t) == "table" then
        local parts = {}
        local is_array = (#t > 0)
        
        if is_array then
            for i, v in ipairs(t) do
                table.insert(parts, encode_json(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(t) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. encode_json(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    elseif type(t) == "string" then
        return '"' .. t:gsub('"', '\\"') .. '"'
    elseif type(t) == "number" then
        return tostring(t)
    elseif type(t) == "boolean" then
        return t and "true" or "false"
    elseif t == nil then
        return "null"
    end
end

-- Connect to companion server
local function connect_to_companion()
    if tcp_socket then
        tcp_socket:close()
    end
    
    tcp_socket = socket.tcp()
    tcp_socket:settimeout(0.1)
    
    local result, err = tcp_socket:connect("localhost", COMPANION_PORT)
    
    if result or err == "timeout" then
        connected = true
        tcp_socket:settimeout(0)
        console.log("Connected to Pokemon Companion Tool on port " .. COMPANION_PORT)
        return true
    else
        console.log("Failed to connect to companion server: " .. (err or "unknown"))
        tcp_socket = nil
        connected = false
        return false
    end
end

-- Send message to companion server
local function send_message(msg_type, data)
    if not connected or not tcp_socket then
        return false
    end
    
    local message = {
        type = msg_type,
        data = data,
        timestamp = os.time()
    }
    
    local json_str = encode_json(message)
    local packet = tostring(#json_str) .. " " .. json_str
    
    local result, err = tcp_socket:send(packet)
    
    if not result then
        console.log("Send error, disconnecting: " .. (err or "unknown"))
        connected = false
        tcp_socket:close()
        tcp_socket = nil
        return false
    end
    
    return true
end

-- Read Pokemon data from memory
local function read_pokemon_data(base_address)
    -- Read species (2 bytes, little endian)
    local species = memory.read_u16_le(base_address + 0x20)
    
    if species == 0 or species > 500 then
        return nil
    end
    
    local pokemon = {
        species = species,
        level = memory.readbyte(base_address + 0x54),
        hp = {
            current = memory.read_u16_le(base_address + 0x56),
            max = memory.read_u16_le(base_address + 0x58)
        },
        stats = {
            attack = memory.read_u16_le(base_address + 0x5A),
            defense = memory.read_u16_le(base_address + 0x5C),
            speed = memory.read_u16_le(base_address + 0x5E),
            spAttack = memory.read_u16_le(base_address + 0x60),
            spDefense = memory.read_u16_le(base_address + 0x62)
        },
        nature = memory.readbyte(base_address + 0x64),
        held_item = memory.read_u16_le(base_address + 0x22),
        moves = {}
    }
    
    -- Read moves (4 moves, 2 bytes each)
    for i = 0, 3 do
        local move = memory.read_u16_le(base_address + 0x2C + i * 2)
        if move > 0 and move < 1000 then
            table.insert(pokemon.moves, move)
        end
    end
    
    return pokemon
end

-- Main frame callback
local function on_frame()
    frame_counter = frame_counter + 1
    
    -- Reconnect if needed (every 5 seconds)
    if not connected and frame_counter % 300 == 0 then
        console.log("Attempting to reconnect...")
        connect_to_companion()
    end
    
    -- Send data at intervals
    if connected and frame_counter - last_send_frame >= SEND_INTERVAL then
        last_send_frame = frame_counter
        
        -- Check if in battle
        local in_battle = memory.readbyte(MEMORY.IN_BATTLE)
        
        if in_battle ~= 0 then
            -- We're in battle, read Pokemon data
            local enemy_pokemon = read_pokemon_data(MEMORY.PARTY_ENEMY)
            local player_pokemon = read_pokemon_data(MEMORY.PARTY_PLAYER)
            
            if enemy_pokemon and player_pokemon then
                local battle_data = {
                    in_battle = true,
                    enemy = {
                        active = enemy_pokemon
                    },
                    player = {
                        active = player_pokemon
                    }
                }
                
                if send_message("battle_update", battle_data) then
                    -- Successfully sent
                end
            end
        else
            -- Not in battle, send heartbeat
            if frame_counter - last_send_frame >= SEND_INTERVAL * 4 then
                send_message("heartbeat", { in_battle = false })
            end
        end
    end
end

-- Cleanup function
local function cleanup()
    console.log("Pokemon Companion script stopping...")
    if tcp_socket then
        send_message("disconnect", { reason = "script_stopped" })
        tcp_socket:close()
        tcp_socket = nil
    end
end

-- Initialize
console.clear()
console.log("==============================================")
console.log("Pokemon Companion Tool v1.0")
console.log("==============================================")
console.log("This script runs alongside Archipelago")
console.log("Make sure the companion server is running on port " .. COMPANION_PORT)

-- Check system
if emu.getsystemid() ~= "GBA" then
    console.log("ERROR: This script is for GBA games only!")
    console.log("Current system: " .. emu.getsystemid())
    return
end

console.log("System check: OK (GBA)")

-- Initial connection attempt
if connect_to_companion() then
    console.log("Successfully connected to companion server!")
else
    console.log("Could not connect to companion server")
    console.log("Make sure the server is running (npm start)")
    console.log("Will retry every 5 seconds...")
end

-- Register callbacks
event.onframestart(on_frame)
event.onexit(cleanup)

console.log("Script is now running!")
console.log("Enter a Pokemon battle to see companion data")
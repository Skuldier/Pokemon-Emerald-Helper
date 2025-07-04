-- Pokemon Companion Connector for BizHawk
-- Final working version with proper memory domain handling

-- Load socket library
local socket = require("socket.core")

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
local last_enemy_species = 0
local EWRAM_OFFSET = 0x02000000

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

-- Pokemon Emerald Memory Addresses
local POKE_ADDR = {
    -- If using EWRAM domain, subtract offset. Otherwise use full address
    in_battle = 0x02022FEC - EWRAM_OFFSET,
    enemy_active = 0x02024744 - EWRAM_OFFSET,
    party_base = 0x02024284 - EWRAM_OFFSET,
}

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

-- Read Pokemon data
local function read_pokemon(base_addr)
    -- Read at two possible species offsets
    local species = read_u16(base_addr)
    if species == 0 or species > 500 then
        species = read_u16(base_addr + 0x20)
    end
    
    if species == 0 or species > 500 then
        return nil
    end
    
    return {
        species = species,
        level = read_byte(base_addr + 0x54),
        hp_current = read_u16(base_addr + 0x56),
        hp_max = read_u16(base_addr + 0x58),
        attack = read_u16(base_addr + 0x5A),
        defense = read_u16(base_addr + 0x5C),
        speed = read_u16(base_addr + 0x5E),
        sp_attack = read_u16(base_addr + 0x60),
        sp_defense = read_u16(base_addr + 0x62)
    }
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
    else
        return '"' .. tostring(t) .. '"'
    end
end

-- Check for battle
local function check_battle()
    -- Read enemy Pokemon
    local enemy = read_pokemon(POKE_ADDR.enemy_active)
    
    if enemy then
        -- In battle!
        if enemy.species ~= last_enemy_species then
            print("Battle detected! Enemy: #" .. enemy.species)
            last_enemy_species = enemy.species
            
            -- Read player's first Pokemon
            local player = read_pokemon(POKE_ADDR.party_base + 8)
            
            if player then
                local battle_data = {
                    player = player,
                    enemy = enemy
                }
                
                local json = to_json(battle_data)
                send_message("BattleUpdate|" .. json)
                print("Sent battle update to server")
            end
        end
    else
        -- Not in battle
        if last_enemy_species ~= 0 then
            print("Battle ended")
            send_message("BattleEnd")
            last_enemy_species = 0
        end
    end
end

-- Initialize
print("========================================")
print("Pokemon Companion Connector v3.0")
print("========================================")
print("ROM: " .. gameinfo.getromname())

-- Initial connection
if not connect() then
    print("Failed to connect. Will retry every 5 seconds.")
end

-- Main loop
while true do
    -- Handle reconnection
    if not connected then
        if reconnect_timer <= 0 then
            if connect() then
                reconnect_timer = 0
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
            check_battle()
        end
    end
    
    -- GUI display
    local color = connected and 0xFF00FF00 or 0xFFFF0000
    local status = connected and "Connected" or "Disconnected"
    gui.pixelText(2, 2, "Companion: " .. status, color)
    
    if not connected and reconnect_timer > 0 then
        gui.pixelText(2, 12, string.format("Retry in %d", math.floor(reconnect_timer/60)), 0xFFFFFF00)
    elseif last_enemy_species > 0 then
        gui.pixelText(2, 12, "In Battle: #" .. last_enemy_species, 0xFFFFFF00)
    end
    
    emu.frameadvance()
end
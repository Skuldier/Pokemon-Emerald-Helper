-- Pokemon Companion Connector for BizHawk
-- Enhanced with SNI connector patterns
-- ULTRATHINK v5.0 - Production Ready

-- Socket loading with fallback methods
local socket = nil
local socket_loaded = false

-- Method 1: Try standard require (if LuaSocket installed normally)
local function try_standard_socket()
    local success, sock = pcall(require, "socket")
    if success and sock.tcp then
        print("Socket loaded via standard require")
        return sock
    end
    return nil
end

-- Method 2: Try loadlib pattern from SNI connector
local function try_loadlib_socket()
    local function get_os()
        if package.config:sub(1,1) == "\\" then
            return "windows", "dll"
        else
            return "linux", "so"
        end
    end
    
    local the_os, ext = get_os()
    local paths = {
        "./socket." .. ext,
        "./socket/core." .. ext,
        "socket." .. ext,
        "socket/core." .. ext
    }
    
    for _, path in ipairs(paths) do
        local success, result = pcall(function()
            local loader = package.loadlib(path, "luaopen_socket_core")
            if loader then
                return loader()
            end
        end)
        if success and result then
            print("Socket loaded via loadlib from: " .. path)
            return result
        end
    end
    return nil
end

-- Try to load socket
socket = try_standard_socket() or try_loadlib_socket()
if socket then
    socket_loaded = true
else
    print("ERROR: Could not load socket library!")
    print("Please ensure LuaSocket is installed in BizHawk's Lua folder")
end

-- Configuration
local SERVER_HOST = os.getenv("POKEMON_COMPANION_HOST") or "127.0.0.1"
local SERVER_PORT = tonumber(os.getenv("POKEMON_COMPANION_PORT") or "17242")
local RECONNECT_BACKOFF = 600  -- 10 seconds at 60fps
local MAX_MESSAGES_PER_FRAME = 8

-- State
local connection = nil
local connected = false
local connection_backoff = 0
local companion_name = "BizHawk-" .. os.date("%H%M%S")

-- Memory domains
local memory_domain = "System Bus"
if not is_snes9x then
    memory.usememorydomain(memory_domain)
end

-- Pokemon memory addresses (Pokemon Emerald - adjust for your game)
local POKE_ADDR = {
    party_count = 0x02024284,
    party_data = 0x02024284 + 4,
    battle_data = 0x02024744,
    player_name = 0x02024C7C,
    money = 0x02024F28,
    badges = 0x02024F5C
}

-- Logging
local function log(message, level)
    level = level or "INFO"
    print(string.format("[%s] %s", level, message))
    
    if level == "ERROR" then
        gui.addmessage("Companion: " .. message)
    end
end

-- Message handling
local function send_message(...)
    if not connected or not connection then
        return false
    end
    
    local parts = {...}
    local message = table.concat(parts, "|") .. "\n"
    
    local success, err = pcall(function()
        connection:send(message)
    end)
    
    if not success then
        log("Send error: " .. tostring(err), "ERROR")
        return false
    end
    
    return true
end

-- Read Pokemon data and send update
local function send_pokemon_update()
    -- Read party count
    local party_count = memory.readbyte(POKE_ADDR.party_count)
    if party_count == nil or party_count == 0 or party_count > 6 then
        return
    end
    
    -- Read first Pokemon species
    local species_addr = POKE_ADDR.party_data
    local species = memory.read_u16_le(species_addr)
    
    -- Read battle status (simplified)
    local in_battle = memory.readbyte(POKE_ADDR.battle_data) > 0
    
    -- Send update
    send_message("PokemonData", 
        tostring(party_count),
        tostring(species),
        tostring(in_battle and 1 or 0),
        tostring(emu.framecount())
    )
end

-- Process incoming message
local function on_message(s)
    local parts = {}
    for part in string.gmatch(s, '([^|]+)') do
        parts[#parts + 1] = part
    end
    
    if #parts == 0 then return end
    
    local cmd = parts[1]
    
    if cmd == "Version" then
        send_message("Version", companion_name, "5.0", "BizHawk-Pokemon")
        
    elseif cmd == "Ping" then
        send_message("Pong", tostring(emu.framecount()))
        
    elseif cmd == "RequestData" then
        send_pokemon_update()
        
    elseif cmd == "Read" then
        -- Read memory: Read|address|length
        if #parts >= 3 then
            local addr = tonumber(parts[2])
            local length = tonumber(parts[3])
            if addr and length then
                local data = memory.readbyterange(addr, length)
                local hex_data = {}
                for i = 0, length - 1 do
                    table.insert(hex_data, string.format("%02x", data[i]))
                end
                send_message("ReadResponse", table.concat(hex_data))
            end
        end
        
    elseif cmd == "Write" then
        -- Write memory: Write|address|byte1|byte2|...
        if #parts >= 3 then
            local addr = tonumber(parts[2])
            if addr then
                for i = 3, #parts do
                    local value = tonumber(parts[i])
                    if value then
                        memory.writebyte(addr + i - 3, value)
                    end
                end
                send_message("WriteResponse", "OK")
            end
        end
        
    elseif cmd == "Message" then
        if parts[2] then
            gui.addmessage("Companion: " .. parts[2])
            print("Server message: " .. parts[2])
        end
        
    elseif cmd == "SetName" then
        if parts[2] then
            companion_name = parts[2]
            log("Name set to: " .. companion_name)
        end
        
    else
        log("Unknown command: " .. cmd, "WARN")
    end
end

-- Connection management
local function do_connect()
    if not socket_loaded then
        return false
    end
    
    if connection_backoff > 0 then
        connection_backoff = connection_backoff - 1
        return false
    end
    
    log("Connecting to Pokemon Companion at " .. SERVER_HOST .. ":" .. SERVER_PORT .. "...")
    
    local conn, err = socket.tcp()
    if not conn then
        log("Failed to create socket: " .. tostring(err), "ERROR")
        connection_backoff = RECONNECT_BACKOFF
        return false
    end
    
    -- Set socket options like SNI connector
    conn:setoption('keepalive', true)
    conn:setoption('tcp-nodelay', true)
    conn:settimeout(0.01)  -- 10ms timeout for connection
    
    local success, err = conn:connect(SERVER_HOST, SERVER_PORT)
    if err and err ~= "timeout" then
        log("Connection failed: " .. tostring(err), "ERROR")
        conn:close()
        connection_backoff = RECONNECT_BACKOFF
        return false
    end
    
    -- Connected!
    connection = conn
    connected = true
    connection_backoff = 0
    
    -- Set to non-blocking mode
    connection:settimeout(0)
    
    local ip, port = connection:getsockname()
    log("Connected to Pokemon Companion from " .. ip .. ":" .. port, "SUCCESS")
    
    -- Send initial handshake
    send_message("Hello", companion_name, "BizHawk", gameinfo.getromname())
    
    return true
end

local function do_disconnect()
    if connection then
        log("Disconnecting from Pokemon Companion...")
        pcall(function()
            send_message("Goodbye", companion_name)
            connection:close()
        end)
        connection = nil
    end
    connected = false
end

-- Main update loop (called every frame)
local frame_counter = 0
local function main_update()
    if not socket_loaded then
        return
    end
    
    -- Handle connection
    if not connected then
        do_connect()
        return
    end
    
    -- Process incoming messages (up to 8 per frame like SNI)
    local messages_processed = 0
    while messages_processed < MAX_MESSAGES_PER_FRAME do
        messages_processed = messages_processed + 1
        
        local s, status = connection:receive('*l')
        
        if status == 'timeout' then
            break  -- No more messages
        elseif status == 'closed' then
            log("Server closed connection", "WARN")
            do_disconnect()
            connection_backoff = RECONNECT_BACKOFF
            break
        elseif s then
            on_message(s)
        end
    end
    
    -- Send periodic updates (every 30 frames = 0.5 seconds)
    frame_counter = frame_counter + 1
    if frame_counter >= 30 then
        frame_counter = 0
        send_pokemon_update()
    end
end

-- GUI overlay
local function draw_status()
    local color = connected and 0xFF00FF00 or 0xFFFF0000
    local status = connected and "Connected" or "Disconnected"
    
    gui.pixelText(2, 2, "Companion: " .. status, color)
    
    if not socket_loaded then
        gui.pixelText(2, 12, "Socket not loaded!", 0xFFFFFF00)
    elseif not connected and connection_backoff > 0 then
        gui.pixelText(2, 12, string.format("Retry in %d", connection_backoff/60), 0xFFFFFF00)
    end
end

-- Cleanup on exit
local function on_exit()
    log("Pokemon Companion shutting down...")
    do_disconnect()
end

-- Initialize
print("========================================")
print("Pokemon Companion Connector v5.0")
print("Enhanced with SNI connector patterns")
print("========================================")

if not socket_loaded then
    print("ERROR: Socket library not available!")
    print("Please install LuaSocket in BizHawk's Lua folder")
    print("Download from: https://github.com/diegonehab/luasocket/releases")
else
    print("Socket library loaded successfully")
    print("Target server: " .. SERVER_HOST .. ":" .. SERVER_PORT)
end

-- Wait for ROM
if emu.getsystemid() == "NULL" then
    print("Waiting for ROM...")
    while emu.getsystemid() == "NULL" do
        emu.frameadvance()
    end
end

print("ROM: " .. gameinfo.getromname())
print("System: " .. emu.getsystemid())

-- Register events
event.onexit(on_exit)

-- Main loop
if emu.getsystemid() == "GB" or emu.getsystemid() == "GBC" or emu.getsystemid() == "SGB" then
    -- GB/GBC use vblank to avoid timing issues
    event.onmemoryexecute(function()
        main_update()
        draw_status()
    end, 0x40, "vblank", "System Bus")
else
    -- Other systems use frame end
    event.onframeend(function()
        main_update()
        draw_status()
    end)
end

-- Frame advance loop
while true do
    emu.frameadvance()
end
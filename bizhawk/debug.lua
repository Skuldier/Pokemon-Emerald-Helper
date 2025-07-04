-- Active Pokemon Memory Finder
-- This script actively searches for Pokemon in memory

print("Active Pokemon Memory Finder")
print("===========================")
print("This will scan memory for Pokemon-like structures")
print("Press B to begin scanning")
print("")

-- Common early-game Pokemon IDs
local common_pokemon = {
    252, 253, 254, -- Treecko line
    255, 256, 257, -- Torchic line
    258, 259, 260, -- Mudkip line
    261, 262,      -- Poochyena line
    263, 264,      -- Zigzagoon line
    265, 266, 267, 268, 269, -- Wurmple lines
    270, 271, 272, -- Lotad line
    273, 274, 275, -- Seedot line
    276, 277,      -- Taillow line
    278, 279,      -- Wingull line
    280, 281, 282, -- Ralts line
    283, 284,      -- Surskit line
    285, 286,      -- Shroomish line
}

-- Create lookup for quick checking
local is_common = {}
for _, id in ipairs(common_pokemon) do
    is_common[id] = true
end

-- Scan for Pokemon-like structures
local function scan_for_pokemon()
    print("\nScanning memory for Pokemon structures...")
    local found = {}
    
    -- Focus on WRAM area where game data is stored
    local scan_start = 0x02000000
    local scan_end = 0x02040000
    local step = 0x100  -- Check every 256 bytes
    
    for addr = scan_start, scan_end, step do
        -- Read potential species value
        local species = mainmemory.read_u16_le(addr)
        
        -- Check if it's a common Pokemon
        if is_common[species] then
            -- Verify it looks like a Pokemon structure
            -- Check multiple possible offsets
            local checks = {
                {species_off = 0, level_off = 0x54, hp_off = 0x56},
                {species_off = 0, level_off = 0x34, hp_off = 0x36},
                {species_off = -0x20, level_off = 0x34, hp_off = 0x36}
            }
            
            for _, offsets in ipairs(checks) do
                local level = mainmemory.readbyte(addr + offsets.level_off)
                local hp = mainmemory.read_u16_le(addr + offsets.hp_off)
                
                if level >= 2 and level <= 10 and hp > 0 and hp < 50 then
                    -- This looks like a valid early-game Pokemon!
                    table.insert(found, {
                        address = addr,
                        species = species,
                        level = level,
                        hp = hp,
                        offset_type = offsets
                    })
                    print(string.format("Found Pokemon #%d at 0x%08X (Lv.%d, HP:%d)", 
                        species, addr, level, hp))
                end
            end
        end
    end
    
    return found
end

-- Monitor specific address for changes
local function monitor_address(addr, name)
    local species = mainmemory.read_u16_le(addr)
    local species2 = mainmemory.read_u16_le(addr + 0x20)
    
    if species > 0 and species <= 500 then
        return string.format("%s: #%d", name, species)
    elseif species2 > 0 and species2 <= 500 then
        return string.format("%s+0x20: #%d", name, species2)
    else
        return nil
    end
end

-- Connect to server and send update
local function send_battle_update(enemy_addr, player_addr)
    -- Try to load socket
    local socket_ok, socket = pcall(require, "socket.core")
    if not socket_ok then
        print("Socket not available, skipping network update")
        return
    end
    
    -- Read Pokemon data
    local enemy_species = mainmemory.read_u16_le(enemy_addr)
    local player_species = mainmemory.read_u16_le(player_addr)
    
    if enemy_species > 0 and enemy_species <= 500 and 
       player_species > 0 and player_species <= 500 then
        print(string.format("Battle detected! Player #%d vs Enemy #%d", 
            player_species, enemy_species))
        print(string.format("Enemy at: 0x%08X", enemy_addr))
        print(string.format("Player at: 0x%08X", player_addr))
    end
end

-- Main state
local scanning = false
local found_pokemon = {}
local last_scan_frame = 0

-- Main loop
while true do
    local keys = input.get()
    
    -- Handle scanning
    if keys["B"] and not scanning then
        scanning = true
        found_pokemon = scan_for_pokemon()
        last_scan_frame = emu.framecount()
    elseif not keys["B"] then
        scanning = false
    end
    
    -- Display GUI
    local y = 10
    gui.pixelText(2, y, "Pokemon Memory Finder", 0xFFFFFF00)
    y = y + 10
    gui.pixelText(2, y, "Press B to scan for Pokemon", 0xFFFFFFFF)
    y = y + 20
    
    -- Show known addresses
    gui.pixelText(2, y, "Standard addresses:", 0xFF00FFFF)
    y = y + 10
    
    local checks = {
        {0x02024744, "Enemy1"},
        {0x020244EC, "Enemy2"},
        {0x02023BE4, "Battle1"},
        {0x02023C48, "Battle2"},
        {0x02024284 + 8, "Party1"}
    }
    
    for _, check in ipairs(checks) do
        local result = monitor_address(check[1], check[2])
        if result then
            gui.pixelText(2, y, result, 0xFF00FF00)
            y = y + 10
        end
    end
    
    -- Show found Pokemon
    if #found_pokemon > 0 then
        y = y + 10
        gui.pixelText(2, y, "Found Pokemon:", 0xFFFFFF00)
        y = y + 10
        
        for i = 1, math.min(5, #found_pokemon) do
            local p = found_pokemon[i]
            local current = mainmemory.read_u16_le(p.address)
            local color = (current == p.species) and 0xFF00FF00 or 0xFFFF0000
            gui.pixelText(2, y, string.format("0x%08X: #%d", p.address, current), color)
            y = y + 10
        end
    end
    
    -- Auto-detect battles
    local enemy_species = mainmemory.read_u16_le(0x02024744 + 0x20)
    if enemy_species > 0 and enemy_species <= 500 then
        gui.pixelText(200, 20, "BATTLE ACTIVE!", 0xFF00FF00)
        gui.pixelText(200, 30, "Enemy: #" .. enemy_species, 0xFF00FF00)
    end
    
    emu.frameadvance()
end
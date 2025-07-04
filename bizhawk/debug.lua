-- Warning-Free Pokemon Scanner
-- Strictly respects 32KB memory limit to avoid warnings

print("Warning-Free Pokemon Scanner")
print("===========================")
print("Memory range: 0x0000 - 0x7FFF")
print("No out-of-bounds reads!")
print("")

-- Constants
local MEM_START = 0x0000
local MEM_END = 0x7FFF
local MEM_SIZE = 0x8000

-- Strictly bounded read functions
local function read_byte(addr)
    if addr >= MEM_START and addr <= MEM_END then
        return mainmemory.readbyte(addr)
    end
    return nil
end

local function read_u16(addr)
    if addr >= MEM_START and addr <= MEM_END - 1 then
        return mainmemory.read_u16_le(addr)
    end
    return nil
end

-- Pokemon data for Gen 1/2
local pokemon_data = {
    -- Gen 1 internal IDs (different from Pokedex numbers!)
    [0x99] = "Bulbasaur",
    [0x09] = "Ivysaur",
    [0x9A] = "Venusaur",
    [0xB0] = "Charmander",
    [0xB2] = "Charmeleon",
    [0xB4] = "Charizard",
    [0xB1] = "Squirtle",
    [0xB3] = "Wartortle",
    [0x1C] = "Blastoise",
    [0x7B] = "Caterpie",
    [0x7C] = "Metapod",
    [0x7D] = "Butterfree",
    [0x70] = "Weedle",
    [0x71] = "Kakuna",
    [0x72] = "Beedrill",
    [0x24] = "Pidgey",
    [0x96] = "Pidgeotto",
    [0x97] = "Pidgeot",
    [0xA5] = "Rattata",
    [0xA6] = "Raticate",
    [0x05] = "Spearow",
    [0x23] = "Fearow",
    [0x6C] = "Ekans",
    [0x2D] = "Arbok",
    [0x54] = "Pikachu",
    [0x55] = "Raichu",
}

-- Quick scan function
local function quick_scan()
    print("Starting quick scan...")
    local results = {}
    
    -- Common Pokemon data locations
    local scan_areas = {
        {start = 0xD000, end_ = 0xDFFF, name = "WRAM Bank D"},
        {start = 0xC000, end_ = 0xCFFF, name = "WRAM Bank C"},
        {start = 0x0000, end_ = 0x3FFF, name = "ROM Bank 0"},
    }
    
    for _, area in ipairs(scan_areas) do
        print("Scanning " .. area.name .. "...")
        
        for addr = area.start, math.min(area.end_, MEM_END), 1 do
            local value = read_byte(addr)
            
            if value and pokemon_data[value] then
                -- Found a Pokemon ID!
                local next_bytes = {}
                for i = 1, 5 do
                    local b = read_byte(addr + i)
                    if b then
                        table.insert(next_bytes, b)
                    end
                end
                
                table.insert(results, {
                    address = addr,
                    value = value,
                    name = pokemon_data[value],
                    context = next_bytes
                })
                
                print(string.format("  Found %s (0x%02X) at 0x%04X", 
                    pokemon_data[value], value, addr))
            end
        end
    end
    
    return results
end

-- Pattern matching for Pokemon structures
local function find_patterns()
    print("\nSearching for Pokemon patterns...")
    local patterns = {}
    
    -- Look for level/HP patterns (common in Pokemon data)
    for addr = MEM_START, MEM_END - 10, 1 do
        local byte1 = read_byte(addr)
        local byte2 = read_byte(addr + 1)
        local byte3 = read_byte(addr + 2)
        
        if byte1 and byte2 and byte3 then
            -- Level pattern: value between 1-100
            if byte1 >= 1 and byte1 <= 100 then
                -- HP pattern: reasonable HP values
                if byte2 > 0 and byte2 <= 255 and byte3 <= byte2 then
                    table.insert(patterns, {
                        address = addr,
                        level = byte1,
                        hp_current = byte3,
                        hp_max = byte2,
                        type = "Level/HP"
                    })
                end
            end
        end
    end
    
    return patterns
end

-- Main execution
print("Press B to start quick scan")
print("Press A to find patterns")
print("Press X to monitor memory")

local mode = "idle"
local scan_results = {}
local pattern_results = {}
local monitor_addr = 0xD000

while true do
    local keys = input.get()
    
    -- Handle input
    if keys["B"] and mode == "idle" then
        mode = "scanning"
        scan_results = quick_scan()
        mode = "results"
    elseif keys["A"] and mode == "idle" then
        mode = "patterns"
        pattern_results = find_patterns()
    elseif keys["X"] then
        mode = "monitor"
    elseif keys["Start"] then
        mode = "idle"
    end
    
    -- Update monitor address
    if mode == "monitor" then
        if keys["Up"] then monitor_addr = math.max(MEM_START, monitor_addr - 16) end
        if keys["Down"] then monitor_addr = math.min(MEM_END - 16, monitor_addr + 16) end
        if keys["Left"] then monitor_addr = math.max(MEM_START, monitor_addr - 1) end
        if keys["Right"] then monitor_addr = math.min(MEM_END, monitor_addr + 1) end
    end
    
    -- Display
    gui.drawBox(0, 0, 256, 224, 0x80000000, 0x80000000)
    
    local y = 2
    gui.pixelText(2, y, "Warning-Free Scanner - " .. mode, 0xFFFFFF00)
    y = y + 10
    
    if mode == "idle" then
        gui.pixelText(2, y, "B=Scan A=Patterns X=Monitor", 0xFF888888)
    elseif mode == "results" then
        gui.pixelText(2, y, "Found Pokemon:", 0xFF00FF00)
        y = y + 10
        
        for i = 1, math.min(10, #scan_results) do
            local r = scan_results[i]
            gui.pixelText(2, y, string.format("0x%04X: %s", r.address, r.name), 0xFF00FFFF)
            y = y + 10
        end
        
        if #scan_results > 10 then
            gui.pixelText(2, y, "... and " .. (#scan_results - 10) .. " more", 0xFF888888)
        end
    elseif mode == "patterns" then
        gui.pixelText(2, y, "Found Patterns:", 0xFF00FF00)
        y = y + 10
        
        for i = 1, math.min(8, #pattern_results) do
            local p = pattern_results[i]
            gui.pixelText(2, y, string.format("0x%04X: Lv.%d HP:%d/%d", 
                p.address, p.level, p.hp_current, p.hp_max), 0xFF00FFFF)
            y = y + 10
        end
    elseif mode == "monitor" then
        gui.pixelText(2, y, string.format("Monitor: 0x%04X", monitor_addr), 0xFF00FF00)
        y = y + 10
        
        -- Show 8x8 grid of bytes
        for row = 0, 7 do
            local x = 2
            for col = 0, 7 do
                local addr = monitor_addr + (row * 8) + col
                if addr <= MEM_END then
                    local value = read_byte(addr)
                    if value then
                        local color = 0xFFFFFFFF
                        if pokemon_data[value] then color = 0xFF00FFFF end
                        gui.pixelText(x, y, string.format("%02X", value), color)
                    end
                end
                x = x + 20
            end
            y = y + 10
        end
        
        y = y + 10
        gui.pixelText(2, y, "Use D-Pad to navigate", 0xFF888888)
    end
    
    -- Memory info
    gui.pixelText(180, 2, "Mem: 32KB", 0xFF888888)
    gui.pixelText(180, 12, "0x0000-0x7FFF", 0xFF888888)
    
    emu.frameadvance()
end
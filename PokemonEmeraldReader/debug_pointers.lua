-- debug_pointers.lua
-- Debug script to find save data in patched ROMs

local Memory = require("Memory")

console.clear()
console.log("=== Pokemon Emerald Save Data Debug ===\n")

-- Check standard IWRAM pointers
console.log("Checking IWRAM pointers...")
local pointers = {
    {addr = 0x03005008, name = "gSaveBlock1"},
    {addr = 0x0300500C, name = "gSaveBlock2"},
    {addr = 0x03004360, name = "gPlayerParty"},
    {addr = 0x030045C0, name = "gEnemyParty"},
    {addr = 0x03005D94, name = "gGameStatus"},
    {addr = 0x03005D90, name = "gSaveFileStatus"}
}

for _, ptr in ipairs(pointers) do
    local value = Memory.read_u32_le(ptr.addr)
    if value then
        console.log(string.format("%s (0x%08X): 0x%08X", ptr.name, ptr.addr, value))
        
        -- Check if it points to valid EWRAM
        if value >= 0x02000000 and value < 0x02040000 then
            console.log("  ✓ Points to valid EWRAM")
            
            -- Try to read some data
            local test = Memory.read_u32_le(value)
            if test then
                console.log(string.format("  Data at pointer: 0x%08X", test))
            end
        else
            console.log("  ✗ Invalid pointer")
        end
    else
        console.log(string.format("%s: Failed to read", ptr.name))
    end
    console.log("")
end

-- Search for party count pattern
console.log("\nSearching for party data patterns...")
console.log("Looking for party count (1-6) followed by Pokemon data...\n")

-- Search in common EWRAM areas
local searchAreas = {
    {start = 0x02024000, size = 0x4000, name = "Lower EWRAM"},
    {start = 0x02020000, size = 0x4000, name = "Mid EWRAM"},
    {start = 0x0202C000, size = 0x4000, name = "Upper EWRAM"}
}

for _, area in ipairs(searchAreas) do
    console.log("Searching " .. area.name .. "...")
    
    for addr = area.start, area.start + area.size - 4, 4 do
        local count = Memory.read_u32_le(addr)
        
        -- Look for valid party count (1-6)
        if count and count >= 1 and count <= 6 then
            -- Check if next data looks like Pokemon (personality value)
            local personality = Memory.read_u32_le(addr + 4)
            if personality and personality > 0 and personality < 0xFFFFFFFF then
                -- Check for reasonable stats
                local hp = Memory.read_u16_le(addr + 4 + 86)
                local maxHp = Memory.read_u16_le(addr + 4 + 88)
                
                if hp and maxHp and hp <= maxHp and maxHp > 0 and maxHp < 1000 then
                    console.log(string.format("\n✓ Possible party found at 0x%08X!", addr))
                    console.log(string.format("  Count: %d", count))
                    console.log(string.format("  First Pokemon HP: %d/%d", hp, maxHp))
                    
                    -- Try to read species
                    local species = Memory.read_u16_le(addr + 4 + 32)
                    if species and species > 0 and species < 500 then
                        console.log(string.format("  Species ID: %d", species))
                    end
                end
            end
        end
    end
end

-- Check for save file signature
console.log("\n\nChecking for save file signature...")
local saveAreas = {
    {addr = 0x02025734, name = "Vanilla SaveBlock1"},
    {addr = 0x02024EA4, name = "Vanilla SaveBlock2"}
}

for _, save in ipairs(saveAreas) do
    local data = Memory.readbytes(save.addr, 16)
    if data then
        local hasData = false
        for i = 1, 16 do
            if data[i] ~= 0 and data[i] ~= 0xFF then
                hasData = true
                break
            end
        end
        
        if hasData then
            console.log(string.format("✓ Data found at %s (0x%08X)", save.name, save.addr))
            
            -- Try to read party count at expected offset
            local partyCount = Memory.read_u32_le(save.addr + 0x234)
            if partyCount and partyCount >= 0 and partyCount <= 6 then
                console.log(string.format("  Party count at +0x234: %d", partyCount))
            end
        else
            console.log(string.format("✗ No data at %s", save.name))
        end
    end
end

console.log("\n=== Debug Complete ===")
console.log("\nIf no save data was found:")
console.log("1. Make sure you've loaded a save file")
console.log("2. Make sure you're in-game (not at title screen)")
console.log("3. Your patched ROM may use different memory layout")
console.log("\nPress any key to exit...")

while true do
    if next(input.get()) then break end
    emu.frameadvance()
end
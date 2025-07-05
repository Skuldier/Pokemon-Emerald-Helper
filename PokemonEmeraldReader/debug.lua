-- find_money.lua
-- Search for $3000 near player data

local Memory = require("Memory")

console.clear()
console.log("=== Searching for Money $3000 ===\n")

local PLAYER_START = 0x02025C72  -- Found player data start
local TARGET_MONEY = 3000        -- Your actual money

console.log(string.format("Player data starts at: 0x%08X", PLAYER_START))
console.log(string.format("Looking for money value: $%d (0x%08X)", TARGET_MONEY, TARGET_MONEY))
console.log("\nSearching nearby areas...\n")

-- Search around player data
for offset = 0, 0x600, 4 do
    local addr = PLAYER_START + offset
    local value = Memory.read_u32_le(addr)
    
    if value == TARGET_MONEY then
        console.log(string.format("✓ Found $3000 at offset +0x%03X (address: 0x%08X)", offset, addr))
        
        -- Show surrounding values to verify
        console.log("\n  Nearby values:")
        for i = -8, 8, 4 do
            local nearAddr = addr + i
            local nearVal = Memory.read_u32_le(nearAddr)
            if nearVal then
                console.log(string.format("    [%+3d] 0x%08X: %d", i, nearAddr, nearVal))
            end
        end
    end
end

-- Also check if money is stored as 16-bit
console.log("\n\nChecking 16-bit values...")
for offset = 0, 0x600, 2 do
    local addr = PLAYER_START + offset
    local value = Memory.read_u16_le(addr)
    
    if value == TARGET_MONEY then
        console.log(string.format("✓ Found $3000 (16-bit) at offset +0x%03X (address: 0x%08X)", offset, addr))
    end
end

console.log("\n=== Search Complete ===")
console.log("\nPress any key to exit...")

while true do
    if next(input.get()) then break end
    emu.frameadvance()
end
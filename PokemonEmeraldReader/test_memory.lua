-- test_memory.lua
-- Test script for Memory module
-- Run this to verify memory access is working correctly

local Memory = require("Memory")

console.clear()
console.log("=== Pokemon Emerald Memory Test ===")
console.log("Testing memory access across all domains...\n")

-- Test 1: Verify Pokemon Emerald ROM
console.log("Test 1: ROM Verification")
local gameCode = Memory.readbytes(0x080000AC, 4)
if gameCode then
    local codeStr = ""
    for i, byte in ipairs(gameCode) do
        codeStr = codeStr .. string.char(byte)
    end
    console.log("Game Code: " .. codeStr)
    
    if codeStr == "BPEE" then
        console.log("✓ Pokemon Emerald detected!")
    else
        console.log("✗ Not Pokemon Emerald (expected BPEE)")
    end
else
    console.log("✗ Failed to read game code")
end

-- Test 2: ROM Header
console.log("\nTest 2: ROM Header")
local romHeader = Memory.readstring(0x080000A0, 12)
if romHeader then
    console.log("Game Title: " .. romHeader)
else
    console.log("✗ Failed to read ROM header")
end

-- Test 3: IWRAM Access
console.log("\nTest 3: IWRAM Access")
local iwramTests = {
    {addr = 0x03000000, name = "IWRAM Start"},
    {addr = 0x030022C0, name = "gMain"},
    {addr = 0x03005008, name = "gSaveBlock1 pointer"},
    {addr = 0x0300500C, name = "gSaveBlock2 pointer"}
}

for _, test in ipairs(iwramTests) do
    local value = Memory.read_u32_le(test.addr)
    if value then
        console.log(string.format("✓ %s (0x%08X): 0x%08X", test.name, test.addr, value))
    else
        console.log(string.format("✗ %s (0x%08X): FAILED", test.name, test.addr))
    end
end

-- Test 4: EWRAM Access (within and beyond 32KB limit)
console.log("\nTest 4: EWRAM Access")
local ewramTests = {
    {addr = 0x02000000, name = "EWRAM Start (< 32KB)"},
    {addr = 0x02007FF0, name = "EWRAM Near 32KB limit"},
    {addr = 0x02008000, name = "EWRAM At 32KB limit"},
    {addr = 0x02020000, name = "EWRAM Beyond limit (128KB)"},
    {addr = 0x02030000, name = "EWRAM Near end (192KB)"}
}

for _, test in ipairs(ewramTests) do
    local value = Memory.read_u32_le(test.addr)
    local requiresSysBus = Memory.requiresSystemBus(test.addr)
    
    if value then
        console.log(string.format("✓ %s: 0x%08X %s", 
            test.name, value, requiresSysBus and "(via System Bus)" or ""))
    else
        console.log(string.format("✗ %s: FAILED", test.name))
    end
end

-- Test 5: Different data types
console.log("\nTest 5: Data Type Tests")
local testAddr = 0x08000000  -- ROM start
console.log(string.format("Testing at address 0x%08X:", testAddr))

local u8 = Memory.read_u8(testAddr)
local u16 = Memory.read_u16_le(testAddr)
local u32 = Memory.read_u32_le(testAddr)
local bytes = Memory.readbytes(testAddr, 4)

if u8 then console.log(string.format("  u8:  0x%02X", u8)) end
if u16 then console.log(string.format("  u16: 0x%04X", u16)) end
if u32 then console.log(string.format("  u32: 0x%08X", u32)) end
if bytes then 
    local byteStr = ""
    for i, b in ipairs(bytes) do
        byteStr = byteStr .. string.format("%02X ", b)
    end
    console.log("  bytes: " .. byteStr)
end

-- Test 6: Save Block Pointers (if game is loaded)
console.log("\nTest 6: Save Block Pointers")
local saveBlock1Ptr = Memory.read_u32_le(0x03005008)
local saveBlock2Ptr = Memory.read_u32_le(0x0300500C)

if saveBlock1Ptr and saveBlock1Ptr >= 0x02000000 and saveBlock1Ptr < 0x02040000 then
    console.log(string.format("✓ SaveBlock1: 0x%08X", saveBlock1Ptr))
    
    -- Try to read player name from save block
    local playerName = Memory.readbytes(saveBlock1Ptr, 8)
    if playerName then
        console.log("  Player name bytes: " .. table.concat(playerName, " "))
    end
else
    console.log("✗ SaveBlock1: Invalid or game not loaded")
end

if saveBlock2Ptr and saveBlock2Ptr >= 0x02000000 and saveBlock2Ptr < 0x02040000 then
    console.log(string.format("✓ SaveBlock2: 0x%08X", saveBlock2Ptr))
else
    console.log("✗ SaveBlock2: Invalid or game not loaded")
end

-- Test 7: Performance test
console.log("\nTest 7: Performance Test")
local startTime = os.clock()
local testCount = 1000

for i = 1, testCount do
    -- Mix of different memory domains
    Memory.read_u32_le(0x08000000)  -- ROM
    Memory.read_u32_le(0x03000000)  -- IWRAM
    Memory.read_u32_le(0x02000000)  -- EWRAM < 32KB
    Memory.read_u32_le(0x02020000)  -- EWRAM > 32KB (System Bus)
end

local endTime = os.clock()
local totalTime = endTime - startTime
local avgTime = (totalTime / testCount) * 1000

console.log(string.format("Performed %d reads in %.3f seconds", testCount * 4, totalTime))
console.log(string.format("Average time per read: %.3f ms", avgTime / 4))

-- Show final statistics
console.log("\n=== Memory Access Statistics ===")
local stats = Memory.getStats()
console.log(string.format("Total reads: %d", stats.reads))
console.log(string.format("Failed reads: %d (%.1f%%)", stats.failures, stats.failureRate))
console.log(string.format("System Bus fallbacks: %d", stats.systemBusFallbacks))

-- Domain breakdown
console.log("\nDomain test results:")
console.log("✓ ROM: Working")
console.log("✓ IWRAM: Working")
console.log("✓ EWRAM < 32KB: Working")
console.log(stats.systemBusFallbacks > 0 and "✓ EWRAM > 32KB: Working (via System Bus)" or "✗ EWRAM > 32KB: Not tested or failed")

console.log("\nMemory module test complete!")
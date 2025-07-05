-- debug_and_fix_pointers.lua
-- Debug why battle functions aren't loading and fix it

console.clear()
console.log("=== Debugging Pointers Module ===\n")

-- First, let's see what's actually in the Pointers module
local Pointers = require("Pointers")

console.log("1. Checking what's in Pointers module:")
console.log("   Type: " .. type(Pointers))

-- List all functions in Pointers
console.log("\n2. Functions found in Pointers:")
local count = 0
for k, v in pairs(Pointers) do
    if type(v) == "function" then
        console.log("   - " .. k)
        count = count + 1
    end
end
console.log("   Total functions: " .. count)

-- Check for addresses
console.log("\n3. Checking addresses table:")
if Pointers.addresses then
    console.log("   ✓ addresses table exists")
    console.log("   - gBattleTypeFlags = " .. (Pointers.addresses.gBattleTypeFlags and string.format("0x%08X", Pointers.addresses.gBattleTypeFlags) or "nil"))
else
    console.log("   ✗ addresses table missing!")
end

-- Now let's read the actual file to see what's in it
console.log("\n4. Reading Pointers.lua file directly:")
local file = io.open("Pointers.lua", "r")
if not file then
    -- Try other locations
    local paths = {"./Pointers.lua", "PokemonEmeraldReader/Pointers.lua", "../Pointers.lua"}
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then
            console.log("   Found at: " .. path)
            break
        end
    end
end

if file then
    local content = file:read("*all")
    file:close()
    
    -- Check for function definitions
    local hasBattleState = content:find("function Pointers%.getBattleState")
    local hasEnemyParty = content:find("function Pointers%.getEnemyPartyAddress")
    local hasReturn = content:find("return Pointers")
    
    console.log("   File contains getBattleState: " .. (hasBattleState and "YES" or "NO"))
    console.log("   File contains getEnemyPartyAddress: " .. (hasEnemyParty and "YES" or "NO"))
    console.log("   File has 'return Pointers': " .. (hasReturn and "YES" or "NO"))
    
    if hasReturn then
        local returnPos = content:find("return Pointers")
        local battlePos = hasBattleState or 999999
        if battlePos > returnPos then
            console.log("\n   ⚠️ PROBLEM FOUND: Battle functions are AFTER the return statement!")
        end
    end
else
    console.log("   ✗ Could not find Pointers.lua file!")
end

console.log("\n=== Attempting Fix ===")

-- Let's manually add the functions to the loaded module
console.log("Adding functions directly to loaded module...")

-- First ensure we have Memory module
local Memory = require("Memory")

-- Add bitwise compatibility
local band = _VERSION >= "Lua 5.3" and function(a,b) return a & b end or bit.band

-- Add getBattleState
Pointers.getBattleState = function()
    local battleFlags = Memory.read_u16_le(Pointers.addresses.gBattleTypeFlags or 0x02022FEC)
    if not battleFlags or battleFlags == 0 then
        return nil  -- Not in battle
    end
    
    return {
        inBattle = true,
        isWildBattle = band(battleFlags, 0x01) ~= 0,
        isTrainerBattle = band(battleFlags, 0x08) ~= 0,
        isDoubleBattle = band(battleFlags, 0x02) ~= 0,
        flags = battleFlags
    }
end

-- Add getEnemyPartyAddress
Pointers.getEnemyPartyAddress = function()
    -- Enemy party is at fixed offset from player party
    local playerParty = Pointers.getPartyAddress and Pointers.getPartyAddress()
    if not playerParty then return nil end
    
    -- Enemy party is typically 0x4C0 bytes after player party
    return playerParty + 0x4C0
end

-- Also fix the battle address if needed
if Pointers.addresses and Pointers.addresses.gBattleTypeFlags == 0x030042DC then
    console.log("Fixing gBattleTypeFlags address...")
    Pointers.addresses.gBattleTypeFlags = 0x02022FEC
end

console.log("✓ Functions added to loaded module")

-- Test if they work now
console.log("\n=== Testing Fixed Functions ===")
console.log("getBattleState exists: " .. (Pointers.getBattleState and "YES" or "NO"))
console.log("getEnemyPartyAddress exists: " .. (Pointers.getEnemyPartyAddress and "YES" or "NO"))

if Pointers.getBattleState then
    local state = Pointers.getBattleState()
    if state then
        console.log("Battle state: In battle")
    else
        console.log("Battle state: Not in battle")
    end
end

console.log("\n=== Fix Complete ===")
console.log("The functions are now available in memory.")
console.log("However, you should still update Pointers.lua file to make this permanent.")
-- test_battle_functions.lua
-- Quick test to verify battle functions exist

console.clear()
console.log("=== Testing Battle Functions ===\n")

-- Load modules
local Memory = require("Memory")
local Pointers = require("Pointers")

-- Check if functions exist
console.log("Checking Pointers module:")
console.log("- getBattleState: " .. (Pointers.getBattleState and "✓ Found" or "✗ MISSING"))
console.log("- getEnemyPartyAddress: " .. (Pointers.getEnemyPartyAddress and "✓ Found" or "✗ MISSING"))

-- Check if battle addresses exist
console.log("\nChecking battle addresses:")
console.log("- gBattleTypeFlags: " .. (Pointers.addresses.gBattleTypeFlags and string.format("0x%08X", Pointers.addresses.gBattleTypeFlags) or "MISSING"))

-- Try calling getBattleState
if Pointers.getBattleState then
    console.log("\nTesting getBattleState():")
    local state = Pointers.getBattleState()
    if state then
        console.log("  In battle: YES")
        console.log("  Wild: " .. (state.isWildBattle and "YES" or "NO"))
        console.log("  Trainer: " .. (state.isTrainerBattle and "YES" or "NO"))
    else
        console.log("  Not in battle")
    end
else
    console.log("\n❌ Cannot test - getBattleState is missing!")
end

console.log("\n=== Test Complete ===")
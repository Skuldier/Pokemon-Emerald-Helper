-- run_fixed.lua
-- Fixed launcher for Pokemon Emerald Memory Reader with Battle Display

-- Set up module path
package.path = package.path .. ";./?.lua"

-- Clear console
console.clear()
console.log("Starting Pokemon Emerald Memory Reader...")
console.log("Version 1.1 - Now with Battle Display!")

-- Load all modules first
local modules_loaded = true
local required_modules = {"Memory", "ROMData", "Pointers", "PokemonReader", "BattleDisplay"}

console.log("\nChecking required modules:")
for _, module in ipairs(required_modules) do
    local success, err = pcall(require, module)
    if not success then
        console.log("✗ ERROR: Failed to load " .. module .. ".lua")
        console.log("  " .. tostring(err))
        modules_loaded = false
        break
    else
        console.log("✓ " .. module .. " loaded successfully")
    end
end

if not modules_loaded then
    console.log("\nMake sure all required files are in the same directory:")
    console.log("- Memory.lua")
    console.log("- Pointers.lua") 
    console.log("- ROMData.lua")
    console.log("- PokemonReader.lua")
    console.log("- BattleDisplay.lua")
    console.log("- main.lua")
    console.log("\nPress any key to exit...")
    
    while true do
        if next(input.get()) then break end
        emu.frameadvance()
    end
    return
end

console.log("\nAll modules loaded successfully!")

-- Test that battle functions exist
local Pointers = require("Pointers")
if not Pointers.getBattleState then
    console.log("\n⚠️  WARNING: getBattleState function not found in Pointers module!")
    console.log("The battle display features may not work properly.")
    console.log("Make sure Pointers.lua has been updated with the latest version.")
end

-- Now load AND EXECUTE main.lua
console.log("\nStarting main program...\n")
dofile("main.lua")
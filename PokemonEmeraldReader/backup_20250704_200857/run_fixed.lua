-- run_fixed.lua
-- Fixed launcher for Pokemon Emerald Memory Reader

-- Set up module path
package.path = package.path .. ";./?.lua"

-- Clear console
console.clear()
console.log("Starting Pokemon Emerald Memory Reader...")

-- Load all modules first
local modules_loaded = true
local required_modules = {"Memory", "ROMData", "Pointers", "PokemonReader"}

for _, module in ipairs(required_modules) do
    local success, err = pcall(require, module)
    if not success then
        console.log("ERROR: Failed to load " .. module .. ".lua")
        console.log(tostring(err))
        modules_loaded = false
        break
    end
end

if not modules_loaded then
    console.log("\nMake sure all required files are in the same directory:")
    console.log("- Memory.lua")
    console.log("- Pointers.lua") 
    console.log("- ROMData.lua")
    console.log("- PokemonReader.lua")
    console.log("- main.lua")
    console.log("\nPress any key to exit...")
    
    while true do
        if next(input.get()) then break end
        emu.frameadvance()
    end
    return
end

-- Now load AND EXECUTE main.lua
dofile("main.lua")
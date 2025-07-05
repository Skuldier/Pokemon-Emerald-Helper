-- run.lua
-- Simple launcher for Pokemon Emerald Memory Reader
-- Load this file in BizHawk to start the tool

-- Set up module path (adjust if your files are in a different location)
package.path = package.path .. ";./?.lua"

-- Clear console
console.clear()

-- Try to load and run main
local success, err = pcall(function()
    require("main")
end)

if not success then
    console.log("=== STARTUP ERROR ===")
    console.log(tostring(err))
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
end
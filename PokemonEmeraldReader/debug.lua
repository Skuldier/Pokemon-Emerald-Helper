-- debug.lua
-- Debug launcher to find out why nothing is showing

console.clear()
console.log("=== DEBUG MODE ===")
console.log("Starting Pokemon Emerald Memory Reader Debug...")

-- Check if we can even print
console.log("1. Console output is working")

-- Check module path
console.log("2. Module path: " .. package.path)

-- Try to load each module one by one
local modules = {"Memory", "Pointers", "ROMData", "PokemonReader"}
local loaded = {}

for i, modname in ipairs(modules) do
    console.log(string.format("3.%d. Loading %s...", i, modname))
    local success, result = pcall(require, modname)
    if success then
        console.log("     ✓ Loaded successfully")
        loaded[modname] = result
    else
        console.log("     ✗ ERROR: " .. tostring(result))
        console.log("     Script stopping here.")
        return
    end
end

console.log("4. All modules loaded!")

-- Try to run basic Memory test
console.log("5. Testing Memory module...")
if loaded.Memory then
    local testRead = loaded.Memory.read_u32_le(0x08000000)
    if testRead then
        console.log("   ✓ Memory read successful: " .. string.format("0x%08X", testRead))
    else
        console.log("   ✗ Memory read failed")
    end
end

-- Check if ROM is loaded
console.log("6. Checking if ROM is loaded...")
local gameCode = loaded.Memory.readbytes(0x080000AC, 4)
if gameCode then
    local codeStr = ""
    for i, byte in ipairs(gameCode) do
        if byte then
            codeStr = codeStr .. string.char(byte)
        end
    end
    console.log("   Game code: " .. codeStr)
else
    console.log("   ✗ Could not read game code - is a ROM loaded?")
end

-- Try to load main
console.log("7. Loading main.lua...")
local success, err = pcall(require, "main")
if not success then
    console.log("   ✗ ERROR loading main.lua:")
    console.log("   " .. tostring(err))
else
    console.log("   ✓ Main loaded successfully")
end

console.log("\n=== DEBUG COMPLETE ===")
console.log("If you see this, the basic system is working.")
console.log("Check for errors above.")
console.log("\nPress any key to exit debug mode...")

-- Wait for input
while true do
    if next(input.get()) then break end
    emu.frameadvance()
end
-- simple_test.lua
-- Absolute bare minimum test

console.clear()
console.log("SIMPLE TEST STARTING")
console.log("Can you see this message?")
console.log("Frame count: " .. emu.framecount())

-- Test loop
for i = 1, 5 do
    console.log("Frame " .. i)
    emu.frameadvance()
end

console.log("TEST COMPLETE - If you see this, Lua is working")
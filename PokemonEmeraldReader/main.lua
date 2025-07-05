-- main.lua
-- Pokemon Emerald Memory Reader for BizHawk
-- Overcomes the 32KB EWRAM limitation using hybrid ROM/RAM approach

-- Load modules
local Memory = require("Memory")
local ROMData = require("ROMData")
local Pointers = require("Pointers")
local PokemonReader = require("PokemonReader")

-- Optional JSON library for external output
local hasJson, json = pcall(require, "json")

-- Configuration
local Config = {
    -- Update intervals (in frames)
    updateInterval = 30,        -- Update display every 0.5 seconds (30 frames)
    fullUpdateInterval = 300,   -- Full update every 5 seconds
    
    -- External output
    enableExternalOutput = false,
    outputFile = "pokemon_data.json",
    
    -- Display options
    showDetailedStats = true,
    showMoves = true,
    showIVsEVs = false,
    
    -- Performance
    cacheLifetime = 300,        -- 5 seconds
}

-- State tracking
local State = {
    frameCount = 0,
    lastUpdate = 0,
    lastFullUpdate = 0,
    isInitialized = false,
    
    -- Current data
    party = nil,
    playerInfo = nil,
    
    -- Statistics
    startTime = os.clock(),
    totalReads = 0,
}

-- Initialize the system
function init()
    console.clear()
    console.log("==============================================")
    console.log("Pokemon Emerald Memory Reader v1.0")
    console.log("==============================================")
    console.log("Initializing...")
    
    -- Verify Pokemon Emerald
    local gameCode = Memory.readbytes(0x080000AC, 4)
    if not gameCode then
        console.log("ERROR: Failed to read ROM")
        return false
    end
    
    local codeStr = ""
    for i, byte in ipairs(gameCode) do
        codeStr = codeStr .. string.char(byte)
    end
    
    if codeStr ~= "BPEE" then
        console.log("ERROR: Not Pokemon Emerald (found: " .. codeStr .. ")")
        console.log("This tool only works with Pokemon Emerald")
        return false
    end
    
    console.log("✓ Pokemon Emerald detected")
    
    -- Load ROM data
    console.log("Loading ROM data...")
    local romInitSuccess = ROMData.init()
    if not romInitSuccess then
        console.log("ERROR: Failed to load ROM data")
        return false
    end
    console.log("✓ ROM data loaded")
    
    -- Check for patches
    if ROMData.data.patchInfo then
        console.log("✓ Patch detected: " .. ROMData.data.patchInfo.type)
    end
    
    -- Test memory access
    console.log("\nTesting memory access...")
    local saveBlock1Ptr = Memory.read_u32_le(0x03005008)
    if saveBlock1Ptr and saveBlock1Ptr >= 0x02000000 and saveBlock1Ptr < 0x02040000 then
        console.log("✓ Save data accessible at 0x" .. string.format("%08X", saveBlock1Ptr))
        
        -- Test System Bus for addresses beyond 32KB
        if saveBlock1Ptr >= 0x02008000 then
            console.log("✓ Using System Bus for extended EWRAM access")
        end
    else
        console.log("⚠ Save data not found - load a save file")
    end
    
    State.isInitialized = true
    console.log("\nInitialization complete!")
    console.log("==============================================\n")
    
    return true
end

-- Update game data
function update()
    State.frameCount = State.frameCount + 1
    
    -- Quick update (every updateInterval frames)
    if State.frameCount - State.lastUpdate >= Config.updateInterval then
        State.lastUpdate = State.frameCount
        quickUpdate()
    end
    
    -- Full update (every fullUpdateInterval frames)
    if State.frameCount - State.lastFullUpdate >= Config.fullUpdateInterval then
        State.lastFullUpdate = State.frameCount
        fullUpdate()
    end
end

-- Quick update - just refresh current party
function quickUpdate()
    -- Read party
    State.party = PokemonReader.readParty()
    State.totalReads = State.totalReads + 1
    
    -- Update display
    displayParty()
    
    -- External output if enabled
    if Config.enableExternalOutput and hasJson then
        outputData()
    end
end

-- Full update - refresh everything including player info
function fullUpdate()
    -- Clear pointer cache to ensure fresh data
    Pointers.clearCache()
    
    -- Read player info
    State.playerInfo = Pointers.getPlayerInfo()
    
    -- Perform quick update too
    quickUpdate()
end

-- Display party information
function displayParty()
    console.clear()
    
    -- Header
    console.log("=== Pokemon Party Monitor ===")
    
    -- Player info
    if State.playerInfo then
        local hours = State.playerInfo.playTimeHours or 0
        local minutes = math.floor((State.playerInfo.playTimeFrames or 0) * 60 / 3600)
        console.log(string.format("Trainer ID: %05d | Money: $%d | Time: %d:%02d",
            State.playerInfo.trainerId or 0,
            State.playerInfo.money or 0,
            hours, minutes))
    end
    
    console.log("-----------------------------")
    
    -- Party Pokemon
    if State.party and State.party.count > 0 then
        console.log(string.format("Party: %d/6 Pokemon\n", State.party.count))
        
        for i, pokemon in ipairs(State.party.pokemon) do
            if pokemon then
                displayPokemon(i, pokemon)
            end
        end
    else
        console.log("No Pokemon in party")
    end
    
    -- Footer stats
    console.log("\n-----------------------------")
    local stats = Memory.getStats()
    local runtime = os.clock() - State.startTime
    console.log(string.format("Runtime: %.1fs | Updates: %d | Memory reads: %d",
        runtime, State.totalReads, stats.reads))
    
    if stats.systemBusFallbacks > 0 then
        console.log(string.format("System Bus used: %d times (extended EWRAM access)",
            stats.systemBusFallbacks))
    end
end

-- Display individual Pokemon
function displayPokemon(slot, pokemon)
    local info = PokemonReader.formatPokemon(pokemon)
    
    -- Basic info line
    console.log(string.format("%d. %s (Lv.%s %s) %s",
        slot,
        info.name,
        info.level,
        info.species,
        info.status and "[" .. info.status .. "]" or ""))
    
    -- HP bar
    local hpPercent = 0
    if pokemon.battleStats and pokemon.battleStats.maxHP > 0 then
        hpPercent = pokemon.battleStats.currentHP / pokemon.battleStats.maxHP
    end
    
    local barLength = 20
    local filledBars = math.floor(hpPercent * barLength)
    local hpBar = string.rep("█", filledBars) .. string.rep("░", barLength - filledBars)
    
    console.log(string.format("   HP: [%s] %s", hpBar, info.hp))
    
    -- Type, ability, nature, item
    console.log(string.format("   %s | %s | %s | Item: %s",
        info.types, info.ability, info.nature, info.item))
    
    -- Detailed stats if enabled
    if Config.showDetailedStats and pokemon.battleStats then
        console.log(string.format("   Stats: ATK %d | DEF %d | SPE %d | SPA %d | SPD %d",
            pokemon.battleStats.attack,
            pokemon.battleStats.defense,
            pokemon.battleStats.speed,
            pokemon.battleStats.spAttack,
            pokemon.battleStats.spDefense))
    end
    
    -- Moves if enabled
    if Config.showMoves and pokemon.moves then
        local moveNames = {}
        for j, moveId in ipairs(pokemon.moves) do
            if moveId > 0 then
                local move = ROMData.getMove(moveId)
                if move then
                    table.insert(moveNames, string.format("%s(%d/%d)", 
                        move.name, pokemon.pp[j] or 0, move.pp))
                end
            end
        end
        if #moveNames > 0 then
            console.log("   Moves: " .. table.concat(moveNames, " | "))
        end
    end
    
    -- IVs/EVs if enabled
    if Config.showIVsEVs and pokemon.parsedIVs and pokemon.evs then
        console.log(string.format("   IVs: %d/%d/%d/%d/%d/%d",
            pokemon.parsedIVs.hp,
            pokemon.parsedIVs.attack,
            pokemon.parsedIVs.defense,
            pokemon.parsedIVs.speed,
            pokemon.parsedIVs.spAttack,
            pokemon.parsedIVs.spDefense))
        console.log(string.format("   EVs: %d/%d/%d/%d/%d/%d",
            pokemon.evs.hp,
            pokemon.evs.attack,
            pokemon.evs.defense,
            pokemon.evs.speed,
            pokemon.evs.spAttack,
            pokemon.evs.spDefense))
    end
    
    console.log("")  -- Blank line between Pokemon
end

-- Output data for external tools
function outputData()
    if not hasJson then return end
    
    local data = {
        timestamp = os.time(),
        frameCount = State.frameCount,
        player = State.playerInfo,
        party = State.party
    }
    
    local success, jsonStr = pcall(json.encode, data)
    if success then
        local file = io.open(Config.outputFile, "w")
        if file then
            file:write(jsonStr)
            file:close()
        end
    end
end

-- Handle user input
function handleInput()
    local keys = input.get()
    
    -- Toggle options with keyboard
    if keys["D"] then
        Config.showDetailedStats = not Config.showDetailedStats
        console.log("Detailed stats: " .. (Config.showDetailedStats and "ON" or "OFF"))
    end
    
    if keys["M"] then
        Config.showMoves = not Config.showMoves
        console.log("Move display: " .. (Config.showMoves and "ON" or "OFF"))
    end
    
    if keys["I"] then
        Config.showIVsEVs = not Config.showIVsEVs
        console.log("IV/EV display: " .. (Config.showIVsEVs and "ON" or "OFF"))
    end
    
    if keys["E"] then
        Config.enableExternalOutput = not Config.enableExternalOutput
        console.log("External output: " .. (Config.enableExternalOutput and "ON" or "OFF"))
    end
    
    if keys["R"] then
        -- Force refresh
        State.lastFullUpdate = 0
        console.log("Forcing full refresh...")
    end
end

-- Main loop
function main()
    -- Initialize
    if not init() then
        console.log("\nPress any key to exit...")
        while not input.get() do
            emu.frameadvance()
        end
        return
    end
    
    console.log("\nControls:")
    console.log("D - Toggle detailed stats")
    console.log("M - Toggle move display")
    console.log("I - Toggle IV/EV display")
    console.log("E - Toggle external output")
    console.log("R - Force refresh")
    console.log("\nStarting in 3 seconds...")
    
    -- Wait 3 seconds
    for i = 1, 180 do
        emu.frameadvance()
    end
    
    -- Main loop
    while true do
        handleInput()
        update()
        emu.frameadvance()
    end
end

-- Error handling
local success, err = pcall(main)
if not success then
    console.log("\n=== ERROR ===")
    console.log(tostring(err))
    console.log("\nPress any key to exit...")
    while true do
        if next(input.get()) then break end
        emu.frameadvance()
    end
end
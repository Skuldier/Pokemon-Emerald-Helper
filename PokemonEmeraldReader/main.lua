-- main.lua
-- Pokemon Emerald Memory Reader for BizHawk
-- Fixed version with move display

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
    showMoves = true,           -- This should show moves
    showIVsEVs = false,
    debugMode = false,          -- Add debug mode
    
    -- Performance
    cacheLifetime = 300,        -- 5 seconds
    
    -- Archipelago mode
    archipelagoMode = false,    -- Set to true if patch detected
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
    console.log("(With Move Display)")
    console.log("==============================================")
    console.log("Initializing...")
    
    -- Try multiple methods to verify Pokemon Emerald
    local isEmerald = false
    local gameInfo = "Unknown"
    
    -- Method 1: Standard game code location
    local gameCode = Memory.readbytes(0x080000AC, 4)
    if gameCode then
        local codeStr = ""
        for i, byte in ipairs(gameCode) do
            if byte then
                codeStr = codeStr .. string.char(byte)
            end
        end
        
        if codeStr == "BPEE" then
            isEmerald = true
            gameInfo = "Pokemon Emerald (Vanilla)"
        else
            console.log("Game code: " .. codeStr .. " (not standard BPEE)")
        end
    else
        console.log("Warning: Could not read game code at standard location")
    end
    
    -- Method 2: Check ROM title
    local romTitle = Memory.readstring(0x080000A0, 12)
    if romTitle and romTitle:find("POKEMON EMER") then
        isEmerald = true
        if gameInfo == "Unknown" then
            gameInfo = "Pokemon Emerald (Modified Header)"
        end
    end
    
    -- Method 3: Check for known data patterns
    if not isEmerald then
        -- Check for Pokemon base stats table signature
        local statsCheck = Memory.read_u32_le(0x083203CC)
        if statsCheck == 0x2D2D0803 then  -- Bulbasaur's stats pattern
            isEmerald = true
            gameInfo = "Pokemon Emerald (Pattern Match)"
        end
    end
    
    if not isEmerald then
        console.log("\nWARNING: Pokemon Emerald not detected!")
        console.log("The tool may not work correctly.")
        console.log("Continuing anyway...")
        gameInfo = "Unknown GBA ROM"
    else
        console.log("✓ " .. gameInfo .. " detected")
    end
    
    -- Load ROM data
    console.log("\nLoading ROM data...")
    local romInitSuccess = ROMData.init()
    if not romInitSuccess then
        console.log("WARNING: Failed to load some ROM data")
        console.log("Basic features will still work")
    else
        console.log("✓ ROM data loaded")
        
        -- Test move data loading
        console.log("\nTesting move data...")
        local tackle = ROMData.getMove(33)  -- Tackle
        if tackle and tackle.name then
            console.log("✓ Move data working: Move #33 = " .. tackle.name)
        else
            console.log("✗ Move data not loading correctly!")
        end
    end
    
    -- Check for patches
    if ROMData.data.patchInfo then
        console.log("✓ Patch detected: " .. ROMData.data.patchInfo.type)
        Config.archipelagoMode = true
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
    if Config.archipelagoMode then
        console.log("(Archipelago Mode)")
    end
    
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
    
    -- Debug info
    if Config.debugMode then
        console.log("\n[DEBUG] Press D for stats, M for moves, I for IVs, E for export, R to refresh")
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
    if pokemon.battleStats and pokemon.battleStats.maxHP and pokemon.battleStats.maxHP > 0 then
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
    
    -- MOVES DISPLAY - ARCHIPELAGO COMPATIBLE VERSION
    if Config.showMoves and pokemon.moves then
        local moveDisplay = {}
        local hasMoves = false
        
        for j = 1, 4 do
            local moveId = pokemon.moves[j]
            if moveId and moveId > 0 then
                hasMoves = true
                
                -- Check if it's a standard move (ID <= 354 for Gen 3)
                if moveId <= 354 then
                    local moveData = ROMData.getMove(moveId)
                    if moveData and moveData.name then
                        local pp = pokemon.pp and pokemon.pp[j] or 0
                        local maxPP = moveData.pp or 0
                        table.insert(moveDisplay, string.format("%s(%d/%d)", moveData.name, pp, maxPP))
                    else
                        local pp = pokemon.pp and pokemon.pp[j] or 0
                        table.insert(moveDisplay, string.format("Move#%d(%d)", moveId, pp))
                    end
                else
                    -- Archipelago custom move
                    local pp = pokemon.pp and pokemon.pp[j] or 0
                    if Config.archipelagoMode then
                        table.insert(moveDisplay, string.format("AM#%d(%d)", moveId, pp))
                    else
                        table.insert(moveDisplay, string.format("Move#%d(%d)", moveId, pp))
                    end
                end
            end
        end
        
        if hasMoves then
            console.log("   Moves: " .. table.concat(moveDisplay, " | "))
        else
            if Config.debugMode then
                console.log("   Moves: (no moves found)")
            end
        end
        
        -- Debug info for high move IDs
        if Config.debugMode and pokemon.moves then
            local hasHighIds = false
            for j = 1, 4 do
                if pokemon.moves[j] and pokemon.moves[j] > 354 then
                    hasHighIds = true
                    break
                end
            end
            if hasHighIds then
                local moveIds = {}
                for j = 1, 4 do
                    if pokemon.moves[j] then
                        table.insert(moveIds, string.format("#%d", pokemon.moves[j]))
                    end
                end
                console.log("   [DEBUG] Raw Move IDs: " .. table.concat(moveIds, ", "))
                console.log("   [DEBUG] Note: IDs > 354 are Archipelago custom moves")
            end
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
        party = State.party,
        archipelago = Config.archipelagoMode
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
    
    if keys["G"] then
        -- Toggle debug mode
        Config.debugMode = not Config.debugMode
        console.log("Debug mode: " .. (Config.debugMode and "ON" or "OFF"))
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
    console.log("G - Toggle debug mode")
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
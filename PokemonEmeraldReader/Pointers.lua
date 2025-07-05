-- Pointers.lua
-- IWRAM pointer management for Pokemon Emerald
-- Handles stable pointers that survive DMA relocations

local Memory = require("Memory")

local Pointers = {}

-- Critical IWRAM pointers for Pokemon Emerald
-- These addresses are in IWRAM and contain pointers to data in EWRAM
Pointers.addresses = {
    -- Save data pointers
    gSaveBlock1 = 0x03005008,      -- Points to save block 1 (player, party, PC, etc.)
    gSaveBlock2 = 0x0300500C,      -- Points to save block 2 (played time, etc.)
    gSaveBlock2PTR = 0x03005010,   -- Another pointer to save block 2
    
    -- Pokemon data pointers
    gPlayerParty = 0x03004360,     -- Player's party Pokemon
    gEnemyParty = 0x030045C0,      -- Enemy party in battle
    
    -- Battle pointers
    gBattleMons = 0x03004324,      -- Battle Pokemon data
    gBattleTypeFlags = 0x030042DC, -- Battle type (wild, trainer, etc.)
    gBattleMainFunc = 0x03004300,  -- Current battle function
    gBattleResults = 0x03004318,   -- Battle results
    
    -- Game state
    gMain = 0x030022C0,            -- Main game structure
    gTasks = 0x03005090,           -- Task system
    gSprites = 0x03007420,         -- Sprite data
    
    -- Special variables
    gSpecialVar_0x8000 = 0x0300481C,
    gSpecialVar_0x8001 = 0x0300481E,
    gSpecialVar_0x8002 = 0x03004820,
    gSpecialVar_0x8003 = 0x03004822,
    gSpecialVar_0x8004 = 0x03004824,
    gSpecialVar_0x8005 = 0x03004826,
    gSpecialVar_0x8006 = 0x03004828,
    gSpecialVar_0x8007 = 0x0300482A,
    gSpecialVar_Result = 0x0300481C,  -- Same as 0x8000
    
    -- DMA control
    gDMA3SAD = 0x030000D4,         -- DMA3 source address
    gDMA3DAD = 0x030000D8,         -- DMA3 destination address
    gDMA3CNT = 0x030000DC,         -- DMA3 control
    
    -- RNG
    gRngValue = 0x03005000,        -- RNG seed
    
    -- Map data
    gMapHeader = 0x0300500C,       -- Current map header
    gObjectEvents = 0x030048E0,    -- NPCs and objects
}

-- SaveBlock1 structure offsets
Pointers.saveBlock1Offsets = {
    playerName = 0x0000,           -- 8 bytes
    playerGender = 0x0008,         -- 1 byte
    playerTrainerId = 0x000A,      -- 2 bytes
    playerSecretId = 0x000C,       -- 2 bytes
    playTimeHours = 0x000E,        -- 2 bytes
    playTimeFrames = 0x0010,       -- 1 byte
    options = 0x0014,              -- 3 bytes
    
    teamAndItems = 0x0234,         -- Party and items start
    teamCount = 0x0234,            -- Party count (4 bytes)
    teamPokemon = 0x0238,          -- Party Pokemon (600 bytes, 6 * 100)
    
    money = 0x0490,                -- 4 bytes
    coins = 0x0494,                -- 2 bytes
    
    pcItems = 0x0498,              -- PC items (120 bytes, 30 * 4)
    itemPocket = 0x0560,           -- Item pocket (120 bytes, 30 * 4)
    keyItemPocket = 0x05B0,        -- Key items (120 bytes, 30 * 4)
    ballPocket = 0x0600,           -- Pokeballs (64 bytes, 16 * 4)
    tmCase = 0x0640,               -- TMs/HMs (232 bytes, 58 * 4)
    berryPocket = 0x0740,          -- Berries (172 bytes, 43 * 4)
    
    rivalName = 0x0BCC,            -- 8 bytes
    
    mapDataSize = 0x09C8,          -- Map data size
    mapData = 0x0C64,              -- Map data
    
    flags = 0x1220,                -- Game flags (300 bytes)
    vars = 0x1340,                 -- Game variables (256 bytes)
    
    gameStats = 0x1540,            -- Game statistics
    
    pcBoxes = 0x4D84,              -- PC boxes start (33600 bytes, 14 * 30 * 80)
}

-- SaveBlock2 structure offsets
Pointers.saveBlock2Offsets = {
    encryptionKey = 0x0000,        -- 4 bytes
    
    -- Pokedex data
    pokedexOwned = 0x0018,         -- 52 bytes (bit flags)
    pokedexSeen = 0x0044,          -- 52 bytes (bit flags)
}

-- Cache for frequently accessed pointers
local cache = {
    saveBlock1 = nil,
    saveBlock2 = nil,
    lastCacheTime = 0
}

-- Cache lifetime in frames (5 seconds at 60fps)
local CACHE_LIFETIME = 300

-- Read and validate a pointer
function Pointers.readPointer(name)
    local addr = Pointers.addresses[name]
    if not addr then 
        return nil, "Unknown pointer: " .. tostring(name)
    end
    
    local pointer = Memory.read_u32_le(addr)
    if not pointer then
        return nil, "Failed to read pointer at " .. string.format("0x%08X", addr)
    end
    
    -- Validate pointer is in valid EWRAM range
    if pointer < 0x02000000 or pointer >= 0x02040000 then
        return nil, "Invalid pointer value: " .. string.format("0x%08X", pointer)
    end
    
    return pointer
end

-- Get SaveBlock1 with caching
function Pointers.getSaveBlock1()
    local currentFrame = emu.framecount()
    
    -- Check cache
    if cache.saveBlock1 and (currentFrame - cache.lastCacheTime) < CACHE_LIFETIME then
        return cache.saveBlock1
    end
    
    -- Read pointer
    local ptr, err = Pointers.readPointer("gSaveBlock1")
    if not ptr then
        return nil, err
    end
    
    -- Create SaveBlock1 structure
    local saveBlock1 = {
        pointer = ptr,
        -- Add all offsets to the base pointer
        playerName = ptr + Pointers.saveBlock1Offsets.playerName,
        playerGender = ptr + Pointers.saveBlock1Offsets.playerGender,
        playerTrainerId = ptr + Pointers.saveBlock1Offsets.playerTrainerId,
        playerSecretId = ptr + Pointers.saveBlock1Offsets.playerSecretId,
        playTimeHours = ptr + Pointers.saveBlock1Offsets.playTimeHours,
        playTimeFrames = ptr + Pointers.saveBlock1Offsets.playTimeFrames,
        teamAndItems = ptr + Pointers.saveBlock1Offsets.teamAndItems,
        teamCount = ptr + Pointers.saveBlock1Offsets.teamCount,
        teamPokemon = ptr + Pointers.saveBlock1Offsets.teamPokemon,
        money = ptr + Pointers.saveBlock1Offsets.money,
        coins = ptr + Pointers.saveBlock1Offsets.coins,
        pcItems = ptr + Pointers.saveBlock1Offsets.pcItems,
        itemPocket = ptr + Pointers.saveBlock1Offsets.itemPocket,
        keyItemPocket = ptr + Pointers.saveBlock1Offsets.keyItemPocket,
        ballPocket = ptr + Pointers.saveBlock1Offsets.ballPocket,
        tmCase = ptr + Pointers.saveBlock1Offsets.tmCase,
        berryPocket = ptr + Pointers.saveBlock1Offsets.berryPocket,
        rivalName = ptr + Pointers.saveBlock1Offsets.rivalName,
        flags = ptr + Pointers.saveBlock1Offsets.flags,
        vars = ptr + Pointers.saveBlock1Offsets.vars,
        gameStats = ptr + Pointers.saveBlock1Offsets.gameStats,
        pcBoxes = ptr + Pointers.saveBlock1Offsets.pcBoxes
    }
    
    -- Update cache
    cache.saveBlock1 = saveBlock1
    cache.lastCacheTime = currentFrame
    
    return saveBlock1
end

-- Get SaveBlock2 with caching
function Pointers.getSaveBlock2()
    local currentFrame = emu.framecount()
    
    -- Check cache
    if cache.saveBlock2 and (currentFrame - cache.lastCacheTime) < CACHE_LIFETIME then
        return cache.saveBlock2
    end
    
    -- Read pointer
    local ptr, err = Pointers.readPointer("gSaveBlock2")
    if not ptr then
        return nil, err
    end
    
    -- Create SaveBlock2 structure
    local saveBlock2 = {
        pointer = ptr,
        encryptionKey = ptr + Pointers.saveBlock2Offsets.encryptionKey,
        pokedexOwned = ptr + Pointers.saveBlock2Offsets.pokedexOwned,
        pokedexSeen = ptr + Pointers.saveBlock2Offsets.pokedexSeen
    }
    
    -- Update cache
    cache.saveBlock2 = saveBlock2
    cache.lastCacheTime = currentFrame
    
    return saveBlock2
end

-- Clear cache (useful when game state changes significantly)
function Pointers.clearCache()
    cache.saveBlock1 = nil
    cache.saveBlock2 = nil
    cache.lastCacheTime = 0
end

-- Get party address
function Pointers.getPartyAddress()
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil, "Failed to get SaveBlock1"
    end
    
    return saveBlock1.teamAndItems
end

-- Get party count
function Pointers.getPartyCount()
    local partyAddr = Pointers.getPartyAddress()
    if not partyAddr then
        return 0
    end
    
    local count = Memory.read_u32_le(partyAddr)
    if not count or count > 6 then
        return 0
    end
    
    return count
end

-- Get Pokemon address in party
function Pointers.getPartyPokemonAddress(slot)
    if slot < 0 or slot > 5 then
        return nil, "Invalid slot: " .. slot
    end
    
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil, "Failed to get SaveBlock1"
    end
    
    -- Each Pokemon is 100 bytes
    return saveBlock1.teamPokemon + (slot * 100)
end

-- Get PC box address
function Pointers.getPCBoxAddress(box, slot)
    if box < 0 or box > 13 then
        return nil, "Invalid box: " .. box
    end
    
    if slot < 0 or slot > 29 then
        return nil, "Invalid slot: " .. slot
    end
    
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil, "Failed to get SaveBlock1"
    end
    
    -- Each box has 30 Pokemon, each Pokemon is 80 bytes in PC
    local boxOffset = box * 30 * 80
    local slotOffset = slot * 80
    
    return saveBlock1.pcBoxes + boxOffset + slotOffset
end

-- Get player info
function Pointers.getPlayerInfo()
    local saveBlock1 = Pointers.getSaveBlock1()
    if not saveBlock1 then
        return nil
    end
    
    return {
        name = Memory.readbytes(saveBlock1.playerName, 8),
        gender = Memory.read_u8(saveBlock1.playerGender),
        trainerId = Memory.read_u16_le(saveBlock1.playerTrainerId),
        secretId = Memory.read_u16_le(saveBlock1.playerSecretId),
        playTimeHours = Memory.read_u16_le(saveBlock1.playTimeHours),
        playTimeFrames = Memory.read_u8(saveBlock1.playTimeFrames),
        money = Memory.read_u32_le(saveBlock1.money),
        coins = Memory.read_u16_le(saveBlock1.coins)
    }
end

-- Test function
function Pointers.test()
    console.log("=== Pointers Module Test ===\n")
    
    -- Test reading main pointers
    console.log("Main pointers:")
    local mainPointers = {"gSaveBlock1", "gSaveBlock2", "gMain", "gPlayerParty"}
    
    for _, name in ipairs(mainPointers) do
        local ptr, err = Pointers.readPointer(name)
        if ptr then
            console.log(string.format("✓ %s: 0x%08X", name, ptr))
        else
            console.log(string.format("✗ %s: %s", name, err or "Unknown error"))
        end
    end
    
    -- Test SaveBlock access
    console.log("\nSaveBlock1 test:")
    local sb1 = Pointers.getSaveBlock1()
    if sb1 then
        console.log(string.format("✓ SaveBlock1 at 0x%08X", sb1.pointer))
        console.log(string.format("  Party data: 0x%08X", sb1.teamAndItems))
        console.log(string.format("  PC boxes: 0x%08X", sb1.pcBoxes))
    else
        console.log("✗ Failed to get SaveBlock1")
    end
    
    -- Test player info
    console.log("\nPlayer info test:")
    local playerInfo = Pointers.getPlayerInfo()
    if playerInfo then
        console.log("✓ Player info retrieved")
        console.log(string.format("  Trainer ID: %d", playerInfo.trainerId or 0))
        console.log(string.format("  Money: $%d", playerInfo.money or 0))
        console.log(string.format("  Play time: %d:%02d", 
            playerInfo.playTimeHours or 0, 
            math.floor((playerInfo.playTimeFrames or 0) * 60 / 3600)))
    else
        console.log("✗ Failed to get player info")
    end
    
    -- Test party access
    console.log("\nParty test:")
    local partyCount = Pointers.getPartyCount()
    console.log(string.format("Party count: %d", partyCount))
    
    for i = 0, math.min(partyCount - 1, 2) do  -- Test first 3 Pokemon
        local addr = Pointers.getPartyPokemonAddress(i)
        if addr then
            console.log(string.format("  Slot %d: 0x%08X", i + 1, addr))
        end
    end
end

return Pointers
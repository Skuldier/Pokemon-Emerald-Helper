-- archipelago_moves.lua
-- Handles custom move IDs in Archipelago ROMs

local ArchipelagoMoves = {}

-- Known custom move IDs in Archipelago (if any)
-- Add any custom moves you discover here
ArchipelagoMoves.customMoves = {
    -- Example: [46345] = {name = "Custom Move 1", power = 40, type = 0, pp = 35},
}

-- Get move data with Archipelago support
function ArchipelagoMoves.getMove(moveId)
    if not moveId or moveId == 0 then
        return nil
    end
    
    -- First check if it's a custom Archipelago move
    local customMove = ArchipelagoMoves.customMoves[moveId]
    if customMove then
        return customMove
    end
    
    -- If it's in the normal range, use standard ROM data
    if moveId > 0 and moveId <= 354 then
        local ROMData = require("ROMData")
        return ROMData.getMove(moveId)
    end
    
    -- For unknown high IDs, return a placeholder
    if moveId > 354 then
        return {
            name = string.format("Move#%d", moveId),
            power = 0,
            type = 0,
            pp = 0,
            custom = true
        }
    end
    
    return nil
end

-- Format move display with better handling of custom moves
function ArchipelagoMoves.formatMoveDisplay(pokemon)
    if not pokemon or not pokemon.moves then
        return nil
    end
    
    local moveDisplay = {}
    local hasMoves = false
    
    for j = 1, 4 do
        local moveId = pokemon.moves[j]
        if moveId and moveId > 0 then
            hasMoves = true
            local moveData = ArchipelagoMoves.getMove(moveId)
            
            if moveData then
                local pp = pokemon.pp and pokemon.pp[j] or 0
                local maxPP = moveData.pp or 0
                
                -- Handle PP display for custom moves
                if moveData.custom or maxPP == 0 then
                    table.insert(moveDisplay, string.format("%s(%d)", moveData.name, pp))
                else
                    table.insert(moveDisplay, string.format("%s(%d/%d)", moveData.name, pp, maxPP))
                end
            else
                local pp = pokemon.pp and pokemon.pp[j] or 0
                table.insert(moveDisplay, string.format("Unknown#%d(%d)", moveId, pp))
            end
        end
    end
    
    return hasMoves and moveDisplay or nil
end

return ArchipelagoMoves
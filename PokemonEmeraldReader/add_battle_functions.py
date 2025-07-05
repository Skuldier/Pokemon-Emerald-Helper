#!/usr/bin/env python3
"""
Add missing battle functions to Pointers.lua
"""

from pathlib import Path

def add_battle_functions():
    """Add the missing getBattleState and getEnemyPartyAddress functions"""
    
    print("🔧 Adding missing battle functions to Pointers.lua...")
    
    # Find Pointers.lua
    search_paths = [
        Path("Pointers.lua"),
        Path("PokemonEmeraldReader/Pointers.lua"),
        Path("./PokemonEmeraldReader/Pointers.lua")
    ]
    
    pointers_file = None
    for path in search_paths:
        if path.exists():
            pointers_file = path
            break
    
    if not pointers_file:
        print("❌ Could not find Pointers.lua!")
        return False
    
    print(f"📄 Found Pointers.lua at: {pointers_file}")
    
    # Read the file
    with open(pointers_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if functions already exist
    if "function Pointers.getBattleState" in content:
        print("✓ getBattleState already exists")
        return True
    
    # Find the return statement
    return_pos = content.rfind("return Pointers")
    if return_pos == -1:
        print("⚠️  No 'return Pointers' found, adding at end")
        insert_pos = len(content)
        content += "\n"
    else:
        insert_pos = return_pos
    
    # Battle functions to add
    battle_functions = '''
-- NEW: Get battle state
function Pointers.getBattleState()
    local battleFlags = Memory.read_u16_le(Pointers.addresses.gBattleTypeFlags)
    if not battleFlags or battleFlags == 0 then
        return nil  -- Not in battle
    end
    
    return {
        inBattle = true,
        isWildBattle = band(battleFlags, 0x01) ~= 0,
        isTrainerBattle = band(battleFlags, 0x08) ~= 0,
        isDoubleBattle = band(battleFlags, 0x02) ~= 0,
        flags = battleFlags
    }
end

-- NEW: Get enemy party address
function Pointers.getEnemyPartyAddress()
    -- Enemy party is at fixed offset from player party
    local playerParty = Pointers.getPartyAddress()
    if not playerParty then return nil end
    
    -- Enemy party is typically 0x4C0 bytes after player party
    return playerParty + 0x4C0
end

'''
    
    # Insert the functions
    new_content = content[:insert_pos] + battle_functions + content[insert_pos:]
    
    # Save backup
    backup_path = str(pointers_file) + ".backup"
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"📋 Backup saved to: {backup_path}")
    
    # Write updated file
    with open(pointers_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("✅ Added battle functions successfully!")
    
    # Also fix the battle address if needed
    if "gBattleTypeFlags = 0x030042DC" in new_content:
        print("\n🔧 Updating gBattleTypeFlags address...")
        new_content = new_content.replace(
            "gBattleTypeFlags = 0x030042DC",
            "gBattleTypeFlags = 0x02022FEC"
        )
        with open(pointers_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("✅ Updated battle address")
    
    return True

if __name__ == "__main__":
    if add_battle_functions():
        print("\n🎮 Now run the test again to verify it works!")
    else:
        print("\n❌ Failed to add functions")
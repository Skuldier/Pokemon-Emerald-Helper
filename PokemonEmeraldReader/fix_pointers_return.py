#!/usr/bin/env python3
"""
Fix Pointers.lua by moving 'return Pointers' to the end of the file
"""

from pathlib import Path
import re

def fix_return_statement():
    """Move the return statement to the end of the file"""
    
    print("🔧 Fixing Pointers.lua return statement position...")
    
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
    
    # Check if return is in wrong place
    return_matches = list(re.finditer(r'return\s+Pointers', content))
    battle_matches = list(re.finditer(r'function\s+Pointers\.getBattleState', content))
    
    if not return_matches:
        print("⚠️  No 'return Pointers' found!")
        content = content.rstrip() + "\n\nreturn Pointers\n"
    else:
        return_pos = return_matches[0].start()
        
        # Check if any battle functions come after return
        functions_after_return = False
        if battle_matches:
            for match in battle_matches:
                if match.start() > return_pos:
                    functions_after_return = True
                    break
        
        if functions_after_return:
            print("🔍 Found functions AFTER return statement - fixing...")
            
            # Remove all return statements
            content = re.sub(r'return\s+Pointers\s*\n?', '', content)
            
            # Add return at the very end
            content = content.rstrip() + "\n\nreturn Pointers\n"
        else:
            print("✓ Return statement is already in correct position")
            return True
    
    # Save backup
    backup_path = str(pointers_file) + ".backup_return"
    with open(pointers_file, 'r', encoding='utf-8') as f:
        backup_content = f.read()
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(backup_content)
    print(f"📋 Backup saved to: {backup_path}")
    
    # Write fixed file
    with open(pointers_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Fixed! 'return Pointers' is now at the end of the file")
    
    # Verify the fix
    print("\n🔍 Verifying fix...")
    with open(pointers_file, 'r', encoding='utf-8') as f:
        new_content = f.read()
    
    last_return = new_content.rfind('return Pointers')
    last_function = max(
        new_content.rfind('function Pointers.getBattleState'),
        new_content.rfind('function Pointers.getEnemyPartyAddress')
    )
    
    if last_return > last_function:
        print("✅ Verified: All functions are now before the return statement")
        return True
    else:
        print("❌ Still not fixed properly!")
        return False

if __name__ == "__main__":
    if fix_return_statement():
        print("\n🎮 Now restart BizHawk and run the tool again!")
        print("The battle functions should work properly now.")
    else:
        print("\n❌ Fix failed. You may need to manually edit the file.")
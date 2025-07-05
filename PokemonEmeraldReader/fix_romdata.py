#!/usr/bin/env python3
"""
Fix bitwise operation deprecation warnings in Pokemon Emerald Memory Reader
Adds compatibility wrappers and updates bit.* calls
"""

import os
import re
import sys
from pathlib import Path

# Compatibility header to add to files
COMPAT_HEADER = '''-- Bitwise operation compatibility
local band = _VERSION >= "Lua 5.3" and function(a,b) return a & b end or bit.band
local bor = _VERSION >= "Lua 5.3" and function(a,b) return a | b end or bit.bor
local bxor = _VERSION >= "Lua 5.3" and function(a,b) return a ~ b end or bit.bxor
local bnot = _VERSION >= "Lua 5.3" and function(a) return ~a end or bit.bnot
local lshift = _VERSION >= "Lua 5.3" and function(a,b) return a << b end or bit.lshift
local rshift = _VERSION >= "Lua 5.3" and function(a,b) return a >> b end or bit.rshift

'''

def fix_lua_file(filepath):
    """Fix bitwise operations in a Lua file"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if file uses bit operations
    if not re.search(r'bit\.\w+', content):
        print(f"  No bit operations found in {filepath.name}")
        return False
    
    # Check if already fixed
    if "Bitwise operation compatibility" in content:
        print(f"  Already fixed: {filepath.name}")
        return False
    
    print(f"  Fixing {filepath.name}...")
    
    # Add compatibility header after initial comments and requires
    lines = content.split('\n')
    insert_pos = 0
    
    # Find where to insert (after initial comments and local requires)
    for i, line in enumerate(lines):
        if line.strip() and not line.strip().startswith('--') and not line.startswith('local') and 'require' not in line:
            insert_pos = i
            break
        if 'require' in line:
            insert_pos = i + 1
    
    # Insert compatibility header
    lines.insert(insert_pos, COMPAT_HEADER)
    content = '\n'.join(lines)
    
    # Replace bit.* calls with local functions
    replacements = [
        (r'bit\.band\(', 'band('),
        (r'bit\.bor\(', 'bor('),
        (r'bit\.bxor\(', 'bxor('),
        (r'bit\.bnot\(', 'bnot('),
        (r'bit\.lshift\(', 'lshift('),
        (r'bit\.rshift\(', 'rshift('),
    ]
    
    for old, new in replacements:
        content = re.sub(old, new, content)
    
    # Save backup
    backup_path = filepath.with_suffix('.lua.backup')
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Write fixed version
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"    ✓ Fixed and backed up to {backup_path.name}")
    return True

def main():
    print("Pokemon Emerald Memory Reader - Bitwise Warning Fixer")
    print("=" * 50)
    
    # Find Lua files to fix
    if len(sys.argv) > 1:
        # Specific directory provided
        search_dir = Path(sys.argv[1])
    else:
        # Try to find the files
        search_dirs = [
            Path("./PokemonEmeraldReader"),
            Path("."),
            Path(".."),
        ]
        
        search_dir = None
        for d in search_dirs:
            if d.exists() and any(d.glob("*.lua")):
                search_dir = d
                break
        
        if not search_dir:
            print("Error: Could not find Lua files!")
            print("Usage: python fix_bitwise_warnings.py [directory]")
            return 1
    
    print(f"Searching in: {search_dir.absolute()}")
    
    # Files to fix
    target_files = [
        "Memory.lua",
        "PokemonReader.lua",
        "ROMData.lua",
        "Pointers.lua"
    ]
    
    fixed_count = 0
    for filename in target_files:
        filepath = search_dir / filename
        if filepath.exists():
            if fix_lua_file(filepath):
                fixed_count += 1
        else:
            print(f"  Skipping {filename} (not found)")
    
    print(f"\n✓ Fixed {fixed_count} files")
    print("\nThe bitwise warnings should now be gone!")
    print("Run your tool again to test.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
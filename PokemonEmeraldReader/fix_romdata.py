#!/usr/bin/env python3
"""
Quick fix for ROMData.lua string escaping issue
"""

import sys
from pathlib import Path

def fix_romdata(filepath="./PokemonEmeraldReader/ROMData.lua"):
    """Fix the string escaping issue in ROMData.lua"""
    
    filepath = Path(filepath)
    if not filepath.exists():
        print(f"Error: {filepath} not found!")
        print("Make sure you're in the right directory")
        return False
    
    print(f"Fixing {filepath}...")
    
    # Read the file
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix the problematic quotes
    # Replace curly quotes with regular quotes
    replacements = [
        ('str = str .. "…"', 'str = str .. "..."'),  # Ellipsis
        ('str = str .. """', 'str = str .. "\\""'),   # Left quote
        ('str = str .. """', 'str = str .. "\\""'),   # Right quote  
        ('str = str .. "'"', 'str = str .. "\'"'),    # Left single
        ('str = str .. "'"', 'str = str .. "\'"'),    # Right single
        ('str = str .. "♂"', 'str = str .. "M"'),     # Male symbol
        ('str = str .. "♀"', 'str = str .. "F"'),     # Female symbol
        ('str = str .. "é"', 'str = str .. "e"'),     # Accented e
    ]
    
    # Apply replacements
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
            print(f"  Fixed: {old[:20]}... -> {new[:20]}...")
    
    # Backup original
    backup_path = filepath.with_suffix('.lua.backup')
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"  Backup saved to: {backup_path}")
    
    # Write fixed version
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Fixed {filepath}")
    print("\nYou can now run the tool again!")
    return True

if __name__ == "__main__":
    # Check command line argument for custom path
    if len(sys.argv) > 1:
        success = fix_romdata(sys.argv[1])
    else:
        # Try common locations
        locations = [
            "./PokemonEmeraldReader/ROMData.lua",
            "./ROMData.lua",
            "../ROMData.lua",
        ]
        
        success = False
        for loc in locations:
            if Path(loc).exists():
                success = fix_romdata(loc)
                break
        
        if not success:
            print("Could not find ROMData.lua!")
            print("Usage: python fix_romdata.py [path_to_ROMData.lua]")
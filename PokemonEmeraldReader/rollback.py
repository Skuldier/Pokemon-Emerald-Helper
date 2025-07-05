#!/usr/bin/env python3
"""Rollback to backup created on backup_20250704_200857"""
import shutil
from pathlib import Path

backup = Path("backup_20250704_200857")
current = Path(".")

if backup.exists():
    for lua_file in backup.glob("*.lua"):
        shutil.copy2(lua_file, current / lua_file.name)
        print(f"Restored: {lua_file.name}")
    print("\nRollback complete!")
else:
    print("Backup directory not found!")

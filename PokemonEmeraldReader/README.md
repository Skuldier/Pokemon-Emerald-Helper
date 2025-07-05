# Pokemon Emerald Memory Reader for BizHawk

A comprehensive memory reading tool for Pokemon Emerald that overcomes BizHawk's 32KB EWRAM limitation using a hybrid ROM/RAM approach.

## Features

- **Overcomes BizHawk's EWRAM Limitation**: Uses System Bus and IWRAM pointers to access the full 256KB EWRAM
- **DMA-Safe Reading**: Frame-synchronized reads avoid corruption from Pokemon Emerald's memory protection
- **Hybrid Data Approach**: Reads static data from ROM (no DMA issues) and only dynamic data from RAM
- **Real-time Party Monitoring**: Display all party Pokemon with stats, moves, and status
- **External Output Support**: Export data as JSON for streaming overlays or other tools
- **Performance Optimized**: Intelligent caching and minimal memory reads

## Requirements

- BizHawk 2.8+ (tested on 2.9.1)
- Pokemon Emerald ROM (US version)
- GBA core in BizHawk (mGBA recommended)

## Installation

1. Download all Lua files to a single directory:
   - `Memory.lua` - Core memory access module
   - `Pointers.lua` - IWRAM pointer management
   - `ROMData.lua` - Static ROM data extraction
   - `PokemonReader.lua` - Pokemon data reading
   - `main.lua` - Main application
   - `run.lua` - Launcher script

2. Open BizHawk and load your Pokemon Emerald ROM

3. In BizHawk, go to Tools → Lua Console

4. In the Lua Console, click "Open Script" and select `run.lua`

## Usage

### Controls

- **D** - Toggle detailed stats display
- **M** - Toggle move display
- **I** - Toggle IV/EV display
- **E** - Toggle external JSON output
- **R** - Force full refresh

### Display Information

The tool shows:
- Trainer ID, Money, and Play Time
- All party Pokemon with:
  - Name, Level, and Species
  - HP bar and exact HP values
  - Type, Ability, Nature, and Held Item
  - Status conditions
  - Full stats (Attack, Defense, etc.)
  - Moves with current/max PP
  - IVs and EVs (when enabled)

### External Output

When enabled, the tool writes Pokemon data to `pokemon_data.json` every update cycle. This file can be used by:
- Streaming overlays
- External stat trackers
- Team builders
- Other analysis tools

## Technical Details

### How It Works

1. **Memory Abstraction Layer**: Routes reads to the appropriate domain (EWRAM, IWRAM, ROM, System Bus)

2. **IWRAM Pointers**: Uses stable pointers in IWRAM (0x03005008, etc.) to find data that moves in EWRAM

3. **System Bus Access**: For EWRAM addresses beyond 0x02008000, uses System Bus domain for universal access

4. **ROM Data Cache**: Loads all static data (base stats, move data, etc.) from ROM once at startup

5. **Frame Synchronization**: All reads happen at frame boundaries to avoid DMA corruption

### Memory Domains Used

| Domain | Range | Usage |
|--------|-------|-------|
| EWRAM | 0x02000000-0x02007FFF | Direct access (first 32KB) |
| System Bus | 0x02008000-0x0203FFFF | Extended EWRAM access |
| IWRAM | 0x03000000-0x03007FFF | Stable pointers |
| ROM | 0x08000000-0x09FFFFFF | Static game data |

## Troubleshooting

### "Not Pokemon Emerald" Error
- Ensure you're using Pokemon Emerald (US) version
- Game code should be "BPEE"

### No Pokemon Displayed
- Load a save file first
- Make sure you're in the overworld or a Pokemon Center
- Try pressing R to force a refresh

### Performance Issues
- Increase update interval in Config section of main.lua
- Disable detailed stats/moves display
- Close other Lua scripts

### Memory Read Failures
- Some areas (battles, menus) may temporarily prevent reads
- The tool will automatically retry
- Check the System Bus fallback counter in the footer

## Extending the Tool

### Adding New Data

To read additional data:

1. Find the IWRAM pointer in `Pointers.lua`
2. Add the offset to the relevant structure
3. Create a reader function in `PokemonReader.lua`
4. Display it in `main.lua`

### Custom Patches

The tool includes patch detection. To support custom patches:

1. Add patch signature to `ROMData.detectPatch()`
2. Add any patch-specific pointers to `Pointers.addresses`
3. Handle patch-specific data structures as needed

## Credits

This tool implements techniques researched from:
- IronMon Tracker
- mkdasher's PokemonBizhawkLua
- Archipelago multiworld
- PokeStreamer-Tools

## License

This tool is provided as-is for educational and personal use.
-- ROMData.lua (COMPLETE FIXED VERSION)
-- Static data extraction from Pokemon Emerald ROM
-- Includes comprehensive fallback systems and interface fixes

local Memory = require("Memory")

local ROMData = {}

-- Bitwise operation compatibility
local band = _VERSION >= "Lua 5.3" and function(a,b) return a & b end or bit.band
local bor = _VERSION >= "Lua 5.3" and function(a,b) return a | b end or bit.bor
local bxor = _VERSION >= "Lua 5.3" and function(a,b) return a ~ b end or bit.bxor
local bnot = _VERSION >= "Lua 5.3" and function(a) return ~a end or bit.bnot
local lshift = _VERSION >= "Lua 5.3" and function(a,b) return a << b end or bit.lshift
local rshift = _VERSION >= "Lua 5.3" and function(a,b) return a >> b end or bit.rshift

-- ROM addresses for Pokemon Emerald (UPDATED WITH YOUR FOUND ADDRESSES)
ROMData.addresses = {
    -- Core game data
    gameCode = 0x080000AC,
    gameName = 0x080000A0,
    
    -- WORKING ADDRESSES (from your address finder results)
    pokemonStats = 0x08324E04,      -- ✅ Found and working
    moveData = 0x083211F0,          -- ✅ Found and working
    
    -- MISSING TEXT DATA (will use fallback system)
    pokemonNames = nil,             -- ❌ Not found - using fallbacks
    moveNames = nil,                -- ❌ Not found - using fallbacks
    itemData = nil,                 -- ❌ Not found - using fallbacks
    
    -- Optional data (try vanilla addresses, may work)
    typeNames = 0x0831AE38,         -- Type names
    abilityNames = 0x0831B6DB,      -- Ability names  
    natureNames = 0x0831E818,       -- Nature names
    typeEffectiveness = 0x0831ACE0, -- Type matchup chart
    
    -- Additional data structures
    pokemonDexData = 0x0831E898,    -- Pokedex data
    evolutionData = 0x08326A8C,     -- Evolution data
    learnsets = 0x0832937C,         -- Level-up learnsets
    eggMoves = 0x08329560,          -- Egg moves
    moveDescriptions = 0x08319C98,  -- Move descriptions
    abilityDescriptions = 0x0831BAD4, -- Ability descriptions
    natureStats = 0x0831E898,       -- Nature stat modifiers
    trainerData = 0x08352080,       -- Trainer battles
    trainerClasses = 0x0831F53C,    -- Trainer class names
    mapHeaders = 0x08486578,        -- Map headers
    mapNames = 0x0831DFD4,          -- Map names
    gameText = 0x08470E6C,          -- General game text
}

-- Type effectiveness values
ROMData.typeEffectiveness = {
    NO_EFFECT = 0,
    NOT_VERY_EFFECTIVE = 5,
    NORMAL_DAMAGE = 10,
    SUPER_EFFECTIVE = 20
}

-- Pokemon stat indices
ROMData.statIndex = {
    HP = 0,
    ATTACK = 1,
    DEFENSE = 2,
    SPEED = 3,
    SP_ATTACK = 4,
    SP_DEFENSE = 5
}

-- Type indices
ROMData.types = {
    NORMAL = 0,
    FIGHTING = 1,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    ROCK = 5,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 10,
    WATER = 11,
    GRASS = 12,
    ELECTRIC = 13,
    PSYCHIC = 14,
    ICE = 15,
    DRAGON = 16,
    DARK = 17
}

-- COMPREHENSIVE FALLBACK NAME SYSTEM
ROMData.fallbackNames = {
    pokemon = {
        [1] = "Bulbasaur", [2] = "Ivysaur", [3] = "Venusaur", [4] = "Charmander", [5] = "Charmeleon",
        [6] = "Charizard", [7] = "Squirtle", [8] = "Wartortle", [9] = "Blastoise", [10] = "Caterpie",
        [11] = "Metapod", [12] = "Butterfree", [13] = "Weedle", [14] = "Kakuna", [15] = "Beedrill",
        [16] = "Pidgey", [17] = "Pidgeotto", [18] = "Pidgeot", [19] = "Rattata", [20] = "Raticate",
        [21] = "Spearow", [22] = "Fearow", [23] = "Ekans", [24] = "Arbok", [25] = "Pikachu",
        [26] = "Raichu", [27] = "Sandshrew", [28] = "Sandslash", [29] = "Nidoran♀", [30] = "Nidorina",
        [31] = "Nidoqueen", [32] = "Nidoran♂", [33] = "Nidorino", [34] = "Nidoking", [35] = "Clefairy",
        [36] = "Clefable", [37] = "Vulpix", [38] = "Ninetales", [39] = "Jigglypuff", [40] = "Wigglytuff",
        [41] = "Zubat", [42] = "Golbat", [43] = "Oddish", [44] = "Gloom", [45] = "Vileplume",
        [46] = "Paras", [47] = "Parasect", [48] = "Venonat", [49] = "Venomoth", [50] = "Diglett",
        [51] = "Dugtrio", [52] = "Meowth", [53] = "Persian", [54] = "Psyduck", [55] = "Golduck",
        [56] = "Mankey", [57] = "Primeape", [58] = "Growlithe", [59] = "Arcanine", [60] = "Poliwag",
        [61] = "Poliwhirl", [62] = "Poliwrath", [63] = "Abra", [64] = "Kadabra", [65] = "Alakazam",
        [66] = "Machop", [67] = "Machoke", [68] = "Machamp", [69] = "Bellsprout", [70] = "Weepinbell",
        [71] = "Victreebel", [72] = "Tentacool", [73] = "Tentacruel", [74] = "Geodude", [75] = "Graveler",
        [76] = "Golem", [77] = "Ponyta", [78] = "Rapidash", [79] = "Slowpoke", [80] = "Slowbro",
        [81] = "Magnemite", [82] = "Magneton", [83] = "Farfetch'd", [84] = "Doduo", [85] = "Dodrio",
        [86] = "Seel", [87] = "Dewgong", [88] = "Grimer", [89] = "Muk", [90] = "Shellder",
        [91] = "Cloyster", [92] = "Gastly", [93] = "Haunter", [94] = "Gengar", [95] = "Onix",
        [96] = "Drowzee", [97] = "Hypno", [98] = "Krabby", [99] = "Kingler", [100] = "Voltorb",
        [101] = "Electrode", [102] = "Exeggcute", [103] = "Exeggutor", [104] = "Cubone", [105] = "Marowak",
        [106] = "Hitmonlee", [107] = "Hitmonchan", [108] = "Lickitung", [109] = "Koffing", [110] = "Weezing",
        [111] = "Rhyhorn", [112] = "Rhydon", [113] = "Chansey", [114] = "Tangela", [115] = "Kangaskhan",
        [116] = "Horsea", [117] = "Seadra", [118] = "Goldeen", [119] = "Seaking", [120] = "Staryu",
        [121] = "Starmie", [122] = "Mr. Mime", [123] = "Scyther", [124] = "Jynx", [125] = "Electabuzz",
        [126] = "Magmar", [127] = "Pinsir", [128] = "Tauros", [129] = "Magikarp", [130] = "Gyarados",
        [131] = "Lapras", [132] = "Ditto", [133] = "Eevee", [134] = "Vaporeon", [135] = "Jolteon",
        [136] = "Flareon", [137] = "Porygon", [138] = "Omanyte", [139] = "Omastar", [140] = "Kabuto",
        [141] = "Kabutops", [142] = "Aerodactyl", [143] = "Snorlax", [144] = "Articuno", [145] = "Zapdos",
        [146] = "Moltres", [147] = "Dratini", [148] = "Dragonair", [149] = "Dragonite", [150] = "Mewtwo",
        [151] = "Mew", [152] = "Chikorita", [153] = "Bayleef", [154] = "Meganium", [155] = "Cyndaquil",
        [156] = "Quilava", [157] = "Typhlosion", [158] = "Totodile", [159] = "Croconaw", [160] = "Feraligatr",
        [161] = "Sentret", [162] = "Furret", [163] = "Hoothoot", [164] = "Noctowl", [165] = "Ledyba",
        [166] = "Ledian", [167] = "Spinarak", [168] = "Ariados", [169] = "Crobat", [170] = "Chinchou",
        [171] = "Lanturn", [172] = "Pichu", [173] = "Cleffa", [174] = "Igglybuff", [175] = "Togepi",
        [176] = "Togetic", [177] = "Natu", [178] = "Xatu", [179] = "Mareep", [180] = "Flaaffy",
        [181] = "Ampharos", [182] = "Bellossom", [183] = "Marill", [184] = "Azumarill", [185] = "Sudowoodo",
        [186] = "Politoed", [187] = "Hoppip", [188] = "Skiploom", [189] = "Jumpluff", [190] = "Aipom",
        [191] = "Sunkern", [192] = "Sunflora", [193] = "Yanma", [194] = "Wooper", [195] = "Quagsire",
        [196] = "Espeon", [197] = "Umbreon", [198] = "Murkrow", [199] = "Slowking", [200] = "Misdreavus",
        [201] = "Unown", [202] = "Wobbuffet", [203] = "Girafarig", [204] = "Pineco", [205] = "Forretress",
        [206] = "Dunsparce", [207] = "Gligar", [208] = "Steelix", [209] = "Snubbull", [210] = "Granbull",
        [211] = "Qwilfish", [212] = "Scizor", [213] = "Shuckle", [214] = "Heracross", [215] = "Sneasel",
        [216] = "Teddiursa", [217] = "Ursaring", [218] = "Slugma", [219] = "Magcargo", [220] = "Swinub",
        [221] = "Piloswine", [222] = "Corsola", [223] = "Remoraid", [224] = "Octillery", [225] = "Delibird",
        [226] = "Mantine", [227] = "Skarmory", [228] = "Houndour", [229] = "Houndoom", [230] = "Kingdra",
        [231] = "Phanpy", [232] = "Donphan", [233] = "Porygon2", [234] = "Stantler", [235] = "Smeargle",
        [236] = "Tyrogue", [237] = "Hitmontop", [238] = "Smoochum", [239] = "Elekid", [240] = "Magby",
        [241] = "Miltank", [242] = "Blissey", [243] = "Raikou", [244] = "Entei", [245] = "Suicune",
        [246] = "Larvitar", [247] = "Pupitar", [248] = "Tyranitar", [249] = "Lugia", [250] = "Ho-Oh",
        [251] = "Celebi", [252] = "Treecko", [253] = "Grovyle", [254] = "Sceptile", [255] = "Torchic",
        [256] = "Combusken", [257] = "Blaziken", [258] = "Mudkip", [259] = "Marshtomp", [260] = "Swampert",
        [261] = "Poochyena", [262] = "Mightyena", [263] = "Zigzagoon", [264] = "Linoone", [265] = "Wurmple",
        [266] = "Silcoon", [267] = "Beautifly", [268] = "Cascoon", [269] = "Dustox", [270] = "Lotad",
        [271] = "Lombre", [272] = "Ludicolo", [273] = "Seedot", [274] = "Nuzleaf", [275] = "Shiftry",
        [276] = "Taillow", [277] = "Swellow", [278] = "Wingull", [279] = "Pelipper", [280] = "Ralts",
        [281] = "Kirlia", [282] = "Gardevoir", [283] = "Surskit", [284] = "Masquerain", [285] = "Shroomish",
        [286] = "Breloom", [287] = "Slakoth", [288] = "Vigoroth", [289] = "Slaking", [290] = "Nincada",
        [291] = "Ninjask", [292] = "Shedinja", [293] = "Whismur", [294] = "Loudred", [295] = "Exploud",
        [296] = "Makuhita", [297] = "Hariyama", [298] = "Azurill", [299] = "Nosepass", [300] = "Skitty",
        [301] = "Delcatty", [302] = "Sableye", [303] = "Mawile", [304] = "Aron", [305] = "Lairon",
        [306] = "Aggron", [307] = "Meditite", [308] = "Medicham", [309] = "Electrike", [310] = "Manectric",
        [311] = "Plusle", [312] = "Minun", [313] = "Volbeat", [314] = "Illumise", [315] = "Roselia",
        [316] = "Gulpin", [317] = "Swalot", [318] = "Carvanha", [319] = "Sharpedo", [320] = "Wailmer",
        [321] = "Wailord", [322] = "Numel", [323] = "Camerupt", [324] = "Torkoal", [325] = "Spoink",
        [326] = "Grumpig", [327] = "Spinda", [328] = "Trapinch", [329] = "Vibrava", [330] = "Flygon",
        [331] = "Cacnea", [332] = "Cacturne", [333] = "Swablu", [334] = "Altaria", [335] = "Zangoose",
        [336] = "Seviper", [337] = "Lunatone", [338] = "Solrock", [339] = "Barboach", [340] = "Whiscash",
        [341] = "Corphish", [342] = "Crawdaunt", [343] = "Baltoy", [344] = "Claydol", [345] = "Lileep",
        [346] = "Cradily", [347] = "Anorith", [348] = "Armaldo", [349] = "Feebas", [350] = "Milotic",
        [351] = "Castform", [352] = "Kecleon", [353] = "Shuppet", [354] = "Banette", [355] = "Duskull",
        [356] = "Dusclops", [357] = "Tropius", [358] = "Chimecho", [359] = "Absol", [360] = "Wynaut",
        [361] = "Snorunt", [362] = "Glalie", [363] = "Spheal", [364] = "Sealeo", [365] = "Walrein",
        [366] = "Clamperl", [367] = "Huntail", [368] = "Gorebyss", [369] = "Relicanth", [370] = "Luvdisc",
        [371] = "Bagon", [372] = "Shelgon", [373] = "Salamence", [374] = "Beldum", [375] = "Metang",
        [376] = "Metagross", [377] = "Regirock", [378] = "Regice", [379] = "Registeel", [380] = "Latias",
        [381] = "Latios", [382] = "Kyogre", [383] = "Groudon", [384] = "Rayquaza", [385] = "Jirachi",
        [386] = "Deoxys", [387] = "Turtwig", [388] = "Grotle", [389] = "Torterra", [390] = "Chimchar",
        [391] = "Monferno", [392] = "Infernape", [393] = "Piplup", [394] = "Prinplup", [395] = "Empoleon",
        [396] = "Starly", [397] = "Staravia", [398] = "Staraptor", [399] = "Bidoof", [400] = "Bibarel",
        [401] = "Kricketot", [402] = "Kricketune", [403] = "Shinx", [404] = "Luxio", [405] = "Luxray",
        [406] = "Budew", [407] = "Roserade", [408] = "Cranidos", [409] = "Rampardos", [410] = "Shieldon",
        [411] = "Bastiodon", [0] = "None"
    },
    
    moves = {
        [1] = "Pound", [2] = "Karate Chop", [3] = "DoubleSlap", [4] = "Comet Punch", [5] = "Mega Punch",
        [6] = "Pay Day", [7] = "Fire Punch", [8] = "Ice Punch", [9] = "ThunderPunch", [10] = "Scratch",
        [11] = "ViceGrip", [12] = "Guillotine", [13] = "Razor Wind", [14] = "Swords Dance", [15] = "Cut",
        [16] = "Gust", [17] = "Wing Attack", [18] = "Whirlwind", [19] = "Fly", [20] = "Bind",
        [21] = "Slam", [22] = "Vine Whip", [23] = "Stomp", [24] = "Double Kick", [25] = "Mega Kick",
        [26] = "Jump Kick", [27] = "Rolling Kick", [28] = "Sand-Attack", [29] = "Headbutt", [30] = "Horn Attack",
        [31] = "Fury Attack", [32] = "Horn Drill", [33] = "Tackle", [34] = "Body Slam", [35] = "Wrap",
        [36] = "Take Down", [37] = "Thrash", [38] = "Double-Edge", [39] = "Tail Whip", [40] = "Poison Sting",
        [41] = "Twineedle", [42] = "Pin Missile", [43] = "Leer", [44] = "Bite", [45] = "Growl",
        [46] = "Roar", [47] = "Sing", [48] = "Supersonic", [49] = "SonicBoom", [50] = "Disable",
        [51] = "Acid", [52] = "Ember", [53] = "Flamethrower", [54] = "Mist", [55] = "Water Gun",
        [56] = "Hydro Pump", [57] = "Surf", [58] = "Ice Beam", [59] = "Blizzard", [60] = "Psybeam",
        [61] = "BubbleBeam", [62] = "Aurora Beam", [63] = "Hyper Beam", [64] = "Peck", [65] = "Drill Peck",
        [66] = "Submission", [67] = "Low Kick", [68] = "Counter", [69] = "Seismic Toss", [70] = "Strength",
        [71] = "Absorb", [72] = "Mega Drain", [73] = "Leech Seed", [74] = "Growth", [75] = "Razor Leaf",
        [76] = "SolarBeam", [77] = "PoisonPowder", [78] = "Stun Spore", [79] = "Sleep Powder", [80] = "Petal Dance",
        [81] = "String Shot", [82] = "Dragon Rage", [83] = "Fire Spin", [84] = "ThunderShock", [85] = "Thunderbolt",
        [86] = "Thunder Wave", [87] = "Thunder", [88] = "Rock Throw", [89] = "Earthquake", [90] = "Fissure",
        [91] = "Dig", [92] = "Toxic", [93] = "Confusion", [94] = "Psychic", [95] = "Hypnosis",
        [96] = "Meditate", [97] = "Agility", [98] = "Quick Attack", [99] = "Rage", [100] = "Teleport",
        [0] = "None"
    },
    
    types = {
        [0] = "Normal", [1] = "Fighting", [2] = "Flying", [3] = "Poison", [4] = "Ground",
        [5] = "Rock", [6] = "Bug", [7] = "Ghost", [8] = "Steel", [9] = "???",
        [10] = "Fire", [11] = "Water", [12] = "Grass", [13] = "Electric", [14] = "Psychic",
        [15] = "Ice", [16] = "Dragon", [17] = "Dark"
    },
    
    natures = {
        [0] = "Hardy", [1] = "Lonely", [2] = "Brave", [3] = "Adamant", [4] = "Naughty",
        [5] = "Bold", [6] = "Docile", [7] = "Relaxed", [8] = "Impish", [9] = "Lax",
        [10] = "Timid", [11] = "Hasty", [12] = "Serious", [13] = "Jolly", [14] = "Naive",
        [15] = "Modest", [16] = "Mild", [17] = "Quiet", [18] = "Bashful", [19] = "Rash",
        [20] = "Calm", [21] = "Gentle", [22] = "Sassy", [23] = "Careful", [24] = "Quirky"
    },
    
    abilities = {
        [1] = "Stench", [2] = "Drizzle", [3] = "Speed Boost", [4] = "Battle Armor", [5] = "Sturdy",
        [6] = "Damp", [7] = "Limber", [8] = "Sand Veil", [9] = "Static", [10] = "Volt Absorb",
        [11] = "Water Absorb", [12] = "Oblivious", [13] = "Cloud Nine", [14] = "Compound Eyes", [15] = "Insomnia",
        [16] = "Color Change", [17] = "Immunity", [18] = "Flash Fire", [19] = "Shield Dust", [20] = "Own Tempo",
        [21] = "Suction Cups", [22] = "Intimidate", [23] = "Shadow Tag", [24] = "Rough Skin", [25] = "Wonder Guard",
        [26] = "Levitate", [27] = "Effect Spore", [28] = "Synchronize", [29] = "Clear Body", [30] = "Natural Cure",
        [31] = "Lightning Rod", [32] = "Serene Grace", [33] = "Swift Swim", [34] = "Chlorophyll", [35] = "Illuminate",
        [36] = "Trace", [37] = "Huge Power", [38] = "Poison Point", [39] = "Inner Focus", [40] = "Magma Armor",
        [41] = "Water Veil", [42] = "Magnet Pull", [43] = "Soundproof", [44] = "Rain Dish", [45] = "Sand Stream",
        [46] = "Pressure", [47] = "Thick Fat", [48] = "Early Bird", [49] = "Flame Body", [50] = "Run Away",
        [51] = "Keen Eye", [52] = "Hyper Cutter", [53] = "Pickup", [54] = "Truant", [55] = "Hustle",
        [56] = "Cute Charm", [57] = "Plus", [58] = "Minus", [59] = "Forecast", [60] = "Sticky Hold",
        [61] = "Shed Skin", [62] = "Guts", [63] = "Marvel Scale", [64] = "Liquid Ooze", [65] = "Overgrow",
        [66] = "Blaze", [67] = "Torrent", [68] = "Swarm", [69] = "Rock Head", [70] = "Drought",
        [71] = "Arena Trap", [72] = "Vital Spirit", [73] = "White Smoke", [74] = "Pure Power", [75] = "Shell Armor",
        [76] = "Air Lock", [0] = "None"
    }
}

-- Storage for loaded data
ROMData.data = {
    pokemon = nil,
    moves = nil,
    items = nil,
    abilities = nil,
    natures = nil,
    types = nil,
    typeChart = nil,
    initialized = false,
    patchInfo = nil
}

-- Initialize all ROM data
function ROMData.init()
    if ROMData.data.initialized then
        return true
    end
    
    console.log("Loading ROM data...")
    console.log("Initializing ROM data...")
    console.log("Detecting ROM type...")
    
    -- Check for patches
    ROMData.data.patchInfo = ROMData.detectPatch()
    if ROMData.data.patchInfo then
        console.log("✓ Detected " .. ROMData.data.patchInfo.type .. " patch")
    end
    
    -- Load static data
    ROMData.data.pokemon = ROMData.loadPokemonData()
    ROMData.data.moves = ROMData.loadMoveData()
    ROMData.data.items = ROMData.loadItemData()
    ROMData.data.abilities = ROMData.loadAbilityNames()
    ROMData.data.natures = ROMData.loadNatureData()
    ROMData.data.types = ROMData.loadTypeNames()
    ROMData.data.typeChart = ROMData.loadTypeChart()
    
    ROMData.data.initialized = true
    console.log("ROM data initialized successfully")
    console.log("ROM Type: " .. (ROMData.data.patchInfo and "patched" or "vanilla"))
    
    if ROMData.addresses.pokemonStats then
        console.log("Using Pokemon data at: 0x" .. string.format("%08X", ROMData.addresses.pokemonStats))
    end
    
    return true
end

-- ENHANCED NAME GETTERS WITH FALLBACKS

-- Enhanced Pokemon name getter (fixes species display)
function ROMData.getPokemonName(speciesId)
    if not speciesId or speciesId < 0 or speciesId > 411 then
        return "???"
    end
    
    -- Try ROM data first
    if ROMData.data.initialized and ROMData.data.pokemon and ROMData.data.pokemon[speciesId] then
        local pokemon = ROMData.data.pokemon[speciesId]
        if pokemon.name and pokemon.name ~= "" and not pokemon.name:match("^%s*$") then
            return pokemon.name
        end
    end
    
    -- Use fallback names
    if ROMData.fallbackNames.pokemon[speciesId] then
        return ROMData.fallbackNames.pokemon[speciesId]
    end
    
    -- Last resort
    return "Pokemon #" .. string.format("%03d", speciesId)
end

-- Enhanced move name getter with fallback  
function ROMData.getMoveName(moveId)
    if not moveId or moveId < 0 then
        return "None"
    end
    
    -- Try ROM first if address exists
    if ROMData.data.initialized and ROMData.data.moves and ROMData.data.moves[moveId] then
        local move = ROMData.data.moves[moveId]
        if move.name and move.name ~= "" and not move.name:match("^%s*$") then
            return move.name
        end
    end
    
    -- Use fallback names
    if ROMData.fallbackNames.moves[moveId] then
        return ROMData.fallbackNames.moves[moveId]
    end
    
    -- Generic fallback
    return "Move #" .. string.format("%03d", moveId)
end

-- Enhanced type name getter (fixes "nil" types)
function ROMData.getTypeName(typeId)
    if not typeId or typeId < 0 or typeId > 17 then
        return "???"
    end
    
    -- Use fallback first (more reliable for patched ROMs)
    if ROMData.fallbackNames.types[typeId] then
        return ROMData.fallbackNames.types[typeId]
    end
    
    -- Try ROM data as backup
    if ROMData.data.initialized and ROMData.data.types and ROMData.data.types[typeId] then
        local romName = ROMData.data.types[typeId]
        if romName and romName ~= "" then
            return romName
        end
    end
    
    return "???"
end

-- Enhanced ability name getter (fixes "None" abilities)
function ROMData.getAbilityName(abilityId)
    if not abilityId or abilityId <= 0 then
        return "None"
    end
    
    -- Use fallback first
    if ROMData.fallbackNames.abilities[abilityId] then
        return ROMData.fallbackNames.abilities[abilityId]
    end
    
    -- Try ROM data as backup
    if ROMData.data.initialized and ROMData.data.abilities and ROMData.data.abilities[abilityId] then
        local romName = ROMData.data.abilities[abilityId]
        if romName and romName ~= "" then
            return romName
        end
    end
    
    return "Ability #" .. abilityId
end

-- Enhanced nature name getter (fixes "ROC" corruption)
function ROMData.getNatureName(natureId)
    if not natureId or natureId < 0 or natureId > 24 then
        return "???"
    end
    
    -- Use fallback first (more reliable)
    if ROMData.fallbackNames.natures[natureId] then
        return ROMData.fallbackNames.natures[natureId]
    end
    
    -- Try ROM data as backup
    if ROMData.data.initialized and ROMData.data.natures and ROMData.data.natures[natureId] then
        local romNature = ROMData.data.natures[natureId]
        if romNature and romNature.name and romNature.name ~= "" then
            return romNature.name
        end
    end
    
    return "Nature #" .. natureId
end

-- Enhanced item getter (fixes "Unknown" items)
function ROMData.getItemName(itemId)
    if not itemId or itemId <= 0 then
        return "None"
    end
    
    -- Try ROM data first for items (since we don't have comprehensive item fallbacks)
    if ROMData.data.initialized and ROMData.data.items and ROMData.data.items[itemId] then
        local item = ROMData.data.items[itemId]
        if item and item.name and item.name ~= "" then
            return item.name
        end
    end
    
    return "Item #" .. itemId
end

-- Load Pokemon base stats and data
function ROMData.loadPokemonData()
    local data = {}
    local baseAddr = ROMData.addresses.pokemonStats
    
    if not baseAddr then
        console.log("⚠ Pokemon stats address not found")
        return data
    end
    
    console.log("✓ Loaded patched ROM memory map")
    
    -- Load base stats for all 411 Pokemon (including ???/Egg)
    for i = 0, 410 do
        local addr = baseAddr + (i * 28)  -- Each Pokemon is 28 bytes
        
        local pokemon = {
            -- Stats
            stats = {
                hp = Memory.read_u8(addr + 0),
                attack = Memory.read_u8(addr + 1),
                defense = Memory.read_u8(addr + 2),
                speed = Memory.read_u8(addr + 3),
                spAttack = Memory.read_u8(addr + 4),
                spDefense = Memory.read_u8(addr + 5)
            },
            
            -- Type
            type1 = Memory.read_u8(addr + 6),
            type2 = Memory.read_u8(addr + 7),
            
            -- Misc data
            catchRate = Memory.read_u8(addr + 8),
            expYield = Memory.read_u8(addr + 9),
            evYield = Memory.read_u16_le(addr + 10),
            
            -- Held items
            item1 = Memory.read_u16_le(addr + 12),
            item2 = Memory.read_u16_le(addr + 14),
            
            -- Gender ratio (0 = always male, 254 = always female, 255 = genderless)
            genderRatio = Memory.read_u8(addr + 16),
            
            -- Breeding
            eggCycles = Memory.read_u8(addr + 17),
            baseFriendship = Memory.read_u8(addr + 18),
            growthRate = Memory.read_u8(addr + 19),
            eggGroup1 = Memory.read_u8(addr + 20),
            eggGroup2 = Memory.read_u8(addr + 21),
            
            -- Abilities
            ability1 = Memory.read_u8(addr + 22),
            ability2 = Memory.read_u8(addr + 23),
            
            -- Safari Zone
            safariRate = Memory.read_u8(addr + 24),
            
            -- Pokedex color
            color = Memory.read_u8(addr + 25),
            
            -- Use enhanced name getter (with fallback)
            name = ROMData.getPokemonName(i)
        }
        
        -- Calculate base stat total
        if pokemon.stats.hp then
            pokemon.bst = pokemon.stats.hp + pokemon.stats.attack + pokemon.stats.defense +
                         pokemon.stats.speed + pokemon.stats.spAttack + pokemon.stats.spDefense
        else
            pokemon.bst = 0
        end
        
        data[i] = pokemon
    end
    
    -- Try to load Pokemon names from ROM (may fail for patched ROMs)
    if ROMData.addresses.pokemonNames then
        console.log("✓ Loading Pokemon names from ROM")
        local nameAddr = ROMData.addresses.pokemonNames
        for i = 0, 410 do
            local name = ROMData.readPokemonString(nameAddr + (i * 11), 11)
            if data[i] and name and name ~= "" then
                data[i].name = name
            end
        end
    else
        console.log("⚠ Pokemon names address not found")
        console.log("Using loaded patched addresses")
    end
    
    return data
end

-- Load move data
function ROMData.loadMoveData()
    local data = {}
    local baseAddr = ROMData.addresses.moveData
    
    if not baseAddr then
        console.log("⚠ Move data address not found")
        return data
    end
    
    -- Load data for all 355 moves
    for i = 0, 354 do
        local addr = baseAddr + (i * 12)  -- Each move is 12 bytes
        
        local move = {
            effect = Memory.read_u8(addr + 0),
            power = Memory.read_u8(addr + 1),
            type = Memory.read_u8(addr + 2),
            accuracy = Memory.read_u8(addr + 3),
            pp = Memory.read_u8(addr + 4),
            effectChance = Memory.read_u8(addr + 5),
            target = Memory.read_u8(addr + 6),
            priority = Memory.read_s8(addr + 7),  -- Signed
            flags = Memory.read_u8(addr + 8),
            argument = Memory.read_u8(addr + 9),
            -- Padding: 2 bytes
            
            -- Use enhanced name getter (with fallback)
            name = ROMData.getMoveName(i)
        }
        
        -- Decode flags
        if move.flags then
            move.makesContact = band(move.flags, 0x01) ~= 0
            move.isProtectable = band(move.flags, 0x02) ~= 0
            move.isMagicCoatAffected = band(move.flags, 0x04) ~= 0
            move.isSnatchable = band(move.flags, 0x08) ~= 0
            move.canMetronome = band(move.flags, 0x10) ~= 0
            move.cannotSketch = band(move.flags, 0x20) ~= 0
        end
        
        data[i] = move
    end
    
    -- Try to load move names from ROM (may fail for patched ROMs)
    if ROMData.addresses.moveNames then
        console.log("✓ Loading move names from ROM")
        local nameAddr = ROMData.addresses.moveNames
        for i = 0, 354 do
            local name = ROMData.readPokemonString(nameAddr + (i * 13), 13)
            if data[i] and name and name ~= "" then
                data[i].name = name
            end
        end
    else
        console.log("⚠ Move names address not found")
    end
    
    return data
end

-- Load item data
function ROMData.loadItemData()
    local data = {}
    local baseAddr = ROMData.addresses.itemData
    
    if not baseAddr then
        console.log("✗ Item data address not found")
        return data
    end
    
    -- Load data for items (up to 377 in Emerald)
    for i = 0, 376 do
        local addr = baseAddr + (i * 44)  -- Each item is 44 bytes
        
        local item = {
            name = ROMData.readPokemonString(addr + 0, 14),
            index = Memory.read_u16_le(addr + 14),
            price = Memory.read_u16_le(addr + 16),
            holdEffect = Memory.read_u8(addr + 18),
            parameter = Memory.read_u8(addr + 19),
            description = Memory.read_u32_le(addr + 20),  -- Pointer to description
            mysteryValue = Memory.read_u16_le(addr + 24),
            pocket = Memory.read_u8(addr + 26),
            type = Memory.read_u8(addr + 27),
            fieldEffect = Memory.read_u32_le(addr + 28),  -- Pointer
            battleUsage = Memory.read_u32_le(addr + 32),  -- Pointer
            battleEffect = Memory.read_u32_le(addr + 36), -- Pointer
            extraParameter = Memory.read_u32_le(addr + 40) -- Pointer
        }
        
        data[i] = item
    end
    
    return data
end

-- Load ability names
function ROMData.loadAbilityNames()
    local data = {}
    local baseAddr = ROMData.addresses.abilityNames
    
    if not baseAddr then
        console.log("⚠ Ability names address not found")
        return data
    end
    
    -- Load 78 abilities (0-77)
    for i = 0, 77 do
        local name = ROMData.readPokemonString(baseAddr + (i * 13), 13)
        data[i] = name
    end
    
    return data
end

-- Load nature data
function ROMData.loadNatureData()
    local data = {}
    local nameAddr = ROMData.addresses.natureNames
    
    if not nameAddr then
        console.log("⚠ Nature names address not found")
    end
    
    -- Nature stat modifiers (hardcoded in game)
    local natureModifiers = {
        -- [increased stat][decreased stat] = nature index
        [1] = {[2] = 0, [3] = 1, [4] = 2, [5] = 3},  -- Attack+
        [2] = {[1] = 4, [3] = 5, [4] = 6, [5] = 7},  -- Defense+
        [3] = {[1] = 8, [2] = 9, [4] = 10, [5] = 11}, -- Speed+
        [4] = {[1] = 12, [2] = 13, [3] = 14, [5] = 15}, -- Sp.Atk+
        [5] = {[1] = 16, [2] = 17, [3] = 18, [4] = 19}  -- Sp.Def+
    }
    
    -- Load 25 natures
    for i = 0, 24 do
        local name = "Unknown"
        
        if nameAddr then
            name = ROMData.readPokemonString(nameAddr + (i * 7), 7)
        end
        
        -- Use fallback if ROM name is empty
        if not name or name == "" then
            name = ROMData.fallbackNames.natures[i] or "Nature #" .. i
        end
        
        -- Calculate stat modifiers
        local increased = nil
        local decreased = nil
        
        -- Find which stats are affected
        for inc = 1, 5 do
            for dec = 1, 5 do
                if natureModifiers[inc] and natureModifiers[inc][dec] == i then
                    increased = inc
                    decreased = dec
                    break
                end
            end
        end
        
        data[i] = {
            name = name,
            increased = increased,  -- 1=Atk, 2=Def, 3=Spe, 4=SpA, 5=SpD
            decreased = decreased   -- Same indices
        }
    end
    
    return data
end

-- Load type names
function ROMData.loadTypeNames()
    local data = {}
    local baseAddr = ROMData.addresses.typeNames
    
    if not baseAddr then
        console.log("⚠ Type names address not found")
        return data
    end
    
    -- Load 18 types (includes ???)
    for i = 0, 17 do
        local name = ROMData.readPokemonString(baseAddr + (i * 7), 7)
        data[i] = name
    end
    
    return data
end

-- Load type effectiveness chart
function ROMData.loadTypeChart()
    local data = {}
    local baseAddr = ROMData.addresses.typeEffectiveness
    
    if not baseAddr then
        console.log("⚠ Type effectiveness address not found")
        return data
    end
    
    -- Read type chart until terminator
    local offset = 0
    while true do
        local attacker = Memory.read_u8(baseAddr + offset)
        local defender = Memory.read_u8(baseAddr + offset + 1)
        local effectiveness = Memory.read_u8(baseAddr + offset + 2)
        
        -- Terminator: 0xFE 0xFE 0x00
        if attacker == 0xFE and defender == 0xFE then
            break
        end
        
        -- Store effectiveness
        if not data[attacker] then
            data[attacker] = {}
        end
        data[attacker][defender] = effectiveness
        
        offset = offset + 3
    end
    
    return data
end

-- Read Pokemon text encoding
function ROMData.readPokemonString(addr, maxLength)
    local str = ""
    for i = 0, maxLength - 1 do
        local char = Memory.read_u8(addr + i)
        if char == 0xFF then break end  -- Terminator
        
        -- Basic character mapping (simplified)
        if char == 0x00 then
            str = str .. " "
        elseif char >= 0xBB and char <= 0xD4 then
            str = str .. string.char(char - 0xBB + 65)  -- A-Z
        elseif char >= 0xD5 and char <= 0xEE then
            str = str .. string.char(char - 0xD5 + 97)  -- a-z
        elseif char >= 0xA1 and char <= 0xAA then
            str = str .. string.char(char - 0xA1 + 48)  -- 0-9
        elseif char == 0xAE then
            str = str .. "-"
        elseif char == 0xAF then
            str = str .. "."
        elseif char == 0xB0 then
            str = str .. "..."  -- Ellipsis
        elseif char == 0xB1 then
            str = str .. "\""   -- Left double quote
        elseif char == 0xB2 then
            str = str .. "\""   -- Right double quote
        elseif char == 0xB3 then
            str = str .. "'"    -- Left single quote
        elseif char == 0xB4 then
            str = str .. "'"    -- Right single quote
        elseif char == 0xB5 then
            str = str .. "M"    -- Male symbol
        elseif char == 0xB6 then
            str = str .. "F"    -- Female symbol
        elseif char == 0xBA then
            str = str .. "e"    -- e with accent
        end
    end
    return str
end

-- Detect ROM patches
function ROMData.detectPatch()
    local patches = {
        -- Common patch signatures and locations
        {addr = 0x08F00000, name = "Archipelago", sig = "ARCH"},
        {addr = 0x08E00000, name = "Randomizer", sig = "RAND"},
        {addr = 0x08D00000, name = "Custom", sig = nil}
    }
    
    for _, patch in ipairs(patches) do
        local data = Memory.readbytes(patch.addr, 16)
        if data and data[1] ~= 0xFF then  -- Not empty ROM space
            -- Check for signature if specified
            if patch.sig then
                local sig = ""
                for i = 1, #patch.sig do
                    sig = sig .. string.char(data[i] or 0)
                end
                if sig == patch.sig then
                    return {
                        type = patch.name,
                        address = patch.addr,
                        signature = sig
                    }
                end
            else
                -- No specific signature, just check for data
                return {
                    type = patch.name,
                    address = patch.addr,
                    signature = "Unknown"
                }
            end
        end
    end
    
    return nil
end

-- MAIN GETTER FUNCTIONS (enhanced with fallbacks)

-- Get Pokemon with proper name
function ROMData.getPokemon(species)
    if not ROMData.data.initialized then ROMData.init() end
    local pokemon = ROMData.data.pokemon and ROMData.data.pokemon[species]
    
    -- Ensure the pokemon has a proper name
    if pokemon then
        pokemon.name = ROMData.getPokemonName(species)
    end
    
    return pokemon
end

-- Get move with proper name
function ROMData.getMove(moveId)
    if not ROMData.data.initialized then ROMData.init() end
    local move = ROMData.data.moves and ROMData.data.moves[moveId]
    
    -- Ensure the move has a proper name
    if move then
        move.name = ROMData.getMoveName(moveId)
    end
    
    return move
end

-- Get item with proper name
function ROMData.getItem(itemId)
    if not ROMData.data.initialized then ROMData.init() end
    local item = ROMData.data.items and ROMData.data.items[itemId]
    
    -- Add name if missing
    if item and (not item.name or item.name == "") then
        item.name = ROMData.getItemName(itemId)
    end
    
    return item
end

-- Get nature with proper name
function ROMData.getNature(natureId)
    if not ROMData.data.initialized then ROMData.init() end
    local nature = ROMData.data.natures and ROMData.data.natures[natureId]
    
    -- Ensure nature has proper name
    if nature then
        nature.name = ROMData.getNatureName(natureId)
    else
        -- Create a basic nature object
        nature = {
            name = ROMData.getNatureName(natureId),
            increased = nil,
            decreased = nil
        }
    end
    
    return nature
end

-- Get type effectiveness
function ROMData.getTypeEffectiveness(attackType, defenseType)
    if not ROMData.data.initialized then ROMData.init() end
    
    if ROMData.data.typeChart[attackType] then
        return ROMData.data.typeChart[attackType][defenseType] or 10  -- Default to normal damage
    end
    return 10
end

-- Test function
function ROMData.test()
    console.log("=== ROM Data Module Test ===\n")
    
    -- Initialize
    ROMData.init()
    
    -- Test Pokemon data
    console.log("Pokemon data test:")
    local bulbasaur = ROMData.getPokemon(1)
    if bulbasaur then
        console.log(string.format("✓ #001 %s", bulbasaur.name or "???"))
        console.log(string.format("  BST: %d (HP:%d ATK:%d DEF:%d SPE:%d SPA:%d SPD:%d)",
            bulbasaur.bst,
            bulbasaur.stats.hp,
            bulbasaur.stats.attack,
            bulbasaur.stats.defense,
            bulbasaur.stats.speed,
            bulbasaur.stats.spAttack,
            bulbasaur.stats.spDefense
        ))
        console.log(string.format("  Types: %s/%s", 
            ROMData.getTypeName(bulbasaur.type1) or "???",
            bulbasaur.type1 == bulbasaur.type2 and "—" or (ROMData.getTypeName(bulbasaur.type2) or "???")))
    else
        console.log("✗ Failed to load Pokemon data")
    end
    
    -- Test move data
    console.log("\nMove data test:")
    local tackle = ROMData.getMove(33)  -- Tackle
    if tackle then
        console.log(string.format("✓ Move #33: %s", tackle.name or "???"))
        console.log(string.format("  Power: %d, Accuracy: %d, PP: %d",
            tackle.power, tackle.accuracy, tackle.pp))
        console.log(string.format("  Type: %s", ROMData.getTypeName(tackle.type) or "???"))
    else
        console.log("✗ Failed to load move data")
    end
    
    -- Test fallback system
    console.log("\nFallback system test:")
    console.log("Pokemon #1: " .. ROMData.getPokemonName(1))
    console.log("Move #1: " .. ROMData.getMoveName(1))
    console.log("Type #0: " .. ROMData.getTypeName(0))
    console.log("Nature #0: " .. ROMData.getNatureName(0))
    
    -- Test patch detection
    console.log("\nPatch detection:")
    if ROMData.data.patchInfo then
        console.log(string.format("✓ Patch detected: %s at 0x%08X", 
            ROMData.data.patchInfo.type,
            ROMData.data.patchInfo.address))
    else
        console.log("✓ No patches detected (vanilla ROM)")
    end
end

return ROMData
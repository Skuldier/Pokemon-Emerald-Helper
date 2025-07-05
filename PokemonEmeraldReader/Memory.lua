-- Memory.lua
-- Core memory access module for Pokemon Emerald in BizHawk
-- Handles domain routing, EWRAM limitations, and safe reading

local Memory = {}

-- Memory domain mapping based on GBA memory map
Memory.domains = {
    [0x00] = "BIOS",       -- 00000000-00003FFF (16KB)
    [0x02] = "EWRAM",      -- 02000000-0203FFFF (256KB, but BizHawk only exposes 32KB)
    [0x03] = "IWRAM",      -- 03000000-03007FFF (32KB)
    [0x04] = "I/O",        -- 04000000-040003FF (1KB)
    [0x05] = "BG/OBJ RAM", -- 05000000-050003FF (1KB) 
    [0x06] = "VRAM",       -- 06000000-06017FFF (96KB)
    [0x07] = "OAM",        -- 07000000-070003FF (1KB)
    [0x08] = "ROM",        -- 08000000-09FFFFFF (32MB)
    [0x09] = "ROM",
    [0x0A] = "ROM",
    [0x0B] = "ROM",
    [0x0C] = "ROM",
    [0x0D] = "ROM",
    [0x0E] = "Cart RAM"    -- 0E000000-0E00FFFF (64KB)
}

-- Configuration
Memory.USE_SYSTEM_BUS_FALLBACK = true
Memory.EWRAM_BIZHAWK_LIMIT = 0x02008000  -- BizHawk only exposes up to this address

-- Statistics tracking
Memory.stats = {
    reads = 0,
    failures = 0,
    systemBusFallbacks = 0
}

-- Get the appropriate memory domain for an address
function Memory.getDomain(addr)
    if not addr then return nil end
    
    local domain = bit.rshift(addr, 24)
    return Memory.domains[domain]
end

-- Check if address requires System Bus (beyond BizHawk's EWRAM limit)
function Memory.requiresSystemBus(addr)
    local domain = Memory.getDomain(addr)
    return domain == "EWRAM" and addr >= Memory.EWRAM_BIZHAWK_LIMIT
end

-- Safe read with automatic domain selection and fallback
function Memory.read_u8(addr)
    if not addr then return nil end
    
    Memory.stats.reads = Memory.stats.reads + 1
    
    -- Determine domain
    local domain = Memory.getDomain(addr)
    if not domain then
        Memory.stats.failures = Memory.stats.failures + 1
        return nil
    end
    
    -- Check if we need System Bus for EWRAM beyond 32KB
    if Memory.requiresSystemBus(addr) then
        domain = "System Bus"
        Memory.stats.systemBusFallbacks = Memory.stats.systemBusFallbacks + 1
    end
    
    -- Try primary domain
    local success, value = pcall(memory.read_u8, addr, domain)
    if success and value then 
        return value 
    end
    
    -- Fallback to System Bus if enabled
    if Memory.USE_SYSTEM_BUS_FALLBACK and domain ~= "System Bus" then
        Memory.stats.systemBusFallbacks = Memory.stats.systemBusFallbacks + 1
        success, value = pcall(memory.read_u8, addr, "System Bus")
        if success and value then
            return value
        end
    end
    
    Memory.stats.failures = Memory.stats.failures + 1
    return nil
end

-- Read unsigned 16-bit little endian
function Memory.read_u16_le(addr)
    if not addr then return nil end
    
    Memory.stats.reads = Memory.stats.reads + 1
    
    local domain = Memory.getDomain(addr)
    if not domain then
        Memory.stats.failures = Memory.stats.failures + 1
        return nil
    end
    
    if Memory.requiresSystemBus(addr) then
        domain = "System Bus"
        Memory.stats.systemBusFallbacks = Memory.stats.systemBusFallbacks + 1
    end
    
    local success, value = pcall(memory.read_u16_le, addr, domain)
    if success and value then 
        return value 
    end
    
    if Memory.USE_SYSTEM_BUS_FALLBACK and domain ~= "System Bus" then
        Memory.stats.systemBusFallbacks = Memory.stats.systemBusFallbacks + 1
        success, value = pcall(memory.read_u16_le, addr, "System Bus")
        if success and value then
            return value
        end
    end
    
    Memory.stats.failures = Memory.stats.failures + 1
    return nil
end

-- Read unsigned 32-bit little endian
function Memory.read_u32_le(addr)
    if not addr then return nil end
    
    Memory.stats.reads = Memory.stats.reads + 1
    
    local domain = Memory.getDomain(addr)
    if not domain then
        Memory.stats.failures = Memory.stats.failures + 1
        return nil
    end
    
    if Memory.requiresSystemBus(addr) then
        domain = "System Bus"
        Memory.stats.systemBusFallbacks = Memory.stats.systemBusFallbacks + 1
    end
    
    local success, value = pcall(memory.read_u32_le, addr, domain)
    if success and value then 
        return value 
    end
    
    if Memory.USE_SYSTEM_BUS_FALLBACK and domain ~= "System Bus" then
        Memory.stats.systemBusFallbacks = Memory.stats.systemBusFallbacks + 1
        success, value = pcall(memory.read_u32_le, addr, "System Bus")
        if success and value then
            return value
        end
    end
    
    Memory.stats.failures = Memory.stats.failures + 1
    return nil
end

-- Read signed 8-bit
function Memory.read_s8(addr)
    local value = Memory.read_u8(addr)
    if not value then return nil end
    
    -- Convert to signed
    if value >= 0x80 then
        return value - 0x100
    end
    return value
end

-- Read signed 16-bit little endian
function Memory.read_s16_le(addr)
    local value = Memory.read_u16_le(addr)
    if not value then return nil end
    
    -- Convert to signed
    if value >= 0x8000 then
        return value - 0x10000
    end
    return value
end

-- Read signed 32-bit little endian
function Memory.read_s32_le(addr)
    local value = Memory.read_u32_le(addr)
    if not value then return nil end
    
    -- Convert to signed
    if value >= 0x80000000 then
        return value - 0x100000000
    end
    return value
end

-- Read array of bytes
function Memory.readbytes(addr, length)
    if not addr or not length or length <= 0 then 
        return nil 
    end
    
    local bytes = {}
    for i = 0, length - 1 do
        local byte = Memory.read_u8(addr + i)
        if byte then
            bytes[i + 1] = byte
        else
            -- Return partial read or nil based on configuration
            return nil
        end
    end
    return bytes
end

-- Read null-terminated string
function Memory.readstring(addr, maxLength)
    if not addr then return nil end
    
    maxLength = maxLength or 256
    local str = ""
    
    for i = 0, maxLength - 1 do
        local byte = Memory.read_u8(addr + i)
        if not byte or byte == 0 then
            break
        end
        str = str .. string.char(byte)
    end
    
    return str
end

-- Validate address is in readable range
function Memory.isValidAddress(addr)
    if not addr or type(addr) ~= "number" then
        return false
    end
    
    local domain = Memory.getDomain(addr)
    if not domain then
        return false
    end
    
    -- Check address ranges
    if domain == "EWRAM" then
        return addr >= 0x02000000 and addr < 0x02040000
    elseif domain == "IWRAM" then
        return addr >= 0x03000000 and addr < 0x03008000
    elseif domain == "ROM" then
        return addr >= 0x08000000 and addr < 0x0E000000
    elseif domain == "BIOS" then
        return addr >= 0x00000000 and addr < 0x00004000
    end
    
    return true
end

-- Get memory statistics
function Memory.getStats()
    return {
        reads = Memory.stats.reads,
        failures = Memory.stats.failures,
        systemBusFallbacks = Memory.stats.systemBusFallbacks,
        failureRate = Memory.stats.reads > 0 and 
                     (Memory.stats.failures / Memory.stats.reads * 100) or 0
    }
end

-- Reset statistics
function Memory.resetStats()
    Memory.stats.reads = 0
    Memory.stats.failures = 0
    Memory.stats.systemBusFallbacks = 0
end

-- Test memory access
function Memory.test()
    console.log("=== Memory Module Test ===")
    
    -- Test BIOS read
    local biosTest = Memory.read_u32_le(0x00000000)
    console.log("BIOS read: " .. (biosTest and string.format("0x%08X", biosTest) or "FAILED"))
    
    -- Test IWRAM read
    local iwramTest = Memory.read_u32_le(0x03000000)
    console.log("IWRAM read: " .. (iwramTest and string.format("0x%08X", iwramTest) or "FAILED"))
    
    -- Test EWRAM within limit
    local ewramTest1 = Memory.read_u32_le(0x02000000)
    console.log("EWRAM (< 32KB) read: " .. (ewramTest1 and string.format("0x%08X", ewramTest1) or "FAILED"))
    
    -- Test EWRAM beyond limit (should use System Bus)
    local ewramTest2 = Memory.read_u32_le(0x02020000)
    console.log("EWRAM (> 32KB) read: " .. (ewramTest2 and string.format("0x%08X", ewramTest2) or "FAILED"))
    
    -- Test ROM read
    local romTest = Memory.read_u32_le(0x08000000)
    console.log("ROM read: " .. (romTest and string.format("0x%08X", romTest) or "FAILED"))
    
    -- Show statistics
    local stats = Memory.getStats()
    console.log(string.format("\nStats: %d reads, %d failures (%.1f%%), %d System Bus fallbacks",
        stats.reads, stats.failures, stats.failureRate, stats.systemBusFallbacks))
end

return Memory
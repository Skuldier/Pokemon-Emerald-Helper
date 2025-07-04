-- Reset Memory Domain Script
-- Run this FIRST to fix the EWRAM issue

print("=== Resetting Memory Domain ===")

-- Show current domain
if memory.getcurrentmemorydomain then
    print("Current domain: " .. memory.getcurrentmemorydomain())
end

-- Get list of domains
if memory.getmemorydomainlist then
    local domains = memory.getmemorydomainlist()
    print("\nAvailable domains:")
    for _, domain in ipairs(domains) do
        print("  - " .. domain)
    end
    
    -- Switch to System Bus
    for _, domain in ipairs(domains) do
        if domain == "System Bus" or domain == "System" or domain == "Main Memory" then
            print("\nSwitching to: " .. domain)
            memory.usememorydomain(domain)
            print("Success! Domain is now: " .. memory.getcurrentmemorydomain())
            break
        end
    end
end

print("\n=== Testing memory reads ===")
-- Test reading with mainmemory
local test = mainmemory.read_u16_le(0x02024744)
print("mainmemory.read_u16_le(0x02024744) = " .. test)

print("\nDomain reset complete! You can now run the companion script.")
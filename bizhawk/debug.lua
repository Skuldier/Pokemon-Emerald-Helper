-- Socket Loading Debug Script
print("=== SOCKET DEBUG ===")

-- Check current directory
local pwd = (io.popen and io.popen("cd"):read'*l') or "."
print("Current directory: " .. pwd)

-- Check architecture
local arch = "x64"
if package.config:sub(1,1) == "\\" then
    local proc_arch = os.getenv("PROCESSOR_ARCHITECTURE")
    print("Processor architecture: " .. (proc_arch or "unknown"))
    if proc_arch and proc_arch:find("64") then
        arch = "x64"
    else
        arch = "x86"
    end
end

-- Check expected DLL path
local dll_name = "socket-windows-5-1.dll"
print("Looking for: " .. dll_name)
print("In directory: " .. pwd)

-- Try different paths
local paths_to_try = {
    pwd .. "/" .. dll_name,
    pwd .. "\\socket-windows-5-1.dll",
    "socket-windows-5-1.dll",
    "./socket-windows-5-1.dll",
    pwd .. "/x64/" .. dll_name,
    pwd .. "\\x64\\" .. dll_name,
}

print("\nTrying paths:")
for i, path in ipairs(paths_to_try) do
    print(i .. ": " .. path)
    local f = io.open(path, "rb")
    if f then
        print("   FOUND! File exists at this path")
        f:close()
        
        -- Try to load it
        local ok, result = pcall(package.loadlib, path, "luaopen_socket_core")
        if ok and result then
            print("   SUCCESS! Can load library")
            local socket_func = result
            local ok2, socket = pcall(socket_func)
            if ok2 then
                print("   LOADED! Socket version: " .. (socket._VERSION or "unknown"))
            else
                print("   ERROR calling luaopen: " .. tostring(socket))
            end
        else
            print("   ERROR loading: " .. tostring(result))
        end
    else
        print("   Not found")
    end
end

-- Try the socket.lua approach
print("\nTrying socket.lua method:")
local socket_path = pwd .. "/" .. dll_name
print("Attempting package.loadlib on: " .. socket_path)
local ok, func_or_err = pcall(package.loadlib, socket_path, "luaopen_socket_core")
if ok and func_or_err then
    print("loadlib succeeded, got function")
    local ok2, socket = pcall(func_or_err)
    if ok2 then
        print("SUCCESS! Socket loaded")
    else
        print("ERROR calling function: " .. tostring(socket))
    end
else
    print("ERROR in loadlib: " .. tostring(func_or_err))
end

-- Check if we're 32-bit BizHawk trying to load 64-bit DLL
print("\nBizHawk info:")
print("_VERSION: " .. _VERSION)
if jit then
    print("LuaJIT detected")
end
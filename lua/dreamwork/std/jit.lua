local glua_jit = jit

---@class dreamwork.std
local std = dreamwork.std

local raw = std.raw
local raw_type = raw.type

local debug = std.debug
local debug_fempty = debug.fempty
local debug_getfmain = debug.getfmain

local error = std.error


-- TODO: docs

--- [SHARED AND MENU]
---
--- The jit library is a standard Lua library which provides functions to manipulate the JIT compiler.
---
--- It"s a wrapper for the native jit library from LuaJIT.
---
---@class dreamwork.std.jit
---@field os "Windows" | "Linux" | "OSX" | "BSD" | "POSIX" | "Other" | string
---@field arch "x86" | "x64" | "arm" | "arm64" | "arm64be" | "ppc" | "ppc64" | "ppc64le" | "mips" | "mipsel" | "mips64" | "mips64el" | string
---@field version string The full name of the JIT compiler version.
---@field version_number integer The version of the JIT compiler.
---@field version_byte integer The version byte of the JIT compiler.
---@field edge boolean `true` if the JIT compiler is an edge version, `false` otherwise.
local jit = {}
std.jit = jit

jit.os = glua_jit.os or "unknown"
jit.arch = glua_jit.arch or "unknown"
jit.version = glua_jit.version or "unknown"

do

    ---@type integer
    local jit_version = glua_jit.version_num or 0
    jit.version_number = jit_version

    jit.edge = false

    if jit_version == 0 then
        jit.version_byte = 0
    elseif jit_version >= 20100 then
        jit.version_byte = 2
        jit.edge = true
    else
        jit.version_byte = 1
    end

end

jit.on = glua_jit.on or debug_fempty
jit.off = glua_jit.off or debug_fempty
jit.status = glua_jit.status or function() return false end

---@diagnostic disable-next-line: deprecated, undefined-field
jit.attach = glua_jit.attach or debug_fempty
jit.flush = glua_jit.flush or debug_fempty

if glua_jit.opt == nil then
    jit.options = debug_fempty
else
    jit.options = glua_jit.opt.start or debug_fempty
end

---@diagnostic disable-next-line: undefined-field
local util = glua_jit.util or {}

-- TODO: improve luals support

---@type fun( func: function, position?: integer ): table
local util_funcinfo = util.funcinfo

if jit.getfinfo == nil then

    function jit.getfinfo( location, position )
        if raw_type( location ) == "number" then
            location = debug_getfmain( location + 1 )
        end

        if location == nil then
            error( "function not found", 2 )
        end

        return util_funcinfo( location, position )
    end

end

if jit.getfbc == nil then

    ---@type fun( func: function, position?: integer ): integer, integer
    local util_funcbc = util.funcbc

    function jit.getfbc( location, position )
        if raw_type( location ) == "number" then
            location = debug_getfmain( location + 1 )
        end

        if location == nil then
            error( "function not found", 2 )
        end

        return util_funcbc( location, position )
    end

end

if jit.getfconst == nil then

    ---@type fun( func: function, index?: integer ): any
    local util_funck = util.funck

    function jit.getfconst( location, position )
        if raw_type( location ) == "number" then
            location = debug_getfmain( location + 1 )
        end

        if location == nil then
            error( "function not found", 2 )
        end

        return util_funck( location, position )
    end

end

if jit.getfupvalue == nil then

    ---@type fun( func: function, index?: integer ): string
    local util_funcuvname = util.funcuvname
    if util_funcuvname == nil then
        -- TODO: fallback
    else

        function jit.getfupvalue( location, position )
            if raw_type( location ) == "number" then
                location = debug_getfmain( location + 1 )
            end

            if location == nil then
                error( "function not found", 2 )
            end

            return util_funcuvname( location, position )
        end

    end

end

if util_funcinfo == nil then

    function jit.isFFI( fn )
        return fn ~= nil
    end

else

    --- [SHARED AND MENU]
    ---
    --- Checks if the given function is a FFI function.
    ---
    ---@param fn function The function to check.
    ---@return boolean is_ffi `true` if the function is a FFI function, `false` otherwise.
    function jit.isFFI( fn )
        local info = util_funcinfo( fn )
        return info ~= nil and info.ffid ~= nil
    end

end

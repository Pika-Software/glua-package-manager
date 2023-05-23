-- Libraries
local system = system
local string = string
local gpm = gpm
local jit = jit

-- Variables
local file_Exists = file.Exists
local MENU_DLL = MENU_DLL
local CLIENT = CLIENT
local type = type

-- https://wiki.facepunch.com/gmod/string.StartsWith
string.StartsWith = string.StartsWith or string.StartWith

-- https://wiki.facepunch.com/gmod/string.Split
function string.Split( str, separator )
    return string.Explode( separator, str, false )
end

-- https://wiki.facepunch.com/gmod/util.IsBinaryModuleInstalled
do

    local suffix = ( { "osx64", "osx", "linux64", "linux", "win64", "win32" } )[ ( system.IsWindows() and 4 or 0 ) + ( system.IsLinux() and 2 or 0 ) + ( jit.arch == "x86" and 1 or 0 ) + 1 ]
    local fmt = "lua/bin/gm" .. ( CLIENT and "cl" or "sv" ) .. "_%s_%s.dll"
    local fmt = "lua/bin/gm" .. ( ( CLIENT and not MENU_DLL ) and "cl" or "sv" ) .. "_%s_%s.dll"

    function util.IsBinaryModuleInstalled( name )
        gpm.ArgAssert( name, 1, "string" )

        if file_Exists( string.format( fmt, name, suffix ), "GAME" ) then
            return true
        end

        -- Edge case - on Linux 32-bit x86-64 branch, linux32 is also supported as a suffix
        if jit.versionnum ~= 20004 and jit.arch == "x86" and system.IsLinux() then
            return file_Exists( string.format( fmt, name, "linux32" ), "GAME" )
        end

        return false
    end

end

do

    local GetConVar = GetConVar

    -- https://wiki.facepunch.com/gmod/cvars.String
    function cvars.String( name, default )
        local convar = GetConVar( name )
        if convar ~= nil then
            return convar:GetString()
        end

        return default
    end

    -- https://wiki.facepunch.com/gmod/cvars.Number
    function cvars.Number( name, default )
        local convar = GetConVar( name )
        if convar ~= nil then
            return convar:GetFloat()
        end

        return default
    end

    -- https://wiki.facepunch.com/gmod/cvars.Bool
    function cvars.Bool( name, default )
        local convar = GetConVar( name )
        if convar ~= nil then
            return convar:GetBool()
        end

        return default
    end

end

-- https://wiki.facepunch.com/gmod/Global.IsColor
do

    local meta = FindMetaTable( "Color" )
    local getmetatable = getmetatable

    function IsColor( any )
        if getmetatable( any ) == meta then
            return true
        end

        if type( any ) == "table" then
            return type( any.r ) == "number" and type( any.g ) == "number" and type( any.b ) == "number"
        end

        return false
    end

end
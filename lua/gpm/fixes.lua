-- Libraries
local string = string
local table = table
local file = file
local gpm = gpm

-- Variables
local SERVER = SERVER

-- Global table
local gluaFixes = gpm.GLuaFixes
if not gluaFixes then
    gluaFixes = {}; gpm.GLuaFixes = gluaFixes
end

-- https://wiki.facepunch.com/gmod/string.StartsWith
string.StartsWith = string.StartsWith or string.StartWith

-- https://wiki.facepunch.com/gmod/string.Split
function string.Split( str, separator )
    return string.Explode( separator, str, false )
end

do

    local file_Exists = table.SetValue( gluaFixes, "file.Exists", file.Exists, true )
    local file_IsDir = table.SetValue( gluaFixes, "file.IsDir", file.IsDir, true )

    -- https://wiki.facepunch.com/gmod/file.IsDir
    function file.IsDir( filePath, gamePath )
        if SERVER then return file_IsDir( filePath, gamePath ) end
        if file_IsDir( filePath, gamePath ) then return true end

        local _, folders = file.Find( filePath .. "*", gamePath )
        if folders == nil or #folders == 0 then return false end

        local splits = string.Split( filePath, "/" )
        return table.HasIValue( folders, splits[ #splits ] )
    end

    -- https://wiki.facepunch.com/gmod/file.Exists
    function file.Exists( filePath, gamePath )
        if SERVER then return file_Exists( filePath, gamePath ) end
        if file_Exists( filePath, gamePath ) then return true end

        local files, folders = file.Find( filePath .. "*", gamePath )
        if not files or not folders then return false end
        if #files == 0 and #folders == 0 then return false end

        local splits = string.Split( filePath, "/" )
        local fileName = splits[ #splits ]

        return table.HasIValue( files, fileName ) or table.HasIValue( folders, fileName )
    end

    -- file.IsFile( filePath, gamePath )
    function file.IsFile( filePath, gamePath )
        if SERVER then
            return file_Exists( filePath, gamePath ) and not file_IsDir( filePath, gamePath )
        end

        if file_Exists( filePath, gamePath ) and not file_IsDir( filePath, gamePath ) then
            return true
        end

        local files, _ = file.Find( filePath .. "*", gamePath )
        if not files or #files == 0 then return false end
        local splits = string.Split( filePath, "/" )

        return table.HasIValue( files, splits[ #splits ] )
    end

end

-- https://wiki.facepunch.com/gmod/Global.CompileFile
do

    local _CompileFile = table.SetValue( gluaFixes, "CompileFile", CompileFile, true )
    local CompileString = CompileString

    function CompileFile( filePath )
        local f = file.Open( filePath, "r", gpm.LuaRealm )
        if not f then
            return _CompileFile( filePath )
        end

        local code = f:Read( f:Size() )
        f:Close()

        local func = CompileString( code, filePath, true )
        if not func then
            return _CompileFile( filePath )
        end

        return func
    end

end

-- https://wiki.facepunch.com/gmod/util.IsBinaryModuleInstalled
do

    local suffix = ( { "osx64", "osx", "linux64", "linux", "win64", "win32" } )[ ( system.IsWindows() and 4 or 0 ) + ( system.IsLinux() and 2 or 0 ) + ( jit.arch == "x86" and 1 or 0 ) + 1 ]
    local fmt = "lua/bin/gm" .. ( CLIENT and "cl" or "sv" ) .. "_%s_%s.dll"
    local fmt = "lua/bin/gm" .. ( ( CLIENT and not MENU_DLL ) and "cl" or "sv" ) .. "_%s_%s.dll"

    function util.IsBinaryModuleInstalled( name )
        gpm.ArgAssert( name, 1, "string" )

        if file.Exists( string.format( fmt, name, suffix ), "GAME" ) then
            return true
        end

        -- Edge case - on Linux 32-bit x86-64 branch, linux32 is also supported as a suffix
        if jit.versionnum ~= 20004 and jit.arch == "x86" and system.IsLinux() then
            return file.Exists( string.format( fmt, name, "linux32" ), "GAME" )
        end

        return false
    end

end

local GetConVar = GetConVar

-- https://wiki.facepunch.com/gmod/cvars.String
function cvars.String( name, default )
    local convar = GetConVar( name )
    if ( convar ~= nil ) then
        return convar:GetString()
    end

    return default
end

-- https://wiki.facepunch.com/gmod/cvars.Number
function cvars.Number( name, default )
    local convar = GetConVar( name )
    if ( convar ~= nil ) then
        return convar:GetFloat()
    end

    return default
end

-- https://wiki.facepunch.com/gmod/cvars.Bool
function cvars.Bool( name, default )
    local convar = GetConVar( name )
    if ( convar ~= nil ) then
        return convar:GetBool()
    end

    return default
end

-- https://wiki.facepunch.com/gmod/Global.IsColor
do

    local meta = FindMetaTable( "Color" )
    local getmetatable = getmetatable
    local type = type

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
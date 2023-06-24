AddCSLuaFile()

local MENU_DLL = MENU_DLL
local SysTime = SysTime
local SERVER = SERVER
local Color = Color
local error = error
local type = type

Msg( [[
    ____    _____    ___ ___
   /'_ `\ /\ '__`\ /' __` __`\
  /\ \L\ \\ \ \L\ \/\ \/\ \/\ \
  \ \____ \\ \ ,__/\ \_\ \_\ \_\
   \/___L\ \\ \ \/  \/_/\/_/\/_/
     /\____/ \ \_\
     \_/__/   \/_/

  GitHub: https://github.com/Pika-Software
  Discord: https://discord.gg/3UVxhZ
  Developers: Pika Software
  License: MIT

]] )

module( "gpm", package.seeall )

_VERSION = 013604

if not Colors then
    Realm = "unknown"
    Colors = {
        ["SecondaryText"] = Color( 150, 150, 150 ),
        ["PrimaryText"] = Color( 200, 200, 200 ),
        ["White"] = Color( 255, 255, 255 ),
        ["Info"] = Color( 70, 135, 255 ),
        ["Warn"] = Color( 255, 130, 90 ),
        ["Error"] = Color( 250, 55, 40 ),
        ["Debug"] = Color( 0, 200, 150 )
    }

    if MENU_DLL then
        Colors.Realm = Color( 75, 175, 80 )
        Realm = "Menu"
    elseif CLIENT then
        Colors.Realm = Color( 225, 170, 10 )
        Realm = "Client"
    elseif SERVER then
        Colors.Realm = Color( 5, 170, 250 )
        Realm = "Server"
    end
end

do

    local AddCSLuaFile = AddCSLuaFile
    local include = include

    function IncludeComponent( filePath )
        filePath = "gpm/" .. filePath  .. ".lua"
        if SERVER then AddCSLuaFile( filePath ) end
        return include( filePath )
    end

end

local stopwatch = SysTime()

IncludeComponent "utils"
IncludeComponent "logger"

Logger = CreateLogger( "GPM@" .. utils.Version( _VERSION ), Color( 180, 180, 255 ) )

libs = {}
libs.deflatelua = IncludeComponent "libs/deflatelua"
Logger:Info( "%s v%s is initialized.", libs.deflatelua._NAME, libs.deflatelua._VERSION )

IncludeComponent "libs/promise"
local promise = promise

Logger:Info( "gm_promise v%s is initialized.", utils.Version( promise._VERSION_NUM ) )

if util.IsBinaryModuleInstalled( "moonloader" ) and pcall( require, "moonloader" ) then
    Logger:Info( "gm_moonloader v%s is initialized, MoonScript support is active.", utils.Version( moonloader._VERSION ) )
end

local moonloader = moonloader

do

    local CompileString = CompileString

    function _G.CompileMoonString( moonCode, identifier, handleError )
        if not moonloader then
            error( "Attempting to compile a Moonscript file fails, install gm_moonloader and try again, https://github.com/Pika-Software/gm_moonloader." )
        end

        local luaCode = moonloader.ToLua( moonCode )
        if not luaCode then
            error( "MoonScript code compilation to Lua code failed." )
        end

        local func = CompileString( luaCode, identifier, handleError )
        if type( func ) ~= "function" then
            error( "MoonScript-Lua code compilation failed." )
        end

        return func
    end

end

IncludeComponent "libs/gmad"
Logger:Info( "gmad v%s is initialized.", utils.Version( gmad.GMA.Version ) )

IncludeComponent "environment"
IncludeComponent "http"
IncludeComponent "fs"
IncludeComponent "zip"

if type( Packages ) ~= "table" then
    Packages = {}
end

IncludeComponent "package"
local fs = fs

CacheLifetime = CreateConVar( "gpm_cache_lifetime", "24", FCVAR_ARCHIVE, "Packages cache lifetime, in hours, sets after how many hours the downloaded gpm packages will not be relevant.", 0, 60480 )
WorkshopPath = fs.CreateDir( "gpm/" .. string.lower( Realm ) .. "/workshop/" )
CachePath = fs.CreateDir( "gpm/" .. string.lower( Realm ) .. "/packages/" )

do

    local string_find = string.find
    local pairs = pairs

    function Find( searchable, ignoreImportNames, noPatterns )
        local result = {}
        for importPath, pkg in pairs( Packages ) do
            if not ignoreImportNames and importPath == searchable then
                result[ #result + 1 ] = pkg
                continue
            end

            local name = pkg:GetName()
            if not name then continue end
            if string_find( name, searchable, 1, noPatterns ) ~= nil then
                result[ #result + 1 ] = pkg
            end
        end

        return result
    end

end

do

    local CompileFile = CompileFile
    local pcall = pcall

    function CompileLua( filePath )
        local ok, result = pcall( fs.CompileLua, filePath, "LUA" )
        if ok then
            return result
        end

        if MENU_DLL then
            error( result )
        end

        local func = CompileFile( filePath )
        if not func then
            error( "File compilation '" .. filePath .. "' failed, unknown error." )
        end

        return func
    end

end

function PreCacheMoon( filePath, noError )
    if not moonloader then
        if noError then return end
        error( "Attempting to compile a Moonscript file fails, install gm_moonloader and try again, https://github.com/Pika-Software/gm_moonloader." )
    end

    if fs.IsDir( filePath, "LUA" ) then
        moonloader.PreCacheDir( filePath )
        Logger:Debug( "All MoonScript files in the '%s' folder was compiled into Lua.", filePath )
        return
    end

    if not fs.IsFile( filePath, "LUA" ) then
        if noError then return end
        error( "Unable to compile Moonscript '" .. filePath .. "' file, file not found." )
    end

    if not moonloader.PreCacheFile( filePath ) then
        if noError then return end
        error( "Compiling Moonscript file '" .. filePath .. "' into Lua is failed!" )
    end

    Logger:Debug( "The MoonScript file '%s' was successfully compiled into Lua.", filePath )
end

IncludeComponent "import"

if not MENU_DLL then
    IncludeComponent "commands"
end

ImportFolder( "packages", nil, true )

Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )
hook.Run( "GPM - Initialized" )
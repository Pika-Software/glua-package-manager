AddCSLuaFile()

-- Libraries
local table = table

-- Variables
local MENU_DLL = MENU_DLL
local SERVER = SERVER
local Color = Color
local type = type

MsgN( [[
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

_VERSION = 013003

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

    local AddCSLuaFile = SERVER and AddCSLuaFile
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

Logger = logger.Create( "GPM@" .. utils.Version( _VERSION ), Color( 180, 180, 255 ) )

do

    local ErrorNoHaltWithStack = ErrorNoHaltWithStack
    local error = error

    function Error( importPath, message, noHalt, sourceName )
        Logger:Error( "[%s] Package '%s' import failed, see above to see the error.", sourceName or "unknown", importPath )
        if noHalt then
            ErrorNoHaltWithStack( message )
            return
        end

        error( message, 2 )
    end

end

libs = {}
libs.deflatelua = IncludeComponent "libs/deflatelua"
Logger:Info( "%s v%s is initialized.", libs.deflatelua._NAME, libs.deflatelua._VERSION )

IncludeComponent "libs/promise"
local promise = promise

Logger:Info( "gm_promise v%s is initialized.", utils.Version( promise._VERSION_NUM ) )

-- https://github.com/Pika-Software/gm_moonloader
if util.IsBinaryModuleInstalled( "moonloader" ) then
    gpm.Logger:Info( "Moonloader engaged." )
    require( "moonloader" )
end

IncludeComponent "libs/gmad"
Logger:Info( "gmad v%s is initialized.", utils.Version( gmad.GMA.Version ) )

IncludeComponent "environment"
IncludeComponent "http"
IncludeComponent "fs"
IncludeComponent "zip"

local fs = fs

if type( Packages ) == "table" then
    table.Empty( Packages )
else
    Packages = {}
end

IncludeComponent "package"

CacheLifetime = CreateConVar( "gpm_cache_lifetime", "24", FCVAR_ARCHIVE, "Packages cache lifetime, in hours, sets after how many hours the downloaded gpm packages will not be relevant.", 0, 60480 )
WorkshopPath = fs.CreateDir( "gpm/" .. ( SERVER and "server" or "client" ) .. "/workshop/" )
CachePath = fs.CreateDir( "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/" )

do

    local CompileFile = CompileFile
    local ArgAssert = ArgAssert
    local pcall = pcall
    local files = {}

    function GetCompiledFiles()
        return files
    end

    CompileLua = promise.Async( function( filePath )
        ArgAssert( filePath, 1, "string" )

        local func = files[ filePath ]
        if func then return func end

        local ok, result = fs.Compile( "lua/" .. filePath, "GAME" ):SafeAwait()
        if ok then
            func = result
        elseif MENU_DLL then
            return promise.Reject( result )
        else
            ok, result = pcall( CompileFile, filePath )
            if not ok then return promise.Reject( result ) end
        end

        if ok and type( result ) == "function" then
            files[ filePath ] = result
            return result
        end

        return promise.Reject( "File '" .. filePath .. "' code compilation failed due to an unknown error." )
    end )

end

IncludeComponent "import"
IncludeComponent "commands"

Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )
hook.Run( "GPM - Initialized" )

util.NextTick( function()
    ImportFolder( "packages", nil, true )
end )
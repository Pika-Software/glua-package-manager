local AddCSLuaFile = SERVER and AddCSLuaFile
local include = include
local SysTime = SysTime
local SERVER = SERVER
local ipairs = ipairs
local Color = Color

module( "gpm", package.seeall )

_VERSION = 011600

if not Colors then
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
        LuaRealm = "LUA"
    elseif CLIENT then
        Colors.Realm = Color( 225, 170, 10 )
        LuaRealm = "lcl"
    elseif SERVER then
        Colors.Realm = Color( 5, 170, 250 )
        LuaRealm = "lsv"
    end
end

module( "gpm" )

_VERSION = 011500

function IncludeComponent( filePath )
    filePath = "gpm/" .. filePath  .. ".lua"
    if SERVER then AddCSLuaFile( filePath ) end
    return include( filePath )
end

-- Measuring startup time
local stopwatch = SysTime()

-- Utils
IncludeComponent "utils"

-- GLua fixes
IncludeComponent "fixes"

-- Colors & Logger modules
IncludeComponent "logger"

-- Global GPM Logger Creating
Logger = logger.Create( "GPM@" .. utils.Version( _VERSION ), Color( 180, 180, 255 ) )

-- Third-party libraries
libs = {}
libs.deflatelua = IncludeComponent "libs/deflatelua"
Logger:Info( "%s %s is initialized.", libs.deflatelua._NAME, libs.deflatelua._VERSION )

-- Our libraries
IncludeComponent "environment"
IncludeComponent "gmad"

-- Promises
IncludeComponent "promise"
Logger:Info( "gm_promise %s is initialized.", utils.Version( promise._VERSION_NUM ) )

-- File System & HTTP
IncludeComponent "fs"
IncludeComponent "http"

-- Creating folder in data
fs.CreateDir( "gpm" )

-- Packages
IncludeComponent "packages"

-- Sources
sources = sources or {}

for _, filePath in ipairs( fs.Find( "gpm/sources/*", "LUA" ) ) do
    filePath = "gpm/sources/" .. filePath

    if SERVER then
        AddCSLuaFile( filePath )
    end

    include( filePath )
end

-- Finish log
Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )

-- Importer
IncludeComponent "importer"
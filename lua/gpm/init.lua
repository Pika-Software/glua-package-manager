local AddCSLuaFile = SERVER and AddCSLuaFile
local include = include
local SysTime = SysTime
local SERVER = SERVER
local ipairs = ipairs
local Color = Color

CreateConVar( "gpm_cache_lifetime", "24", FCVAR_ARCHIVE, " - the cache lifetime, in hours, sets after how many hours the downloaded gpm packages will not be relevant.", 0, 60480 )

module( "gpm" )

_VERSION = 010600

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

-- Basic Libs
IncludeComponent "environment"
IncludeComponent "gmad"

-- Promises
IncludeComponent "promise"
Logger:Info( "Promise the library version %s is initialized.", utils.Version( promise._VERSION_NUM ) )

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
-- Libraries
local file = file

-- Variables
local AddCSLuaFile = SERVER and AddCSLuaFile
local include = include
local SysTime = SysTime
local SERVER = SERVER
local ipairs = ipairs
local Color = Color

module( "gpm" )

_VERSION = 010000

-- Include function
function includeShared( filePath )
    filePath = "gpm/" .. filePath  .. ".lua"
    if SERVER then AddCSLuaFile( filePath ) end
    return include( filePath )
end

-- Measuring startup time
local stopwatch = SysTime()

-- Utils
includeShared "utils"

-- Creating folder in data
utils.CreateFolder( "gpm" )

-- GLua fixes
includeShared "fixes"

-- Colors & Logger modules
includeShared "logger"

-- Global GPM Logger Creating
Logger = logger.Create( "GPM@" .. utils.Version( _VERSION ), Color( 180, 180, 255 ) )

-- Promises
includeShared "promise"
Logger:Info( "Promise the library version %s is initialized.", utils.Version( promise._VERSION_NUM ) )

-- Environment & Packages
includeShared "environment"
includeShared "packages"

-- HTTP
includeShared "http"

-- GMAD & PKGF
includeShared "gmad"
includeShared "pkgf"

-- Sources
sources = sources or {}

for _, filePath in ipairs( file.Find( "gpm/sources/*", "LUA" ) ) do
    filePath = "gpm/sources/" .. filePath

    if SERVER then
        AddCSLuaFile( filePath )
    end

    include( filePath )
end

-- Importer module
includeShared "importer"

-- Finish log
Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )
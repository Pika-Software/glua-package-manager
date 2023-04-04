-- Libraries
local file = file

-- Functions
local AddCSLuaFile = AddCSLuaFile
local include = include
local SysTime = SysTime
local ipairs = ipairs
local Color = Color

module( "gpm" )

_VERSION = 000001

-- Include function
function includeShared( fileName )
    local filePath = "gpm/" .. fileName
    if file.IsDir( filePath, "LUA" ) then
        for _, fileName in ipairs( file.Find( filePath .. "/*", "LUA" ) ) do
            fileName = filePath .. "/" .. fileName
            AddCSLuaFile( fileName )
            include( fileName )
        end

        return
    end

    filePath = filePath .. ".lua"
    AddCSLuaFile( filePath )
    include( filePath )
end

-- Measuring startup time
local stopwatch = SysTime()

-- Utils
includeShared "utils"

-- GLua fixes
includeShared "fixes"

-- Colors & Logger modules
includeShared "logger"

-- Global GPM Logger Creating
Logger = logger.Create( "GPM (" .. utils.Version( _VERSION ) .. ")", Color( 180, 200, 235 ) )

-- Promises
includeShared "promise"
Logger:Info( "Promise the library version %s is initialized.", utils.Version( promise._VERSION_NUM ) )

-- Environment & Packages
includeShared "environment"
includeShared "packages"

-- Filesystem & HTTP
includeShared "filesystem"
includeShared "http"

-- Sources
sources = sources or {}
includeShared "sources"

-- Importer module
includeShared "importer"

-- Reloading all packages
Reload()

-- Finish log
Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )
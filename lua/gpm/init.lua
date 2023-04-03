-- Libraries
local file = file

-- Functions
local AddCSLuaFile = AddCSLuaFile
local include = include

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

-- Loading start time
local startTime = SysTime()

-- Utils
includeShared "utils"

-- Colors & Logger modules
includeShared "colors"
includeShared "logger"

-- Global GPM Logger Creating
colors.Set( "gpm", Color(174, 197, 235) )
Logger = logger.Create( "GPM (" .. utils.Version( _VERSION ) .. ")", color )

-- Promises
includeShared "promise"
Logger:Info( "Promise the library version %s is initialized.", utils.Version( promise._VERSION_NUM ) )

-- Environment & Zip modules
includeShared "environment"
includeShared "unzip"

includeShared "packages"

-- Sources
sources = sources or {}
includeShared "sources"

-- Importer module
includeShared "importer"

-- Finish log
Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - startTime )
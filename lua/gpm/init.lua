local AddCSLuaFile = AddCSLuaFile
local include = include

gpm = gpm or {}
gpm._VERSION = "0.0.1"

-- Include function
local function includeShared( fileName )
    local filePath = "gpm/" .. fileName .. ".lua"
    AddCSLuaFile( filePath )
    include( filePath )
end

-- Loading start time
local startTime = SysTime()

-- Global functions & Promises
includeShared "globals"
includeShared "utils"
includeShared "promise"

-- Colors & Logger modules
includeShared "colors"
includeShared "logger"

-- Global GPM Logger Creating
gpm.colors.Set( "gpm", Color(174, 197, 235) )
gpm.Logger = gpm.logger.Create( "Glua Package Manager (" .. gpm._VERSION  .. ")", color )

-- Environment & Zip modules
includeShared "environment"
includeShared "unzip"

includeShared "package"

-- Loaders
gpm.loaders = gpm.loaders or {}
includeShared "loaders/lua"
includeShared "loaders/zip"

-- Importer module
includeShared "importer"

-- Finish log
gpm.Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - startTime )
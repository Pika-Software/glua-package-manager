-- Functions
local AddCSLuaFile = AddCSLuaFile
local include = include
local file = file

gpm = gpm or {}
gpm._VERSION = 000001

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

-- Promises
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

includeShared "packages"

-- Sources
gpm.sources = gpm.sources or {}
includeShared "sources"

-- Importer module
includeShared "importer"

-- Finish log
gpm.Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - startTime )
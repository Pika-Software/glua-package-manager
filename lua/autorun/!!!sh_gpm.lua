local AddCSLuaFile = AddCSLuaFile
local include = include
local SERVER = SERVER

gpm = gpm or {}
gpm._VERSION = 000001

-- Include function
local workFolder = "gpm/"
local function includeShared( fileName )
    if (SERVER) then
        AddCSLuaFile( workFolder .. fileName )
    end

    include( workFolder .. fileName )
end

-- Loading start time
local startTime = SysTime()

-- Global & Debug functions
includeShared( "globals.lua" )
includeShared( "debug.lua" )

-- Colors & Logger modules
includeShared( "colors.lua" )
includeShared( "logger.lua" )

-- Global GPM Logger Creating
local color = HEXToColor( "#AEC5EB" )
gpm.colors.Set( "gpm", color )
gpm.Logger = gpm.logger.Create( "Glua Package Manager", color )

-- Environment & Zip modules
includeShared( "environment.lua" )
includeShared( "unzip.lua" )

-- Importer module
includeShared( "importer.lua" )

-- Finish log
gpm.Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - startTime )
local AddCSLuaFile = AddCSLuaFile
local include = include
local SERVER = SERVER

local startTime = SysTime()

gpm = gpm or {}
gpm._VERSION = 000001

local workFolder = "gpm/"
local function includeShared( fileName )
    if (SERVER) then
        AddCSLuaFile( workFolder .. fileName )
    end

    include( workFolder .. fileName )
end

includeShared( "globals.lua" )
includeShared( "debug.lua" )

includeShared( "colors.lua" )
includeShared( "logger.lua" )

local color = HEXToColor( "#AEC5EB" )
gpm.colors.Set( "gpm", color )
gpm.Logger = gpm.logger.Create( "Glua Package Manager", color )

includeShared( "environment.lua" )
includeShared( "unzip.lua" )

includeShared( "importer.lua" )

gpm.Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - startTime )

-- PrintTable( gpm )
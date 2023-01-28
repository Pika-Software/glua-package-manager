local AddCSLuaFile = AddCSLuaFile
local include = include
local SERVER = SERVER

gpm = gpm or {}

local function IncludeShared( fileName )
    if (SERVER) then
        AddCSLuaFile( fileName )
    end

    include( fileName )
end

IncludeShared("gpm/globals.lua")

IncludeShared("gpm/debug.lua")
IncludeShared("gpm/environment.lua")

IncludeShared("gpm/colors.lua")
IncludeShared("gpm/logger.lua")
IncludeShared("gpm/unzip.lua")

IncludeShared("gpm/importer.lua")

PrintTable( gpm )
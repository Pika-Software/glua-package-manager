if SERVER then
    require "moonloader"
    moonloader.PreCacheDir "gpm"
    AddCSLuaFile "gpm/init.lua"
end

include "gpm/init.lua"
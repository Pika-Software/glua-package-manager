if SERVER and util.IsBinaryModuleInstalled "moonloader" then
    require "moonloader"
end

AddCSLuaFile "gpm/init.lua"
include "gpm/init.lua"

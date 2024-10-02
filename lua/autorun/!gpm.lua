if SERVER then
    if util.IsBinaryModuleInstalled( "moonloader" ) then
        require( "moonloader" )
    end

    AddCSLuaFile( "gpm/init.lua" )
end

include( "gpm/init.lua" )

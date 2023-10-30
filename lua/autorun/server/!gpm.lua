if util.IsBinaryModuleInstalled( "moonloader" ) and pcall( require, "moonloader" ) and moonloader ~= nil then
    moonloader.PreCacheDir( "gpm" )
end

include( "gpm/init.lua" )
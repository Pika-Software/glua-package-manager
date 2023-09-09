local promise = promise
local require = require
local pcall = pcall
local util = util
local gpm = gpm
local _G = _G

module( "gpm.sources.modules" )

Priority = 1

function CanImport( moduleName )
    return util.IsLuaModuleInstalled( moduleName ) or util.IsBinaryModuleInstalled( moduleName )
end

GetMetadata = promise.Async( function( moduleName )
    return {
        module_type = util.IsBinaryModuleInstalled( moduleName ) and "dll" or "lua"
    }
end )

Import = promise.Async( function( metadata )
    local moduleName = metadata.importpath
    if metadata.module_type == "lua" then
        return gpm.SourceImport( "lua", "includes/modules/" .. moduleName .. ".lua" )
    end

    local ok, result = pcall( require, moduleName )
    if ok then return _G[ moduleName ] end
    return promise.Reject( result )
end )
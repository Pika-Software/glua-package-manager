local gpm = gpm
local promise = gpm.promise
local LUA_REALM = CLIENT and "lcl" or SERVER and "lsv" or "LUA"

module( "gpm.loaders.lua", package.seeall )

function ImportMetadata(packagePath)
    if not packagePath:EndsWith( ".lua" ) then
        packagePath = gpm.path.Join(packagePath, "package.lua")
    end
    if file.Exists(packagePath, LUA_REALM) then
        return gpm.package.ParseTableFromFunc(
            setfenv(CompileFile(packagePath), {})
        )
    end
end

Import = promise.Async(function(packagePath)
    local metadata = ImportMetadata(packagePath)
    if not metadata then return promise.Reject("failed to import metadata") end

    PrintTable(metadata)
end)
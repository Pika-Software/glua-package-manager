local gpm = gpm
local promise = gpm.promise
local LUA_REALM = CLIENT and "lcl" or SERVER and "lsv" or "LUA"

module( "gpm.sources.lua", package.seeall )

function ImportMetadata( packagePath )
    if not string.EndsWith( packagePath, ".lua" ) then
        packagePath = gpm.path.Join( packagePath, "package.lua" )
    end

    if file.Exists( packagePath, LUA_REALM ) then
        return gpm.packages.GetMetaData( setfenv( CompileFile( packagePath ), {} ) )
    end

    return gpm.packages.GetMetaData( {} )
end

Import = promise.Async( function( packagePath )
    print( packagePath )
    local metadata = ImportMetadata( packagePath )

    if not metadata.name then
        metadata.name = string.GetFileFromFilename( packagePath )
    end

    if not metadata.main then
        metadata.main = gpm.path.Join( packagePath, "init.lua" )
    end

    if not file.Exists( metadata.main, LUA_REALM ) then return promise.Reject( "main file is missing" ) end

    local func = CompileFile( metadata.main )
    if not func then return promise.Reject( "main file compilation failed" ) end

    PrintTable( metadata )

    local env = nil
    if istable( gpm.Package ) then
        env = gpm.Package:GetEnvironment()
    end

    return InitializePackage( metadata, func, files, env )
end )
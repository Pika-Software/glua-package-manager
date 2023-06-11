local gpm = gpm

-- Libraries
local promise = promise
local string = string
local table = table
local fs = gpm.fs

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local util_JSONToTable = util.JSONToTable
local game_MountGMA = game.MountGMA
local gmad_Open = gmad.Open
local ipairs = ipairs
local pcall = pcall
local type = type

module( "gpm.sources.gma" )

function CanImport( filePath )
    return fs.IsFile( filePath, "GAME" ) and string.EndsWith( filePath, ".gma.dat" ) or string.EndsWith( filePath, ".gma" )
end

Import = promise.Async( function( metadata )
    local importPath = metadata.importpath

    local gma = gmad_Open( importPath, "GAME" )
    if not gma then return promise.Reject( "gma file '" .. importPath .. "' cannot be readed" ) end

    metadata.name = gma:GetTitle()
    metadata.description = gma:GetDescription()

    metadata.author = gma:GetAuthor()
    metadata.timestamp = gma:GetTimestamp()
    metadata.requiredContent = gma:GetRequiredContent()

    gma:Close()

    local description = util_JSONToTable( metadata.description )
    if type( description ) == "table" then
        table.Merge( metadata, description )
    end

    local ok, files = game_MountGMA( importPath )
    if not ok then
        return promise.Reject( "gma file '" .. importPath .. "' cannot be mounted" )
    end

    local importPaths = {}
    for _, filePath in ipairs( files ) do
        if string.StartsWith( filePath, "lua/autorun/" ) then
            if string.StartsWith( filePath, "lua/autorun/server/" ) and not SERVER then
                continue
            elseif string.StartsWith( filePath, "lua/autorun/client" ) and not CLIENT then
                continue
            end

            local ok, result = gpm.CompileLua( string.sub( filePath, 4, #filePath ) ):SafeAwait()
            if ok then
                ok, result = pcall( result )
            end

            if not ok then
                ErrorNoHaltWithStack( result )
            end
        elseif string.StartsWith( filePath, "lua/packages/" ) then
            local importPath = string.match( string.sub( filePath, 5 ), "packages/[^/]+" )
            if not importPath then continue end

            if table.HasIValue( importPaths, importPath ) then continue end
            importPaths[ #importPaths + 1 ] = importPath
        end
    end

    local results = {}
    for _, importPath in ipairs( importPaths ) do
        results[ #results + 1 ] = gpm.SourceImport( "lua", importPath ):Await()
    end

    local count = #results
    if count > 0 then
        if count == 1 then
            return results[ 1 ]
        end

        return results
    end
end )
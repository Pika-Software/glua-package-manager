local gpm = gpm

-- Libraries
local promise = promise
local string = string
local table = table
local fs = gpm.fs

-- Variables
local game_MountGMA = game.MountGMA
local gmad_Open = gpm.gmad.Open
local ipairs = ipairs
local type = type

module( "gpm.sources.gma" )

function CanImport( filePath )
    return fs.IsFile( filePath, "GAME" ) and string.EndsWith( filePath, ".gma.dat" ) or string.EndsWith( filePath, ".gma" )
end

function GetInfo( filePath )
    return {}
end

Import = promise.Async( function( info )
    local importPath = info.importPath

    local gma = gmad_Open( importPath, "GAME" )
    if not gma then return promise.Reject( "gma file '" .. importPath .. "' cannot be readed" ) end

    info.name = gma:GetTitle()
    info.description = gma:GetDescription()

    info.author = gma:GetAuthor()
    info.timestamp = gma:GetTimestamp()
    info.requiredContent = gma:GetRequiredContent()

    gma:Close()

    local description = util.JSONToTable( info.description )
    if type( description ) == "table" then
        table.Merge( info, description )
    end

    local ok, files = game_MountGMA( importPath )
    if not ok then return promise.Reject( "gma file '" .. importPath .. "' cannot be mounted" ) end

    local packages = {}
    for _, filePath in ipairs( files ) do
        if not string.StartsWith( filePath, "lua/packages/" ) then continue end

        local importPath = string.match( string.sub( filePath, 5 ), "packages/[^/]+" )
        if not importPath then continue end

        if table.HasIValue( packages, importPath ) then continue end
        packages[ #packages + 1 ] = importPath
    end

    return package.Initialize( package.GetMetadata( info ), function()
        if #packages < 1 then return end

        local tasks, pkg = {}, _PKG
        for _, importPath in ipairs( packages ) do
            tasks[ #tasks + 1 ] = gpm.SourceImport( "lua", importPath, pkg, false )
        end

        local count = #tasks
        if count == 0 then return end
        if count == 1 then return tasks[1] end
        return tasks
    end )
end )
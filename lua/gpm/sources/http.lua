-- Libraries
local promise = gpm.promise
local sources = gpm.sources
local gmad = gpm.gmad
local http = gpm.http
local string = string
local file = file

module( "gpm.sources.http", package.seeall )

function CanImport( filePath )
    return string.IsURL( filePath )
end

local packagesFolder = "gpm/package"
if not file.IsDir( packagesFolder, "DATA" ) then
    file.Delete( packagesFolder )
    file.CreateDir( packagesFolder )
end

local realmFolder = packagesFolder .. "/" .. ( SERVER and "server" or "client" )
if not file.IsDir( realmFolder, "DATA" ) then
    file.Delete( realmFolder )
    file.CreateDir( realmFolder )
end

Import = promise.Async( function( url )

    local packageName = util.CRC( url )
    local gmaPath = realmFolder .. "/" .. packageName .. ".gma.dat"

    if not file.Exists( gmaPath, "DATA" ) then
        local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( result ) end

        if result.code ~= 200 then return promise.Reject( "invalid response http code - " .. result.code ) end

        local metadata = util.JSONToTable( result.body )
        if not metadata then return promise.Reject( "package info is damaged" ) end

        metadata = gpm.utils.LowerTableKeys( metadata )
        if not metadata.files then return promise.Reject( "package with no name" ) end

        local mainFile = metadata.main
        if not isstring( mainFile ) then
            mainFile = "init.lua"
        end

        metadata.main = "gpm/packages/" .. packageName .. "/" .. mainFile
        metadata.source = metadata.source or "http"

        local files = {
            { "lua/gpm/packages/" .. packageName .. "/package.lua", "return util.JSONToTable( [[" .. util.TableToJSON( metadata ) .. "]] )" }
        }

        for filePath, fileURL in pairs( metadata.files ) do
            local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
            if not ok or result.code ~= 200 then return promise.Reject( "file " .. filePath .. " download failed" ) end
            files[ #files + 1 ] = { "lua/gpm/packages/" .. packageName .. "/" .. filePath, result.body }
        end

        local gma = gmad.Create( gmaPath )

        local title = metadata.name
        if isstring( title ) then
            gma:SetTitle( title )
        end

        local description = metadata.description
        if isstring( description ) then
            gma:SetDescription( description )
        end

        local author = metadata.author
        if isstring( author ) then
            gma:SetAuthor( author )
        end

        for _, data in ipairs( files ) do
            gma:AddFile( data[ 1 ], data[ 2 ] )
        end

        gma:Close()
    end

    if not game.MountGMA( "data/" .. gmaPath ) then return promise.Reject( "gma mounting failed" ) end
    return sources.lua.Import( "gpm/packages/" .. packageName )
end )

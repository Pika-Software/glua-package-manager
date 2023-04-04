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

if not file.IsDir( "gpm/packages", "DATA" ) then
    file.Delete( "gpm/packages" )
    file.CreateDir( "gpm/packages" )
end

Import = promise.Async( function( url )

    local packageName = util.CRC( url )
    local gmaPath = "gpm/packages/" .. packageName .. ".gma.dat"
    if not file.Exists( gmaPath, "DATA" ) then
        local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( result ) end

        if result.code ~= 200 then return promise.Reject( "invalid response http code - " .. result.code ) end
        local json = result.body

        local packageInfo = util.JSONToTable( json )
        if not packageInfo then return promise.Reject( "package info is damaged" ) end

        packageInfo = gpm.utils.LowerTableKeys( packageInfo )
        if not packageInfo.files then return promise.Reject( "package with no name" ) end

        local files = {
            { "lua/gpm/packages/" .. packageName .. "/package.lua", "return util.JSONToTable( [[" .. json .. "]] )" }
        }

        for filePath, fileURL in pairs( packageInfo.files ) do
            local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
            if not ok or result.code ~= 200 then return promise.Reject( "file " .. filePath .. " download failed" ) end
            files[ #files + 1 ] = { "lua/gpm/packages/" .. packageName .. "/" .. filePath, result.body }
        end

        local gma = gmad.Create( gmaPath )

        local title = packageInfo.name
        if isstring( title ) then
            gma:SetTitle( title )
        end

        local description = packageInfo.description
        if isstring( description ) then
            gma:SetDescription( description )
        end

        local author = packageInfo.author
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

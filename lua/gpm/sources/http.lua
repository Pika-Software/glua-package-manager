-- Libraries
local filesystem = gpm.filesystem
local promise = gpm.promise
local sources = gpm.sources
local http = gpm.http
local string = string

module( "gpm.sources.http", package.seeall )

function CanImport( filePath )
    return string.IsURL( filePath )
end

if filesystem.Exists( "gpm/packages", "DATA" ) then
    filesystem.CreateDir( "gpm/packages" )
end

PackagesLifeTime = 60 * 60 * 24 * 2

Import = promise.Async( function( url )

    http.Download( url, "gpm/packages", nil, PackagesLifeTime ):Then( function( result )
        -- sources.lua.Import( result.filePath )
    end )

end )

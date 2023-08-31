local SERVER = SERVER
local gpm = gpm

-- https://github.com/WilliamVenner/gmsv_workshop
if SERVER and not steamworks and util.IsBinaryModuleInstalled( "workshop" ) and pcall( require, "workshop" ) then
    gpm.Logger:Info( "A third-party steamworks API 'workshop' has been initialized." )
end

-- Libraries
local steamworks = steamworks
local promise = promise
local fs = gpm.fs

-- Variables
local tempPath = gpm.TempPath
local tonumber = tonumber
local type = type

module( "gpm.sources.workshop" )

function CanImport( filePath )
    return tonumber( filePath ) ~= nil
end

function Download( wsid )
    if not steamworks then
        return promise.Reject( "There is no steamworks library, it is required to work with the Steam Workshop, a supported binary for server side: https://github.com/WilliamVenner/gmsv_workshop" )
    end

    local p = promise.New()
    steamworks.DownloadUGC( wsid, function( filePath, fileClass )
        if type( filePath ) ~= "string" then
            filePath = "unknown/" .. wsid .. ".gma"
        elseif fs.Exists( filePath, "GAME" ) then
            p:Resolve( filePath )
            return
        end

        if not fileClass then
            p:Reject( "Unknown error reading downloaded GMA file '" .. filePath .. "' failed." )
            return
        end

        local content = fileClass:Read( fileClass:Size() )
        if not content or #content == 0 then
            return p:Reject( "GMA file '" .. filePath .. "' is corrupted and unreadable." )
        end

        local tepmFile = tempPath .. "workshop_" .. wsid .. ".gma.dat"
        if fs.IsFile( tepmFile, "DATA" ) then
            fs.Delete( tepmFile )
        end

        if fs.IsFile( tepmFile, "DATA" ) then
            return p:Resolve( "data/" .. tepmFile )
        end

        fs.Write( tepmFile, content )

        if not fs.IsFile( tepmFile, "DATA" ) then
            return p:Reject( "Writing GMA '" .. tepmFile .. "' file was failed." )
        end

        p:Resolve( "data/" .. tepmFile )
    end )

    return p
end

Import = promise.Async( function( metadata )
    local ok, result = Download( metadata.importpath ):SafeAwait()
    if ok then
        return gpm.SourceImport( "gma", result )
    end

    return promise.Reject( result )
end )
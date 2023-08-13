local SERVER = SERVER
local gpm = gpm

-- https://github.com/WilliamVenner/gmsv_workshop
if SERVER and not steamworks and util.IsBinaryModuleInstalled( "workshop" ) and pcall( require, "workshop" ) then
    gpm.Logger:Info( "A third-party steamworks API 'workshop' has been initialized." )
end

-- Libraries
local promise = promise
local gmad = gmad
local fs = gpm.fs

-- Variables
local cacheFolder = gpm.TempPath
local steamworks = steamworks
local tonumber = tonumber
local type = type

module( "gpm.sources.workshop" )

function CanImport( filePath )
    return type( tonumber( filePath ) ) == "number"
end

function Download( wsid )
    if not steamworks and SERVER then
        return promise.Reject( "There is no steamworks library on the server, it is required to work with the Steam Workshop, a supported binary: https://github.com/WilliamVenner/gmsv_workshop" )
    end

    local p = promise.New()
    steamworks.DownloadUGC( wsid, function( filePath, fileClass )
        if type( filePath ) ~= "string" then
            filePath = "unknown path"
        elseif fs.IsFile( filePath, "GAME" ) then
            p:Resolve( filePath )
            return
        end

        if not fileClass then
            p:Reject( "Unknown error reading downloaded GMA file '" .. filePath .. "' failed." )
            return
        end

        local gmaReader = gmad.Open( fileClass )
        if not gmaReader then
            p:Reject( "Unknown error reading downloaded GMA file '" .. filePath .. "' failed." )
            return
        end

        gmaReader:ReadAllFiles()
        gmaReader:Close()

        local gmaPath = cacheFolder .. "workshop_" .. wsid .. ".gma.dat"
        if fs.IsFile( gmaPath, "DATA" ) then
            fs.Delete( gmaPath )
        end

        local gmaWriter = gmad.Write( gmaPath )
        if not gmaWriter then
            if fs.IsFile( gmaPath, "DATA" ) then
                gpm.Logger:Warn( "GMA file '" .. gmaPath .. "' cannot be written, it is probably already mounted to the game, try restarting the game." )
            else
                p:Reject( "Unknown GMA file '" .. gmaPath .. "' writing error." )
            end

            return
        end

        gmaWriter.Metadata = gmaReader.Metadata
        gmaWriter.Files = gmaReader.Files
        gmaWriter:Close()

        p:Resolve( "data/" .. gmaPath )
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
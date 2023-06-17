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
local steamworks = steamworks
local tonumber = tonumber
local type = type

local cacheLifetime = gpm.CacheLifetime
local cacheFolder = gpm.WorkshopPath

module( "gpm.sources.workshop" )

function CanImport( filePath )
    return type( tonumber( filePath ) ) == "number"
end

function Download( wsid )
    local p = promise.New()

    -- TODO: Check game path "WORKSHOP"
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

        local gmaReader = gmad.Read( fileClass )
        if not gmaReader then
            p:Reject( "Unknown error reading downloaded GMA file '" .. filePath .. "' failed." )
            return
        end

        gmaReader:ReadAllFiles()
        gmaReader:Close()

        local cachePath = cacheFolder .. wsid .. ".gma.dat"
        if fs.IsFile( cachePath, "DATA" ) then
            if fs.Time( cachePath, "DATA" ) <= ( 60 * 60 * cacheLifetime:GetInt() ) then
                p:Resolve( "data/" .. cachePath )
                return
            end

            fs.Delete( cachePath )
        end

        local gmaWriter = gmad.Write( cachePath )
        if not gmaWriter then
            if fs.IsFile( cachePath, "DATA" ) then
                gpm.Logger:Warn( "GMA file '" .. cachePath .. "' cannot be written, it is probably already mounted to the game, try restarting the game." )
            else
                p:Reject( "Unknown GMA file '" .. cachePath .. "' writing error." )
            end

            return
        end

        gmaWriter.Metadata = gmaReader.Metadata
        gmaWriter.Files = gmaReader.Files
        gmaWriter:Close()

        p:Resolve( "data/" .. cachePath )
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
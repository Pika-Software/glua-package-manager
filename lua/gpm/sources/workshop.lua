local gpm = gpm

-- https://github.com/WilliamVenner/gmsv_workshop
if SERVER and not steamworks then
    if not util.IsBinaryModuleInstalled( "workshop" ) then return end
    require( "workshop" )
end

-- Libraries
local promise = promise
local gmad = gmad
local fs = gpm.fs

-- Variables
local steamworks = steamworks
local logger = gpm.Logger
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

    steamworks.DownloadUGC( wsid, function( filePath, fileClass )
        if type( filePath ) == "string" and fs.IsFile( filePath, "GAME" ) then
            p:Resolve( filePath )
            return
        end

        if fileClass then
            local gmaReader = gmad.Read( fileClass )
            if not gmaReader then
                p:Reject( "gma reading failed" )
                return
            end

            local cachePath = cacheFolder .. wsid .. ".gma.dat"
            if fs.IsFile( cachePath, "DATA" ) then
                if fs.Time( cachePath, "DATA" ) <= ( 60 * 60 * cacheLifetime:GetInt() ) then
                    p:Resolve( "data/" .. cachePath )
                    return
                end

                fs.Delete( cachePath )
            end

            gmaReader:ReadAllFiles()
            gmaReader:Close()

            local gmaWriter = gmad.Write( cachePath )
            if gmaWriter then
                gmaWriter.Metadata = gmaReader.Metadata
                gmaWriter.Files = gmaReader.Files
                gmaWriter:Close()
            elseif fs.IsFile( cachePath, "DATA" ) then
                logger:Warn( "Cache writing failed, probably file 'data/" .. cachePath .. "' was already mounted, need to restart the game." )
            else
                p:Reject( "gma file writing failed" )
                return
            end

            p:Resolve( "data/" .. cachePath )
            return
        end

        p:Reject( "gma has no data to read" )
    end )

    return p
end

Import = promise.Async( function( metadata )
    local wsid = metadata.importpath
    local ok, result = Download( wsid ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    return gpm.SourceImport( "gma", result )
end )
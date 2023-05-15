local gpm = gpm

-- https://github.com/WilliamVenner/gmsv_workshop
if SERVER and not steamworks then
    if not util.IsBinaryModuleInstalled( "workshop" ) then return end
    require( "workshop" )
end

-- Libraries
local promise = gpm.promise
local gmad = gpm.gmad
local fs = gpm.fs

-- Variables
local steamworks = steamworks
local logger = gpm.Logger
local tonumber = tonumber
local type = type

local cacheLifetime = GetConVar( "gpm_cache_lifetime" )
local cacheFolder = gpm.WorkshopPath

module( "gpm.sources.workshop" )

function CanImport( filePath )
    return type( tonumber( filePath ) ) == "number"
end

function GetInfo( wsid )
    return {
        ["importPath"] = wsid,
        ["wsid"] = wsid
    }
end

function Download( wsid )
    local p = promise.New()

    steamworks.DownloadUGC( wsid, function( filePath, fileClass )
        if fs.Exists( filePath, "GAME" ) then
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
            if fs.Exists( cachePath, "DATA" ) then
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
            elseif fs.Exists( cachePath, "DATA" ) then
                logger:Warn( "Cache writing failed, probably file `data/" .. cachePath .. "` was already mounted, need to restart the game." )
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

Import = promise.Async( function( info )
    local ok, result = Download( info.wsid ):SafeAwait()
    if not ok then
        logger:Error( "Package `%s` import failed, %s.", info.wsid, result )
        return
    end

    return gpm.SourceImport( "gma", result, _PACKAGE, false )
end )
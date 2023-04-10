-- Libraries
local sources = gpm.sources
local promise = gpm.promise
local gmad = gpm.gmad
local fs = gpm.fs

-- https://github.com/WilliamVenner/gmsv_workshop
if SERVER and not steamworks and util.IsBinaryModuleInstalled( "workshop" ) then
    require( "workshop" )
end

-- Variables
local steamworks = steamworks
local tonumber = tonumber
local type = type

local realmFolder = "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/"
fs.CreateDir( realmFolder )

local cacheLifetime = GetConVar( "gpm_cache_lifetime" )

module( "gpm.sources.workshop" )

function CanImport( filePath )
    return type( tonumber( filePath ) ) == "number"
end

Import = promise.Async( function( wsid, parentPackage )
    local p = promise.New()

    steamworks.DownloadUGC( wsid, function( filePath, fileClass )
        if not fs.Exists( filePath, "GAME" ) then
            if not fileClass then return p:Reject( "there is no data to read..." ) end

            local gma = gmad.Read( fileClass )
            if not gma then return p:Reject( "gma reading error" ) end

            local outputPath = realmFolder .. "/workshop_" .. wsid .. ".gma.dat"
            local fileExists = fs.Exists( outputPath, "DATA" )

            if not fileExists or fs.Time( outputPath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
                if fileExists then fs.Delete( outputPath ) end

                local output = gmad.Write( outputPath )
                if output then
                    output.Metadata = gma.Metadata
                    output.Files = gma.Files
                    output:Close()
                end
            end

            if not fs.Exists( outputPath, "DATA" ) then return p:Reject( "gma writing error" ) end
            p:Resolve( "data/" .. outputPath )
            return
        end

        p:Resolve( filePath )
    end )

    local ok, result = p:SafeAwait()
    if not ok then return promise.Reject( result ) end

    return sources.gmad.Import( result, parentPackage )
end )
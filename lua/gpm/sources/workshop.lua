-- Libraries
local sources = gpm.sources
local promise = gpm.promise
local utils = gpm.utils
local gmad = gpm.gmad
local file = file

-- https://github.com/WilliamVenner/gmsv_workshop
if SERVER and not steamworks and util.IsBinaryModuleInstalled( "workshop" ) then
    require( "workshop" )
end

-- Variables
local steamworks = steamworks
local tonumber = tonumber
local type = type

local realmFolder = "gpm/packages" .. "/" .. ( SERVER and "server" or "client" )
utils.CreateFolder( realmFolder )

module( "gpm.sources.workshop" )

function CanImport( filePath )
    return type( tonumber( filePath ) ) == "number"
end

PackageLifeTime = 60 * 60 * 24

Import = promise.Async( function( wsid, parentPackage )
    local p = promise.New()

    steamworks.DownloadUGC( wsid, function( filePath, fileClass )
        if not file.Exists( filePath, "GAME" ) then
            if not fileClass then return p:Reject( "there is no data to read..." ) end

            local gma = gmad.Read( fileClass )
            if not gma then return p:Reject( "gma reading error" ) end

            local outputPath = realmFolder .. "/" .. wsid .. ".gma.dat"
            local fileExists = file.Exists( outputPath, "DATA" )

            if not fileExists or file.Time( outputPath, "DATA" ) > PackageLifeTime then
                if fileExists then file.Delete( outputPath ) end

                local output = gmad.Write( outputPath )
                if output then
                    output.Metadata = gma.Metadata
                    output.Files = gma.Files
                    output:Close()
                end
            end

            if not file.Exists( outputPath, "DATA" ) then return p:Reject( "gma writing error" ) end
            p:Resolve( "data/" .. outputPath )
            return
        end

        p:Resolve( filePath )
    end )

    local ok, result = p:SafeAwait()
    if not ok then return promise.Reject( result ) end

    return sources.gmad.Import( result, parentPackage )
end )
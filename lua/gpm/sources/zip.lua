local gpm = gpm

-- Libraries
local promise = promise
local gmad = gpm.gmad
local string = string
local table = table
local zip = gpm.zip
local util = util
local fs = gpm.fs

-- Variables
local cacheLifetime = GetConVar( "gpm_cache_lifetime" )
local cacheFolder = gpm.CachePath
local ipairs = ipairs

module( "gpm.sources.zip" )

function CanImport( filePath )
    return fs.IsFile( filePath, "GAME" ) and string.EndsWith( filePath, ".zip.dat" ) or string.EndsWith( filePath, ".zip" )
end

local contentFolders = {
    ["particles"] = true,
    ["materials"] = true,
    ["gamemodes"] = true,
    ["resource"] = true,
    ["scripts"] = true,
    ["scenes"] = true,
    ["models"] = true,
    ["sound"] = true,
    ["maps"] = true,
    ["lua"] = true
}

function GetInfo( filePath )
    return {}
end

Import = promise.Async( function( info )
    local importPath = info.importPath

    local cachePath = cacheFolder .. "zip_" .. util.MD5( importPath ) .. ".gma.dat"
    if fs.IsFile( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        return gpm.SimpleSourceImport( "gma", "data/" .. cachePath, _PKG )
    end

    local fileClass = fs.Open( importPath, "rb", "GAME" )
    if not fileClass then
        return promise.Reject( "file '" .. importPath .. "' cannot be readed" )
    end

    local files = {}
    for filePath, content in zip.IterateZipFiles( fileClass ) do
        if not content then continue end

        local result = {}

        local founded = false
        for _, folder in ipairs( string.Split( filePath, "/" ) ) do
            if not founded and contentFolders[ folder ] then
                founded = true
            end

            if founded then
                result[ #result + 1 ] = folder
            end
        end

        if #result == 0 then continue end
        files[ #files + 1 ] = { table.concat( result, "/" ), content }
    end

    fileClass:Close()

    if #files == 0 then
        return promise.Reject( "zip archive is empty ( no files to mount )" )
    end

    local gma = gmad.Write( cachePath )
    if not gma then
        return promise.Reject( "cache file '" .. cachePath .. "' construction error, mounting failed" )
    end

    gma:SetTitle( importPath )

    for _, data in ipairs( files ) do
        gma:AddFile( data[ 1 ], data[ 2 ] )
    end

    gma:Close()

    return gpm.SimpleSourceImport( "gma", "data/" .. cachePath, _PKG )
end )
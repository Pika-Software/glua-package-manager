local gpm = gpm

-- Libraries
local promise = gpm.promise
local paths = gpm.paths
local gmad = gpm.gmad
local string = string
local table = table
local zip = gpm.zip
local util = util
local fs = gpm.fs

-- Variables
local cacheLifetime = GetConVar( "gpm_cache_lifetime" )
local cacheFolder = gpm.CachePath
local logger = gpm.Logger
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
    local importPath = paths.Fix( filePath )
    return {
        ["cachePath"] = cacheFolder .. "zip_" .. util.MD5( importPath ) .. ".gma.dat",
        ["importPath"] = importPath
    }
end

Import = promise.Async( function( info )
    local cachePath = info.cachePath
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        return gpm.SourceImport( "gma", "data/" .. cachePath, _PKG, false )
    end

    local importPath = info.importPath
    local fileClass = fs.Open( importPath, "rb", "GAME" )
    if not fileClass then
        logger:Error( "Package '%s' import failed, file cannot be readed.", importPath )
        return
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
        logger:Error( "Package '%s' import failed, no files to mount.", importPath )
        return
    end

    local gma = gmad.Write( cachePath )
    if not gma then
        logger:Error( "Package '%s' import failed, cache construction error, mounting failed.", importPath )
        return
    end

    gma:SetTitle( importPath )

    for _, data in ipairs( files ) do
        gma:AddFile( data[ 1 ], data[ 2 ] )
    end

    gma:Close()

    return gpm.SourceImport( "gma", "data/" .. cachePath, _PKG, false )
end )
local gpm = gpm

-- Libraries
local package = gpm.package
local promise = gpm.promise
local utils = gpm.utils
local gmad = gpm.gmad
local http = gpm.http
local string = string
local fs = gpm.fs
local util = util

-- Variables
local CompileString = CompileString
local logger = gpm.Logger
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type

local cacheLifetime = GetConVar( "gpm_cache_lifetime" )
local cacheFolder = gpm.CachePath

module( "gpm.sources.http" )

function CanImport( filePath )
    return string.IsURL( filePath )
end

function GetInfo( url )
    return {
        ["extension"] = string.GetExtensionFromFilename( url ) or "json",
        ["importPath"] = url,
        ["url"] = url
    }
end

local allowedExtensions = {
    ["lua"] = true,
    ["zip"] = true,
    ["gma"] = true,
    ["json"] = true
}

Import = promise.Async( function( info )
    local url, extension = info.url, info.extension
    if not allowedExtensions[ extension ] then
        local wsid = string.match( url, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
        if wsid ~= nil then
            return gpm.SourceImport( "workshop", wsid, _PKG, false )
        elseif string.match( url, "^https?://github.com/[^/]+/[^/]+$" ) ~= nil then
            return gpm.SourceImport( "http", string.gsub( url, "^https?://", "" ), _PKG, false )
        end

        logger:Error( "Package `%s` import failed, unsupported file extension. ", url )
        return
    end

    -- Local cache
    local cachePath = cacheFolder .. "http_" .. util.MD5( url ) .. "."  .. ( extension == "json" and "gma" or extension ) .. ".dat"
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        if extension == "gma" or extension == "json" then
            return gpm.SourceImport( "gma", "data/" .. cachePath, _PKG, false )
        elseif extension == "zip" then
            return gpm.SourceImport( "zip", "data/" .. cachePath, _PKG, false )
        end

        local ok, result = fs.Compile( cachePath, "DATA" ):SafeAwait()
        if not ok then
            logger:Error( "Package `%s` import failed, cache `%s` compile error: %s. ", url, cachePath, result )
            return
        end

        return package.Initialize( package.GetMetadata( {
            ["name"] = url
        } ), result, {} )
    end

    -- Downloading
    logger:Info( "Package `%s` is downloading...", url )
    local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
    if not ok then
        logger:Error( "Package `%s` import failed, %s.", url, result )
        return
    end

    if result.code ~= 200 then
        logger:Error( "Package `%s` import failed, invalid response code: %d.", url, result.code )
        return
    end

    -- Processing
    local body = result.body
    if extension ~= "json" then
        local ok, result = fs.AsyncWrite( cachePath, body ):SafeAwait()
        if not ok then
            logger:Error( "Package `%s` import failed, %s.", url, result )
            return
        end

        if extension == "gma" then
            return gpm.SourceImport( "gma", "data/" .. cachePath, _PKG, false )
        elseif extension == "zip" then
            return gpm.SourceImport( "zip", "data/" .. cachePath, _PKG, false )
        end

        logger:Error( "Package `%s` import failed, unknown file format.", url )
        return
    end

    local metadata = util.JSONToTable( body )
    if not metadata then
        local ok, err = fs.AsyncWrite( cachePath, body ):SafeAwait()
        if not ok then
            logger:Error( "Package `%s` import cache `%s` write failed, %s", url, cachePath, err )
        end

        local ok, result = pcall( CompileString, body, url )
        if not ok then
            logger:Error( "Package `%s` import failed, %s.", url, result )
            return
        end

        if not result then
            logger:Error( "Package `%s` import failed, lua compilation failed.", url )
            return
        end

        return package.Initialize( package.GetMetadata( {
            ["name"] = url,
            ["autorun"] = true
        } ), result )
    end

    metadata = utils.LowerTableKeys( metadata )
    metadata.filePath = url

    local urls = metadata.files
    if type( urls ) ~= "table" then
        logger:Error( "Package `%s` import failed, no links to files, download canceled.", url )
        return
    end

    metadata.files = nil

    local files = {}
    for filePath, fileURL in pairs( urls ) do
        logger:Debug( "Package `%s`, file `%s` (%s) download has started.", url, filePath, fileURL )

        local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( "file `" .. filePath .. "` download failed, " .. result ) end
        if result.code ~= 200 then return promise.Reject( "file `" .. filePath .. "` download failed, invalid response code: " .. result.code .. "." ) end
        files[ #files + 1 ] = { filePath, result.body }
    end

    if #files == 0 then
        logger:Error( "Package `%s` import failed, no files to download.", url )
        return
    end

    if metadata.mount == false then
        metadata = package.GetMetadata( metadata )

        local compiledFiles = {}
        for _, data in ipairs( files ) do
            local ok, result = pcall( CompileString, data[ 2 ], data[ 1 ] )
            if not ok then return promise.Reject( "file `" .. data[ 1 ] .. "` compile failed, " .. result .. "." ) end
            if not result then return promise.Reject( "file `" ..  data[ 1 ] .. "` compile failed, no result." ) end
            compiledFiles[ data[ 1 ] ] = result
        end

        if not metadata.name then
            metadata.name = url
        end

        local main = metadata.main
        if not main then
            main = "init.lua"
        end

        local func = compiledFiles[ main ]
        if not func then
            main = "main.lua"
            func = gpm.CompileLua( main )
        end

        if not func then
            logger:Error( "Package `%s` import failed, main file is missing.", url )
            return
        end

        return package.Initialize( metadata, func, compiledFiles )
    end

    local gma = gmad.Write( cachePath )
    if not gma then
        logger:Error( "Package `%s` import failed, cache construction error, mounting failed.", url )
        return
    end

    local name = metadata.name
    if name ~= nil then
        gma:SetTitle( name )
    else
        gma:SetTitle( url )
    end

    gma:SetDescription( util.TableToJSON( metadata ) )

    local author = metadata.author
    if author ~= nil then
        gma:SetAuthor( author )
    end

    for _, data in ipairs( files ) do
        gma:AddFile( data[ 1 ], data[ 2 ] )
    end

    gma:Close()

    return gpm.SourceImport( "gma", "data/" .. cachePath, _PKG, false )
end )

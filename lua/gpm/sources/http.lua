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
        ["importPath"] = url
    }
end

local allowedExtensions = {
    ["lua"] = true,
    ["zip"] = true,
    ["gma"] = true,
    ["json"] = true
}

Import = promise.Async( function( info )
    local url, extension = info.importPath, info.extension
    if not allowedExtensions[ extension ] then
        local wsid = string.match( url, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
        if wsid ~= nil then
            return gpm.SourceImport( "workshop", wsid, _PKG, false )
        elseif string.match( url, "^https?://github.com/[^/]+/[^/]+$" ) ~= nil then
            return gpm.SourceImport( "http", string.gsub( url, "^https?://", "" ), _PKG, false )
        end

        logger:Error( "Package '%s' import failed, unsupported file extension. ", url )
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
            gpm.Error( url, result )
        end

        return package.Initialize( package.GetMetadata( {
            ["autorun"] = true,
            ["name"] = url
        } ), result )
    end

    -- Downloading
    logger:Info( "Package '%s' is downloading...", url )
    local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
    if not ok then
        logger:Error( "Package '%s' import failed, %s.", url, result )
        return
    end

    if result.code ~= 200 then
        logger:Error( "Package '%s' import failed, invalid response code: %d.", url, result.code )
        return
    end

    -- Processing
    local body = result.body
    if extension ~= "json" then
        local ok, result = fs.AsyncWrite( cachePath, body ):SafeAwait()
        if not ok then
            logger:Warn( "Cache creation for package '%s' failed, error: %s", url, result )
        end

        if extension == "lua" then
            local ok, result = pcall( CompileString, body, url )
            if not ok then
                gpm.Error( url, result )
            end

            return package.Initialize( package.GetMetadata( {
                ["autorun"] = true,
                ["name"] = url
            } ), result )
        elseif extension == "gma" or extension == "zip" then
            return gpm.SourceImport( extension, "data/" .. cachePath, _PKG, false )
        end

        gpm.Error( url, "unsupported file format." )
    end

    local json = util.JSONToTable( body )
    if not json then
        gpm.Error( url, "'package.json' file is corrupted." )
    end

    package.GetMetadata( table.Merge( info, utils.LowerTableKeys( json ) ) )
    info.importPath = url

    if not info.name then
        info.name = url
    end

    local urls = info.files
    if type( urls ) ~= "table" then
        logger:Error( "Package '%s' import failed, no links to files, download canceled.", url )
        return
    end

    info.files = nil

    local files = {}
    for filePath, fileURL in pairs( urls ) do
        logger:Debug( "Package '%s', file '%s' (%s) download has started.", url, filePath, fileURL )

        local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( "file '" .. filePath .. "' download failed, " .. result ) end
        if result.code ~= 200 then return promise.Reject( "file '" .. filePath .. "' download failed, invalid response code: " .. result.code .. "." ) end
        files[ #files + 1 ] = { filePath, result.body }
    end

    if #files == 0 then
        logger:Error( "Package '%s' import failed, no files to download.", url )
        return
    end

    if info.mount == false then
        local compiledFiles = {}
        for _, data in ipairs( files ) do
            local ok, result = pcall( CompileString, data[ 2 ], data[ 1 ] )
            if not ok then return promise.Reject( "file '" .. data[ 1 ] .. "' compile failed, " .. result .. "." ) end
            if not result then return promise.Reject( "file '" ..  data[ 1 ] .. "' compile failed, no result." ) end
            compiledFiles[ data[ 1 ] ] = result
        end

        local main = info.main
        if type( main ) ~= "string" then
            main = "init.lua"
        end

        local func = package.GetCompiledFile( main, compiledFiles )
        if not func then
            func = package.GetCompiledFile( "main.lua", compiledFiles )
        end

        if not func then
            gpm.Error( url, "main file is missing." )
        end

        return package.Initialize( info, func, compiledFiles )
    end

    local gma = gmad.Write( cachePath )
    if not gma then
        gpm.Error( url, "cache construction error." )
    end

    gma:SetTitle( info.name )
    gma:SetDescription( util.TableToJSON( info ) )

    local author = info.author
    if author ~= nil then
        gma:SetAuthor( author )
    end

    for _, data in ipairs( files ) do
        gma:AddFile( data[ 1 ], data[ 2 ] )
    end

    gma:Close()

    return gpm.SourceImport( "gma", "data/" .. cachePath, _PKG, false )
end )

-- Libraries
local packages = gpm.packages
local sources = gpm.sources
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
local SERVER = SERVER
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type

local cacheLifetime = GetConVar( "gpm_cache_lifetime" )

module( "gpm.sources.http" )

function CanImport( filePath )
    return string.IsURL( filePath )
end

local cacheFolder = "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/"
fs.CreateDir( cacheFolder )

local allowedExtensions = {
    ["lua"] = true,
    ["zip"] = true,
    ["gma"] = true,
    ["json"] = true
}

Import = promise.Async( function( url, parentPackage )
    if string.match( url, "^https?://github.com/[^/]+/[^/]+$" ) ~= nil then
        return sources.github.Import( url, parentPackage )
    end

    local wsid = string.match( url, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
    if wsid ~= nil then
        if not sources.workshop then
            logger:Error( "Package `%s` import failed, importing content from the workshop is not possible due to the missing steamworks library, you can download the binary module here: https://github.com/WilliamVenner/gmsv_workshop", wsid )
            return
        end

        return sources.workshop.Import( wsid, parentPackage )
    end

    local extension = string.GetExtensionFromFilename( url )
    if not extension then extension = "json" end

    if not allowedExtensions[ extension ] then
        logger:Error( "Package `%s` import failed, unsupported file extension. ", url )
        return
    end

    -- Cache
    local cachePath = cacheFolder .. "http_" .. util.MD5( url ) .. "."  .. ( extension == "json" and "gma" or extension ) .. ".dat"
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        if extension == "zip" then
            return sources.zip.Import( "data/" .. cachePath, parentPackage )
        elseif extension == "gma" or extension == "json" then
            return sources.gmad.Import( "data/" .. cachePath, parentPackage )
        elseif extension == "lua" then
            local ok, result = fs.Compile( cachePath, "DATA" ):SafeAwait()
            if not ok then
                logger:Error( "Package `%s` import failed, cache `%s` compile error: %s. ", url, cachePath, result )
                return
            end

            return packages.Initialize( packages.GetMetadata( {
                ["name"] = url
            } ), result, {}, parentPackage )
        end
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

        if extension == "zip" then
            return sources.zip.Import( "data/" .. cachePath, parentPackage )
        elseif extension == "gma" then
            return sources.gmad.Import( "data/" .. cachePath, parentPackage )
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

        return packages.Initialize( packages.GetMetadata( {
            ["name"] = url,
            ["autorun"] = true
        } ), result, sources.lua.Files, parentPackage )
    end

    metadata = utils.LowerTableKeys( metadata )

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
        metadata = packages.GetMetadata( packageFile )

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

        local mainFile = metadata.main
        if not mainFile then
            mainFile = "init.lua"
        end

        local func = compiledFiles[ mainFile ]
        if not func then
            mainFile = "main.lua"
            func = Files[ mainFile ]
        end

        if not func then
            logger:Error( "Package `%s` import failed, main file is missing.", url )
            return
        end

        return packages.Initialize( metadata, func, compiledFiles, parentPackage )
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

    return sources.gmad.Import( "data/" .. cachePath, parentPackage )
end )

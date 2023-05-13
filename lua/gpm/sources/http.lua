-- Libraries
local sources = gpm.sources
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
    local url = info.url

    if string.match( url, "^https?://github.com/[^/]+/[^/]+$" ) ~= nil then
        return sources.github.Import( sources.github.GetInfo( url ) )
    end

    local wsid = string.match( url, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
    if wsid ~= nil then
        local workshop = sources.workshop
        if not workshop then
            logger:Error( "Package `%s` import failed, importing content from the workshop is not possible due to the missing steamworks library, you can download the binary module here: https://github.com/WilliamVenner/gmsv_workshop", wsid )
            return
        end

        return workshop.Import( workshop.GetInfo( wsid ) )
    end

    local extension = string.GetExtensionFromFilename( url ) or "json"
    if not allowedExtensions[ extension ] then
        logger:Error( "Package `%s` import failed, unsupported file extension. ", url )
        return
    end

    -- Local cache
    local cachePath = cacheFolder .. "http_" .. util.MD5( url ) .. "."  .. ( extension == "json" and "gma" or extension ) .. ".dat"
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        if extension == "zip" then
            return sources.zip.Import( sources.zip.GetInfo( "data/" .. cachePath ) )
        elseif extension == "gma" or extension == "json" then
            return sources.gmad.Import( sources.gmad.GetInfo( "data/" .. cachePath ) )
        elseif extension == "lua" then
            local ok, result = fs.Compile( cachePath, "DATA" ):SafeAwait()
            if not ok then
                logger:Error( "Package `%s` import failed, cache `%s` compile error: %s. ", url, cachePath, result )
                return
            end

            return package.Initialize( package.GetMetadata( {
                ["name"] = url
            } ), result, {} )
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
            return sources.zip.Import( sources.zip.GetInfo( "data/" .. cachePath ) )
        elseif extension == "gma" then
            return sources.gmad.Import( sources.gmad.GetInfo( "data/" .. cachePath ) )
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
        } ), result, sources.lua.Files )
    end

    metadata = utils.LowerTableKeys( metadata )

    -- Singleplayer
    if not metadata.singleplayer and isSinglePlayer then
        logger:Error( "Package `%s` import failed, cannot be executed in a single-player game.", url )
        return
    end

    -- Gamemode
    local gamemodes = metadata.gamemodes
    local gamemodesType = type( gamemodes )
    if ( gamemodesType == "string" and gamemodes ~= activeGamemode ) or ( gamemodesType == "table" and not table.HasIValue( gamemodes, activeGamemode ) ) then
        logger:Error( "Package `%s` import failed, is not compatible with active gamemode.", url )
        return
    end

    -- Map
    local maps = metadata.maps
    local mapsType = type( maps )
    if ( mapsType == "string" and maps ~= currentMap ) or ( mapsType == "table" and not table.HasIValue( maps, currentMap ) ) then
        logger:Error( "Package `%s` import failed, is not compatible with current map.", url )
        return
    end

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

    return sources.gmad.Import( sources.gmad.GetInfo( "data/" .. cachePath ) )
end )

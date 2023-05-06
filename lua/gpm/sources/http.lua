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
local util_MD5 = util.MD5
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
            return promise.Reject( "Importing content from the workshop is not possible due to the missing steamworks library, you can download the binary module here: https://github.com/WilliamVenner/gmsv_workshop" )
        end

        return sources.workshop.Import( wsid, parentPackage )
    end

    local extension = string.GetExtensionFromFilename( url )
    if not extension then extension = "json" end

    if not allowedExtensions[ extension ] then
        return promise.Reject( "Unsupported file extension. (" .. url .. ")" )
    end

    local packageName = util.MD5( url )

    -- Cache
    local cachePath = cacheFolder .. "http_" .. packageName .. "."  .. ( extension == "json" and "gma" or extension ) .. ".dat"
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        if extension == "zip" then
            return sources.zip.Import( "data/" .. cachePath, parentPackage )
        elseif extension == "gma" or extension == "json" then
            return sources.gmad.Import( "data/" .. cachePath, parentPackage )
        elseif extension == "lua" then
            local ok, result = fs.Compile( cachePath, "DATA" ):SafeAwait()
            if not ok then
                return promise.Reject( string.format( "Package `%s` cache compile error: %s. (%s)", url, result, cachePath ) )
            end

            return packages.Initialize( packages.GetMetadata( {
                ["name"] = packageName
            } ), result, {}, parentPackage )
        end
    end

    -- Downloading
    logger:Info( "Package `%s` is downloading...", url )
    local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    if result.code ~= 200 then
        return promise.Reject( string.format( "Package `%s` downloading failed, invalid response http code (%s).", url, result.code ) )
    end

    -- Processing
    local body = result.body
    if extension ~= "json" then
        local ok, result = fs.AsyncWrite( cachePath, body ):SafeAwait()
        if not ok then return promise.Reject( result ) end

        if extension == "zip" then
            return sources.zip.Import( "data/" .. cachePath, parentPackage )
        elseif extension == "gma" then
            return sources.gmad.Import( "data/" .. cachePath, parentPackage )
        end

        return promise.Reject( "Unknown file format. (" .. url .. ")" )
    end

    local metadata = util.JSONToTable( body )
    if not metadata then
        local ok, err = fs.AsyncWrite( cachePath, body ):SafeAwait()
        if not ok then
            return promise.Reject( string.format( "Failed cache write: %s (%s), file system message: %s", cachePath, url, err ) )
        end

        local ok, result = pcall( CompileString, body, url )
        if not ok then return promise.Reject( result ) end
        if not result then return promise.Reject( "File `" .. url .. "` compilation failed." ) end

        return packages.Initialize( packages.GetMetadata( {
            ["name"] = packageName,
            ["autorun"] = true
        } ), result, sources.lua.Files, parentPackage )
    end

    metadata = utils.LowerTableKeys( metadata )

    local urls = metadata.files
    if type( urls ) ~= "table" then
        return promise.Reject( string.format( "No links to files, download canceled. (%s)", url ) )
    end

    metadata.files = nil

    local files = {}
    for filePath, fileURL in pairs( urls ) do
        local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( "file " .. filePath .. " downloading failed, with error: " .. result ) end
        if result.code ~= 200 then return promise.Reject( "file " .. filePath .. " downloading failed, with code: " .. result.code ) end
        files[ #files + 1 ] = { filePath, result.body }
    end

    if #files == 0 then
        return promise.Reject( string.format( "No files to download. (%s)", url ) )
    end

    if metadata.mount == false then
        metadata = packages.GetMetadata( packageFile )

        local compiledFiles = {}
        for _, data in ipairs( files ) do
            local ok, result = pcall( CompileString, data[ 2 ], data[ 1 ] )
            if not ok then return promise.Reject( result ) end
            if not result then return promise.Reject( "Package `" .. url .. "`, file `" .. data[ 1 ] .. "` compilation failed." ) end
            compiledFiles[ data[ 1 ] ] = result
        end

        if not metadata.name then
            metadata.name = util_MD5( url )
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
            return promise.Reject( string.format( "Package `%s` main file is missing!", metadata.name .. "@" .. metadata.version ) )
        end

        return packages.Initialize( metadata, func, compiledFiles, parentPackage )
    end

    local gma = gmad.Write( cachePath )
    if not gma then
        return promise.Reject( string.format( "Package cache construction error, mounting failed. (%s)", url ) )
    end

    local name = metadata.name
    if name ~= nil then
        gma:SetTitle( name )
    else
        gma:SetTitle( packageName )
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

-- Libraries
local packages = gpm.packages
local sources = gpm.sources
local promise = gpm.promise
local logger = gpm.Logger
local utils = gpm.utils
local gmad = gpm.gmad
local http = gpm.http
local string = string
local fs = gpm.fs
local util = util

-- Variables
local CompileString = CompileString
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

local realmFolder = "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/"
fs.CreateDir( realmFolder )

Import = promise.Async( function( url, parentPackage )
    local wsid = string.match( url, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
    if wsid ~= nil then return sources.workshop.Import( wsid, parentPackage ) end

    local packageName = util.MD5( url )

    local cachePath = realmFolder .. "/http_" .. packageName .. ".dat"
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        local gma = gmad.Open( cachePath, "DATA" )
        if gma ~= nil then
            return sources.gmad.Import( "data/" .. cachePath, parentPackage )
        end

        local ok, result = fs.Compile( cachePath, "DATA" ):SafeAwait()
        if not ok then
            logger:Error( "Package `%s` cache compile error: %s. (%s)", url, result, cachePath )
            return
        end

        return packages.Initialize( packages.GetMetadata( {
            ["name"] = packageName
        } ), result, {}, parentPackage )
    end

    local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    if result.code ~= 200 then
        logger:Error( "Package `%s` downloading failed, invalid response http code (%s).", url, result.code )
        return
    end

    local code = result.body
    local metadata = util.JSONToTable( code )
    if not metadata then
        local ok, err = fs.AsyncWrite( cachePath, code ):SafeAwait()
        if not ok then
            logger:Error( "Failed cache write: %s (%s), file system message: %s", cachePath, url, err )
        end

        local ok, result = pcall( CompileString, code, url )
        if not ok then return promise.Reject( result ) end
        if not result then return promise.Reject( "File `" .. url .. "` compilation failed." ) end

        return packages.Initialize( packages.GetMetadata( {
            ["name"] = packageName
        } ), result, {}, parentPackage )
    end

    metadata = utils.LowerTableKeys( metadata )

    local urls = metadata.files
    if type( urls ) ~= "table" then
        logger:Error( "No links to files, download canceled. (%s)", url )
        return
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
        logger:Error( "No files to download. (%s)", url )
        return
    end

    if metadata.mount == false then
        metadata = packages.GetMetadata( packageFile )

        local cFiles = {}
        for _, data in ipairs( files ) do
            local ok, result = pcall( CompileString, data[ 2 ], data[ 1 ] )
            if not ok then return promise.Reject( result ) end
            if not result then return promise.Reject( "File `" .. data[ 1 ] .. "` compilation failed." ) end
            cFiles[ data[ 1 ] ] = result
        end

        if not metadata.name then
            metadata.name = util_MD5( url )
        end

        local mainFile = metadata.main
        if not mainFile then
            mainFile = "init.lua"
        end

        local func = cFiles[ mainFile ]
        if not func then
            mainFile = "main.lua"
            func = Files[ mainFile ]
        end

        if not func then
            logger:Error( "Package `%s` main file is missing!", metadata.name .. "@" .. metadata.version )
            return
        end

        return packages.Initialize( metadata, func, cFiles, parentPackage )
    end

    local gma = gmad.Write( cachePath )
    if not gma then
        logger:Error( "Cache construction error, mounting failed. (%s)", url )
        return
    end

    gma:SetTitle( metadata.name or packageName )
    gma:SetDescription( util.TableToJSON( metadata ) )

    local author = metadata.author
    if author ~= nil then
        gma:SetAuthor( author )
    end

    for _, tbl in ipairs( files ) do
        gma:AddFile( tbl[ 1 ], tbl[ 2 ] )
    end

    gma:Close()

    return sources.gmad.Import( "data/" .. cachePath, parentPackage )
end )

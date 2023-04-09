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

local realmFolder = "gpm/packages" .. "/" .. ( SERVER and "server" or "client" )
fs.CreateDir( realmFolder )

Import = promise.Async( function( url, parentPackage )
    local wsid = string.match( url, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
    if wsid ~= nil then return sources.workshop.Import( wsid, parentPackage ) end

    local packageName = util.SHA1( url )

    local cachePath = realmFolder .. "/http_" .. packageName .. ".dat"
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        local gma = gmad.Open( cachePath, "DATA" )
        if gma ~= nil then
            fileClass:Close()
            return sources.gmad.Import( "data/" .. cachePath, parentPackage )
        end

        local code = fs.Read( cachePath, "DATA" )
        if code then
            local ok, result = pcall( CompileString, code, cachePath )
            if not ok then return promise.Reject( result ) end
            if not result then return promise.Reject( "file compilation failed" ) end
            return packages.Initialize( packages.GetMetaData( {
                ["name"] = packageName
            } ), result, {}, parentPackage )
        end

        return promise.Reject( "file reading failed" )
    end

    local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    if result.code ~= 200 then return promise.Reject( "invalid response http code - " .. result.code ) end

    local code = result.body
    local metadata = util.JSONToTable( code )
    if not metadata then
        fs.AsyncWrite( cachePath, code )
        local ok, result = pcall( CompileString, code, url )
        if not ok then return promise.Reject( result ) end
        if not result then return promise.Reject( "file compilation failed" ) end
        return packages.Initialize( packages.GetMetaData( {
            ["name"] = packageName
        } ), result, {}, parentPackage )
    end

    metadata = utils.LowerTableKeys( metadata )

    local urls = metadata.files
    if type( urls ) ~= "table" then return promise.Reject( "no urls to files" ) end
    metadata.files = nil

    local files = {}
    for filePath, fileURL in pairs( urls ) do
        local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( "file " .. filePath .. " downloading failed, with error: " .. result ) end
        if result.code ~= 200 then return promise.Reject( "file " .. filePath .. " downloading failed, with code: " .. result.code ) end
        files[ #files + 1 ] = { filePath, result.body }
    end

    if #files == 0 then return promise.Reject( "no files" ) end

    local gma = gmad.Write( cachePath )
    if not gma then return promise.Reject( "cache construction error" ) end

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

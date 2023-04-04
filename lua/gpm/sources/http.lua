-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local utils = gpm.utils
local http = gpm.http
local file = file
local util = util

-- Variables
local string_IsURL = string.IsURL
local pairs = pairs
local pcall = pcall

module( "gpm.sources.http" )

function CanImport( filePath )
    return string_IsURL( filePath )
end

local realmFolder = "gpm/package" .. "/" .. ( SERVER and "server" or "client" )
utils.CreateFolder( realmFolder )

PackageLifeTime = 60 * 60 * 24

Import = promise.Async( function( url )
    local packageName = util.CRC( url )

    local cachePath = realmFolder .. "/" .. packageName
    if file.Exists( cachePath, "DATA" ) and file.Time( cachePath, "DATA" ) <= PackageLifeTime then
        local ok, result = pcall( CompileString, code, filePath )
        if not ok then return promise.Reject( result ) end
        return packages.Initialize( packages.GetMetaData( {
            ["name"] = packageName
        } ), result, {} )
    end

    local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    if result.code ~= 200 then return promise.Reject( "invalid response http code - " .. result.code ) end

    local metadata = util.JSONToTable( result.body )
    if not metadata then
        local ok, result = pcall( CompileString, result.body, filePath )
        if not ok then return promise.Reject( "package metadata is damaged" ) end
        return packages.Initialize( packages.GetMetaData( {
            ["name"] = packageName
        } ), result, {} )
    end

    metadata = packages.GetMetaData( utils.LowerTableKeys( metadata ) )

    if not metadata.files then return promise.Reject( "package is empty" ) end

    local mainFile = metadata.main
    if type( mainFile ) ~= "string" then
        mainFile = "init.lua"
    end

    metadata.main = mainFile

    local files = {}
    for filePath, fileURL in pairs( metadata.files ) do
        local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( "file " .. filePath .. " downloading failed, with error: " .. result ) end
        if result.code ~= 200 then return promise.Reject( "file " .. filePath .. " downloading failed, with code: " .. result.code ) end

        local ok, result = pcall( CompileString, result.body, filePath )
        if not ok then return promise.Reject( result ) end
        files[ filePath ] = result
    end

    metadata.source = metadata.source or "http"
    metadata.files = nil

    local func = files[ mainFile ]
    if not func then return promise.Reject( "main file '" .. mainFile .. "' is missing" ) end

    return packages.Initialize( metadata, func, files )
end )

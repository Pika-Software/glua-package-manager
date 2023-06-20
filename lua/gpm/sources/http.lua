local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local http = gpm.http
local string = string
local table = table
local gmad = gmad
local fs = gpm.fs
local util = util

-- Variables
local CompileMoonString = CompileMoonString
local CompileString = CompileString
local logger = gpm.Logger
local ipairs = ipairs
local pcall = pcall
local type = type

local cacheLifetime = gpm.CacheLifetime
local cacheFolder = gpm.CachePath

local supportedExtensions = {
    ["lua"] = true,
    ["zip"] = true,
    ["gma"] = true,
    ["json"] = true
}

local jsonExtensions = {
    ["php"] = true
}

module( "gpm.sources.http" )

function CanImport( filePath )
    return string.IsURL( filePath )
end

GetMetadata = promise.Async( function( importPath )
    local metadata = {}

    local wsid = string.match( importPath, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
    if wsid then
        metadata.workshopid = wsid
        return metadata
    end

    local github = string.match( importPath, "github%.com/[^/]+/[^/]+$" )
    if github then
        metadata.github = github
        return metadata
    end

    local extension = string.GetExtensionFromFilename( importPath )
    if extension then
        if jsonExtensions[ extension ] then
            extension = "json"
        elseif not supportedExtensions[ extension ] then
            return promise.Reject( "Package '" .. importPath .. "' metadata cannot be retrieved, unsupported file extension." )
        end
    else
        extension = "json"
    end

    metadata.extension = extension

    if extension == "json" then
        logger:Info( "Package '%s' JSON is downloading...", importPath )

        local ok, result = http.Fetch( importPath, nil, 120 ):SafeAwait()
        if not ok then
            return promise.Reject( result )
        end

        if result.code ~= 200 then
            return promise.Reject( "Package '%s' JSON download failed, wrong HTTP response code (" .. result.code .. ")." )
        end

        local json = util.JSONToTable( body )
        if not json then
            return promise.Reject( "Package '" .. importPath .. "' JSON data is corrupted." )
        end

        table.Merge( metadata, json )
    end

    return metadata
end )

Import = promise.Async( function( metadata )
    local wsid = metadata.workshopid
    if wsid then
        return gpm.SourceImport( "workshop", wsid )
    end

    local github = metadata.github
    if github then
        return gpm.SourceImport( "github", gitHub )
    end

    local extension = metadata.extension
    local importpath = metadata.importpath

    -- Cache
    local cachePath = cacheFolder .. "http_" .. util.MD5( importpath ) .. "."  .. ( extension == "json" and "gma" or extension ) .. ".dat"
    if fs.IsFile( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        if extension == "json" then
            return gpm.SourceImport( "gma", "data/" .. cachePath )
        elseif extension == "gma" or extension == "zip" then
            return gpm.SourceImport( extension, "data/" .. cachePath )
        end

        local ok, result
        if extension == "lua" then
            ok, result = fs.CompileLua( cachePath, "DATA" ):SafeAwait()
        elseif extension == "moon" then
            ok, result = fs.CompileMoon( cachePath, "DATA" ):SafeAwait()
        end

        if not ok then
            return promise.Reject( result )
        end

        return package.Initialize( metadata, result, {
            [ cachePath ] = result
        } )
    end

    -- JSON
    if extension == "json" then
        local source = metadata.source
        if type( source ) ~= "table" then
            return promise.Reject( "No 'source' parameter, can't determine code source, cancelling..." )
        end

        local files = {}

        local urls = source.urls
        if type( urls ) == "table" then
            for _, data in ipairs( urls ) do
                utils.LowerTableKeys( data )

                local filePath = data.filepath
                if type( filePath ) ~= "string" then
                    return promise.Reject( "" )
                end

                local url = data.url
                if type( url ) ~= "string" then
                    return promise.Reject( "" )
                end

                local headers = data.headers
                if type( headers ) ~= "table" then
                    headers = nil
                end

                logger:Debug( "Package '%s' file '%s' (%s) is downloading...", importpath, filePath, url )

                local ok, result = http.Fetch( url, headers, 120 ):SafeAwait()
                if not ok then
                    return promise.Reject( "Package '" .. importpath .. "' file '" .. filePath .. "' (" .. url .. ") download failed, " .. result .. "." )
                end

                if result.code ~= 200 then
                    return promise.Reject( "Package '" .. importpath .. "' file '" .. filePath .. "' (" .. url .. ") download failed, wrong HTTP response code (" .. result.code .. ")." )
                end

                files[ #files + 1 ] = {
                    ["FilePath"] = filePath,
                    ["Content"] = result.body
                }
            end
        end

        if table.IsEmpty( files ) then
            return promise.Reject( "No files to compile, file list is empty." )
        end

        if metadata.mount == false then
            local compiled = {}
            for _, data in ipairs( files ) do
                local filePath = data.FilePath

                local ok, result
                if string.GetExtensionFromFilename( filePath ) == "moon" then
                    ok, result = pcall( CompileMoonString, data.Content, filePath )
                else
                    ok, result = pcall( CompileString, data.Content, filePath )
                end

                if not ok then
                    return promise.Reject( "File '" .. filePath .. "' compile failed, " .. result .. "." )
                end

                if not result then
                    return promise.Reject( "File '" ..  filePath .. "' compile failed, no result." )
                end

                compiled[ filePath ] = result
            end

            local initPath = package.GetCurrentInitByRealm( metadata.init )
            local func = compiled[ initPath ]
            if not func then
                return promise.Reject( "Package init file '" .. initPath .. "' is missing or compilation was failed." )
            end

            return package.Initialize( metadata, func, compiled )
        end

        local gma = gmad.Write( cachePath )
        if not gma then
            return promise.Reject( "Package '" .. importpath .. "' cache file '" .. cachePath .. "' writing failed." )
        end

        local name = metadata.name
        if name then
            gma:SetTitle( name )
        end

        gma:SetDescription( util.TableToJSON( metadata ) )

        local author = metadata.author
        if author then
            gma:SetAuthor( author )
        end

        for _, data in ipairs( files ) do
            gma:AddFile( data[ 1 ], data[ 2 ] )
        end

        gma:Close()

        return gpm.SourceImport( "gma", "data/" .. cachePath )
    end

    logger:Info( "Package '%s' is downloading...", importpath )

    local headers = metadata.headers
    if type( headers ) ~= "table" then
        headers = nil
    end

    local ok, result = http.Fetch( importpath, headers, 120 ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    if result.code ~= 200 then
        return promise.Reject( "Package '%s' download failed, wrong HTTP response code (" .. result.code .. ")." )
    end

    local ok, err = fs.AsyncWrite( cachePath, result.body ):SafeAwait()
    if not ok then
        return promise.Reject( "Package '" .. importpath .. "' cache writing failed, " .. err )
    end

    if extension == "lua" then
        local ok, result = pcall( CompileString, result.body, cachePath )
        if not ok then
            return promise.Reject( result )
        end

        return package.Initialize( metadata, result )
    elseif extension == "moon" then
        local ok, result = pcall( CompileMoonString, result.body, cachePath )
        if not ok then
            return promise.Reject( result )
        end

        return package.Initialize( metadata, result )
    elseif extension == "gma" or extension == "zip" then
        return gpm.SourceImport( extension, "data/" .. cachePath )
    end

    return promise.Reject( "How did you do that?!" )
end )

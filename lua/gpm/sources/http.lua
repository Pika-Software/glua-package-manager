-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local utils = gpm.utils
local http = gpm.http
local file = file
local util = util

-- Variables
local CompileString = CompileString
local string_IsURL = string.IsURL
local SERVER = SERVER
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type

module( "gpm.sources.http" )

function CanImport( filePath )
    return string_IsURL( filePath )
end

local realmFolder = "gpm/packages" .. "/" .. ( SERVER and "server" or "client" )
utils.CreateFolder( realmFolder )

PackageLifeTime = 60 * 60 * 24

Import = promise.Async( function( url, env )
    local packageName = util.CRC( url )

    local cachePath = realmFolder .. "/" .. packageName .. ".dat"
    if file.Exists( cachePath, "DATA" ) and file.Time( cachePath, "DATA" ) <= PackageLifeTime then
        local fileClass = file.Open( cachePath, "rb", "DATA" )
        if fileClass ~= nil then
            if fileClass:Read( 4 ) == "GPMP" then
                local json = fileClass:ReadString()
                if json then
                    local metadata = util.JSONToTable( json )
                    if metadata ~= nil then

                        local entries, offset = {}, 0
                        while fileClass:ReadULong() ~= 0 do
                            local entry = {}
                            entry.Path = fileClass:ReadString()
                            entry.Size = fileClass:ReadULong()
                            entry.Offset = offset

                            entries[ #entries + 1 ] = entry
                            offset = offset + entry.Size
                        end

                        local dataPos = fileClass:Tell()

                        for _, entry in ipairs( entries ) do
                            fileClass:Seek( dataPos + entry.Offset )
                            entry.Content = fileClass:Read( entry.Size )
                        end

                        fileClass:Close()

                        local files = {}
                        for _, entry in ipairs( entries ) do
                            local ok, result = pcall( CompileString, entry.Content, entry.Path )
                            if not ok then return promise.Reject( result ) end
                            files[ entry.Path ] = result
                        end

                        local func = files[ metadata.main ]
                        if not func then return promise.Reject( "main file is missing" ) end

                        return packages.Initialize( metadata, func, files, env )
                    end
                end

                fileClass:Close()

                return promise.Reject( "package file is damaged" )
            end

            fileClass:Seek( -4 )
            local code = fileClass:Read( fileClass:Size() )
            fileClass:Close()

            if not code then return promise.Reject( "no data" ) end

            local ok, result = pcall( CompileString, code, cachePath )
            if not ok then return promise.Reject( result ) end
            return packages.Initialize( packages.GetMetaData( {
                ["name"] = packageName
            } ), result, {}, env )
        end
    end

    local ok, result = http.Fetch( url, nil, 120 ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    if result.code ~= 200 then return promise.Reject( "invalid response http code - " .. result.code ) end

    local metadata = util.JSONToTable( result.body )
    if not metadata then
        local code = result.body

        local ok, result = pcall( CompileString, code, cachePath )
        if not ok then return promise.Reject( result ) end

        file.Write( cachePath, code )

        return packages.Initialize( packages.GetMetaData( {
            ["name"] = packageName
        } ), result, {}, env )
    end

    metadata = packages.GetMetaData( utils.LowerTableKeys( metadata ) )

    if not metadata.files then return promise.Reject( "package is empty" ) end
    metadata.source = metadata.source or "http"

    local mainFile = metadata.main
    if type( mainFile ) ~= "string" then
        mainFile = "init.lua"
    end

    metadata.main = mainFile

    local content = {}
    for filePath, fileURL in pairs( metadata.files ) do
        local ok, result = http.Fetch( fileURL, nil, 120 ):SafeAwait()
        if not ok then return promise.Reject( "file " .. filePath .. " downloading failed, with error: " .. result ) end
        if result.code ~= 200 then return promise.Reject( "file " .. filePath .. " downloading failed, with code: " .. result.code ) end
        content[ #content + 1 ] = { result.body, filePath }
    end

    metadata.files = nil

    local files = {}
    for _, data in ipairs( content ) do
        local ok, result = pcall( CompileString, data[ 1 ], data[ 2 ] )
        if not ok then return promise.Reject( result ) end
        files[ data[ 2 ] ] = result
    end

    local func = files[ mainFile ]
    if not func then return promise.Reject( "main file '" .. mainFile .. "' is missing" ) end

    local fileClass = file.Open( cachePath, "wb", "DATA" )
    if fileClass ~= nil then
        fileClass:WriteString( "GPMP" )
        fileClass:WriteString( util.TableToJSON( metadata ) )

        for num, data in ipairs( content ) do
            fileClass:WriteULong( num )
            fileClass:WriteString( data[ 1 ] )
            fileClass:WriteULong( #data[ 2 ] )
        end

        fileClass:WriteULong( 0 )

        for num, data in ipairs( content ) do
            fileClass:Write( data[ 2 ] )
        end

        fileClass:Flush()
        fileClass:Close()
    end

    return packages.Initialize( metadata, func, files, env )
end )

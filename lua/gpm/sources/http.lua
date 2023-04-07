-- Libraries
local packages = gpm.packages
local sources = gpm.sources
local promise = gpm.promise
local utils = gpm.utils
local pkgf = gpm.pkgf
local http = gpm.http
local string = string
local file = file
local util = util

-- Variables
local CompileString = CompileString
local SERVER = SERVER
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type

module( "gpm.sources.http" )

function CanImport( filePath )
    return string.IsURL( filePath )
end

local realmFolder = "gpm/packages" .. "/" .. ( SERVER and "server" or "client" )
utils.CreateFolder( realmFolder )

PackageLifeTime = 60 * 60 * 24

Import = promise.Async( function( url, parentPackage )
    local wsid = string.match( url, "steamcommunity%.com/sharedfiles/filedetails/%?id=(%d+)" )
    if wsid ~= nil then return sources.workshop.Import( wsid, parentPackage ) end

    local packageName = util.CRC( url )

    local cachePath = realmFolder .. "/" .. packageName .. ".dat"
    if file.Exists( cachePath, "DATA" ) and file.Time( cachePath, "DATA" ) <= PackageLifeTime then
        local fileClass = file.Open( cachePath, "rb", "DATA" )
        if fileClass ~= nil then
            local pkg = pkgf.Read( fileClass )
            if pkg ~= nil then
                local files = pkg:ReadAllFiles()
                if not files then return promise.Reject( "package is empty" ) end

                local packageFiles = {}
                for _, entry in ipairs( files ) do
                    local filePath = entry.path
                    local ok, result = pcall( CompileString, entry.Content, filePath )
                    if not ok then return promise.Reject( result ) end
                    packageFiles[ filePath ] = result
                end

                local metadata = packages.GetMetaData( pkg:GetMetadata() )

                local func = packageFiles[ metadata.main ]
                if not main then return promise.Reject( "main file is missing (" .. metadata.name .. "@" .. metadata.version .. ")" ) end

                return packages.Initialize( metadata, func, packageFiles, parentPackage )
            end

            fileClass:SeekToStart()
            local code = fileClass:Read( fileClass:Size() )
            fileClass:Close()

            if not code then return promise.Reject( "no data" ) end

            local ok, result = pcall( CompileString, code, cachePath )
            if not ok then return promise.Reject( result ) end
            if not result then return promise.Reject( "file compilation failed" ) end

            return packages.Initialize( packages.GetMetaData( {
                ["name"] = packageName
            } ), result, {}, parentPackage )
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
        if not result then return promise.Reject( "file compilation failed" ) end

        file.Write( cachePath, code )

        return packages.Initialize( packages.GetMetaData( {
            ["name"] = packageName
        } ), result, {}, parentPackage )
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

    local pkg = pkgf.Write( cachePath )
    if pkg ~= nil then
        -- Info
        pkg:SetName( metadata.name )
        pkg:SetMainFile( metadata.main )
        pkg:SetVersion( metadata.version )

        -- Client & Server
        pkg:SetClient( metadata.client )
        pkg:SetServer( metadata.server )

        -- Package Author
        local author = metadata.author
        if type( author ) == "string" then
            pkg:SetAuthor( author )
        end

        pkg:Close()
    end

    return packages.Initialize( metadata, func, files, parentPackage )
end )

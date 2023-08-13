local SERVER = SERVER
local util = util
local gpm = gpm
local logger = gpm.Logger

-- https://github.com/Pika-Software/gm_asyncio
-- https://github.com/WilliamVenner/gm_async_write
if util.IsBinaryModuleInstalled( "asyncio" ) and pcall( require, "asyncio" ) then
    logger:Info( "A third-party file system API 'asyncio' has been initialized." )
elseif SERVER and util.IsBinaryModuleInstalled( "async_write" ) and pcall( require, "async_write" ) then
    logger:Info( "A third-party file system API 'async_write' has been initialized." )
end

-- https://github.com/Pika-Software/gm_efsw
if util.IsBinaryModuleInstalled( "efsw" ) and pcall( require, "efsw" ) then
    logger:Info( "gm_efsw is initialized, package auto-reload are available." )
end

-- Libraries
local moonloader = moonloader
local asyncio = asyncio
local promise = promise
local paths = gpm.paths
local string = string
local table = table
local file = file
local efsw = efsw

-- Variables
local CompileMoonString = CompileMoonString
local CompileString = CompileString
local game_MountGMA = game.MountGMA
local debug_fempty = debug.fempty
local MENU_DLL = MENU_DLL
local CLIENT = CLIENT
local select = select
local ipairs = ipairs
local error = error
local type = type

module( "gpm.fs" )

Delete = file.Delete
Rename = file.Rename
Open = file.Open
Find = file.Find
Size = file.Size
Time = file.Time

function IsFile( ... )
    return Exists( ... ) and not IsDir( ... )
end

function MountGMA( gmaPath )
    error( "Not yet implemented." )
end

if type( MountedFiles ) ~= "table" then
    MountedFiles = {}
end

if not MENU_DLL then
    function MountGMA( gmaPath )
        local ok, files = game_MountGMA( gmaPath )
        if ok then
            for _, filePath in ipairs( files ) do
                table.insert( MountedFiles, 1, filePath )
            end

            logger:Debug( "GMA file '%s' was mounted to GAME with %d files.", gmaPath, #files  )
        else
            logger:Error( "GMA file '%s' mounting failed.", gmaPath )
        end

        return ok, files
    end
end

local gamePaths = {
    ["LUA"] = "lua",
    ["lsv"] = "lua",
    ["lcl"] = "lua"
}

-- https://github.com/Facepunch/garrysmod-issues/issues/5481
function IsMounted( filePath, gamePath, onlyDir )
    if onlyDir and string.GetExtensionFromFilename( filePath ) then return end

    local additional = gamePaths[ gamePath ]
    if additional then
        filePath = additional .. "/" .. filePath
    end

    for _, mountedFile in ipairs( MountedFiles ) do
        if string.StartsWith( mountedFile, filePath ) then return true end
    end

    return false
end

function Exists( filePath, gamePath )
    return IsMounted( filePath, gamePath ) or file.Exists( filePath, gamePath )
end

function IsDir( filePath, gamePath )
    return IsMounted( filePath, gamePath, true ) or file.IsDir( filePath, gamePath )
end

function IsFile( filePath, gamePath )
    return IsMounted( filePath, gamePath ) or ( file.Exists( filePath, gamePath ) and not file.IsDir( filePath, gamePath ) )
end

function IsLuaFile( filePath, gamePath, compileMoon )
    local extension = string.GetExtensionFromFilename( filePath )
    if extension and extension ~= "lua" and extension ~= "moon" then
        return false
    end

    filePath = string.sub( filePath, 1, #filePath - ( extension ~= nil and ( #extension + 1 ) or 0 ) )

    if ( SERVER or MENU_DLL ) and moonloader ~= nil then
        local moonPath = filePath  .. ".moon"
        if IsFile( moonPath, gamePath ) then
            if compileMoon then
                if not moonloader.PreCacheFile( moonPath ) then
                    error( "Compiling Moonscript file '" .. moonPath .. "' into Lua is failed!" )
                end

                logger:Debug( "The MoonScript file '%s' was successfully compiled into Lua.", moonPath )
            end

            return true
        end
    end

    return IsFile( filePath .. ".lua", gamePath )
end

function Read( filePath, gamePath, length )
    local fileClass = Open( filePath, "rb", gamePath )
    if not fileClass then return end

    local fileContent = fileClass:Read( length )
    fileClass:Close()

    return fileContent
end

function Write( filePath, contents, fileMode )
    local fileClass = Open( filePath, fileMode or "wb", "DATA" )
    if not fileClass then
        error( "Writing file 'data/" .. filePath .. "' was failed!" )
    end

    fileClass:Write( contents )
    fileClass:Close()
end

function Append( filePath, contents )
    Write( filePath, contents, "ab" )
end

function CreateDir( folderPath )
    local currentPath = nil

    for _, folderName in ipairs( string.Split( folderPath, "/" ) ) do
        if not folderName then continue end

        currentPath = currentPath and ( currentPath .. "/" .. folderName ) or folderName
        if IsDir( currentPath, "DATA" ) then continue end

        Delete( currentPath )
        file.CreateDir( currentPath )
    end

    return currentPath
end

function CompileLua( filePath, gamePath, handleError )
    if CLIENT and IsMounted( filePath, gamePath ) then
        filePath = "lua/" .. filePath
        gamePath = "GAME"
    end

    local content = Read( filePath, gamePath )
    if not content then
        error( "File compilation '" .. filePath .. "' failed, file cannot be read." )
    end

    local func = CompileString( content, filePath, handleError )
    if not func then
        error( "File compilation '" .. filePath .. "' failed, unknown error." )
    end

    return func
end

function CompileMoon( filePath, gamePath, handleError )
    local content = Read( filePath, gamePath )
    if not content then
        error( "File compilation '" .. filePath .. "' failed, file cannot be read." )
    end

    return CompileMoonString( content, filePath, handleError )
end

Watch = debug_fempty
UnWatch = debug_fempty

if efsw ~= nil then
    local watchList = efsw.WatchList
    if type( watchList ) ~= "table" then
        watchList = {}; efsw.WatchList = watchList
    end

    function Watch( filePath, gamePath, recursively )
        filePath = paths.Fix( filePath )

        if CLIENT and IsMounted( filePath, gamePath ) then return end
        if watchList[ filePath .. ";" .. gamePath ] then return end
        if IsDir( filePath, gamePath ) then
            filePath = filePath .. "/"
            if recursively then
                for _, folder in ipairs( select( -1, Find( filePath .. "*", gamePath ) ) ) do
                    Watch( filePath .. folder, gamePath, recursively )
                end
            end
        end

        watchList[ filePath .. ";" .. gamePath ] = efsw.Watch( filePath, gamePath )
    end

    function UnWatch( filePath, gamePath, recursively )
        filePath = paths.Fix( filePath )

        local watchID = watchList[ filePath .. ";" .. gamePath ]
        if not watchID then return end

        if IsDir( filePath, gamePath ) then
            filePath = filePath .. "/"
            if recursively then
                for _, folder in ipairs( select( -1, Find( filePath .. "*", gamePath ) ) ) do
                    UnWatch( filePath .. folder, gamePath, recursively )
                end
            end
        end

        efsw.Unwatch( watchID )
        watchList[ filePath .. ";" .. gamePath ] = nil
    end
end

if asyncio ~= nil then
    function AsyncRead( filePath, gamePath )
        local p = promise.New()

        if asyncio.AsyncRead( filePath, gamePath, function( filePath, gamePath, status, fileContent )
            if status ~= 0 then
                return p:Reject( "Async read error, code: " .. status )
            end

            p:Resolve( {
                ["fileContent"] = fileContent,
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end ) ~= 0 then
            p:Reject( "Async read error, code: " .. status )
        end

        return p
    end

    function AsyncWrite( filePath, fileContent )
        local p = promise.New()

        if asyncio.AsyncWrite( filePath, fileContent, function( filePath, gamePath, status )
            if status ~= 0 then
                return p:Reject( "Async write error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end ) ~= 0 then
            p:Reject( "Async write error, code: " .. status )
        end

        return p
    end

    function AsyncAppend( filePath, fileContent )
        local p = promise.New()

        if asyncio.AsyncAppend( filePath, fileContent, function( filePath, gamePath, status )
            if status ~= 0 then
                return p:Reject( "Async append error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end ) ~= 0 then
            p:Reject( "Async append error, code: " .. status )
        end

        return p
    end

    return
end

function AsyncRead( filePath, gamePath )
    local p = promise.New()

    if file.AsyncRead( filePath, gamePath, function( filePath, gamePath, status, fileContent )
        if status ~= 0 then
            return p:Reject( "Async read error, code: " .. status )
        end

        p:Resolve( {
            ["filePath"] = filePath,
            ["gamePath"] = gamePath,
            ["fileContent"] = fileContent
        } )
    end ) ~= 0 then
        p:Reject( "Async read error, code: " .. status )
    end

    return p
end

if type( file.AsyncWrite ) == "function" then
    function AsyncWrite( filePath, fileContent )
        local p = promise.New()

        if file.AsyncWrite( filePath, fileContent, function( filePath, status )
            if status ~= 0 then
                return p:Reject( "Async write error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath
            } )
        end ) ~= 0 then
            p:Reject( "Async write error, code: " .. status )
        end

        return p
    end
else
    function AsyncWrite( filePath, fileContent )
        local p = promise.New()

        Write( filePath, fileContent )

        if Exists( filePath, "DATA" ) then
            p:Resolve( {
                ["filePath"] = filePath
            } )
        else
            p:Reject( "failed" )
        end

        return p
    end
end

if type( file.AsyncAppen ) == "function" then
    function AsyncAppend( filePath, fileContent )
        local p = promise.New()

        if file.AsyncAppend( filePath, fileContent, function( filePath, status )
            if status ~= 0 then
                return p:Reject( "Async append error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath
            } )
        end ) ~= 0 then
            p:Reject( "Async append error, code: " .. status )
        end

        return p
    end
else
    function AsyncAppend( filePath, fileContent )
        local p = promise.New()

        Append( filePath, fileContent )
        p:Resolve( {
            ["filePath"] = filePath
        } )

        return p
    end
end
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

Move = file.Rename
Open = file.Open
Find = file.Find
Time = file.Time

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
    if IsMounted( filePath, gamePath, true ) or file.IsDir( filePath, gamePath ) then return true end
    if SERVER then return false end

    local _, folders = Find( filePath .. "*", gamePath )
    if folders == nil or #folders == 0 then return false end

    local splits = string.Split( filePath, "/" )
    return table.HasIValue( folders, splits[ #splits ] )
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

    if compileMoon and ( SERVER or MENU_DLL ) and moonloader ~= nil then
        local moonPath = filePath  .. ".moon"
        if IsFile( moonPath, gamePath ) then
            if not moonloader.PreCacheFile( moonPath ) then
                error( "Compiling Moonscript file '" .. moonPath .. "' into Lua is failed!" )
            end

            logger:Debug( "The MoonScript file '%s' was successfully compiled into Lua.", moonPath )
            return true
        end
    end

    return IsFile( filePath .. ".lua", gamePath )
end

function Size( filePath, gamePath )
    if IsDir( filePath, gamePath ) then
        local files, folders = Find( paths.Join( filePath, "*" ), gamePath )
        local size = 0

        for _, folderName in ipairs( folders ) do
            size = size + Size( paths.Join( filePath, folderName ), gamePath )
        end

        for _, fileName in ipairs( files ) do
            size = size + Size( paths.Join( filePath, fileName ), gamePath )
        end

        return size
    end

    return file.Size( filePath, gamePath )
end

function Read( filePath, gamePath, length )
    local fileClass = Open( filePath, "rb", gamePath )
    if not fileClass then return end

    local content = fileClass:Read( length )
    fileClass:Close()
    return content
end

function Delete( filePath, gamePath, force )
    gamePath = gamePath or "DATA"

    if IsDir( filePath, gamePath ) then
        if force then
            local files, folders = Find( paths.Join( filePath, "*" ), gamePath )
            for _, folderName in ipairs( folders ) do
                Delete( paths.Join( filePath, folderName ), gamePath, force )
            end

            for _, fileName in ipairs( files ) do
                Delete( paths.Join( filePath, fileName ), gamePath, force )
            end
        end

        file.Delete( filePath, gamePath )
        return not IsDir( filePath, gamePath )
    end

    file.Delete( filePath, gamePath )
    return not IsFile( filePath, gamePath )
end

function CreateDir( folderPath )
    local currentPath
    for _, folderName in ipairs( string.Split( folderPath, "/" ) ) do
        if not folderName then continue end

        currentPath = currentPath and ( currentPath .. "/" .. folderName ) or folderName
        if file.IsDir( currentPath, "DATA" ) then continue end

        Delete( currentPath )
        file.CreateDir( currentPath )
    end

    return currentPath
end

function CreateFilePath( filePath )
    local folder = string.GetPathFromFilename( filePath )
    if folder then
        return CreateDir( folder )
    end
end

function Write( filePath, contents, fileMode )
    CreateFilePath( filePath )

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

if not efsw then
    Watch = debug_fempty
    UnWatch = debug_fempty
else
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

        local status = asyncio.AsyncRead( filePath, gamePath, function( filePath, gamePath, status, content )
            if status ~= 0 then
                return p:Reject( "Async read error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath,
                ["gamePath"] = gamePath,
                ["content"] = content
            } )
        end )

        if status ~= 0 then
            p:Reject( "Async read error, code: " .. status )
        end

        return p
    end

    function AsyncWrite( filePath, content )
        CreateFilePath( filePath )
        local p = promise.New()

        local status = asyncio.AsyncWrite( filePath, content, function( filePath, gamePath, status )
            if status ~= 0 then
                return p:Reject( "Async write error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end )

        if status ~= 0 then
            p:Reject( "Async write error, code: " .. status )
        end

        return p
    end

    function AsyncAppend( filePath, content )
        CreateFilePath( filePath )
        local p = promise.New()

        local status = asyncio.AsyncAppend( filePath, content, function( filePath, gamePath, status )
            if status ~= 0 then
                return p:Reject( "Async append error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end )

        if status ~= 0 then
            p:Reject( "Async append error, code: " .. status )
        end

        return p
    end

    return
end

function AsyncRead( filePath, gamePath )
    local p = promise.New()

    local status = file.AsyncRead( filePath, gamePath, function( filePath, gamePath, status, content )
        if status ~= 0 then
            return p:Reject( "Async read error, code: " .. status )
        end

        p:Resolve( {
            ["filePath"] = filePath,
            ["gamePath"] = gamePath,
            ["content"] = content
        } )
    end )

    if status ~= 0 then
        p:Reject( "Async read error, code: " .. status )
    end

    return p
end

if type( file.AsyncWrite ) == "function" then
    function AsyncWrite( filePath, content )
        CreateFilePath( filePath )
        local p = promise.New()

        local status = file.AsyncWrite( filePath, content, function( filePath, status )
            if status ~= 0 then
                return p:Reject( "Async write error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath
            } )
        end )

        if status ~= 0 then
            p:Reject( "Async write error, code: " .. status )
        end

        return p
    end
else
    function AsyncWrite( filePath, content )
        Write( filePath, content )
        return promise.Resolve( {
            ["filePath"] = filePath
        } )
    end
end

if type( file.AsyncAppen ) == "function" then
    function AsyncAppend( filePath, content )
        CreateFilePath( filePath )
        local p = promise.New()

        local status = file.AsyncAppend( filePath, content, function( filePath, status )
            if status ~= 0 then
                return p:Reject( "Async append error, code: " .. status )
            end

            p:Resolve( {
                ["filePath"] = filePath
            } )
        end )

        if status ~= 0 then
            p:Reject( "Async append error, code: " .. status )
        end

        return p
    end
else
    function AsyncAppend( filePath, content )
        Append( filePath, content )
        return promise.Resolve( {
            ["filePath"] = filePath
        } )
    end
end
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
local gpm_fs_gmod_async = CreateConVar( "gpm_fs_gmod_async", "1", FCVAR_ARCHIVE, "Allow gpm to use standard async gmod file system functions.", 0, 1 )
local CompileMoonString = CompileMoonString
local CompileString = CompileString
local game_MountGMA = game.MountGMA
local debug_fempty = debug.fempty
local MENU_DLL = MENU_DLL
local CLIENT = CLIENT
local select = select
local ipairs = ipairs
local pcall = pcall
local pairs = pairs
local error = error
local type = type

module( "gpm.fs" )

Move = file.Rename
Open = file.Open
Find = file.Find
Time = file.Time

if type( MountedFiles ) ~= "table" then
    MountedFiles = {}
end

if MENU_DLL then
    function MountGMA( gmaPath )
        error( "Not yet implemented." )
    end
else
    function MountGMA( gmaPath )
        local ok, files = game_MountGMA( gmaPath )
        if not ok then error( "gma could not be mounted" ) end

        for _, filePath in ipairs( files ) do
            table.insert( MountedFiles, 1, filePath )
        end

        logger:Debug( "GMA file '%s' was mounted to GAME with %d files.", gmaPath, #files  )
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

function Write( filePath, content, fileMode, fastMode )
    if not fastMode then CreateFilePath( filePath ) end

    local fileClass = Open( filePath, fileMode or "wb", "DATA" )
    if not fileClass then
        error( "Writing file 'data/" .. filePath .. "' was failed!" )
    end

    fileClass:Write( content )
    fileClass:Close()
end

function Append( filePath, content, fastMode )
    Write( filePath, content, "ab", fastMode )
end

local asyncSources = {
    {
        Available = asyncio ~= nil,
        Get = function()
            return {
                append = asyncio.Append,
                write = asyncio.Write,
                read = asyncio.Read
            }
        end
    },
    {
        Available = file.AsyncAppen ~= nil,
        Get = function()
            return {
                append = file.AsyncAppen
            }
        end
    },
    {
        Available = file.AsyncWrite ~= nil,
        Get = function()
            return {
                write = file.AsyncWrite
            }
        end
    },
    {
        Available = file.AsyncRead ~= nil and gpm_fs_gmod_async:GetBool(),
        Get = function()
            return {
                read = file.AsyncRead
            }
        end
    },
    {
        Available = true,
        Get = function()
            return {
                append = function( fileName, content, func )
                    local ok = pcall( Append, fileName, content, true )
                    local state = ok and 0 or -1
                    func( fileName, "DATA", state )
                    return state
                end,
                write = function( fileName, content, func )
                    local ok = pcall( Write, fileName, content, "wb", true )
                    local state = ok and 0 or -1
                    func( fileName, "DATA", state )
                    return state
                end,
                read = function( fileName, gamePath, func )
                    local ok, content = pcall( Read, fileName, gamePath )
                    local state = ok and 0 or -1
                    func( fileName, gamePath, state, content )
                    return state
                end
            }
        end
    }
}

local async = {
    append = false,
    write = false,
    read = false
}

for _, source in ipairs( asyncSources ) do
    if not source.Available then continue end
    local functions = source.Get()

    for funcName, func in pairs( async ) do
        if func ~= false then continue end
        func = functions[ funcName ]
        if func then
            async[ funcName ] = func
        end
    end
end

function AsyncRead( fileName, gameDir )
    local p = promise.New()

    local state = async.read( fileName, gameDir, function( filePath, gamePath, code, content )
        if code ~= 0 then return p:Reject( "FSASYNC_READ_ERR: " .. code ) end
        p:Resolve( {
            ["filePath"] = filePath,
            ["gamePath"] = gamePath,
            ["content"] = content
        } )
    end )

    if state ~= 0 then
        p:Reject( "FSASYNC_READ_ERR: " .. state )
    end

    return p
end

function AsyncWrite( fileName, content )
    CreateFilePath( fileName )
    local p = promise.New()

    local state = async.write( fileName, content, function( filePath, gamePath, code )
        if code ~= 0 then return p:Reject( "FSASYNC_WRITE_ERR: " .. code ) end
        p:Resolve( {
            ["filePath"] = filePath,
            ["gamePath"] = gamePath
        } )
    end )

    if state ~= 0 then
        p:Reject( "FSASYNC_WRITE_ERR: " .. state )
    end

    return p
end

function AsyncAppend( fileName, content )
    CreateFilePath( fileName )
    local p = promise.New()

    local state = async.append( fileName, content, function( filePath, gamePath, code )
        if code ~= 0 then return p:Reject( "FSASYNC_APPEND_ERR: " .. code ) end
        p:Resolve( {
            ["filePath"] = filePath,
            ["gamePath"] = gamePath
        } )
    end )

    if state ~= 0 then
        p:Reject( "FSASYNC_APPEND_ERR: " .. state )
    end

    return p
end

CompileLua = promise.Async( function( filePath, gamePath, handleError )
    if CLIENT and IsMounted( filePath, gamePath ) then
        filePath = "lua/" .. filePath
        gamePath = "GAME"
    end

    local ok, result = AsyncRead( filePath, gamePath ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local content = result.content
    if not content then
        return promise.Reject( "File compilation '" .. filePath .. "' failed, file cannot be read." )
    end

    local func = CompileString( content, filePath, handleError )
    if not func then
        return promise.Reject( "File compilation '" .. filePath .. "' failed, unknown error." )
    end

    return func
end )

CompileMoon = promise.Async( function( filePath, gamePath, handleError )
    local ok, result = AsyncRead( filePath, gamePath ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local content = result.content
    if not content then
        return promise.Reject( "File compilation '" .. filePath .. "' failed, file cannot be read." )
    end

    return CompileMoonString( content, filePath, handleError )
end )

if efsw then
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
else
    Watch, UnWatch = debug_fempty, debug_fempty
end
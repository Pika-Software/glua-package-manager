-- Libraries
local string = string
local table = table

-- Variables
local MENU_DLL = MENU_DLL
local SERVER = SERVER
local ipairs = ipairs
local Color = Color
local pairs = pairs
local type = type

MsgN( [[
    ____    _____    ___ ___
   /'_ `\ /\ '__`\ /' __` __`\
  /\ \L\ \\ \ \L\ \/\ \/\ \/\ \
  \ \____ \\ \ ,__/\ \_\ \_\ \_\
   \/___L\ \\ \ \/  \/_/\/_/\/_/
     /\____/ \ \_\
     \_/__/   \/_/

  GitHub: https://github.com/Pika-Software
  Discord: https://discord.gg/3UVxhZ
  Developers: Pika Software
  License: MIT
]] )

module( "gpm", package.seeall )

_VERSION = 012500

if not Colors then
    Colors = {
        ["SecondaryText"] = Color( 150, 150, 150 ),
        ["PrimaryText"] = Color( 200, 200, 200 ),
        ["White"] = Color( 255, 255, 255 ),
        ["Info"] = Color( 70, 135, 255 ),
        ["Warn"] = Color( 255, 130, 90 ),
        ["Error"] = Color( 250, 55, 40 ),
        ["Debug"] = Color( 0, 200, 150 )
    }

    LuaRealm = "LUA"

    if MENU_DLL then
        Colors.Realm = Color( 75, 175, 80 )
    elseif CLIENT then
        Colors.Realm = Color( 225, 170, 10 )
        LuaRealm = "lcl"
    elseif SERVER then
        Colors.Realm = Color( 5, 170, 250 )
        LuaRealm = "lsv"
    end
end

local luaRealm = LuaRealm

do

    local AddCSLuaFile = SERVER and AddCSLuaFile
    local include = include

    function IncludeComponent( filePath )
        filePath = "gpm/" .. filePath  .. ".lua"
        if SERVER then AddCSLuaFile( filePath ) end
        return include( filePath )
    end

end

local stopwatch = SysTime()

IncludeComponent "utils"
IncludeComponent "fixes"
IncludeComponent "logger"

Logger = logger.Create( "GPM@" .. utils.Version( _VERSION ), Color( 180, 180, 255 ) )

local ErrorNoHaltWithStack = ErrorNoHaltWithStack

do

    local error = error

    function Error( importPath, message, noHalt, sourceName )
        Logger:Error( "[%s] Package '%s' import failed, see above to see the error.", sourceName or "unknown", importPath )
        if noHalt then
            ErrorNoHaltWithStack( message )
            return
        end

        error( message )
    end

end

libs = {}
libs.deflatelua = IncludeComponent "libs/deflatelua"
Logger:Info( "%s %s is initialized.", libs.deflatelua._NAME, libs.deflatelua._VERSION )

IncludeComponent "libs/promise"
local promise = promise

Logger:Info( "gm_promise %s is initialized.", utils.Version( promise._VERSION_NUM ) )

IncludeComponent "environment"
IncludeComponent "gmad"
IncludeComponent "http"
IncludeComponent "fs"
IncludeComponent "zip"

if Packages then
    table.Empty( Packages )
else
    Packages = {}
end

IncludeComponent "package"

local fs = fs

CacheLifetime = CreateConVar( "gpm_cache_lifetime", "24", FCVAR_ARCHIVE, "Packages cache lifetime, in hours, sets after how many hours the downloaded gpm packages will not be relevant.", 0, 60480 )
WorkshopPath = fs.CreateDir( "gpm/" .. ( SERVER and "server" or "client" ) .. "/workshop/" )
CachePath = fs.CreateDir( "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/" )

do

    local CompileFile = CompileFile
    local ArgAssert = ArgAssert
    local pcall = pcall
    local files = {}

    function GetCompiledFiles()
        return files
    end

    CompileLua = promise.Async( function( filePath )
        ArgAssert( filePath, 1, "string" )

        local func = files[ filePath ]
        if func then return func end

        local ok, result = fs.Compile( filePath, luaRealm ):SafeAwait()
        if ok then
            func = result
        elseif MENU_DLL then
            return promise.Reject( result )
        else
            ok, result = pcall( CompileFile, filePath )
            if not ok then return promise.Reject( result ) end
        end

        if ok and type( result ) == "function" then
            files[ filePath ] = result
            return result
        end

        return promise.Reject( "File '" .. filePath .. "' code compilation failed due to an unknown error." )
    end )

end

sources = sources or {}

for _, filePath in ipairs( fs.Find( "gpm/sources/*", "LUA" ) ) do
    filePath = "gpm/sources/" .. filePath

    if SERVER then
        AddCSLuaFile( filePath )
    end

    include( filePath )
end

local IsPackage = IsPackage

do

    local sourceList = {}

    for sourceName in pairs( sources ) do
        sourceList[ #sourceList + 1 ] = sourceName
    end

    function CanImport( importPath )
        for _, sourceName in ipairs( sourceList ) do
            local source = sources[ sourceName ]
            if not source then continue end
            if not source.CanImport( importPath ) then continue end
            return true
        end

        return false
    end

    function LocatePackage( importPath, alternative )
        ArgAssert( importPath, 1, "string" )
        if CanImport( importPath ) then
            return importPath
        end

        if type( alternative ) ~= "string" then
            return importPath
        end

        return alternative
    end

    function LinkTaskToPackage( task, pkg )
        if task:IsPending() then
            task:Then( function( pkg2 )
                if IsPackage( pkg2 ) then
                    pkg:Link( pkg2 )
                end
            end )
        elseif task:IsFulfilled() then
            local pkg2 = task:GetResult()
            if IsPackage( pkg2 ) then
                pkg:Link( pkg2 )
            end
        end
    end

    local tasks, metadatas = {}, {}
    local package = package

    SourceImport = promise.Async( function( sourceName, importPath )
        local task = tasks[ importPath ]
        if not task then
            local source = sources[ sourceName ]
            if not source then
                return promise.Reject( "Requested package source not found." )
            end

            local metadata = metadatas[ sourceName .. ";" .. importPath ]
            if not metadata then
                if type( source.GetMetadata ) == "function" then
                    metadata = package.GetMetadata( source.GetMetadata( importPath ):Await() )
                else
                    metadata = package.GetMetadata( {} )
                end

                metadatas[ sourceName .. ";" .. importPath ] = metadata
            end

            if CLIENT and not metadata.client then return promise.Reject( "Package does not support running on the client." ) end
            if MENU_DLL and not metadata.menu then return promise.Reject( "Package does not support running in menu." ) end

            if type( metadata.name ) ~= "string" then
                metadata.name = importPath
            end

            metadata.import_path = importPath
            metadata.source = sourceName

            if not metadata.singleplayer and SinglePlayer then
                return promise.Reject( "Package cannot be executed in a singleplayer game." )
            end

            local gamemodes = metadata.gamemodes
            local gamemodesType = type( gamemodes )
            if ( gamemodesType == "string" and gamemodes ~= Gamemode ) or ( gamemodesType == "table" and not table.HasIValue( gamemodes, Gamemode ) ) then
                return promise.Reject( "Package does not support active gamemode." )
            end

            local maps = metadata.maps
            local mapsType = type( maps )
            if ( mapsType == "string" and maps ~= Map ) or ( mapsType == "table" and not table.HasIValue( maps, Map ) ) then
                return promise.Reject( "Package does not support current map." )
            end

            if SERVER then
                if metadata.client then
                    if type( source.SendToClient ) == "function" then
                        source.SendToClient( metadata )
                    end
                elseif not metadata.server then
                    return promise.Reject( "Package does not support running on the server." )
                end
            end

            task = source.Import( metadata )
            tasks[ importPath ] = task
        end

        return task
    end )

    AsyncImport = promise.Async( function( importPath, pkg, autorun )
        if not string.IsURL( importPath ) then
            importPath = paths.Fix( importPath )
        end

        local task = tasks[ importPath ]
        if not task then
            for _, sourceName in ipairs( sourceList ) do
                local source = sources[ sourceName ]
                if not source then continue end

                if not source.CanImport( importPath ) then continue end

                if autorun then
                    local metadata = metadatas[ sourceName .. ";" .. importPath ]
                    if not metadata then
                        if type( source.GetMetadata ) == "function" then
                            metadata = package.GetMetadata( source.GetMetadata( importPath ):Await() )
                        else
                            metadata = package.GetMetadata( {} )
                        end

                        metadatas[ sourceName .. ";" .. importPath ] = metadata
                    end

                    if not metadata.autorun then
                        Logger:Debug( "[%s] Package '%s' autorun restricted.", sourceName, importPath )
                        if SERVER and metadata.client and type( source.SendToClient ) == "function" then
                            source.SendToClient( metadata )
                        end

                        return
                    end
                end

                task = SourceImport( sourceName, importPath, autorun )
                break
            end
        end

        if not task then
            return promise.Reject( "Requested package doesn't exist." )
        end

        if IsPackage( pkg ) then
            LinkTaskToPackage( task, pkg )
        end

        return task
    end )

end

Gamemode = engine.ActiveGamemode()
SinglePlayer = game.SinglePlayer()
Map = game.GetMap()

do

    local assert = assert

    function Import( importPath, async, pkg )
        assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

        local import = AsyncImport( importPath, pkg )
        if not async then
            local pkg = import:Await()
            if not pkg then return end
            return pkg:GetResult(), pkg
        end

        return import
    end

    _G.import = Import

end

-- https://github.com/Pika-Software/gm_moonloader
if util.IsBinaryModuleInstalled( "moonloader" ) then
    gpm.Logger:Info( "Moonloader engaged." )
    require( "moonloader" )
end

local moonloader = moonloader

function ImportFolder( folderPath, pkg, autorun )
    if not fs.IsDir( folderPath, luaRealm ) then
        Logger:Warn( "Import impossible, folder '%s' does not exist, skipping...", folderPath )
        return
    end

    Logger:Info( "Starting to import packages from '%s'", folderPath )

    if moonloader then
        moonloader.PreCacheDir( folderPath )
    end

    local files, folders = fs.Find( folderPath .. "/*", luaRealm )
    for _, folderName in ipairs( folders ) do
        local importPath = folderPath .. "/" .. folderName
        AsyncImport( importPath, pkg, autorun ):Catch( function( message )
            Error( importPath, message, true, "lua" )
        end )
    end

    for _, fileName in ipairs( files ) do
        local importPath = folderPath .. "/" .. fileName
        AsyncImport( importPath, pkg, autorun ):Catch( function( message )
            Error( importPath, message, true, "lua" )
        end )
    end
end

function ClearCache()
    local count, size = 0, 0

    for _, fileName in ipairs( fs.Find( CachePath .. "*", "DATA" ) ) do
        local filePath = CachePath .. fileName
        local fileSize = fs.Size( filePath, "DATA" )
        fs.Delete( filePath )

        if not fs.IsFile( filePath, "DATA" ) then
            size = size + fileSize
            count = count + 1
            continue
        end

        Logger:Warn( "Unable to remove file '%s' probably used by the game, restart game and try again.", filePath )
    end

    for _, fileName in ipairs( fs.Find( WorkshopPath .. "*", "DATA" ) ) do
        local filePath = WorkshopPath .. fileName
        local fileSize = fs.Size( filePath, "DATA" )
        fs.Delete( filePath )

        if not fs.IsFile( filePath, "DATA" ) then
            size = size + fileSize
            count = count + 1
            continue
        end

        Logger:Warn( "Unable to remove file '%s' probably used by the game, restart game and try again.", filePath )
    end

    Logger:Info( "Deleted %d cache files, freeing up %dMB of space.", count, size / 1024 / 1024 )
end

do

    local MsgC = MsgC

    function PrintPackageList()
        MsgC( Colors.Realm, SERVER and "Server" or "Client", Colors.PrimaryText, " packages:\n" )

        local total = 0
        for name, pkg in pairs( Packages ) do
            MsgC( Colors.Realm, "\t* ", Colors.PrimaryText, string.format( "%s@%s\n", name, pkg:GetVersion() ) )
            total = total + 1
        end

        MsgC( Colors.Realm, "\tTotal: ", Colors.PrimaryText, total, "\n" )
    end

end

function Reload()
    hook.Run( "GPM - Reload" )
    include( "gpm/init.lua" )
    hook.Run( "GPM - Reloaded" )
end

if SERVER then

    concommand.Add( "gpm_clear_cache", function( ply )
        if not IsValid( ply ) or ply:IsListenServerHost() then
            ClearCache()
        end

        ply:SendLua( "gpm.ClearCache()" )
    end )

    concommand.Add( "gpm_list", function( ply )
        if not IsValid( ply ) or ply:IsListenServerHost() then
            PrintPackageList()
        end

        ply:SendLua( "gpm.PrintPackageList()" )
    end )

    concommand.Add( "gpm_reload", function( ply )
        if not IsValid( ply ) or ply:IsSuperAdmin() then
            Reload(); BroadcastLua( "gpm.Reload()" )
            return
        end

        ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
    end )

end

Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )
hook.Run( "GPM - Initialized" )

util.NextTick( function()
    ImportFolder( "packages", nil, true )
end )
-- Libraries
local string = string
local table = table

-- Variables
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

_VERSION = 012000

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

do

    local error = error

    function Error( packageName, ... )
        Logger:Error( "Package '%s' import failed, see above to see the error.", packageName )
        error( ... )
    end

end

libs = {}
libs.deflatelua = IncludeComponent "libs/deflatelua"
Logger:Info( "%s %s is initialized.", libs.deflatelua._NAME, libs.deflatelua._VERSION )

IncludeComponent "promise"
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
    local pcall = pcall
    local files = {}

    function GetCompiledFiles()
        return files
    end

    function CompileLua( filePath )
        if not filePath or not fs.Exists( filePath, luaRealm ) then return end

        local func = files[ filePath ]
        if func then return func end

        local ok, result = pcall( CompileFile, filePath )
        if not ok then return end
        files[ filePath ] = result
        return result
    end

end

sources = sources or {}

for _, filePath in ipairs( fs.Find( "gpm/sources/*", "LUA" ) ) do
    filePath = "gpm/sources/" .. filePath

    if SERVER then
        AddCSLuaFile( filePath )
    end

    include( filePath )
end

do

    local sourceList = {}

    for sourceName in pairs( sources ) do
        sourceList[ #sourceList + 1 ] = sourceName
    end

    function PackageExists( packagePath )
        for _, sourceName in ipairs( sourceList ) do
            local source = sources[ sourceName ]
            if not source then continue end
            if not source.CanImport( packagePath ) then continue end
            return true
        end

        return false
    end

    local tasks = {}

    function SourceImport( sourceName, packagePath, package, autorun )
        if not string.IsURL( packagePath ) then
            packagePath = paths.Fix( packagePath )
        end

        local task = tasks[ packagePath ]
        if not task then
            local source = sources[ sourceName ]
            if not source or not source.CanImport( packagePath ) then return end

            local info = source.GetInfo( packagePath )
            if not info then
                Logger:Error( "Package '%s' import failed, no import info.", packagePath )
                return false
            end

            local sendToClient = source.SendToClient
            if autorun and not info.autorun then
                if SERVER and info.client and type( sendToClient ) == "function" then
                    sendToClient( info )
                end

                Logger:Debug( "Package '%s' autorun restricted.", packagePath )
                return false
            end

            if not info.singleplayer and SinglePlayer then
                Logger:Error( "Package '%s' import failed, cannot be executed in a single-player game.", packagePath )
                return false
            end

            local gamemodes = info.gamemodes
            local gamemodesType = type( gamemodes )
            if ( gamemodesType == "string" and gamemodes ~= Gamemode ) or ( gamemodesType == "table" and not table.HasIValue( gamemodes, Gamemode ) ) then
                Logger:Error( "Package '%s' import failed, is not compatible with active gamemode.", packagePath )
                return false
            end

            local maps = info.maps
            local mapsType = type( maps )
            if ( mapsType == "string" and maps ~= Map ) or ( mapsType == "table" and not table.HasIValue( maps, Map ) ) then
                Logger:Error( "Package '%s' import failed, is not compatible with current map.", packagePath )
                return false
            end

            if SERVER and info.client and type( sendToClient ) == "function" then
                sendToClient( info )
            end

            task = source.Import( info )
            tasks[ packagePath ] = task
        end

        if not promise.IsPromise( task ) then return end

        if IsPackage( package ) then
            if task:IsPending() then
                task:Then( function( package2 )
                    if not IsPackage( package2 ) then return end
                    package:Link( package2 )
                end )
            elseif task:IsFulfilled() then
                local package2 = task:GetResult()
                if IsPackage( package2 ) then
                    package:Link( package2 )
                end
            end
        end

        return task
    end

    function AsyncImport( packagePath, package, autorun )

        local task = tasks[ packagePath ]
        if not task then
            for _, sourceName in ipairs( sourceList ) do
                local p = SourceImport( sourceName, packagePath, package, autorun )
                if p == false then return end
                if p == nil then continue end
                task = p
            end
        end

        if not task then
            Error( packagePath, "Requested package doesn't exist!" )
            return
        end

        return task
    end

end

Gamemode = engine.ActiveGamemode()
SinglePlayer = game.SinglePlayer()
Map = game.GetMap()

do

    local assert = assert

    function Import( packagePath, async, package )
        assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

        local task = AsyncImport( packagePath, package, false )
        if not task then return end

        if not async then
            local ok, result = task:SafeAwait()
            if not ok then
                Error( packagePath, result )
            end

            if not result then
                Error( packagePath, "This should never have happened, but the package was missing after the import." )
            end

            return result:GetResult()
        end

        return task
    end

    _G.import = Import

end

function ImportFolder( folderPath, package, autorun )
    folderPath = paths.Fix( folderPath )

    if not fs.IsDir( folderPath, luaRealm ) then
        Logger:Warn( "Import impossible, folder '%s' is empty, skipping...", folderPath )
        return
    end

    Logger:Info( "Starting to import packages from '%s'", folderPath )

    local files, folders = fs.Find( folderPath .. "/*", luaRealm )
    for _, folderName in ipairs( folders ) do
        local packagePath = folderPath .. "/" .. folderName

        local p = AsyncImport( packagePath, package, autorun )
        if not p then continue end

        p:Catch( function( result )
            Error( packagePath, result )
        end )
    end

    for _, fileName in ipairs( files ) do
        local packagePath = folderPath .. "/" .. fileName

        local p = AsyncImport( packagePath, package, autorun )
        if not p then continue end

        p:Catch( function( result )
            Error( packagePath, result )
        end )
    end

end

function ClearCache()
    local count, size = 0, 0

    for _, fileName in ipairs( fs.Find( CachePath .. "*", "DATA" ) ) do
        local filePath = CachePath .. fileName
        local fileSize = fs.Size( filePath, "DATA" )
        fs.Delete( filePath )

        if not fs.Exists( filePath, "DATA" ) then
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

        if not fs.Exists( filePath, "DATA" ) then
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
        for name, package in pairs( Packages ) do
            MsgC( Colors.Realm, "\t* ", Colors.PrimaryText, string.format( "%s@%s\n", name, package:GetVersion() ) )
            total = total + 1
        end

        MsgC( Colors.Realm, "\tTotal: ", Colors.PrimaryText, total, "\n" )
    end

end

if SERVER then

    concommand.Add( "gpm_clear_cache", function( ply )
        if not ply or ply:IsListenServerHost() then
            ClearCache()
        end

        ply:SendLua( "gpm.ClearCache()" )
    end )

    concommand.Add( "gpm_list", function( ply )
        if not ply or ply:IsListenServerHost() then
            PrintPackageList()
        end

        ply:SendLua( "gpm.PrintPackageList()" )
    end )

    concommand.Add( "gpm_reload", function( ply )
        if not ply or ply:IsSuperAdmin() then
            BroadcastLua( "include( \"gpm/init.lua\" )" )
            include( "gpm/init.lua" )
            hook.Run( "GPM - Reloaded" )
            return
        end

        ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
    end )

end

ImportFolder( "packages", nil, true )

Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )
hook.Run( "GPM - Initialized" )
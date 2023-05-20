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

_VERSION = 012400

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

    local ErrorNoHaltWithStack = ErrorNoHaltWithStack
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

    local CompileString = CompileString
    local CompileFile = CompileFile
    local ArgAssert = ArgAssert
    local pcall = pcall
    local files = {}

    function GetCompiledFiles()
        return files
    end

    function CompileLua( filePath )
        ArgAssert( filePath, 1, "string" )

        local func = files[ filePath ]
        if func then return func end

        local fileClass = file.Open( filePath, "r", luaRealm )
        if fileClass then
            local code = fileClass:Read( fileClass:Size() )
            fileClass:Close()

            local ok, result = pcall( CompileString, code, filePath, true )
            if not ok then return ok, result end
            if not result then return false, "file '" .. filePath .. "' code compilation failed due to an unknown error." end
            func = result
        end

        if not func and not MENU_DLL then
            local ok, result = pcall( CompileFile, filePath )
            if not ok then return ok, result end
            if not result then return false, "file '" .. filePath .. "' code compilation failed due to an unknown error." end
            func = result
        end

        files[ filePath ] = func
        return true, func
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

local IsPackage = IsPackage

do

    local sourceList = {}

    for sourceName in pairs( sources ) do
        sourceList[ #sourceList + 1 ] = sourceName
    end

    function PackageExists( importPath )
        for _, sourceName in ipairs( sourceList ) do
            local source = sources[ sourceName ]
            if not source then continue end
            if not source.CanImport( importPath ) then continue end
            return true
        end

        return false
    end

    local tasks = {}

    function SourceImport( sourceName, importPath, pkg, autorun )
        if not string.IsURL( importPath ) then
            importPath = paths.Fix( importPath )
        end

        local task = tasks[ importPath ]
        if not task then
            local source = sources[ sourceName ]
            if not source or not source.CanImport( importPath ) then return end

            local info = source.GetInfo( importPath )
            if not info then
                return false, "not enough information to start importing"
            end

            if type( info.name ) ~= "string" then
                info.name = importPath
            end

            info.importPath = importPath
            info.source = sourceName

            if autorun and not info.autorun then
                local sendToClient = source.SendToClient
                if SERVER and info.client and type( sendToClient ) == "function" then
                    sendToClient( info )
                end

                Logger:Debug( "[%s] Package '%s' autorun restricted.", sourceName, importPath )
                return false
            end

            if not info.singleplayer and SinglePlayer then
                return false, "cannot be executed in a singleplayer game"
            end

            local gamemodes = info.gamemodes
            local gamemodesType = type( gamemodes )
            if ( gamemodesType == "string" and gamemodes ~= Gamemode ) or ( gamemodesType == "table" and not table.HasIValue( gamemodes, Gamemode ) ) then
                return false, "does not support active gamemode"
            end

            local maps = info.maps
            local mapsType = type( maps )
            if ( mapsType == "string" and maps ~= Map ) or ( mapsType == "table" and not table.HasIValue( maps, Map ) ) then
                return false, "does not support current map"
            end

            local sendToClient = source.SendToClient
            if SERVER and info.client and type( sendToClient ) == "function" then
                sendToClient( info )
            end

            task = source.Import( info )
            tasks[ importPath ] = task
        end

        if not promise.IsPromise( task ) then
            return false, "package task does not exist"
        end

        if task:IsPending() then
            task:Catch( function( message )
                Error( importPath, message, true, sourceName )
            end )
        end

        if IsPackage( pkg ) then
            if task:IsPending() then
                task:Then( function( package2 )
                    if IsPackage( package2 ) then
                        pkg:Link( package2 )
                    end
                end )
            elseif task:IsFulfilled() then
                local package2 = task:GetResult()
                if IsPackage( package2 ) then
                    pkg:Link( package2 )
                end
            end
        end

        return true, task
    end

    function SimpleSourceImport( sourceName, importPath, ... )
        local ok, result = gpm.SourceImport( sourceName, importPath, ... )
        if not ok then
            gpm.Error( importPath, result or "import from this source is impossible", false, sourceName )
        end

        return result
    end

    function AsyncImport( importPath, pkg, autorun )
        local task = tasks[ importPath ]
        if not task then
            for _, sourceName in ipairs( sourceList ) do
                local ok, result = SourceImport( sourceName, importPath, pkg or _PKG, autorun )
                if ok == nil then continue end
                if ok then
                    task = result
                    break
                end

                if result == nil then return end
                Error( importPath, result, autorun, sourceName )
                return
            end
        end

        if not task then
            Error( importPath, "Requested package doesn't exist!" )
        end

        return task
    end

end

Gamemode = engine.ActiveGamemode()
SinglePlayer = game.SinglePlayer()
Map = game.GetMap()

do

    local assert = assert

    function Import( importPath, async, pkg )
        assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

        local task = AsyncImport( importPath, pkg, false )
        if not task then return end

        if not async then
            local ok, result = task:SafeAwait()
            if not ok then return promise.Reject( result ) end
            if not IsPackage( result ) then return result end
            return result:GetResult()
        end

        return task
    end

    _G.import = Import

end

local moonloader = moonloader

function ImportFolder( folderPath, pkg, autorun )
    folderPath = paths.Fix( folderPath )

    if not fs.IsDir( folderPath, luaRealm ) then
        Logger:Warn( "Import impossible, folder '%s' is empty, skipping...", folderPath )
        return
    end

    Logger:Info( "Starting to import packages from '%s'", folderPath )

    if moonloader then
        moonloader.PreCacheDir( folderPath )
    end

    local files, folders = fs.Find( folderPath .. "/*", luaRealm )
    for _, folderName in ipairs( folders ) do
        AsyncImport( folderPath .. "/" .. folderName, pkg, autorun )
    end

    for _, fileName in ipairs( files ) do
        AsyncImport( folderPath .. "/" .. fileName, pkg, autorun )
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
            Reload(); BroadcastLua( "gpm.Reload()" )
            return
        end

        ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
    end )

end

Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - stopwatch )
hook.Run( "GPM - Initialized" )

util.NextTick( function()
    ImportFolder( "packages", _PKG, true )
end )
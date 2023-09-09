local AddCSLuaFile = AddCSLuaFile
local include = include
AddCSLuaFile()

local SERVER, MENU_DLL = SERVER, MENU_DLL
local SysTime = SysTime
local ipairs = ipairs
local Color = Color
local error = error
local pairs = pairs
local pcall = pcall
local type = type
local _G = _G

Msg( [[
    ____    _____    ___ ___
   /'_ `\ /\ '__`\ /' __` __`\
  /\ \L\ \\ \ \L\ \/\ \/\ \/\ \
  \ \____ \\ \ ,__/\ \_\ \_\ \_\
   \/___L\ \\ \ \/  \/_/\/_/\/_/
     /\____/ \ \_\
     \_/__/   \/_/

  GitHub: https://github.com/Pika-Software
  Discord: https://discord.gg/3UVxhZ
  Website: https://pika-soft.ru
  Developers: Pika Software
  License: MIT

]] )

module( "gpm", package.seeall )

StartTime = SysTime()
VERSION = "1.52.1"

if not Colors then
    Realm = "unknown"
    Colors = {
        ["SecondaryText"] = Color( 150, 150, 150 ),
        ["PrimaryText"] = Color( 200, 200, 200 ),
        ["White"] = Color( 255, 255, 255 ),
        ["Info"] = Color( 70, 135, 255 ),
        ["Warn"] = Color( 255, 130, 90 ),
        ["Error"] = Color( 250, 55, 40 ),
        ["Debug"] = Color( 0, 200, 150 )
    }

    if MENU_DLL then
        Colors.Realm = Color( 75, 175, 80 )
        Realm = "Menu"
    elseif CLIENT then
        Colors.Realm = Color( 225, 170, 10 )
        Realm = "Client"
    elseif SERVER then
        Colors.Realm = Color( 5, 170, 250 )
        Realm = "Server"
    end
end

local function includeComponent( fileName )
    local filePath = "gpm/" .. fileName  .. ".lua"
    if SERVER then AddCSLuaFile( filePath ) end
    return include( filePath )
end

includeComponent "utils"
includeComponent "logger"
Logger = CreateLogger( "GPM@" .. VERSION, Color( 180, 180, 255 ) )

deflate = includeComponent "libs/deflate"
Logger:Info( "%s v%s is initialized.", deflate._NAME, deflate._VERSION )

includeComponent "libs/promise"
Logger:Info( "gm_promise v%s is initialized.", promise.VERSION )

local moonloader
if util.IsBinaryModuleInstalled( "moonloader" ) then
    local ok, message = pcall( require, "moonloader" )
    if ok then
        moonloader = _G.moonloader
        Logger:Info( "gm_moonloader v%s is initialized, MoonScript support is active.", utils.Version( moonloader._VERSION ) )
    else
        Logger:Error( "gm_moonloader startup error: %s", message )
    end
end

do

    local CompileString = CompileString

    function _G.CompileMoonString( moonCode, identifier, handleError )
        if not moonloader then
            error( "Attempting to compile a Moonscript file fails, install gm_moonloader and try again, https://github.com/Pika-Software/gm_moonloader." )
        end

        local luaCode, err = moonloader.ToLua( moonCode )
        if not luaCode then
            error( err or "MoonScript code compilation to Lua code failed." )
        end

        local func = CompileString( luaCode, identifier, handleError )
        if type( func ) ~= "function" then
            error( "MoonScript-Lua code compilation failed." )
        end

        return func
    end

end

includeComponent "libs/gmad"
Logger:Info( "gmad v%s is initialized.", utils.Version( gmad.GMA.Version ) )

includeComponent "libs/metaworks"
Logger:Info( "metaworks v%s is initialized.", metaworks.VERSION )

includeComponent "http"
includeComponent "fs"
includeComponent "zip"

TempPath = fs.CreateDir( "gpm/" .. string.lower( Realm ) .. "/temp/" )

if SERVER then

    function AddCSLuaFolder( folder )
        local files, folders = fs.Find( paths.Join( folder, "*" ), "lsv" )
        for _, folderName in ipairs( folders ) do
            AddCSLuaFolder( paths.Join( folder, folderName ) )
        end

        for _, fileName in ipairs( files ) do
            local filePath = paths.Join( folder, fileName )
            if fs.IsLuaFile( filePath, "lsv", true ) then
                AddCSLuaFile( paths.FormatToLua( filePath ) )
            end
        end
    end

end

if type( Packages ) ~= "table" then
    Packages = {}
end

do

    local string_find = string.find

    function Find( searchable, ignoreImportNames, noPatterns )
        local result = {}
        for importPath, pkg in pairs( Packages ) do
            if not ignoreImportNames and importPath == searchable then
                result[ #result + 1 ] = pkg
                continue
            end

            local name = pkg:GetName()
            if not name then continue end
            if string_find( name, searchable, 1, noPatterns ) ~= nil then
                result[ #result + 1 ] = pkg
            end
        end

        return result
    end

end

includeComponent "package"

do

    local CompileFile = CompileFile

    CompileLua = promise.Async( function( filePath )
        local ok, result = fs.CompileLua( filePath, "LUA" ):SafeAwait()
        if ok then return result end

        if MENU_DLL then return promise.Reject( result ) end

        local func = CompileFile( filePath )
        if not func then return promise.Reject( result ) end
        return func
    end )

end

includeComponent "import"

function ClearCache()
    local count, size = 0, 0

    for _, fileName in ipairs( fs.Find( TempPath .. "*", "DATA" ) ) do
        local filePath = TempPath .. fileName
        fs.Delete( filePath )

        if not fs.IsFile( filePath, "DATA" ) then
            size = size + fs.Size( filePath, "DATA" )
            count = count + 1
            continue
        end

        Logger:Warn( "Unable to remove file '%s' probably used by the game, restart game and try again.", filePath )
    end

    Logger:Info( "Deleted %d cache files, freeing up %dMB of space.", count, size / 1024 / 1024 )
end

do

    local MsgC = MsgC

    function PrintPackageList( packages )
        MsgC( Colors.Realm, Realm, Colors.PrimaryText, " packages:\n" )

        if type( packages ) ~= "table" then
            packages = {}

            for _, pkg in pairs( Packages ) do
                packages[ #packages + 1 ] = pkg
            end
        end

        table.sort( packages, function( a, b )
            return a:GetIdentifier() < b:GetIdentifier()
        end )

        local total = 0
        for _, pkg in pairs( packages ) do
            MsgC( Colors.Realm, "\t* ", Colors.PrimaryText, pkg:GetIdentifier() .. "\n" )
            total = total + 1
        end

        MsgC( Colors .Realm, "\tTotal: ", Colors.PrimaryText, total, "\n" )
    end

end

function Reload( ... )
    local arguments = { ... }
    if #arguments == 0 then
        Logger:Warn( "There is no information for package reloading, if you are trying to do a full reload then just use .*" )
        return
    end

    if SERVER then
        net.Start( "GPM.Networking" )
            net.WriteUInt( 2, 3 )
            net.WriteTable( arguments )
        net.Broadcast()
    end

    local packages, count = {}, 0
    for _, searchable in ipairs( arguments ) do
        if #searchable == 0 then continue end
        for _, pkg in ipairs( Find( searchable, false, false ) ) do
            packages[ pkg ] = true
            count = count + 1
        end
    end

    if count == 0 then
        Logger:Info( "No candidates found for reloading, skipping..." )
        return
    end

    Logger:Info( "Found %d candidates to reload, reloading...", count )

    for pkg in pairs( packages ) do
        pkg:Reload():Catch( function( message )
            Logger:Error( "Package '%s' reload failed, error:\n%s", pkg:GetIdentifier(), message )
        end )
    end
end

function Uninstall( force, ... )
    local arguments = {...}
    if #arguments == 0 then
        Logger:Warn( "There is no information for package uninstalling." )
        return
    end

    local packages, count = {}, 0
    for _, searchable in ipairs( arguments ) do
        if #searchable == 0 then continue end
        for _, pkg in ipairs( Find( searchable, false, false ) ) do
            packages[ pkg ] = true
            count = count + 1
        end
    end

    if count == 0 then
        Logger:Info( "No candidates found for uninstalling, skipping..." )
        return
    end

    Logger:Info( "Found %d candidates to uninstall, uninstalling...", count )

    for pkg in pairs( packages ) do
        local children = pkg:GetChildren()
        local childCount = #children
        if childCount ~= 0 and not force then
            Logger:Error( "Package '%s' uninstallation cancelled, %d dependencies found, try use -f to force uninstallation, skipping...", pkg:GetIdentifier(), childCount )
            PrintPackageList( children )
            continue
        end

        pkg:Uninstall()
    end
end

includeComponent "commands"
ClearCache()

ImportFolder( "packages", nil, true )
Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - StartTime )
hook.Run( "GPM - Initialized" )
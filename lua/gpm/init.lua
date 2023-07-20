local AddCSLuaFile = AddCSLuaFile
local include = include
AddCSLuaFile()

local SERVER, MENU_DLL = SERVER, MENU_DLL
local SysTime = SysTime
local Color = Color
local error = error
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
  Developers: Pika Software
  License: MIT

]] )

module( "gpm", package.seeall )

StartTime = SysTime()
VERSION = "1.42.0"

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

if SERVER then

    local ipairs = ipairs
    local paths = paths
    local fs = fs

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
    local pairs = pairs

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

CacheLifetime = CreateConVar( "gpm_cache_lifetime", "24", FCVAR_ARCHIVE, "Packages cache lifetime, in hours, sets after how many hours the downloaded gpm packages will not be relevant.", 0, 60480 )
WorkshopPath = fs.CreateDir( "gpm/" .. string.lower( Realm ) .. "/workshop/" )
CachePath = fs.CreateDir( "gpm/" .. string.lower( Realm ) .. "/packages/" )

do

    local CompileFile = CompileFile

    function CompileLua( filePath )
        local ok, result = pcall( fs.CompileLua, filePath, "LUA" )
        if ok then
            return result
        end

        if MENU_DLL then
            error( result )
        end

        local func = CompileFile( filePath )
        if not func then
            error( "File compilation '" .. filePath .. "' failed, unknown error." )
        end

        return func
    end

end

includeComponent "import"

if not MENU_DLL then
    includeComponent "commands"
end

if SERVER or MENU_DLL or game.IsDedicated() then
    ImportFolder( "packages", nil, true )
else
    util.NextTick( ImportFolder, "packages", nil, true )
end

Logger:Info( "Time taken to start-up: %.4f sec.", SysTime() - StartTime )
hook.Run( "GPM - Initialized" )
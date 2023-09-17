local AddCSLuaFile = AddCSLuaFile
local include = include
local SERVER = SERVER

Msg( [[
                                    ___         __
                                  /'___`\     /'__`\
     __   _____     ___ ___      /\_\ /\ \   /\ \/\ \
   /'_ `\/\ '__`\ /' __` __`\    \/_/// /__  \ \ \ \ \
  /\ \L\ \ \ \L\ \/\ \/\ \/\ \      // /_\ \__\ \ \_\ \
  \ \____ \ \ ,__/\ \_\ \_\ \_\    /\______/\_\\ \____/
   \/___L\ \ \ \/  \/_/\/_/\/_/    \/_____/\/_/ \/___/
    /\____/\ \_\
    \_/__/  \/_/

  GitHub: https://github.com/Pika-Software
  Discord: https://discord.gg/3UVxhZ
  Website: https://pika-soft.ru
  Developers: Pika Software
  License: MIT

]] )

if type( gpm ) ~= "table" then
    gpm = {}
end

gpm.StartTime = SysTime()
gpm.VERSION = "2.0.0"

local colors = gpm.Colors
if type( colors ) ~= "table" then
    colors = {
        ["SecondaryText"] = Color( 150, 150, 150 ),
        ["PrimaryText"] = Color( 200, 200, 200 ),
        ["White"] = Color( 255, 255, 255 ),
        ["Info"] = Color( 70, 135, 255 ),
        ["Warn"] = Color( 255, 130, 90 ),
        ["Error"] = Color( 250, 55, 40 ),
        ["Debug"] = Color( 0, 200, 150 ),
        ["gpm"] = Color( 180, 180, 255 ),
        ["Black"] = Color( 0, 0, 0 )
    }

    colors.State = colors.White
    gpm.Colors = colors
end

local state = gpm.State
if type( state ) ~= "string" then
    if MENU_DLL then
        colors.State = Color( 75, 175, 80 )
        state = "Menu"
    elseif CLIENT then
        colors.State = Color( 225, 170, 10 )
        state = "Client"
    elseif SERVER then
        colors.State = Color( 5, 170, 250 )
        state = "Server"
    end

    gpm.State = state or "unknown"
end

gpm.Developer = cvars.Number( "developer", 0 )
cvars.AddChangeCallback( "developer", function( _, __, new )
    gpm.Developer = tonumber( new ) or 0
end, "gLua Package Manager" )

if SERVER then
    AddCSLuaFile( "gpm/util.lua" )
    AddCSLuaFile( "gpm/fs.lua" )
    AddCSLuaFile( "gpm/http.lua" )
end

include( "gpm/util.lua" )
include( "gpm/fs.lua" )
include( "gpm/http.lua" )

gpm.Logger:Info( "Start-up time: %.4f sec.", SysTime() - gpm.StartTime )
return gpm
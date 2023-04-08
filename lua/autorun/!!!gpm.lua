if SERVER then

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

    AddCSLuaFile "gpm/init.lua"

end

include "gpm/init.lua"
hook.Run( "GPM - Initialized" )
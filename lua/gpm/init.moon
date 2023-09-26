export gpm

SERVER = SERVER
if SERVER
    AddCSLuaFile!

SysTime = SysTime
include = include
type = type

if type( gpm ) ~= "table"
    gpm = { VERSION: "2.0.0" }
gpm.StartTime = SysTime!

do

    splash = {
        "Flying over rooftops...",
        "We need more packages!",
        "Where's fireworks!?",
        "Now on MoonScript!",
        "I'm watching you.",
        "Faster than ever.",
        "v" .. gpm.VERSION,
        "Blazing fast ☄",
        "More splashes?!",
        "Here For You ♪",
        "Hello World!",
        "Once Again ♪",
        "Sandblast ♪",
        "That's me!",
        "I see you."
    }

    if CLIENT
        splash[ #splash + 1 ] = "I know you, " .. cvars.String( "name", "player" ) .. "..."
    splash[ #splash + 1 ] = "Wow, here more " .. #splash .. " splashes!"
    splash = splash[ math.random( 1, #splash ) ]
    for i = 1, ( 25 - #splash ) / 2
        if i % 2 == 1
            splash = splash .. " "
        splash = " " .. splash
    MsgN string.format "\n                                     ___          __            \n                                   /'___`\\      /'__`\\          \n     __    _____     ___ ___      /\\_\\ /\\ \\    /\\ \\/\\ \\         \n   /'_ `\\ /\\ '__`\\ /' __` __`\\    \\/_/// /__   \\ \\ \\ \\ \\        \n  /\\ \\L\\ \\\\ \\ \\L\\ \\/\\ \\/\\ \\/\\ \\      // /_\\ \\ __\\ \\ \\_\\ \\   \n  \\ \\____ \\\\ \\ ,__/\\ \\_\\ \\_\\ \\_\\    /\\______//\\_\\\\ \\____/   \n   \\/___L\\ \\\\ \\ \\/  \\/_/\\/_/\\/_/    \\/_____/ \\/_/ \\/___/    \n     /\\____/ \\ \\_\\                                          \n     \\_/__/   \\/_/                %s                        \n\n  GitHub: https://github.com/Pika-Software\n  Discord: https://discord.gg/Gzak99XGvv\n  Website: https://pika-soft.ru\n  Developers: Pika Software\n  License: MIT\n", splash

unless gpm.Developer
    gpm.Developer = cvars.Number "developer", 0
    tonumber = tonumber

    cvars.AddChangeCallback "developer",
        ( _, __, new ) -> gpm.Developer = tonumber( new ) or 0,
        "gLua Package Manager"

include "gpm/util.lua"

logger = gpm.Logger
logger\Info "gm_promise v%s is initialized.", (include "gpm/libs/promise.lua").VERSION
logger\Info "gmad v%s is initialized.", (include "gpm/libs/gmad.lua").VERSION

include "gpm/filesystem.lua"
include "gpm/http.lua"
include "gpm/package.lua"

logger\Info "Start-up time: %.4f sec.", SysTime() - gpm.StartTime
return gpm
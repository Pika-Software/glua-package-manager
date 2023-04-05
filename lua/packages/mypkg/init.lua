MYMODULE = MYMODULE or {}

import( "packages/mypkg2" )

if SERVER then
    AddCSLuaFile("helloworld.lua")
end

include("helloworld.lua")

MYMODULE.HelloWorld()

return MYMODULE
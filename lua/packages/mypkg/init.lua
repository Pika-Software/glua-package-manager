import( "packages/mypkg2" )
PrintTable( MYMODULE )

MYMODULE = MYMODULE or {}

if SERVER then
    AddCSLuaFile("helloworld.lua")
end

include("helloworld.lua")

return MYMODULE
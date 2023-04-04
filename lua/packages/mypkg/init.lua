MYMODULE = MYMODULE or {}

-- print( import "https://raw.githubusercontent.com/PrikolMen/gpm_web_package_test/main/i_love_github.json" )
-- local tbl = import "https://raw.githubusercontent.com/PrikolMen/gpm_web_package_test/main/test.lua"

-- PrintTable( tbl )

-- print( import( "packages/mypkg2" ).Test() )

if SERVER then
    AddCSLuaFile("helloworld.lua")
end

include("helloworld.lua")

MYMODULE.HelloWorld()

return MYMODULE
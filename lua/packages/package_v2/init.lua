cprint = cprint or print

function print( ... )
    cprint( "[v2]", ... )
end

local submodule = require "./submodule.lua"
local Promise = gpm.Promise

print("Got from submodule:", submodule)
Promise.delay(1):await()

print("I am", __package )
require "package:b"

return "this package is da best"

local submodule = require "./submodule.lua"
local Promise = gpm.Promise

print("Got from submodule:", submodule)
Promise.delay(1):await()

print("I am", PKG)
require "b"

return "this package is da best"

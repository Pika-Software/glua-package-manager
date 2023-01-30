AddCSLuaFile()
include("helloworld.lua")

print("MyPKG Loaded! Package ENV:", PACKAGE_ENV)
print("_G:", _G)
print("CURRENT_DIR:", CURRENT_DIR)
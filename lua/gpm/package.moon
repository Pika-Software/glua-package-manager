fs = gpm.fs

lib = gpm.package
if type( lib ) ~= "table"
    lib = {}
    gpm.package = gpm.metaworks.CreateLink( package, true )

do

    AddCSLuaFile = AddCSLuaFile
    include = include

    sourcesFolder = "gpm/sources/"
    for fileName in *fs.Find sourcesFolder .. "*", "LUA"
        filePath = sourcesFolder .. fileName
        if fs.IsLuaFile filePath, "LUA", true
            if SERVER
                AddCSLuaFile filePath
            include filePath

class Package
    new: =>
        @name = "unknown"
        @source = "unknown"
        @version = "unknown"

    GetInfo: =>

    Install: =>

    Reload: =>

    Uninstall: =>


lib.Create = Package

lib
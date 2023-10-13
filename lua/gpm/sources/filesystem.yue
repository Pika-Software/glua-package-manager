export SOURCE
fs = gpm.fs

SOURCE.Name = "Filesystem"

SOURCE.IsAvalibleFilePath = ( filePath ) ->
    return fs.IsDir( filePath, "LUA" ) or fs.IsFile( filePath, "LUA" )

SOURCE.GetInfo = () ->
    metadata = nil

SOURCE.Install = () ->

SOURCE.Reload = () ->
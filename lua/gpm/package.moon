if SERVER
    AddCSLuaFile!

logger = gpm.Logger
paths = gpm.paths
type = type
fs = gpm.fs

lib = gpm.Lib "package", gpm.metaworks.CreateLink( package, true )

class Package
    new: ( filePath ) =>
        @name = "unknown"
        @source = "unknown"
        @version = "unknown"
        @filepath = filePath

    GetInfo: =>

    Install: =>

    Reload: =>

    Uninstall: =>

do

    string_GetExtensionFromFilename = string.GetExtensionFromFilename
    package_seeall = package.seeall
    fs_CompileLua = fs.CompileLua
    debug_setfenv = debug.setfenv
    AddCSLuaFile = AddCSLuaFile
    table_Empty = table.Empty
    fs_Find = fs.Find
    SERVER = SERVER
    pcall = pcall

    sources = lib.Sources
    if type( sources ) ~= "table"
        sources = {}
        lib.Sources = sources

    -- lib.SourceImport = ( importPath, sourceName ) ->
    --     source = sources[ sourceName ]
    --     unless source
    --         return

    files = {}
    for fileName in *fs_Find "gpm/sources/" .. "*", "LUA"
        filePath = "gpm/sources/" .. fileName
        if string_GetExtensionFromFilename( filePath ) == "lua"
            files[ #files + 1 ] = filePath

    processed, total = 0, #files
    table_Empty( sources )

    initSource = promise.Async( ( filePath ) ->
        if SERVER
            AddCSLuaFile filePath

        ok, result = fs_CompileLua( filePath, "LUA" )\SafeAwait!
        unless ok
            logger\Error "Source '%s' compile failed, %s.", filePath, result
            processed += 1
            return

        environment = {
            SOURCE: {
                FilePath: filePath
            }
        }

        debug_setfenv( result, environment )
        package_seeall( environment )
        ok, result = pcall( result )
        processed += 1

        if ok
            source = environment.SOURCE
            sourceName = source.Name or filePath

            if type( source.IsAvalibleFilePath ) ~= "function"
                logger\Error "Function .IsAvalibleFilePath is missing from source '%s', source loading failed!", sourceName
                return

            func = source.GetInfo
            if type( func ) == "function"
                source.GetInfo = promise.Async( func )
            else
                logger\Error "Function .GetInfo is missing from source '%s', source loading failed!", sourceName
                return

            func = source.Install
            if type( func ) == "function"
                source.Install = promise.Async( func )
            else
                logger\Error "Function .Install is missing from source '%s', source loading failed!", sourceName
                return

            func = source.Reload
            if type( func ) == "function"
                source.Reload = promise.Async( func )

            sources[ #sources + 1 ] = source
            sources[ sourceName ] = source

        else
            logger\Error result
            return

        if processed == total
            files, folders = fs_Find "packages/*", "LUA"
            for folderName in *folders
                importPath = "packages/" .. folderName

            for fileName in *files
                importPath = "packages/" .. fileName

    )

    for index = 1, total
        initSource files[ index ]
    files = nil

lib
gpm = gpm
file = file
util = gpm.util
paths = gpm.paths
string = gpm.string

logger = gpm.Logger
ipairs = ipairs
SERVER = SERVER
error = error
type = type

-- https://github.com/Pika-Software/gm_efsw
if SERVER and not efsw and util.IsBinaryModuleInstalled( "efsw" ) and pcall( require, "efsw" )
    logger\Info( "gm_efsw is initialized, package auto-reloading are available." )

lib = gpm.fs
if type( lib ) ~= "table"
    lib = gpm.metaworks.CreateLink( file, true )
    gpm.fs = lib

mountedFiles = lib.MountedFiles
if type( mountedFiles ) ~= "table"
    string_StartsWith = string.StartsWith
    rawget, rawset = rawget, rawset
    table_insert = table.insert

    mountedFiles = setmetatable( {}, {
        __index: ( tbl, key ) ->
            for value in *tbl
                if string_StartsWith( value, key )
                    return true

            false
        __newindex: ( tbl, key ) ->
            if not rawget( tbl, key )
                table_insert( tbl, 1, key )
                rawset( tbl, key, true )
    } )

    lib.MountedFiles = mountedFiles

do
    game_MountGMA = game.MountGMA
    lib.MountGMA = ( gmaPath ) ->
        ok, files = game_MountGMA( gmaPath )
        if not ok
            error( "gma could not be mounted" )

        for filePath in *files
            mountedFiles[ filePath ] = true

        logger\Debug( "GMA file '%s' was mounted to GAME with %d files.", gmaPath, #files )
        ok, files

string_GetExtensionFromFilename = string.GetExtensionFromFilename

luaPaths = {
    LUA: true,
    lsv: true,
    lcl: true
}

-- https://github.com/Facepunch/garrysmod-issues/issues/5481
lib_IsMounted = ( filePath, gamePath, onlyDir ) ->
    if onlyDir and string_GetExtensionFromFilename( filePath )
        return

    if luaPaths[ gamePath ]
        filePath = "lua/" .. filePath

    mountedFiles[ filePath ]

lib.IsMounted = lib_IsMounted
lib.Exists = ( filePath, gamePath ) -> lib_IsMounted( filePath, gamePath ) or file.Exists( filePath, gamePath )

lib_Find = lib.Find
lib_IsDir = ( filePath, gamePath ) ->
    if lib_IsMounted( filePath, gamePath, true ) or file.IsDir( filePath, gamePath )
        return true

    _, folders = lib_Find( filePath .. "*", gamePath )
    if folders == nil or #folders == 0
        return false

    splits = string.Split( filePath, "/" )
    table.HasIValue( folders, splits[ #splits ] )

lib.IsDir = lib_IsDir
lib.IsFile = ( filePath, gamePath ) -> lib_IsMounted( filePath, gamePath ) or ( file.Exists( filePath, gamePath ) and not lib_IsDir( filePath, gamePath ) )
paths_Join = paths.Join

do
    file_Size = file.Size
    lib_Size = ( filePath, gamePath ) ->
        if not lib_IsDir( filePath, gamePath )
            return file_Size( filePath, gamePath )

        size, files, folders = 0, lib_Find( paths_Join( filePath, "*" ), gamePath )
        for fileName in *files
            size += file_Size( paths_Join( filePath, fileName ), gamePath )

        for folderName in *folders
            size += lib_Size( paths_Join( filePath, folderName ), gamePath )

        size

    lib.Size = lib_Size

lib
gpm = gpm
file = file
util = gpm.util
paths = gpm.paths
string = gpm.string

string_GetPathFromFilename = string.GetPathFromFilename
File = FindMetaTable( "File" )
MENU_DLL = MENU_DLL
logger = gpm.Logger
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
            error "gma could not be mounted"

        for filePath in *files
            mountedFiles[ filePath ] = true

        logger\Debug( "GMA file '%s' was mounted to GAME with %d files.", gmaPath, #files )
        ok, files

string_GetExtensionFromFilename = string.GetExtensionFromFilename

lib_IsMounted = nil
do
    luaPaths = {
        LUA: true,
        lsv: true,
        lcl: true
    }

    lib_IsMounted = ( filePath, gamePath, onlyDir ) ->
        if onlyDir and string_GetExtensionFromFilename( filePath )
            return

        if luaPaths[ gamePath ]
            filePath = "lua/" .. filePath

        mountedFiles[ filePath ]

    lib.IsMounted = lib_IsMounted

paths_Join = paths.Join
lib_Find = file.Find
lib.Find = lib_Find
lib_CreateDir = nil
lib_IsFile = nil

do
    table_HasIValue = table.HasIValue
    string_Split = string.Split
    file_Exists = file.Exists
    file_Delete = file.Delete
    file_IsDir = file.IsDir

    lib.Exists = ( filePath, gamePath ) ->
        lib_IsMounted( filePath, gamePath ) or file_Exists( filePath, gamePath )

    lib_IsDir = ( filePath, gamePath ) ->
        if lib_IsMounted( filePath, gamePath, true ) or file_IsDir( filePath, gamePath )
            return true

        _, folders = lib_Find( filePath .. "*", gamePath )
        if folders == nil or #folders == 0
            return false

        splits = string_Split( filePath, "/" )
        table_HasIValue( folders, splits[ #splits ] )

    lib.IsDir = lib_IsDir
    lib_IsFile = ( filePath, gamePath ) ->
        lib_IsMounted( filePath, gamePath ) or ( file_Exists( filePath, gamePath ) and not lib_IsDir( filePath, gamePath ) )
    lib.IsFile = lib_IsFile

    lib_Delete = ( filePath, gamePath, force ) ->
            gamePath = gamePath or "DATA"

            if lib_IsDir filePath, gamePath
                if force
                    files, folders = lib_Find paths_Join( filePath, "*" ), gamePath
                    for folderName in *folders
                        lib_Delete paths_Join( filePath, folderName ), gamePath, force

                    for fileName in *files
                        file_Delete paths_Join( filePath, fileName ), gamePath, force

                file_Delete filePath, gamePath
                return not lib_IsDir filePath, gamePath

            file_Delete filePath, gamePath
            not lib_IsFile filePath, gamePath

    lib.Delete = lib_Delete

    do
        file_CreateDir = file.CreateDir
        lib_CreateDir = ( folderPath, force ) ->
            unless force
                file_CreateDir folderPath
                return folderPath

            currentPath = nil
            for folderName in *string_Split folderPath, "/"
                if folderName
                    unless currentPath
                        currentPath = folderName
                    else
                        currentPath = currentPath .. "/" .. folderName

                    unless file_IsDir currentPath, "DATA"
                        file_Delete currentPath, "DATA"
                        file_CreateDir currentPath

            currentPath

        lib.CreateDir = lib_CreateDir

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

lib_BuildFilePath = nil
do
    lib_BuildFilePath = ( filePath ) ->
        folderPath = string_GetPathFromFilename( filePath )
        if folderPath
            lib_CreateDir( folderPath )

    lib.BuildFilePath = lib_BuildFilePath

lib_IsLuaFile = nil
do
    moonloader = moonloader
    lib_IsLuaFile = ( filePath, gamePath, compileMoon ) ->
        extension = string_GetExtensionFromFilename filePath
        if extension and extension ~= "lua" and extension ~= "moon"
            return false

        filePath = string.sub filePath, 1, #filePath - ( extension ~= nil and ( #extension + 1 ) or 0 )

        if compileMoon and ( SERVER or MENU_DLL ) and moonloader ~= nil
            moonPath = filePath  .. ".moon"
            if lib_IsFile moonPath, gamePath
                unless moonloader.PreCacheFile moonPath
                    error "Compiling Moonscript file '" .. moonPath .. "' into Lua is failed!"

                logger/Debug "The MoonScript file '%s' was successfully compiled into Lua.", moonPath
                true

        lib_IsFile filePath .. ".lua", gamePath

    lib.IsLuaFile = lib_IsLuaFile

do

    file_Open = file.Open

    lib.Read = ( filePath, gamePath, length ) ->
        fileObject = file_Open filePath, "rb", gamePath
        unless fileObject
            return

        content = File.Read( fileObject, length )
        File.Close( fileObject )
        content

    lib_Write = ( filePath, content, fileMode, fastMode ) ->
        unless fastMode
            lib_BuildFilePath filePath

        fileObject = file_Open filePath, fileMode or "wb", "DATA"
        unless fileObject
            error "Writing file 'data/" .. filePath .. "' was failed!"

        File.Write fileObject, content
        File.Close fileObject

    lib.Write = lib_Write
    lib.Append = ( filePath, content, fastMode ) ->
        lib_Write filePath, content, "ab", fastMode

if SERVER
    paths_FormatToLua = paths.FormatToLua
    debug_getfpath = debug.getfpath
    gpm_ArgAssert = gpm.ArgAssert
    AddCSLuaFile = AddCSLuaFile

    lib.AddCSLuaFile = ( fileName ) ->
        luaPath = debug_getfpath!
        if not fileName and luaPath and lib_IsFile luaPath, "LUA"
            AddCSLuaFile luaPath
            return

        gpm_ArgAssert fileName, 1, "string"
        fileName = paths_FormatToLua paths.Fix fileName

        if luaPath
            folder = string_GetPathFromFilename luaPath
            if folder
                filePath = folder .. fileName
                if lib_IsLuaFile filePath, "LUA", true
                    AddCSLuaFile filePath
                    return

        if lib_IsLuaFile fileName, "LUA", true
            AddCSLuaFile fileName
            return

        error "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found"

    lib_AddCSLuaFolder = ( folder ) ->
        files, folders = lib_Find paths_Join( folder, "*" ), "lsv"
        for folderName in *folders
            lib_AddCSLuaFolder paths_Join( folder, folderName )

        for fileName in *files
            filePath = paths_Join folder, fileName
            if lib_IsLuaFile filePath, "lsv", true
                AddCSLuaFile paths.FormatToLua filePath

    lib.AddCSLuaFolder = lib_AddCSLuaFolder

lib

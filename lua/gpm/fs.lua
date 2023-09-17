local gpm = gpm
local file = file
local paths = gpm.paths
local metaworks = gpm.metaworks

-- local File = FindMetaTable( "File" )
local logger = gpm.Logger
local ipairs = ipairs
local error = error
local type = type

local lib = gpm.fs
if type( lib ) ~= "table" then
    lib = metaworks.CreateLink( file, true )
    gpm.fs = lib
end

local mountedFiles = lib.MountedFiles
if type( mountedFiles ) ~= "table" then
    mountedFiles = {}; lib.MountedFiles = mountedFiles
end

do

    local game_MountGMA = game.MountGMA
    local table_insert = table.insert

    function lib.MountGMA( gmaPath )
        local ok, files = game_MountGMA( gmaPath )
        if not ok then
            error( "gma could not be mounted" )
        end

        for _, filePath in ipairs( files ) do
            table_insert( MountedFiles, 1, filePath )
        end

        logger:Debug( "GMA file '%s' was mounted to GAME with %d files.", gmaPath, #files  )
        return ok, files
    end

end

local function fs_IsDir( filePath, gameDir )

end

lib.IsDir = fs_IsDir

local paths_Join = paths.Join
local file_Find = file.Find
local file_Size = file.Size

local function fs_Size( filePath, gameDir )
    if not fs_IsDir( filePath, gameDir ) then
        return file_Size( filePath, gameDir )
    end

    local files, folders = file_Find( paths_Join( filePath, "*" ), gameDir )
    local fileSize = 0

    for _, folderName in ipairs( folders ) do
        fileSize = fileSize + size( paths_Join( filePath, folderName ), gameDir )
    end

    for _, fileName in ipairs( files ) do
        fileSize = fileSize + size( paths_Join( filePath, fileName ), gameDir )
    end

    return fileSize
end

lib.Size = fs_Size
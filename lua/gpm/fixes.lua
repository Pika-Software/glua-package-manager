-- Variables
local SERVER = SERVER
local ipairs = ipairs

-- Libraries
local string = string
local file = file

local gluaFixes = gpm.GLuaFixes
if not gluaFixes then
    gluaFixes = {}; gpm.GLuaFixes = gluaFixes
end

local file_Exists = table.SetValue( gluaFixes, "file.Exists", file.Exists, true )
local file_IsDir = table.SetValue( gluaFixes, "file.IsDir", file.IsDir, true )

function file.IsDir( filePath, gamePath )
    if SERVER then return file_IsDir( filePath, gamePath ) end
    if file_IsDir( filePath, gamePath ) then return true end

    local _, folders = file.Find( filePath .. "*", gamePath )
    if ( folders == nil or #folders == 0 ) then return false end

    local splits = string.Split( filePath, "/" )
    local folderName = splits[ #splits ]

    for _, value in ipairs( folders ) do
        if ( value == folderName ) then return true end
    end

    return false
end

function file.Exists( filePath, gamePath )
    if SERVER then return file_Exists( filePath, gamePath ) end
    if file_Exists( filePath, gamePath ) then return true end

    local files, folders = file.Find( filePath .. "*", gamePath )
    if not files or not folders then return false end
    if ( #files == 0 and #folders == 0 ) then return false end

    local splits = string.Split( filePath, "/" )
    local fileName = splits[ #splits ]

    for _, value in ipairs( files ) do
        if ( value == fileName ) then return true end
    end

    for _, value in ipairs( folders ) do
        if ( value == fileName ) then return true end
    end

    return false
end
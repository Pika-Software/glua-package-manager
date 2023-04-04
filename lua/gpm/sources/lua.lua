-- Libraries
local package = gpm.package
local promise = gpm.promise
local paths = gpm.paths
local string = string
local file = file

-- Variables
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local AddCSLuaFile = AddCSLuaFile
local setmetatable = setmetatable
local CompileFile = CompileFile
local rawset = rawset
local pcall = pcall
local type = type

module( "gpm.sources.lua" )

LuaRealm = "LUA"

if SERVER then
    LuaRealm = "lsv"
elseif MENU_DLL then
    LuaRealm = "LUA"
elseif CLIENT then
    LuaRealm = "lcl"
end

function CanImport( filePath )
    return file.Exists( filePath, LuaRealm ) and string.EndsWith( filePath, ".lua" ) or file.IsDir( filePath, LuaRealm )
end

Files = setmetatable( {}, {
    ["__index"] = function( self, filePath )
        if type( filePath ) == "string" then
            filePath = paths.Fix( filePath )

            if file.Exists( filePath, LuaRealm ) and string.EndsWith( filePath, ".lua" ) then
                local ok, result = pcall( CompileFile, filePath )
                if ok then
                    rawset( self, filePath, result )
                    return result
                end
            end
        end

        rawset( self, filePath, false )
        return false
    end
} )

Import = promise.Async( function( filePath )
    local packagePath = paths.Fix( filePath )

    local packageFilePath = packagePath
    if string.EndsWith( packagePath, ".lua" ) then
        packagePath = string.GetPathFromFilename( packageFilePath )
    else
        packageFilePath = paths.Join( packagePath, "package.lua" )
    end

    local packageFile, metadata = Files[ packageFilePath ], nil
    if packageFile then
        metadata = package.GetMetaData( packageFile )
        if SERVER and metadata.client then AddCSLuaFile( packageFilePath ) end
    else
        metadata = package.GetMetaData( {} )
    end

    if CLIENT and not metadata.client then return end
    if not metadata.name then metadata.name = string.GetFileFromFilename( packagePath ) end

    local mainFilePath = metadata.main
    if not mainFilePath then
        mainFilePath = paths.Join( packagePath, "init.lua" )
    end

    if not file.Exists( mainFilePath, LuaRealm ) then return promise.Reject( "main file '" .. mainFilePath .. "' is missing" ) end
    if SERVER and metadata.client then AddCSLuaFile( mainFilePath ) end

    metadata.source = "local"

    if SERVER and not metadata.server then return end

    local mainFile = Files[ mainFilePath ]
    if not mainFile then return promise.Reject( "main file compilation failed" ) end

    return package.InitializePackage( metadata, mainFile, Files )
end )
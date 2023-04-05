-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local paths = gpm.paths
local string = string
local file = file

-- Variables
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local CompileString = CompileString
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
        if type( filePath ) == "string" and file.Exists( filePath, LuaRealm ) and string.EndsWith( filePath, ".lua" ) then
            local code, func = file.Read( filePath, "LUA" ), nil
            if code then
                func = CompileString( code, filePath, ErrorNoHaltWithStack )
            end

            if not func then
                local ok, result = pcall( CompileFile, filePath )
                if ok then
                    func = result
                end
            end

            if func ~= nil then
                rawset( self, filePath, func )
                return func
            end
        end

        rawset( self, filePath, false )
        return false
    end
} )

Import = promise.Async( function( filePath )
    local packagePath = paths.Fix( filePath )

    local packageFilePath = packagePath

    local packagePathIsLuaFile = string.EndsWith( packagePath, ".lua" )
    if packagePathIsLuaFile then
        packagePath = string.GetPathFromFilename( packageFilePath )
    else
        packageFilePath = paths.Join( packagePath, "package.lua" )
    end

    local packageFile, metadata = Files[ packageFilePath ], nil
    if packageFile then
        metadata = packages.GetMetaData( packageFile )
        if not metadata then
            if packagePathIsLuaFile then
                return packages.Initialize( packages.GetMetaData( {
                    ["name"] = packageFilePath,
                    ["main"] = packageFilePath
                } ), packageFile, Files )
            end

            return promise.Reject( "package.lua is completely corrupted" )
        end

        if SERVER and metadata.client then
            AddCSLuaFile( packageFilePath )
        end
    else
        metadata = packages.GetMetaData( {} )
    end

    if CLIENT and not metadata.client then return end
    if not metadata.name then metadata.name = string.GetFileFromFilename( packagePath ) end

    local mainFilePath = metadata.main
    if not mainFilePath then
        mainFilePath = paths.Join( packagePath, "init.lua" )
    end

    if not file.Exists( mainFilePath, LuaRealm ) then return promise.Reject( "main file '" .. mainFilePath .. "' is missing" ) end
    if SERVER and metadata.client then AddCSLuaFile( mainFilePath ) end

    metadata.source = metadata.source or "local"

    if SERVER and not metadata.server then return end

    local mainFile = Files[ mainFilePath ]
    if not mainFile then return promise.Reject( "main file compilation failed" ) end

    return packages.Initialize( metadata, mainFile, Files )
end )
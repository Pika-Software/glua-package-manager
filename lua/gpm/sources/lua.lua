-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local paths = gpm.paths
local utils = gpm.utils
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
            local code, func = file.Read( filePath, LuaRealm ), nil
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

Import = promise.Async( function( filePath, parentPackage )
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
            metadata = packages.GetMetaData( {
                ["name"] = packageFilePath,
                ["main"] = packageFilePath
            } )

            if packagePathIsLuaFile then
                return packages.Initialize( metadata, packageFile, Files, parentPackage )
            end

            return promise.Reject( "package file is missing (" .. metadata.name .. "@" .. utils.Version( metadata.version ) .. ")" )
        end

        if SERVER and metadata.client then
            AddCSLuaFile( packageFilePath )
        end
    else
        metadata = packages.GetMetaData( {} )
    end

    if CLIENT and not metadata.client then return end
    if not metadata.name then metadata.name = string.GetFileFromFilename( packagePath ) end

    local mainFile = metadata.main
    if not mainFile then
        mainFile = paths.Join( packagePath, "init.lua" )
    end

    local func = Files[ mainFile ]
    if not func then
        mainFile = paths.Join( packagePath, mainFile )
        func = Files[ mainFile ]
    end

    if not func then
        return promise.Reject( "main file is missing (" .. metadata.name .. "@" .. utils.Version( metadata.version ) .. ")" )
    end

    metadata.source = metadata.source or "local"

    if SERVER then
        if metadata.client then AddCSLuaFile( mainFile ) end
        if not metadata.server then return end
    end

    return packages.Initialize( metadata, func, Files, parentPackage )
end )
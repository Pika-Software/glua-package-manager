-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local paths = gpm.paths
local file = file

module( "gpm.sources.lua", package.seeall )

if SERVER then
    LuaRealm = "lsv"
elseif MENU_DLL then
    LuaRealm = "LUA"
elseif CLIENT then
    LuaRealm = "lcl"
end

function CanImport( filePath )
    return file.Exists( filePath, LuaRealm )
end

Files = Files or setmetatable( {}, {
    ["__index"] = function( self, filePath )
        if isstring( filePath ) and string.EndsWith( filePath, ".lua" ) and file.Exists( filePath, LuaRealm ) then
            local ok, result = pcall( CompileFile, filePath )
            if ok then
                self[ filePath ] = result
                return result
            end
        end

        self[ filePath ] = false
        return false
    end
} )

function ImportLocal( fileName )
    AddCSLuaFile( packageFileName )
    AddCSLuaFile( packageInfo.main )

    local files = setmetatable( {}, LocalFilesFinderMeta )
    files[ packageInfo.main ] = mainFile

    packageInfo.ImportedFrom = "Local"
    packageInfo.ImportedExtra = nil

    return gpm.packages.InitializePackage( packageInfo, mainFile, files )
end

Import = promise.Async( function( packagePath )
    local packageFilePath = packagePath
    if string.EndsWith( packagePath, ".lua" ) then
        packagePath = string.GetPathFromFilename( packageFilePath )
    else
        packageFilePath = paths.Join( packagePath, "package.lua" )
    end

    local metadata = nil
    if file.Exists( packageFilePath, LuaRealm ) then
        local func = CompileFile( packageFilePath )
        if not func then return promise.Reject( "package.lua file compilation failed" ) end

        metadata = gpm.packages.GetMetaData( setfenv( func, {} ) )
        Files[ packageFilePath ] = func
    else
        metadata = gpm.packages.GetMetaData( {} )
    end

    if CLIENT and not metadata.client then return end

    if not metadata.name then
        metadata.name = string.GetFileFromFilename( packagePath )
    end

    local mainFilePath = metadata.main
    if not mainFilePath then
        mainFilePath = paths.Join( packagePath, "init.lua" )
    end

    if SERVER then
        if metadata.client then
            AddCSLuaFile( packageFilePath )
            AddCSLuaFile( mainFilePath )
        end

        if not metadata.server then return end
    end

    if not file.Exists( mainFilePath, LuaRealm ) then return promise.Reject( "main file is missing" ) end

    metadata.source = "local"

    local func = CompileFile( mainFilePath )
    if not func then return promise.Reject( "main file compilation failed" ) end
    Files[ mainFilePath ] = func

    local env = nil
    if istable( gpm.Package ) then
        env = gpm.Package:GetEnvironment()
    end

    return packages.InitializePackage( metadata, func, Files, env )
end )
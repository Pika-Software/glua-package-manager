-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local paths = gpm.paths
local string = string
local file = file

-- Functions
local rawset = rawset
local pcall = pcall
local type = type


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

Files = setmetatable( {}, {
    ["__index"] = function( self, filePath )
        if type( filePath ) == "string" and string.EndsWith( filePath, ".lua" ) and file.Exists( filePath, LuaRealm ) then
            local ok, result = pcall( CompileFile, filePath )
            if ok then
                rawset( self, filePath, result )
                return result
            end
        end

        rawset( self, filePath, false )
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
        local func = Files[ packageFilePath ]
        if not func then
            func = CompileFile( packageFilePath ); Files[ packageFilePath ] = func
        end

        if not func then return promise.Reject( "package.lua file compilation failed" ) end
        metadata = gpm.packages.GetMetaData( setfenv( func, {} ) )
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

    local func = Files[ mainFilePath ]
    if not func then
        func = CompileFile( mainFilePath ); Files[ mainFilePath ] = func
    end

    if not func then return promise.Reject( "main file compilation failed" ) end

    -- print( "gpm.Package", gpm.Package )
    -- PrintTable( debug.getfenv() )

    -- local gPackage, env = gpm.Package, nil
    -- if istable( gPackage ) then
    --     print( gPackage )
    --     -- env = gPackage:GetEnvironment()
    -- end

    return packages.InitializePackage( metadata, func, Files --[[, env ]] )
end )
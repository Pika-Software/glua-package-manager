-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local paths = gpm.paths
local string = string
local file = file

-- Functions
local setmetatable = setmetatable
local CompileFile = CompileFile
local rawset = rawset
local pcall = pcall
local type = type

local luaRealm = "LUA"
if SERVER then
    luaRealm = "lsv"
elseif MENU_DLL then
    luaRealm = "LUA"
elseif CLIENT then
    luaRealm = "lcl"
end

module( "gpm.sources.lua" )

function CanImport( filePath )
    return file.Exists( filePath, luaRealm ) and string.EndsWith( filePath, ".lua" ) or file.IsDir( filePath, luaRealm )
end

Files = setmetatable( {}, {
    ["__index"] = function( self, filePath )
        if type( filePath ) == "string" then
            filePath = paths.Fix( filePath )

            if file.Exists( filePath, luaRealm ) and string.EndsWith( filePath, ".lua" ) then
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

    local metadata = nil
    if file.Exists( packageFilePath, luaRealm ) then
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

    if not file.Exists( mainFilePath, luaRealm ) then return promise.Reject( "main file is missing" ) end

    metadata.source = "local"

    local func = Files[ mainFilePath ]
    if not func then
        func = CompileFile( mainFilePath ); Files[ mainFilePath ] = func
    end

    if not func then
        return promise.Reject( "main file compilation failed" )
    end

    return packages.InitializePackage( metadata, func, Files )
end )
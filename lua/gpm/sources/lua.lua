-- Libraries
local package = gpm.package
local promise = gpm.promise
local paths = gpm.paths
local string = string
local fs = gpm.fs

-- Variables
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local AddCSLuaFile = AddCSLuaFile
local setmetatable = setmetatable
local CompileFile = CompileFile
local luaRealm = gpm.LuaRealm
local logger = gpm.Logger
local ipairs = ipairs
local rawset = rawset
local pcall = pcall
local type = type

module( "gpm.sources.lua" )

function CanImport( filePath )
    return fs.Exists( filePath, luaRealm ) and string.EndsWith( filePath, ".lua" ) or fs.IsDir( filePath, luaRealm )
end

Files = setmetatable( {}, {
    ["__index"] = function( self, filePath )
        if type( filePath ) ~= "string" then return false end
        if not fs.IsFile( filePath, luaRealm ) then return false end

        local ok, result = pcall( CompileFile, filePath )
        if not ok then return false end
        if not result then return false end

        rawset( self, filePath, result )
        return result
    end
} )

function GetInfo( filePath )
    local importPath = paths.Fix( filePath )
    local info = nil

    local folder = importPath
    if not fs.IsDir( folder, luaRealm ) then
        folder = string.GetPathFromFilename( importPath )
    end

    local packagePath = folder .. "/package.lua"
    local hasPackageFile = fs.IsFile( packagePath, luaRealm )
    if hasPackageFile then
        local func = Files[ packagePath ]
        if func then
            info = package.GetMetadata( func )
        end
    end

    if not info then
        info = {
            ["autorun"] = true
        }

        if fs.IsFile( importPath, luaRealm ) then
            info.main = importPath
        end

        info = package.GetMetadata( info )
    end

    if hasPackageFile then
        info.packagePath = packagePath
    end

    info.importPath = importPath
    info.folder = folder

    local mainFile = info.main
    if not mainFile or not fs.IsFile( mainFile, luaRealm ) then
        mainFile = importPath .. "/init.lua"
    end

    if not fs.IsFile( mainFile, luaRealm ) then
        mainFile = importPath .. "/" .. mainFile
    end

    if not fs.IsFile( mainFile, luaRealm ) then
        mainFile = importPath .. "/main.lua"
    end

    info.main = mainFile

    if type( info.name ) ~= "string" then
        info.name = importPath
    end

    return info
end

Import = promise.Async( function( info )
    if CLIENT and not info.client then return end
    if MENU_DLL and not info.menu then return end
    local mainFile = info.main

    local main = Files[ mainFile ]
    if not main then
        logger:Error( "Package `%s` import failed, main file is missing.", packagePath )
        return
    end

    if SERVER then
        if info.client then
            AddCSLuaFile( mainFile )

            local packagePath = info.packagePath
            if packagePath then
                AddCSLuaFile( packagePath )
            end

            local send = info.send
            if send then
                for _, filePath in ipairs( send ) do
                    local localFilePath = packagePath .. "/" .. filePath
                    if fs.IsFile( localFilePath, luaRealm ) then
                        AddCSLuaFile( localFilePath )
                    elseif fs.IsFile( filePath, luaRealm ) then
                        AddCSLuaFile( filePath )
                    end
                end
            end
        end

        if not info.server then return end
    end

    return package.Initialize( info, main, Files )
end )
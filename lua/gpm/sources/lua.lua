local gpm = gpm

-- Libraries
local package = gpm.package
local promise = gpm.promise
local paths = gpm.paths
local string = string
local fs = gpm.fs

-- Variables
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local AddCSLuaFile = AddCSLuaFile
local luaRealm = gpm.LuaRealm
local ipairs = ipairs
local type = type

module( "gpm.sources.lua" )

function CanImport( filePath )
    return fs.Exists( filePath, luaRealm ) and string.EndsWith( filePath, ".lua" ) or fs.IsDir( filePath, luaRealm )
end

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
        local func = gpm.CompileLua( packagePath )
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

    local main = info.main
    if type( main ) ~= "string" then
        main = "init.lua"
    end

    if not fs.IsFile( main, luaRealm ) then
        main = paths.Join( importPath, main )

        if not fs.IsFile( main, luaRealm ) then
            main = importPath .. "/init.lua"
            if not fs.IsFile( main, luaRealm ) then
                main = importPath .. "/main.lua"
            end
        end
    end

    if fs.IsFile( main, luaRealm ) then
        info.main = main
    else
        info.main = nil
    end

    local cl_main = info.cl_main
    if type( cl_main ) ~= "string" then
        cl_main = "cl_init.lua"
    end

    if type( cl_main ) == "string" and not fs.IsFile( cl_main, luaRealm ) then
        cl_main = paths.Join( importPath, cl_main )
        if not fs.IsFile( cl_main, luaRealm ) then
            cl_main = importPath .. "/cl_init.lua"
        end
    end

    if fs.IsFile( cl_main, luaRealm ) then
        info.cl_main = cl_main
    else
        info.cl_main = nil
    end

    if type( info.name ) ~= "string" then
        info.name = importPath
    end

    return info
end

if SERVER then

    function SendToClient( info )
        local packagePath = info.packagePath
        if packagePath then
            AddCSLuaFile( packagePath )
        end

        local cl_main = info.cl_main
        if type( cl_main ) == "string" then
            AddCSLuaFile( cl_main )
        end

        local main = info.main
        if main then
            AddCSLuaFile( info.main )
        end

        local send = info.send
        if not send then return end

        local folder = info.folder
        for _, filePath in ipairs( send ) do
            local localFilePath = folder .. "/" .. filePath
            if fs.IsFile( localFilePath, luaRealm ) then
                AddCSLuaFile( localFilePath )
            elseif fs.IsFile( filePath, luaRealm ) then
                AddCSLuaFile( filePath )
            end
        end
    end

end

Import = promise.Async( function( info )
    if MENU_DLL and not info.menu then return end
    if CLIENT and not info.client then return end
    if SERVER and not info.server then return end

    local func = gpm.CompileLua( info.main )
    if not func then
        gpm.Error( info.importPath, "main file `" .. ( info.main or "init.lua" ) .. "` is missing." )
        return
    end

    return package.Initialize( info, func )
end )
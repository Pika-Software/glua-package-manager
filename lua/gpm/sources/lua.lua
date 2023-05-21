local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local paths = gpm.paths
local string = string
local fs = gpm.fs

-- Variables
local SERVER = SERVER
local AddCSLuaFile = SERVER and AddCSLuaFile
local luaRealm = gpm.LuaRealm
local ipairs = ipairs
local type = type

module( "gpm.sources.lua" )

function CanImport( filePath )
    if fs.IsFile( filePath, luaRealm ) and ( string.EndsWith( filePath, ".lua" ) or string.EndsWith( filePath, "lua.dat" ) ) then return true end
    if fs.IsDir( filePath, luaRealm ) then return true end
    return false
end

GetMetadata = promise.Async( function( importPath )
    if not fs.IsDir( folder, luaRealm ) then
        folder = string.GetPathFromFilename( importPath )
    end

    local packagePath = folder .. "/package.lua"
    local hasPackageFile = fs.IsFile( packagePath, luaRealm )
    if hasPackageFile then
        local ok, result = gpm.CompileLua( packagePath )
        if ok then
            info = package.GetMetadata( result )
        else
            gpm.Error( importPath, result, true )
        end
    end

    -- For single file
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

    info.folder = folder

    -- Shared init
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
        info.main = paths.Fix( main )
    else
        info.main = nil
    end

    -- Client init
    local cl_main = info.cl_main
    if type( cl_main ) ~= "string" then
        cl_main = "cl_init.lua"
    end

    if not fs.IsFile( cl_main, luaRealm ) then
        cl_main = paths.Join( importPath, cl_main )
        if not fs.IsFile( cl_main, luaRealm ) then
            cl_main = importPath .. "/cl_init.lua"
        end
    end

    if fs.IsFile( cl_main, luaRealm ) then
        info.cl_main = paths.Fix( cl_main )
    else
        info.cl_main = nil
    end

    return info
end )

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

    local main = info.main
    if not main or not fs.IsFile( main, luaRealm ) then
        return promise.Reject( "main file '" .. ( main or "init.lua" ) .. "' is missing." )
    end

    local ok, result = gpm.CompileLua( main )
    if not ok then
        return promise.Reject( result )
    end

    return package.Initialize( info, result )
end )
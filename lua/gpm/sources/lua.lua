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
local moonloader = moonloader
local ipairs = ipairs
local type = type

module( "gpm.sources.lua" )

function CanImport( filePath )
    if fs.IsDir( "lua/" .. filePath, "GAME" ) then return true end
    if fs.IsFile( "lua/" .. filePath, "GAME" ) then
        local extension = string.GetExtensionFromFilename( filePath )
        if extension == "moon" then return moonloader ~= nil end
        if extension == "lua" then return true end
    end

    return false
end

GetMetadata = promise.Async( function( importPath )
    local metadata, folder = nil, importPath
    if fs.IsDir( "lua/" .. folder, "GAME" ) then
        if moonloader ~= nil then
            moonloader.PreCacheDir( folder )
        end
    else
        folder = string.GetPathFromFilename( importPath )
    end

    local packagePath, hasPackageFile = nil
    if string.StartsWith( folder, "includes/modules/" ) then
        hasPackageFile = false
    else
        packagePath = paths.Fix( folder .. "/package.lua" )
        hasPackageFile = fs.IsFile( "lua/" .. packagePath, "GAME" )
    end

    if hasPackageFile then
        local ok, result = gpm.CompileLua( packagePath ):SafeAwait()
        if not ok then return promise.Reject( result ) end
        metadata = package.GetMetadata( result )
    end

    -- Single file
    if not metadata then
        metadata = {
            ["autorun"] = true
        }

        if fs.IsFile( "lua/" .. importPath, "GAME" ) then
            if string.EndsWith( importPath, ".moon" ) and moonloader ~= nil and not moonloader.PreCacheFile( importPath ) then
                return promise.Reject( "Compiling Moonscript file '" .. importPath .. "' into Lua is failed!" )
            end

            metadata.main = importPath
        end
    end

    if hasPackageFile then
        metadata.package_path = packagePath
    end

    metadata.folder = folder

    -- Shared init
    local main = metadata.main
    if type( main ) == "string" then
        main = paths.Fix( main )
    else
        main = "init.lua"
    end

    if not fs.IsFile( "lua/" .. main, "GAME" ) then
        main = paths.Join( importPath, main )

        if not fs.IsFile( "lua/" .. main, "GAME" ) then
            main = importPath .. "/init.lua"
            if not fs.IsFile( "lua/" .. main, "GAME" ) then
                main = importPath .. "/main.lua"
            end
        end
    end

    if fs.IsFile( "lua/" .. main, "GAME" ) then
        metadata.main = main
    else
        metadata.main = nil
    end

    -- Client init
    local cl_main = metadata.cl_main
    if type( cl_main ) == "string" then
        cl_main = paths.Fix( cl_main )
    else
        cl_main = "cl_init.lua"
    end

    if not fs.IsFile( "lua/" .. cl_main, "GAME" ) then
        cl_main = paths.Join( importPath, cl_main )
        if not fs.IsFile( "lua/" .. cl_main, "GAME" ) then
            cl_main = importPath .. "/cl_init.lua"
        end
    end

    if fs.IsFile( "lua/" .. cl_main, "GAME" ) then
        metadata.cl_main = cl_main
    else
        metadata.cl_main = nil
    end

    return metadata
end )

if SERVER then

    function SendToClient( metadata )
        local packagePath = metadata.package_path
        if packagePath then
            AddCSLuaFile( packagePath )
        end

        local cl_main = metadata.cl_main
        if type( cl_main ) == "string" then
            AddCSLuaFile( cl_main )
        end

        local main = metadata.main
        if main then
            AddCSLuaFile( metadata.main )
        end

        local send = metadata.send
        if not send then return end

        local folder = metadata.folder
        for _, filePath in ipairs( send ) do
            local localFilePath = folder .. "/" .. filePath
            if fs.IsFile( "lua/" .. localFilePath, "GAME" ) then
                AddCSLuaFile( localFilePath )
            elseif fs.IsFile( "lua/" .. filePath, "GAME" ) then
                AddCSLuaFile( filePath )
            end
        end
    end

end

Import = promise.Async( function( metadata )
    local main = metadata.main
    if not main or not fs.IsFile( "lua/" .. main, "GAME" ) then
        return promise.Reject( "main file '" .. ( main or "init.lua" ) .. "' is missing." )
    end

    local ok, result = gpm.CompileLua( main ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    return package.Initialize( metadata, result )
end )
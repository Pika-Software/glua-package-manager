local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local paths = gpm.paths
local string = string
local fs = gpm.fs

-- Variables
local SERVER = SERVER
local moonloader = moonloader
local ipairs = ipairs
local type = type

module( "gpm.sources.lua" )

function CanImport( filePath )
    if fs.IsDir( filePath, "LUA" ) then return true end
    if fs.IsFile( filePath, "LUA" ) then
        local extension = string.GetExtensionFromFilename( filePath )
        if extension == "moon" then return moonloader ~= nil end
        if extension == "lua" then return true end
    end

    return false
end

GetMetadata = promise.Async( function( importPath )
    local metadata, folder = nil, importPath
    if fs.IsDir( folder, "LUA" ) then
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
        hasPackageFile = fs.IsFile( packagePath, "LUA" )
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

        local extension = string.GetExtensionFromFilename( importPath )
        if extension == "moon" then
            if not fs.IsFile( "lua/" .. importPath, "GAME" ) then
                return promise.Reject( "Unable to compile Moonscript file, file not found." )
            end

            if not moonloader then
                return promise.Reject( "Attempting to compile a Moonscript file fails, install gm_moonloader and try again.\nhttps://github.com/Pika-Software/gm_moonloader" )
            end

            if not moonloader.PreCacheFile( importPath ) then
                return promise.Reject( "Compiling Moonscript file '" .. importPath .. "' into Lua is failed!" )
            end

            importPath = string.sub( importPath, 1, #importPath - #extension ) .. "lua"
        end

        if fs.IsFile( importPath, "LUA" ) then
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

    if not fs.IsFile( main, "LUA" ) then
        main = paths.Join( importPath, main )

        if not fs.IsFile( main, "LUA" ) then
            main = importPath .. "/init.lua"
            if not fs.IsFile( main, "LUA" ) then
                main = importPath .. "/main.lua"
            end
        end
    end

    if fs.IsFile( main, "LUA" ) then
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

    if not fs.IsFile( cl_main, "LUA" ) then
        cl_main = paths.Join( importPath, cl_main )
        if not fs.IsFile( cl_main, "LUA" ) then
            cl_main = importPath .. "/cl_init.lua"
        end
    end

    if fs.IsFile( cl_main, "LUA" ) then
        metadata.cl_main = cl_main
    else
        metadata.cl_main = nil
    end

    return metadata
end )

if SERVER then

    local addClientLuaFile = package.AddClientLuaFile

    function SendToClient( metadata )
        local packagePath = metadata.packagepath
        if packagePath then
            addClientLuaFile( packagePath )
        end

        local cl_main = metadata.cl_main
        if type( cl_main ) == "string" then
            addClientLuaFile( cl_main )
        end

        local main = metadata.main
        if main then
            addClientLuaFile( metadata.main )
        end

        local send = metadata.send
        if not send then return end

        local folder = metadata.folder
        for _, filePath in ipairs( send ) do
            local localFilePath = folder .. "/" .. filePath
            if fs.IsFile( localFilePath, "LUA" ) then
                addClientLuaFile( localFilePath )
            elseif fs.IsFile( filePath, "LUA" ) then
                addClientLuaFile( filePath )
            end
        end
    end

end

Import = promise.Async( function( metadata )
    local main = metadata.main
    if not main or not fs.IsFile( main, "LUA" ) then
        return promise.Reject( "main file '" .. ( main or "init.lua" ) .. "' is missing." )
    end

    return package.Initialize( metadata, gpm.CompileLua( main ):Await() )
end )
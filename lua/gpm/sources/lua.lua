local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local paths = gpm.paths
local string = string
local fs = gpm.fs

-- Variables
local SERVER = SERVER
local ipairs = ipairs
local type = type

module( "gpm.sources.lua" )

function CanImport( filePath )
    if fs.IsDir( filePath, "LUA" ) then return true end
    if fs.IsFile( filePath, "LUA" ) then
        local extension = string.GetExtensionFromFilename( filePath )
        if extension == "moon" then return SERVER end
        if extension == "lua" then return true end
    end

    return false
end

GetMetadata = promise.Async( function( importPath )
    local metadata, folder = nil, importPath
    if fs.IsDir( folder, "LUA" ) then
        if SERVER then
            gpm.PreCacheMoon( folder, true )
        end
    else
        folder = paths.Fix( string.GetPathFromFilename( importPath ) )
    end

    local packagePath = nil
    if folder ~= "includes/modules" then
        if SERVER then
            local moonPath = folder .. "/package.moon"
            if fs.IsFile( moonPath, "lsv" ) then
                local ok, result = fs.CompileMoon( moonPath, "lsv" ):SafeAwait()
                if not ok then
                    return promise.Reject( result )
                end

                metadata = package.GetMetadata( result )
                packagePath = moonPath
            end
        end

        if packagePath == nil then
            local luaPath = folder .. "/package.lua"
            if fs.IsFile( luaPath, "LUA" ) then
                local ok, result = gpm.CompileLua( luaPath ):SafeAwait()
                if not ok then
                    return promise.Reject( result )
                end

                metadata = package.GetMetadata( result )
                packagePath = luaPath
            end
        end
    end

    -- Single file
    if not metadata then
        metadata = {
            ["autorun"] = true
        }

        local extension = string.GetExtensionFromFilename( importPath )
        if extension == "moon" then
            if SERVER then
                if not fs.IsFile( importPath, "lsv" ) then
                    return promise.Reject( "Unable to compile Moonscript '" .. importPath .. "' file, file not found." )
                end

                gpm.PreCacheMoon( importPath, false )
            end

            importPath = string.sub( importPath, 1, #importPath - #extension ) .. "lua"
        end

        if fs.IsFile( importPath, "LUA" ) then
            metadata.main = importPath
        end
    end

    if packagePath ~= nil then
        metadata.packagepath = packagePath
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
            if fs.IsFile( localFilePath, "lsv" ) then
                addClientLuaFile( localFilePath )
            elseif fs.IsFile( filePath, "lsv" ) then
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

    local ok, result = gpm.Compile( main ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    return package.Initialize( metadata, result )
end )
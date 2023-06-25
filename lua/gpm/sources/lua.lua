local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local paths = gpm.paths
local string = string
local table = table
local fs = gpm.fs

-- Variables
local SERVER, MENU_DLL = SERVER, MENU_DLL
local AddCSLuaFile = AddCSLuaFile
local ipairs = ipairs
local pcall = pcall
local error = error

if ( SERVER or MENU_DLL ) and efsw ~= nil then

    local logger = gpm.Logger
    local timer = timer

    hook.Add( "FileWatchEvent", "gpm.efsw.sources.lua", function( action, _, filePath )
        if action <= 0 then return end
        filePath = paths.Localize( filePath )

        local importPath = string.match( filePath, "packages/[^/]+" )
        if not importPath then return end

        local pkg = gpm.Packages[ importPath ]
        if not pkg then return end

        if action ~= 3 and fs.IsDir( filePath, "lsv" ) then
            if action == 1 then
                fs.Watch( filePath, "lsv", true )
            elseif action == 2 then
                fs.UnWatch( filePath, "lsv", true )
            end
        end

        local timerName = "gpm.efsw.sources.lua." .. importPath
        timer.Create( timerName, 0.25, 1, function()
            timer.Remove( timerName )
            if not pkg:IsInstalled() then return end
            if pkg:IsReloading() then return end
            pkg:Reload():Catch( function( message )
                logger:Error( "Package '%s' reload failed, error:\n%s", pkg:GetIdentifier(), message )
            end )
        end )
    end )

end

module( "gpm.sources.lua" )

function CanImport( filePath )
    if fs.IsDir( filePath, "LUA" ) then return true end
    if fs.IsFile( filePath, "LUA" ) then
        local extension = string.GetExtensionFromFilename( filePath )
        return extension == "moon" or extension == "lua"
    end

    return false
end

GetMetadata = promise.Async( function( importPath )
    importPath = paths.Fix( importPath )
    local metadata = {}

    if fs.IsDir( importPath, "LUA" ) then
        local packagePath = importPath .. "/package.lua"
        if fs.IsLuaFile( packagePath, "LUA", true ) then
            metadata.packagepath = packagePath

            local ok, result = pcall( gpm.CompileLua, packagePath )
            if not ok then
                return promise.Reject( result )
            end

            table.Merge( metadata, package.ExtractMetadata( result ) )
        else
            metadata.autorun = true
        end
    elseif fs.IsFile( importPath, "LUA" ) then
        metadata.init = importPath
        metadata.autorun = true
    end

    if SERVER or MENU_DLL then
        fs.Watch( importPath, "lsv", true )
    end

    return metadata
end )

if SERVER then

    function SendToClient( metadata )
        local packagePath = metadata.packagepath
        if packagePath then
            AddCSLuaFile( paths.FormatToLua( packagePath ) )
        end

        local importPath = metadata.importpath
        local isInFolder = fs.IsDir( importPath, "lsv" )

        local client = metadata.init.client
        if client then
            local filePath = importPath .. "/" .. client
            if fs.IsLuaFile( filePath, "lsv", true ) then
                AddCSLuaFile( paths.FormatToLua( filePath ) )
            elseif fs.IsLuaFile( client, "lsv", true ) then
                AddCSLuaFile( paths.FormatToLua( client ) )
            end
        end

        local send = metadata.send
        if send then
            for _, filePath in ipairs( send ) do
                if isInFolder then
                    local localFilePath = importPath .. "/" .. filePath
                    if fs.IsLuaFile( localFilePath, "lsv", true ) then
                        AddCSLuaFile( paths.FormatToLua( localFilePath ) )
                        continue
                    end
                end

                if fs.IsLuaFile( filePath, "lsv", true ) then
                    AddCSLuaFile( paths.FormatToLua( filePath ) )
                end
            end
        end
    end

end

function CompileInit( metadata )
    local absolutePath = paths.FormatToLua( package.GetCurrentInitByRealm( metadata.init ) )
    local relativePath = metadata.importpath .. "/" .. absolutePath
    if fs.IsLuaFile( relativePath, "LUA", true ) then
        return gpm.CompileLua( relativePath )
    elseif fs.IsLuaFile( absolutePath, "LUA", true ) then
        return gpm.CompileLua( absolutePath )
    end

    error( "Package init file '" .. absolutePath .. "' is missing." )
end

Import = promise.Async( function( metadata )
    local ok, result = pcall( CompileInit, metadata )
    if not ok then
        return promise.Reject( result )
    end

    return package.Initialize( metadata, result )
end )

Reload = promise.Async( function( pkg, metadata )
    table.Empty( pkg.Files )

    if SERVER then
        SendToClient( metadata )
    end

    local ok, result = pcall( CompileInit, metadata )
    if not ok then
        return promise.Reject( result )
    end

    pkg.Init = result

    local ok, result = pkg:Initialize( metadata ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    local ok, result = pkg:Run():SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    return result
end )
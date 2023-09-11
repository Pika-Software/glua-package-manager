local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local paths = gpm.paths
local string = string
local table = table
local fs = gpm.fs

-- Variables
local utils_LowerTableKeys = gpm.utils.LowerTableKeys
local SERVER, MENU_DLL = SERVER, MENU_DLL
local AddCSLuaFolder = gpm.AddCSLuaFolder
local AddCSLuaFile = AddCSLuaFile
local ipairs = ipairs
local type = type

if ( SERVER or MENU_DLL ) and efsw ~= nil then

    local logger = gpm.Logger
    local timer = timer

    hook.Add( "FileWatchEvent", "gpm.efsw.sources.lua", function( action, _, filePath )
        if action <= 0 then return end
        filePath = paths.Localize( filePath )

        local importPath = string.match( filePath, "packages/[^/]+" )
        if not importPath then return end

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

            net.Start( "GPM.Networking" )
                net.WriteUInt( 5, 3 )
                net.WriteString( importPath )
            net.Broadcast()

            local pkg = gpm.Packages[ importPath ]
            if pkg and pkg:IsInstalled() then
                if pkg:IsReloading() then return end
                pkg:Reload():Catch( function( message )
                    logger:Error( "Package '%s' reload failed, error:\n%s", pkg:GetIdentifier(), message )
                end )
            end
        end )
    end )

end

module( "gpm.sources.lua" )

Priority = 2

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

    local isFolder, packagePath = fs.IsDir( importPath, "LUA" )
    if isFolder then
        packagePath = importPath .. "/package.lua"
        if fs.IsLuaFile( packagePath, "LUA", true ) then
            local ok, result = gpm.CompileLua( packagePath ):SafeAwait()
            if not ok then return promise.Reject( result ) end
            table.Merge( metadata, package.ExtractMetadata( result ) )
            if SERVER then utils_LowerTableKeys( metadata ) end
        else
            local initPath = importPath .. "/init.lua"
            if not fs.IsLuaFile( initPath, "LUA", true ) then
                return promise.Reject( "Package '" .. importPath .. "' missing entry point and package information, execution impossible." )
            end

            metadata.init = initPath
            metadata.autorun = true
            packagePath = nil
        end
    elseif fs.IsFile( importPath, "LUA" ) then
        metadata.init = importPath
        metadata.autorun = true
    end

    if SERVER then
        local client = package.FormatInit( metadata.init ).client
        if client then
            if packagePath then
                AddCSLuaFile( packagePath )
            end

            local filePath = importPath .. "/" .. client
            if fs.IsLuaFile( filePath, "lsv", true ) then
                AddCSLuaFile( paths.FormatToLua( filePath ) )
            elseif fs.IsLuaFile( client, "lsv", true ) then
                AddCSLuaFile( paths.FormatToLua( client ) )
            end
        end

        local send = metadata.send
        if send then
            for _, fileName in ipairs( send ) do
                if isFolder then
                    local filePath = importPath .. "/" .. fileName
                    if fs.IsDir( filePath, "lsv" ) then
                        AddCSLuaFolder( filePath )
                        continue
                    elseif fs.IsLuaFile( filePath, "lsv", true ) then
                        AddCSLuaFile( paths.FormatToLua( filePath ) )
                        continue
                    end
                end

                if fs.IsDir( fileName, "lsv" ) then
                    AddCSLuaFolder( fileName )
                elseif fs.IsLuaFile( fileName, "lsv", true ) then
                    AddCSLuaFile( paths.FormatToLua( fileName ) )
                end
            end
        end
    end

    if SERVER or MENU_DLL then
        fs.Watch( importPath, "LUA", true )
    end

    return metadata
end )

function CompileInit( metadata )
    local absolutePath = package.GetCurrentInitByRealm( metadata.init )
    if not absolutePath then
        return promise.Reject( "Package does not support running from this realm." )
    end

    absolutePath = paths.FormatToLua( absolutePath )

    local relativePath = metadata.importpath .. "/" .. absolutePath
    if fs.IsLuaFile( relativePath, "LUA", true ) then
        return gpm.CompileLua( relativePath )
    elseif fs.IsLuaFile( absolutePath, "LUA", true ) then
        return gpm.CompileLua( absolutePath )
    end

    return promise.Reject( "Package '" .. metadata.importpath .. "' init file '" .. absolutePath .. "' is missing." )
end

Import = promise.Async( function( metadata )
    local ok, result = CompileInit( metadata ):SafeAwait()
    if not ok then return promise.Reject( result ) end
    return package.Initialize( metadata, result )
end )

Reload = promise.Async( function( pkg, metadata )
    table.Empty( pkg.Files )

    local ok, result = CompileInit( metadata ):SafeAwait()
    if not ok then return promise.Reject( result ) end
    pkg.Init = result

    local ok, result = pkg:Initialize( metadata ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local ok, result = pkg:Run():SafeAwait()
    if not ok then return promise.Reject( result ) end

    return result
end )
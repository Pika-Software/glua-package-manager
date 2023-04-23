-- Libraries
local promise = gpm.promise
local paths = gpm.paths
local gpm = gpm

-- Variables
local ipairs = ipairs
local pairs = pairs
local type = type

local sources = {}
for _, source in pairs( gpm.sources ) do
    sources[ #sources + 1 ] = source
end

gpm.AsyncImport = promise.Async( function( filePath, parentPackage, isAutorun )
    ArgAssert( filePath, 1, "string" )

    for _, source in ipairs( sources ) do
        if type( source.CanImport ) ~= "function" then continue end
        if not source.CanImport( filePath ) then continue end
        return source.Import( filePath, parentPackage, isAutorun )
    end

    ErrorNoHaltWithStack( "The requested package doesn't exist." )
end )

function gpm.LuaPackageExists( filePath )
    return gpm.sources.lua.CanImport( filePath )
end

function gpm.GetLuaFiles()
    return gpm.sources.lua.Files
end

do

    local assert = assert

    function gpm.Import( filePath, async, parentPackage, isAutorun )
        assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

        local p = gpm.AsyncImport( filePath, parentPackage, isAutorun )
        if not async then return p:Await() end
        return p
    end

end

_G.import = gpm.Import

do

    local file_Find = file.Find

    gpm.ImportFolder = promise.Async( function( filePath, parentPackage, isAutorun )
        filePath = paths.Fix( filePath )

        local files, folders = file_Find( filePath .. "/*", "LUA" )
        for _, folderName in ipairs( folders ) do
            gpm.AsyncImport( filePath .. "/" .. folderName, parentPackage, isAutorun )
        end

        for _, fileName in ipairs( files ) do
            gpm.AsyncImport( filePath .. "/" .. fileName, parentPackage, isAutorun )
        end
    end )

end

local pkgs = gpm.Packages
if type( pkgs ) == "table" then
    for packageName in pairs( pkgs ) do
        pkgs[ packageName ] = nil
    end
end

gpm.ImportFolder( "gpm/packages", nil, true )
gpm.ImportFolder( "packages", nil, true )

do

    local cachePath = "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/"
    local fs = gpm.fs

    function gpm.ClearCache()
        local files, _ = fs.Find( cachePath .. "*", "DATA" )
        for _, fileName in ipairs( files ) do
            fs.Delete( cachePath .. fileName )
        end

        gpm.Logger:Info( "Deleted %d cache files.", #files )
    end

end

if SERVER then

    local BroadcastLua = BroadcastLua

    concommand.Add( "gpm_reload", function( ply )
        if not ply or ply:IsSuperAdmin() then
            BroadcastLua( "include( \"gpm/init.lua\" )" )
            include( "gpm/init.lua" )

            hook.Run( "GPM - Reloaded" )
        end
    end )

    concommand.Add( "gpm_clear_cache", function( ply )
        if not ply or ply:IsListenServerHost() then
            gpm.ClearCache()
        end

        ply:SendLua( "gpm.ClearCache()" )
    end )

end
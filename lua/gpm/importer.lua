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

gpm.AsyncImport = promise.Async( function( filePath )
    ArgAssert( filePath, 1, "string" )

    for _, source in ipairs( sources ) do
        if type( source.CanImport ) ~= "function" then continue end
        if not source.CanImport( filePath ) then continue end
        return source.Import( filePath )
    end
end )

do

    local assert = assert

    function gpm.Import( filePath, async )
        assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

        local p = gpm.AsyncImport( filePath )
        if not async then return p:Await() end
        return p
    end

end

_G.import = gpm.Import

do

    local file_Find = file.Find

    gpm.ImportFolder = promise.Async( function( luaPath )
        luaPath = paths.Fix( luaPath )

        local files, folders = file_Find( luaPath .. "/*", "LUA" )
        for _, folderName in ipairs( folders ) do
            gpm.AsyncImport( luaPath .. "/" .. folderName )
        end

        for _, fileName in ipairs( files ) do
            gpm.AsyncImport( luaPath .. "/" .. fileName )
        end
    end )

end

function gpm.Reload()
    local packages = gpm.Packages
    if type( packages ) == "table" then
        for packageName in pairs( packages ) do
            packages[ packageName ] = nil
        end
    end

    gpm.ImportFolder( "gpm/packages" )
    gpm.ImportFolder( "packages" )
end

if SERVER then

    local BroadcastLua = BroadcastLua
    local IsValid = IsValid

    concommand.Add( "gpm_reload", function( ply )
        if ply == nil or ( IsValid( ply ) and ply:IsSuperAdmin() ) then
            BroadcastLua( "gpm.Reload()" )
            gpm.Reload()
        end
    end )

end
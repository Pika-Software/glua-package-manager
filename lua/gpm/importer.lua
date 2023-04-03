-- Libraries
local promise = gpm.promise
local paths = gpm.paths
local gpm = gpm

-- Functions
local pairs = pairs

local sources = {}
for _, source in pairs( gpm.sources ) do
    sources[ #sources + 1 ] = source
end

gpm.AsyncImport = promise.Async( function( filePath )
    filePath = paths.Fix( filePath )

    for _, source in ipairs( sources ) do
        if not isfunction( source.CanImport ) then continue end
        if not source.CanImport( filePath ) then continue end
        return source.Import( filePath )
    end
end )

function gpm.Import( filePath, async )
    assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

    local p = gpm.AsyncImport( filePath )
    if not async then return p:Await() end
    return p
end

_G.import = gpm.Import

gpm.ImportFolder = promise.Async( function( luaPath )
    luaPath = paths.Fix( luaPath )

    local files, folders = file.Find( luaPath .. "/*", "LUA" )
    for _, folderName in ipairs( folders ) do
        gpm.AsyncImport( luaPath .. "/" .. folderName )
    end

    for _, fileName in ipairs( files ) do
        gpm.AsyncImport( luaPath .. "/" .. fileName )
    end
end )

function gpm.Reload()
    local luaSource = sources.lua
    if ( luaSource ~= nil ) then
        local files = luaSource.Files
        if ( files ~= nil ) then
            for filePath in pairs( luaSource.Files ) do
                files[ filePath ] = nil
            end
        end
    end

    gpm.ImportFolder( "gpm/packages" )
    gpm.ImportFolder( "packages" )
end

concommand.Add( "gpm_reload", function( ply )
    if IsValid( ply ) and not ply:IsSuperAdmin() then return end
    gpm.Reload()
end )
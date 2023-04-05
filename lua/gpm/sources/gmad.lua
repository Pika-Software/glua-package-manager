-- Libraries
local packages = gpm.packages
local sources = gpm.sources
local promise = gpm.promise
local gmad = gpm.gmad
local file = file

module( "gpm.sources.gmad", package.seeall )

function CanImport( filePath )
    return file.Exists( filePath, "GAME" ) and string.EndsWith( filePath, ".gma.dat" ) or string.EndsWith( filePath, ".gma" )
end

local autorunTypes = {
    ["lua/autorun/server/"] = "server",
    ["lua/autorun/client/"] = "client",
    ["lua/entities/"] = "entities",
    ["lua/effects/"] = "effects",
    ["lua/autorun/"] = "shared",
    ["lua/weapons/"] = "sweps"
}

local autorunBuilder = {}
for filePath, pathType in pairs( autorunTypes ) do
    autorunBuilder[ #autorunBuilder + 1 ] = { #filePath, filePath, pathType }
end

Import = promise.Async( function( filePath, env )
    local gma = gmad.Open( filePath, "GAME" )
    if not gma then return promise.Reject( "gma file cannot be read" ) end

    local metadata = packages.GetMetaData( {
        ["name"] = gma:GetTitle(),
        ["description"] = gma:GetDescription(),
        ["author"] = gma:GetAuthor(),
        ["timestamp"] = gma:GetTimestamp(),
        ["requiredContent"] = gma:GetRequiredContent()
    } )

    local ok, files = game.MountGMA( filePath )
    if not ok then return promise.Reject( "gma file mounting failed" ) end

    local autorun = {}

    for _, filePath in ipairs( files ) do
        for _, data in ipairs( autorunBuilder ) do
            if string.sub( filePath, 1, data[ 1 ] ) == data[ 2 ] then
                local filesTable = autorun[ data[ 3 ] ]
                if not filesTable then
                    filesTable = {}; autorun[ data[ 3 ] ] = filesTable
                end

                filesTable[ #filesTable + 1 ] = string.sub( filePath, 5 )
            end
        end
    end

    local luaFiles = sources.lua.Files

    return packages.Initialize( metadata, function()
        local gPackage, environment = gpm.Package, nil
        if gPackage ~= nil then
            environment = gPackage:GetEnvironment()
        end

        if CLIENT then

            local client = autorun.client

            if ( client ~= nil ) then
                for _, filePath in ipairs( client ) do
                    local compiledFile = luaFiles[ filePath ]
                    if not compiledFile then continue end

                    if environment ~= nil then
                        setfenv( compiledFile, environment )
                    end

                    xpcall( compiledFile, ErrorNoHaltWithStack )
                end
            end

            local effectsList = autorun.effects

            if ( effectsList ~= nil ) then
                for _, filePath in ipairs( effectsList ) do
                    local compiledFile = luaFiles[ filePath ]
                    if not compiledFile then continue end

                    local className = string.match( filePath, "^effects/([%w_]+).lua$" )
                    if not className then continue end

                    EFFECT = {}

                    if environment ~= nil then
                        setfenv( compiledFile, environment )
                    end

                    xpcall( compiledFile, ErrorNoHaltWithStack )

                    effects.Register( EFFECT, className )
                    EFFECT = nil
                end
            end

        end

        if SERVER then
            local server = autorun.server
            if ( server ~= nil ) then
                for _, filePath in ipairs( server ) do
                    local compiledFile = luaFiles[ filePath ]
                    if not compiledFile then continue end

                    if environment ~= nil then
                        setfenv( compiledFile, environment )
                    end

                    xpcall( compiledFile, ErrorNoHaltWithStack )
                end
            end
        end

        local shared = autorun.shared
        if ( shared ~= nil ) then
            for _, filePath in ipairs( shared ) do
                local compiledFile = luaFiles[ filePath ]
                if not compiledFile then continue end

                if environment ~= nil then
                    setfenv( compiledFile, environment )
                end

                xpcall( compiledFile, ErrorNoHaltWithStack )
            end
        end

        if not GAMEMODE then
            local p = promise.New()

            hook.Add( "PostGamemodeLoaded", filePath, function()
                hook.Remove( "PostGamemodeLoaded", filePath )
                p:Resolve()
            end )

            p:Await( true )
        end

        local entities = autorun.entities
        if ( entities ~= nil ) then
            for _, filePath in ipairs( entities ) do
                local compiledFile = luaFiles[ filePath ]
                if not compiledFile then continue end

                local className, fileName = string.match( filePath, "^entities/([%w_]+)/?([%w_]*)" )

                local folder = nil
                if ( fileName ~= nil ) then
                    if CLIENT and fileName ~= "cl_init.lua" then continue end
                    if SERVER and fileName ~= "init.lua" then continue end
                    folder = "entities/" .. className
                end

                ENT = {
                    ["ClassName"] = className,
                    ["Folder"] = folder
                }

                if environment ~= nil then
                    setfenv( compiledFile, environment )
                end

                xpcall( compiledFile, ErrorNoHaltWithStack )

                scripted_ents.Register( ENT, className )
                ENT = nil
            end
        end

        local sweps = autorun.sweps
        if ( sweps ~= nil ) then
            for _, filePath in ipairs( sweps ) do
                local compiledFile = luaFiles[ filePath ]
                if not compiledFile then continue end

                local className, fileName = string.match( filePath, "^weapons/([%w_]+)/?([%w_]*)" )

                local folder = nil
                if ( fileName ~= nil and fileName ~= "" ) then
                    if CLIENT and fileName ~= "cl_init" then continue end
                    if SERVER and fileName ~= "init" then continue end
                    folder = "weapons/" .. className
                end

                SWEP = {
                    ["ClassName"] = className,
                    ["Base"] = "weapon_base",
                    ["Folder"] = folder
                }

                SWEP.Primary = {}
                SWEP.Secondary = {}

                if environment ~= nil then
                    setfenv( compiledFile, environment )
                end

                xpcall( compiledFile, ErrorNoHaltWithStack )

                weapons.Register( SWEP, className )
                SWEP = nil
            end
        end
    end, luaFiles, env )
end )
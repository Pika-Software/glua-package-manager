-- Libraries
local packages = gpm.packages
local sources = gpm.sources
local promise = gpm.promise
local gmad = gpm.gmad
local string = string
local file = file

-- Variables
local scripted_ents_Register = scripted_ents.Register
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local effects_Register = effects.Register
local weapons_Register = weapons.Register
local CLIENT, SERVER = CLIENT, SERVER
local game_MountGMA = game.MountGMA
local setfenv = setfenv
local ipairs = ipairs
local xpcall = xpcall

local gamemodeResult
local function waitGamemode()
    if GAMEMODE then return promise.Resolve() end
    if gamemodeResult then return gamemodeResult end
    gamemodeResult = promise.New()

    hook.Add( "PostGamemodeLoaded", "gpm.sources.gmad", function()
        hook.Remove( "PostGamemodeLoaded", "gpm.sources.gmad" )
        gamemodeResult:Resolve()
    end )

    return gamemodeResult
end

local autorunTypes = {
    ["lua/autorun/server/"] = "server",
    ["lua/autorun/client/"] = "client",
    ["lua/gpm/packages/"] = "packages",
    ["lua/packages/"] = "packages",
    ["lua/entities/"] = "entities",
    ["lua/effects/"] = "effects",
    ["lua/autorun/"] = "shared",
    ["lua/weapons/"] = "sweps"
}

local autorunBuilder = {}
for filePath, pathType in pairs( autorunTypes ) do
    autorunBuilder[ #autorunBuilder + 1 ] = { #filePath, filePath, pathType }
end

module( "gpm.sources.gmad" )

function CanImport( filePath )
    return file.Exists( filePath, "GAME" ) and string.EndsWith( filePath, ".gma.dat" ) or string.EndsWith( filePath, ".gma" )
end

Import = promise.Async( function( filePath, parentPackage )
    local gma = gmad.Open( filePath, "GAME" )
    if not gma then return promise.Reject( "gma file cannot be read" ) end

    local metadata = packages.GetMetaData( {
        ["name"] = gma:GetTitle(),
        ["description"] = gma:GetDescription(),
        ["author"] = gma:GetAuthor(),
        ["timestamp"] = gma:GetTimestamp(),
        ["requiredContent"] = gma:GetRequiredContent()
    } )

    local ok, files = game_MountGMA( filePath )
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

                    effects_Register( EFFECT, className )
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

        local packageList = autorun.packages
        if ( packageList ~= nil ) then
            local packages = {}

            for _, filePath in ipairs( packageList ) do
                local packageName = string.match( filePath, "packages/([%w%s_]+)/" )
                if not packageName then continue end

                local packagePath = string.match( filePath, "^([%w%s_]+)/" .. packageName .. "/" ) .. "/" .. packageName
                if not packagePath then continue end

                if packages[ packagePath ] then continue end
                packages[ packagePath ] = true

                sources.lua.Import( packagePath, gpm.Package or parentPackage )
            end
        end

        -- Waiting a gamemode
        waitGamemode():Await()

        local entities = autorun.entities
        if ( entities ~= nil ) then
            local sents = {}
            for _, filePath in ipairs( entities ) do
                local className, fileName = string.match( filePath, "^entities/([%w_]+)/?([%w_%.]*)/?" )
                if not className then continue end

                local sent = sents[ className ]
                if not sent then
                    sent = { ["Files"] = {} }
                    sents[ className ] = sent
                end

                sent.Files[ #sent.Files + 1 ] = { filePath, fileName }
            end

            for className, sent in pairs( sents ) do
                ENT = {
                    ["ClassName"] = className,
                    ["Folder"] = folder
                }

                local files = sent.Files
                if ( #files > 1 ) then
                    ENT.Folder = "entities/" .. className
                end

                for _, data in ipairs( files ) do
                    if ( data[ 2 ] ~= nil and data[ 2 ] ~= "" ) then
                        if CLIENT and data[ 2 ] ~= "cl_init.lua" then continue end
                        if SERVER and data[ 2 ] ~= "init.lua" then continue end
                    end

                    local compiledFile = luaFiles[ data[ 1 ] ]
                    if not compiledFile then continue end

                    if environment ~= nil then
                        setfenv( compiledFile, environment )
                    end

                    xpcall( compiledFile, ErrorNoHaltWithStack )
                end

                scripted_ents_Register( ENT, className )
                ENT = nil
            end
        end

        local sweps = autorun.sweps
        if ( sweps ~= nil ) then
            local weps = {}
            for _, filePath in ipairs( sweps ) do
                local className, fileName = string.match( filePath, "^weapons/([%w_]+)/?([%w_%.]*)" )
                if not className then continue end

                local swep = weps[ className ]
                if not swep then
                    swep = { ["Files"] = {} }
                    swep[ className ] = swep
                end

                swep.Files[ #swep.Files + 1 ] = { filePath, fileName }
            end

            for className, swep in pairs( weps ) do
                SWEP = {
                    ["ClassName"] = className,
                    ["Base"] = "weapon_base"
                }

                SWEP.Primary = {}
                SWEP.Secondary = {}

                local files = sent.Files
                if ( #files > 1 ) then
                    ENT.Folder = "weapons/" .. className
                end

                for _, data in ipairs( files ) do
                    if ( data[ 2 ] ~= nil and data[ 2 ] ~= "" ) then
                        if CLIENT and data[ 2 ] ~= "cl_init.lua" then continue end
                        if SERVER and data[ 2 ] ~= "init.lua" then continue end
                    end

                    local compiledFile = luaFiles[ data[ 1 ] ]
                    if not compiledFile then continue end

                    if environment ~= nil then
                        setfenv( compiledFile, environment )
                    end

                    xpcall( compiledFile, ErrorNoHaltWithStack )
                end

                weapons_Register( SWEP, className )
                SWEP = nil
            end
        end
    end, luaFiles, parentPackage )
end )
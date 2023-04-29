-- Libraries
local packages = gpm.packages
local sources = gpm.sources
local promise = gpm.promise
local gmad = gpm.gmad
local string = string
local fs = gpm.fs

-- Variables
local scripted_ents_Register = scripted_ents.Register
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local effects_Register = effects.Register
local weapons_Register = weapons.Register
local CLIENT, SERVER = CLIENT, SERVER
local game_MountGMA = game.MountGMA
local setfenv = setfenv
local ipairs = ipairs
local pcall = pcall

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
    ["lua/gpm/packages/"] = "gpmPackages",
    ["lua/autorun/server/"] = "server",
    ["lua/autorun/client/"] = "client",
    ["lua/packages/"] = "packages",
    ["lua/entities/"] = "entities",
    ["lua/effects/"] = "effects",
    ["lua/autorun/"] = "shared",
    ["lua/weapons/"] = "weapons"
}

local typesCache = {}
for filePath, pathType in pairs( autorunTypes ) do
    typesCache[ #typesCache + 1 ] = { #filePath, filePath, pathType }
end

autorunTypes = typesCache
typesCache = nil

module( "gpm.sources.gmad" )

function CanImport( filePath )
    return fs.Exists( filePath, "GAME" ) and string.EndsWith( filePath, ".gma.dat" ) or string.EndsWith( filePath, ".gma" )
end

local runLua = promise.Async( function( filePath, environment )
    local files = sources.lua.Files
    if not files then return end

    local func = files[ filePath ]
    if not func then return end

    if environment ~= nil then
        setfenv( func, environment )
    end

    local ok, result = pcall( func )
    if not ok then
        ErrorNoHaltWithStack( result )
        return
    end

    return result
end )

RunLua = runLua

Import = promise.Async( function( filePath, psarentPackage )
    local gma = gmad.Open( filePath, "GAME" )
    if not gma then
        return promise.Reject( "Package `" .. filePath .. "` gma file cannot be readed." )
    end

    local metadata = packages.GetMetadata( {
        ["requiredContent"] = gma:GetRequiredContent(),
        ["description"] = gma:GetDescription(),
        ["timestamp"] = gma:GetTimestamp(),
        ["author"] = gma:GetAuthor(),
        ["name"] = gma:GetTitle()
    } )

    gma:Close()

    local ok, files = game_MountGMA( filePath )
    if not ok then
        return promise.Reject( "Package `" .. metadata.name .. "@" .. metadata.version .. "` gma file mounting failed." )
    end

    local autorun = {}
    for _, filePath in ipairs( files ) do
        for _, data in ipairs( autorunTypes ) do
            if string.sub( filePath, 1, data[ 1 ] ) == data[ 2 ] then
                local filesTable = autorun[ data[ 3 ] ]
                if not filesTable then
                    filesTable = {}; autorun[ data[ 3 ] ] = filesTable
                end

                filesTable[ #filesTable + 1 ] = string.sub( filePath, 5 )
            end
        end
    end

    return packages.Initialize( metadata, function()
        local gPackage, environment = gpm.Package, nil
        if gPackage ~= nil then
            environment = gPackage:GetEnvironment()
        end

        -- Packages
        local packages = autorun.packages
        if packages ~= nil then
            local imported = {}

            for _, filePath in ipairs( packages ) do
                local packagePath = string.match( filePath, "packages/[^/]+" )
                if not packagePath then continue end

                if imported[ packagePath ] then continue end
                imported[ packagePath ] = true

                local ok, result = sources.lua.Import( packagePath, gPackage or parentPackage ):SafeAwait()
                if not ok then return promise.Reject( result ) end
            end
        end

        -- Legacy packages
        packages = autorun.gpmPackages
        if packages ~= nil then
            local imported = {}

            for _, filePath in ipairs( packages ) do
                local packagePath = string.match( filePath, "gpm/packages/[^/]+" )
                if not packagePath then continue end

                if imported[ packagePath ] then continue end
                imported[ packagePath ] = true

                local ok, result = sources.lua.Import( packagePath, gPackage or parentPackage ):SafeAwait()
                if not ok then return promise.Reject( result ) end
            end
        end

        -- Client autorun
        if CLIENT then
            local client = autorun.client
            if client ~= nil then
                for _, filePath in ipairs( client ) do
                    runLua( filePath, environment )
                end
            end
        end

        -- Server autorun
        if SERVER then
            local server = autorun.server
            if server ~= nil then
                for _, filePath in ipairs( server ) do
                    runLua( filePath, environment )
                end
            end
        end

        -- Shared autorun
        local shared = autorun.shared
        if shared ~= nil then
            for _, filePath in ipairs( shared ) do
                runLua( filePath, environment )
            end
        end

        -- Lua effects
        if CLIENT then
            local effects = autorun.effects
            if effects ~= nil then
                for _, filePath in ipairs( effects ) do
                    local className = string.match( filePath, "effects/(.+)%.lua" )
                    if not className then continue end

                    EFFECT = {}

                    runLua( filePath, environment ):SafeAwait()

                    local ok, err = pcall( effects_Register, EFFECT, className )
                    if not ok then ErrorNoHaltWithStack( err ) end

                    EFFECT = nil
                end
            end
        end

        -- Waiting a gamemode
        waitGamemode():SafeAwait()

        -- Entity registration
        local entities = autorun.entities
        if entities ~= nil then
            local registred = {}

            for _, filePath in ipairs( entities ) do
                local entityPath = string.match( filePath, "entities/([^/]+)" )
                if not entityPath then continue end

                local className = entityPath
                if string.EndsWith( className, ".lua" ) then
                    className = string.Replace( entityPath, ".lua", "" )

                    ENT = {
                        ["ClassName"] = className,
                        ["Folder"] = "entities/" .. className
                    }

                    if SERVER then
                        AddCSLuaFile( filePath )
                    end

                    runLua( filePath, environment ):SafeAwait()

                else

                    if registred[ className ] then continue end
                    registred[ className ] = true

                    ENT = {
                        ["ClassName"] = className,
                        ["Folder"] = "entities/" .. className
                    }

                    -- Server init
                    local initPath = "entities/" .. className .. "/init.lua"
                    if SERVER and table.HasIValue( entities, initPath ) then
                        runLua( initPath, environment ):SafeAwait()
                    end

                    -- Client init
                    initPath = "entities/" .. className .. "/cl_init.lua"
                    if CLIENT and table.HasIValue( entities, initPath ) then
                        runLua( initPath, environment ):SafeAwait()
                    end

                end

                local ok, err = pcall( scripted_ents_Register, ENT, className )
                if not ok then ErrorNoHaltWithStack( err ) end

                ENT = nil
            end
        end

        -- Weapons registration
        local weapons = autorun.weapons
        if weapons ~= nil then
            local registred = {}

            for _, filePath in ipairs( weapons ) do
                local entityPath = string.match( filePath, "weapons/([^/]+)" )
                if not entityPath then continue end

                local className = entityPath
                if string.EndsWith( className, ".lua" ) then
                    className = string.Replace( entityPath, ".lua", "" )

                    SWEP = {
                        ["ClassName"] = className,
                        ["Folder"] = "weapons/" .. className,
                        ["Base"] = "weapon_base",
                        ["Secondary"] = {},
                        ["Primary"] = {}
                    }

                    if SERVER then
                        AddCSLuaFile( filePath )
                    end

                    runLua( filePath, environment ):SafeAwait()

                else

                    if registred[ className ] then continue end
                    registred[ className ] = true

                    SWEP = {
                        ["ClassName"] = className,
                        ["Folder"] = "weapons/" .. className,
                        ["Base"] = "weapon_base",
                        ["Secondary"] = {},
                        ["Primary"] = {}
                    }

                    -- Server init
                    local initPath = "weapons/" .. className .. "/init.lua"
                    if SERVER and table.HasIValue( weapons, initPath ) then
                        runLua( initPath, environment ):SafeAwait()
                    end

                    -- Client init
                    initPath = "weapons/" .. className .. "/cl_init.lua"
                    if CLIENT and table.HasIValue( weapons, initPath ) then
                        runLua( initPath, environment ):SafeAwait()
                    end

                end

                local ok, err = pcall( weapons_Register, SWEP, className )
                if not ok then ErrorNoHaltWithStack( err ) end

                SWEP = nil
            end
        end
    end, sources.lua.Files, parentPackage )
end )
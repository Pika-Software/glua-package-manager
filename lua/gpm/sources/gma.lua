local gpm = gpm

-- Libraries
local package = gpm.package
local promise = gpm.promise
local paths = gpm.paths
local gmad = gpm.gmad
local string = string
local fs = gpm.fs

-- Variables
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local effects_Register = ( CLIENT and not MENU_DLL ) and effects.Register
local scripted_ents_Register = not MENU_DLL and scripted_ents.Register
local weapons_Register = not MENU_DLL and weapons.Register
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local util_JSONToTable = util.JSONToTable
local game_MountGMA = game.MountGMA
local logger = gpm.Logger
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
    ["lua/autorun/server/"] = "server",
    ["lua/autorun/client/"] = "client",
    ["lua/package/"] = "package",
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

module( "gpm.sources.gma" )

function CanImport( filePath )
    return fs.Exists( filePath, "GAME" ) and string.EndsWith( filePath, ".gma.dat" ) or string.EndsWith( filePath, ".gma" )
end

function GetInfo( filePath )
    return {
        ["importPath"] = paths.Fix( filePath )
    }
end

local runLua = promise.Async( function( filePath, environment )
    local func = gpm.CompileLua( filePath )
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

Import = promise.Async( function( info )
    local importPath = info.importPath

    local gma = gmad.Open( importPath, "GAME" )
    if not gma then
        logger:Error( "Package `%s` import failed, gma file cannot be readed.", importPath )
        return
    end

    info.requiredContent = gma:GetRequiredContent()
    info.description = gma:GetDescription()
    info.timestamp = gma:GetTimestamp()
    info.author = gma:GetAuthor()
    info.name = gma:GetTitle()
    gma:Close()

    local description = util_JSONToTable( info.description )
    if description then
        for key, value in pairs( description ) do
            info[ key ] = value
        end
    end

    local ok, files = game_MountGMA( importPath )
    if not ok then
        logger:Error( "Package `%s` import failed, gma file cannot be mounted.", importPath )
        return
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

    return package.Initialize( package.GetMetadata( info ), function()
        local pkg, environment = _PACKAGE, nil
        if pkg ~= nil then
            environment = pkg:GetEnvironment()
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

        if MENU_DLL then return end

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

        -- Packages
        local packages = autorun.package
        if packages ~= nil then
            local imported = {}

            for _, filePath in ipairs( packages ) do
                local packagePath = string.match( filePath, "package/[^/]+" )
                if not packagePath then continue end

                if imported[ packagePath ] then continue end
                imported[ packagePath ] = true

                local ok, result = gpm.SourceImport( "lua", packagePath, pkg, false ):SafeAwait()
                if not ok then return promise.Reject( result ) end
            end
        end
    end )
end )
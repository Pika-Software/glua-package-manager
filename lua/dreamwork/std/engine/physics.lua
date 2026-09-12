local std = dreamwork.std

local physenv = physenv
local util = util

local setmetatable = std.setmetatable
local isString = std.isString
local error = std.error

-- TODO: rewrite this crap

---
--- https://wiki.facepunch.com/gmod/Enums/MAT
---
--- https://developer.valvesoftware.com/wiki/Material_Types
---
---@type table<string, integer>
local material_ids = {
    ANTLION = 65,
    A = 65,
    BLOODYFLESH = 66,
    B = 66,
    CONCRETE = 67,
    C = 67,
    DIRT = 68,
    D = 68,
    EGGSHELL = 69,
    E = 69,
    FLESH = 70,
    F = 70,
    GRATE = 71,
    G = 71,
    ALIENFLESH = 72,
    H = 72,
    CLIP = 73,
    I = 73,
    SNOW = 74,
    J = 74,
    PLASTIC = 76,
    L = 76,
    METAL = 77,
    M = 77,
    SAND = 78,
    N = 78,
    FOLIAGE = 79,
    O = 79,
    COMPUTER = 80,
    P = 80,
    SLOSH = 83,
    S = 83,
    TILE = 84,
    T = 84,
    GRASS = 85,
    VENT = 86,
    V = 86,
    WOOD = 87,
    W = 87,
    DEFAULT = 88,
    GLASS = 89,
    Y = 89,
    WARPSHIELD = 90
}

---@class dreamwork.std.physics
local physics = {
    getSimulationDuration = physenv.GetLastSimulationTime
}

do

    ---@class dreamwork.std.physics.collide
    local collide = {
        createFromModel = _G.CreatePhysCollidesFromModel,
        createBox = _G.CreatePhysCollideBox,
    }

    setmetatable( collide, { __index = std.debug.findmetatable( "PhysCollide" ) } )

    physics.collide = collide

end

---@type PhysObj
---@diagnostic disable-next-line: assign-type-mismatch
physics.object = setmetatable( {}, { __index = std.debug.findmetatable( "PhysObj" ) } )

do

    ---@class dreamwork.std.physics.surface
    local surface = {
        getID = util.GetSurfaceIndex,
        getData = util.GetSurfaceData,
        getName = util.GetSurfacePropName,
        Materials = material_ids
    }


    local physenv_AddSurfaceData = physenv.AddSurfaceData
    local table_concat = std.table.concat
    local tostring = std.tostring

    local mat2name = {
        [ material_ids.A ] = "A",
        [ material_ids.B ] = "B",
        [ material_ids.C ] = "C",
        [ material_ids.D ] = "D",
        [ material_ids.E ] = "E",
        [ material_ids.F ] = "F",
        [ material_ids.G ] = "G",
        [ material_ids.H ] = "H",
        [ material_ids.I ] = "I",
        [ material_ids.L ] = "L",
        [ material_ids.M ] = "M",
        [ material_ids.N ] = "N",
        [ material_ids.O ] = "O",
        [ material_ids.P ] = "P",
        [ material_ids.S ] = "S",
        [ material_ids.T ] = "T",
        [ material_ids.V ] = "V",
        [ material_ids.W ] = "W",
        [ material_ids.Y ] = "Y"
    }

    -- https://wiki.facepunch.com/gmod/Structures/SurfacePropertyData
    local garry2key = {
        hardnessFactor = "audiohardnessfactor",
        hardThreshold = "impactHardThreshold",
        hardVelocityThreshold = "audioHardMinVelocity",
        reflectivity = "audioreflectivity",
        roughnessFactor = "audioroughnessfactor",
        roughThreshold = "scrapeRoughThreshold",
        jumpFactor = "jumpfactor",
        maxSpeedFactor = "maxspeedfactor",
        breakSound = "break",
        bulletImpactSound = "bulletimpact",
        impactHardSound = "impacthard",
        impactSoftSound = "impactsoft",
        rollingSound = "roll",
        scrapeRoughSound = "scraperough",
        scrapeSmoothSound = "scrapesmooth",
        stepLeftSound = "stepleft",
        stepRightSound = "stepright",
        strainSound = "strain"
    }

    --- Adds surface properties to the game's physics environment.
    ---@param data SurfacePropertyData | table The surface data to be added.
    function surface.add( data )
        local buffer, length = {}, 0

        for key, value in pairs( data ) do
            key = tostring( key )

            if key ~= "name" then
                value = tostring( value )

                if key == "material" then
                    key, value = "gamematerial", mat2name[ value ] or value
                end

                length = length + 1
                buffer[ length ] = "\""

                length = length + 1
                buffer[ length ] = garry2key[ key ] or key

                length = length + 1
                buffer[ length ] = "\"\t\""

                length = length + 1
                buffer[ length ] = value

                length = length + 1
                buffer[ length ] = "\"\n"
            end
        end

        if length == 0 then
            error( "Invalid surface data", 2 )
        else
            local name = data.name
            if isString( name ) then
                physenv_AddSurfaceData( "\"" .. name .. "\"\n{\n" .. table_concat( buffer, "", 1, length ) .. "}" )
            else
                error( "Invalid surface name", 2 )
            end
        end
    end

    physics.surface = surface

end

do

    ---@class dreamwork.std.physics.settings
    ---@field max_ovw_time number Maximum amount of seconds to precalculate collisions with world. ( Default: 1 )
    ---@field max_ovo_time number Maximum amount of seconds to precalculate collisions with objects. ( Default: 0.5 )
    ---@field max_collisions_per_tick number Maximum collision checks per tick.
    --- Objects may penetrate after this many collision checks. ( Default: 50000 )
    ---@field max_object_collisions_pre_tick number Maximum collision per object per tick.
    --- Object will be frozen after this many collisions (visual hitching vs. CPU cost). ( Default: 10 )
    ---@field max_velocity number Maximum world-space speed of an object in inches per second. ( Default: 4000 )
    ---@field max_angular_velocity number Maximum world-space rotational velocity in degrees per second. ( Default: 7200 )
    ---@field min_friction_mass number Minimum mass of an object to be affected by friction. ( Default: 10 )
    ---@field max_friction_mass number Maximum mass of an object to be affected by friction. ( Default: 2500 )
    local settings = {}

    local physenv_GetPerformanceSettings, physenv_SetPerformanceSettings = physenv.GetPerformanceSettings, physenv.SetPerformanceSettings
    local physenv_GetAirDensity, physenv_SetAirDensity = physenv.GetAirDensity, physenv.SetAirDensity
    local physenv_GetGravity, physenv_SetGravity = physenv.GetGravity, physenv.SetGravity

    -- https://wiki.facepunch.com/gmod/Structures/PhysEnvPerformanceSettings
    local key2performance = {
        max_ovw_time = "LookAheadTimeObjectsVsWorld",
        max_ovo_time = "LookAheadTimeObjectsVsObject",

        max_collisions_per_tick = "MaxCollisionChecksPerTimestep",
        max_object_collisions_pre_tick = "MaxCollisionsPerObjectPerTimestep",

        max_velocity = "MaxVelocity",
        max_angular_velocity = "MaxAngularVelocity",

        min_friction_mass = "MinFrictionMass",
        max_friction_mass = "MaxFrictionMass"
    }

    setmetatable( settings, {
        __index = function( tbl, key )
            local performanceKey = key2performance[ key ]
            if performanceKey ~= nil then
                return physenv_GetPerformanceSettings()[ performanceKey ]
            elseif key == "gravity" then
                return physenv_GetGravity()
            elseif key == "air_density" then
                return physenv_GetAirDensity()
            end
        end,
        __newindex = function( tbl, key, value )
            local performanceKey = key2performance[ key ]
            if performanceKey ~= nil then
                local values = physenv_GetPerformanceSettings()
                values[ performanceKey ] = value
                physenv_SetPerformanceSettings( values )
            elseif key == "gravity" then
                physenv_SetGravity( value )
            elseif key == "air_density" then
                physenv_SetAirDensity( value )
            end
        end
    } )

    physics.settings = settings

end

return physics

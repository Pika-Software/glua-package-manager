-- Libraries
local string = string
local debug = debug
local table = table
local gpm = gpm

-- Variables
local tonumber = tonumber
local module = module
local ipairs = ipairs
local pairs = pairs

-- https://wiki.facepunch.com/gmod/Global.TypeID
do

    local TypeID = TypeID

    local types = gpm.VTypes
    if TypeID( types ) ~= TYPE_TABLE then
        types = { { TYPE_COLOR, IsColor } }; gpm.VTypes = types
    end

    function gpm.SetTypeID( id, func )
        ArgAssert( id, 1, "number" )
        ArgAssert( func, 2, "function" )

        for index, tbl in ipairs( types ) do
            if tbl[ 1 ] ~= id then continue end
            table.remove( types, index )
        end

        types[ #types + 1 ] = { id, func }
    end

    function gpm.TypeID( any )
        for _, tbl in ipairs( types ) do
            if tbl[ 2 ]( any ) then return tbl[ 1 ] end
        end

        return TypeID( any )
    end

end

-- https://wiki.facepunch.com/gmod/Global.type
do

    local TYPE_NONE = TYPE_NONE
    local list = list

    -- https://wiki.facepunch.com/gmod/Enums/TYPE
    list.Set( "GPM - Type Names", TYPE_PARTICLESYSTEM, "CNewParticleEffect" )
    list.Set( "GPM - Type Names", TYPE_PROJECTEDTEXTURE, "ProjectedTexture" )
    list.Set( "GPM - Type Names", TYPE_PIXELVISHANDLE, "pixelvis_handle_t" )
    list.Set( "GPM - Type Names", TYPE_RECIPIENTFILTER, "CRecipientFilter" )
    list.Set( "GPM - Type Names", TYPE_SOUNDHANDLE, "IGModAudioChannel" )
    list.Set( "GPM - Type Names", TYPE_LIGHTUSERDATA, "light userdata" )
    list.Set( "GPM - Type Names", TYPE_PARTICLEEMITTER, "CLuaEmitter" )
    list.Set( "GPM - Type Names", TYPE_DAMAGEINFO, "CTakeDamageInfo" )
    list.Set( "GPM - Type Names", TYPE_LOCOMOTION, "CLuaLocomotion" )
    list.Set( "GPM - Type Names", TYPE_SURFACEINFO, "SurfaceInfo" )
    list.Set( "GPM - Type Names", TYPE_PHYSCOLLIDE, "PhysCollide" )
    list.Set( "GPM - Type Names", TYPE_EFFECTDATA, "CEffectData" )
    list.Set( "GPM - Type Names", TYPE_PARTICLE, "CLuaParticle" )
    list.Set( "GPM - Type Names", TYPE_NAVLADDER, "CNavLadder" )
    list.Set( "GPM - Type Names", TYPE_VIDEO, "IVideoWriter" )
    list.Set( "GPM - Type Names", TYPE_MATERIAL, "IMaterial" )
    list.Set( "GPM - Type Names", TYPE_MOVEDATA, "CMoveData" )
    list.Set( "GPM - Type Names", TYPE_PATH, "PathFollower" )
    list.Set( "GPM - Type Names", TYPE_SOUND, "CSoundPatch" )
    list.Set( "GPM - Type Names", TYPE_USERDATA, "userdata" )
    list.Set( "GPM - Type Names", TYPE_FUNCTION, "function" )
    list.Set( "GPM - Type Names", TYPE_TEXTURE, "ITexture" )
    list.Set( "GPM - Type Names", TYPE_USERCMD, "CUserCmd" )
    list.Set( "GPM - Type Names", TYPE_RESTORE, "IRestore" )
    list.Set( "GPM - Type Names", TYPE_NAVAREA, "CNavArea" )
    list.Set( "GPM - Type Names", TYPE_PHYSOBJ, "PhysObj" )
    list.Set( "GPM - Type Names", TYPE_DLIGHT, "dlight_t" )
    list.Set( "GPM - Type Names", TYPE_USERMSG, "bf_read" )
    list.Set( "GPM - Type Names", TYPE_MATRIX, "VMatrix" )
    list.Set( "GPM - Type Names", TYPE_CONVAR, "ConVar" )
    list.Set( "GPM - Type Names", TYPE_VECTOR, "Vector" )
    list.Set( "GPM - Type Names", TYPE_ENTITY, "Entity" )
    list.Set( "GPM - Type Names", TYPE_THREAD, "thread" )
    list.Set( "GPM - Type Names", TYPE_STRING, "string" )
    list.Set( "GPM - Type Names", TYPE_NUMBER, "number" )
    list.Set( "GPM - Type Names", TYPE_NONE, "unknown" )
    list.Set( "GPM - Type Names", TYPE_BOOL, "boolean" )
    list.Set( "GPM - Type Names", TYPE_IMESH, "IMesh" )
    list.Set( "GPM - Type Names", TYPE_PANEL, "Panel" )
    list.Set( "GPM - Type Names", TYPE_ANGLE, "Angle" )
    list.Set( "GPM - Type Names", TYPE_COLOR, "Color" )
    list.Set( "GPM - Type Names", TYPE_TABLE, "table" )
    list.Set( "GPM - Type Names", TYPE_SAVE, "ISave" )
    list.Set( "GPM - Type Names", TYPE_FILE, "File" )
    list.Set( "GPM - Type Names", TYPE_NIL, "nil" )

    local types = list.GetForEdit( "GPM - Type Names" )

    function gpm.type( any )
        local str = types[ gpm.TypeID( any ) ]
        if ( str ~= nil ) then
            return str
        end

        return types[ TYPE_NONE ] or "unknown"
    end

end

-- Checks if argument have valid type
do

    local error = error

    function ArgAssert( value, argNum, expected, errorlevel )
        local valueType = gpm.type( value )
        if valueType == expected then return end

        local dinfo = debug.getinfo( 2, "n" )
        error( string.format( "bad argument #%d to \'%s\' (%s expected, got %s)", argNum, dinfo and dinfo.name or "func", expected, valueType ), errorlevel or 3 )
    end

end

-- Returns true if string is url
function string.IsURL( str )
    return string.match( str, "^https?://.*" ) ~= nil
end

-- Make JIT happy
function debug.fempty()
end

-- Returns copy of function
function debug.fcopy( func )
    return function( ... )
        return func( ... )
    end
end

-- FileClass extensions
do

    local meta = FindMetaTable( "File" )

    function meta:SkipEmpty()
        while not self:EndOfFile() do
            if self:ReadByte() ~= 0 then self:Skip( -1 ) break end
        end
    end

    function meta:ReadString()
        local startPos = self:Tell()
        local len = 0

        while not self:EndOfFile() and self:ReadByte() ~= 0 do
            len = len + 1
        end

        self:Seek( startPos )
        local data = self:Read( len )
        self:Skip( 1 )

        return data
    end

    function meta:WriteString( str )
        self:Write( str )
        self:WriteByte( 0 )
    end

end

do

    local timer_Simple = timer.Simple
    local unpack = unpack

    function util.NextTick( func, ... )
        ArgAssert( func, 1, "function" )

        local args = {...}
        timer_Simple( 0, function()
            if ( #args ~= 0 ) then
                func( unpack( args ) )
                return
            end

            func()
        end )
    end

end

function table.Lookup( tbl, str, default )
    for _, key in ipairs( string.Split( str, "." ) ) do
        tbl = tbl[ key ]
        if not tbl then return default end
    end

    return tbl
end

function table.SetValue( tbl, str, value, ifEmpty )
    local keys = string.Split( str, "." )
    local count = #keys

    for num, key in ipairs( keys ) do
        if num == count then
            local oldValue = tbl[ key ]
            if oldValue ~= nil and ifEmpty then
                return oldValue
            end

            tbl[ key ] = value
            return value
        end

        local nextValue = tbl[ key ]
        if nextValue == nil then
            tbl[ key ] = {}
        elseif gpm.type( nextValue ) ~= "table" then
            return
        end

        tbl = tbl[ key ]
    end
end

module( "gpm.utils" )

function LowerTableKeys( tbl )
    for key, value in pairs( tbl ) do
        if gpm.type( value ) == "table" then value = LowerTableKeys( value ) end
        if gpm.type( key ) ~= "string" then continue end
        tbl[ key ] = nil; tbl[ string.lower( key ) ] = value
    end

    return tbl
end

function Version( number )
    if not number then return "invalid version" end
    local version = string.format( "%06d", number )
    return string.format( "%d.%d.%d", tonumber( string.sub( version, 0, 2 ) ), tonumber( string.sub( version, 3, 4 ) ), tonumber( string.sub( version, 5 ) ) )
end

function GetCurrentFile()
    for i = 2, 6 do
        local info = debug.getinfo( i, "S" )
        if not info then break end
        if info.what == "main" then return info.short_src end
    end
end

module( "gpm.paths" )

-- File path fix
function Fix( filePath )
    return string.lower( string.gsub( filePath, "[/\\]+", "/" ) )
end

-- File path join
function Join( filePath, ... )
    return Fix( table.concat( { filePath, ... }, "/" ) )
end

-- File path localization
function Localize( filePath )
    filePath = string.gsub( filePath, "^addons/[%w%-_]-/", "" )
    filePath = string.gsub( filePath, "^lua/", "" )
    return filePath
end

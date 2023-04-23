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

    local types = list.GetForEdit( "GPM - Type Names" )
    local TYPE_NONE = TYPE_NONE

    -- https://wiki.facepunch.com/gmod/Enums/TYPE
    types[TYPE_PARTICLESYSTEM] = "CNewParticleEffect"
    types[TYPE_PROJECTEDTEXTURE] = "ProjectedTexture"
    types[TYPE_PIXELVISHANDLE] = "pixelvis_handle_t"
    types[TYPE_RECIPIENTFILTER] = "CRecipientFilter"
    types[TYPE_SOUNDHANDLE] = "IGModAudioChannel"
    types[TYPE_LIGHTUSERDATA] = "light userdata"
    types[TYPE_PARTICLEEMITTER] = "CLuaEmitter"
    types[TYPE_DAMAGEINFO] = "CTakeDamageInfo"
    types[TYPE_LOCOMOTION] = "CLuaLocomotion"
    types[TYPE_SURFACEINFO] = "SurfaceInfo"
    types[TYPE_PHYSCOLLIDE] = "PhysCollide"
    types[TYPE_EFFECTDATA] = "CEffectData"
    types[TYPE_PARTICLE] = "CLuaParticle"
    types[TYPE_NAVLADDER] = "CNavLadder"
    types[TYPE_VIDEO] = "IVideoWriter"
    types[TYPE_MATERIAL] = "IMaterial"
    types[TYPE_MOVEDATA] = "CMoveData"
    types[TYPE_PATH] = "PathFollower"
    types[TYPE_SOUND] = "CSoundPatch"
    types[TYPE_USERDATA] = "userdata"
    types[TYPE_FUNCTION] = "function"
    types[TYPE_TEXTURE] = "ITexture"
    types[TYPE_USERCMD] = "CUserCmd"
    types[TYPE_RESTORE] = "IRestore"
    types[TYPE_NAVAREA] = "CNavArea"
    types[TYPE_PHYSOBJ] = "PhysObj"
    types[TYPE_DLIGHT] = "dlight_t"
    types[TYPE_USERMSG] = "bf_read"
    types[TYPE_MATRIX] = "VMatrix"
    types[TYPE_CONVAR] = "ConVar"
    types[TYPE_VECTOR] = "Vector"
    types[TYPE_ENTITY] = "Entity"
    types[TYPE_THREAD] = "thread"
    types[TYPE_STRING] = "string"
    types[TYPE_NUMBER] = "number"
    types[TYPE_NONE] = "unknown"
    types[TYPE_BOOL] = "boolean"
    types[TYPE_IMESH] = "IMesh"
    types[TYPE_PANEL] = "Panel"
    types[TYPE_ANGLE] = "Angle"
    types[TYPE_COLOR] = "Color"
    types[TYPE_TABLE] = "table"
    types[TYPE_SAVE] = "ISave"
    types[TYPE_FILE] = "File"
    types[TYPE_NIL] = "nil"

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
    if not number then return "unknown" end
    if gpm.type( number ) == "string" then return number end
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

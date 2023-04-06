-- Libraries
local string = string
local debug = debug
local table = table
local file = file
local gpm = gpm

-- Variables
local tonumber = tonumber
local module = module
local ipairs = ipairs
local pairs = pairs

-- https://wiki.facepunch.com/gmod/Global.TypeID
do

    local TYPE_COLOR = TYPE_COLOR
    local IsColor = IsColor
    local TypeID = TypeID

    function gpm.TypeID( any )
        if IsColor( any ) then return TYPE_COLOR end
        return TypeID( any )
    end

end

-- https://wiki.facepunch.com/gmod/Global.type
do

    local TYPE_NONE = TYPE_NONE
    local list = list

    -- https://wiki.facepunch.com/gmod/Enums/TYPE
    list.Set( "GPM - Variable Types", TYPE_PARTICLESYSTEM, "CNewParticleEffect" )
    list.Set( "GPM - Variable Types", TYPE_PROJECTEDTEXTURE, "ProjectedTexture" )
    list.Set( "GPM - Variable Types", TYPE_PIXELVISHANDLE, "pixelvis_handle_t" )
    list.Set( "GPM - Variable Types", TYPE_RECIPIENTFILTER, "CRecipientFilter" )
    list.Set( "GPM - Variable Types", TYPE_SOUNDHANDLE, "IGModAudioChannel" )
    list.Set( "GPM - Variable Types", TYPE_LIGHTUSERDATA, "light userdata" )
    list.Set( "GPM - Variable Types", TYPE_PARTICLEEMITTER, "CLuaEmitter" )
    list.Set( "GPM - Variable Types", TYPE_DAMAGEINFO, "CTakeDamageInfo" )
    list.Set( "GPM - Variable Types", TYPE_LOCOMOTION, "CLuaLocomotion" )
    list.Set( "GPM - Variable Types", TYPE_SURFACEINFO, "SurfaceInfo" )
    list.Set( "GPM - Variable Types", TYPE_PHYSCOLLIDE, "PhysCollide" )
    list.Set( "GPM - Variable Types", TYPE_EFFECTDATA, "CEffectData" )
    list.Set( "GPM - Variable Types", TYPE_PARTICLE, "CLuaParticle" )
    list.Set( "GPM - Variable Types", TYPE_NAVLADDER, "CNavLadder" )
    list.Set( "GPM - Variable Types", TYPE_VIDEO, "IVideoWriter" )
    list.Set( "GPM - Variable Types", TYPE_MATERIAL, "IMaterial" )
    list.Set( "GPM - Variable Types", TYPE_MOVEDATA, "CMoveData" )
    list.Set( "GPM - Variable Types", TYPE_PATH, "PathFollower" )
    list.Set( "GPM - Variable Types", TYPE_SOUND, "CSoundPatch" )
    list.Set( "GPM - Variable Types", TYPE_USERDATA, "userdata" )
    list.Set( "GPM - Variable Types", TYPE_FUNCTION, "function" )
    list.Set( "GPM - Variable Types", TYPE_TEXTURE, "ITexture" )
    list.Set( "GPM - Variable Types", TYPE_USERCMD, "CUserCmd" )
    list.Set( "GPM - Variable Types", TYPE_RESTORE, "IRestore" )
    list.Set( "GPM - Variable Types", TYPE_NAVAREA, "CNavArea" )
    list.Set( "GPM - Variable Types", TYPE_PHYSOBJ, "PhysObj" )
    list.Set( "GPM - Variable Types", TYPE_DLIGHT, "dlight_t" )
    list.Set( "GPM - Variable Types", TYPE_USERMSG, "bf_read" )
    list.Set( "GPM - Variable Types", TYPE_MATRIX, "VMatrix" )
    list.Set( "GPM - Variable Types", TYPE_CONVAR, "ConVar" )
    list.Set( "GPM - Variable Types", TYPE_VECTOR, "Vector" )
    list.Set( "GPM - Variable Types", TYPE_ENTITY, "Entity" )
    list.Set( "GPM - Variable Types", TYPE_THREAD, "thread" )
    list.Set( "GPM - Variable Types", TYPE_STRING, "string" )
    list.Set( "GPM - Variable Types", TYPE_NUMBER, "number" )
    list.Set( "GPM - Variable Types", TYPE_NONE, "unknown" )
    list.Set( "GPM - Variable Types", TYPE_BOOL, "boolean" )
    list.Set( "GPM - Variable Types", TYPE_IMESH, "IMesh" )
    list.Set( "GPM - Variable Types", TYPE_PANEL, "Panel" )
    list.Set( "GPM - Variable Types", TYPE_ANGLE, "Angle" )
    list.Set( "GPM - Variable Types", TYPE_COLOR, "Color" )
    list.Set( "GPM - Variable Types", TYPE_TABLE, "table" )
    list.Set( "GPM - Variable Types", TYPE_SAVE, "ISave" )
    list.Set( "GPM - Variable Types", TYPE_FILE, "File" )
    list.Set( "GPM - Variable Types", TYPE_NIL, "nil" )

    local types = list.Get( "GPM - Variable Types" )

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

-- util.NextTick( func, ... )
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

--
function table.GetValue( source, path )
    ArgAssert( source, 1, "table" )

    local levels = string.Split( path, "." )
    local count = #levels
    local tbl = source

    for num, key in ipairs( levels ) do
        if ( num == count ) then
            return tbl[ key ]
        end

        local nextTable = tbl[ key ]
        if gpm.type( nextTable ) ~= "table" then
            return
        end

        tbl = tbl[ key ]
    end
end

function table.SetValue( source, path, value, ifEmpty )
    ArgAssert( source, 1, "table" )

    local levels = string.Split( path, "." )
    local count = #levels
    local tbl = source

    for num, key in ipairs( levels ) do
        if ( num == count ) then
            local oldValue = tbl[ key ]
            if ( oldValue ~= nil and ifEmpty ) then
                return oldValue
            end

            tbl[ key ] = value
            return value
        end

        local nextTable = tbl[ key ]
        if ( nextTable == nil ) then
            tbl[ key ] = {}
        elseif gpm.type( nextTable ) ~= "table" then
            return
        end

        tbl = tbl[ key ]
    end

    return
end

module( "gpm.utils" )

function CreateFolder( folderPath )
    local currentPath = nil
    for _, folderName in ipairs( string.Split( folderPath, "/" ) ) do
        if currentPath == nil then
            currentPath = folderName
        else
            currentPath = currentPath .. "/" .. folderName
        end

        if not file.IsDir( currentPath, "DATA" ) then
            file.Delete( currentPath )
            file.CreateDir( currentPath )
        end
    end

end

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
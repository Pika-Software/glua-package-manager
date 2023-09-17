local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local type = type
local gpm = gpm
local _G = _G

local types = gpm.Types
if type( types ) ~= "table" then
    types = {
        -- https://wiki.facepunch.com/gmod/Enums/TYPE
        ["Names"] = {
            [TYPE_PARTICLESYSTEM] = "CNewParticleEffect",
            [TYPE_PROJECTEDTEXTURE] = "ProjectedTexture",
            [TYPE_PIXELVISHANDLE] = "pixelvis_handle_t",
            [TYPE_RECIPIENTFILTER] = "CRecipientFilter",
            [TYPE_SOUNDHANDLE] = "IGModAudioChannel",
            [TYPE_LIGHTUSERDATA] = "light userdata",
            [TYPE_PARTICLEEMITTER] = "CLuaEmitter",
            [TYPE_DAMAGEINFO] = "CTakeDamageInfo",
            [TYPE_LOCOMOTION] = "CLuaLocomotion",
            [TYPE_SURFACEINFO] = "SurfaceInfo",
            [TYPE_PHYSCOLLIDE] = "PhysCollide",
            [TYPE_EFFECTDATA] = "CEffectData",
            [TYPE_PARTICLE] = "CLuaParticle",
            [TYPE_NAVLADDER] = "CNavLadder",
            [TYPE_VIDEO] = "IVideoWriter",
            [TYPE_MATERIAL] = "IMaterial",
            [TYPE_MOVEDATA] = "CMoveData",
            [TYPE_PATH] = "PathFollower",
            [TYPE_SOUND] = "CSoundPatch",
            [TYPE_USERDATA] = "userdata",
            [TYPE_FUNCTION] = "function",
            [TYPE_TEXTURE] = "ITexture",
            [TYPE_USERCMD] = "CUserCmd",
            [TYPE_RESTORE] = "IRestore",
            [TYPE_NAVAREA] = "CNavArea",
            [TYPE_PHYSOBJ] = "PhysObj",
            [TYPE_DLIGHT] = "dlight_t",
            [TYPE_USERMSG] = "bf_read",
            [TYPE_MATRIX] = "VMatrix",
            [TYPE_CONVAR] = "ConVar",
            [TYPE_VECTOR] = "Vector",
            [TYPE_ENTITY] = "Entity",
            [TYPE_THREAD] = "thread",
            [TYPE_STRING] = "string",
            [TYPE_NUMBER] = "number",
            [TYPE_NONE] = "unknown",
            [TYPE_BOOL] = "boolean",
            [TYPE_IMESH] = "IMesh",
            [TYPE_PANEL] = "Panel",
            [TYPE_ANGLE] = "Angle",
            [TYPE_COLOR] = "Color",
            [TYPE_TABLE] = "table",
            [TYPE_SAVE] = "ISave",
            [TYPE_FILE] = "File",
            [TYPE_NIL] = "nil"
        },
        ["IDs"] = {}
    }

    gpm.Types = types
end

do

    local gpm_TypeID = gpm.TypeID
    local typeNames = types.Names

    function gpm.type( any )
        return typeNames[ gpm_TypeID( any ) ] or "unknown"
    end

end

do

    local typeIDs = types.IDs
    local TypeID = TypeID

    function gpm.TypeID( any )
        for _, tbl in ipairs( typeIDs ) do
            if tbl[ 1 ]( any ) then
                return tbl[ 2 ]
            end
        end

        return TypeID( any )
    end

end

local string = gpm.string
if type( string ) ~= "table" then
    string = setmetatable( {}, { __index = _G.string } )
    gpm.string = string
end

string.StartsWith = string.StartsWith or string.StartWith

function string.IsURL( str )
    return string.match( str, "^https?://.+$" ) ~= nil
end

local string_format = string.format
local string_lower = string.lower
local string_sub = string.sub

local debug = gpm.debug
if type( debug ) ~= "table" then
    debug = setmetatable( {}, { __index = _G.debug } )
    gpm.debug = debug
end

function debug.fempty()
end

function debug.fcall( func )
    return func()
end

local debug_getinfo = debug.getinfo

do

    local gpm_type = gpm.type
    local error = error

    function gpm.ArgAssert( value, argNum, expected, errorlevel )
        local valueType, expectedType = gpm_type( value ), gpm_type( expected )
        if expectedType == "table" then
            local str, len = "[ ", #expected
            for index, typeName in ipairs( expected ) do
                if valueType == typeName then return value end
                if index ~= len then continue end
                str = str .. typeName .. ", "
            end

            expected = str .. " ]"
        elseif expectedType == "function" then
            expected = expected( value, argNum )
            if type( expected ) ~= "string" then
                return value
            end
        elseif valueType == expected then
            return value
        end

        local dinfo = debug_getinfo( 2, "n" )
        error( string_format( "bad argument #%d to \'%s\' (%s expected, got %s)", argNum, dinfo and dinfo.name or "func", expected, valueType ), errorlevel or 3 )
    end

end

local table = gpm.table
if type( table ) ~= "table" then
    table = setmetatable( {}, { __index = _G.table } )
    gpm.table = table
end

function table.HasIValue( tbl, any )
    for _, value in ipairs( tbl ) do
        if value == any then
            return true
        end
    end

    return false
end

local table_remove = table.remove

function table.RemoveByIValue( tbl, any )
    for index, value in ipairs( tbl ) do
        if value ~= any then continue end
        return table_remove( tbl, index )
    end
end

local string_Split = string.Split

function table.Lookup( tbl, str, default )
    for _, key in ipairs( string_Split( str, "." ) ) do
        tbl = tbl[ key ]
        if not tbl then return default end
    end

    return tbl
end

function table.SetValue( tbl, str, value, ifEmpty )
    local keys = string_Split( str, "." )
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
        elseif type( nextValue ) ~= "table" then
            return
        end

        tbl = tbl[ key ]
    end
end

function table.Lower( tbl )
    for key, value in pairs( tbl ) do
        if type( value ) == "table" then
            value = table.Lower( value )
        end

        local keyType = type( key )
        if keyType == "string" then
            tbl[ key ] = nil; tbl[ string_lower( key ) ] = value
        elseif keyType == "table" then
            tbl[ key ] = nil; tbl[ table.Lower( key ) ] = value
        end
    end

    return tbl
end

if SERVER then
    AddCSLuaFile( "libs/metaworks.lua" )
end

local metaworks = include( "libs/metaworks.lua" )
gpm.metaworks = metaworks

local gpm_ArgAssert = gpm.ArgAssert

do

    local typeNames = types.Names
    local typeIDs = types.IDs

    function gpm.AddType( typeName, func )
        gpm_ArgAssert( typeName, 1, "string" )
        gpm_ArgAssert( func, 2, "function" )

        local index = 256
        for key, name in pairs( typeNames ) do
            if typeName == name then
                index = key
                break
            elseif key >= index then
                index = key + 1
            end
        end

        typeNames[ index ] = typeName

        for index2, data in ipairs( typeIDs ) do
            if index ~= data[ 2 ] then continue end
            table_remove( typeIDs, index2 )
            break
        end

        typeIDs[ #typeIDs + 1 ] = { func, index }
        return index
    end

end

local getmetatable = getmetatable

do

    local Color = FindMetaTable( "Color" )

    local function gpm_IsColor( any )
        if getmetatable( any ) == Color then
            return true
        end

        if type( any ) == "table" then
            return type( any.r ) == "number" and type( any.g ) == "number" and type( any.b ) == "number"
        end

        return false
    end

    gpm.AddType( "Color", gpm_IsColor )
    gpm.IsColor = gpm_IsColor

end

local paths = gpm.paths
if type( paths ) ~= "table" then
    paths = {}; gpm.paths = paths
end

local string_gsub = string.gsub

local function paths_Fix( filePath )
    return string_lower( string_gsub( filePath, "[/\\]+", "/" ) )
end

paths.Fix = paths_Fix

function paths.Join( ... )
    local args, filePath = { ... }
    local len = #args
    for i = 1, len do
        if filePath ~= nil then
            filePath = filePath .. args[ i ]
        else
            filePath = args[ i ]
        end

        if i == len then
            return paths_Fix( filePath )
        end

        filePath = filePath .. "/"
    end
end

local function paths_Localize( filePath )
    filePath = string_gsub( filePath, "^cache/moonloader/", "" )
    filePath = string_gsub( filePath, "^addons/[%w%-_]-/", "" )
    filePath = string_gsub( filePath, "^lua/", "" )
    return filePath
end

paths.Localize = paths_Localize

do
    local string_GetExtensionFromFilename = string.GetExtensionFromFilename
    function paths.FormatToLua( filePath )
        local extension = string_GetExtensionFromFilename( filePath )
        if extension ~= "lua" then
            if extension then
                filePath = string_gsub( filePath, "%..+$", ".lua" )
            else
                filePath = filePath .. ".lua"
            end
        end

        return filePath
    end
end

do

    local util = gpm.util
    if type( util ) ~= "table" then
        util = metaworks.CreateLink( _G.util, true )
        gpm.util = util
    end

    local tonumber = tonumber

    function util.Version( number )
        if not number then return "unknown" end
        if type( number ) == "string" then return number end

        local version = string_format( "%06d", number )
        return string_format( "%d.%d.%d", tonumber( string_sub( version, 0, 2 ) ), tonumber( string_sub( version, 3, 4 ) ), tonumber( string_sub( version, 5 ) ) )
    end

    function util.GetCurrentFilePath()
        for i = 2, 6 do
            local info = debug_getinfo( i, "S" )
            if not info then break end
            if info.what ~= "main" then continue end
            return paths_Localize( paths_Fix( info.short_src ) )
        end
    end

    do
        local timer_Simple = timer.Simple
        function util.NextTick( func, a, b, c, d )
            gpm_ArgAssert( func, 1, "function" )
            timer_Simple( 0, function()
                func( a, b, c, d )
            end )
        end
    end

    local file_Exists = file.Exists

    function util.IsLuaModuleInstalled( name )
        return file_Exists( "includes/modules/" .. name .. ".lua", "LUA" )
    end

    local jit_versionnum = jit.versionnum
    local jit_arch = jit.arch

    local isWindows = system.IsWindows()
    local isLinux = system.IsLinux()

    local suffix = ( { "osx64", "osx", "linux64", "linux", "win64", "win32" } )[ ( isWindows and 4 or 0 ) + ( isLinux and 2 or 0 ) + ( jit_arch == "x86" and 1 or 0 ) + 1 ]
    local fmt = "lua/bin/gm" .. ( ( CLIENT and not MENU_DLL ) and "cl" or "sv" ) .. "_%s_%s.dll"

    function util.IsBinaryModuleInstalled( name )
        gpm_ArgAssert( name, 1, "string" )

        if file_Exists( string_format( fmt, name, suffix ), "GAME" ) then
            return true
        end

        if jit_versionnum ~= 20004 and jit_arch == "x86" and isLinux then
            return file_Exists( string_format( fmt, name, "linux32" ), "GAME" )
        end

        return false
    end

end

do

    local File = FindMetaTable( "File" )

    function File:SkipEmpty()
        while not self:EndOfFile() do
            if self:ReadByte() ~= 0 then
                self:Skip( -1 )
                break
            end
        end
    end

    function File:ReadString()
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

    function File:WriteString( str )
        self:Write( str )
        self:WriteByte( 0 )
    end

end

do

    local Logger = gpm.LOGGER
    if type( Logger ) ~= "table" then
        Logger = {}; gpm.LOGGER = Logger
    end

    Logger.__index = Logger

    function Logger:__tostring()
        return "Logger [" .. Logger.GetName( self ) .. "]"
    end

    function Logger:GetName()
        return self.Name or "unknown"
    end

    function Logger:SetName( str )
        gpm_ArgAssert( str, 1, "string" )
        self.Name = str
    end

    function Logger:GetColor()
        return self.Color
    end

    function Logger:SetColor( color )
        gpm_ArgAssert( color, 1, "Color" )
        self.Color = color
    end

    function Logger:GetTextColor()
        return self.TextColor
    end

    function Logger:SetTextColor( color )
        gpm_ArgAssert( color, 1, "Color" )
        self.TextColor = color
    end

    function Logger:GetDebugFilter()
        return self.DebugFilter
    end

    function Logger:SetDebugFilter( func )
        gpm_ArgAssert( func, 1, "function" )
        self.DebugFilter = func
    end

    local colors = gpm.Colors
    local primaryTextColor = colors.PrimaryText
    local secondaryTextColor = colors.SecondaryText

    do

        local stateName, stateColor = string.upper( gpm.State ), colors.State
        local os_date = os.date
        local select = select
        local MsgC = MsgC

        function Logger:Log( color, level, str, ... )
            gpm_ArgAssert( color, 1, "Color" )
            gpm_ArgAssert( level, 2, "string" )

            if select( "#", ... ) > 0 then
                str = string_format( str, ... )
            end

            MsgC( secondaryTextColor, os_date( "%d/%m/%Y %H:%M:%S " ), color, level, secondaryTextColor, " --- ", stateColor, "[" .. stateName .. "] ", self.Color, self.Name, secondaryTextColor, " : ", self.TextColor, str, "\n"  )
        end

    end

    do
        local infoColor = colors.Info
        function Logger:Info( str, ... )
            Logger.Log( self, infoColor, " INFO", str, ... )
        end
    end

    do
        local warnColor = colors.Warn
        function Logger:Warn( str, ... )
            Logger.Log( self, warnColor, " WARN", str, ... )
        end
    end

    do
        local errorColor = colors.Error
        function Logger:Error( str, ... )
            Logger.Log( self, errorColor, "ERROR", str, ... )
        end
    end

    do
        local debugColor = colors.Debug
        function Logger:Debug( str, ... )
            if not self:DebugFilter( str, ... ) then return end
            Logger.Log( self, debugColor, "DEBUG", str, ... )
        end
    end

    local function debugFilter()
        return gpm.Developer > 0
    end

    local gpm_IsColor = gpm.IsColor
    local whiteColor = colors.White

    local function createLogger( name, color )
        gpm_ArgAssert( name, 1, "string" )
        return setmetatable( {
            ["Color"] = gpm_IsColor( color ) and color or whiteColor,
            ["TextColor"] = primaryTextColor,
            ["DebugFilter"] = debugFilter,
            ["Name"] = name
        }, Logger )
    end

    Logger.__call = createLogger
    gpm.Logger = createLogger( "gpm@" .. gpm.VERSION, colors.gpm )

    local function gpm_IsLogger( any )
        return getmetatable( any ) == Logger
    end

    gpm.IsLogger = gpm_IsLogger
    gpm.AddType( "Logger", gpm_IsLogger )

end
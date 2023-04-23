local setmetatable = setmetatable
local ArgAssert = ArgAssert
local Color = Color

-- Metatable
local meta = {}
meta.__index = meta

function meta:__tostring()
    return "Logger [" .. self:GetName() .. "]"
end

do

    local getmetatable = getmetatable
    function IsLogger( any )
        return getmetatable( any ) == meta
    end

    TYPE_LOGGER = 257

    list.Set( "GPM - Type Names", TYPE_LOGGER, "Logger" )
    gpm.SetTypeID( TYPE_LOGGER, IsLogger )

end

-- Logs name
function meta:GetName()
    return self.Name
end

function meta:SetName( str )
    ArgAssert( str, 1, "string" )
    self.Name = str
end

-- Logs name color
function meta:GetColor()
    return self.Color
end

function meta:SetColor( color )
    ArgAssert( color, 1, "Color" )
    self.Color = color
end

-- Logs basic text colot
function meta:GetTextColor()
    return self.TextColor
end

function meta:SetTextColor( color )
    ArgAssert( color, 1, "Color" )
    self.TextColor = color
end

-- Debug options
function meta:GetDebugFilter()
    return self.DebugFilter
end

function meta:SetDebugFilter( func )
    ArgAssert( func, 1, "function" )
    self.DebugFilter = func
end

-- Console log
do

    local dateColor = Color( 150, 150, 150 )
    local realmColor = nil

    if SERVER then
        realmColor = Color( 5, 170, 250 )
    elseif MENU_DLL then
        realmColor = Color( 75, 175, 80 )
    else
        realmColor = Color( 225, 170, 10 )
    end

    local os_time = os.time
    local os_date = os.date
    local MsgC = MsgC

    function meta:Log( levelColor, level, str, ... )
        ArgAssert( levelColor, 1, "Color" )
        ArgAssert( level, 2, "string" )

        MsgC( dateColor, os_date( "%d/%m/%Y %H:%M:%S ", os_time() ), levelColor, level, dateColor, " --- ", realmColor, "[" .. (SERVER and "SERVER" or "CLIENT") .. "] ", self.Color, self.Name, dateColor, " : ", self.TextColor, string.format( str, ... ), "\n"  )
    end

end

local convar = GetConVar( "developer" )
local function debugFilter()
    return convar:GetInt() > 0
end

module( "gpm.logger" )

LOGGER = meta

INFO_COLOR = Color( 70, 135, 255 )
WARN_COLOR = Color( 255, 130, 90 )
ERROR_COLOR = Color( 250, 55, 40 )
DEBUG_COLOR = Color( 0, 200, 150 )
TEXT_COLOR = Color( 200, 200, 200 )
WHITE_COLOR = Color( 255, 255, 255 )

-- Info log
function meta:Info( str, ... )
    self:Log( INFO_COLOR, " INFO", str, ... )
end

-- Warn log
function meta:Warn( str, ... )
    self:Log( WARN_COLOR, " WARN", str, ... )
end

-- Error log
function meta:Error( str, ... )
    self:Log( ERROR_COLOR, "ERROR", str, ... )
end

-- Debug log
function meta:Debug( str, ... )
    if not self:DebugFilter( str, ... ) then return end
    self:Log( DEBUG_COLOR, "DEBUG", str, ... )
end

function Create( name, color )
    ArgAssert( name, 1, "string" )
    return setmetatable( {
        ["DebugFilter"] = debugFilter,
        ["Color"] = color or WHITE_COLOR,
        ["TextColor"] = TEXT_COLOR,
        ["Name"] = name
    }, meta )
end
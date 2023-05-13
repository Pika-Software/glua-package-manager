local setmetatable = setmetatable
local ArgAssert = gpm.ArgAssert
local colors = gpm.Colors

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

    TYPE_LOGGER = gpm.AddType( "Logger", IsLogger )

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

    local os_time = os.time
    local os_date = os.date
    local MsgC = MsgC

    function meta:Log( levelColor, level, str, ... )
        ArgAssert( levelColor, 1, "Color" )
        ArgAssert( level, 2, "string" )

        MsgC( colors.SecondaryText, os_date( "%d/%m/%Y %H:%M:%S ", os_time() ), levelColor, level, colors.SecondaryText, " --- ", colors.Realm, "[" .. (SERVER and "SERVER" or "CLIENT") .. "] ", self.Color, self.Name, colors.SecondaryText, " : ", self.TextColor, string.format( str, ... ), "\n"  )
    end

end

local convar = GetConVar( "developer" )
local function debugFilter()
    return convar:GetInt() > 0
end

module( "gpm.logger" )

-- Metatable
LOGGER = meta

-- Info log
function meta:Info( str, ... )
    self:Log( colors.Info, " INFO", str, ... )
end

-- Warn log
function meta:Warn( str, ... )
    self:Log( colors.Warn, " WARN", str, ... )
end

-- Error log
function meta:Error( str, ... )
    self:Log( colors.Error, "ERROR", str, ... )
end

-- Debug log
function meta:Debug( str, ... )
    if not self:DebugFilter( str, ... ) then return end
    self:Log( colors.Debug, "DEBUG", str, ... )
end

function Create( name, color )
    ArgAssert( name, 1, "string" )
    return setmetatable( {
        ["DebugFilter"] = debugFilter,
        ["Color"] = color or colors.White,
        ["TextColor"] = colors.PrimaryText,
        ["Name"] = name
    }, meta )
end
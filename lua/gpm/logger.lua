
-- Metatable
local meta = gpm.LoggerMeta
if type( meta ) ~= "table" then
    meta = {}
    gpm.LoggerMeta = meta
end

meta.__index = meta

do

    local getmetatable = getmetatable

    local function isLogger( any )
        return getmetatable( any ) == meta
    end

    TYPE_LOGGER = gpm.AddType( "Logger", isLogger )
    gpm.IsLogger = isLogger

end

function meta:__tostring()
    return "Logger [" .. self:GetName() .. "]"
end

local ArgAssert = gpm.ArgAssert

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

local colors = gpm.Colors

-- Console log
do

    local realm = string.upper( gpm.Realm )
    local string_format = string.format
    local os_date = os.date
    local select = select
    local MsgC = MsgC

    function meta:Log( color, level, str, ... )
        ArgAssert( color, 1, "Color" )
        ArgAssert( level, 2, "string" )

        if select( "#", ... ) > 0 then
            str = string_format( str, ... )
        end

        MsgC( colors.SecondaryText, os_date( "%d/%m/%Y %H:%M:%S " ), color, level, colors.SecondaryText, " --- ", colors.Realm, "[" .. realm .. "] ", self.Color, self.Name, colors.SecondaryText, " : ", self.TextColor, str, "\n"  )
    end

end

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

-- Default debug filter
local developer = GetConVar( "developer" )
local function debugFilter()
    return developer:GetInt() > 0
end

local setmetatable = setmetatable

function gpm.CreateLogger( name, color )
    ArgAssert( name, 1, "string" )
    return setmetatable( {
        ["DebugFilter"] = debugFilter,
        ["Color"] = color or colors.White,
        ["TextColor"] = colors.PrimaryText,
        ["Name"] = name
    }, meta )
end

local ArgAssert = ArgAssert
local colors = gpm.colors

-- Default Colors
colors.Set( 'info', Color( 70, 135, 255 ) )
colors.Set( 'warn', Color( 255, 130, 90 ) )
colors.Set( 'error', Color( 250, 55, 40 ) )
colors.Set( 'debug', Color( 0, 200, 150 ) )

-- Metatable
local meta = {}
meta.__index = meta

-- Logs name
function meta:GetName()
    return self.Name
end

function meta:SetName( str )
    ArgAssert( str, 1, 'string' )
    self.Name = str
end

-- Logs name color
function meta:GetColor()
    return self.Color
end

function meta:SetColor( color )
    ArgAssert( color, 1, 'table' )
    self.Color = color
end

-- Logs basic text colot
function meta:GetTextColor()
    return self.TextColor
end

function meta:SetTextColor( color )
    ArgAssert( color, 1, 'table' )
    self.TextColor = color
end

-- Debug options
function meta:GetDebugFilter()
    return self.DebugFilter
end

function meta:SetDebugFilter( func )
    ArgAssert( func, 1, 'function' )
    self.DebugFilter = func
end

-- Console log
do

    local sideColor = colors.Get( SERVER and 'server' or 'client' )
    local color1 = colors.Get( '150' )
    local color2 = colors.Get( '200' )
    local os_time = os.time
    local os_date = os.date
    local MsgC = MsgC

    function meta:Log( levelColor, level, str, ... )
        ArgAssert( levelColor, 1, 'table' )
        ArgAssert( level, 2, 'string' )

        MsgC( color1, os_date( '%d/%m/%Y %H:%M:%S ', os_time() ), levelColor, level, color1, ' --- ', sideColor, '[' .. (SERVER and 'SERVER' or 'CLIENT') .. '] ', self:GetColor(), self:GetName(), color1, ' : ', color2, string.format( str, ... ), '\n'  )
    end

end

-- Info log
do
    local color = colors.Get( 'info' )
    function meta:Info( str, ... )
        self:Log( color, ' INFO', str, ... )
    end
end

-- Warn log
do
    local color = colors.Get( 'warn' )
    function meta:Warn( str, ... )
        self:Log( color, ' WARN', str, ... )
    end
end

-- Error log
do
    local color = colors.Get( 'error' )
    function meta:Error( str, ... )
        self:Log( color, 'ERROR', str, ... )
    end
end

-- Debug log
do

    local convar = GetConVar( 'developer' )
    local color = colors.Get( 'debug' )

    function meta:Debug( str, ... )
        if (convar:GetInt() > 1) then
            self:Log( color, 'DEBUG', str, ... )
        end
    end

end

local white = colors.White
function gpm.Logger( name, color )
    ArgAssert( name, 1, 'string' )
    return setmetatable({
        ['Color'] = color or white,
        ['Name'] = name
    }, meta)
end
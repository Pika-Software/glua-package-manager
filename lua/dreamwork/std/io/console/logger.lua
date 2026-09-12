local engine                       = dreamwork.engine
local engine_consoleMessageColored = engine.consoleMessageColored


local std           = dreamwork.std

local raw           = std.raw
local raw_select    = raw.select
local raw_tostring  = raw.tostring

local color_scheme  = std.color.Scheme
local realm_color   = color_scheme.realm

local time          = std.time
local time_format   = time.format

local string        = std.string
local string_gsub   = string.gsub
local string_format = string.format

local class         = std.class


local represent = std.represent

local realm_text = ({
    menu = string.bytePad( "[ Menu ]", 11, 0x20, false, true ),
    client = string.bytePad( "[ Client ]", 11, 0x20, false, true ),
    server = string.bytePad( "[ Server ]", 11, 0x20, false, true ),
    unknown = string.bytePad( "[ N/A ]", 11, 0x20, false, true ),
})[ std.LUA_REALM ]

---@class dreamwork.std.console
local console = std.console

--- [SHARED AND MENU]
---
--- The logger object.
---
---@alias Logger dreamwork.std.console.Logger
---@class dreamwork.std.console.Logger : dreamwork.std.Object
---@field __class dreamwork.std.console.LoggerClass
---@field title string The logger title.
---@field title_color dreamwork.std.Color The logger title color.
---@field text_color dreamwork.std.Color The logger text color.
---@field interpolation boolean The logger interpolation.
---@field debug_fn fun( dreamwork.std.console.Logger ): boolean The logger debug function.
local Logger = class.base( "console.Logger" )

--- [SHARED AND MENU]
---
--- The logger class.
---
---@class dreamwork.std.console.LoggerClass : dreamwork.std.console.Logger
---@field __base dreamwork.std.console.Logger
---@overload fun( options: dreamwork.std.console.Logger.Options? ) : dreamwork.std.console.Logger
console.Logger = class.create( Logger )

local developer_cvar = console.Variable.get( "developer", "number" )
local default_debug_fn

if developer_cvar == nil then

    function default_debug_fn()
        return true
    end

else

    function default_debug_fn()
        return developer_cvar.value ~= 0
    end

end

local white_color = color_scheme.white
local primary_text_color = color_scheme.light_gray
local secondary_text_color = color_scheme.dark_gray

---@protected
function Logger:__init( options )
    if options == nil then
        self.title = "unknown"
        self.title_color = white_color
        self.text_color = primary_text_color
        self.interpolation = true
        self.debug_fn = default_debug_fn
        return
    end

    local title = options.title
    if title == nil then
        self.title = "unknown"
    else
        self.title = title
    end

    local color = options.color
    if color == nil then
        self.title_color = 0xFFFFFF
    else
        self.title_color = color
    end

    local text_color = options.text_color
    if text_color == nil then
        self.text_color = primary_text_color
    else
        self.text_color = text_color
    end

    self.interpolation = options.interpolation == true

    local debug_fn = options.debug
    if debug_fn == nil then
        self.debug_fn = default_debug_fn
    else
        self.debug_fn = debug_fn
    end
end

--- [SHARED AND MENU]
---
--- Logs a message.
---@param color dreamwork.std.Color The log level color.
---@param level string The log level name.
---@param fmt string The log message.
---@param ... any The log message arguments to format/interpolate.
local function write_log( object, color, level, fmt, ... )
    engine_consoleMessageColored( time_format( "{day}-{month}-{year} {hours}:{minutes}:{seconds}.{milliseconds} " ), secondary_text_color )
    engine_consoleMessageColored( realm_text, realm_color )
    engine_consoleMessageColored( level, color )
    engine_consoleMessageColored( " --> ", secondary_text_color )
    engine_consoleMessageColored( object.title, object.title_color )
    engine_consoleMessageColored( " : ", secondary_text_color )

    if object.interpolation then
        local args = {}

        for i = 1, raw_select( "#", ... ), 1 do
            args[ raw_tostring( i ) ] = represent( raw_select( i, ... ) )
        end

        engine_consoleMessageColored( string_gsub( fmt, "{([0-9]+)}", args ) .. "\n", object.text_color )
        return
    end

    engine_consoleMessageColored( string_format( fmt, ... ) .. "\n", object.text_color )
end

Logger.log = write_log

do

    local info_color = color_scheme.dreamwork_info

    --- [SHARED AND MENU]
    ---
    --- Logs an info message.
    ---
    function Logger:info( ... )
        return write_log( self, info_color, "INFO ", ... )
    end

end

do

    local warn_color = color_scheme.dreamwork_warn

    --- [SHARED AND MENU]
    ---
    --- Logs a warning message.
    ---
    function Logger:warn( ... )
        return write_log( self, warn_color, "WARN ", ... )
    end

end

do

    local error_color = color_scheme.dreamwork_error

    --- [SHARED AND MENU]
    ---
    --- Logs an error message.
    ---
    function Logger:error( ... )
        return write_log( self, error_color, "ERROR", ... )
    end

end

do

    local debug_color = color_scheme.dreamwork_debug

    --- [SHARED AND MENU]
    ---
    --- Logs a debug message.
    ---
    function Logger:debug( ... )
        if self.debug_fn( self ) then
            return write_log( self, debug_color, "DEBUG", ... )
        end
    end

end

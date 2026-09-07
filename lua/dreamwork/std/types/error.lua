local engine = dreamwork.engine
local engine_consoleMessageColored = engine.consoleMessageColored

---@class dreamwork.std
local std = dreamwork.std

local debug = std.debug
local debug_Stack = debug.Stack

local string = std.string
local string_format = string.format

local utf8 = std.utf8

local color = std.color
local color_Scheme = color.Scheme

local class = std.class

local represent = std.represent
local tostring = std.tostring
local type = std.type
local is = std.is


local COLOR_WHITE_SMOKE = color_Scheme.white_smoke
local COLOR_SUVA_GRAY   = color_Scheme.suva_gray
local COLOR_SANDSTONE   = color_Scheme.sandstone
local COLOR_SPRAY       = color_Scheme.spray
local COLOR_MONA_LISA   = color_Scheme.mona_lisa
local COLOR_LIGHT_GRAY  = color_Scheme.light_gray
local COLOR_ERROR       = color_Scheme.error


--- [SHARED AND MENU]
---
--- The base error object used throughout `dreamwork`.
---
--- An `Error` wraps a `dreamwork.std.debug.Stack` of call frames captured
--- at (or before) the point the error was raised, and provides helpers to
--- turn that stack into a human-readable string (`toString`/`__tostring`)
--- or print it directly to the console with colors (`display`).
---
---@class dreamwork.std.Error : dreamwork.std.Object
---@field __class dreamwork.std.ErrorClass
---@field stack dreamwork.std.debug.Stack | nil The captured call stack this error carries.
---@field message string | nil The error message to display. Defaults to `"unknown error"` if omitted.
---@field protected __message fun( self: dreamwork.std.Error, error_message: ( string | nil ) ): string
---@field protected __head fun( self: dreamwork.std.Error, frame: ( dreamwork.std.debug.StackLevel | nil ) )
---@field protected __frame fun( self: dreamwork.std.Error, frame: dreamwork.std.debug.StackLevel )
---@field protected __tail fun( self: dreamwork.std.Error )
---@operator concat( any ): string
local Error = class.base( "Error", false, nil )

---@param message string | nil
---@protected
function Error:__init( message )
    self.message = message
end

---@return integer size
---@protected
function Error:__len()
    local stack = self.stack
    if stack == nil then
        return 0
    end

    return stack.size
end

---@return string
---@protected
function Error:__tostring()
    local error_message = self.message

    local message_fn = self.__message
    if message_fn ~= nil then
        return message_fn( self, error_message )
    elseif error_message == nil then
        return "unknown error"
    end

    return error_message
end

---@return string
---@protected
function Error:__concat( other )
    return tostring( self ) .. tostring( other )
end

--- [SHARED AND MENU]
---
--- Checks whether the error's stack has no captured frames.
---
---@return boolean is_empty Returns `true` if no frames have been captured, otherwise `false`.
function Error:isEmpty()
    local stack = self.stack
    if stack == nil then
        return true
    end

    return stack.size == 0
end

--- [SHARED AND MENU]
---
--- Removes all entries from the stack, leaving it empty.
---
function Error:reset()
    self.stack = nil
end

--- [SHARED AND MENU]
---
--- Captures the current call stack into this error, merging it into
--- whatever frames are already stored (see `dreamwork.std.debug.Stack:capture`).
---
---@param stack_level? integer  Levels to skip to reach the caller (same as before).
---@param head_skip? integer    Constant frames to drop from the innermost end (e.g. 1 for the bare `error` C frame).
---@param tail_skip? integer    Constant frames to drop from the outermost end (e.g. your xpcall/wrapper frames).
function Error:capture( stack_level, head_skip, tail_skip )
    if stack_level == nil then
        stack_level = 2
    else
        stack_level = stack_level + 1
    end

    local stack = self.stack
    if stack == nil then
        stack = debug_Stack()
        self.stack = stack
    end

    stack:capture( stack_level, head_skip, tail_skip )
end

do

    local realm_name = utf8.capitalize( std.LUA_REALM )

    --- [SHARED AND MENU]
    ---
    --- Prints the error and its captured call stack directly to the console
    --- using `engine.consoleMessageColored`, with colored segments for the
    --- realm, error type, message, source locations and function references.
    ---
    --- This is a display-only counterpart to `toString`: it writes straight to
    --- the console instead of building and returning a string.
    ---
    function Error:display()
        engine_consoleMessageColored( "\n[", COLOR_WHITE_SMOKE )
        engine_consoleMessageColored( realm_name, COLOR_ERROR )
        engine_consoleMessageColored( "/", COLOR_SUVA_GRAY )
        engine_consoleMessageColored( type( self ), COLOR_MONA_LISA )
        engine_consoleMessageColored( "] ", COLOR_WHITE_SMOKE )

        engine_consoleMessageColored( tostring( self ) .. "\n", COLOR_MONA_LISA )

        local stack = self.stack
        if stack == nil then
            local head_fn = self.__head
            if head_fn ~= nil then
                head_fn( self, nil )
            end

            return
        end

        local stack_size = stack.size

        local top_frame = stack:peek()
        if top_frame ~= nil then
            ---@type string | nil
            local file_path = top_frame.source

            ---@type function | nil
            local func = top_frame.func
            if func ~= nil and file_path == nil then
                file_path = debug.getfsource( func )
            end

            engine_consoleMessageColored( "  thrown at ", COLOR_SUVA_GRAY )
            engine_consoleMessageColored( file_path or "=[C]", COLOR_SANDSTONE )

            engine_consoleMessageColored( ":", COLOR_SUVA_GRAY )

            engine_consoleMessageColored( tostring( top_frame.currentline or -1 ), COLOR_SPRAY )
            engine_consoleMessageColored( "\n", COLOR_SUVA_GRAY )
        end

        local head_fn = self.__head
        if head_fn ~= nil then
            head_fn( self, top_frame )
        end

        if stack_size > 0 then
            engine_consoleMessageColored( "\n  call stack:\n", COLOR_SUVA_GRAY )
        end

        for index = 1, stack_size, 1 do
            engine_consoleMessageColored( "  " .. index, COLOR_SANDSTONE )

            ---@type dreamwork.std.debug.StackLevel
            local frame = stack[ (stack_size - index) + 1 ]

            ---@type string | nil
            local name = frame.name

            ---@type string | nil
            local file_path = frame.source

            ---@type function | nil
            local func = frame.func
            if func ~= nil then
                if name == nil then
                    name = debug.getfname( func )
                end

                if file_path == nil then
                    file_path = debug.getfsource( func )
                end
            end

            engine_consoleMessageColored( ". ", COLOR_SUVA_GRAY )

            if name == nil then
                engine_consoleMessageColored( "<unknown>", COLOR_LIGHT_GRAY )
            else
                engine_consoleMessageColored( name, COLOR_WHITE_SMOKE )
            end

            engine_consoleMessageColored( " [", COLOR_SUVA_GRAY )

            if func == nil then
                engine_consoleMessageColored( "=[C]", COLOR_SPRAY )
            else
                engine_consoleMessageColored( tostring( func ), COLOR_SPRAY )
            end

            engine_consoleMessageColored( "]:\n     file: ", COLOR_SUVA_GRAY )
            engine_consoleMessageColored( file_path or "=[C]", COLOR_SANDSTONE )

            engine_consoleMessageColored( ":", COLOR_SUVA_GRAY )
            engine_consoleMessageColored( tostring( frame.currentline or -1 ) .. "\n", COLOR_SPRAY )

            local frame_fn = self.__frame
            if frame_fn ~= nil then
                frame_fn( self, frame )
            end
        end

        local tail_fn = self.__tail
        if tail_fn ~= nil then
            tail_fn( self )
        end

        engine_consoleMessageColored( "\n", COLOR_WHITE_SMOKE )
    end

end

--- [SHARED AND MENU]
---
--- The class used to create new `Error` instances.
---
---@class dreamwork.std.ErrorClass : dreamwork.std.Error
---@field __base dreamwork.std.Error
---@overload fun( message: ( string | nil ) ): dreamwork.std.Error
local ErrorClass = class.create( Error )
std.Error = ErrorClass

--- [SHARED AND MENU]
---
--- Returns whether the given value is an error.
---
---@param value any
---@return boolean is_error
function std.isError( value )
    return is( value, ErrorClass )
end

--- [SHARED AND MENU]
---
--- An error raised for generic runtime failures that don't fall into
--- any more specific error category.
---
---@class dreamwork.std.RuntimeError : dreamwork.std.Error
---@field __class dreamwork.std.RuntimeErrorClass
---@field __parent dreamwork.std.Error
---@field message string | nil The error message to display.
local RuntimeError = class.base( "RuntimeError", false, ErrorClass )

--- [SHARED AND MENU]
---
--- The class used to create new `RuntimeError` instances.
---
---@class dreamwork.std.RuntimeErrorClass : dreamwork.std.RuntimeError
---@field __base dreamwork.std.RuntimeError
---@field __parent dreamwork.std.ErrorClass
---@overload fun( message: ( string | nil ) ): dreamwork.std.RuntimeError
std.RuntimeError = class.create( RuntimeError )

--- [SHARED AND MENU]
---
--- An error raised when a called feature, method, or function
--- has not been implemented yet.
---
---@class dreamwork.std.NotImplementedError : dreamwork.std.Error
---@field __class dreamwork.std.NotImplementedErrorClass
---@field __parent dreamwork.std.Error
---@field message string | nil The error message to display.
local NotImplementedError = class.base( "NotImplementedError", false, ErrorClass )

---@param error_message string | nil
---@return string
---@protected
function NotImplementedError:__message( error_message )
    local stack = self.stack
    if stack ~= nil then
        local top_frame = stack:peek()
        if top_frame ~= nil then
            ---@type string | nil
            local name = top_frame.name
            if name == nil and top_frame.func ~= nil then
                name = debug.getfname( top_frame.func )
            end

            if name ~= nil then
                if error_message == nil then
                    return string_format( "`%s` is not implemented.", name )
                end

                return string_format( "`%s` is not implemented, because %s.", name, error_message )
            end
        end
    end

    if error_message == nil then
        return "This feature is not implemented."
    end

    return string_format( "This feature is not implemented, because %s.", error_message )
end

--- [SHARED AND MENU]
---
--- The class used to create new `NotImplementedError` instances.
---
---@class dreamwork.std.NotImplementedErrorClass : dreamwork.std.NotImplementedError
---@field __base dreamwork.std.NotImplementedError
---@field __parent dreamwork.std.ErrorClass
---@overload fun( message: ( string | nil ) ): dreamwork.std.NotImplementedError
std.NotImplementedError = class.create( NotImplementedError )

--- [SHARED AND MENU]
---
--- An error raised during asynchronous/coroutine execution, whose
--- traceback additionally reports the thread it occurred in.
---
---@class dreamwork.std.AsyncError : dreamwork.std.Error
---@field __class dreamwork.std.AsyncErrorClass
---@field __parent dreamwork.std.Error
---@field message string | nil The error message to display.
local AsyncError = class.base( "AsyncError", false, ErrorClass )

---@param top_frame dreamwork.std.debug.StackLevel | nil
---@protected
function AsyncError:__head( top_frame )
    engine_consoleMessageColored( "         in ", COLOR_SUVA_GRAY )

    if top_frame ~= nil then
        local thread = top_frame.thread
        if thread ~= nil then
            engine_consoleMessageColored( represent( top_frame.thread ) .. "\n", COLOR_SPRAY )
            return
        end
    end

    engine_consoleMessageColored( "main\n", COLOR_LIGHT_GRAY )
end

---@param frame dreamwork.std.debug.StackLevel
---@protected
function AsyncError:__frame( frame )
    local thread = frame.thread
    if thread == nil then
        engine_consoleMessageColored( "     thread: ", COLOR_SUVA_GRAY )
        engine_consoleMessageColored( "main\n", COLOR_LIGHT_GRAY )
    else
        engine_consoleMessageColored( "     thread: ", COLOR_SUVA_GRAY )
        engine_consoleMessageColored( string_format( "%p\n", thread ), COLOR_SPRAY )
    end
end

--- [SHARED AND MENU]
---
--- The class used to create new `AsyncError` instances.
---
---@class dreamwork.std.AsyncErrorClass : dreamwork.std.AsyncError
---@field __base dreamwork.std.AsyncError
---@field __parent dreamwork.std.ErrorClass
---@overload fun( message: ( string | nil ) ): dreamwork.std.AsyncError
std.AsyncError = class.create( AsyncError )

--- [SHARED AND MENU]
---
--- An error raised when a value does not match the type
--- expected by an operation, function argument, or field.
---
---@class dreamwork.std.TypeError : dreamwork.std.Error
---@field __class dreamwork.std.TypeErrorClass
---@field __parent dreamwork.std.Error
---@field index integer
---@field value any
---@field value_name string | nil
---@field function_name string | nil
---@field expected_type string The type that was expected.
---@field received_type string The type that was actually received.
local TypeError = class.base( "TypeError", false, ErrorClass )

---@param index integer
---@param value any
---@param value_name string | nil
---@param expected_type string
---@param function_name string
---@protected
function TypeError:__init( index, value, expected_type, value_name, function_name )
    self.index = index
    self.value = value
    self.expected_type = expected_type

    self.value_name = value_name
    self.function_name = function_name or "<unknown>"

    self.received_type = type( value )
end

---@protected
function TypeError:__head()
    engine_consoleMessageColored( "  value info:\n", COLOR_SUVA_GRAY )

    engine_consoleMessageColored( "    index: ", COLOR_SUVA_GRAY )
    engine_consoleMessageColored( self.index .. "\n", COLOR_LIGHT_GRAY )

    engine_consoleMessageColored( "    type: ", COLOR_SUVA_GRAY )
    engine_consoleMessageColored( "\"" .. self.received_type .. "\"\n", COLOR_SANDSTONE )

    engine_consoleMessageColored( "    name: ", COLOR_SUVA_GRAY )

    local value_name = self.value_name
    if value_name == nil then
        engine_consoleMessageColored( "<unknown>\n", COLOR_LIGHT_GRAY )
    else
        engine_consoleMessageColored( "\"" .. value_name .. "\"\n", COLOR_SANDSTONE )
    end

    engine_consoleMessageColored( "    value: ", COLOR_SUVA_GRAY )
    engine_consoleMessageColored( represent( self.value ) .. "\n", COLOR_SPRAY )
end

---@return string
---@protected
function TypeError:__message()
    return string_format(
        "bad argument #%d to `%s` (`%s` expected, got `%s`)",
        self.index or 0,
        self.function_name,
        self.expected_type,
        self.received_type
    )
end

--- [SHARED AND MENU]
---
--- The class used to create new `TypeError` instances.
---
---@class dreamwork.std.TypeErrorClass : dreamwork.std.TypeError
---@field __base dreamwork.std.TypeError
---@field __parent dreamwork.std.ErrorClass
---@overload fun( index: integer, value: any, expected_type: string, value_name: ( string | nil ), function_name: ( string | nil ) ): dreamwork.std.TypeError
std.TypeError = class.create( TypeError )

--- [SHARED AND MENU]
---
--- An error raised when a value has the correct type but is
--- otherwise invalid or out of the accepted range for an operation.
---
---@class dreamwork.std.ValueError : dreamwork.std.Error
---@field __class dreamwork.std.ValueErrorClass
---@field __parent dreamwork.std.Error
---@field message string | nil Optional explanation of why the value is invalid.
---@field value any The invalid value.
local ValueError = class.base( "ValueError", false, ErrorClass )

---@param value any
---@param message string | nil
---@protected
function ValueError:__init( value, message )
    self.value = value
    Error.__init( self, message )
end

---@param error_message string | nil
---@return string
---@protected
function ValueError:__message( error_message )
    if self.value ~= nil then
        if error_message == nil then
            return string_format( "invalid value `%s`", represent( self.value ) )
        end

        return string_format( "invalid value `%s`: %s", represent( self.value ), error_message )
    end

    return "an invalid value was provided"
end

--- [SHARED AND MENU]
---
--- The class used to create new `ValueError` instances.
---
---@class dreamwork.std.ValueErrorClass : dreamwork.std.ValueError
---@field __base dreamwork.std.ValueError
---@field __parent dreamwork.std.ErrorClass
---@overload fun( value: any, message: ( string | nil ) ): dreamwork.std.ValueError
std.ValueError = class.create( ValueError )

--- [SHARED AND MENU]
---
--- An error raised when a read operation unexpectedly reaches
--- the end of a stream, file, or buffer before completing.
---
---@class dreamwork.std.EndOfFileError : dreamwork.std.Error
---@field __class dreamwork.std.EndOfFileErrorClass
---@field __parent dreamwork.std.Error
---@field position integer | nil Byte offset at which EOF was hit.
---@field expected integer | nil Number of bytes that were expected to be read.
local EndOfFileError = class.base( "EndOfFileError", false, ErrorClass )

---@param position integer | nil
---@param expected integer | nil
---@protected
function EndOfFileError:__init( position, expected )
    self.position = position
    self.expected = expected
end

---@return string
---@protected
function EndOfFileError:__message()
    if self.position ~= nil and self.expected ~= nil then
        return string_format( "unexpected end of data at byte %d (expected %d more byte%s)",
            self.position, self.expected, self.expected == 1 and "" or "s" )
    elseif self.position ~= nil then
        return string_format( "unexpected end of data at byte %d", self.position )
    end

    return "unexpected end of data"
end

--- [SHARED AND MENU]
---
--- The class used to create new `EndOfFileError` instances.
---
---@class dreamwork.std.EndOfFileErrorClass : dreamwork.std.EndOfFileError
---@field __base dreamwork.std.EndOfFileError
---@field __parent dreamwork.std.ErrorClass
---@overload fun( position: ( integer | nil ), expected: ( integer | nil ) ): dreamwork.std.EndOfFileError
std.EndOfFileError = class.create( EndOfFileError )

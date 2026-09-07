---@diagnostic disable-next-line: undefined-global
local dofile = dofile or include
if dofile == nil then
    error( "`dofile` not found, dreamwork cannot be loaded!" )
end

if dreamwork == nil then
    --- [SHARED AND MENU]
    ---
    --- Lua runtime and package manager.
    ---
    ---@class dreamwork
    ---@field Version string Package manager version in semver format.
    ---@field Prefix string Package manager unique prefix.
    ---@field std dreamwork.std Standard runtime environment.
    ---@diagnostic disable-next-line: missing-fields
    dreamwork = { std = {} }
    dreamwork.Version = "0.1.0"
    dreamwork.Prefix = "dreamwork@" .. dreamwork.Version
end

dreamwork.dofile = dofile

---@class dreamwork.std
---@field _G table The global environment of Lua.
---@field _R table The registry of Lua.
---@field LUA_VERSION string The version of the Lua interpreter.
---@field GAME_VERSION integer Contains the version number of the Garrys Mod. For example: `201211` = `01.01.2012`
---@field GAME_BRANCH "x86-64" | "dev" | "prerelease" | "unknown" | string The branch the Garry's Mod is running on. This will be `unknown` on main branch.
---@field LUA_REALM "server" | "client" | "menu" | "unknown" The realm the code is running on.
---@field LUA_MENU boolean `true` if code is running on the menu, `false` otherwise.
---@field LUA_CLIENT boolean `true` if code is running on the client, `false` otherwise.
---@field LUA_CLIENT_MENU boolean `true` if code is running on the client or menu, `false` otherwise.
---@field LUA_CLIENT_SERVER boolean `true` if code is running on the client or server, `false` otherwise.
---@field LUA_SERVER boolean `true` if code is running on the server, `false` otherwise.
---@field DEVELOPER integer A cached value of `developer` console variable.
---@field FRAME_TIME number The time it takes to run one frame in seconds. **Client-only**
---@field FPS number The number of frames per second. **Client-only**
local std = dreamwork.std

std.LUA_VERSION = _VERSION or "unknown"

---@diagnostic disable-next-line: assign-type-mismatch, undefined-global
std.GAME_VERSION = VERSION or 0

---@diagnostic disable-next-line: undefined-global
std.GAME_BRANCH = BRANCH or "unknown"

---@diagnostic disable-next-line: undefined-global
local LUA_MENU = MENU_DLL == true
std.LUA_MENU = LUA_MENU

---@diagnostic disable-next-line: undefined-global
local LUA_CLIENT = CLIENT == true and not LUA_MENU
std.LUA_CLIENT = LUA_CLIENT

---@diagnostic disable-next-line: undefined-global
local LUA_SERVER = SERVER == true and not LUA_MENU
std.LUA_SERVER = LUA_SERVER

local LUA_CLIENT_MENU = LUA_CLIENT or LUA_MENU
std.LUA_CLIENT_MENU = LUA_CLIENT_MENU

local LUA_MENU_SERVER = LUA_SERVER or LUA_MENU
std.LUA_MENU_SERVER = LUA_MENU_SERVER

local LUA_CLIENT_SERVER = LUA_CLIENT or LUA_SERVER
std.LUA_CLIENT_SERVER = LUA_CLIENT_SERVER

if LUA_SERVER then
    std.LUA_REALM = "server"
elseif LUA_CLIENT then
    std.LUA_REALM = "client"
elseif LUA_MENU then
    std.LUA_REALM = "menu"
else
    std.LUA_REALM = "unknown"
end

--- [SHARED AND MENU]
---
--- If object does not have a metatable, returns `nil`.
---
--- Otherwise, if the object's metatable has a `__metatable` field, returns the associated value.
---
--- Otherwise, returns the metatable of the given object.
---
--- [View documents](http://www.lua.org/manual/5.1/manual.html#pdf-getmetatable)
---
---@type fun(object: any): dreamwork.std.Metatable | nil
std.getmetatable = getmetatable

--- [SHARED AND MENU]
---
--- Sets the metatable for the given table.
---
--- If `metatable` is `nil`, removes the metatable of the given table.
---
--- If the original metatable has a `__metatable` field, raises an error.
---
--- This function returns `table`.
---
--- To change the metatable of other types from Lua code, you must use the debug library ([§6.10](http://www.lua.org/manual/5.4/manual.html#6.10)).
---
---[View documents](http://www.lua.org/manual/5.1/manual.html#pdf-setmetatable)
---
---@generic K, V
---@type fun(tbl: table<K,V>, metatable: dreamwork.std.Metatable<K,V>): table<K,V>
std.setmetatable = setmetatable

local setmetatable = std.setmetatable

std.xpcall = xpcall

local pcall = pcall
std.pcall = pcall

-- raw data library
dofile( "dreamwork/std/raw.lua" )

---@class dreamwork.std.raw
local raw = std.raw
local raw_get = raw.get
local raw_pairs = raw.pairs
local raw_select = raw.select

-- debug library
dofile( "dreamwork/std/debug.lua" )

---@class dreamwork.std.debug
local debug = std.debug
local debug_fempty = debug.fempty
local debug_getmetavalue = debug.getmetavalue

do

    local raw_tostring = raw.tostring

    --- [SHARED AND MENU]
    ---
    --- Receives a value of any type and converts it to a string in a human-readable format.
    ---
    --- If the metatable of `v` has a `__tostring` field, then `tostring` calls the corresponding value with `v` as argument, and uses the result of the call as its result.
    ---
    --- Otherwise, if the metatable of `v` has a `__name` field with a string value, `tostring` may use that string in its final result.
    ---
    --- For complete control of how numbers are converted, use [string.format](http://www.lua.org/manual/5.4/manual.html#pdf-string.format).
    ---
    ---
    --- [View documents](http://www.lua.org/manual/5.4/manual.html#pdf-tostring)
    ---
    ---@param value any The value to convert to a string.
    ---@return string str The string representation of `value`.
    function std.tostring( value )
        local name = debug_getmetavalue( value, "__name" )
        if name == nil then
            return raw_tostring( value )
        else
            return name
        end
    end

end

local tostring = std.tostring

-- we need more sugar!!1
raw.getmetatable = debug.getmetatable
raw.setmetatable = debug.setmetatable

---@type fun( lua_path: string )
---@diagnostic disable-next-line: undefined-global
local sendfile = LUA_SERVER and AddCSLuaFile or debug_fempty
dreamwork.sendfile = sendfile

sendfile( "dreamwork/loader.lua" )
sendfile( "dreamwork/std/raw.lua" )
sendfile( "dreamwork/std/debug.lua" )

-- garbage collector
dofile( "dreamwork/std/gc.lua" )
sendfile( "dreamwork/std/gc.lua" )

local gc = std.gc
local startup_memory = gc.getMemory()

std.getfenv = getfenv or debug.getfenv

if std.getfenv == nil then

    local debug_getupvalue = debug.getupvalue
    local debug_getf = debug.getf
    local raw_type = raw.type

    ---@diagnostic disable-next-line: undefined-global
    local _G = _G or _ENV

    --- [SHARED AND MENU]
    ---
    --- Returns the current environment in use by the function.
    ---
    ---@param location integer | function Can be a Lua `function` or a `number` that specifies the function at that stack level.
    ---@return table fenv Specified function environment.
    ---@diagnostic disable-next-line: duplicate-set-field
    function std.getfenv( location )
        ---@type function | nil
        local func

        local location_type = raw_type( location )
        if location_type == "function" then
            ---@cast location function
            func = location
        elseif location_type == "number" then
            func = debug_getf( (location or 1) + 1 )
            if func == nil then
                return _G
            end
        else
            return _G
        end

        local index = 1

        ::fenv_search_loop::

        local name, value = debug_getupvalue( func, index )

        if name == nil then
            return _G
        elseif name == "_ENV" then
            return value
        end

        index = index + 1

        ---@diagnostic disable-next-line: missing-return
        goto fenv_search_loop
    end

end

std.setfenv = setfenv or debug.setfenv

if std.setfenv == nil then

    local debug_getupvalue = debug.getupvalue
    local debug_setupvalue = debug.setupvalue
    local debug_getf = debug.getf
    local raw_type = raw.type

    --- [SHARED AND MENU]
    ---
    --- Sets the environment of the specified function.
    ---
    ---@generic F: function
    ---@param location integer | F Can be a Lua `function` or a `number` that specifies the function at that stack level.
    ---@param env table The environment table to set.
    ---@return F location The function with the updated environment.
    ---@diagnostic disable-next-line: duplicate-set-field
    std.setfenv = setfenv or debug.setfenv or function( location, env )
        local func

        if location == nil or raw_type( location ) == "number" then
            func = debug_getf( (location or 1) + 1 )
            if func == nil then
                std.error( "environment was corrupted; setfenv failed", 2 )
                ---@diagnostic disable-next-line: missing-return-value
                return
            end
        end

        local index = 1

        ::fenv_setup_loop::

        local name = debug_getupvalue( func, index )
        if name == "_ENV" then
            debug_setupvalue( func, index, env )
        elseif name ~= nil then
            goto fenv_setup_loop
        end

        index = index + 1
        return location
    end

end

---@type fun( value: any ): boolean
---@diagnostic disable-next-line: undefined-global
local isTable = istable

if isTable == nil then

    local raw_type = raw.type

    --- [SHARED AND MENU]
    ---
    --- Checks whether the value is a `table`.
    ---
    ---@param value any The value to check.
    ---@return boolean is_table `true` if the value is a `table`, `false` otherwise.
    function isTable( value )
        return raw_type( value ) == "table"
    end

end

std.isTable = isTable

-- jit library
dofile( "dreamwork/std/jit.lua" )
sendfile( "dreamwork/std/jit.lua" )

--- [SHARED AND MENU]
---
--- Returns the length of the given value.
---
---@param value any The value to get the length of.
---@return number length The length of the given value.
function std.len( value )
    ---@type nil | fun( value: any ): number
    local fn = debug_getmetavalue( value, "__len" )
    if fn == nil then
        return #value
    else
        return fn( value )
    end
end

--- [SHARED AND MENU]
---
--- Compares two values for equality.
---
--- Unlike Lua's `==` operator, this function invokes the `__eq` metamethod
--- from either operand if one is available. If neither operand defines
--- `__eq`, it falls back to the built-in equality operator.
---
---@param a any The first value to compare.
---@param b any The second value to compare.
---@return boolean is_equal `true` if the values are considered equal; otherwise `false`.
function std.eq( a, b )
    ---@type nil | fun( a: any, b: any ): boolean
    local a__eq = debug_getmetavalue( a, "__eq" )
    if a__eq == nil then
        ---@type nil | fun( a: any, b: any ): boolean
        local b__eq = debug_getmetavalue( b, "__eq" )
        if b__eq == nil then
            return a == b
        else
            return b__eq( b, a )
        end
    else
        return a__eq( a, b )
    end
end

--- [SHARED AND MENU]
---
--- Returns binary size of the `value` as integer of bit/bytes.
---
---@param value any The value to get the size of.
---@param as_bytes? boolean Whether return size as bytes. By default: `false`
---@return integer | nil size The size of the `value`.
function std.sizeof( value, as_bytes )
    ---@type nil | fun( value: any, as_bytes: boolean ): integer
    local fn = debug_getmetavalue( value, "__sizeof" )
    if fn == nil then
        return nil
    else
        return fn( value, as_bytes == true )
    end
end

--- [SHARED AND MENU]
---
--- Returns a string representation of the given value.
---
---@param value any The value to get the string representation of.
---@return string str The string representation of the given value.
function std.represent( value )
    ---@type fun( value: any ): string
    local fn = debug_getmetavalue( value, "__represent" )
    if fn == nil then
        return tostring( value )
    else
        return fn( value )
    end
end

--- [SHARED AND MENU]
---
--- Returns the copy of the `value`.
---
---@generic T
---@param value T The value to copy.
---@return T copy The copy of the `value`.
function std.copy( value )
    local fn = debug_getmetavalue( value, "__copy" )
    if fn == nil then
        return nil
    else
        return fn( value )
    end
end

--- [SHARED AND MENU]
---
--- If `e` has a metamethod `__tonumber`, calls it with `e` and `base` as arguments and returns its result.
---
--- When called with no `base`, `tonumber` tries to convert its argument to a number. If the argument is already a number or a string convertible to a number, then `tonumber` returns this number; otherwise, it returns `fail`.
---
--- The conversion of strings can result in integers or floats, according to the lexical conventions of Lua (see [§3.1](command:extension.lua.doc?["en-us/51/manual.html/3.1"])). The string may have leading and trailing spaces and a sign.
---
---
--- [View documents](command:extension.lua.doc?["en-us/51/manual.html/pdf-tonumber"])
---
---@param e any The value to convert to a number.
---@param base? integer The number base, default is `10`.
---@return number | nil x The number value of `e`, or `nil` if `e` cannot be converted to a number.
function std.tonumber( e, base )
    local fn = debug_getmetavalue( e, "__tonumber" )
    if fn == nil then
        return nil
    else
        return fn( e, base or 10 )
    end
end

--- [SHARED AND MENU]
---
--- If `e` has a metamethod `__toboolean`, calls it with `e` as argument and returns its result.
---
--- Otherwise, returns `nil`.
---
---@param e any The value to convert to a `boolean`.
---@return boolean | nil bool The boolean value of `e`, or `nil` if `e` cannot be converted to a boolean.
function std.toboolean( e )
    local fn = debug_getmetavalue( e, "__toboolean" )
    if fn == nil then
        return nil
    else
        return fn( e )
    end
end

-- Alias for lazy developers
std.tobool = std.toboolean

--- [SHARED AND MENU]
---
--- If `value` has a metamethod `__tocolor`, calls it with `value` as argument and returns its result.
---
--- Otherwise, returns `nil`.
---
---@param value any The value to convert to a `color`.
---@return dreamwork.std.Color | nil clr The color value of `value`, or `nil` if `value` cannot be converted to a color.
function std.tocolor( value )
    ---@type fun(value: any): dreamwork.std.Color | nil
    local fn = debug_getmetavalue( value, "__tocolor" )
    if fn == nil then
        return nil
    else
        return fn( value )
    end
end

--- [SHARED AND MENU]
---
--- Checks if the value is valid.
---
---@param value any The value to check for validity.
---@return boolean is_valid `true` if object is still valid and should be kept alive, `false` otherwise.
function std.isValid( value )
    local fn = debug_getmetavalue( value, "__isvalid" )
    if fn == nil then
        return false
    else
        return fn( value )
    end
end

do

    local raw_next = raw.next

    --- [SHARED AND MENU]
    ---
    --- If `t` has a metamethod `__pairs`, calls it with t as argument and returns the first three results from the call.
    ---
    --- Otherwise, returns three values: the [next](command:extension.lua.doc?["en-us/54/manual.html/pdf-next"]) function, the table `t`, and `nil`, so that the construction
    --- ```lua
    ---     for k,v in pairs(t) do body end
    --- ```
    --- will iterate over all key–value pairs of table `t`.
    ---
    --- See function [next](command:extension.lua.doc?["en-us/54/manual.html/pdf-next"]) for the caveats of modifying the table during its traversal.
    ---
    ---@generic K, V
    ---@param tbl table<K, V>
    ---@param key K | nil
    ---@return K, V
    function std.next( tbl, key )
        return (debug_getmetavalue( tbl, "__pairs" ) or raw_next)( tbl, key )
    end

end

--- [SHARED AND MENU]
---
--- If `t` has a metamethod `__pairs`, calls it with t as argument and returns the first three results from the call.
---
--- Otherwise, returns three values: the [next](command:extension.lua.doc?["en-us/54/manual.html/pdf-next"]) function, the table `t`, and `nil`, so that the construction
--- ```lua
---     for k,v in pairs(t) do body end
--- ```
--- will iterate over all key–value pairs of table `t`.
---
--- See function [next](command:extension.lua.doc?["en-us/54/manual.html/pdf-next"]) for the caveats of modifying the table during its traversal.
---
---
--- [View documents](command:extension.lua.doc?["en-us/54/manual.html/pdf-pairs"])
---
---@generic K, V
---@param t table<K, V>
---@return fun( table: table<K, V>, index: ( K | nil ) ): K, V
---@return table<K, V>
function std.pairs( t )
    local next_fn = debug_getmetavalue( t, "__pairs" )
    if next_fn == nil then
        return raw_pairs( t )
    else
        return next_fn( t, nil ), t
    end
end

do

    --- [SHARED AND MENU]
    ---
    --- Returns the next value in the table `t`, with the given `index`.
    ---
    ---@param tbl table
    ---@param index integer
    ---@return integer | nil, any
    local function inext( tbl, index )
        index = index + 1

        local value = tbl[ index ]
        if value == nil then
            return nil, nil
        else
            return index, value
        end
    end

    std.inext = inext

    local raw_ipairs = raw.ipairs

    --- [SHARED AND MENU]
    ---
    --- Returns three values (an iterator function, the table `t`, and `0`) so that the construction
    --- ```lua
    ---     for i,v in ipairs(t) do body end
    --- ```
    --- will iterate over the key–value pairs `(1,t[1]), (2,t[2]), ...`, up to the first absent index.
    ---
    ---
    --- [View documents](command:extension.lua.doc?["en-us/51/manual.html/pdf-ipairs"])
    ---
    ---@generic V
    ---@param t V[]
    ---@return fun( table: V[], i: ( integer | nil ) ): integer, V
    ---@return V[]
    ---@return integer i
    function std.ipairs( t )
        if debug_getmetavalue( t, "__index" ) == nil then
            return raw_ipairs( t )
        else
            return inext, t, 0
        end
    end

end

-- math library
dofile( "dreamwork/std/math.lua" )
sendfile( "dreamwork/std/math.lua" )

---@class dreamwork.std.math
local math = std.math
local math_min, math_max = math.min, math.max

do

    ---@alias dreamwork.std.RangeIterator fun( break_point: integer, index: integer ): integer | nil

    ---@type table<integer, dreamwork.std.RangeIterator>
    local range_iterators = {
        [ 0 ] = debug_fempty
    }

    setmetatable( range_iterators, {
        ---@param self table<integer, dreamwork.std.RangeIterator>
        ---@param step_size integer
        ---@return dreamwork.std.RangeIterator
        __index = function( self, step_size )
            local fn

            if step_size < 0 then
                fn = function( break_point, index )
                    local next_index = math_max( index + step_size, break_point )
                    if next_index == break_point then
                        return nil
                    end

                    return next_index
                end
            else
                fn = function( break_point, index )
                    local next_index = math_min( index + step_size, break_point )
                    if next_index == break_point then
                        return nil
                    end

                    return next_index
                end
            end

            self[ step_size ] = fn
            return fn
        end
    } )

    --- [SHARED AND MENU]
    ---
    --- Creates a stateless numeric `for`-loop iterator that steps from `from` to `to`
    --- (inclusive), incrementing (or decrementing) by `step` each iteration.
    ---
    --- Intended to be used directly in a generic `for` loop,
    --- e.g. `for i in range( 1, 10, 2 ) do ... end`.
    ---
    ---@param from integer The starting value of the range.
    ---@param to integer The ending value of the range (inclusive).
    ---@param step? integer The amount to step by each iteration. Defaults to `1`. Can be negative to count down.
    ---@return dreamwork.std.RangeIterator iterator The iterator function to be used with a generic `for` loop.
    ---@return integer to The final value, passed through as the loop's invariant state.
    ---@return integer start The initial value, passed to the iterator on the first call.
    function std.range( from, to, step )
        return range_iterators[ step or 1 ], to, from - (step or 1)
    end

end

--- [SHARED AND MENU]
---
--- The global environment table (outside of DreamWork).
---
---@type _G
---@diagnostic disable-next-line: undefined-global
std.global = std.getfenv( 1 ) or _G or _ENV

-- os library
dofile( "dreamwork/std/os.lua" )
sendfile( "dreamwork/std/os.lua" )

---@class dreamwork.std.os
local os = std.os

---@diagnostic disable-next-line: undefined-global
local SysTime = SysTime or os.clock
dreamwork.InitTime = SysTime()

-- detour library
dofile( "dreamwork/detour.lua" )
sendfile( "dreamwork/detour.lua" )

-- table library
dofile( "dreamwork/std/table.lua" )
sendfile( "dreamwork/std/table.lua" )

-- vararg library
dofile( "dreamwork/std/vararg.lua" )
sendfile( "dreamwork/std/vararg.lua" )

---@class dreamwork.std.table
local table = std.table
local table_concat = table.concat

-- ascii library
dofile( "dreamwork/std/ascii.lua" )
sendfile( "dreamwork/std/ascii.lua" )

-- string library
dofile( "dreamwork/std/string.lua" )
sendfile( "dreamwork/std/string.lua" )

---@class dreamwork.std.string
local string = std.string
local string_match = string.match
local string_format = string.format
local string_sub, string_len = string.sub, string.len
local string_char, string_byte = string.char, string.byte

do

    local string_toNumber = string.toNumber

    --- [SHARED AND MENU]
    ---
    --- Returns the hash of the given value.
    ---
    ---@param value any The value to get the hash of.
    ---@return integer hash The hash of the given value.
    function std.hash( value )
        ---@type fun( value: any ): integer
        local fn = debug_getmetavalue( value, "__hash" )
        if fn == nil then
            return string_toNumber( string_format( "%p", value ), 16 ) or 0
        else
            return fn( value )
        end
    end

end

-- table library ( extension )
dofile( "dreamwork/std/table.ext.lua" )
sendfile( "dreamwork/std/table.ext.lua" )

-- bit library
dofile( "dreamwork/std/bit.lua" )
sendfile( "dreamwork/std/bit.lua" )

-- symbols
dofile( "dreamwork/std/types/symbol.lua" )
sendfile( "dreamwork/std/types/symbol.lua" )

-- class library
dofile( "dreamwork/std/class.lua" )
sendfile( "dreamwork/std/class.lua" )

do

    local debub_getmetatable = debug.getmetatable
    local isInherited = std.class.isInherited
    local isClass = std.isClass

    --- [SHARED AND MENU]
    ---
    --- Checks if the value is an instance of the given parent.
    ---
    ---@param object any The object to check for being an instance of the given parent.
    ---@param ... any The parent classes/metatables to check against.
    ---@return boolean is_instance `true` if `object` is an instance of any of the given parent classes/metatables, `false` otherwise.
    function std.isInstance( object, ... )
        local metatable = debub_getmetatable( object )

        for i = 1, raw_select( "#", ... ) do
            local parent = raw_select( i, ... )
            if isClass( parent ) then
                if isInherited( object, parent ) then
                    return true
                end
            elseif metatable == parent then
                return true
            end
        end

        return false
    end

    --- [SHARED AND MENU]
    ---
    --- Checks if the value is an instance of the given parent.
    ---
    ---@param object any The object to check for being an instance of the given parent.
    ---@param value any The parent class/metatable to check against.
    ---@return boolean is_instance `true` if `object` is an instance of the given parent class/metatable, `false` otherwise.
    function std.is( object, value )
        if isClass( value ) then
            if isInherited( object, value ) then
                return true
            end
        elseif debub_getmetatable( object ) == value then
            return true
        end

        return false
    end

end

-- bitpack library
dofile( "dreamwork/std/codec/bitpack.lua" )
sendfile( "dreamwork/std/codec/bitpack.lua" )

-- bytepack library
dofile( "dreamwork/std/codec/bytepack.lua" )
sendfile( "dreamwork/std/codec/bytepack.lua" )

-- string library ( extension )
dofile( "dreamwork/std/string.ext.lua" )
sendfile( "dreamwork/std/string.ext.lua" )

-- ipv4 library
dofile( "dreamwork/std/ipv4.lua" )
sendfile( "dreamwork/std/ipv4.lua" )

-- ipv6 class
dofile( "dreamwork/std/ipv6.lua" )
sendfile( "dreamwork/std/ipv6.lua" )

-- stack class
dofile( "dreamwork/std/types/stack.lua" )
sendfile( "dreamwork/std/types/stack.lua" )

-- queue class
dofile( "dreamwork/std/types/queue.lua" )
sendfile( "dreamwork/std/types/queue.lua" )

-- node class
dofile( "dreamwork/std/types/node.lua" )
sendfile( "dreamwork/std/types/node.lua" )

-- version class
dofile( "dreamwork/std/types/version.lua" )
sendfile( "dreamwork/std/types/version.lua" )

-- crc checksum clases
dofile( "dreamwork/std/checksum/crc.lua" )
sendfile( "dreamwork/std/checksum/crc.lua" )

-- adler checksum classes
dofile( "dreamwork/std/checksum/adler.lua" )
sendfile( "dreamwork/std/checksum/adler.lua" )

-- fletcher checksum library
dofile( "dreamwork/std/checksum/fletcher.lua" )
sendfile( "dreamwork/std/checksum/fletcher.lua" )

-- base16 encoding library
dofile( "dreamwork/std/codec/base16.lua" )
sendfile( "dreamwork/std/codec/base16.lua" )

-- base32 encoding library
dofile( "dreamwork/std/codec/base32.lua" )
sendfile( "dreamwork/std/codec/base32.lua" )

-- base64 encoding library
dofile( "dreamwork/std/codec/base64.lua" )
sendfile( "dreamwork/std/codec/base64.lua" )

-- utf8 encoding library
dofile( "dreamwork/std/codec/utf8.lua" )
sendfile( "dreamwork/std/codec/utf8.lua" )

-- utf16 encoding library
dofile( "dreamwork/std/codec/utf16.lua" )
sendfile( "dreamwork/std/codec/utf16.lua" )

-- utf32 encoding library
dofile( "dreamwork/std/codec/utf32.lua" )
sendfile( "dreamwork/std/codec/utf32.lua" )

-- unicode encoding library
dofile( "dreamwork/std/codec/unicode.lua" )
sendfile( "dreamwork/std/codec/unicode.lua" )

-- percent encoding library
dofile( "dreamwork/std/codec/percent.lua" )
sendfile( "dreamwork/std/codec/percent.lua" )

-- punycode encoding library
dofile( "dreamwork/std/codec/punycode.lua" )
sendfile( "dreamwork/std/codec/punycode.lua" )

-- time library
dofile( "dreamwork/std/time.lua" )
sendfile( "dreamwork/std/time.lua" )

local time = std.time

if math.randomseed == 0 then
    math.randomseed = time.now( "ms", false )
end

-- coroutine library
dofile( "dreamwork/std/coroutine.lua" )
sendfile( "dreamwork/std/coroutine.lua" )

-- debug stack class
dofile( "dreamwork/std/types/debug_stack.lua" )
sendfile( "dreamwork/std/types/debug_stack.lua" )

-- buffer library
dofile( "dreamwork/std/codec/buffer.lua" )
sendfile( "dreamwork/std/codec/buffer.lua" )

do

    ---@diagnostic disable-next-line: undefined-global
    local timer_Simple = timer.Simple
    local table_unpack = table.unpack

    --- [SHARED AND MENU]
    ---
    --- Calls the `fn` function after `delay` seconds.
    ---
    --- **Usage example:**
    ---
    --- ```lua
    --- std.setTimeout( function()
    ---     print( "Hello, world!" )
    --- end, 5 ) -- Calls the function after 5 seconds.
    --- ```
    ---
    ---@param fn function The callback function.
    ---@param delay? number The delay in seconds, default is `0`.
    ---@param ... any Additional arguments to pass to the callback function.
    function std.setTimeout( fn, delay, ... )
        local arg_count = raw_select( "#", ... )
        if arg_count ~= 0 then
            local args = { ... }
            local callback = fn

            fn = function()
                callback( table_unpack( args, 1, arg_count ) )
            end
        end

        timer_Simple( delay or 0, fn )
    end

end

do

    ---@class dreamwork.std
    ---@field SYSTEM_OSX boolean `true` if the game is running on OSX.
    ---@field SYSTEM_LINUX boolean `true` if the game is running on Linux.
    ---@field SYSTEM_WINDOWS boolean `true` if the game is running on Windows.
    ---@field SYSTEM_X64 boolean `true` if the game is running on 64-bit architecture.
    ---@field SYSTEM_X32 boolean `true` if the game is running on 32-bit architecture.
    ---@field SYSTEM_NAME "osx64" | "osx" | "linux64" | "linux" | "win64" | "win32" The short name of the currently running system with architecture.

    local jit = std.jit
    local jit_os = string.lower( jit.os )

    local SYSTEM_OSX = jit_os == "osx"
    std.SYSTEM_OSX = SYSTEM_OSX

    local SYSTEM_LINUX = jit_os == "linux"
    std.SYSTEM_LINUX = SYSTEM_LINUX

    local SYSTEM_WINDOWS = jit_os == "windows"
    std.SYSTEM_WINDOWS = SYSTEM_WINDOWS

    local SYSTEM_X64 = string.match( jit.arch, "64" ) ~= nil
    std.SYSTEM_X64 = SYSTEM_X64

    local SYSTEM_X32 = not SYSTEM_X64
    std.SYSTEM_X32 = SYSTEM_X32

    std.SYSTEM_NAME = ({ "osx64", "osx", "linux64", "linux", "win64", "win32" })[ (SYSTEM_WINDOWS and 4 or 0) + (SYSTEM_LINUX and 2 or 0) + (SYSTEM_X32 and 1 or 0) + 1 ]

end

do

    --- [SHARED AND MENU]
    ---
    --- Runs a benchmark on the given function, measuring the time it takes to execute a specified number of iterations.
    ---
    ---@param name string The name of the benchmark.
    ---@param fn function The function to benchmark.
    ---@param iterations? integer The number of iterations to run.
    function dreamwork.bench( name, fn, iterations )
        if iterations == nil then
            iterations = 1000
        end

        local warmup = math.min( iterations / 100, 100 )

        for _ = 1, warmup do
            fn()
        end

        gc.stop()
        time.tick()

        for _ = 1, iterations do
            fn()
        end

        local time_took = time.tick()
        gc.restart()

        local avg = time_took / iterations
        raw.print( string.format( "[DW] Benchmark `%s` - iter: %d / avg: %f / exp: %s / total: %f sec.", name, iterations, avg, time.transform( math.ceil( time.transform( avg, "s", "ms", true ) * iterations ), "ms", "s", true ), time_took ) )

        return time_took
    end

end

do

    local debug_registermetatable = debug.registermetatable
    local debug_getmetatable = debug.getmetatable
    local debug_setmetatable = debug.setmetatable

    -- nil ( 0 )
    do

        ---@class dreamwork.std.Nil : dreamwork.std.Metatable
        local Nil = debug_getmetatable( nil )

        if Nil == nil then
            Nil = {}
            debug_setmetatable( nil, Nil )
        end

        debug_registermetatable( "nil", Nil )

        Nil.__type = "nil"
        std.Nil = Nil

        ---@private
        function Nil.__toboolean()
            return false
        end

        ---@private
        function Nil.__tonumber()
            return 0
        end

        Nil.__len = Nil.__tonumber

        --- [SHARED AND MENU]
        ---
        --- Checks whether the value type is `nil`.
        ---
        ---@param value any
        ---@return boolean is_nil
        function std.isNil( value )
            return value == nil
        end

    end

    -- boolean ( 1 )
    do

        ---@class dreamwork.std.Boolean : dreamwork.std.Metatable
        local Boolean = debug_getmetatable( false )

        if Boolean == nil then
            Boolean = {}
            debug_setmetatable( false, Boolean )
        end

        debug_registermetatable( "boolean", Boolean )

        Boolean.__type = "boolean"
        std.Boolean = Boolean

        ---@param value boolean
        ---@private
        function Boolean.__toboolean( value )
            return value
        end

        ---@param value boolean
        ---@private
        function Boolean.__tonumber( value )
            return value == true and 1 or 0
        end

        ---@param value boolean
        ---@private
        function Boolean.__hash( value )
            return value == true and 1 or 0
        end

        ---@private
        function Boolean.__len()
            return 1
        end

        --- [SHARED AND MENU]
        ---
        --- Checks whether the value type is `boolean`.
        ---
        ---@param value any
        ---@return boolean is_bool
        function std.isBoolean( value )
            return value == true or value == false
        end

    end

    -- number ( 3 )
    do

        ---@class dreamwork.std.Number : dreamwork.std.Metatable
        local Number = debug_getmetatable( 0 )

        if Number == nil then
            Number = {}
            debug_setmetatable( 0, Number )
        end

        debug_registermetatable( "number", Number )

        Number.__type = "number"
        std.Number = Number

        ---@param value number
        ---@private
        function Number.__toboolean( value )
            return value ~= 0
        end

        ---@param value number
        ---@private
        function Number.__tonumber( value )
            return value
        end

        ---@param value number
        ---@private
        function Number.__hash( value )
            return value
        end

        ---@return string
        ---@private
        function Number:__represent()
            if (self % 1) == 0 then
                return string_format( "integer: %p [%d]", self, self )
            end

            return string_format( "number: %p [%d]", self, self )
        end

        do

            local math_ceil, math_log, math_isFinite = math.ceil, math.log, math.isFinite
            local math_ln2 = math.ln2

            ---@param value number
            ---@private
            function Number.__len( value )
                if math_isFinite( value ) then
                    if (value % 1) == 0 then
                        return math_ceil( (
                            math_ceil( math_log( value + 1 ) / math_ln2 ) +
                            (((1 / value) > 0) and 1 or 0)
                        ) / 8 )
                    elseif value >= 1.175494351E-38 and value <= 3.402823466E+38 then
                        return 4
                    end

                    return 8
                end

                return 0
            end

        end

        --- [SHARED AND MENU]
        ---
        --- Checks whether the value type is a `number`.
        ---
        ---@param value any
        ---@return boolean is_number
        function std.isNumber( value )
            return debug_getmetatable( value ) == Number
        end

        ---@class dreamwork.std.Integer : dreamwork.std.Metatable
        local Integer = debug.initmetatable( "Integer" )
        Integer.__type = "integer"
        std.Integer = Integer

        setmetatable( Integer, {
            ---@param value number
            __eq = function( _, value )
                return (value % 1) == 0
            end
        } )

        --- [SHARED AND MENU]
        ---
        --- Checks whether the value type is a `integer`.
        ---
        ---@param value any
        ---@return boolean is_integer
        function std.isInteger( value )
            return debug_getmetatable( value ) == Number and (value % 1) == 0
        end

    end

    -- string ( 4 )
    do

        ---@class dreamwork.std.String : dreamwork.std.Metatable
        local String = debug_getmetatable( "" )

        if String == nil then
            String = {}
            debug_setmetatable( "", String )
        end

        debug_registermetatable( "string", String )

        String.__type = "string"
        std.String = String

        ---@private
        function String:__toboolean()
            return self ~= "" and self ~= "0" and self ~= "false"
        end

        function String:__represent()
            return string_format( "string: %p [%s]", self, self )
        end

        String.__tonumber = raw.tonumber
        String.__div = string.divide
        String.__len = string.len

        --- [SHARED AND MENU]
        ---
        --- Checks whether the value type is a `string`.
        ---
        ---@param value any
        ---@return boolean is_string
        function std.isString( value )
            return debug_getmetatable( value ) == String
        end

    end

    -- table ( 5 )

    -- function ( 6 )
    do

        ---@class dreamwork.std.Function : dreamwork.std.Metatable
        local Function = debug_getmetatable( debug_fempty )

        if Function == nil then
            Function = {}
            debug_setmetatable( debug_fempty, Function )
        end

        debug_registermetatable( "function", Function )

        Function.__type = "function"
        std.Function = Function

        --- [SHARED AND MENU]
        ---
        --- Checks whether the value type is a `function`.
        ---
        ---@param value any
        ---@return boolean is_function
        function std.isFunction( value )
            return debug_getmetatable( value ) == Function
        end

        --- [SHARED AND MENU]
        ---
        --- Checks if the value is callable, basically it's a function or a table with a callable `__call` metamethod.
        ---
        ---@param value any
        ---@return boolean is_callable
        function std.isCallable( value )
            local metatable = debug_getmetatable( value )
            return metatable ~= nil and (metatable == Function or debug_getmetatable( metatable.__call ) == Function)
        end

    end

    -- thread ( 8 )
    do

        local object = std.coroutine.create( debug_fempty )

        ---@class dreamwork.std.Thread : dreamwork.std.Metatable
        local Thread = debug_getmetatable( object )

        if Thread == nil then
            Thread = {}
            debug_setmetatable( object, Thread )
        end

        debug_registermetatable( "thread", Thread )

        Thread.__type = "thread"
        std.Thread = Thread

        --- [SHARED AND MENU]
        ---
        --- Checks whether the value type is a `thread`.
        ---
        ---@param value any
        ---@return boolean is_thread
        function std.isThread( value )
            return debug_getmetatable( value ) == Thread
        end

    end

end

local isFunction = std.isFunction
local isString = std.isString
local isNumber = std.isNumber

do

    local raw_type = raw.type

    --- [SHARED AND MENU]
    ---
    --- Returns a string representing the name of the type of the passed object.
    ---
    ---@param value any The value to get the type of.
    ---@return string type_name The type name of the given value.
    function std.type( value )
        if isNumber( value ) and (value % 1) == 0 then
            return "integer"
        end

        return debug_getmetavalue( value, "__type" ) or
            debug_getmetavalue( value, "MetaName" ) or
            raw_type( value )
    end

end

local represent = std.represent
local type = std.type
local len = std.len

-- path library
dofile( "dreamwork/std/path.lua" )
sendfile( "dreamwork/std/path.lua" )

-- color library
dofile( "dreamwork/std/color.lua" )
sendfile( "dreamwork/std/color.lua" )

---@class dreamwork.std.color
local color_lib = std.color

--- [SHARED AND MENU]
---
--- A table containing named colors.
---
--- Also takes colors from `resource/ClientScheme.res` if available. [CLIENT/MENU?]
---
--- If no color is found, a new empty color will be created and assigned to specified name.
---
--- Table key must be `string` or `integer`.
---
---@class dreamwork.std.color.Scheme
local color_scheme = color_lib.Scheme or {}
color_lib.Scheme = color_scheme

do

    local color_fromRGB = color_lib.fromRGB

    do

        local Scheme = std.getmetatable( color_scheme ) or {}
        setmetatable( color_scheme, Scheme )

        ---@protected
        function Scheme:__tostring()
            return string_format( "ColorScheme: %p", self )
        end

        ---@diagnostic disable-next-line: undefined-global
        local NamedColor = NamedColor or debug_fempty

        local tmp = { r = 255, g = 255, b = 255, a = 255 }

        ---@param name string | integer
        ---@protected
        function Scheme:__index( name )
            local color

            if isString( name ) then
                ---@cast name string
                ---@diagnostic disable-next-line: redundant-parameter
                local engine_color = NamedColor( name ) or tmp
                color = color_fromRGB( engine_color.r, engine_color.g, engine_color.b )
            elseif isNumber( name ) then
                ---@cast name integer
                color = color_fromRGB( name, name, name )
            else
                std.error( "color name must be string or integer to resolve color.", 3 )
            end

            self[ name ] = color
            return color
        end

    end

    -- Basic Colors
    color_scheme.white = 0xFFFFFF
    color_scheme.white_smoke = 0xF0F0F0

    color_scheme.black = 0x000000

    color_scheme.red = 0xFF0000
    color_scheme.mona_lisa = 0xFF8A80

    color_scheme.green = 0x00FF00

    color_scheme.blue = 0x0000FF
    color_scheme.spray = 0x7EC8E3
    color_scheme.robin_egg_blue = 0x7EC8E3

    color_scheme.yellow = 0xFFFF00
    color_scheme.sandstone = 0xC9B896

    color_scheme.cyan = 0x00FFFF
    color_scheme.magenta = 0xFF00FF

    color_scheme.gray = 0x808080
    color_scheme.dark_gray = 0xA9A9A9
    color_scheme.light_gray = 0xD0D0D0
    color_scheme.suva_gray = 0x8A8A8A

    color_scheme.turquoise = 0x40e0d0
    color_scheme.dark_turquoise = 0x00D0D0

    -- Garry's Mod
    -- Thank you code_gs <3
    -- https://discord.com/channels/565105920414318602/565108080300261398/905385921283756062
    color_scheme.server_message = color_lib.fromRGB( 156, 241, 255 )
    color_scheme.server_error = color_lib.fromRGB( 136, 221, 255 )

    color_scheme.client_message = color_lib.fromRGB( 255, 241, 122 )
    color_scheme.client_error = color_lib.fromRGB( 255, 221, 102 )

    color_scheme.menu_message = color_lib.fromRGB( 100, 220, 100 )
    color_scheme.menu_error = color_lib.fromRGB( 120, 220, 100 )

    -- DreamWork
    color_scheme.dreamwork_main = color_lib.fromRGB( 180, 180, 255 )

    color_scheme.dreamwork_info = color_lib.fromRGB( 70, 135, 255 )
    color_scheme.dreamwork_warn = color_lib.fromRGB( 255, 130, 90 )
    color_scheme.dreamwork_error = color_lib.fromRGB( 250, 55, 40 )
    color_scheme.dreamwork_debug = color_lib.fromRGB( 0, 200, 150 )

    color_scheme.dreamwork_menu = color_lib.fromRGB( 75, 175, 80 )
    color_scheme.dreamwork_client = color_lib.fromRGB( 225, 170, 10 )
    color_scheme.dreamwork_server = color_lib.fromRGB( 5, 170, 250 )

    -- Dynamic
    if LUA_CLIENT then
        color_scheme.realm = color_scheme.dreamwork_client
        color_scheme.message = color_scheme.client_message
        color_scheme.error = color_scheme.client_error
    elseif LUA_MENU then
        color_scheme.realm = color_scheme.dreamwork_menu
        color_scheme.message = color_scheme.menu_message
        color_scheme.error = color_scheme.menu_error
    else
        color_scheme.realm = color_scheme.dreamwork_server
        color_scheme.message = color_scheme.server_message
        color_scheme.error = color_scheme.server_error
    end

end

do

    local string_hasPrefix = string.hasPrefix

    --- [SHARED AND MENU]
    ---
    --- Returns the value of the key in a table.
    ---
    ---@param tbl table The table.
    ---@param key any The key.
    ---@return any
    function raw.index( tbl, key )
        if isString( key ) then
            ---@cast key string
            if string_hasPrefix( key, "__" ) then
                return nil
            end
        end

        return raw_get( tbl, key )
    end

end

do

    ---@diagnostic disable-next-line: undefined-field
    local CompileString = _G.CompileString
    local getfenv, setfenv = std.getfenv, std.setfenv

    --- [SHARED AND MENU]
    ---
    --- Loads a string as
    --- a lua code chunk in the specified environment
    --- and returns function as a compile result.
    ---
    ---@param lua_code string The lua code chunk.
    ---@param chunk_name string | nil The lua code chunk name.
    ---@param env table | nil The environment of compiled function.
    ---@return function | nil fn The compiled function.
    ---@return string | nil msg The error message.
    function std.loadstring( lua_code, chunk_name, env )
        local fn = CompileString( lua_code, chunk_name or "=(loadstring)", false )
        if fn == nil then
            return nil, "lua code compilation failed"
        elseif isString( fn ) then
            ---@diagnostic disable-next-line: cast-type-mismatch
            ---@cast fn string
            return nil, fn
        else
            setfenv( fn, env or getfenv( 2 ) )
            return fn
        end
    end

end

-- BigInteger class
dofile( "dreamwork/std/types/big_integer.lua" )
sendfile( "dreamwork/std/types/big_integer.lua" )

-- -- BigFixed class
-- dofile( "dreamwork/std/types/big_fixed.lua" )
-- sendfile( "dreamwork/std/types/big_fixed.lua" )

-- -- ByteReader class
-- dofile( "dreamwork/std/types/binary_reader.lua" )
-- sendfile( "dreamwork/std/types/binary_reader.lua" )

-- -- ByteWriter class
-- dofile( "dreamwork/std/types/binary_writer.lua" )
-- sendfile( "dreamwork/std/types/binary_writer.lua" )

-- engine submodule
dofile( "dreamwork/engine.lua" )
sendfile( "dreamwork/engine.lua" )

-- error class
dofile( "dreamwork/std/types/error.lua" )
sendfile( "dreamwork/std/types/error.lua" )

local engine = dreamwork.engine

do

    ---@type integer | nil
    local required_stack_level

    std._R[ 1 ] = function( error_value )
        local stack_level = math_max( 1, required_stack_level or 1 )
        required_stack_level = nil

        return engine.hookCall( "dreamwork.lua.error", error_value, stack_level + 1 ) or error_value
    end

    ---@param value any
    ---@param stack_level integer | nil
    _G.error = dreamwork.detour.attach( function( fn, value, stack_level )
        required_stack_level = stack_level

        ---@diagnostic disable-next-line: need-check-nil
        return fn( value, stack_level )
    end, error )

    local debug_ispcall = debug.ispcall
    local isError = std.isError

    local runtime_error = std.RuntimeError()
    local runtime_stack = debug.Stack()
    runtime_error.stack = runtime_stack

    do

        engine.hookCatch( "dreamwork.lua.error", "console.display", function( error_value, stack_level )
            if isError( error_value ) then
                ---@cast error_value dreamwork.std.Error

                for i = stack_level + 2, 2, -1 do
                    error_value:capture( i )
                    if not error_value:isEmpty() then break end
                end

                error_value:display()
            else
                error_value = tostring( error_value )
                ---@cast error_value string

                for i = stack_level + 2, 2, -1 do
                    runtime_stack:capture( i )
                    if not runtime_stack:isEmpty() then break end
                end

                runtime_error.message = string_match( error_value, "^[^:]+:%d+: ([^\n]+)" ) or error_value
                runtime_error:display()
                runtime_stack:clear()
            end

            return "The original error message was caught by dreamwork, see above for details about the error.", 2
        end, 1000 )

    end

    --- [SHARED AND MENU]
    ---
    --- Throws an error with the specified message and level.
    ---
    ---@param value? any The error value to throw.
    ---@param stack_level? integer The stack level to throw the error.
    ---@param dont_break? boolean If `true`, the error will not break the current stack.
    local function std_error( value, stack_level, dont_break )
        if value == nil then
            value = "unknown error"
        elseif isError( value ) then
            ---@cast value dreamwork.std.Error

            for i = math_max( 1, stack_level or 1 ) + 1, 2, -1 do
                value:capture( i )
                if not value:isEmpty() then break end
            end

            if dont_break then
                value:display()
                return
            end

            required_stack_level = stack_level
            return error( value, stack_level )
        end

        if dont_break then
            for i = math_max( 1, stack_level or 1 ) + 1, 2, -1 do
                runtime_stack:capture( i )
                if not runtime_stack:isEmpty() then break end
            end

            runtime_error.message = tostring( value )
            runtime_error:display()
            runtime_stack:clear()
            return
        end

        if not (isString( value ) or debug_ispcall( 2 )) then
            value = tostring( value )
        end

        ---@cast value string

        required_stack_level = stack_level
        return error( value, stack_level )
    end

    std.error = std_error

    --- [SHARED AND MENU]
    ---
    --- Throws an error with the specified message and level.
    ---
    ---@param stack_level? integer The stack level to throw the error.
    ---@param dont_break? boolean If `true`, the error will not break the current stack.
    ---@param fmt string The error message to throw.
    ---@param ... any The error message arguments to format/interpolate.
    function std.errorf( stack_level, dont_break, fmt, ... )
        return std_error( string_format( fmt, ... ), (stack_level or 1) + 1, dont_break )
    end

    --- [SHARED AND MENU]
    ---
    --- Throws an error if the given expression is false.
    ---
    ---@param expression boolean The expression to check.
    ---@param fmt string The error message to throw.
    ---@param ... any The error message arguments to format/interpolate.
    function std.assert( expression, fmt, ... )
        if expression then return end

        return std_error( string_format( fmt, ... ), 2, false )
    end

end

local TypeError = std.TypeError
local error = std.error

do

    local debug_getlocal = debug.getlocal
    local debug_getinfo = debug.getinfo

    local is = std.is
    local eq = std.eq

    --- [SHARED AND MENU]
    ---
    --- Checks that the local variable at the given stack `index` (in the calling function)
    --- matches one of the expected types/classes given in `...`. If the value's type/instance
    --- does not match any of the expected types, a `TypeError` is raised, otherwise the
    --- function returns without doing anything.
    ---
    ---@param index integer The stack index of the local variable to check (as used by `debug.getlocal`).
    ---@param ... any The expected type names (strings) or class/type tables (with an optional `__type` field) to check the value against.
    function std.checktype( index, ... )
        local value_name, value = debug_getlocal( 2, index )
        local value_type = type( value )

        local count = raw_select( "#", ... )

        for i = 1, count, 1 do
            local expected = raw_select( i, ... )
            if isString( expected ) then
                if expected == value_type then return end
            elseif eq( expected, value ) then
                return
            elseif is( value, expected ) then
                return
            end
        end

        ---@type string
        local expected_names

        for i = 1, count, 1 do
            local expected = raw_select( i, ... )
            if isString( expected ) then
                expected_name = expected
            elseif isTable( expected ) then
                expected_name = expected.__type or represent( expected )
            else
                expected_name = represent( expected )
            end

            if i == 1 then
                expected_names = expected_name
            else
                expected_names = expected_names .. ", " .. expected_name
            end
        end

        return error( TypeError( index, value, expected_names, value_name, debug_getinfo( 2, "n" ).name ), 2 )
    end

end

do

    ---@generic F: function
    ---@class dreamwork.OverloadInput<F>
    ---@field match string[] | string
    ---@field fn F

    ---@generic F: function
    ---@param inputs dreamwork.OverloadInput[]
    ---@param ... any
    ---@return function | nil
    local function input_select( inputs, ... )
        ---@type integer
        local arg_count = raw_select( "#", ... )

        ---@type string[]
        local arg_types = {}

        for i = 1, arg_count, 1 do
            arg_types[ i ] = type( raw_select( i, ... ) )
        end

        for i = 1, inputs[ 0 ], 1 do
            local input = inputs[ i ]
            local match = input.match

            if arg_count == match[ 0 ] then
                for j = 1, arg_count, 1 do
                    if match[ j ] ~= arg_types[ j ] then
                        break
                    end

                    if j == arg_count then
                        return input.fn
                    end
                end
            end
        end

        return nil
    end

    --- [SHARED AND MENU]
    ---
    --- Overloads the given function with the given inputs.
    ---
    ---@generic F: function
    ---@param inputs dreamwork.OverloadInput<F>[]
    ---@param fallback_fn? F
    ---@return F fn_over
    function std.dispatch( inputs, fallback_fn )
        local input_count = len( inputs )
        inputs[ 0 ] = input_count

        for i = 1, input_count, 1 do
            local input = inputs[ i ]
            if not isFunction( input.fn ) then
                error( TypeError( i, input.fn, "function", "fn", "dispatch" ), 2 )
            end

            local input_match = input.match
            if input_match == nil then
                error( TypeError( i, input.fn, "string, string[]", "match", "dispatch" ), 2 )
            elseif isString( input_match ) then
                ---@cast input_match string
                input.match = { [ 0 ] = 1, input_match }
            else
                input_match[ 0 ] = len( input_match )
            end
        end

        return function( ... )
            local fn = input_select( inputs, ... )
            if fn == nil then
                if fallback_fn == nil then
                    error( "dispatch: no input matches and no fallback function", 2 )
                    return
                end

                return fallback_fn( ... )
            end

            return fn( ... )
        end
    end

end

--- [SHARED AND MENU]
---
--- Overloads the given function with the given inputs.
---
---@generic F: function
---@param main_fn function
---@param match string[] | string
---@param overload_fn function
---@return function
function std.overload( main_fn, match, overload_fn )
    ---@type integer
    local required_args = 0

    if isString( match ) then
        ---@cast match string
        required_args = 1
    else

        ---@cast match string[]

        required_args = len( match )

        if required_args == 1 then
            match = match[ 1 ]
        end

    end

    if required_args == 0 then
        return main_fn
    elseif required_args == 1 then
        ---@cast match string

        return function( ... )
            ---@type integer
            local arg_count = raw_select( "#", ... )
            if arg_count ~= 1 then
                return main_fn( ... )
            end

            if match == type( raw_select( 1, ... ) ) then
                return overload_fn( ... )
            else
                return main_fn( ... )
            end
        end
    end

    return function( ... )
        ---@type integer
        local arg_count = raw_select( "#", ... )
        if arg_count == required_args then
            for i = 1, arg_count, 1 do
                if match[ i ] ~= type( raw_select( i, ... ) ) then
                    break
                end

                if i == arg_count then
                    return overload_fn( ... )
                end
            end
        end

        return main_fn( ... )
    end
end

do

    local loadstring = std.loadstring
    local math_floor = math.floor

    local empty_env = {}

    setmetatable( empty_env, {
        __index = debug_fempty,
        __newindex = debug_fempty
    } )

    --- [SHARED AND MENU]
    ---
    --- Creates a function that accepts a variable
    --- number of arguments and returns them in
    --- the order of the specified indices.
    ---
    --- | `junction(...)` call | `fjn(...)` call | result `...` |
    --- | ---------------------|-----------------|--------------|
    --- | `junction(1)`        | `(A, B, C)`     | `A`          |
    --- | `junction(2)`        | `(A, B, C)`     | `B`          |
    --- | `junction(3)`        | `(A, B, C)`     | `C`          |
    --- | `junction(2, 1)`     | `(A, B, C)`     | `B, A`       |
    --- | `junction(3, 1, 2)`  | `(X, Y, Z)`     | `Z, X, Y`    |
    ---
    ---@param ... integer The indices of arguments to return.
    ---@return function fjn The created junction function.
    function std.junction( ... )
        local out_arg_count = raw_select( '#', ... )
        local out_args = { ... }

        local in_arg_count = 0

        for i = 1, out_arg_count, 1 do
            local value = out_args[ i ]
            if isNumber( value ) and (value % 1) == 0 then
                out_args[ i ] = math_floor( value )
                in_arg_count = math_max( in_arg_count, value )
            else
                std.error( TypeError( i, value, "integer", "1", "junction" ), 2 )
            end
        end

        local locals, local_count = {}, 0

        for i = 1, in_arg_count, 1 do
            local_count = local_count + 1
            locals[ local_count ] = "a" .. i
        end

        local returns, return_count = {}, 0

        for i = 1, out_arg_count, 1 do
            return_count = return_count + 1
            returns[ return_count ] = "a" .. out_args[ i ]
        end

        local fn, err_msg = loadstring( "local " .. table_concat( locals, ",", 1, local_count ) .. " = ...\r\nreturn " .. table_concat( returns, ",", 1, return_count ), "junction", empty_env )
        if fn == nil then
            error( err_msg, 2 )
        end

        return fn
    end

end

do

    local engine_consoleMessage = engine.consoleMessage

    --- [SHARED AND MENU]
    ---
    --- Prints the given arguments to the console.
    ---
    ---@param ... any The arguments to print.
    ---@diagnostic disable-next-line: duplicate-set-field
    function std.print( ... )
        local arg_count = raw_select( "#", ... )
        if arg_count == 0 then
            engine_consoleMessage( "\n" )
        elseif arg_count == 1 then
            engine_consoleMessage( represent( ... ) .. "\n" )
        else
            local args = { ... }

            for arg_num = 1, arg_count, 1 do
                args[ arg_num ] = represent( args[ arg_num ] )
            end

            engine_consoleMessage( table_concat( args, "\t", 1, arg_count ) .. "\n" )
        end
    end

    --- [SHARED AND MENU]
    ---
    --- Prints a formatted string to the console.
    ---
    --- Basically the same as `print( string.format( fmt, ... ) )`
    ---@param fmt string The format string.
    ---@param ... any The arguments to format/interpolate.
    function std.printf( fmt, ... )
        return engine_consoleMessage( string_format( fmt, ... ) .. "\n" )
    end

    do

        local engine_consoleMessageColored = engine.consoleMessageColored
        local realm_color = color_scheme.realm

        local color_fromHex = std.color.fromHex
        local tocolor = std.tocolor

        --- [SHARED AND MENU]
        ---
        --- Prints the given arguments to the console with colors!
        ---
        ---@param ... any The arguments to print.
        function std.printc( ... )
            local color = realm_color
            local args = { ... }

            for ang_num = 1, raw_select( "#", ... ), 1 do
                local value = args[ ang_num ]
                if isString( value ) then
                    ---@cast value string

                    if string_byte( value, 1, 1 ) == 0x23 --[[ # ]] and string_len( value ) < 10 then
                        color = color_fromHex( value )
                    else
                        engine_consoleMessageColored( value, color )
                    end
                else
                    ---@cast value any
                    engine_consoleMessageColored( represent( value ), tocolor( value ) or color )
                end
            end

            engine_consoleMessage( "\n" )
        end

        -- TODO: rewrite function below with goto

        --- [SHARED AND MENU]
        ---
        --- Prints a formatted string to the console with colors!
        ---
        --- Works very similarly to `printf`, but supports an additional `%C` specifier for colors.
        ---
        ---@param fmt string The format string.
        ---@param ... any The arguments to format/interpolate.
        function std.printfc( fmt, ... )
            local fmt_length = string_len( fmt )
            if fmt_length == 0 then
                return
            end

            fmt = fmt .. "\n"
            fmt_length = fmt_length + 1

            local arg_count = raw_select( "#", ... )
            local arg_index = 0
            local args = { ... }

            local color = realm_color
            local break_point = 1
            local index = 0

            local buffer, buffer_length = {}, 0

            while index ~= fmt_length do
                index = index + 1

                local uint8_1 = string_byte( fmt, index, index )
                if uint8_1 == 0x25 --[[ % ]] then
                    if (index - break_point) ~= 0 then
                        buffer_length = buffer_length + 1
                        buffer[ buffer_length ] = string_sub( fmt, break_point, index - 1 )
                    end

                    if index == fmt_length then
                        buffer_length = buffer_length + 1
                        buffer[ buffer_length ] = "%"
                        break_point = index
                        break
                    end

                    index = index + 1
                    break_point = index + 1

                    local uint8_2 = string_byte( fmt, index, index )

                    if uint8_2 == 0x25 --[[ % ]] or uint8_2 == 0x7B --[[ { ]] or uint8_2 == 0x7D --[[ } ]] then
                        buffer_length = buffer_length + 1
                        buffer[ buffer_length ] = string_char( uint8_2 )
                    else

                        arg_index = arg_index + 1

                        if arg_index > arg_count then
                            std.errorf( 2, false, fmt, "Argument #%d [%s] to 'printfc' is missing!", arg_index, string_char( uint8_1, uint8_2 ) )
                        end

                        if uint8_2 == 0x43 --[[ C ]] then
                            if buffer_length ~= 0 then
                                engine_consoleMessageColored( table_concat( buffer, "", 1, buffer_length ), color )
                                buffer_length = 0
                            end

                            color = tocolor( args[ arg_index ] ) or color
                        else
                            buffer_length = buffer_length + 1
                            buffer[ buffer_length ] = string_format( string_char( uint8_1, uint8_2 ), args[ arg_index ] )
                        end

                    end
                elseif uint8_1 == 0x7B --[[ { ]] then
                    ---@type integer | nil
                    local end_index

                    for i = index, fmt_length, 1 do
                        if string_byte( fmt, i, i ) == 0x7D --[[ } ]] then
                            end_index = i
                            break
                        end
                    end

                    if end_index ~= nil then
                        if (index - break_point) ~= 0 then
                            buffer_length = buffer_length + 1
                            buffer[ buffer_length ] = string_sub( fmt, break_point, index - 1 )
                        end

                        if buffer_length ~= 0 then
                            engine_consoleMessageColored( table_concat( buffer, "", 1, buffer_length ), color )
                            buffer_length = 0
                        end

                        index = index + 1

                        if (end_index - index) == 0 then
                            color = realm_color
                        else
                            local color_str = string_sub( fmt, index, end_index - 1 )
                            if string_byte( color_str, 1, 1 ) == 0x23 --[[ # ]] then
                                color = color_fromHex( color_str )
                            else
                                color = color_scheme[ color_str ] or realm_color
                            end
                        end

                        index = end_index
                        break_point = end_index + 1
                    end
                end
            end

            if break_point < fmt_length then
                buffer_length = buffer_length + 1
                buffer[ buffer_length ] = string_sub( fmt, break_point, fmt_length )
            end

            if buffer_length ~= 0 then
                engine_consoleMessageColored( table_concat( buffer, "", 1, buffer_length ), color )
            end
        end

    end

end

-- futures library
dofile( "dreamwork/std/futures.lua" )
sendfile( "dreamwork/std/futures.lua" )

do

    local futures = std.futures
    local futures_sleep = futures.sleep
    local futures_running = futures.running

    --- [SHARED AND MENU]
    ---
    --- Puts current thread to sleep for given amount of seconds.
    ---
    --- **CAUTION**: This function could pause the main thread.
    ---
    ---@see dreamwork.std.futures.sleep
    ---@param seconds number
    function std.sleep( seconds )
        if futures_running() == nil then -- main thread
            local deadline = SysTime() + seconds
            while SysTime() < deadline do end

            return
        end

        futures_sleep( seconds ) -- second thread
    end

end

-- json encoding library
dofile( "dreamwork/std/codec/json.lua" )
sendfile( "dreamwork/std/codec/json.lua" )

-- xml encoding library
dofile( "dreamwork/std/codec/xml.lua" )
sendfile( "dreamwork/std/codec/xml.lua" )

-- vdf encoding library
dofile( "dreamwork/std/codec/vdf.lua" )
sendfile( "dreamwork/std/codec/vdf.lua" )

-- url class
dofile( "dreamwork/std/types/url.lua" )
sendfile( "dreamwork/std/types/url.lua" )

--- [SHARED AND MENU]
---
--- A collection of cryptographic utilities.
---
---@class dreamwork.std.crypto
std.crypto = std.crypto or {}

---@alias dreamwork.std.HashClass.digest fun( data: string ): string

---@class dreamwork.std.HashClass : dreamwork.std.Class
---@field digest dreamwork.std.HashClass.digest The digest function.
---@field digest_size integer The size of the digest in bytes.
---@field block_size integer The size of the block in bytes.

-- md5 hash library
dofile( "dreamwork/std/crypto/md5.lua" )
sendfile( "dreamwork/std/crypto/md5.lua" )

-- sha1 hash library
dofile( "dreamwork/std/crypto/sha1.lua" )
sendfile( "dreamwork/std/crypto/sha1.lua" )

-- sha256 hash library
dofile( "dreamwork/std/crypto/sha256.lua" )
sendfile( "dreamwork/std/crypto/sha256.lua" )

-- sha512 hash library
dofile( "dreamwork/std/crypto/sha512.lua" )
sendfile( "dreamwork/std/crypto/sha512.lua" )

-- hmac library
dofile( "dreamwork/std/crypto/hmac.lua" )
sendfile( "dreamwork/std/crypto/hmac.lua" )

-- pbkdf2 library
dofile( "dreamwork/std/crypto/pbkdf2.lua" )
sendfile( "dreamwork/std/crypto/pbkdf2.lua" )

-- TODO: crypto.ed25519 & crypto.chacha20/xchacha

-- uuid library
dofile( "dreamwork/std/uuid.lua" )
sendfile( "dreamwork/std/uuid.lua" )

-- mixin
dofile( "dreamwork/std/types/mixin.lua" )
sendfile( "dreamwork/std/types/mixin.lua" )

-- hook class
dofile( "dreamwork/std/types/hook.lua" )
sendfile( "dreamwork/std/types/hook.lua" )

-- timer class
dofile( "dreamwork/std/engine/types/timer.lua" )
sendfile( "dreamwork/std/engine/types/timer.lua" )

if dreamwork.TickTimer0_05 == nil then
    local timer = std.Timer( 0.05, 0, dreamwork.Prefix .. "::TickTimer0_05" )
    dreamwork.TickTimer0_05 = timer
    timer:start()
end

if dreamwork.TickTimer0_1 == nil then
    local timer = std.Timer( 0.1, 0, dreamwork.Prefix .. "::TickTimer0_1" )
    dreamwork.TickTimer0_1 = timer
    timer:start()
end

if dreamwork.TickTimer0_25 == nil then
    local timer = std.Timer( 0.25, 0, dreamwork.Prefix .. "::TickTimer0_25" )
    dreamwork.TickTimer0_25 = timer
    timer:start()
end

if dreamwork.TickTimer1 == nil then
    local timer = std.Timer( 1, 0, dreamwork.Prefix .. "::TickTimer1" )
    dreamwork.TickTimer1 = timer
    timer:start()
end

do

    ---@class dreamwork.std
    ---@field SYSTEM_COUNTRY string The country code of the operating system. (ISO 3166-1 alpha-2)
    ---@field SYSTEM_HAS_BATTERY boolean `true` if the operating system has a battery, `false` if not.
    ---@field SYSTEM_BATTERY_LEVEL integer The battery level, from `0` to `100`.

    local glua_system = system or {}

    std.SYSTEM_COUNTRY = string.lower( (glua_system.GetCountry or debug_fempty)() or "eu" )

    local system_BatteryPower = glua_system.BatteryPower
    if system_BatteryPower ~= nil then

        local battery_power = 0

        local function update_battery()
            if battery_power ~= system_BatteryPower() then
                battery_power = system_BatteryPower()

                if battery_power == 255 then
                    std.SYSTEM_HAS_BATTERY = false
                    std.SYSTEM_BATTERY_LEVEL = 100
                else
                    std.SYSTEM_HAS_BATTERY = true
                    std.SYSTEM_BATTERY_LEVEL = battery_power
                end
            end
        end

        dreamwork.TickTimer1:attach( update_battery, "dreamwork::battery" )
        update_battery()

    end

    if LUA_CLIENT_MENU then

        local system_HasFocus = glua_system.HasFocus
        if system_HasFocus ~= nil then

            ---@class dreamwork.std.window
            ---@field focus boolean `true` if the game's window has focus, `false` otherwise.
            local window = std.window

            local has_focus = system_HasFocus()
            window.focus = has_focus

            dreamwork.TickTimer0_05:attach( function()
                if has_focus ~= system_HasFocus() then
                    has_focus = not has_focus
                    window.focus = has_focus
                end
            end, "dreamwork::window_focus" )

        end

    end

end

-- 2d vector class
dofile( "dreamwork/std/types/vector2.lua" )
sendfile( "dreamwork/std/types/vector2.lua" )

-- 3d vector class
dofile( "dreamwork/std/types/vector3.lua" )
sendfile( "dreamwork/std/types/vector3.lua" )

-- quaternion class
dofile( "dreamwork/std/types/quaternion.lua" )
sendfile( "dreamwork/std/types/quaternion.lua" )

-- 3d angle class
dofile( "dreamwork/std/types/angle3.lua" )
sendfile( "dreamwork/std/types/angle3.lua" )

-- valve matrix class
dofile( "dreamwork/std/types/vmatrix.lua" )
sendfile( "dreamwork/std/types/vmatrix.lua" )

-- engine console library
dofile( "dreamwork/std/io/console.lua" )
sendfile( "dreamwork/std/io/console.lua" )

local console = std.console

if os.exit == nil then

    --- [SHARED AND MENU]
    ---
    --- Calls the ISO C function exit to terminate the host program.
    ---
    function os.exit()
        console.Command.run( "_restart" )
    end

end

local developer = console.Variable.get( "developer", "integer" )
if developer == nil then
    std.DEVELOPER = 1
else
    developer:attach( function( _, new_value )
        std.DEVELOPER = new_value
    end, "dreamwork.std", false )

    std.DEVELOPER = developer.value
end

local logger = console.Logger( {
    color = color_scheme.dreamwork_main,
    title = dreamwork.Prefix,
    interpolation = false
} )

if std.LUA_VERSION ~= "Lua 5.1" then
    logger:warn( "Lua version changed, possible unpredictable behavior. (" .. std.LUA_VERSION .. ")" )
end

dreamwork.Logger = logger

-- file system library
dofile( "std/io/fs.lua" )
sendfile( "std/io/fs.lua" )

-- lzw compression library
dofile( "dreamwork/std/compress/lzw.lua" )
sendfile( "dreamwork/std/compress/lzw.lua" )

-- lz4 compression library
dofile( "dreamwork/std/compress/lz4.lua" )
sendfile( "dreamwork/std/compress/lz4.lua" )

-- deflate compression library
dofile( "dreamwork/std/compress/deflate.lua" )
sendfile( "dreamwork/std/compress/deflate.lua" )

-- lzma compression library
dofile( "dreamwork/std/compress/lzma.lua" )
sendfile( "dreamwork/std/compress/lzma.lua" )

-- sqlite library
dofile( "std/db/sqlite.lua" )
sendfile( "std/db/sqlite.lua" )

-- Welcome message
do

    local variables = {}

    local cvar = console.Variable.get( LUA_SERVER and "hostname" or "name", "string" )
    if cvar ~= nil then
        local value = cvar.value
        if not string.isEmpty( value ) and value ~= "unnamed" then
            variables.username = value
        end
    end

    if variables.username == nil then
        variables.username = std.DEVELOPER ~= 0 and "develoer" or "stranger"
    end

    local splashes = {
        "We'll Sandblast these walls and paint them again ♪",
        ";fix these broken wings, then show me how to fly ♪",
        "And I feel like I could spread my wings and fly ♪",
        "They'll wait for me to fall under the pressure ♪",
        "nf2ca53pnz2caytfebzw6idfmfzxsidun4qho2lo * 0.5",
        "eW91dHViZS5jb20vd2F0Y2g/dj1kUXc0dzlXZ1hjUQ==",
        "Woah-oh-oh, tell me where you wanna go ♪",
        "Let's write our names here in the sky ♪",
        "We will have a great Future together.",
        "Millions of pieces without a tether ♪",
        "It always seems time is on the side ♪",
        "Why are we always looking for more ♪",
        "Never forget to finish your Task's!",
        "They'll wait for me to give it up ♪",
        "I don't care who I'm meant to be ♪",
        "Take it in and breathe the light ♪",
        "T2gsIHlvdSdyZSBhIHNtYXJ0IG9uZS4=",
        "I'm tired of these darker days ♪",
        "Don't worry, {username} :>",
        "Big Brother is watching you",
        "As we build it once agai1n ♪",
        "I'm turning the lights on ♪",
        "I'm calling out for help ♪",
        "I'll make you a promise.",
        "Flying over rooftops...",
        "Hello, {username}!",
        "Dream + Framework = <3",
        "We need more packages!",
        "Pew-pew-pew-pew-pew! ♪",
        "Play SOMA sometime;",
        "Where's fireworks!?",
        "Let the sun arise ♪",
        "Looking For More ♪",
        "I'm watching you.",
        "Faster than ever.",
        "Love Wins Again ♪",
        "Made with love <3",
        "I burn my sky ♪",
        "Blazing fast ☄",
        "Ancient Tech ♪",
        "Here For You ♪",
        "Good Enough ♪",
        "Manifest It ♪",
        "MAKE A MOVE ♪",
        "v" .. dreamwork.Version,
        "Hello World!",
        "all_the_same",
        "Star Glide ♪",
        "Once Again ♪",
        "Without Us ♪",
        "Data Loss ♪",
        "Sandblast ♪",
        "Now on LLS!",
        "That's me!",
        "I see you.",
        "Light Up ♪",
        "Majesty ♪",
        "Eat Me ♪",
        "FLY ♪"
    }

    local count = #splashes + 1
    splashes[ count ] = "Wow, there are over " .. (count - 1) .. " splashes here!"

    local scheme

    if std.SYSTEM_WINDOWS --[[ ha-ha microslop ]] then
        scheme = {
            "       / *    .      +                                                         ⣀⣀⣤⠤⢤⣀⠀ ",
            "  .   /                        /  '           '                         ⢀⣠⠴⠒⢋⣉⣀⣠⣄⣀⣈⡇   ",
            "     *   .         '          /           *                   ⠀⠀⠀⠀⣠⣴⣾⣯⠴⠚⠉⠉⠀⠀⠀⠀⣤⠏⣿      ",
            "   *    * %s                                                 ⠀⣠⣴⡿⠿⢛⠁⠁⣸⠀⠀⠀⠀⠀⣤⣾⠵⠚⠁      ",
            "'                +   +                    _|_     '    *  ⠀⣠⣴⠿⠋⠁⠀⠀⠀⠀⠘⣿⠀⣀⡠⠞⠛⠁⠂⠁⠀⠀      ",
            "       .                             .      |         ⠀⠀⣀⣴⠟⠋⠁⠀⠀⠀⠀⠐⠠⡤⣾⣙⣶⡶⠃⠀⠀⠀⠀⠀⠀⠀       ",
            "⠉                ____    o  +   .    +                ⣤⢾⣋⠉        __ ⡴⢿⢛⠃              ",
            "⠄       o       / __ \\_____ __  __ _ _ __ _____     ⣴⡼⢏⠑__  _____/ /__ ⢿               ",
            "⠂⠂      .      / / / /⠁⠁⠁//_ \\/ _` | '_ ` _ \\ \\ /\\ / / _  \\/ ___/ //_/                 ",
            "⠁   +       ⣀⣴/ /_/ / /⠞⠁/ __/ (_) | | | | | \\ V  V / (_) / /  / ,<                    ",
            "         ⣠⢴⣿⠟/_____/_/  ⠞\\___|\\__,_|_| |_| |_|\\_/\\_/ \\___/_/  /_/|_|                   ",
            "⠀⠀⠀⠀⠀⢀⡴⢏⡵⠛⠀⠀⠀⠀⠀⠀⠀⣀⣴⠞⠛                                                                  ",
            "⠀⠀⠀⣀⣼⠛⣲⡏⠁⠀⠀⠀⠀⠀⢀⣠⡾⠋⠉⠁⠁⠁        .-.    o  +   .    |                                     ",
            "⠀⠀⡴⠟⠀⢰⡯⠄⠀⠀⠀⠀⣠⢴⠟⠉ ⠁              ) )             --o--                                  ",
            "⠀⡾⠁⠁⠀⠘⠧⠤⢤⣤⠶⠏⠙⠁    *     *       '-´   ⠁   ⠁    ⠁  |                                    ",
            "⠘⣇⠂⢀⣀⣀⠤⠞⠋                                                                              ",
            "⠀⠈⠉⠉⠉     .      +                      *   '      '        +                          ",
            "╭────⋆⋅☆⋅⋆──────⋆⋅☆⋅⋆──────⋆⋅☆⋅⋆──────⋆⋅☆⋅⋆──ˎˊ˗                                       ",
            "┊  GitHub: https://github.com/Pika-Software                                            ",
            "┊  Discord: https://discord.gg/Gzak99XGvv                                              ",
            "┊  Website: https://p1ka.eu                                                            ",
            "┊  Developers: Pika Software                                                           ",
            "┊  License: MIT                                                                        ",
            "╰────⋆⋅☆⋅⋆──────⋆⋅☆⋅⋆──────⋆⋅☆⋅⋆──────⋆⋅☆⋅⋆──ˎˊ˗                                       "
        }
    else
        scheme = {
            "               /          .      +           /                                    ",
            "          .   *                             /  '           '     .                ",
            "   .             .             '           /           *                `         ",
            "                     +                    *        *                         .    ",
            "     '              /                                 _|_     '    *              ",
            "           ,       +            .            .         |              +     |     ",
            "            '       \\            \\                       .     '          --o--   ",
            "  `      * .         +            \\          ,                         '    |     ",
            "             ____                  \\        __        __            __            ",
            "    .       / __ \\ ____ __   __ __  __ ____\\  \\      /  /___  _____/ /__ ` .     .",
            "   /   .   / / / / __// _ \\ /  _` || '_ ` _ \\  \\ __ /  / _  \\/ ___/ //_/  `     / ",
            "  /   /   / /_/ / /  /  __//  (_) || | | | | \\  V  V  / (_) / /  / ,<\\         /  ",
            " *   *   /_____/_/   \\ ___|\\ __/__||_| |_| |_|\\ _/\\_/ \\ ___/_/  /_/|_|        /   ",
            "  ,                 .      +              \\                 '                *    ",
            "       +         \\  %s                                                  `          ",
            "  .               \\              *           \\               *              ,     ",
            "     .-.    `      *                          *        |         '                ",
            "      ) )               *     '                      --o--         ,   +          ",
            "     '-´                           *                   |                          ",
            "         '        +           *           *   '               +                   ",
            "|>|================================================= ` .                          ",
            "|=| -  GitHub:   https://github.com/Pika-Software  /  `                           ",
            "|<| - Discord:   https://discord.gg/Gzak99XGvv    /                               ",
            "|=| - Website:   https://p1ka.eu                 /                                ",
            "|<| - DevTeam:   Pika Software                  /                                 ",
            "|=| - License:   MIT                           /                                  ",
            "|>|___________________________________________/                                   "
        }
    end

    local welcome_art = string.gsub( table_concat( scheme, "\n", 1 ), "%%s" .. string.rep( " ", 50 - 1 ), "%%s" )
    local splash = string.interpolate( splashes[ math.random( 1, count ) ], variables )

    std.printfc( "\n" .. welcome_art .. "\n", string.pad( splash, 50, " ", nil, std.utf8.len( splash ) ) )

end

-- https://github.com/wrefgtzweve/gm_getregistry
if std.loadbinary( "getregistry" ) and getregistry ~= nil then
    debug.setregistry( (getregistry.Get or debug.getregistry)() )
    logger:info( "'gm_getregistry' was loaded & connected, enjoy full access to `debug.getregistry`." )
end

-- https://github.com/willox/gmbc
if std.loadbinary( "gmbc" ) then
    logger:info( "'gmbc' was loaded & connected as LuaJIT bytecode compiler." )
else
    logger:warn( "'gmbc' is missing, bytecode compilation not available." )
end

do

    ---@diagnostic disable-next-line: undefined-global
    local gmbc_load_bytecode = gmbc_load_bytecode

    if gmbc_load_bytecode == nil then
        ---@diagnostic disable-next-line: duplicate-set-field
        function std.loadbytecode()
            error( "bytecode compilation not available.", 2 )
        end
    else

        --- [SHARED AND MENU]
        ---
        --- Loads a string as
        --- a bytecode chunk in the specified environment
        --- and returns function as a compile result.
        ---
        ---@param bytecode string The luajit bytecode chunk.
        ---@param env table | nil The environment of compiled function.
        ---@return function | nil fn The compiled function.
        ---@return string | nil msg The error message.
        function std.loadbytecode( bytecode, env )
            local success, result = pcall( gmbc_load_bytecode, bytecode )
            if success then
                setfenv( result, env or getfenv( 2 ) )
                return result, nil
            end

            return nil, result
        end

    end

end

---@param game_info dreamwork.engine.GameInfo
---@param is_mounted boolean
engine.hookCatch( "dreamwork.game.mount", "logs", function( game_info, is_mounted )
    logger:debug( "Game '%s' (AppID: %d) was %s.", game_info.folder, game_info.depot, is_mounted and "mounted" or "unmounted" )
end )

---@param addon_info dreamwork.engine.AddonInfo
---@param is_mounted boolean
engine.hookCatch( "dreamwork.addon.mount", "logs", function( addon_info, is_mounted )
    logger:debug( "Addon '%s' (%d) was %s.", addon_info.title, addon_info.index, is_mounted and "mounted" or "unmounted" )
end )

do

    local changes_timeout = std.Timer( 0.5, 1, dreamwork.Prefix .. "::ContentWatcher" )

    local function perform_synchronization()
        logger:debug( "Game content change triggered, synchronization..." )
        time.tick( "ms", false )

        local game_changes, addon_changes = engine.hookCall( "dreamwork.content.update" )

        if game_changes == 0 and addon_changes == 0 then
            logger:debug( "No changes found, skipped." )
        else
            logger:debug( "Synchronization finished with %d game(s) and %d addon(s) in %d ms.", game_changes, addon_changes, time.tick( "ms", false ) )
        end
    end

    changes_timeout:attach( perform_synchronization )
    perform_synchronization()

    engine.hookCatch( "GameContentChanged", "dreamwork.content.update", function()
        changes_timeout:start()
    end, -1000 )

end

logger:info( "%d game(s) and %d add-on(s) mounted to game.", engine.GameCount, engine.AddonCount )

std.FRAME_TIME = 1 / 60
std.FPS = 60

---@diagnostic disable-next-line: undefined-global
if LUA_CLIENT and CurTime ~= nil then

    ---@diagnostic disable-next-line: undefined-global
    local CurTime = CurTime

    local last_call = CurTime()

    engine.hookCatch( "PreRender", "dreamwork.frame_counter", function()
        local elapsed_time = CurTime()

        local frame_time = elapsed_time - last_call
        last_call = elapsed_time

        std.FRAME_TIME = frame_time
        std.FPS = 1 / frame_time
    end, 1000 )

end

--- [SHARED AND MENU]
---
--- Returns the value of the process environment variable varname or fail if the variable is not defined.
---
---@param key string
---@return string value
function os.getenv( key )
    return ""
end

--- [SHARED AND MENU]
---
---
---
---@param package_name string
---@param package_version string
---@return any
function std.import( package_name, package_version )
    -- TODO: implement
end

--- [SHARED AND MENU]
---
--- Opens the named file and executes its content as a Lua chunk.
---
--- When called without arguments, `dofile` executes the content of the standard input (`stdin`).
---
--- Returns all values returned by the chunk. In case of errors, `dofile` propagates the error to its caller. (That is, `dofile` does not run in protected mode.)
---
--- [View documents](http://www.lua.org/manual/5.1/manual.html#pdf-dofile)
---
---@param file_path string
---@param ... any
---@return any ...
function std.dofile( file_path, ... )
    -- TODO: reimplement
end

--- [SHARED AND MENU]
---
--- Loads the given module, returns any value returned by the searcher(`true` when `nil`). Besides that value, also returns as a second result the loader data returned by the searcher, which indicates how `require` found the module. (For instance, if the module came from a file, this loader data is the file path.)
---
--- [View documents](http://www.lua.org/manual/5.1/manual.html#pdf-require)
---
---@param modname string
---@param ... any
---@return ...
function std.require( modname, ... )
    -- TODO: reimplement
end

local total_memory = gc.getMemory()
logger:info( "Start-up time: %.2f ms, memory used during startup: %.02f MB.", (SysTime() - dreamwork.InitTime) * 1000, (total_memory - startup_memory) / 1024 )

-- Memory clean-up
time.tick( "ms" )
gc.collect()

local cleanup_memory = gc.getMemory()
logger:info( "Clean-up finished, took %.2f ms, cleaned up %.02f MB of garbage, total memory used by LuaJIT: %.02f MB.", time.tick( "ms" ), (total_memory - cleanup_memory) / 1024, cleanup_memory / 1024 )

-- TODO: Globally replace all versions, steamids, url, etc. with their classes in dreamwork, e.g. std.URL, steam.Identifier

-- TODO: few ideas from https://gitlab.com/DBotThePony/DLib/-/blob/develop/lua_src/dlib/extensions/extensions.lua?ref_type=heads

-- TODO: enums https://gitlab.com/DBotThePony/DLib/-/blob/develop/lua_src/dlib/enums/sdk.lua?ref_type=heads maybe maybe https://gitlab.com/DBotThePony/DLib/-/blob/develop/lua_src/dlib/enums/gmod.lua?ref_type=heads

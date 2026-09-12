local glua_debug = debug

---@class dreamwork.std
local std = dreamwork.std

---@class dreamwork.std.raw
local raw = std.raw
local raw_get = raw.get

local xpcall = std.xpcall
local pcall = std.pcall
local error = std.error


--- [SHARED AND MENU]
---
--- The debug library is intended to help you debug your scripts,
--- however it also has several other powerful uses.
---
---@class dreamwork.std.debug : debuglib
--- [SHARED AND MENU]
---
--- Just empty function, do nothing.
---
--- Sometimes makes jit happy :>
---
---@field fempty fun()
--- [SHARED AND MENU]
---
--- Sets the metatable for the given value to the given table (which can be `nil`).
---
--- [View documents](http://www.lua.org/manual/5.1/manual.html#pdf-debug.setmetatable)
---
---@field setmetatable fun( object: any, metatable: ( dreamwork.std.Metatable | nil ) )
local debug = std.debug or {
    -- LuaJIT
    ---@diagnostic disable-next-line: deprecated
    newproxy = newproxy,
    fempty = function() end, -- yep, it's literally empty function

    -- Lua 5.1
    debug = glua_debug.debug, -- dont answer me

    getregistry = glua_debug.getregistry,
    traceback = glua_debug.traceback,

    setlocal = glua_debug.setlocal,

    getmetatable = glua_debug.getmetatable or std.getmetatable,
    setmetatable = glua_debug.setmetatable,

    getupvalue = glua_debug.getupvalue, -- fucked up in menu
    setupvalue = glua_debug.setupvalue, -- fucked up in menu

    ---@diagnostic disable-next-line: deprecated
    getfenv = glua_debug.getfenv or getfenv,

    ---@diagnostic disable-next-line: deprecated
    setfenv = glua_debug.setfenv or setfenv,

    gethook = glua_debug.gethook,
    sethook = glua_debug.sethook,

    -- Lua 5.2/jit
    upvalueid = glua_debug.upvalueid,       -- fucked up in menu
    upvaluejoin = glua_debug.upvaluejoin,   -- fucked up in menu

    getuservalue = glua_debug.getuservalue, -- fucked up in menu
    setuservalue = glua_debug.setuservalue, -- fucked up in menu
}

std.debug = debug

--- [SHARED AND MENU]
---
--- Returns a table with information about a function. You can give the
--- function directly, or you can give a number as the value of `location`, which
--- means the function running at level `location` of the call stack of the given
--- thread: level 0 is the current function (`getinfo` itself); level 1 is
--- the function that called `getinfo` (except for tail calls, which do not
--- count on the stack); and so on. If `location` is a number larger than the
--- number of active functions, then `getinfo` returns `nil`.
---
--- The parameter `what` (a string) controls which fields of the returned
--- table are filled in — see `dreamwork.std.debug.InfoWhat` for the list
--- of letters and what each one populates. The default (when `what` is
--- omitted) is to get all information, except the table of active lines.
---
--- If the option `"f"` is given, then `func` is set with the function
--- itself. If the option `"L"` is given, then `activelines` is set with
--- the table of active lines.
---
--- If `what` contains the `">"` modifier, `location` is
--- consumed as the value to inspect and treated as if it were passed via
--- the trailing argument rather than as a stack level — this lets you
--- write `debug.getinfo(thread, level, ">S")`-style calls where the
--- object being inspected is taken from the end of the argument list. See
--- the `">"` entry in `InfoWhat` for details.
---
--- [View documents](http://www.lua.org/manual/5.1/manual.html#pdf-debug.getinfo)
---
---@return dreamwork.std.debug.Info info The info for the given location, or `nil` if no info could be retrieved.
---@overload fun( location: function, what: dreamwork.std.debug.InfoWhat?, f: function? ): dreamwork.std.debug.Info
---@overload fun( location: integer, what: dreamwork.std.debug.InfoWhat?, f: function? ): dreamwork.std.debug.Info | nil
---@overload fun( thread: thread, location: function, what: dreamwork.std.debug.InfoWhat?, f: function? ): dreamwork.std.debug.Info
---@overload fun( thread: thread, location: integer, what: dreamwork.std.debug.InfoWhat?, f: function? ): dreamwork.std.debug.Info | nil
debug.getinfo = glua_debug.getinfo

--- [SHARED AND MENU]
---
--- Returns the name and the value of the local variable with index `local` of the function at level `stack_level` of the stack.
---
--- [View documents](http://www.lua.org/manual/5.1/manual.html#pdf-debug.getlocal)
---
---@overload fun( stack_level: integer, index: integer ): string, any
---@overload fun( thread: thread, stack_level: integer, index: integer ): string, any
debug.getlocal = glua_debug.getlocal

if debug.getmetatable == nil or debug.setmetatable == nil or debug.getinfo == nil then
    error( "execution environment is broken or sandboxed - it's over ;c" )
end

local debug_getmetatable = debug.getmetatable
local debug_getinfo = debug.getinfo
local debug_fempty = debug.fempty

--- [SHARED AND MENU]
---
--- Calls the given function or object with the given arguments.
---
---@param f function | any The function or object to call.
---@param ... any The arguments to pass to the function or object.
---@return any ... The result of execution.
function debug.fcall( f, ... )
    return f( ... )
end

if debug.newproxy == nil then

    local setmetatable = std.setmetatable

    ---@diagnostic disable-next-line: duplicate-set-field
    function debug.newproxy( add_metatable )
        local fake_userdata = {}

        if add_metatable then
            ---@type dreamwork.std.Metatable | nil
            local metatable

            if add_metatable == true then
                metatable = {}
            else
                metatable = debug_getmetatable( add_metatable )
            end

            setmetatable( fake_userdata, metatable )
        end

        ---@diagnostic disable-next-line: cast-type-mismatch
        ---@cast fake_userdata userdata

        return fake_userdata
    end

    raw.print( "newproxy is missing, fallback created!" )

end

--- [SHARED AND MENU]
---
--- Returns the value of the given key in the metatable of the given value.
---
--- Returns `nil` if not found.
---
---@param value any The value to get the metatable from.
---@param key string The searchable key.
---@return any | nil value The value of the given key.
function debug.getmetavalue( value, key, allow_index )
    local metatable = debug_getmetatable( value )
    if metatable == nil then
        return nil
    elseif allow_index then
        return metatable[ key ]
    else
        return raw_get( metatable, key )
    end
end

do

    local debug_getupvalue = debug.getupvalue

    --- [SHARED AND MENU]
    ---
    --- Returns all upvalues of the given function as a table, keyed by upvalue name.
    ---
    --- If the function is a C function (or otherwise has no debug info), an empty
    --- table and a count of `0` are returned.
    ---
    ---@param fn function The function to get upvalues from.
    ---@return table<string, any> values A table mapping each upvalue's name to its current value.
    ---@return integer value_count The number of upvalues found.
    function debug.getupvalues( fn )
        ---@type table<string, any>
        local values = {}

        local info = debug_getinfo( fn, "Su" )
        if info == nil or info.what == "C" then
            return values, 0
        end

        ---@type integer
        local count = info.nups or 0

        for i = 1, count, 1 do
            local key, value = debug_getupvalue( fn, i )
            if key == nil then
                count = count - 1
            else
                values[ key ] = value
            end
        end

        return values, count
    end

end

do

    local debug_getlocal = debug.getlocal

    --- [SHARED AND MENU]
    ---
    --- Returns all available local variables at the given stack level (and, optionally,
    --- in the given thread/coroutine) as a table keyed by variable name.
    ---
    ---@param stack_level? integer The stack level to inspect, relative to the caller (defaults to the immediate caller's frame). Cannot be negative.
    ---@param thread? thread The thread/coroutine to inspect. If omitted, the current thread is used.
    ---@return table<string, any> values A table mapping each local variable's name to its current value.
    ---@return integer value_count The number of locals found.
    function debug.getlocals( stack_level, thread )
        if stack_level == nil then
            stack_level = 2
        elseif stack_level >= 0 then
            stack_level = stack_level + 1
        else
            error( "stack level cannot be less than zero", 2 )
        end

        ---@type table<string, any>
        local values = {}

        ---@type integer
        local index = 1

        ::getlocals_loop::

        local key, value
        if thread == nil then
            key, value = debug_getlocal( stack_level, index )
        else
            key, value = debug_getlocal( thread, stack_level, index )
        end

        if key ~= nil then
            values[ key ] = value
            index = index + 1
            goto getlocals_loop
        end

        return values, index - 1
    end

end

--- [SHARED AND MENU]
---
--- Returns the function at the given stack level.
---
---@param level integer The stack level.
---@return function | nil The function at the given level, or `nil` if the level is invalid.
function debug.getf( level )
    local info = debug_getinfo( level + 1, "f" )
    if info == nil then
        return nil
    end

    return info.func
end

if raw.type == nil then

    local type = type

    local values, count = debug.getupvalues( type )

    if count == 0 or values.C_type == nil then
        raw.type = type
    else
        raw.type = values.C_type
    end

end

local raw_type = raw.type

--- [SHARED AND MENU]
---
--- Attempts to determine the name and kind of a function,
--- the same way the `n` option of the standard `debug.getinfo` does.
---
--- `location` can be either a function reference or a stack level
--- (an integer, where `1` is the function that called `getfname`).
---
--- Since Lua functions have no inherent name, this works by inspecting
--- how the function was called or accessed - e.g. as a global, a local variable,
--- a table field, a method, or an upvalue - and can fail to find anything,
--- in which case both results are `nil`.
---
---@param location? integer | function The function or stack level.
---@return string | nil name The name of the function, or `nil` if unknown.
---@return "global" | "local" | "method" | "field" | "upvalue" | nil name_what The kind of the function, or `nil` if unknown.
function debug.getfname( location )
    if location == nil then
        location = 2
    elseif raw_type( location ) == "number" then
        location = location + 1
    end

    local info = debug_getinfo( location, "n" )
    if info == nil then
        return nil, nil
    end

    local name_what = info.namewhat
    if name_what == "" then
        return info.name, nil
    end

    return info.name, name_what
end

--- [SHARED AND MENU]
---
--- Returns the path to the file that the function is defined in.
---
---@param f function | integer The function or stack level to get the path from.
---@return string | nil file_path The file path or `nil` if not found.
function debug.getfsource( f )
    local info = debug_getinfo( f, "S" )
    if info ~= nil then
        return info.source
    end

    return nil
end

--- [SHARED AND MENU]
---
--- Returns the main function of the current stack.
---
---@param stack_level? integer The stack `stack_level` to get the main function from.
---@return function | nil main_fn The main function or `nil` if not found.
function debug.getfmain( stack_level )
    if stack_level == nil then
        stack_level = 2
    elseif stack_level >= 0 then
        stack_level = stack_level + 1
    else
        error( "stack level cannot be less than zero", 2 )
    end

    ::getfmain_loop::

    local info = debug_getinfo( stack_level, "fS" )

    if info == nil then
        return nil
    elseif info.what == "main" then
        return info.func
    end

    stack_level = stack_level + 1
    goto getfmain_loop
end

--- [SHARED AND MENU]
---
--- Captures the current call stack, starting at `stack_level` relative to the caller
--- of this function, and returns it as a list of debug info tables.
---
---@param stack_level? integer The level to start capturing from, where `0` is the function that called `getstackinfo`. Default is `0`.
---@param what? dreamwork.std.debug.InfoWhat A string of `debug.getinfo`-style flags selecting which fields to populate per frame. Default is `"Snluf"`.
---@param head_skip? integer Number of extra frames to skip from the top ( nearest the caller ) before capturing begins. Default is `0`.
---@param tail_skip? integer Number of frames to drop from the bottom ( nearest the root ) of the captured stack after capturing ends. Default is `0`.
---@param max_levels? integer Maximum number of frames to read (after `head_skip` is applied). Stack walking stops as soon as this many frames have been collected, so no `debug.getinfo` call is made beyond that point. `tail_skip` is still applied afterward to this (already capped) set. `nil`/`0` means no limit.
---@return dreamwork.std.debug.Info[] stack A list of debug info tables, one per captured stack frame, ordered from `stack_level` outward.
---@return integer stack_size The number of entries in `stack` ( equivalent to `#stack` ).
function debug.getstack( stack_level, what, head_skip, tail_skip, max_levels )
    if stack_level == nil then
        stack_level = 2
    elseif stack_level >= 0 then
        stack_level = stack_level + 1
    else
        error( "stack level cannot be less than zero", 2 )
    end

    if head_skip ~= nil and head_skip > 0 then
        stack_level = stack_level + head_skip
    end

    ---@type dreamwork.std.debug.Info[]
    local stack = {}

    ---@type integer
    local stack_length = 0

    ::debug_getstack_loop::

    local info = debug_getinfo( stack_level, what )
    if info ~= nil then
        stack_length = stack_length + 1
        stack[ stack_length ] = info

        if max_levels == nil or stack_length < max_levels then
            stack_level = stack_level + 1
            goto debug_getstack_loop
        end
    end

    if tail_skip ~= nil and tail_skip > 0 then
        local trimmed_length = stack_length - tail_skip
        if trimmed_length <= 0 then
            return {}, 0
        end

        for i = trimmed_length + 1, stack_length, 1 do
            stack[ i ] = nil
        end

        return stack, trimmed_length
    end

    return stack, stack_length
end

--- [SHARED AND MENU]
---
--- Checks if the given function or stack level is a C function.
---
---@param location integer | function The function or stack level.
---@return boolean iscf `true` if the function is a C function, `false` otherwise.
function debug.iscf( location )
    if raw_type( location ) == "number" then
        location = location + 1
    end

    local dbg_info = debug_getinfo( location, "S" )
    if dbg_info == nil then
        return false
    end

    local what = dbg_info.what
    return not (what == "Lua" or what == "lua")
end

--- [SHARED AND MENU]
---
--- Checks whether the call at the given stack level was made through
--- `pcall` or `xpcall`, by walking up the stack from that level until it
--- finds a frame whose function is `pcall`/`xpcall`, or runs out of frames.
---
---@param stack_level? integer The stack level to start checking from (same meaning as the `level` argument of `debug.getinfo`). Defaults to `2`, i.e. the function calling `ispcall`.
---@return boolean ispcall `true` if the call is (directly or indirectly) inside a `pcall`/`xpcall`, `false` otherwise.
function debug.ispcall( stack_level )
    if stack_level == nil then
        stack_level = 2
    elseif stack_level >= 0 then
        stack_level = stack_level + 1
    else
        error( "stack level cannot be less than zero", 2 )
    end

    ::debug_ispcall_loop::

    local info = debug_getinfo( stack_level, "f" )
    if info ~= nil then
        local func = info.func
        if func == pcall or func == xpcall then
            return true
        end

        stack_level = stack_level + 1
        goto debug_ispcall_loop
    end

    return false
end

local registry

--- [SHARED AND MENU]
---
--- Returns the registry table.
---
---@diagnostic disable-next-line: duplicate-set-field
function debug.getregistry()
    return registry
end

--- [SHARED AND MENU]
---
--- Sets registry table.
---
--- **ATTENTION**
---
--- This function is extremly dangerous,
--- only reason why this exists is fact
--- that `getregistry` originally broken by cockpunch
--- and i cannot set locals over debug,
--- so only way to implement 3rd party moudles support
--- is implement this function :c
---
---@param tbl table
function debug.setregistry( tbl )
    if registry ~= nil then
        for key, value in raw.pairs( registry ) do
            local existing_value = raw_get( tbl, key )
            if existing_value == nil or existing_value ~= value then
                tbl[ key ] = value
            end
        end
    end

    registry = tbl
    raw.set( std, "_R", tbl ) -- global _R alias support
end

debug.setregistry( (debug.getregistry or debug_fempty)() or std._R or {} )

do

    ---@diagnostic disable-next-line: undefined-global
    local FindMetaTable = FindMetaTable

    if FindMetaTable == nil then

        function debug.findmetatable( name )
            return registry[ name ]
        end

    else

        --- [SHARED AND MENU]
        ---
        --- Returns the metatable of the given name or `nil` if not found.
        ---
        ---@param name string The name of the metatable.
        ---@return dreamwork.std.Metatable | nil meta The metatable.
        function debug.findmetatable( name )
            local cached = registry[ name ]
            if cached ~= nil then
                return cached
            end

            local metatable = FindMetaTable( name )
            if metatable ~= nil then
                registry[ name ] = metatable
                return metatable
            end

            return nil
        end

    end

end

do

    ---@type fun(name: string, tbl: dreamwork.std.Metatable)
    ---@diagnostic disable-next-line: undefined-global
    local RegisterMetaTable = RegisterMetaTable or debug_fempty

    --- [SHARED AND MENU]
    ---
    --- Registers the metatable of the given name and table.
    ---
    ---@param name string The name of the metatable.
    ---@param tbl dreamwork.std.Metatable The metatable to register.
    ---@param do_full_register? boolean `true`, the metatable will be registered, `false` otherwise.
    ---@return integer meta_id The ID of the metatable or `-1` if not fully registered.
    function debug.registermetatable( name, tbl, do_full_register )
        tbl = registry[ name ] or tbl
        registry[ name ] = tbl

        if do_full_register then
            RegisterMetaTable( name, tbl )
        end

        return tbl.MetaID or -1
    end

end

--- [SHARED AND MENU]
---
---
---@param name string The name of the metatable.
---@return dreamwork.std.Metatable metatable The metatable.
function debug.initmetatable( name )
    local metatable = debug.findmetatable( name )
    if metatable == nil then
        metatable = {}
        debug.registermetatable( name, metatable, true )
    end

    return metatable
end

-- gmod developer/s sanity check
if debug_getmetatable( debug_fempty ) == nil then
    debug.setmetatable( debug_fempty, {} )
end

if debug_getmetatable( debug_fempty ) == nil then

    --- [SHARED AND MENU]
    ---
    --- Returns the metatable of the given value or `nil` if not found.
    ---
    --- [View documents](http://www.lua.org/manual/5.1/manual.html#pdf-debug.getmetatable)
    ---
    ---@param value any The value.
    ---@return dreamwork.std.Metatable | nil metatable The metatable.
    ---@diagnostic disable-next-line: duplicate-set-field
    function debug.getmetatable( value )
        return debug_getmetatable( value ) or registry[ raw_type( value ) ]
    end

    raw.print( "at any cost, but we'll build it once again..." )

end

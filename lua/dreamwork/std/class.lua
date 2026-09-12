---@class dreamwork.std
local std = dreamwork.std

local isTable = std.isTable
local setmetatable = std.setmetatable

local string = std.string
local string_byte = string.byte
local string_format = string.format

local debug = std.debug
local debug_newproxy = debug.newproxy
local debug_getmetatable = debug.getmetatable
local debug_getmetavalue = debug.getmetavalue

local raw = std.raw
local raw_pairs = raw.pairs
local raw_get, raw_set = raw.get, raw.set

local error = std.error


--- [SHARED AND MENU]
---
--- A library for creating classes, implementing inheritance, and working with the object model in Lua.
---
---@class dreamwork.std.class
local class = {}
std.class = class

---@alias dreamwork.std.Class.__inherited fun( parent: dreamwork.std.Class, child: dreamwork.std.Class )
---@alias dreamwork.std.Class.__new fun( cls: dreamwork.std.Class, ...: any? ): dreamwork.std.Object
---@alias dreamwork.std.Object.__init fun( obj: dreamwork.std.Object, ...: any? )

--- [SHARED AND MENU]
---
--- A base for objects were created by `class` library.
---
---@class dreamwork.std.Object : dreamwork.std.Metatable
---@field __type string The name of object type. **READ ONLY**
---@field __class? dreamwork.std.Class  The class of the object. **READ ONLY**
---@field __parent? dreamwork.std.Object The parent of the object. **READ ONLY**
---@field __init? dreamwork.std.Object.__init A function that will be called when creating a new object and should be used as the constructor.
---@field __new? dreamwork.std.Class.__new A function that will be called when a new class is created and allows you to replace the result.

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias Object dreamwork.std.Object

--- [SHARED AND MENU]
---
--- A general structure for every class that created with `class` library.
---
---@class dreamwork.std.Class : dreamwork.std.Object
---@field __base dreamwork.std.Object The base of the class. **READ ONLY**
---@field __parent? dreamwork.std.Class The parent of the class. **READ ONLY**
---@field __private boolean If the class is private. **READ ONLY**
---@field __inherited? dreamwork.std.Class.__inherited The function that will be called when the class is inherited.

--- [SHARED AND MENU]
---
--- Checks if the value is a class.
---
---@param value any The value to check for being a class.
---@return boolean is_class `true` if `value` is a class, `false` otherwise.
function std.isClass( value )
    if not isTable( value ) then return false end

    local base = raw_get( value, "__base" )
    if base == nil then return false end

    return raw_get( base, "__class" ) == value
end

--- [SHARED AND MENU]
---
--- Checks if the value is a object created by class.
---
---@param value any The value to check for being a object.
---@return boolean is_object `true` is `value` is a object created by class, `false` otherwise.
function std.isObject( value )
    local base = debug_getmetatable( value )
    if base == nil then return false end

    return raw_get( base, "__class" ) ~= nil
end

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias Class dreamwork.std.Class

---@type table<dreamwork.std.Object, userdata>
local templates = {}

std.gc.setTableRules( templates, true, false )

---@param obj dreamwork.std.Object The object to convert to a string.
---@return string str The string representation of the object.
local function __tostring( obj )
    return string_format( "%s: %p", debug_getmetavalue( obj, "__type" ) or "unknown", obj )
end

do

    ---@type table<string, boolean>
    local non_inheritable = {
        __private = true,
        __class = true,
        __base = true,
        __type = true,
    }

    --- [SHARED AND MENU]
    ---
    --- Creates a new class base ( metatable ).
    ---
    ---@param name string The name of the class.
    ---@param private? boolean If the class is private.
    ---@param parent? dreamwork.std.Class | unknown The parent of the class.
    ---@return dreamwork.std.Object base The base of the class.
    function class.base( name, private, parent )
        local base

        if private then
            local template = debug_newproxy( true )
            base = debug_getmetatable( template )

            if base == nil then
                error( "`userdata` metatable is missing, Lua environment is corrupted!" )
            end

            templates[ base ] = template

            raw_set( base, "__type", name )
            raw_set( base, "__private", true )
            raw_set( base, "__tostring", __tostring )
        else
            base = {
                __type = name,
                __tostring = __tostring
            }
        end

        base.__index = base
        ---@cast base dreamwork.std.Object

        if parent ~= nil then
            local parent_base = raw_get( parent, "__base" )
            if parent_base == nil then
                error( "Parent class has no `__base` variable.", 2 )
            end

            ---@cast parent_base dreamwork.std.Object
            base.__parent = parent_base
            setmetatable( base, { __index = parent_base } )

            -- copy metamethods from parent
            for key, value in raw_pairs( parent_base ) do
                local uint8_1, uint8_2 = string_byte( key, 1, 2 )
                if (uint8_1 == 0x5F --[[ "_" ]] and uint8_2 == 0x5F --[[ "_" ]]) and not (key == "__index" and value == parent_base) and not non_inheritable[ key ] then
                    base[ key ] = value
                end
            end
        end

        return base
    end

end

local class__call
do

    --- [SHARED AND MENU]
    ---
    --- This function is optional and can be used to re-initialize the object.
    ---
    --- Calls the base initialization function, <b>if it exists</b>, and returns the given object.
    ---
    ---@param base dreamwork.std.Object The base object, aka metatable.
    ---@param obj dreamwork.std.Object The object to initialize.
    ---@param ... any? Arguments to pass to the constructor.
    ---@return dreamwork.std.Object object The initialized object.
    local function class_init( base, obj, ... )
        local init_fn = raw_get( base, "__init" )
        if init_fn ~= nil then
            init_fn( obj, ... )
        end

        return obj
    end

    class.init = class_init

    --- [SHARED AND MENU]
    ---
    --- Creates a new class object.
    ---
    ---@generic T : dreamwork.std.Object
    ---@param base T The base object, aka metatable.
    ---@return T obj The new object.
    local function class_new( base )
        if raw_get( base, "__private" ) then
            ---@diagnostic disable-next-line: return-type-mismatch
            return debug_newproxy( templates[ base ] )
        end

        local obj = {}
        setmetatable( obj, base )
        return obj
    end

    class.new = class_new

    ---@param self dreamwork.std.Class The class.
    ---@return dreamwork.std.Object obj The new object.
    function class__call( self, ... )
        ---@type dreamwork.std.Object | nil
        local obj

        ---@type dreamwork.std.Class.__new | nil
        local new_fn = raw_get( self, "__new" )
        if new_fn ~= nil then
            obj = new_fn( self, ... )
        end

        if obj == nil then
            ---@type dreamwork.std.Object | nil
            local base = raw_get( self, "__base" )
            if base == nil then
                std.errorf( 2, false, "Class '%s' variable `__base` is missing, class creation failed.", self )
            else
                obj = class_init( base, class_new( base ), ... )
            end
        end

        ---@diagnostic disable-next-line: return-type-mismatch
        return obj
    end

end

--- [SHARED AND MENU]
---
--- Creates a new class from the given base.
---
---@param base dreamwork.std.Object The base object, aka metatable.
---@return dreamwork.std.Class | unknown cls The class.
function class.create( base )
    local cls = {}

    ---@type dreamwork.std.Class | nil
    local parent_class

    local parent_base = raw_get( base, "__parent" )
    if parent_base ~= nil then
        ---@cast parent_base dreamwork.std.Object
        parent_class = raw_get( parent_base, "__class" )

        if parent_class ~= nil then
            for key, value in raw_pairs( parent_class ) do
                cls[ key ] = value
            end
        end
    end

    raw_set( base, "__class", cls )

    setmetatable( cls, {
        __index = base,
        __metatable = base,
        __call = class__call,
        __tostring = __tostring,
        __type = raw_get( base, "__type" ) .. "Class"
    } )

    raw_set( cls, "__parent", parent_class )
    raw_set( cls, "__base", base )

    if parent_class ~= nil then
        ---@type dreamwork.std.Class.__inherited | nil
        local inherited_fn = raw_get( parent_class, "__inherited" )
        if inherited_fn ~= nil then
            inherited_fn( parent_class, cls )
        end
    end

    return cls
end

--- [SHARED AND MENU]
---
--- Checks if the value is an instance of the given class.
---
---@param obj dreamwork.std.Object The object to check for being an instance of the given class.
---@param cls dreamwork.std.Class | dreamwork.std.Object The class to check against.
---@return boolean is_instance `true` if `obj` is an instance of the given class, `false` otherwise.
function class.isInherited( obj, cls )
    local obj_base = debug_getmetatable( obj )
    local cls_base = raw_get( cls, "__base" )

    while obj_base ~= nil do
        if obj_base == cls_base then
            return true
        end

        obj_base = raw_get( obj_base, "__parent" )
    end

    return false
end

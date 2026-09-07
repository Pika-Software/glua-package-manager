---@class dreamwork.std
local std = dreamwork.std
local class = std.class

local string_format = std.string.format

--- TODO: implement Quaternion class / object
---
--- ref: https://github.com/thegrb93/StarfallEx/blob/master/lua/starfall/libs_sh/quaternion.lua
---
--- ref: https://github.com/excessive/cpml/blob/master/modules/quat.lua

---@class dreamwork.std.Quaternion : dreamwork.std.Object
---@operator unm: Quaternion
local Quaternion = class.base( "Quaternion", false )

---@alias Quaternion dreamwork.std.Quaternion

do

    local debug_getmetatable = std.debug.getmetatable

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if the value is a `Quaternion`.
    ---
    ---@param value any The value.
    ---@return boolean is_quaternion `true` if the value is a `Quaternion`, `false` otherwise.
    function std.isQuaternion( value )
        return debug_getmetatable( value ) == Quaternion
    end

end

--- [SHARED AND MENU]
---
--- The class used to create new `Quaternion` instances.
---
---@class dreamwork.std.QuaternionClass : dreamwork.std.Quaternion
---@overload fun(r: number, i: number, j: number, k: number): Quaternion
local QuaternionClass = class.create( Quaternion )
std.Quaternion = QuaternionClass

---@protected
function Quaternion:__tostring()
    return string_format( "Quaternion: %p [%s, %s, %s, %s]", self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ] )
end

---@param r number The real component.
---@param i number The imaginary component.
---@param j number The imaginary component.
---@param k number The imaginary component.
---@protected
function Quaternion:__init( r, i, j, k )
    self[ 1 ] = r or 0
    self[ 2 ] = i or 0
    self[ 3 ] = j or 0
    self[ 4 ] = k or 0
end

---@protected
---@param writer dreamwork.std.buffer.Writer
function Quaternion:__serialize( writer )
    -- TODO
end

---@protected
---@param reader dreamwork.std.buffer.Reader
function Quaternion:__deserialize( reader )
    -- TODO
end

---@param other Quaternion The other quaternion to compare with.
---@protected
function Quaternion:__eq( other )
    return self[ 1 ] == other[ 1 ] and
        self[ 2 ] == other[ 2 ] and
        self[ 3 ] == other[ 3 ] and
        self[ 4 ] == other[ 4 ]
end

---@return Quaternion
---@protected
function Quaternion:__unm()
    return QuaternionClass( -self[ 1 ], -self[ 2 ], -self[ 3 ], -self[ 4 ] )
end

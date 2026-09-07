-- TODO: https://github.com/excessive/cpml/blob/master/modules/vec2.lua

---@class dreamwork.std
local std = dreamwork.std
local class = std.class

local isNumber = std.isNumber

local string_format = std.string.format

local math = std.math
local math_deg = math.deg
local math_lerp = math.lerp
local math_sqrt = math.sqrt
local math_huge = math.huge
local math_atan2 = math.atan2
local math_toFloat32 = math.toFloat32

local raw = std.raw
local raw_index = raw.index
local raw_get, raw_set = raw.get, raw.set

--- [SHARED AND MENU]
---
--- A 2D vector object.
---
---@class dreamwork.std.Vector2 : dreamwork.std.Object
---@field __class dreamwork.std.Vector2Class
---@operator add( dreamwork.std.Vector2 | number ): dreamwork.std.Vector2
---@operator sub( dreamwork.std.Vector2 | number ): dreamwork.std.Vector2
---@operator mul( dreamwork.std.Vector2 | number ): dreamwork.std.Vector2
---@operator div( dreamwork.std.Vector2 | number ): dreamwork.std.Vector2
---@operator unm: dreamwork.std.Vector2
---@field [1] number
---@field x number
---@field [2] number
---@field y number
local Vector2 = class.base( "Vector2" )

do

    local debug_getmetatable = std.debug.getmetatable

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if the value is a `Vector2`.
    ---
    ---@param value any The value.
    ---@return boolean is_vector2 `true` if the value is a `Vector2`, `false` otherwise.
    function std.isVector2( value )
        return debug_getmetatable( value ) == Vector2
    end

end

--- [SHARED AND MENU]
---
--- The class used to create new `Vector2` instances.
---
---@class dreamwork.std.Vector2Class: dreamwork.std.Vector2
---@field __base dreamwork.std.Vector2
---@overload fun( x: number, y: number ): dreamwork.std.Vector2
local Vector2Class = class.create( Vector2 )
Vector2Class.origin = setmetatable( { 0, 0 }, Vector2 )
std.Vector2 = Vector2Class

---@protected
---@return string
function Vector2:__tostring()
    return string_format( "Vector2: %p [%f, %f]", self, self[ 1 ], self[ 2 ] )
end

---@protected
---@param x? number
---@param y? number
function Vector2:__init( x, y )
    if x == nil then
        self[ 1 ] = 0
    else
        self[ 1 ] = math_toFloat32( x )
    end

    if y == nil then
        self[ 2 ] = 0
    else
        self[ 2 ] = math_toFloat32( y )
    end
end

---@protected
function Vector2:__index( key )
    if key == "x" then
        return raw_get( self, 1 )
    elseif key == "y" then
        return raw_get( self, 2 )
    else
        return raw_index( Vector2, key )
    end
end

---@protected
function Vector2:__newindex( key, value )
    if key == 1 or key == "x" then
        raw_set( self, 1, value )
    elseif key == 2 or key == "y" then
        raw_set( self, 2, value )
    end
end

---@protected
---@param writer dreamwork.std.buffer.Writer
function Vector2:__serialize( writer )
    writer:writeFloat( self[ 1 ] )
    writer:writeFloat( self[ 2 ] )
end

---@protected
---@param reader dreamwork.std.buffer.Reader
function Vector2:__deserialize( reader )
    self[ 1 ] = reader:readFloat()
    self[ 2 ] = reader:readFloat()
end

--- [SHARED AND MENU]
---
--- Returns the x and y coordinates of the vector.
---
---@return number x The x coordinate of the vector.
---@return number y The y coordinate of the vector.
function Vector2:unpack()
    return self[ 1 ], self[ 2 ]
end

--- [SHARED AND MENU]
---
--- Sets the x and y coordinates of the vector.
---
---@param x number The x coordinate of the vector.
---@param y number The y coordinate of the vector.
function Vector2:setUnpacked( x, y )
    self[ 1 ] = math_toFloat32( x )
    self[ 2 ] = math_toFloat32( y )
end

--- [SHARED AND MENU]
---
--- Creates a copy of the vector.
---
---@param self dreamwork.std.Vector2 The vector.
---@return dreamwork.std.Vector2 copy The copy of the vector.
local function Vector2_copy( self )
    return setmetatable( { self[ 1 ], self[ 2 ] }, Vector2 )
end

Vector2.copy = Vector2_copy

--- [SHARED AND MENU]
---
--- Negates the vector.
---
---@return dreamwork.std.Vector2
function Vector2:negate()
    self[ 1 ] = -self[ 1 ]
    self[ 2 ] = -self[ 2 ]
    return self
end

---@protected
function Vector2:__unm()
    return setmetatable( { -self[ 1 ], -self[ 2 ] }, Vector2 )
end

--- [SHARED AND MENU]
---
--- Scales the vector.
---
---@param self dreamwork.std.Vector2 The vector to scale.
---@param scale number The scale factor.
---@return dreamwork.std.Vector2 vec2 The scaled vector.
local function Vector2_scale( self, scale )
    if scale == 0 or scale ~= scale then
        self[ 1 ] = 0
        self[ 2 ] = 0
    elseif scale == math_huge then
        self[ 1 ] = math_huge
        self[ 2 ] = math_huge
    else
        self[ 1 ] = math_toFloat32( self[ 1 ] * scale )
        self[ 2 ] = math_toFloat32( self[ 2 ] * scale )
    end

    return self
end

Vector2.scale = Vector2_scale

--- [SHARED AND MENU]
---
--- Returns a scaled copy of the vector.
---
---@param scale number The scale factor.
---@return dreamwork.std.Vector2 vec2 The scaled copy of the vector.
function Vector2:getScaled( scale )
    return Vector2_scale( Vector2_copy( self ), scale )
end

do

    --- [SHARED AND MENU]
    ---
    --- Adds the vector to another vector.
    ---
    ---@param self dreamwork.std.Vector2 The vector to add to.
    ---@param vector dreamwork.std.Vector2 The other vector.
    ---@return dreamwork.std.Vector2 vec2 The sum of the two vectors.
    local function Vector2_add( self, vector )
        self[ 1 ] = math_toFloat32( self[ 1 ] + vector[ 1 ] )
        self[ 2 ] = math_toFloat32( self[ 2 ] + vector[ 2 ] )
        return self
    end

    Vector2.add = Vector2_add

    ---@protected
    ---@param value dreamwork.std.Vector2 | number
    ---@return dreamwork.std.Vector2
    function Vector2:__add( value )
        if isNumber( value ) then
            ---@cast value number
            return setmetatable( {
                math_toFloat32( self[ 1 ] + value ),
                math_toFloat32( self[ 2 ] + value )
            }, Vector2 )
        else
            ---@cast value dreamwork.std.Vector2
            return Vector2_add( Vector2_copy( self ), value )
        end
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Subtracts the vector from another vector.
    ---
    ---@param self dreamwork.std.Vector2 The vector to subtract from.
    ---@param other dreamwork.std.Vector2 The other vector.
    ---@return dreamwork.std.Vector2 vec2 The difference of the two vectors.
    local function Vector2_sub( self, other )
        self[ 1 ] = math_toFloat32( self[ 1 ] - other[ 1 ] )
        self[ 2 ] = math_toFloat32( self[ 2 ] - other[ 2 ] )
        return self
    end

    Vector2.sub = Vector2_sub

    ---@param value dreamwork.std.Vector2 | number
    ---@return dreamwork.std.Vector2
    ---@protected
    function Vector2:__sub( value )
        if isNumber( value ) then
            ---@cast value number
            return setmetatable( {
                math_toFloat32( self[ 1 ] - value ),
                math_toFloat32( self[ 2 ] - value )
            }, Vector2 )
        else
            ---@cast value dreamwork.std.Vector2
            return Vector2_sub( Vector2_copy( self ), value )
        end
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Multiplies the vector by another vector or a number.
    ---
    ---@param self dreamwork.std.Vector2 The vector to multiply.
    ---@param vector dreamwork.std.Vector2 The other vector or a number.
    ---@return dreamwork.std.Vector2 multiplied_vector The product of the two vectors or the vector multiplied by a number.
    local function Vector2_multiply( self, vector )
        self[ 1 ] = math_toFloat32( self[ 1 ] * vector[ 1 ] )
        self[ 2 ] = math_toFloat32( self[ 2 ] * vector[ 2 ] )
        return self
    end

    Vector2.multiply = Vector2_multiply

    ---@protected
    ---@param value dreamwork.std.Vector2 | number
    ---@return dreamwork.std.Vector2
    function Vector2:__mul( value )
        if isNumber( value ) then
            ---@cast value number
            return Vector2_scale( Vector2_copy( self ), value )
        else
            ---@cast value dreamwork.std.Vector2
            return setmetatable( {
                math_toFloat32( self[ 1 ] * value[ 1 ] ),
                math_toFloat32( self[ 2 ] * value[ 2 ] )
            }, Vector2 )
        end
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Divides the vector by another vector or a number.
    ---
    ---@param self dreamwork.std.Vector2 The vector to divide.
    ---@param other dreamwork.std.Vector2 | number The other vector or a number.
    ---@return dreamwork.std.Vector2 vec2 The quotient of the two vectors or the vector divided by a number.
    local function Vector2_div( self, other )
        if isNumber( other ) then
            ---@cast other number
            return self:scale( 1 / other )
        else
            ---@cast other dreamwork.std.Vector2
            self[ 1 ] = math_toFloat32( self[ 1 ] / other[ 1 ] )
            self[ 2 ] = math_toFloat32( self[ 2 ] / other[ 2 ] )
        end

        return self
    end

    Vector2.div = Vector2_div

    ---@protected
    function Vector2:__div( other )
        return Vector2_div( Vector2_copy( self ), other )
    end

end

---@protected
function Vector2:__eq( vector )
    return self[ 1 ] == vector[ 1 ] and self[ 2 ] == vector[ 2 ]
end

--- [SHARED AND MENU]
---
--- Calculates the distance between two vectors.
---
---@param vector dreamwork.std.Vector2 The other vector.
---@return number distance The distance between the two vectors.
function Vector2:getDistance( vector )
    return (math_sqrt( (vector[ 1 ] - self[ 1 ]) ^ 2 ) + (vector[ 2 ] - self[ 2 ]) ^ 2)
end

do

    --- [SHARED AND MENU]
    ---
    --- Calculates the squared length of the vector.
    ---
    ---@param self dreamwork.std.Vector2 The vector to calculate the length of.
    ---@return number length The squared length of the vector.
    local function Vector2_getLengthSqr( self )
        return (self[ 1 ] ^ 2) + (self[ 2 ] ^ 2)
    end

    Vector2.getLengthSqr = Vector2_getLengthSqr

    --- [SHARED AND MENU]
    ---
    --- Calculates the length of the vector.
    ---
    ---@param self dreamwork.std.Vector2 The vector to calculate the length of.
    ---@return number length The length of the vector.
    local function Vector2_getLength( self )
        return math_sqrt( Vector2_getLengthSqr( self ) )
    end

    Vector2.getLength = Vector2_getLength

    --- [SHARED AND MENU]
    ---
    --- Normalizes the vector.
    ---
    ---@param self dreamwork.std.Vector2 The vector to normalize.
    ---@return dreamwork.std.Vector2 vec2 The normalized vector.
    local function Vector2_normalize( self )
        local length = Vector2_getLength( self )
        if length == 0 then
            return self
        else
            return Vector2_scale( self, 1 / length )
        end
    end

    Vector2.normalize = Vector2_normalize

    --- [SHARED AND MENU]
    ---
    --- Returns a normalized copy of the vector.
    ---
    ---@return dreamwork.std.Vector2 normalized_vec2 The normalized copy of the vector.
    function Vector2:getNormalized()
        return Vector2_normalize( Vector2_copy( self ) )
    end

end

--- [SHARED AND MENU]
---
--- Checks if the vector is zero.
---
---@return boolean is_zero `true` if the vector is zero, `false` otherwise.
function Vector2:isZero()
    return self[ 1 ] == 0 and self[ 2 ] == 0
end

--- [SHARED AND MENU]
---
--- Sets the vector to zero.
---
---@return dreamwork.std.Vector2 vec2 The zero vector.
function Vector2:zero()
    self[ 1 ] = 0
    self[ 2 ] = 0
    return self
end

--- [SHARED AND MENU]
---
--- Calculates the dot product of two vectors.
---
---@param vector dreamwork.std.Vector2 The other vector.
---@return number dot_product The dot product of two vectors.
function Vector2:dot( vector )
    return (self[ 1 ] * vector[ 1 ]) + (self[ 2 ] * vector[ 2 ])
end

--- [SHARED AND MENU]
---
--- Calculates the cross product of two vectors.
---
---@param vector dreamwork.std.Vector2 The other vector.
---@return number cross_product The cross product of two vectors.
function Vector2:cross( vector )
    return (self[ 1 ] * vector[ 2 ]) - (self[ 2 ] * vector[ 1 ])
end

--- [SHARED AND MENU]
---
--- Returns the angle of the vector.
---
---@param self dreamwork.std.Vector2 The vector to calculate the angle of.
---@param up? dreamwork.std.Vector2 The direction of the angle.
---@return number angle The angle of the vector.
local function Vector2_getAngle( self, up )
    if up == nil then
        return 360 - math_deg( math_atan2( self[ 1 ], self[ 2 ] ) )
    else
        return Vector2_getAngle( up ) + Vector2_getAngle( self )
    end
end

Vector2.getAngle = Vector2_getAngle

--- [SHARED AND MENU]
---
--- Linear interpolation between two vectors.
---
---@param self dreamwork.std.Vector2 The vector.
---@param vector dreamwork.std.Vector2 The other vector.
---@param frac number The interpolation factor.
---@return dreamwork.std.Vector2 vec3 The interpolated vector.
local function Vector2_lerpToVector( self, vector, frac )
    self[ 1 ] = math_lerp( frac, self[ 1 ], vector[ 1 ] )
    self[ 2 ] = math_lerp( frac, self[ 2 ], vector[ 2 ] )
    return self
end

Vector2.lerpToVector = Vector2_lerpToVector

--- [SHARED AND MENU]
---
--- Linear interpolation between two vectors.
---
---@param vector dreamwork.std.Vector2 The other vector.
---@param frac number The interpolation factor.
---@return dreamwork.std.Vector2 vec3 The interpolated vector.
function Vector2:getLerpedToVector( vector, frac )
    return Vector2_lerpToVector( Vector2_copy( self ), vector, frac )
end

--- [SHARED AND MENU]
---
--- Linear interpolation between vector and number.
---
---@param self dreamwork.std.Vector2 The vector.
---@param number number The other number.
---@param frac number The interpolation factor.
---@return dreamwork.std.Vector2 vec3 The interpolated vector.
local function Vector2_lerpToNumber( self, number, frac )
    self[ 1 ] = math_lerp( frac, self[ 1 ], number )
    self[ 2 ] = math_lerp( frac, self[ 2 ], number )
    return self
end

Vector2.lerpToNumber = Vector2_lerpToNumber

--- [SHARED AND MENU]
---
--- Linear interpolation between vector and number.
---
---@param number number The other number.
---@param frac number The interpolation factor.
---@return dreamwork.std.Vector2 vec3 The interpolated vector.
function Vector2:getLerpedToNumber( number, frac )
    return Vector2_lerpToNumber( Vector2_copy( self ), number, frac )
end

-- TODO: rewrite & rebuild this

---@class dreamwork.std
local std = dreamwork.std
local class = std.class

local isNumber = std.isNumber

local string_format = std.string.format

local math = std.math
local math_abs = math.abs
local math_lerp = math.lerp
local math_huge = math.huge
local math_sqrt = math.sqrt
local math_toFloat32 = math.toFloat32
local math_deg, math_rad = math.deg, math.rad
local math_cos, math_sin = math.cos, math.sin
local math_min, math_max = math.min, math.max

local raw = std.raw
local raw_index = raw.index
local raw_get, raw_set = raw.get, raw.set

--[[

    TODO: make serealizers
        Vec3 as Nak2 checked must be writed as 3 floats but this required more tests i guess
        Same for Vec2

        ref: https://github.com/excessive/cpml/blob/master/modules/vec3.lua

        ref: https://github.com/excessive/cpml/blob/master/modules/intersect.lua

        mb mb mb https://gitlab.com/DBotThePony/DLib/-/blob/develop/lua_src/dlib/modules/luavector.lua?ref_type=heads

]]

--- [SHARED AND MENU]
---
--- A 3D vector object.
---
---@class dreamwork.std.Vector3 : dreamwork.std.Object
---@field __class dreamwork.std.Vector3Class
---@operator add( dreamwork.std.Vector3 | number ): dreamwork.std.Vector3
---@operator sub( dreamwork.std.Vector3 | number ): dreamwork.std.Vector3
---@operator mul( dreamwork.std.Vector3 | number ): dreamwork.std.Vector3
---@operator div( dreamwork.std.Vector3 | number ): dreamwork.std.Vector3
---@operator unm: dreamwork.std.Vector3
---@field x number
---@field [1] number
---@field y number
---@field [2] number
---@field z number
---@field [3] number
local Vector3 = class.base( "Vector3" )

do

    local debug_getmetatable = std.debug.getmetatable

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if the value is a `Vector3`.
    ---
    ---@param value any The value.
    ---@return boolean is_vector3 `true` if the value is a `Vector3`, `false` otherwise.
    function std.isVector3( value )
        return debug_getmetatable( value ) == Vector3
    end

end

--- [SHARED AND MENU]
---
--- The class used to create new `Vector3` instances.
---
---@class dreamwork.std.Vector3Class: dreamwork.std.Vector3
---@field __base dreamwork.std.Vector3
---@overload fun( x: number, y: number, z: number ): dreamwork.std.Vector3
local Vector3Class = class.create( Vector3 )
Vector3Class.origin = setmetatable( { 0, 0, 0 }, Vector3 )
std.Vector3 = Vector3Class


---@protected
function Vector3:__tostring()
    return string_format( "Vector3: %p [%f, %f, %f]", self, self[ 1 ], self[ 2 ], self[ 3 ] )
end

---@protected
---@param x? number
---@param y? number
---@param z? number
function Vector3:__init( x, y, z )
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

    if z == nil then
        self[ 3 ] = 0
    else
        self[ 3 ] = math_toFloat32( z )
    end
end

---@protected
function Vector3:__index( key )
    if key == 1 or key == "x" then
        return raw_get( self, 1 )
    elseif key == 2 or key == "y" then
        return raw_get( self, 2 )
    elseif key == 3 or key == "z" then
        return raw_get( self, 3 )
    else
        return raw_index( Vector3, key )
    end
end

---@protected
function Vector3:__newindex( key, value )
    if key == 1 or key == "x" then
        raw_set( self, 1, value )
    elseif key == 2 or key == "y" then
        raw_set( self, 2, value )
    elseif key == 3 or key == "z" then
        raw_set( self, 3, value )
    end
end

---@protected
---@param writer dreamwork.std.buffer.Writer
function Vector3:__serialize( writer )
    writer:writeFloat( self[ 1 ] )
    writer:writeFloat( self[ 2 ] )
    writer:writeFloat( self[ 3 ] )
end

---@protected
---@param reader dreamwork.std.buffer.Reader
function Vector3:__deserialize( reader )
    self[ 1 ] = reader:readFloat()
    self[ 2 ] = reader:readFloat()
    self[ 3 ] = reader:readFloat()
end

--- [SHARED AND MENU]
---
--- Returns the x, y, and z coordinates of the vector.
---
---@return number x The x coordinate of the vector.
---@return number y The y coordinate of the vector.
---@return number z The z coordinate of the vector.
function Vector3:unpack()
    return self[ 1 ], self[ 2 ], self[ 3 ]
end

--- [SHARED AND MENU]
---
--- Sets the x, y, and z coordinates of the vector.
---
---@param x number The x coordinate of the vector.
---@param y number The y coordinate of the vector.
---@param z number The z coordinate of the vector.
function Vector3:setUnpacked( x, y, z )
    self[ 1 ] = x
    self[ 2 ] = y
    self[ 3 ] = z
end

--- [SHARED AND MENU]
---
--- Creates a copy of the vector.
---
---@param self dreamwork.std.Vector3 The vector.
---@return dreamwork.std.Vector3 copy The copy of the vector.
local function Vector3_copy( self )
    return setmetatable( { self[ 1 ], self[ 2 ], self[ 3 ] }, Vector3 )
end

Vector3.copy = Vector3_copy

--- [SHARED AND MENU]
---
--- Negates the vector.
---
---@return dreamwork.std.Vector3
function Vector3:negate()
    self[ 1 ] = -self[ 1 ]
    self[ 2 ] = -self[ 2 ]
    self[ 3 ] = -self[ 3 ]
    return self
end

---@protected
---@return dreamwork.std.Vector3
function Vector3:__unm()
    return setmetatable( { -self[ 1 ], -self[ 2 ], -self[ 3 ] }, Vector3 )
end

--- [SHARED AND MENU]
---
--- Scales the vector.
---
---@param self dreamwork.std.Vector3 The vector.
---@param scale number The scale factor.
---@return dreamwork.std.Vector3 vec3 The scaled vector.
local function Vector3_scale( self, scale )
    if scale == 0 or scale ~= scale then
        self[ 1 ] = 0
        self[ 2 ] = 0
        self[ 3 ] = 0
    elseif scale == math_huge then
        self[ 1 ] = math_huge
        self[ 2 ] = math_huge
        self[ 3 ] = math_huge
    else
        self[ 1 ] = self[ 1 ] * scale
        self[ 2 ] = self[ 2 ] * scale
        self[ 3 ] = self[ 3 ] * scale
    end

    return self
end

Vector3.scale = Vector3_scale

--- [SHARED AND MENU]
---
--- Returns a scaled copy of the vector.
---
---@param scale number The scale factor.
---@return dreamwork.std.Vector3 scaled_vec3 The scaled copy of the vector.
function Vector3:getScaled( scale )
    return Vector3_scale( Vector3_copy( self ), scale )
end

do

    --- [SHARED AND MENU]
    ---
    --- Adds the vector to another vector.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@param vector dreamwork.std.Vector3 The other vector.
    ---@return dreamwork.std.Vector3 vec3 The sum of the two vectors.
    local function Vector3_add( self, vector )
        self[ 1 ] = math_toFloat32( self[ 1 ] + vector[ 1 ] )
        self[ 2 ] = math_toFloat32( self[ 2 ] + vector[ 2 ] )
        self[ 3 ] = math_toFloat32( self[ 3 ] + vector[ 3 ] )
        return self
    end

    Vector3.add = Vector3_add

    ---@protected
    ---@param vector dreamwork.std.Vector3
    function Vector3:__add( vector )
        return Vector3_add( Vector3_copy( self ), vector )
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Subtracts the vector from another vector.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@param vector dreamwork.std.Vector3 The other vector.
    ---@return dreamwork.std.Vector3 vec3 The difference of the two vectors.
    local function Vector3_sub( self, vector )
        self[ 1 ] = math_toFloat32( self[ 1 ] - vector[ 1 ] )
        self[ 2 ] = math_toFloat32( self[ 2 ] - vector[ 2 ] )
        self[ 3 ] = math_toFloat32( self[ 3 ] - vector[ 3 ] )
        return self
    end

    Vector3.sub = Vector3_sub

    ---@protected
    ---@param vector dreamwork.std.Vector3
    function Vector3:__sub( vector )
        return Vector3_sub( Vector3_copy( self ), vector )
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Multiplies the vector by another vector or a number.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@param value dreamwork.std.Vector3 | number The other vector or a number.
    ---@return dreamwork.std.Vector3 vec3 The product of the two vectors or the vector multiplied by a number.
    local function Vector3_mul( self, value )
        if isNumber( value ) then
            ---@cast value number
            Vector3_scale( self, value )
        else
            ---@cast value dreamwork.std.Vector3
            self[ 1 ] = math_toFloat32( self[ 1 ] * value[ 1 ] )
            self[ 2 ] = math_toFloat32( self[ 2 ] * value[ 2 ] )
            self[ 3 ] = math_toFloat32( self[ 3 ] * value[ 3 ] )
        end

        return self
    end

    Vector3.mul = Vector3_mul

    ---@protected
    ---@param value dreamwork.std.Vector3
    function Vector3:__mul( value )
        return Vector3_mul( Vector3_copy( self ), value )
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Divides the vector by another vector or a number.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@param value dreamwork.std.Vector3 | number The other vector or a number.
    ---@return dreamwork.std.Vector3 vec3 The quotient of the two vectors or the vector divided by a number.
    local function Vector3_div( self, value )
        if isNumber( value ) then
            ---@cast value number
            return Vector3_scale( self, 1 / value )
        end

        ---@cast value dreamwork.std.Vector3
        self[ 1 ] = math_toFloat32( self[ 1 ] / value[ 1 ] )
        self[ 2 ] = math_toFloat32( self[ 2 ] / value[ 2 ] )
        self[ 3 ] = math_toFloat32( self[ 3 ] / value[ 3 ] )
        return self
    end

    Vector3.div = Vector3_div

    ---@protected
    ---@param value dreamwork.std.Vector3
    function Vector3:__div( value )
        return Vector3_div( Vector3_copy( self ), value )
    end

end

---@protected
---@param vector dreamwork.std.Vector3
---@return boolean
function Vector3:__eq( vector )
    return self[ 1 ] == vector[ 1 ] and self[ 2 ] == vector[ 2 ] and self[ 3 ] == vector[ 3 ]
end

--- [SHARED AND MENU]
---
--- Calculates the distance between two vectors.
---
---@param vector dreamwork.std.Vector3 The other vector.
---@return number distance The distance between the two vectors.
function Vector3:getDistance( vector )
    return math_sqrt( (vector[ 1 ] - self[ 1 ]) ^ 2 + (vector[ 2 ] - self[ 2 ]) ^ 2 + (vector[ 3 ] - self[ 3 ]) ^ 2 )
end

do

    --- [SHARED AND MENU]
    ---
    --- Calculates the squared length of the vector.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@return number length The squared length of the vector.
    local function Vector3_getLengthSqr( self )
        return (self[ 1 ] ^ 2) + (self[ 2 ] ^ 2) + (self[ 3 ] ^ 2)
    end

    Vector3.getLengthSqr = Vector3_getLengthSqr

    --- [SHARED AND MENU]
    ---
    --- Calculates the length of the vector.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@return number length The length of the vector.
    local function Vector3_getLength( self )
        return math_sqrt( Vector3_getLengthSqr( self ) )
    end

    Vector3.getLength = Vector3_getLength

    --- [SHARED AND MENU]
    ---
    --- Calculates the dot product of two vectors.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@param vector dreamwork.std.Vector3 The other vector.
    ---@return number dot_product The dot product of two vectors.
    local function Vector3_dot( self, vector )
        return (self[ 1 ] * vector[ 1 ]) + (self[ 2 ] * vector[ 2 ]) + (self[ 3 ] * vector[ 3 ])
    end

    Vector3.dot = Vector3_dot

    --- [SHARED AND MENU]
    ---
    --- Calculates the cross product of two vectors.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@param vector dreamwork.std.Vector3 The other vector.
    ---@return dreamwork.std.Vector3 cross_product The cross product of two vectors.
    local function Vector3_cross( self, vector )
        local x1, y1, z1 = self[ 1 ], self[ 2 ], self[ 3 ]
        local x2, y2, z2 = vector[ 1 ], vector[ 2 ], vector[ 3 ]

        return setmetatable( {
            y1 * z2 - z1 * y2,
            z1 * x2 - x1 * z2,
            x1 * y2 - y1 * x2
        }, Vector3 )
    end

    Vector3.cross = Vector3_cross

    --- [SHARED AND MENU]
    ---
    --- Normalizes the vector.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@return dreamwork.std.Vector3 vec3 The normalized vector.
    local function Vector3_normalize( self )
        local length = Vector3_getLength( self )
        if length == 0 then
            return self
        else
            return Vector3_scale( self, 1 / length )
        end
    end

    Vector3.normalize = Vector3_normalize

    --- [SHARED AND MENU]
    ---
    --- Returns a normalized copy of the vector.
    ---
    ---@return dreamwork.std.Vector3 normalized_vec3 The normalized copy of the vector.
    function Vector3:getNormalized()
        return Vector3_normalize( Vector3_copy( self ) )
    end

    local math_asin = math.asin

    -- --- [SHARED AND MENU]
    -- ---
    -- --- Returns the angle of the vector.
    -- ---
    -- ---@param up? dreamwork.std.Vector3 The direction of the angle.
    -- ---@return dreamwork.std.Angle3 ang3 The angle of the vector.
    -- function Vector3:toAngle( up )
    --     if self[ 1 ] == 0 and self[ 2 ] == 0 and self[ 3 ] == 0 then
    --         return setmetatable( { 0, 0, 0 }, Angle3 )
    --     end

    --     local forward = Vector3_normalize( Vector3_copy( self ) )

    --     if up == nil then
    --         return setmetatable( {
    --             math_deg( math_asin( -forward[ 3 ] ) ),
    --             math_deg( math_atan2( forward[ 2 ], forward[ 1 ] ) ),
    --             0
    --         }, Angle3 )
    --     end

    --     local right = Vector3_normalize( Vector3_cross( up, forward ) )
    --     local x1, y1 = forward[ 1 ], forward[ 2 ]

    --     return setmetatable( {
    --         math_deg( math_asin( -forward[ 3 ] ) ),
    --         math_deg( math_atan2( y1, x1 ) ),
    --         math_deg( math_atan2( right[ 3 ], (x1 * right[ 2 ]) - (y1 * right[ 1 ]) ) )
    --     }, Angle3 )
    -- end

    local math_acos = math.acos

    --- [SHARED AND MENU]
    ---
    --- Calculates the angle between two vectors.
    ---
    ---@param vector dreamwork.std.Vector3 The other vector.
    ---@return number degrees The angle between two vectors.
    function Vector3:getAngle( vector )
        return math_deg( math_acos( Vector3_dot( self, vector ) / (Vector3_getLength( self ) * Vector3_getLength( vector )) ) )
    end

    --- [SHARED AND MENU]
    ---
    --- Projects the vector onto another vector.
    ---
    ---@param self dreamwork.std.Vector3 The vector.
    ---@param vector dreamwork.std.Vector3 The other vector.
    ---@return dreamwork.std.Vector3 vec3 The projected vector.
    local function Vector3_project( self, vector )
        local normalized = Vector3_normalize( Vector3_copy( vector ) )
        local dot = Vector3_dot( self, normalized )

        self[ 1 ] = math_toFloat32( normalized[ 1 ] * dot )
        self[ 2 ] = math_toFloat32( normalized[ 2 ] * dot )
        self[ 3 ] = math_toFloat32( normalized[ 3 ] * dot )

        return self
    end

    Vector3.project = Vector3_project

    --- [SHARED AND MENU]
    ---
    --- Returns a copy of the vector projected onto another vector.
    ---
    ---@param vector dreamwork.std.Vector3 The other vector.
    ---@return dreamwork.std.Vector3 projected_vec3 The projected vector.
    function Vector3:getProjected( vector )
        return Vector3_project( Vector3_copy( self ), vector )
    end

end

--- [SHARED AND MENU]
---
--- Checks if the vector is zero.
---
---@return boolean is_zero `true` if the vector is zero, `false` otherwise.
function Vector3:isZero()
    return self[ 1 ] == 0 and
        self[ 2 ] == 0 and
        self[ 3 ] == 0
end

--- [SHARED AND MENU]
---
--- Sets the vector to zero.
---
---@return dreamwork.std.Vector3 vec3 The zero vector.
function Vector3:zero()
    self[ 1 ] = 0
    self[ 2 ] = 0
    self[ 3 ] = 0
    return self
end

--- [SHARED AND MENU]
---
--- Checks if the vector is within an axis-aligned box.
---
---@param vector dreamwork.std.Vector3 The other vector.
---@return boolean in_box `true` if the vector is within the box, `false` otherwise.
function Vector3:withinAABox( vector )
    return not (
        self[ 1 ] < math_min( self[ 1 ], vector[ 1 ] ) or self[ 1 ] > math_max( self[ 1 ], vector[ 1 ] ) or
        self[ 2 ] < math_min( self[ 2 ], vector[ 2 ] ) or self[ 2 ] > math_max( self[ 2 ], vector[ 2 ] ) or
        self[ 3 ] < math_min( self[ 3 ], vector[ 3 ] ) or self[ 3 ] > math_max( self[ 3 ], vector[ 3 ] )
    )
end

--- [SHARED AND MENU]
---
--- Checks if the vector is equal to the given vector with the given tolerance.
---
---@param vector dreamwork.std.Vector3 The vector to check.
---@param tolerance number The tolerance to use.
---@return boolean is_near `true` if the vectors are equal, otherwise `false`.
function Vector3:isNear( vector, tolerance )
    return math_abs( self[ 1 ] - vector[ 1 ] ) <= tolerance and
        math_abs( self[ 2 ] - vector[ 2 ] ) <= tolerance and
        math_abs( self[ 3 ] - vector[ 3 ] ) <= tolerance
end

do

    --- [SHARED AND MENU]
    ---
    --- Rotates the vector by the given angle.
    ---
    ---@param self dreamwork.std.Vector3 The vector to rotate.
    ---@param angle Angle3 The angle to rotate by.
    ---@return dreamwork.std.Vector3 vec3 The rotated vector.
    local function Vector3_rotate( self, angle )
        local pitch, yaw, roll = math_rad( angle[ 1 ] ), math_rad( angle[ 2 ] ), math_rad( angle[ 3 ] )
        local ysin, ycos, psin, pcos, rsin, rcos = math_sin( yaw ), math_cos( yaw ), math_sin( pitch ), math_cos( pitch ), math_sin( roll ), math_cos( roll )

        local psin_rsin, psin_rcos = psin * rsin, psin * rcos
        local x, y, z = self[ 1 ], self[ 2 ], self[ 3 ]

        self[ 1 ] = x * (ycos * pcos) + y * (ycos * psin_rsin - ysin * rcos) + z * (ycos * psin_rcos + ysin * rsin)
        self[ 2 ] = x * (ysin * pcos) + y * (ysin * psin_rsin + ycos * rcos) + z * (ysin * psin_rcos - ycos * rsin)
        self[ 3 ] = x * (-psin) + y * (pcos * rsin) + z * (pcos * rcos)

        return self
    end

    Vector3.rotate = Vector3_rotate

    --- [SHARED AND MENU]
    ---
    --- Returns a copy of the vector rotated by the given angle.
    ---
    ---@param angle dreamwork.std.Angle3 The angle to rotate by.
    ---@return dreamwork.std.Vector3 rotated_vec3 The rotated vector.
    function Vector3:getRotated( angle )
        return Vector3_rotate( Vector3_copy( self ), angle )
    end

end

--- [SHARED AND MENU]
---
--- Linear interpolation between two vectors.
---
---@param vector dreamwork.std.Vector3 The other vector.
---@param frac number The interpolation factor.
---@return dreamwork.std.Vector3 vec3 The interpolated vector.
function Vector3:lerpToVector( vector, frac )
    ---@cast vector dreamwork.std.Vector3
    self[ 1 ] = math_lerp( frac, self[ 1 ], vector[ 1 ] )
    self[ 2 ] = math_lerp( frac, self[ 2 ], vector[ 2 ] )
    self[ 3 ] = math_lerp( frac, self[ 3 ], vector[ 3 ] )
    return self
end

--- [SHARED AND MENU]
---
--- Linear interpolation between vector and number.
---
---@param number number The other number.
---@param frac number The interpolation factor.
---@return dreamwork.std.Vector3 vec3 The interpolated vector.
function Vector3:lerpToNumber( number, frac )
    self[ 1 ] = math_lerp( frac, self[ 1 ], number )
    self[ 2 ] = math_lerp( frac, self[ 2 ], number )
    self[ 3 ] = math_lerp( frac, self[ 3 ], number )
    return self
end

--- [SHARED AND MENU]
---
--- Modifies the given vectors so that all of vector2's axis are larger than vector1's by switching them around.
---
--- Also known as ordering vectors.
---
---@param mins dreamwork.std.Vector3 The first vector to modify.
---@param maxs dreamwork.std.Vector3 The second vector to modify.
function Vector3Class.order( mins, maxs )
    local x1, y1, z1 = mins[ 1 ], mins[ 2 ], mins[ 3 ]
    local x2, y2, z2 = maxs[ 1 ], maxs[ 2 ], maxs[ 3 ]

    mins[ 1 ], mins[ 2 ], mins[ 3 ] = math_min( x1, x2 ), math_min( y1, y2 ), math_min( z1, z2 )
    maxs[ 1 ], maxs[ 2 ], maxs[ 3 ] = math_max( x1, x2 ), math_max( y1, y2 ), math_max( z1, z2 )

    return mins, maxs
end

--- [SHARED AND MENU]
---
--- Returns a new vector from world position and world angle.
---
---@param position dreamwork.std.Vector3 The local position.
---@param angle dreamwork.std.Angle3 The local angle.
---@param world_position dreamwork.std.Vector3 The world position.
---@param world_angle dreamwork.std.Angle3 The world angle.
---@return dreamwork.std.Vector3 vec3 The new vector.
---@return dreamwork.std.Angle3 ang3 The new angle.
function Vector3Class.translateToLocal( position, angle, world_position, world_angle )
    -- TODO: implement this function

end

--- [SHARED AND MENU]
---
--- Returns a new vector from local position and local angle.
---
---@param local_position dreamwork.std.Vector3 The local position.
---@param local_angle dreamwork.std.Angle3 The local angle.
---@param world_position dreamwork.std.Vector3 The world position.
---@param world_angle dreamwork.std.Angle3 The world angle.
---@return dreamwork.std.Vector3 vec3 The new vector.
---@return dreamwork.std.Angle3 ang3 The new angle.
function Vector3Class.translateToWorld( local_position, local_angle, world_position, world_angle )
    -- TODO: implement this function

end

--- [SHARED AND MENU]
---
--- Returns a new vector from screen position.
---
---@param view_angle dreamwork.std.Angle3 The view angle.
---@param view_fov number The view fov.
---@param x number The x position.
---@param y number The y position.
---@param screen_width number The screen width.
---@param screen_height number The screen height.
---@return dreamwork.std.Vector3 direction The view direction.
function Vector3Class.fromScreen( view_angle, view_fov, x, y, screen_width, screen_height )
    -- TODO: implement this function
end

-- TODO: rewrite & rebuild this

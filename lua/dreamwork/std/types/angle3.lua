---@class dreamwork.std
local std = dreamwork.std
local class = std.class

local string_format = std.string.format

local isNumber = std.isNumber

local math = std.math
local math_abs = math.abs
local math_lerp = math.lerp
local math_floor = math.floor
local math_toFloat32 = math.toFloat32

local raw = std.raw
local raw_index = raw.index
local raw_get, raw_set = raw.get, raw.set

--[[

    TODO:

    https://wiki.facepunch.com/gmod/gui.ScreenToVector ( Vector.FromScreen(X,Y) )

    https://wiki.facepunch.com/gmod/util.AimVector

    https://wiki.facepunch.com/gmod/Global.LocalToWorld
    https://wiki.facepunch.com/gmod/Global.WorldToLocal

    https://wiki.facepunch.com/gmod/util.IsInWorld

    https://wiki.facepunch.com/gmod/util.IntersectRayWithOBB

    https://wiki.facepunch.com/gmod/util.IntersectRayWithPlane

    https://wiki.facepunch.com/gmod/util.IntersectRayWithSphere

    https://wiki.facepunch.com/gmod/util.IsBoxIntersectingSphere

    https://wiki.facepunch.com/gmod/util.IsOBBIntersectingOBB

    https://wiki.facepunch.com/gmod/util.IsPointInCone

    https://wiki.facepunch.com/gmod/util.IsRayIntersectingRay

    https://wiki.facepunch.com/gmod/util.IsSkyboxVisibleFromPoint

    https://wiki.facepunch.com/gmod/util.IsSphereIntersectingCone

    https://wiki.facepunch.com/gmod/util.IsSphereIntersectingSphere


    https://wiki.facepunch.com/gmod/gui.ScreenToVector
    https://wiki.facepunch.com/gmod/Vector:ToScreen

]]

--- [SHARED AND MENU]
---
--- A 3D angle object.
---
---@class dreamwork.std.Angle3 : dreamwork.std.Object
---@field __class dreamwork.std.Angle3Class
---@operator add( dreamwork.std.Angle3 | number ): dreamwork.std.Angle3
---@operator sub( dreamwork.std.Angle3 | number ): dreamwork.std.Angle3
---@operator mul( dreamwork.std.Angle3 | number ): dreamwork.std.Angle3
---@operator div( dreamwork.std.Angle3 | number ): dreamwork.std.Angle3
---@operator unm: dreamwork.std.Angle3
---@field pitch number
---@field [1] number
---@field yaw number
---@field [2] number
---@field roll number
---@field [3] number
local Angle3 = class.base( "Angle3", false )

do

    local debug_getmetatable = debug.getmetatable

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if the value is an `dreamwork.std.Angle3`.
    ---
    ---@param value any The value.
    ---@return boolean is_angle3 `true` if the value is an `Angle3`, `false` otherwise.
    function std.isAngle3( value )
        return debug_getmetatable( value ) == Angle3
    end

end

--- [SHARED AND MENU]
---
--- The class used to create new `Angle3` instances.
---
---@class dreamwork.std.Angle3Class : dreamwork.std.Angle3
---@field __base dreamwork.std.Angle3
---@overload fun( pitch: number?, yaw: number?, roll: number? ): dreamwork.std.Angle3
local Angle3Class = class.create( Angle3 )
Angle3Class.zero = setmetatable( { 0, 0, 0 }, Angle3 )
std.Angle3 = Angle3Class

---@protected
function Angle3:__tostring()
    return string_format( "Angle3: %p [%f, %f, %f]", self, self:unpack() )
end

---@protected
function Angle3:__init( pitch, yaw, roll )
    if pitch == nil then
        self[ 1 ] = 0
    else
        self[ 1 ] = math_toFloat32( pitch )
    end

    if yaw == nil then
        self[ 2 ] = 0
    else
        self[ 2 ] = math_toFloat32( yaw )
    end

    if roll == nil then
        self[ 3 ] = 0
    else
        self[ 3 ] = math_toFloat32( roll )
    end
end

---@protected
function Angle3:__index( key )
    if key == 1 or key == "pitch" or key == "p" then
        return raw_get( self, 1 )
    elseif key == 2 or key == "yaw" or key == "y" then
        return raw_get( self, 2 )
    elseif key == 3 or key == "roll" or key == "r" then
        return raw_get( self, 3 )
    else
        return raw_index( Angle3, key )
    end
end

---@protected
function Angle3:__newindex( key, value )
    if key == 1 or key == "pitch" or key == "p" then
        raw_set( self, 1, value )
    elseif key == 2 or key == "yaw" or key == "y" then
        raw_set( self, 2, value )
    elseif key == 3 or key == "roll" or key == "r" then
        raw_set( self, 3, value )
    end
end

---@protected
---@param writer dreamwork.std.buffer.Writer
function Angle3:__serialize( writer )
    writer:writeUInt8( math_floor( (self[ 1 ] + 90) / 180 * 255 + 0.5 ) )
    writer:writeUInt8( math_floor( self[ 2 ] / 360 * 255 + 0.5 ) )
    writer:writeUInt8( math_floor( (self[ 3 ] + 180) / 360 * 255 + 0.5 ) )
end

---@protected
---@param reader dreamwork.std.buffer.Reader
function Angle3:__deserialize( reader )
    self[ 1 ] = (reader:readUInt8() / 255 * 180) - 90
    self[ 2 ] = reader:readUInt8() / 255 * 360
    self[ 3 ] = (reader:readUInt8() / 255 * 360) - 180
end

--- [SHARED AND MENU]
---
--- Unpacks the angle.
---
---@return number pitch The pitch angle.
---@return number yaw The yaw angle.
---@return number roll The roll angle.
function Angle3:unpack()
    return self[ 1 ], self[ 2 ], self[ 3 ]
end

--- [SHARED AND MENU]
---
--- Sets the angle from unpacked angles.
---
---@param pitch? number The pitch angle.
---@param yaw? number The yaw angle.
---@param roll? number The roll angle.
---@return dreamwork.std.Angle3 ang3 The angle.
function Angle3:setUnpacked( pitch, yaw, roll )
    self[ 1 ] = pitch
    self[ 2 ] = yaw
    self[ 3 ] = roll
    return self
end

--- [SHARED AND MENU]
---
--- Returns a copy of the angle.
---
---@param self dreamwork.std.Angle3 The angle.
---@return dreamwork.std.Angle3 copy A copy of the angle.
local function Angle3_copy( self )
    return setmetatable( { self[ 1 ], self[ 2 ], self[ 3 ] }, Angle3 )
end

Angle3.copy = Angle3_copy

do

    --- [SHARED AND MENU]
    ---
    --- Adds the angle.
    ---
    ---@param self dreamwork.std.Angle3 The angle.
    ---@param angle dreamwork.std.Angle3 The angle to add.
    ---@return dreamwork.std.Angle3 ang3 The sum of the angles.
    local function Angle3_add( self, angle )
        self[ 1 ] = self[ 1 ] + angle[ 1 ]
        self[ 2 ] = self[ 2 ] + angle[ 2 ]
        self[ 3 ] = self[ 3 ] + angle[ 3 ]
        return self
    end

    Angle3.add = Angle3_add

    ---@protected
    ---@param angle dreamwork.std.Angle3
    ---@return dreamwork.std.Angle3
    function Angle3:__add( angle )
        return Angle3_add( Angle3_copy( self ), angle )
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Subtracts the angle.
    ---
    ---@param self dreamwork.std.Angle3 The angle.
    ---@param angle dreamwork.std.Angle3 The angle to subtract.
    ---@return dreamwork.std.Angle3 ang3 The subtracted angle.
    local function Angle3_sub( self, angle )
        self[ 1 ] = self[ 1 ] - angle[ 1 ]
        self[ 2 ] = self[ 2 ] - angle[ 2 ]
        self[ 3 ] = self[ 3 ] - angle[ 3 ]
        return self
    end

    Angle3.sub = Angle3_sub

    ---@protected
    function Angle3:__sub( angle )
        return Angle3_sub( Angle3_copy( self ), angle )
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Multiplies the angle with a number or angle.
    ---
    ---@param self dreamwork.std.Angle3 The angle.
    ---@param angle number | dreamwork.std.Angle3 The angle to multiply with.
    ---@return dreamwork.std.Angle3 ang3 The multiplied angle.
    local function Angle3_mul( self, angle )
        if isNumber( angle ) then
            ---@cast angle number
            self[ 1 ] = self[ 1 ] * angle
            self[ 2 ] = self[ 2 ] * angle
            self[ 3 ] = self[ 3 ] * angle
        else
            ---@cast angle dreamwork.std.Angle3
            self[ 1 ] = self[ 1 ] * angle[ 1 ]
            self[ 2 ] = self[ 2 ] * angle[ 2 ]
            self[ 3 ] = self[ 3 ] * angle[ 3 ]
        end

        return self
    end

    dreamwork.std.Angle3.mul = Angle3_mul

    ---@protected
    ---@param angle dreamwork.std.Angle3
    ---@return dreamwork.std.Angle3
    function Angle3:__mul( angle )
        return Angle3_mul( Angle3_copy( self ), angle )
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Divides the angle with a number or angle.
    ---
    ---@param self dreamwork.std.Angle3 The angle.
    ---@param angle number | dreamwork.std.Angle3 The angle to divide with.
    ---@return dreamwork.std.Angle3 ang3 The divided angle.
    local function Angle3_div( self, angle )
        if isNumber( angle ) then
            ---@cast angle number
            self[ 1 ] = self[ 1 ] / angle
            self[ 2 ] = self[ 2 ] / angle
            self[ 3 ] = self[ 3 ] / angle
        else
            ---@cast angle dreamwork.std.Angle3
            self[ 1 ] = self[ 1 ] / angle[ 1 ]
            self[ 2 ] = self[ 2 ] / angle[ 2 ]
            self[ 3 ] = self[ 3 ] / angle[ 3 ]
        end

        return self
    end

    dreamwork.std.Angle3.div = Angle3_div

    ---@protected
    function Angle3:__div( angle )
        return Angle3_div( Angle3_copy( self ), angle )
    end

end

--- [SHARED AND MENU]
---
--- Negates the angle.
---
---@return dreamwork.std.Angle3 ang3 The negated angle.
function Angle3:negate()
    self[ 1 ] = -self[ 1 ]
    self[ 2 ] = -self[ 2 ]
    self[ 3 ] = -self[ 3 ]
    return self
end

---@protected
function Angle3:__unm()
    return setmetatable( { -self[ 1 ], -self[ 2 ], -self[ 3 ] }, Angle3 )
end

---@protected
function Angle3:__eq( angle )
    return self[ 1 ] == angle[ 1 ] and self[ 2 ] == angle[ 2 ] and self[ 3 ] == angle[ 3 ]
end

--- [SHARED AND MENU]
---
--- Linearly interpolates the angle.
---
---@param angle dreamwork.std.Angle3 | number The other angle.
---@param frac number The interpolation factor.
---@return dreamwork.std.Angle3 ang3 The interpolated angle.
function Angle3:lerp( angle, frac )
    if isNumber( angle ) then
        ---@cast angle number
        self[ 1 ] = math_lerp( frac, self[ 1 ], angle )
        self[ 2 ] = math_lerp( frac, self[ 2 ], angle )
        self[ 3 ] = math_lerp( frac, self[ 3 ], angle )
    else
        ---@cast angle dreamwork.std.Angle3
        self[ 1 ] = math_lerp( frac, self[ 1 ], angle[ 1 ] )
        self[ 2 ] = math_lerp( frac, self[ 2 ], angle[ 2 ] )
        self[ 3 ] = math_lerp( frac, self[ 3 ], angle[ 3 ] )
    end

    return self
end

--- [SHARED AND MENU]
---
--- Returns a copy of the angle linearly interpolated between two angles.
---
---@param angle dreamwork.std.Angle3 | number  The other angle.
---@param frac number The interpolation factor.
---@return dreamwork.std.Angle3 lerped_vec3 The interpolated angle.
function Angle3:getLerped( angle, frac )
    return self:copy():lerp( angle, frac )
end

-- --- [SHARED AND MENU]
-- ---
-- --- Returns the forward direction of the angle.
-- ---
-- ---@return dreamwork.std.Vector3 forward_dir The forward direction of the angle.
-- function Angle3:getForward()
--     return setmetatable( { 1, 0, 0 }, Vector3 ):rotate( self )
-- end

-- --- [SHARED AND MENU]
-- ---
-- --- Returns the backward direction of the angle.
-- ---
-- ---@return dreamwork.std.Vector3 backward_dir The backward direction of the angle.
-- function Angle3:getBackward()
--     return setmetatable( { -1, 0, 0 }, Vector3 ):rotate( self )
-- end

-- --- [SHARED AND MENU]
-- ---
-- --- Returns the left direction of the angle.
-- ---
-- ---@return dreamwork.std.Vector3 left_dir The left direction of the angle.
-- function Angle3:getLeft()
--     return setmetatable( { 0, 1, 0 }, Vector3 ):rotate( self )
-- end

-- --- [SHARED AND MENU]
-- ---
-- --- Returns the right direction of the angle.
-- ---
-- ---@return dreamwork.std.Vector3 right_dir The right direction of the angle.
-- function Angle3:getRight()
--     return setmetatable( { 0, -1, 0 }, Vector3 ):rotate( self )
-- end

-- --- [SHARED AND MENU]
-- ---
-- --- Returns the up direction of the angle.
-- ---
-- ---@return dreamwork.std.Vector3 up_dir The up direction of the angle.
-- function Angle3:getUp()
--     return setmetatable( { 0, 0, 1 }, Vector3 ):rotate( self )
-- end

-- --- [SHARED AND MENU]
-- ---
-- --- Returns the down direction of the angle.
-- ---
-- ---@return dreamwork.std.Vector3 down_dir The down direction of the angle.
-- function Angle3:getDown()
--     return setmetatable( { 0, 0, -1 }, Vector3 ):rotate( self )
-- end

do

    local math_angleNormalize = math.angleNormalize

    --- [SHARED AND MENU]
    ---
    --- Normalizes the angle.
    ---
    ---@return dreamwork.std.Angle3 ang3 The normalized angle.
    function Angle3:normalize()
        self[ 1 ] = math_angleNormalize( self[ 1 ] )
        self[ 2 ] = math_angleNormalize( self[ 2 ] )
        self[ 3 ] = math_angleNormalize( self[ 3 ] )
        return self
    end

    --- [SHARED AND MENU]
    ---
    --- Returns a normalized copy of the angle.
    ---
    ---@return dreamwork.std.Angle3 normalized_ang3 A normalized copy of the angle.
    function Angle3:getNormalized()
        return self:copy():normalize()
    end

end

--- [SHARED AND MENU]
---
--- Checks if the angle is within the given tolerance of the given angle.
---
---@param angle dreamwork.std.Angle3 The angle to check against.
---@param tolerance number The tolerance.
---@return boolean is_near `true` if the angle is within the given tolerance of the given angle.
function Angle3:isNear( angle, tolerance )
    return math_abs( self[ 1 ] - angle[ 1 ] ) <= tolerance and
        math_abs( self[ 2 ] - angle[ 2 ] ) <= tolerance and
        math_abs( self[ 3 ] - angle[ 3 ] ) <= tolerance
end

--- [SHARED AND MENU]
---
--- Checks if the angle is zero.
---
---@return boolean is_zero `true` if the angle is zero, `false` otherwise.
function Angle3:isZero()
    return self[ 1 ] == 0 and self[ 2 ] == 0 and self[ 3 ] == 0
end

--- [SHARED AND MENU]
---
--- Sets the angle to zero.
---
---@return dreamwork.std.Angle3 ang3 The angle.
function Angle3:zero()
    self[ 1 ] = 0
    self[ 2 ] = 0
    self[ 3 ] = 0
    return self
end

--- [SHARED AND MENU]
---
--- Rotates the angle around the specified axis by the specified degrees.
---
---@param axis dreamwork.std.Vector3 The axis to rotate around as a normalized unit vector. When argument is not a unit vector, you will experience numerical offset errors in the rotated angle.
---@param rotation number The degrees to rotate around the specified axis.
function Angle3:rotate( axis, rotation )

    return self
end

-- TODO: rewrite & rebuild this

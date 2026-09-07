---@class dreamwork.std
local std = dreamwork.std
local class = std.class

local raw = std.raw
local raw_index = raw.index
local raw_get, raw_set = raw.get, raw.set

local math = std.math
local math_deg = math.deg
local math_rad = math.rad
local math_sqrt = math.sqrt
local math_clamp = math.clamp
local math_sin, math_cos = math.sin, math.cos
local math_acos, math_atan2 = math.acos, math.atan2

--[[

    VMatrix structrue:

    {

        [  1 ] [  2 ] [  3 ] [  4 ] : number[] - row1
        [  5 ] [  6 ] [  7 ] [  8 ] : number[] - row2
        [  9 ] [ 10 ] [ 11 ] [ 12 ] : number[] - row3
        [ 13 ] [ 14 ] [ 15 ] [ 16 ] : number[] - row4

    }

--]]

--- [SHARED AND MENU]
---
--- A 4x4 matrix object.
---
---@class dreamwork.std.VMatrix : dreamwork.std.Object
---@field __class dreamwork.std.VMatrixClass
local VMatrix = class.base( "VMatrix" )

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias VMatrix dreamwork.std.VMatrix

--- [SHARED AND MENU]
---
--- The class used to create new `VMatrix` instances.
---
---@class dreamwork.std.VMatrixClass : dreamwork.std.VMatrix
---@field __base dreamwork.std.VMatrix
---@overload fun( ...: number? ): VMatrix
local VMatrixClass = class.create( VMatrix )
std.VMatrix = VMatrixClass

---@param r1c1 number?
---@param r1c2 number?
---@param r1c3 number?
---@param r1c4 number?
---@param r2c1 number?
---@param r2c2 number?
---@param r2c3 number?
---@param r2c4 number?
---@param r3c1 number?
---@param r3c2 number?
---@param r3c3 number?
---@param r3c4 number?
---@param r4c1 number?
---@param r4c2 number?
---@param r4c3 number?
---@param r4c4 number?
---@protected
function VMatrixClass:__new( r1c1, r1c2, r1c3, r1c4, r2c1, r2c2, r2c3, r2c4, r3c1, r3c2, r3c3, r3c4, r4c1, r4c2, r4c3, r4c4 )
    return setmetatable( {
        r1c1 or 0, r1c2 or 0, r1c3 or 0, r1c4 or 0,
        r2c1 or 0, r2c2 or 0, r2c3 or 0, r2c4 or 0,
        r3c1 or 0, r3c2 or 0, r3c3 or 0, r3c4 or 0,
        r4c1 or 0, r4c2 or 0, r4c3 or 0, r4c4 or 0
    }, VMatrix )
end

---@protected
function VMatrix:__tostring()
    return string.format( "VMatrix: %p\n[\n%.2f %.2f %.2f %.2f,\n%.2f %.2f %.2f %.2f,\n%.2f %.2f %.2f %.2f,\n%.2f %.2f %.2f %.2f\n]", self, self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ], self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ], self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ], self[ 13 ], self[ 14 ], self[ 15 ], self[ 16 ] )
end

---@return dreamwork.std.VMatrix
function VMatrix:identity()
    self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ] = 1, 0, 0, 0
    self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ] = 0, 1, 0, 0
    self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ] = 0, 0, 1, 0
    self[ 13 ], self[ 14 ], self[ 15 ], self[ 16 ] = 0, 0, 0, 1
    return self
end

---@return boolean
function VMatrix:isIdentity()
    return self[ 1 ] == 1 and self[ 2 ] == 0 and self[ 3 ] == 0 and self[ 4 ] == 0 and
        self[ 5 ] == 0 and self[ 6 ] == 1 and self[ 7 ] == 0 and self[ 8 ] == 0 and
        self[ 9 ] == 0 and self[ 10 ] == 0 and self[ 11 ] == 1 and self[ 12 ] == 0 and
        self[ 13 ] == 0 and self[ 14 ] == 0 and self[ 15 ] == 0 and self[ 16 ] == 1
end

---@return dreamwork.std.VMatrix
function VMatrix:zero()
    self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ] = 0, 0, 0, 0
    self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ] = 0, 0, 0, 0
    self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ] = 0, 0, 0, 0
    self[ 13 ], self[ 14 ], self[ 15 ], self[ 16 ] = 0, 0, 0, 0
    return self
end

---@return boolean
function VMatrix:isZero()
    return self[ 1 ] == 0 and self[ 2 ] == 0 and self[ 3 ] == 0 and self[ 4 ] == 0 and
        self[ 5 ] == 0 and self[ 6 ] == 0 and self[ 7 ] == 0 and self[ 8 ] == 0 and
        self[ 9 ] == 0 and self[ 10 ] == 0 and self[ 11 ] == 0 and self[ 12 ] == 0 and
        self[ 13 ] == 0 and self[ 14 ] == 0 and self[ 15 ] == 0 and self[ 16 ] == 0
end

---@return dreamwork.std.VMatrix
function VMatrix:copy()
    return VMatrixClass( self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ], self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ], self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ], self[ 13 ], self[ 14 ], self[ 15 ], self[ 16 ] )
end

---@param matrix dreamwork.std.VMatrix
---@return dreamwork.std.VMatrix
function VMatrix:multiply( matrix )
    local r1c1, r1c2, r1c3, r1c4 = self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ]
    local r2c1, r2c2, r2c3, r2c4 = self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ]
    local r3c1, r3c2, r3c3, r3c4 = self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ]
    local r4c1, r4c2, r4c3, r4c4 = self[ 13 ], self[ 14 ], self[ 15 ], self[ 16 ]

    local sr1c1, sr1c2, sr1c3, sr1c4 = matrix[ 1 ], matrix[ 2 ], matrix[ 3 ], matrix[ 4 ]
    local sr2c1, sr2c2, sr2c3, sr2c4 = matrix[ 5 ], matrix[ 6 ], matrix[ 7 ], matrix[ 8 ]
    local sr3c1, sr3c2, sr3c3, sr3c4 = matrix[ 9 ], matrix[ 10 ], matrix[ 11 ], matrix[ 12 ]
    local sr4c1, sr4c2, sr4c3, sr4c4 = matrix[ 13 ], matrix[ 14 ], matrix[ 15 ], matrix[ 16 ]

    r1c1 = (r1c1 * sr1c1) + (r1c2 * sr2c1) + (r1c3 * sr3c1) + (r1c4 * sr4c1)
    self[ 1 ] = r1c1

    r1c2 = (r1c1 * sr1c2) + (r1c2 * sr2c2) + (r1c3 * sr3c2) + (r1c4 * sr4c2)
    self[ 2 ] = r1c2

    r1c3 = (r1c1 * sr1c3) + (r1c2 * sr2c3) + (r1c3 * sr3c3) + (r1c4 * sr4c3)
    self[ 3 ] = r1c3

    r1c4 = (r1c1 * sr1c4) + (r1c2 * sr2c4) + (r1c3 * sr3c4) + (r1c4 * sr4c4)
    self[ 4 ] = r1c4

    r2c1 = (r2c1 * sr1c1) + (r2c2 * sr2c1) + (r2c3 * sr3c1) + (r2c4 * sr4c1)
    self[ 5 ] = r2c1

    r2c2 = (r2c1 * sr1c2) + (r2c2 * sr2c2) + (r2c3 * sr3c2) + (r2c4 * sr4c2)
    self[ 6 ] = r2c2

    r2c3 = (r2c1 * sr1c3) + (r2c2 * sr2c3) + (r2c3 * sr3c3) + (r2c4 * sr4c3)
    self[ 7 ] = r2c3

    r2c4 = (r2c1 * sr1c4) + (r2c2 * sr2c4) + (r2c3 * sr3c4) + (r2c4 * sr4c4)
    self[ 8 ] = r2c4

    r3c1 = (r3c1 * sr1c1) + (r3c2 * sr2c1) + (r3c3 * sr3c1) + (r3c4 * sr4c1)
    self[ 9 ] = r3c1

    r3c2 = (r3c1 * sr1c2) + (r3c2 * sr2c2) + (r3c3 * sr3c2) + (r3c4 * sr4c2)
    self[ 10 ] = r3c2

    r3c3 = (r3c1 * sr1c3) + (r3c2 * sr2c3) + (r3c3 * sr3c3) + (r3c4 * sr4c3)
    self[ 11 ] = r3c3

    r3c4 = (r3c1 * sr1c4) + (r3c2 * sr2c4) + (r3c3 * sr3c4) + (r3c4 * sr4c4)
    self[ 12 ] = r3c4

    r4c1 = (r4c1 * sr1c1) + (r4c2 * sr2c1) + (r4c3 * sr3c1) + (r4c4 * sr4c1)
    self[ 13 ] = r4c1

    r4c2 = (r4c1 * sr1c2) + (r4c2 * sr2c2) + (r4c3 * sr3c2) + (r4c4 * sr4c2)
    self[ 14 ] = r4c2

    r4c3 = (r4c1 * sr1c3) + (r4c2 * sr2c3) + (r4c3 * sr3c3) + (r4c4 * sr4c3)
    self[ 15 ] = r4c3

    r4c4 = (r4c1 * sr1c4) + (r4c2 * sr2c4) + (r4c3 * sr3c4) + (r4c4 * sr4c4)
    self[ 16 ] = r4c4

    return self
end

---@return dreamwork.std.Vector3
function VMatrix:getForward()
    return std.Vector3( self[ 1 ], self[ 5 ], self[ 9 ] )
end

---@param vector dreamwork.std.Vector3
---@return dreamwork.std.VMatrix
function VMatrix:setForward( vector )
    self[ 1 ], self[ 5 ], self[ 9 ] = vector[ 1 ], vector[ 2 ], vector[ 3 ]
    return self
end

---@return dreamwork.std.Vector3
function VMatrix:getLeft()
    return std.Vector3( self[ 2 ], self[ 6 ], self[ 10 ] )
end

---@param vector dreamwork.std.Vector3
---@return dreamwork.std.VMatrix
function VMatrix:setLeft( vector )
    self[ 2 ], self[ 6 ], self[ 10 ] = vector[ 1 ], vector[ 2 ], vector[ 3 ]
    return self
end

---@return dreamwork.std.Vector3
function VMatrix:getUp()
    return std.Vector3( self[ 3 ], self[ 7 ], self[ 11 ] )
end

---@param vector dreamwork.std.Vector3
---@return dreamwork.std.VMatrix
function VMatrix:setUp( vector )
    self[ 3 ], self[ 7 ], self[ 11 ] = vector[ 1 ], vector[ 2 ], vector[ 3 ]
    return self
end

-- ---@return dreamwork.std.Vector3
-- function VMatrix:getTranslation()
--     return std.Vector3( self[ 4 ], self[ 8 ], self[ 12 ] )
-- end

-- ---@param vector dreamwork.std.Vector3
-- ---@return dreamwork.std.VMatrix
-- function VMatrix:setTranslation( vector )
--     self[ 4 ], self[ 8 ], self[ 12 ] = vector[ 1 ], vector[ 2 ], vector[ 3 ]
--     return self
-- end

-- ---@param vector dreamwork.std.Vector3
-- ---@return dreamwork.std.VMatrix
-- function VMatrix:translate( vector )
--     return self:multiply( VMatrixClass():identity():setTranslation( vector ) )
-- end

---@param row integer
---@param column integer
---@return number
function VMatrix:getField( row, column )
    return self[ (math_clamp( row, 1, 4 ) - 1) * 4 + math_clamp( column, 1, 4 ) ]
end

---@param row integer
---@param column integer
---@param value number
---@return dreamwork.std.VMatrix
function VMatrix:setField( row, column, value )
    self[ (math_clamp( row, 1, 4 ) - 1) * 4 + math_clamp( column, 1, 4 ) ] = value
    return self
end

function VMatrix:inverse()
    local mat = {
        [ 1 ] = {
            self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ], 1, 0, 0, 0
        },
        [ 2 ] = {
            self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ], 0, 1, 0, 0
        },
        [ 3 ] = {
            self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ], 0, 0, 1, 0
        },
        [ 4 ] = {
            self[ 13 ], self[ 14 ], self[ 15 ], self[ 16 ], 0, 0, 0, 1
        }
    }

    local rowMap = { 1, 2, 3, 4 }

    -- Row reduction
    for iRow = 1, 4 do
        local fLargest = 0.00001
        local iLargest = -1

        for iTest = iRow, 4 do
            local fTest = math.abs( mat[ rowMap[ iTest ] ][ iRow ] )
            if fTest > fLargest then
                iLargest = iTest
                fLargest = fTest
            end
        end

        if iLargest == -1 then
            return false, nil
        end

        -- Swap rows
        rowMap[ iLargest ], rowMap[ iRow ] = rowMap[ iRow ], rowMap[ iLargest ]
        local pRow = mat[ rowMap[ iRow ] ]

        -- Normalize row
        local mul = 1.0 / pRow[ iRow ]
        for j = 1, 8, 1 do
            pRow[ j ] = pRow[ j ] * mul
        end

        pRow[ iRow ] = 1.0

        -- Eliminate column
        for i = 1, 4 do
            if i ~= iRow then
                local pScaleRow = mat[ rowMap[ i ] ]
                local mul = -pScaleRow[ iRow ]
                for j = 1, 8 do
                    pScaleRow[ j ] = pScaleRow[ j ] + pRow[ j ] * mul
                end

                pScaleRow[ iRow ] = 0.0
            end
        end
    end

    -- Extract inverse matrix
    local dst = {}

    for i = 1, 4 do
        dst[ i ] = {}
        local pIn = mat[ rowMap[ i ] ]
        for j = 1, 4 do
            dst[ i ][ j ] = pIn[ j + 4 ]
        end
    end

    return true, dst
end

--- [SHARED AND MENU]
---
--- Does a fast inverse, assuming the matrix only contains translation and rotation.
function VMatrix:inverseTranslation()

    local dst = VMatrixClass(
        self[ 1 ], self[ 2 ], self[ 3 ], 0,
        self[ 5 ], self[ 6 ], self[ 7 ], 0,
        self[ 9 ], self[ 10 ], self[ 11 ], 0,
        0, 0, 0, 0
    )
end

function VMatrix:set( other )
    for i = 1, 16 do
        self[ i ] = other[ i ]
    end

    return self
end

function VMatrix:clone()
    local mat = {}

    for i = 1, 16 do
        mat[ i ] = self[ i ]
    end

    return setmetatable( mat, VMatrix )
end

function VMatrix:mul( B )
    local a11, a12, a13, a14 = self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ]
    local a21, a22, a23, a24 = self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ]
    local a31, a32, a33, a34 = self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ]
    local a41, a42, a43, a44 = self[ 13 ], self[ 14 ], self[ 15 ], self[ 16 ]

    local b11, b12, b13, b14 = B[ 1 ], B[ 2 ], B[ 3 ], B[ 4 ]
    local b21, b22, b23, b24 = B[ 5 ], B[ 6 ], B[ 7 ], B[ 8 ]
    local b31, b32, b33, b34 = B[ 9 ], B[ 10 ], B[ 11 ], B[ 12 ]
    local b41, b42, b43, b44 = B[ 13 ], B[ 14 ], B[ 15 ], B[ 16 ]

    self[ 1 ]                = a11 * b11 + a12 * b21 + a13 * b31 + a14 * b41
    self[ 2 ]                = a11 * b12 + a12 * b22 + a13 * b32 + a14 * b42
    self[ 3 ]                = a11 * b13 + a12 * b23 + a13 * b33 + a14 * b43
    self[ 4 ]                = a11 * b14 + a12 * b24 + a13 * b34 + a14 * b44

    self[ 5 ]                = a21 * b11 + a22 * b21 + a23 * b31 + a24 * b41
    self[ 6 ]                = a21 * b12 + a22 * b22 + a23 * b32 + a24 * b42
    self[ 7 ]                = a21 * b13 + a22 * b23 + a23 * b33 + a24 * b43
    self[ 8 ]                = a21 * b14 + a22 * b24 + a23 * b34 + a24 * b44

    self[ 9 ]                = a31 * b11 + a32 * b21 + a33 * b31 + a34 * b41
    self[ 10 ]               = a31 * b12 + a32 * b22 + a33 * b32 + a34 * b42
    self[ 11 ]               = a31 * b13 + a32 * b23 + a33 * b33 + a34 * b43
    self[ 12 ]               = a31 * b14 + a32 * b24 + a33 * b34 + a34 * b44

    self[ 13 ]               = a41 * b11 + a42 * b21 + a43 * b31 + a44 * b41
    self[ 14 ]               = a41 * b12 + a42 * b22 + a43 * b32 + a44 * b42
    self[ 15 ]               = a41 * b13 + a42 * b23 + a43 * b33 + a44 * b43
    self[ 16 ]               = a41 * b14 + a42 * b24 + a43 * b34 + a44 * b44

    return self
end

function VMatrix:rotate( ang )
    local p, y, r = math_rad( ang.p ), math_rad( ang.y ), math_rad( ang.r )
    local sp, cp = math_sin( p ), math_cos( p )
    local sy, cy = math_sin( y ), math_cos( y )
    local sr, cr = math_sin( r ), math_cos( r )

    local r11 = cy * cp
    local r12 = cy * sp * sr - sy * cr
    local r13 = cy * sp * cr + sy * sr

    local r21 = sy * cp
    local r22 = sy * sp * sr + cy * cr
    local r23 = sy * sp * cr - cy * sr

    local r31 = -sp
    local r32 = cp * sr
    local r33 = cp * cr

    local a11, a12, a13 = self[ 1 ], self[ 2 ], self[ 3 ]
    local a21, a22, a23 = self[ 5 ], self[ 6 ], self[ 7 ]
    local a31, a32, a33 = self[ 9 ], self[ 10 ], self[ 11 ]
    local a41, a42, a43 = self[ 13 ], self[ 14 ], self[ 15 ]

    self[ 1 ] = a11 * r11 + a12 * r21 + a13 * r31
    self[ 2 ] = a11 * r12 + a12 * r22 + a13 * r32
    self[ 3 ] = a11 * r13 + a12 * r23 + a13 * r33

    self[ 5 ] = a21 * r11 + a22 * r21 + a23 * r31
    self[ 6 ] = a21 * r12 + a22 * r22 + a23 * r32
    self[ 7 ] = a21 * r13 + a22 * r23 + a23 * r33

    self[ 9 ] = a31 * r11 + a32 * r21 + a33 * r31
    self[ 10 ] = a31 * r12 + a32 * r22 + a33 * r32
    self[ 11 ] = a31 * r13 + a32 * r23 + a33 * r33

    self[ 13 ] = a41 * r11 + a42 * r21 + a43 * r31
    self[ 14 ] = a41 * r12 + a42 * r22 + a43 * r32
    self[ 15 ] = a41 * r13 + a42 * r23 + a43 * r33

    return self
end

function VMatrix:invert()
    local m11, m12, m13, m14          = self[ 1 ], self[ 2 ], self[ 3 ], self[ 4 ]
    local m21, m22, m23, m24          = self[ 5 ], self[ 6 ], self[ 7 ], self[ 8 ]
    local m31, m32, m33, m34          = self[ 9 ], self[ 10 ], self[ 11 ], self[ 12 ]

    self[ 1 ], self[ 2 ], self[ 3 ]   = m11, m21, m31
    self[ 5 ], self[ 6 ], self[ 7 ]   = m12, m22, m32
    self[ 9 ], self[ 10 ], self[ 11 ] = m13, m23, m33

    self[ 4 ]                         = -(m11 * m14 + m21 * m24 + m31 * m34)
    self[ 8 ]                         = -(m12 * m14 + m22 * m24 + m32 * m34)
    self[ 12 ]                        = -(m13 * m14 + m23 * m24 + m33 * m34)

    return self
end

function VMatrix:lerp( t, target, tAngle )
    tAngle = tAngle or t

    -- rotation / scale
    local a11, a12, a13 = self[ 1 ], self[ 2 ], self[ 3 ]
    local a21, a22, a23 = self[ 5 ], self[ 6 ], self[ 7 ]
    local a31, a32, a33 = self[ 9 ], self[ 10 ], self[ 11 ]

    local b11, b12, b13 = target[ 1 ], target[ 2 ], target[ 3 ]
    local b21, b22, b23 = target[ 5 ], target[ 6 ], target[ 7 ]
    local b31, b32, b33 = target[ 9 ], target[ 10 ], target[ 11 ]

    -- scale calc
    local sx1 = math_sqrt( a11 * a11 + a21 * a21 + a31 * a31 ); sx1 = sx1 < 1e-6 and 1.0 or sx1
    local sy1 = math_sqrt( a12 * a12 + a22 * a22 + a32 * a32 ); sy1 = sy1 < 1e-6 and 1.0 or sy1
    local sz1 = math_sqrt( a13 * a13 + a23 * a23 + a33 * a33 ); sz1 = sz1 < 1e-6 and 1.0 or sz1

    local sx2 = math_sqrt( b11 * b11 + b21 * b21 + b31 * b31 ); sx2 = sx2 < 1e-6 and 1.0 or sx2
    local sy2 = math_sqrt( b12 * b12 + b22 * b22 + b32 * b32 ); sy2 = sy2 < 1e-6 and 1.0 or sy2
    local sz2 = math_sqrt( b13 * b13 + b23 * b23 + b33 * b33 ); sz2 = sz2 < 1e-6 and 1.0 or sz2

    local isx1, isy1, isz1 = 1.0 / sx1, 1.0 / sy1, 1.0 / sz1
    local isx2, isy2, isz2 = 1.0 / sx2, 1.0 / sy2, 1.0 / sz2

    a11, a21, a31 = a11 * isx1, a21 * isx1, a31 * isx1
    a12, a22, a32 = a12 * isy1, a22 * isy1, a32 * isy1
    a13, a23, a33 = a13 * isz1, a23 * isz1, a33 * isz1

    b11, b21, b31 = b11 * isx2, b21 * isx2, b31 * isx2
    b12, b22, b32 = b12 * isy2, b22 * isy2, b32 * isy2
    b13, b23, b33 = b13 * isz2, b23 * isz2, b33 * isz2

    -- matrix 1 -> quaternion
    local q1x, q1y, q1z, q1w
    local tr1 = a11 + a22 + a33
    if tr1 > 0 then
        local S = math_sqrt( tr1 + 1.0 ) * 2.0
        local invS = 1.0 / S
        q1w, q1x, q1y, q1z = 0.25 * S, (a32 - a23) * invS, (a13 - a31) * invS, (a21 - a12) * invS
    elseif a11 > a22 and a11 > a33 then
        local S = math_sqrt( 1.0 + a11 - a22 - a33 ) * 2.0
        local invS = 1.0 / S
        q1w, q1x, q1y, q1z = (a32 - a23) * invS, 0.25 * S, (a12 + a21) * invS, (a13 + a31) * invS
    elseif a22 > a33 then
        local S = math_sqrt( 1.0 + a22 - a11 - a33 ) * 2.0
        local invS = 1.0 / S
        q1w, q1x, q1y, q1z = (a13 - a31) * invS, (a12 + a21) * invS, 0.25 * S, (a23 + a32) * invS
    else
        local S = math_sqrt( 1.0 + a33 - a11 - a22 ) * 2.0
        local invS = 1.0 / S
        q1w, q1x, q1y, q1z = (a21 - a12) * invS, (a13 + a31) * invS, (a23 + a32) * invS, 0.25 * S
    end

    -- matrix 2 -> quaternion
    local q2x, q2y, q2z, q2w
    local tr2 = b11 + b22 + b33
    if tr2 > 0 then
        local S = math_sqrt( tr2 + 1.0 ) * 2.0
        local invS = 1.0 / S
        q2w, q2x, q2y, q2z = 0.25 * S, (b32 - b23) * invS, (b13 - b31) * invS, (b21 - b12) * invS
    elseif b11 > b22 and b11 > b33 then
        local S = math_sqrt( 1.0 + b11 - b22 - b33 ) * 2.0
        local invS = 1.0 / S
        q2w, q2x, q2y, q2z = (b32 - b23) * invS, 0.25 * S, (b12 + b21) * invS, (b13 + b31) * invS
    elseif b22 > b33 then
        local S = math_sqrt( 1.0 + b22 - b11 - b33 ) * 2.0
        local invS = 1.0 / S
        q2w, q2x, q2y, q2z = (b13 - b31) * invS, (b12 + b21) * invS, 0.25 * S, (b23 + b32) * invS
    else
        local S = math_sqrt( 1.0 + b33 - b11 - b22 ) * 2.0
        local invS = 1.0 / S
        q2w, q2x, q2y, q2z = (b21 - b12) * invS, (b13 + b31) * invS, (b23 + b32) * invS, 0.25 * S
    end

    -- Dot product
    local dot = q1x * q2x + q1y * q2y + q1z * q2z + q1w * q2w

    if dot < 0 then
        q2x, q2y, q2z, q2w = -q2x, -q2y, -q2z, -q2w
        dot = -dot
    end

    local qx, qy, qz, qw
    if dot > 0.9995 then
        -- NLERP (quaternions almost equal)
        qx = q1x + tAngle * (q2x - q1x)
        qy = q1y + tAngle * (q2y - q1y)
        qz = q1z + tAngle * (q2z - q1z)
        qw = q1w + tAngle * (q2w - q1w)

        local inv_len = 1.0 / math_sqrt( qx * qx + qy * qy + qz * qz + qw * qw )
        qx, qy, qz, qw = qx * inv_len, qy * inv_len, qz * inv_len, qw * inv_len
    else
        -- SLERP
        local theta_0 = math_acos( dot )

        -- sin(acos(x)) ~ sqrt(1 - x^2)
        local inv_sin = 1.0 / math_sqrt( 1.0 - dot * dot )

        local s0 = math_sin( (1.0 - tAngle) * theta_0 ) * inv_sin
        local s1 = math_sin( tAngle * theta_0 ) * inv_sin

        qx = s0 * q1x + s1 * q2x
        qy = s0 * q1y + s1 * q2y
        qz = s0 * q1z + s1 * q2z
        qw = s0 * q1w + s1 * q2w
    end

    -- quaternion back to matrix
    local xx, yy, zz = qx * qx, qy * qy, qz * qz
    local xy, xz, xw = qx * qy, qx * qz, qx * qw
    local yz, yw, zw = qy * qz, qy * qw, qz * qw

    local sx = sx1 + t * (sx2 - sx1)
    local sy = sy1 + t * (sy2 - sy1)
    local sz = sz1 + t * (sz2 - sz1)

    self[ 1 ] = (1.0 - 2.0 * (yy + zz)) * sx
    self[ 2 ] = (2.0 * (xy - zw)) * sy
    self[ 3 ] = (2.0 * (xz + yw)) * sz

    self[ 5 ] = (2.0 * (xy + zw)) * sx
    self[ 6 ] = (1.0 - 2.0 * (xx + zz)) * sy
    self[ 7 ] = (2.0 * (yz - xw)) * sz

    self[ 9 ] = (2.0 * (xz - yw)) * sx
    self[ 10 ] = (2.0 * (yz + xw)) * sy
    self[ 11 ] = (1.0 - 2.0 * (xx + yy)) * sz

    -- translation and 4-line projection interpolation into matrix
    self[ 4 ] = self[ 4 ] + t * (target[ 4 ] - self[ 4 ])
    self[ 8 ] = self[ 8 ] + t * (target[ 8 ] - self[ 8 ])
    self[ 12 ] = self[ 12 ] + t * (target[ 12 ] - self[ 12 ])

    self[ 13 ] = self[ 13 ] + t * (target[ 13 ] - self[ 13 ])
    self[ 14 ] = self[ 14 ] + t * (target[ 14 ] - self[ 14 ])
    self[ 15 ] = self[ 15 ] + t * (target[ 15 ] - self[ 15 ])
    self[ 16 ] = self[ 16 ] + t * (target[ 16 ] - self[ 16 ])

    return self
end

function VMatrix:getAngles()
    local a11, a12, a13 = self[ 1 ], self[ 2 ], self[ 3 ]
    local a21, a22, a23 = self[ 5 ], self[ 6 ], self[ 7 ]
    local a31, a32, a33 = self[ 9 ], self[ 10 ], self[ 11 ]

    local xyDist = math_sqrt( a11 * a11 + a21 * a21 )

    local p, y, r

    if xyDist > 0.001 then
        p = math_deg( math_atan2( -a31, xyDist ) )
        y = math_deg( math_atan2( a21, a11 ) )
        r = math_deg( math_atan2( a32, a33 ) )
    else
        p = math_deg( math_atan2( -a31, xyDist ) )
        y = math_deg( math_atan2( -a12, a22 ) )
        r = 0
    end

    return p, y, r
end

function VMatrix:setAngles( ang )
    local p, y, r = math_rad( ang.p ), math_rad( ang.y ), math_rad( ang.r )

    local sp, cp = math_sin( p ), math_cos( p )
    local sy, cy = math_sin( y ), math_cos( y )
    local sr, cr = math_sin( r ), math_cos( r )

    self[ 1 ] = cy * cp
    self[ 2 ] = cy * sp * sr - sy * cr
    self[ 3 ] = cy * sp * cr + sy * sr

    self[ 5 ] = sy * cp
    self[ 6 ] = sy * sp * sr + cy * cr
    self[ 7 ] = sy * sp * cr - cy * sr

    self[ 9 ] = -sp
    self[ 10 ] = cp * sr
    self[ 11 ] = cp * cr

    return self
end

function VMatrix:getTranslation()
    return self[ 4 ], self[ 8 ], self[ 12 ]
end

function VMatrix:setTranslation( x, y, z )
    self[ 4 ], self[ 8 ], self[ 12 ] = x, y, z
end

-- TODO: rewrite & rebuild this

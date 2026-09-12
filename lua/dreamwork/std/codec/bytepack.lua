---@class dreamwork.std
local std = dreamwork.std

local setmetatable = std.setmetatable

local math = std.math
local math_isPositive = math.isPositive
local math_clamp, math_floor = math.clamp, math.floor
local math_frexp, math_ldexp = math.frexp, math.ldexp
local math_huge, math_tiny, math_nan = math.huge, math.tiny, math.nan

local bit = std.bit
local bit_band, bit_bor = bit.band, bit.bor
local bit_sign, bit_unsign = bit.sign, bit.unsign
local bit_lshift, bit_rshift = bit.lshift, bit.rshift

local error = std.error


-- TODO: ffi/holylib support?

--- [SHARED AND MENU]
---
--- Library that packs/unpacks types as bytes.
---
---@class dreamwork.std.bytepack
local bytepack = {}
std.bytepack = bytepack

---@alias dreamwork.std.bytepack.Sequence integer[] # The sequence of bytes (integers<0-255>).


--- [SHARED AND MENU]
---
--- Reads signed 1-byte (8 bit) integer as little endian bytes.
---
--- Valid values without loss of precision: `-128` - `127`
---
---@param uint8_1 integer The byte.
---@return integer value The signed 1-byte integer.
function bytepack.readInt8( uint8_1 )
    return uint8_1 - 0x80
end

--- [SHARED AND MENU]
---
--- Writes signed 1-byte (8 bit) integer as little endian bytes.
---
--- Valid values without loss of precision: `-128` - `127`
---
---@param value integer The signed 1-byte integer.
---@return integer uint8_1 The byte.
function bytepack.writeInt8( value )
    return value + 0x80
end

-- U/Int16 Read [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 2-byte (16 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-32768` - `32767`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@return integer value The signed 2-byte integer.
    local function bytepack_readInt16BE( uint8_1, uint8_2 )
        return bit_bor(
            bit_lshift( uint8_1, 8 ),
            uint8_2
        )
    end

    bytepack.readInt16BE = bytepack_readInt16BE

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 2-byte (16 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `65535`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@return integer value The unsigned 2-byte integer.
    function bytepack.readUInt16BE( uint8_1, uint8_2 )
        return bit_unsign( bytepack_readInt16BE( uint8_1, uint8_2 ), 16 )
    end

end

-- U/Int16 Write [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 2-byte (16 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-32768` - `32767`
    ---
    ---@param value integer The signed 2-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    local function bytepack_writeInt16BE( value )
        return bit_band( bit_rshift( value, 8 ), 0xFF ),
            bit_band( value, 0xFF )
    end

    bytepack.writeInt16BE = bytepack_writeInt16BE

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 2-byte (16 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `65535`
    ---
    ---@param value integer The unsigned 2-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    function bytepack.writeUInt16BE( value )
        return bytepack_writeInt16BE( bit_unsign( value, 16 ) )
    end

end

-- U/Int16 Read [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 2-byte (16 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-32768` - `32767`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@return integer value The signed 2-byte integer.
    local function bytepack_readInt16LE( uint8_1, uint8_2 )
        return bit_bor(
            bit_lshift( uint8_2, 8 ),
            uint8_1
        )
    end

    bytepack.readInt16LE = bytepack_readInt16LE

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 2-byte (16 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `65535`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@return integer value The unsigned 2-byte integer.
    function bytepack.readUInt16LE( uint8_1, uint8_2 )
        return bit_unsign( bytepack_readInt16LE( uint8_1, uint8_2 ), 16 )
    end

end

-- U/Int16 Write [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 2-byte (16 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-32768` - `32767`
    ---
    ---@param value integer The signed 2-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    local function bytepack_writeInt16LE( value )
        return bit_band( value, 0xFF ),
            bit_band( bit_rshift( value, 8 ), 0xFF )
    end

    bytepack.writeInt16LE = bytepack_writeInt16LE

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 2-byte (16 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `65535`
    ---
    ---@param value integer The unsigned 2-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    function bytepack.writeUInt16LE( value )
        return bytepack_writeInt16LE( bit_unsign( value, 16 ) )
    end

end

-- U/Int24 Read [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 3-byte (24 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-8388608` - `8388607`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@return integer value The signed 3-byte integer.
    local function bytepack_readInt24BE( uint8_1, uint8_2, uint8_3 )
        return bit_bor(
            bit_lshift( uint8_1, 16 ),
            bit_lshift( uint8_2, 8 ),
            uint8_3
        )
    end

    bytepack.readInt24BE = bytepack_readInt24BE

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 3-byte (24 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `16777215`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@return integer value The unsigned 3-byte integer.
    function bytepack.readUInt24BE( uint8_1, uint8_2, uint8_3 )
        return bit_unsign( bytepack_readInt24BE( uint8_1, uint8_2, uint8_3 ), 24 )
    end

end

-- U/Int24 Write [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 3-byte (24 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-8388608` - `8388607`
    ---
    ---@param value integer The signed 3-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    local function bytepack_writeInt24BE( value )
        return bit_band( bit_rshift( value, 16 ), 0xFF ),
            bit_band( bit_rshift( value, 8 ), 0xFF ),
            bit_band( value, 0xFF )
    end

    bytepack.writeInt24BE = bytepack_writeInt24BE

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 3-byte (24 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `16777215`
    ---
    ---@param value integer The unsigned 3-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    function bytepack.writeUInt24BE( value )
        return bytepack_writeInt24BE( bit_unsign( value, 24 ) )
    end

end

-- U/Int24 Read [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 3-byte (24 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-8388608` - `8388607`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@return integer value The signed 3-byte integer.
    local function bytepack_readInt24LE( uint8_1, uint8_2, uint8_3 )
        return bit_bor(
            bit_lshift( uint8_3, 16 ),
            bit_lshift( uint8_2, 8 ),
            uint8_1
        )
    end

    bytepack.readInt24LE = bytepack_readInt24LE

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 3-byte (24 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `16777215`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@return integer value The unsigned 3-byte integer.
    function bytepack.readUInt24LE( uint8_1, uint8_2, uint8_3 )
        return bit_unsign( bytepack_readInt24LE( uint8_1, uint8_2, uint8_3 ), 24 )
    end

end

-- U/Int24 Write [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 3-byte (24 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-8388608` - `8388607`
    ---
    ---@param value integer The signed 3-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    local function bytepack_writeInt24LE( value )
        return bit_band( value, 0xFF ),
            bit_band( bit_rshift( value, 8 ), 0xFF ),
            bit_band( bit_rshift( value, 16 ), 0xFF )
    end

    bytepack.writeInt24LE = bytepack_writeInt24LE

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 3-byte (24 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `16777215`
    ---
    ---@param value integer The unsigned 3-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    function bytepack.writeUInt24LE( value )
        return bytepack.writeInt24LE( bit_unsign( value, 24 ) )
    end

end

-- U/Int32 Read [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 4-byte (32 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `-2147483648` - `2147483647`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@return integer value The signed 4-byte integer.
    local function bytepack_readInt32BE( uint8_1, uint8_2, uint8_3, uint8_4 )
        return bit_bor(
            bit_lshift( uint8_1, 24 ),
            bit_lshift( uint8_2, 16 ),
            bit_lshift( uint8_3, 8 ),
            uint8_4
        )
    end

    bytepack.readInt32BE = bytepack_readInt32BE

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 4-byte (32 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `4294967295`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@return integer value The unsigned 4-byte integer.
    function bytepack.readUInt32BE( uint8_1, uint8_2, uint8_3, uint8_4 )
        return bit_unsign( bytepack_readInt32BE( uint8_1, uint8_2, uint8_3, uint8_4 ) )
    end

end

-- U/Int32 Write [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 4-byte (32 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-2147483648` - `2147483647`
    ---
    ---@param value integer The signed 4-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    local function bytepack_writeInt32BE( value )
        return bit_band( bit_rshift( value, 24 ), 0xFF ),
            bit_band( bit_rshift( value, 16 ), 0xFF ),
            bit_band( bit_rshift( value, 8 ), 0xFF ),
            bit_band( value, 0xFF )
    end

    bytepack.writeInt32BE = bytepack_writeInt32BE

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 4-byte (32 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `4294967295`
    ---
    ---@param value integer The unsigned 4-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    function bytepack.writeUInt32BE( value )
        return bytepack_writeInt32BE( bit_unsign( value ) )
    end

end

-- U/Int32 Read [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 4-byte (32 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `-2147483648` - `2147483647`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@return integer value The signed 4-byte integer.
    local function bytepack_readInt32LE( uint8_1, uint8_2, uint8_3, uint8_4 )
        return bit_bor(
            bit_lshift( uint8_4, 24 ),
            bit_lshift( uint8_3, 16 ),
            bit_lshift( uint8_2, 8 ),
            uint8_1
        )
    end

    bytepack.readInt32LE = bytepack_readInt32LE

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 4-byte (32 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `4294967295`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@return integer value The unsigned 4-byte integer.
    function bytepack.readUInt32LE( uint8_1, uint8_2, uint8_3, uint8_4 )
        return bit_unsign( bytepack_readInt32LE( uint8_1, uint8_2, uint8_3, uint8_4 ) )
    end

end

-- U/Int32 Write [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 4-byte (32 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-2147483648` - `2147483647`
    ---
    ---@param value integer The signed 4-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    local function bytepack_writeInt32LE( value )
        return bit_band( value, 0xFF ),
            bit_band( bit_rshift( value, 8 ), 0xFF ),
            bit_band( bit_rshift( value, 16 ), 0xFF ),
            bit_band( bit_rshift( value, 24 ), 0xFF )
    end

    bytepack.writeInt32LE = bytepack_writeInt32LE

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 4-byte (32 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `4294967295`
    ---
    ---@param value integer The unsigned 4-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    function bytepack.writeUInt32LE( value )
        return bytepack_writeInt32LE( bit_unsign( value ) )
    end

end

-- U/Int40 Read [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 5-byte (40 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `1099511627775`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@return integer value The unsigned 5-byte integer.
    local function bytepack_readUInt40BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5 )
        return (((uint8_1 * 0x100 + uint8_2) * 0x100 + uint8_3) * 0x100 + uint8_4) * 0x100 + uint8_5
    end

    bytepack.readUInt40BE = bytepack_readUInt40BE

    --- [SHARED AND MENU]
    ---
    --- Reads signed 5-byte (40 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `-549755813888` - `549755813887`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@return integer value The signed 5-byte integer.
    function bytepack.readInt40BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5 )
        return bytepack_readUInt40BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5 ) - 0x8000000000
    end

end

-- U/Int40 Write [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 5-byte (40 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `1099511627775`.
    ---
    ---@param value integer The unsigned 5-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    local function bytepack_writeUInt40BE( value )
        return math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            value % 0x100
    end

    bytepack.writeUInt40BE = bytepack_writeUInt40BE

    --- [SHARED AND MENU]
    ---
    --- Writes signed 5-byte (40 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-549755813888` - `549755813887`
    ---
    ---@param value integer The signed 5-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    function bytepack.writeInt40BE( value )
        return bytepack_writeUInt40BE( value + 0x8000000000 )
    end

end

-- U/Int40 Read [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 5-byte (40 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `1099511627775`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@return integer value The unsigned 5-byte integer.
    local function bytepack_readUInt40LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5 )
        return (((uint8_5 * 0x100 + uint8_4) * 0x100 + uint8_3) * 0x100 + uint8_2) * 0x100 + uint8_1
    end

    bytepack.readUInt40LE = bytepack_readUInt40LE

    --- [SHARED AND MENU]
    ---
    --- Reads signed 5-byte (40 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `-549755813888` - `549755813887`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@return integer value The signed 5-byte integer.
    function bytepack.readInt40LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5 )
        return bytepack_readUInt40LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5 ) - 0x8000000000
    end

end

-- U/Int40 Write [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 5-byte (40 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `1099511627775`.
    ---
    ---@param value integer The unsigned 5-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    local function bytepack_writeUInt40LE( value )
        return value % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100
    end

    bytepack.writeUInt40LE = bytepack_writeUInt40LE

    --- [SHARED AND MENU]
    ---
    --- Writes signed 5-byte (40 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-549755813888` - `549755813887`
    ---
    ---@param value integer The signed 5-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    function bytepack.writeInt40LE( value )
        return bytepack_writeUInt40LE( value + 0x8000000000 )
    end

end

-- U/Int48 Read [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 6-byte (48 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `281474976710655`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@return integer value The unsigned 6-byte integer.
    local function bytepack_readUInt48BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 )
        return ((((uint8_1 * 0x100 + uint8_2) * 0x100 + uint8_3) * 0x100 + uint8_4) * 0x100 + uint8_5) * 0x100 + uint8_6
    end

    bytepack.readUInt48BE = bytepack_readUInt48BE

    --- [SHARED AND MENU]
    ---
    --- Reads signed 6-byte (48 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `-140737488355328` - `140737488355327`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@return integer value The signed 6-byte integer.
    function bytepack.readInt48BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 )
        return bytepack_readUInt48BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 ) - 0x800000000000
    end

end

-- U/Int48 Write [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 6-byte (48 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `281474976710655`
    ---
    ---@param value integer The unsigned 6-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    local function bytepack_writeUInt48BE( value )
        return math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            value % 0x100
    end

    bytepack.writeUInt48BE = bytepack_writeUInt48BE

    --- [SHARED AND MENU]
    ---
    --- Writes signed 6-byte (48 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-140737488355328` - `140737488355327`
    ---
    ---@param value integer The signed 6-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    function bytepack.writeInt48BE( value )
        return bytepack_writeUInt48BE( value + 0x800000000000 )
    end

end


-- U/Int48 Read [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 6-byte (48 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `281474976710655`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@return integer value The unsigned 6-byte integer.
    local function bytepack_readUInt48LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 )
        return ((((uint8_6 * 0x100 + uint8_5) * 0x100 + uint8_4) * 0x100 + uint8_3) * 0x100 + uint8_2) * 0x100 + uint8_1
    end

    bytepack.readUInt48LE = bytepack_readUInt48LE

    --- [SHARED AND MENU]
    ---
    --- Reads signed 6-byte (48 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `-140737488355328` - `140737488355327`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@return integer value The signed 6-byte integer.
    function bytepack.readInt48LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 )
        return bytepack_readUInt48LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 ) - 0x800000000000
    end

end

-- U/Int48 Write [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 6-byte (48 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `281474976710655`
    ---
    ---@param value integer The unsigned 6-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    local function bytepack_writeUInt48LE( value )
        return value % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100
    end

    bytepack.writeUInt48LE = bytepack_writeUInt48LE

    --- [SHARED AND MENU]
    ---
    --- Writes signed 6-byte (48 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-140737488355328` - `140737488355327`
    ---
    ---@param value integer The signed 6-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    function bytepack.writeInt48LE( value )
        return bytepack_writeUInt48LE( value + 0x800000000000 )
    end

end

-- U/Int56 Read [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 7-byte (56 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@return integer value The unsigned 7-byte integer.
    function bytepack.readUInt56BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7 )
        return (((((uint8_1 * 0x100 + uint8_2) * 0x100 + uint8_3) * 0x100 + uint8_4) * 0x100 + uint8_5) * 0x100 + uint8_6) * 0x100 + uint8_7
    end

    --- [SHARED AND MENU]
    ---
    --- Reads signed 7-byte (56 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `-36028797018963968` - `36028797018963967`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@return integer value The signed 7-byte integer.
    function bytepack.readInt56BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7 )
        if uint8_1 < 0x80 then
            return (((((uint8_1 * 0x100 + uint8_2) * 0x100 + uint8_3) * 0x100 + uint8_4) * 0x100 + uint8_5) * 0x100 + uint8_6) * 0x100 + uint8_7
        else
            return (((((((uint8_1 - 0xFF) * 0x100 + (uint8_2 - 0xFF)) * 0x100 + (uint8_3 - 0xFF)) * 0x100 + (uint8_4 - 0xFF)) * 0x100 + (uint8_5 - 0xFF)) * 0x100 + (uint8_6 - 0xFF)) * 0x100 + (uint8_7 - 0xFF)) - 1
        end
    end

end

-- U/Int56 Write [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 7-byte (56 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param value integer The unsigned 7-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    function bytepack.writeUInt56BE( value )
        return math_floor( value / 0x1000000000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            value % 0x100
    end

    --- [SHARED AND MENU]
    ---
    --- Writes signed 7-byte (56 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-36028797018963968` - `36028797018963967`
    ---
    ---@param value integer The signed 7-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    function bytepack.writeInt56BE( value )
        return math_isPositive( value ) and 0 or 0xFF,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            value % 0x100
    end

end

-- U/Int56 Read [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 7-byte (56 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@return integer value The unsigned 7-byte integer.
    function bytepack.readUInt56LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7 )
        return (((((uint8_7 * 0x100 + uint8_6) * 0x100 + uint8_5) * 0x100 + uint8_4) * 0x100 + uint8_3) * 0x100 + uint8_2) * 0x100 + uint8_1
    end

    --- [SHARED AND MENU]
    ---
    --- Reads signed 7-byte (56 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `-36028797018963968` - `36028797018963967`
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@return integer value The signed 7-byte integer.
    function bytepack.readInt56LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7 )
        if uint8_1 < 0x80 then
            return (((((uint8_7 * 0x100 + uint8_6) * 0x100 + uint8_5) * 0x100 + uint8_4) * 0x100 + uint8_3) * 0x100 + uint8_2) * 0x100 + uint8_1
        else
            return (((((((uint8_7 - 0xFF) * 0x100 + (uint8_6 - 0xFF)) * 0x100 + (uint8_5 - 0xFF)) * 0x100 + (uint8_4 - 0xFF)) * 0x100 + (uint8_3 - 0xFF)) * 0x100 + (uint8_2 - 0xFF)) * 0x100 + (uint8_1 - 0xFF)) - 1
        end
    end

end

-- U/Int56 Write [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 7-byte (56 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param value integer The unsigned 7-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    function bytepack.writeUInt56LE( value )
        return value % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x1000000000000 ) % 0x100
    end

    --- [SHARED AND MENU]
    ---
    --- Writes signed 7-byte (56 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-36028797018963968` - `36028797018963967`
    ---
    ---@param value integer The signed 7-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    function bytepack.writeInt56LE( value )
        return value % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_isPositive( value ) and 0 or 0xFF
    end

end

-- U/Int64 Read [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 8-byte (64 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@param uint8_8 integer The eighth byte.
    ---@return integer value The unsigned 8-byte integer.
    function bytepack.readUInt64BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
        return ((((((uint8_1 * 0x100 + uint8_2) * 0x100 + uint8_3) * 0x100 + uint8_4) * 0x100 + uint8_5) * 0x100 + uint8_6) * 0x100 + uint8_7) * 0x100 + uint8_8
    end

    --- [SHARED AND MENU]
    ---
    --- Reads signed 8-byte (64 bit) integer from big endian bytes.
    ---
    --- Valid values without loss of precision: `-9007199254740991` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@param uint8_8 integer The eighth byte.
    ---@return integer value The signed 8-byte integer.
    function bytepack.readInt64BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
        if uint8_1 < 0x80 then
            return ((((((uint8_1 * 0x100 + uint8_2) * 0x100 + uint8_3) * 0x100 + uint8_4) * 0x100 + uint8_5) * 0x100 + uint8_6) * 0x100 + uint8_7) * 0x100 + uint8_8
        else
            return ((((((((uint8_1 - 0xFF) * 0x100 + (uint8_2 - 0xFF)) * 0x100 + (uint8_3 - 0xFF)) * 0x100 + (uint8_4 - 0xFF)) * 0x100 + (uint8_5 - 0xFF)) * 0x100 + (uint8_6 - 0xFF)) * 0x100 + (uint8_7 - 0xFF)) * 0x100 + (uint8_8 - 0xFF)) - 1
        end
    end

end

-- U/Int64 Write [BE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 8-byte (64 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param value integer The unsigned 8-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    function bytepack.writeUInt64BE( value )
        return 0, -- skip first byte because luajit cannot handle such huge numbers
            math_floor( value / 0x1000000000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            value % 0x100
    end

    --- [SHARED AND MENU]
    ---
    --- Writes signed 8-byte (64 bit) integer as big endian bytes.
    ---
    --- Valid values without loss of precision: `-9007199254740991` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param value integer The signed 8-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    function bytepack.writeInt64BE( value )
        return math_isPositive( value ) and 0 or 0xFF,
            math_floor( value / 0x1000000000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            value % 0x100
    end

end

-- U/Int64 Read [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 8-byte (64 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@param uint8_8 integer The eighth byte.
    ---@return integer value The unsigned 8-byte integer.
    function bytepack.readUInt64LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
        return ((((((uint8_8 * 0x100 + uint8_7) * 0x100 + uint8_6) * 0x100 + uint8_5) * 0x100 + uint8_4) * 0x100 + uint8_3) * 0x100 + uint8_2) * 0x100 + uint8_1
    end

    --- [SHARED AND MENU]
    ---
    --- Reads signed 8-byte (64 bit) integer from little endian bytes.
    ---
    --- Valid values without loss of precision: `-9007199254740991` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@param uint8_8 integer The eighth byte.
    ---@return integer value The signed 8-byte integer.
    function bytepack.readInt64LE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
        if uint8_1 < 0x80 then
            return ((((((uint8_8 * 0x100 + uint8_7) * 0x100 + uint8_6) * 0x100 + uint8_5) * 0x100 + uint8_4) * 0x100 + uint8_3) * 0x100 + uint8_2) * 0x100 + uint8_1
        else
            return ((((((((uint8_8 - 0xFF) * 0x100 + (uint8_7 - 0xFF)) * 0x100 + (uint8_6 - 0xFF)) * 0x100 + (uint8_5 - 0xFF)) * 0x100 + (uint8_4 - 0xFF)) * 0x100 + (uint8_3 - 0xFF)) * 0x100 + (uint8_2 - 0xFF)) * 0x100 + (uint8_1 - 0xFF)) - 1
        end
    end

end


-- U/Int64 Write [LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes unsigned 8-byte (64 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `0` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param value integer The unsigned 8-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    function bytepack.writeUInt64LE( value )
        return value % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x1000000000000 ) % 0x100,
            0 -- skip last byte because luajit cannot handle such huge numbers
    end

    --- [SHARED AND MENU]
    ---
    --- Writes signed 8-byte (64 bit) integer as little endian bytes.
    ---
    --- Valid values without loss of precision: `-9007199254740991` - `9007199254740991`
    ---
    --- All values above will have problems when working with them.
    ---
    ---@param value integer The signed 8-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    function bytepack.writeInt64LE( value )
        return value % 0x100,
            math_floor( value / 0x100 ) % 0x100,
            math_floor( value / 0x10000 ) % 0x100,
            math_floor( value / 0x1000000 ) % 0x100,
            math_floor( value / 0x100000000 ) % 0x100,
            math_floor( value / 0x10000000000 ) % 0x100,
            math_floor( value / 0x1000000000000 ) % 0x100,
            math_isPositive( value ) and 0 or 0xFF
    end

end

-- Float Read [BE/LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 4-byte (32 bit) float from big endian bytes.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@return number value The signed 4-byte float.
    local function bytepack_readFloatBE( uint8_1, uint8_2, uint8_3, uint8_4 )
        local sign = uint8_1 > 0x7F
        local expo = (uint8_1 % 0x80) * 0x2 + math_floor( uint8_2 / 0x80 )
        local mant = ((uint8_2 % 0x80) * 0x100 + uint8_3) * 0x100 + uint8_4

        if mant == 0 and expo == 0 then
            if sign then
                return -0.0
            else
                return 0.0
            end
        elseif expo == 0xFF then
            if mant == 0 then
                if sign then
                    return math_tiny
                else
                    return math_huge
                end
            else
                return math_nan
            end
        end

        if sign then
            return -math_ldexp( 1.0 + mant / 0x800000, expo - 0x7F )
        else
            return math_ldexp( 1.0 + mant / 0x800000, expo - 0x7F )
        end
    end

    bytepack.readFloatBE = bytepack_readFloatBE

    --- [SHARED AND MENU]
    ---
    --- Reads signed 4-byte (32 bit) float from little endian bytes.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@return number value The signed 4-byte float.
    function bytepack.readFloatLE( uint8_1, uint8_2, uint8_3, uint8_4 )
        return bytepack_readFloatBE( uint8_4, uint8_3, uint8_2, uint8_1 )
    end

end

-- Float Write [BE/LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 4-byte (32 bit) float as big endian bytes.
    ---
    ---@param value number The signed 4-byte float.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    local function bytepack_writeFloatBE( value )
        if value ~= value then
            return 0, 0, 136, 255
        end

        local sign = false
        if value < 0.0 then
            value = -value
            sign = true
        end

        local mant, expo = math_frexp( value )
        if mant == math_huge or expo > 0x80 then
            if sign then
                return 0, 0, 128, 255
            else
                return 0, 0, 128, 127
            end
        elseif (mant == 0.0 and expo == 0) or (expo < -0x7E) then
            if (1 / value) == math_huge then
                return 0, 0, 0, 0
            else
                return 0, 0, 0, 128
            end
        end

        mant = math_floor( (mant * 2.0 - 1.0) * math_ldexp( 0.5, 24 ) )
        expo = expo + 0x7E

        return (sign and 0x80 or 0) + math_floor( expo / 0x2 ),
            (expo % 0x2) * 0x80 + math_floor( mant / 0x10000 ),
            math_floor( mant / 0x100 ) % 0x100,
            mant % 0x100
    end

    bytepack.writeFloatBE = bytepack_writeFloatBE

    --- [SHARED AND MENU]
    ---
    --- Writes signed 4-byte (32 bit) float as little endian bytes.
    ---
    ---@param value number The signed 4-byte float.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    function bytepack.writeFloatLE( value )
        local uint8_1, uint8_2, uint8_3, uint8_4 = bytepack_writeFloatBE( value )
        return uint8_4, uint8_3, uint8_2, uint8_1
    end

end

-- Double Read [BE/LE]
do

    --- [SHARED AND MENU]
    ---
    --- Reads signed 8-byte (64 bit) float (double) from big endian bytes.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@param uint8_8 integer The eighth byte.
    ---@return number value The signed 8-byte float.
    local function bytepack_readDoubleBE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
        local sign = uint8_1 > 0x7F
        local expo = (uint8_1 % 0x80) * 0x10 + math_floor( uint8_2 / 0x10 )
        local mant = ((((((uint8_2 % 0x10) * 0x100 + uint8_3) * 0x100 + uint8_4) * 0x100 + uint8_5) * 0x100 + uint8_6) * 0x100 + uint8_7) * 0x100 + uint8_8

        if mant == 0 and expo == 0 then
            if sign then
                return -0.0
            else
                return 0.0
            end
        elseif expo == 0x7FF then
            if mant == 0 then
                if sign then
                    return math_tiny
                else
                    return math_huge
                end
            else
                return math_nan
            end
        end

        if sign then
            return -math_ldexp( 1.0 + mant / 4503599627370496.0, expo - 0x3FF )
        else
            return math_ldexp( 1.0 + mant / 4503599627370496.0, expo - 0x3FF )
        end
    end

    bytepack.readDoubleBE = bytepack_readDoubleBE

    --- [SHARED AND MENU]
    ---
    --- Reads signed 8-byte (64 bit) float (double) from little endian bytes.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@param uint8_8 integer The eighth byte.
    ---@return number value The signed 8-byte float.
    function bytepack.readDoubleLE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
        return bytepack_readDoubleBE( uint8_8, uint8_7, uint8_6, uint8_5, uint8_4, uint8_3, uint8_2, uint8_1 )
    end

end

-- Double Write [BE/LE]
do

    --- [SHARED AND MENU]
    ---
    --- Writes signed 8-byte (64 bit) float (double) as big endian bytes.
    ---
    ---@param value number The signed 8-byte float.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    local function bytepack_writeDoubleBE( value )
        if value ~= value then -- NaN
            return 0, 0, 0, 0, 0, 0, 248, 255
        end

        local sign = false
        if value < 0.0 then
            value = -value
            sign = true
        end

        local mant, expo = math_frexp( value )
        if mant == math_huge or expo > 0x400 then -- inf
            if sign then
                return 0, 0, 0, 0, 0, 0, 240, 255
            else
                return 0, 0, 0, 0, 0, 0, 240, 127
            end
        elseif (mant == 0.0 and expo == 0) or (expo < -0x3FE) then -- zero
            if (1 / value) == math_huge then
                return 0, 0, 0, 0, 0, 0, 0, 0
            else
                return 0, 0, 0, 0, 0, 0, 0, 128
            end
        end

        mant = math_floor( (mant * 2.0 - 1.0) * math_ldexp( 0.5, 53 ) )
        expo = expo + 0x3FE

        return (sign and 0x80 or 0) + math_floor( expo / 0x10 ),
            (expo % 0x10) * 0x10 + math_floor( mant / 0x1000000000000 ),
            math_floor( mant / 0x10000000000 ) % 0x100,
            math_floor( mant / 0x100000000 ) % 0x100,
            math_floor( mant / 0x1000000 ) % 0x100,
            math_floor( mant / 0x10000 ) % 0x100,
            math_floor( mant / 0x100 ) % 0x100,
            mant % 0x100
    end

    bytepack.writeDoubleBE = bytepack_writeDoubleBE

    --- [SHARED AND MENU]
    ---
    --- Writes signed 8-byte (64 bit) float (double) as little endian bytes.
    ---
    ---@param value number The signed 8-byte float.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    function bytepack.writeDoubleLE( value )
        local uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 = bytepack_writeDoubleBE( value )
        return uint8_8, uint8_7, uint8_6, uint8_5, uint8_4, uint8_3, uint8_2, uint8_1
    end

end

--- [SHARED AND MENU]
---
--- Reads `hours`, `minutes` and `seconds` from single `Short` number ( UInt16 ).
---
---@param uint16 integer The uint16 to read from.
---@return integer hours The number of hours.
---@return integer minutes The number of minutes.
---@return integer seconds The number of seconds, **will be rounded**.
function bytepack.readTime( uint16 )
    return bit_rshift( bit_band( uint16, 0xF800 ), 11 ),
        bit_rshift( bit_band( uint16, 0x7E0 ), 5 ),
        bit_band( uint16, 0x1F ) * 2
end

--- [SHARED AND MENU]
---
--- Writes time in DOS format as single `Short` number ( UInt16 ).
---
---@param hours? integer The number of hours.
---@param minutes? integer The number of minutes.
---@param seconds? integer The number of seconds, **will be rounded**.
---@return integer uint16 The uint16 to read from.
function bytepack.writeTime( hours, minutes, seconds )
    if hours == nil then
        hours = 0
    else
        hours = math_clamp( hours, 0, 24 )
    end

    if minutes == nil then
        minutes = 0
    else
        minutes = math_clamp( minutes, 0, 60 )
    end

    if seconds == nil then
        seconds = 0
    else
        seconds = math_floor( math_clamp( seconds, 0, 60 ) * 0.5 )
    end

    return bit_bor(
        bit_lshift( hours, 11 ),
        bit_lshift( minutes, 5 ),
        seconds
    )
end

--- [SHARED AND MENU]
---
--- Reads date in DOS format from single `Short` number ( UInt16 ).
---
---@param uint16 integer The uint16 to read from.
---@return integer day The day.
---@return integer month The month.
---@return integer year The year.
function bytepack.readDate( uint16 )
    return bit_band( uint16, 0x1F ),
        bit_rshift( bit_band( uint16, 0x1E0 ), 5 ),
        bit_rshift( bit_band( uint16, 0xFE00 ), 9 ) + 1980
end

--- [SHARED AND MENU]
---
--- Writes date in DOS format as single `Short` number ( UInt16 ).
---
---@param day? integer The day.
---@param month? integer The month.
---@param year? integer The year.
---@return integer uint16 The uint16 to read from.
function bytepack.writeDate( day, month, year )
    if day == nil then
        day = 1
    else
        day = math_clamp( day, 1, 31 )
    end

    if month == nil then
        month = 1
    else
        month = math_clamp( month, 1, 12 )
    end

    if year == nil then
        year = 0
    else
        year = math_clamp( year, 1980, 2107 ) - 1980
    end

    return bit_bor( day,
        bit_lshift( month, 5 ),
        bit_lshift( year, 9 )
    )
end

--- [SHARED AND MENU]
---
--- Reads fixed-point number (**UQm.n**) from specified integer with `n` bits.
---
--- ### Commonly Used UQm.n Formats (**unsigned**)
--- | Format  | Range                          | Precision (Step)        |
--- |:--------|:-------------------------------|:------------------------|
--- | UQ8.8   | `0 to 255.996`                 | 0.00390625 (1/256)      |
--- | UQ10.6  | `0 to 1023.984375`             | 0.015625 (1/64)         |
--- | UQ12.4  | `0 to 4095.9375`               | 0.0625 (1/16)           |
--- | UQ16.16 | `0 to 65,535.99998`            | 0.0000152588 (1/65536)  |
--- | UQ24.8  | `0 to 16,777,215.996`          | 0.00390625 (1/256)      |
--- | UQ32.16 | `0 to 4,294,967,295.99998`     | 0.0000152588 (1/65536)  |
---
--- ### Commonly Used Qm.n Formats (**signed**)
--- | Format | Range                          | Precision (Step)        |
--- |:-------|:-------------------------------|:------------------------|
--- | Q8.8   | `-128.0 to 127.996`            | 0.00390625 (1/256)      |
--- | Q10.6  | `-512.0 to 511.984375`         | 0.015625 (1/64)         |
--- | Q12.4  | `-2048.0 to 2047.9375`         | 0.0625 (1/16)           |
--- | Q16.16 | `-32,768.0 to 32,767.99998`    | 0.0000152588 (1/65536)  |
--- | Q24.8  | `-8,388,608.0 to 8,388,607.996`| 0.00390625 (1/256)      |
--- | Q32.16 | `-2,147,483,648.0 to 2,147,483,647.99998` | 0.0000152588 (1/65536) |
---
---@param n integer Number of fractional bits.
---@param integer integer The integer number to read from.
---@return number value The unsigned fixed-point number.
function bytepack.readFixedPoint( n, integer )
    if integer == 0 then
        return 0
    else
        return integer / (2 ^ n)
    end
end

--- [SHARED AND MENU]
---
--- Writes unsigned fixed-point number (**UQm.n**) as little endian bytes.
---
--- ### Commonly Used UQm.n Formats
--- | Format  | Range                          | Precision (Step)        |
--- |:--------|:-------------------------------|:------------------------|
--- | UQ8.8   | `0 to 255.996`                 | 0.00390625 (1/256)      |
--- | UQ10.6  | `0 to 1023.984375`             | 0.015625 (1/64)         |
--- | UQ12.4  | `0 to 4095.9375`               | 0.0625 (1/16)           |
--- | UQ16.16 | `0 to 65,535.99998`            | 0.0000152588 (1/65536)  |
--- | UQ24.8  | `0 to 16,777,215.996`          | 0.00390625 (1/256)      |
--- | UQ32.16 | `0 to 4,294,967,295.99998`     | 0.0000152588 (1/65536)  |
---
--- ### Commonly Used Qm.n Formats (**signed**)
--- | Format | Range                          | Precision (Step)        |
--- |:-------|:-------------------------------|:------------------------|
--- | Q8.8   | `-128.0 to 127.996`            | 0.00390625 (1/256)      |
--- | Q10.6  | `-512.0 to 511.984375`         | 0.015625 (1/64)         |
--- | Q12.4  | `-2048.0 to 2047.9375`         | 0.0625 (1/16)           |
--- | Q16.16 | `-32,768.0 to 32,767.99998`    | 0.0000152588 (1/65536)  |
--- | Q24.8  | `-8,388,608.0 to 8,388,607.996`| 0.00390625 (1/256)      |
--- | Q32.16 | `-2,147,483,648.0 to 2,147,483,647.99998` | 0.0000152588 (1/65536) |
---
---@param value number The unsigned fixed-point number.
---@param m integer Number of integer bits (including sign bit).
---@param n integer Number of fractional bits.
---@return integer integer The integer number to read from.
function bytepack.writeFixedPoint( value, m, n )
    local byte_count = (m + n) * 0.125
    if byte_count % 1 ~= 0 then
        error( "invalid count of integer/fractional bits", 2 )
    end

    return value * (2 ^ n)
end

-- HEX Read [BE/LE]
do

    ---@type table<integer, integer>
    local decode_map = {
        -- digits
        [ 0x30 ] = 0x0, --[[ 0 ]]
        [ 0x31 ] = 0x1, --[[ 1 ]]
        [ 0x32 ] = 0x2, --[[ 2 ]]
        [ 0x33 ] = 0x3, --[[ 3 ]]
        [ 0x34 ] = 0x4, --[[ 4 ]]
        [ 0x35 ] = 0x5, --[[ 5 ]]
        [ 0x36 ] = 0x6, --[[ 6 ]]
        [ 0x37 ] = 0x7, --[[ 7 ]]
        [ 0x38 ] = 0x8, --[[ 8 ]]
        [ 0x39 ] = 0x9, --[[ 9 ]]

        -- upper-case letters
        [ 0x41 ] = 0xA, --[[ A ]]
        [ 0x42 ] = 0xB, --[[ B ]]
        [ 0x43 ] = 0xC, --[[ C ]]
        [ 0x44 ] = 0xD, --[[ D ]]
        [ 0x45 ] = 0xE, --[[ E ]]
        [ 0x46 ] = 0xF, --[[ F ]]

        -- lower-case letters
        [ 0x61 ] = 0xA, --[[ a ]]
        [ 0x62 ] = 0xB, --[[ b ]]
        [ 0x63 ] = 0xC, --[[ c ]]
        [ 0x64 ] = 0xD, --[[ d ]]
        [ 0x65 ] = 0xE, --[[ e ]]
        [ 0x66 ] = 0xF, --[[ f ]]
    }

    do

        local raw_pairs = std.raw.pairs
        local uint8_cache = {}

        for i in raw_pairs( decode_map ) do
            for j in raw_pairs( decode_map ) do
                uint8_cache[ bit_lshift( i, 8 ) + j ] = bit_lshift( decode_map[ i ], 4 ) + decode_map[ j ]
            end
        end

        --- [SHARED AND MENU]
        ---
        --- Reads unsigned 1-byte (8 bit) integer from big endian hex bytes.
        ---
        ---@param uint8_1 integer The first byte.
        ---@param uint8_2 integer The second byte.
        ---@return integer | nil value The unsigned 1-byte integer or `nil` if bytes do not match the allowed ones.
        function bytepack.readHex8( uint8_1, uint8_2 )
            return uint8_cache[ bit_lshift( uint8_1, 8 ) + uint8_2 ]
        end

    end

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 2-byte (16 bit) integer from big endian hex bytes.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@return integer value The unsigned 2-byte integer.
    function bytepack.readHex16BE( uint8_1, uint8_2, uint8_3, uint8_4 )
        return bit_bor(
            bit_lshift( decode_map[ uint8_1 ], 12 ),
            bit_lshift( decode_map[ uint8_2 ], 8 ),
            bit_lshift( decode_map[ uint8_3 ], 4 ),
            decode_map[ uint8_4 ]
        )
    end

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 3-byte (24 bit) integer from big endian hex bytes.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@return integer value The unsigned 3-byte integer.
    function bytepack.readHex24BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 )
        return bit_bor(
            bit_lshift( decode_map[ uint8_1 ], 20 ),
            bit_lshift( decode_map[ uint8_2 ], 16 ),
            bit_lshift( decode_map[ uint8_3 ], 12 ),
            bit_lshift( decode_map[ uint8_4 ], 8 ),
            bit_lshift( decode_map[ uint8_5 ], 4 ),
            decode_map[ uint8_6 ]
        )
    end

    --- [SHARED AND MENU]
    ---
    --- Reads unsigned 4-byte (32 bit) integer from big endian hex bytes.
    ---
    ---@param uint8_1 integer The first byte.
    ---@param uint8_2 integer The second byte.
    ---@param uint8_3 integer The third byte.
    ---@param uint8_4 integer The fourth byte.
    ---@param uint8_5 integer The fifth byte.
    ---@param uint8_6 integer The sixth byte.
    ---@param uint8_7 integer The seventh byte.
    ---@param uint8_8 integer The eighth byte.
    ---@return integer value The unsigned 4-byte integer.
    function bytepack.readHex32BE( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
        return bit_bor(
            bit_lshift( decode_map[ uint8_1 ], 28 ),
            bit_lshift( decode_map[ uint8_2 ], 24 ),
            bit_lshift( decode_map[ uint8_3 ], 20 ),
            bit_lshift( decode_map[ uint8_4 ], 16 ),
            bit_lshift( decode_map[ uint8_5 ], 12 ),
            bit_lshift( decode_map[ uint8_6 ], 8 ),
            bit_lshift( decode_map[ uint8_7 ], 4 ),
            decode_map[ uint8_8 ]
        ) % 0xFFFFFFFF
    end

end

-- HEX Write [BE/LE]
do

    ---@type table<integer, integer>
    local encode_map = {
        -- digits
        [ 0x0 ] = 0x30, --[[ 0 ]]
        [ 0x1 ] = 0x31, --[[ 1 ]]
        [ 0x2 ] = 0x32, --[[ 2 ]]
        [ 0x3 ] = 0x33, --[[ 3 ]]
        [ 0x4 ] = 0x34, --[[ 4 ]]
        [ 0x5 ] = 0x35, --[[ 5 ]]
        [ 0x6 ] = 0x36, --[[ 6 ]]
        [ 0x7 ] = 0x37, --[[ 7 ]]
        [ 0x8 ] = 0x38, --[[ 8 ]]
        [ 0x9 ] = 0x39, --[[ 9 ]]

        -- upper-case letters
        [ 0xA ] = 0x41, --[[ A ]]
        [ 0xB ] = 0x42, --[[ B ]]
        [ 0xC ] = 0x43, --[[ C ]]
        [ 0xD ] = 0x44, --[[ D ]]
        [ 0xE ] = 0x45, --[[ E ]]
        [ 0xF ] = 0x46, --[[ F ]]
    }

    ---@type table<integer, integer>
    local hex_cache_1 = {}

    setmetatable( hex_cache_1, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( uint, 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    ---@type table<integer, integer>
    local hex_cache_2 = {}

    setmetatable( hex_cache_2, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( bit_rshift( uint, 4 ), 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    --- [SHARED AND MENU]
    ---
    --- Encodes unsigned 1-byte (8 bit) integer to big endian hex bytes.
    ---
    --- Valid values without loss of precision: `0` - `255`
    ---
    ---@param uint8 integer The unsigned 1-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    function bytepack.writeHex8( uint8 )
        return hex_cache_2[ uint8 ], hex_cache_1[ uint8 ]
    end

    ---@type table<integer, integer>
    local hex_cache_3 = {}

    setmetatable( hex_cache_3, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( bit_rshift( uint, 8 ), 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    ---@type table<integer, integer>
    local hex_cache_4 = {}

    setmetatable( hex_cache_4, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( bit_rshift( uint, 12 ), 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    --- [SHARED AND MENU]
    ---
    --- Encodes unsigned 2-byte (16 bit) integer to big endian hex bytes.
    ---
    --- Valid values without loss of precision: `0` - `65535`
    ---
    ---@param uint16 integer The unsigned 2-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    function bytepack.writeHex16BE( uint16 )
        return hex_cache_4[ uint16 ], hex_cache_3[ uint16 ],
            hex_cache_2[ uint16 ], hex_cache_1[ uint16 ]
    end

    --- [SHARED AND MENU]
    ---
    --- Encodes unsigned 2-byte (16 bit) integer to little endian hex bytes.
    ---
    --- Valid values without loss of precision: `0` - `65535`
    ---
    ---@param uint16 integer The unsigned 2-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    function bytepack.writeHex16LE( uint16 )
        return hex_cache_2[ uint16 ], hex_cache_1[ uint16 ],
            hex_cache_4[ uint16 ], hex_cache_3[ uint16 ]
    end

    ---@type table<integer, integer>
    local hex_cache_5 = {}

    setmetatable( hex_cache_5, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( bit_rshift( uint, 16 ), 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    ---@type table<integer, integer>
    local hex_cache_6 = {}

    setmetatable( hex_cache_6, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( bit_rshift( uint, 20 ), 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    --- [SHARED AND MENU]
    ---
    --- Encodes unsigned 3-byte (24 bit) integer to big endian hex bytes.
    ---
    --- Valid values without loss of precision: `0` - `16777215`
    ---
    ---@param uint24 integer The unsigned 3-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    function bytepack.writeHex24BE( uint24 )
        return hex_cache_6[ uint24 ], hex_cache_5[ uint24 ],
            hex_cache_4[ uint24 ], hex_cache_3[ uint24 ],
            hex_cache_2[ uint24 ], hex_cache_1[ uint24 ]
    end

    --- [SHARED AND MENU]
    ---
    --- Encodes unsigned 3-byte (24 bit) integer to little endian hex bytes.
    ---
    --- Valid values without loss of precision: `0` - `16777215`
    ---
    ---@param uint24 integer The unsigned 3-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    function bytepack.writeHex24LE( uint24 )
        return hex_cache_2[ uint24 ], hex_cache_1[ uint24 ],
            hex_cache_4[ uint24 ], hex_cache_3[ uint24 ],
            hex_cache_6[ uint24 ], hex_cache_5[ uint24 ]
    end

    ---@type table<integer, integer>
    local hex_cache_7 = {}

    setmetatable( hex_cache_7, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( bit_rshift( uint, 24 ), 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    ---@type table<integer, integer>
    local hex_cache_8 = {}

    setmetatable( hex_cache_8, {
        __index = function( self, uint )
            local value = encode_map[ bit_band( bit_rshift( uint, 28 ), 0x0F ) ]
            self[ uint ] = value
            return value
        end,
        __mode = "v"
    } )

    --- [SHARED AND MENU]
    ---
    --- Encodes unsigned 4-byte (32 bit) integer to big endian hex bytes.
    ---
    --- Valid values without loss of precision: `0` - `4294967295`
    ---
    ---@param uint32 integer The unsigned 4-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    function bytepack.writeHex32BE( uint32 )
        return hex_cache_8[ uint32 ], hex_cache_7[ uint32 ],
            hex_cache_6[ uint32 ], hex_cache_5[ uint32 ],
            hex_cache_4[ uint32 ], hex_cache_3[ uint32 ],
            hex_cache_2[ uint32 ], hex_cache_1[ uint32 ]
    end

    --- [SHARED AND MENU]
    ---
    --- Encodes unsigned 4-byte (32 bit) integer to little endian hex bytes.
    ---
    --- Valid values without loss of precision: `0` - `4294967295`
    ---
    ---@param uint32 integer The unsigned 4-byte integer.
    ---@return integer uint8_1 The first byte.
    ---@return integer uint8_2 The second byte.
    ---@return integer uint8_3 The third byte.
    ---@return integer uint8_4 The fourth byte.
    ---@return integer uint8_5 The fifth byte.
    ---@return integer uint8_6 The sixth byte.
    ---@return integer uint8_7 The seventh byte.
    ---@return integer uint8_8 The eighth byte.
    function bytepack.writeHex32LE( uint32 )
        return hex_cache_2[ uint32 ], hex_cache_1[ uint32 ],
            hex_cache_4[ uint32 ], hex_cache_3[ uint32 ],
            hex_cache_6[ uint32 ], hex_cache_5[ uint32 ],
            hex_cache_8[ uint32 ], hex_cache_7[ uint32 ]
    end

end

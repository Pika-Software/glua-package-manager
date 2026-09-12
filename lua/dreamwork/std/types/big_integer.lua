---@class dreamwork.std
local std = dreamwork.std

local setmetatable = std.setmetatable
local tostring = std.tostring
local tonumber = std.tonumber

local isString = std.isString
local isNumber = std.isNumber

local ascii = std.ascii
local ascii_toInteger = ascii.toInteger

local bit = std.bit
local bit_bxor = bit.bxor
local bit_rshift = bit.rshift
local bit_band, bit_bor = bit.band, bit.bor

local raw = std.raw
local raw_select = raw.select
local raw_tonumber = raw.tonumber

local debug = std.debug
local debug_getmetatable = debug.getmetatable

local math = std.math
local math_log2 = math.log2
local math_frexp = math.frexp
local math_relative = math.relative
local math_isNegative = math.isNegative
local math_min, math_max = math.min, math.max
local math_floor, math_clamp = math.floor, math.clamp

local table = std.table
local table_concat = table.concat
local table_unpack = table.unpack

local string = std.string
local string_len = string.len
local string_sub = string.sub
local string_byte = string.byte
local string_format = string.format

local class = std.class
local class_new = class.new

--- [SHARED AND MENU]
---
--- Represents an arbitrary-precision signed integer.
---
--- A `BigInteger` object can represent any integer value that fits in
--- available memory. It supports arithmetic, comparison, conversion,
--- and bitwise operations while preserving exact integer precision.
---
---@class dreamwork.std.BigInteger : dreamwork.std.Object
---@field __class dreamwork.std.BigIntegerClass
---@field bytes integer[]
---@field sign boolean
---@operator add( any ): dreamwork.std.BigInteger
---@operator sub( any ): dreamwork.std.BigInteger
---@operator mul( any ): dreamwork.std.BigInteger
---@operator div( any ): dreamwork.std.BigInteger
---@operator idiv( any ): dreamwork.std.BigInteger
---@operator pow( integer ): dreamwork.std.BigInteger
---@operator unm: dreamwork.std.BigInteger
---@operator bnot: dreamwork.std.BigInteger
---@operator band( any ): dreamwork.std.BigInteger
---@operator bor( any ): dreamwork.std.BigInteger
---@operator bxor( any ): dreamwork.std.BigInteger
---@operator shl( integer ): dreamwork.std.BigInteger
---@operator shr( integer ): dreamwork.std.BigInteger
---@operator len: integer
---@operator concat( any ): string
local BigInteger = class.base( "BigInteger", false, nil )

--- [SHARED AND MENU]
---
--- The class used to create new `BigInteger` instances.
---
--- Arbitrary-precision signed integer type.
---
--- Unlike Lua's built-in integers, `BigInteger` values are limited only by
--- available memory, allowing calculations on integers of virtually
--- unlimited size without overflow.
---
--- Supports the standard arithmetic, comparison, and bitwise operators
--- through metamethods.
---
---@class dreamwork.std.BigIntegerClass : dreamwork.std.BigInteger
---@field __base dreamwork.std.BigInteger
---@overload fun( value: ( dreamwork.std.BigInteger | string | integer | nil ), base: ( integer | nil ) ): dreamwork.std.BigInteger
local BigIntegerClass = class.create( BigInteger )
std.BigInteger = BigIntegerClass

--- [SHARED AND MENU]
---
--- Checks whether the value is a `BigInteger`.
---
---@param value any The value to check.
---@return boolean is_bigint `true` if the value is a `BigInteger`, `false` otherwise.
local function isBigInteger( value )
    return debug_getmetatable( value ) == BigInteger
end

std.isBigInteger = isBigInteger

do

    --- [SHARED AND MENU]
    ---
    --- Checks if a big integer object is zero/empty.
    ---
    ---@return boolean is_zero `true` if the big integer object is zero/empty, `false` otherwise.
    function BigInteger:isZero()
        return self.bytes[ 0 ] == 0
    end

    local BigInteger_isZero = BigInteger.isZero
    BigInteger.isEmpty = BigInteger_isZero

    ---@return boolean
    ---@protected
    function BigInteger:__toboolean()
        return not BigInteger_isZero( self )
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Checks if a big integer object is even.
    ---
    ---@return boolean result `true` if the big integer object is even, `false` otherwise.
    function BigInteger:isEven()
        local bytes = self.bytes
        return bytes[ 0 ] == 0 or (bytes[ 1 ] % 2) == 0
    end

    --- [SHARED AND MENU]
    ---
    --- Checks if a big integer object is odd.
    ---
    ---@return boolean `true` if the big integer object is odd, `false` otherwise.
    function BigInteger:isOdd()
        return not self:isEven()
    end

end

--- [SHARED AND MENU]
---
--- Checks if a big integer object is one.
---
---@return boolean `true` if the big integer object is one, `false` otherwise.
function BigInteger:isOne()
    local bytes = self.bytes
    return bytes[ 0 ] == 1 and bytes[ 1 ] == 1
end

--- [SHARED AND MENU]
---
--- Negates a big integer object.
---
---@return dreamwork.std.BigInteger self The negated big integer object.
function BigInteger:negate()
    self.sign = not self.sign
    return self
end

---@return integer
---@protected
function BigInteger:__len()
    return self.bytes[ 0 ]
end

---@param as_bytes boolean
---@return integer
---@protected
function BigInteger:__sizeof( as_bytes )
    if as_bytes then
        return self.bytes[ 0 ]
    else
        return self.bytes[ 0 ] * 8
    end
end

---@param bytes integer[]
---@param byte_count integer | nil
---@return integer[]
local function bytes_copy( bytes, byte_count )
    if byte_count == nil then
        byte_count = bytes[ 0 ]
    end

    if byte_count == 0 then
        return {
            [ 0 ] = 0,
        }
    end

    -- 1-4 bytes
    if byte_count < 5 then
        return {
            [ 0 ] = byte_count,
            bytes[ 1 ],
            bytes[ 2 ],
            bytes[ 3 ],
            bytes[ 4 ]
        }
    end

    -- 5-8 bytes
    if byte_count < 9 then
        return {
            [ 0 ] = byte_count,
            bytes[ 1 ],
            bytes[ 2 ],
            bytes[ 3 ],
            bytes[ 4 ],
            bytes[ 5 ],
            bytes[ 6 ],
            bytes[ 7 ],
            bytes[ 8 ]
        }
    end

    -- 9-16 bytes
    if byte_count < 17 then
        return {
            [ 0 ] = byte_count,
            bytes[ 1 ],
            bytes[ 2 ],
            bytes[ 3 ],
            bytes[ 4 ],
            bytes[ 5 ],
            bytes[ 6 ],
            bytes[ 7 ],
            bytes[ 8 ],
            bytes[ 9 ],
            bytes[ 10 ],
            bytes[ 11 ],
            bytes[ 12 ],
            bytes[ 13 ],
            bytes[ 14 ],
            bytes[ 15 ],
            bytes[ 16 ]
        }
    end

    -- 17-32 bytes
    if byte_count < 33 then
        return {
            [ 0 ] = byte_count,
            bytes[ 1 ],
            bytes[ 2 ],
            bytes[ 3 ],
            bytes[ 4 ],
            bytes[ 5 ],
            bytes[ 6 ],
            bytes[ 7 ],
            bytes[ 8 ],
            bytes[ 9 ],
            bytes[ 10 ],
            bytes[ 11 ],
            bytes[ 12 ],
            bytes[ 13 ],
            bytes[ 14 ],
            bytes[ 15 ],
            bytes[ 16 ],
            bytes[ 17 ],
            bytes[ 18 ],
            bytes[ 19 ],
            bytes[ 20 ],
            bytes[ 21 ],
            bytes[ 22 ],
            bytes[ 23 ],
            bytes[ 24 ],
            bytes[ 25 ],
            bytes[ 26 ],
            bytes[ 27 ],
            bytes[ 28 ],
            bytes[ 29 ],
            bytes[ 30 ],
            bytes[ 31 ],
            bytes[ 32 ]
        }
    end

    -- more that 4096 bytes (wow, that's too much i guess)
    if byte_count > 4096 then
        -- actuall limit is 7997, but i dont sure
        local copy = {
            [ 0 ] = byte_count,
        }

        for i = 1, byte_count, 1 do
            copy[ i ] = bytes[ i ]
        end

        return copy
    end

    return {
        [ 0 ] = byte_count,
        table_unpack( bytes, 1, byte_count )
    }
end

---@param a_bytes integer[]
---@param a_byte_count integer
---@param b_bytes integer[]
---@param b_byte_count integer
---@return `-1` | `0` | `1`
local function bytes_unsigned_compare( a_bytes, a_byte_count, b_bytes, b_byte_count )
    if a_byte_count < b_byte_count then
        return -1
    elseif a_byte_count > b_byte_count then
        return 1
    end

    for i = a_byte_count, 1, -1 do
        if a_bytes[ i ] < b_bytes[ i ] then
            return -1
        elseif a_bytes[ i ] > b_bytes[ i ] then
            return 1
        end
    end

    return 0
end

---@param a dreamwork.std.BigInteger
---@param b dreamwork.std.BigInteger
---@return `-1` | `0` | `1`
local function compare( a, b )
    if a.sign then
        if not b.sign then
            return -1
        end
    elseif b.sign then
        return 1
    end

    local a_bytes, b_bytes = a.bytes, b.bytes
    local a_byte_count, b_byte_count = a_bytes[ 0 ], b_bytes[ 0 ]

    if a_byte_count == 0 and b_byte_count == 0 then
        return 0
    end

    if a_byte_count < b_byte_count then
        return -1
    elseif a_byte_count > b_byte_count then
        return 1
    end

    for i = a_byte_count, 1, -1 do
        if a_bytes[ i ] < b_bytes[ i ] then
            return -1
        elseif a_bytes[ i ] > b_bytes[ i ] then
            return 1
        end
    end

    return 0
end

---
--- Writes `bytes` (magnitude, `byte_count` long) into `out` as a two's-complement
--- byte string of exactly `target_len` bytes (little-endian), sign-extended.
---
---@param bytes integer[]
---@param byte_count integer
---@param is_negative boolean
---@param target_len integer
---@param out integer[]
local function twos_complement_extend( bytes, byte_count, is_negative, target_len, out )
    if is_negative then
        local carry = 1

        for i = 1, target_len do
            local summary

            if i > byte_count then
                summary = 0xFF + carry
            else
                summary = (0xFF - bytes[ i ]) + carry
            end

            if summary > 0xFF then
                out[ i ] = summary - 0x100
                carry = 1
            else
                out[ i ] = summary
                carry = 0
            end
        end

        return
    end

    byte_count = math_min( byte_count, target_len )

    for i = 1, byte_count, 1 do
        out[ i ] = bytes[ i ]
    end

    for i = byte_count + 1, target_len, 1 do
        out[ i ] = 0
    end
end

---@param bytes integer[]
---@param byte_count integer
---@return integer byte_count
local function bytes_rstrip( bytes, byte_count )
    if byte_count == 0 then
        return byte_count
    end

    ::big_integer_rstrip_loop::

    if bytes[ byte_count ] == 0 then
        bytes[ byte_count ] = nil
        byte_count = byte_count - 1

        if byte_count ~= 0 then
            goto big_integer_rstrip_loop
        end
    end

    bytes[ 0 ] = byte_count
    return byte_count
end

---
--- Converts a `target_len` byte two-complement value (in place, in `bytes`)
--- back to sign-magnitude
---
---@param bytes integer[]
---@param target_len integer
---@return integer, boolean
local function twos_complement_to_magnitude( bytes, target_len )
    local is_negative = bit_band( bytes[ target_len ], 0x80 ) ~= 0
    if is_negative then
        local carry = 1

        for i = 1, target_len, 1 do
            local summary = (0xFF - bytes[ i ]) + carry
            if summary > 0xFF then
                summary, carry = summary - 0x100, 1
            else
                carry = 0
            end

            bytes[ i ] = summary
        end
    end

    return bytes_rstrip( bytes, target_len ), is_negative
end

---@param bytes integer[]
---@param byte_count integer | nil
---@return integer | nil
local function bytes_power_of_two( bytes, byte_count )
    if byte_count == nil then
        byte_count = bytes[ 0 ]
    end

    if byte_count == 0 then
        return nil
    end

    local power = 0
    local index = 1

    -- skip zero/empty bytes
    while index <= byte_count and bytes[ index ] == 0 do
        index, power = index + 1, power + 8
    end

    -- top-byte analysis
    local value = bytes[ index ]
    local found_bit = false

    for j = 1, 8, 1 do
        if bit_band( value, 1 ) == 1 then
            if found_bit then
                return nil -- second set bit within this byte
            end

            found_bit = true
        elseif not found_bit then
            power = power + 1
        end

        value = bit_rshift( value, 1 )
    end

    -- remaining bytes must be zero/empty
    for i = index + 1, byte_count, 1 do
        if bytes[ i ] ~= 0 then
            return nil
        end
    end

    return power
end

do

    ---@type table<integer, integer[]>
    local byte_cache = {}

    setmetatable( byte_cache, {
        __index = function( self, value )
            ---@type integer[]
            local bytes = {}

            ---@type integer
            local byte_count = 0

            while value > 0 do
                byte_count = byte_count + 1
                bytes[ byte_count ] = value % 0x100
                value = math_floor( value * 0.00390625 )
            end

            bytes[ 0 ] = byte_count

            self[ value ] = bytes
            return bytes
        end,
        __mode = "v" -- not sure
    } )

    --- [SHARED AND MENU]
    ---
    --- Sets a `BigInteger` object from Lua integer.
    ---
    ---@param value integer The number to convert.
    ---@return dreamwork.std.BigInteger self
    function BigInteger:fromInteger( value )
        if value == 0 then
            self.sign = math_isNegative( value )
            self.bytes[ 0 ] = 0
        else
            if math_isNegative( value ) then
                self.sign = true
                value = -value
            else
                self.sign = false
            end

            self.bytes = bytes_copy( byte_cache[ value ] )
        end

        return self
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Sets a `BigInteger` object from a decimal string.
    ---
    ---@param str string The string representation of the big integer.
    ---@param base? integer The numerical base of the digits in the input value. Can be any integer between 2 and 36, inclusive. By default: `10`
    ---@param start_position? integer The start position to read from.
    ---@param end_position? integer The end position to read to.
    ---@return dreamwork.std.BigInteger self
    function BigInteger:fromString( str, base, start_position, end_position )
        local str_length = string_len( str )

        if start_position == nil then
            start_position = 1
        elseif start_position < 0 then
            start_position = math_relative( start_position, str_length )
        else
            start_position = math_min( start_position, str_length )
        end

        if end_position == nil then
            end_position = str_length
        elseif end_position < 0 then
            end_position = math_relative( end_position, str_length )
        else
            end_position = math_min( end_position, str_length )
        end

        if string_byte( str, start_position ) == 0x2d then -- "-"
            start_position = start_position + 1
            self.sign = true
        else
            self.sign = false
        end

        if string_byte( str, start_position ) == 0x30 --[[ 0 ]] then
            start_position = start_position + 1

            local prefix = string_byte( str, start_position )
            if (base == nil or base == 16) and prefix == 0x78 --[[ x ]] then
                start_position = start_position + 1
                base = 16
            elseif (base == nil or base == 2) and prefix == 0x62 --[[ b ]] then
                start_position = start_position + 1
                base = 2
            end
        end

        while string_byte( str, start_position ) == 0x30 --[[ 0 ]] do
            start_position = start_position + 1
        end

        if start_position > end_position then
            self.bytes[ 0 ] = 0
            self.sign = false
            return self
        end

        ---@type integer[]
        local bytes = {}

        ---@type integer
        local byte_count = 0

        base = math_clamp( base or 10, 2, 36 )
        self.bytes = bytes

        if base == 2 or base == 16 then
            -- fast bin/hex parser
            local width = base == 16 and 2 or 8

            for j = end_position, start_position, -width do
                byte_count = byte_count + 1

                local chunk_start = j - width + 1
                if chunk_start > start_position then
                    bytes[ byte_count ] = raw_tonumber( string_sub( str, chunk_start, j ), base )
                else
                    bytes[ byte_count ] = raw_tonumber( string_sub( str, start_position, j ), base )
                end
            end

            bytes[ 0 ] = byte_count

            return self
        end

        for i = start_position, end_position, 1 do
            local carry = ascii_toInteger( string_byte( str, i ) )
            if carry == nil then
                break     -- drop floats and not a number parts
            elseif carry >= base then
                carry = 0 -- rare case when we can decode integer but its to large for current base
            end

            for j = 1, byte_count, 1 do
                local value = (bytes[ j ] * base) + carry
                bytes[ j ] = value % 0x100
                carry = math_floor( value * 0.00390625 ) -- /256
            end

            while carry ~= 0 do
                byte_count = byte_count + 1
                bytes[ byte_count ] = carry % 0x100
                carry = math_floor( carry * 0.00390625 ) -- /256
            end
        end

        bytes[ 0 ] = byte_count

        return self
    end

end

do

    local BigInteger_fromInteger = BigInteger.fromInteger
    local BigInteger_fromString = BigInteger.fromString

    ---@param obj dreamwork.std.BigInteger
    ---@param value any
    ---@param base integer | nil
    ---@param stack_level integer
    local function fromAny( obj, value, base, stack_level )
        if isString( value ) then
            ---@cast value string
            BigInteger_fromString( obj, value, base )
            return
        end

        ---@type integer | nil
        local number_value

        if isNumber( value ) then
            ---@cast value number
            number_value = value
        else
            ---@cast value any
            number_value = tonumber( value, base )
            if number_value == nil then
                error( "given value cannot be converted to a number", stack_level + 1 )
            end
        end

        ---@cast number_value number

        BigInteger_fromInteger( obj, math_floor( number_value ) )
    end

    ---@param value dreamwork.std.BigInteger | string | integer | nil
    ---@param base integer | nil
    ---@protected
    function BigInteger:__init( value, base )
        if isBigInteger( value ) then
            ---@cast value dreamwork.std.BigInteger
            self.bytes = bytes_copy( value.bytes )
            self.sign = value.sign
            return
        end

        self.bytes = { [ 0 ] = 0 }
        self.sign = false

        if value ~= nil then
            ---@cast value string | integer
            fromAny( self, value, base, 3 )
        end
    end

    --- [SHARED AND MENU]
    ---
    --- Creates a `BigInteger` object from the given value.
    ---
    --- If `value` is already a `BigInteger`, it is returned unchanged.
    ---
    ---@param value any The value to convert to a `BigInteger`.
    ---@param base? integer The numeric base used when parsing string values. Must be between `2` and `36` (inclusive). Defaults to `10`.
    ---@return dreamwork.std.BigInteger obj
    function std.toBigInteger( value, base )
        if isBigInteger( value ) then
            ---@cast value dreamwork.std.BigInteger
            return value
        end

        local obj = class_new( BigInteger )
        obj.bytes = { [ 0 ] = 0 }
        obj.sign = false

        fromAny( obj, value, base, 2 )
        return obj
    end

    std.toBigInt = std.toBigInteger

end

--- [SHARED AND MENU]
---
--- Replaces the contents of this `BigInteger` with the given bytes.
---
--- The bytes are interpreted in big-endian order (most significant byte first).
--- If `signed` is `true`, the resulting value is interpreted as a signed
--- two's-complement integer.
---
---@param signed boolean Whether the byte sequence represents a signed integer.
---@param ... integer The bytes to store, each in the range `0`–`255`.
---@return dreamwork.std.BigInteger self
function BigInteger:fromBytes( signed, ... )
    local byte_count = raw_select( "#", ... )

    self.bytes = { [ 0 ] = byte_count, ... }
    self.signed = false

    if signed then
        self:toSigned( byte_count )
    end

    return self
end

--- [SHARED AND MENU]
---
--- Creates a new `BigInteger` from the given bytes.
---
--- The bytes are interpreted in big-endian order (most significant byte first).
--- If `signed` is `true`, the resulting value is interpreted as a signed
--- two's-complement integer.
---
---@param signed boolean Whether the byte sequence represents a signed integer.
---@param ... integer The bytes of the integer, each in the range `0`–`255`.
---@return dreamwork.std.BigInteger new_obj
function BigIntegerClass.fromBytes( signed, ... )
    local byte_count = raw_select( "#", ... )

    ---@type dreamwork.std.BigInteger
    local obj = setmetatable( {
        bytes = { [ 0 ] = byte_count, ... },
        signed = false
    }, BigInteger )

    if signed then
        obj:toSigned( byte_count )
    end

    return obj
end

local toBigInteger = std.toBigInteger

---@param b any
---@return boolean
---@protected
function BigInteger:__eq( b )
    return compare( self, toBigInteger( b ) ) == 0
end

---@param b any
---@return boolean
---@protected
function BigInteger:__lt( b )
    return compare( self, toBigInteger( b ) ) == -1
end

---@param b any
---@return boolean
---@protected
function BigInteger:__le( b )
    return compare( self, toBigInteger( b ) ) <= 0
end

--- [SHARED AND MENU]
---
--- Makes a copy of the `BigInteger` object.
---
---@return dreamwork.std.BigInteger new_obj
function BigInteger:copy()
    return setmetatable( {
        bytes = bytes_copy( self.bytes ),
        sign = self.sign
    }, BigInteger )
end

--- [SHARED AND MENU]
---
--- Converts a big integer object to a lua_number (always an integer).
---
---@return integer value The number that the big integer object represents.
function BigInteger:toInteger()
    local bytes = self.bytes

    ---@type integer
    local integer = 0

    for i = bytes[ 0 ], 1, -1 do
        integer = (integer * 0x100) + bytes[ i ]
    end

    if self.sign then
        return -integer
    end

    return integer
end

BigInteger.__tonumber = BigInteger.toInteger

do

    ---@type string[]
    local digits = {
        [ 0 ] = "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "a",
        "b",
        "c",
        "d",
        "e",
        "f",
        "g",
        "h",
        "i",
        "j",
        "k",
        "l",
        "m",
        "n",
        "o",
        "p",
        "q",
        "r",
        "s",
        "t",
        "u",
        "v",
        "w",
        "x",
        "y",
        "z"
    }

    --- [SHARED AND MENU]
    ---
    --- Converts the big integer to a string in the specified (or not) base.
    ---
    ---@param base? integer The numerical base of the digits in the input value. Can be any integer between 2 and 36, inclusive. By default: `10`
    ---@return string str The string representation of the big integer.
    function BigInteger:toString( base )
        if base == nil then
            base = 10
        else
            base = math_clamp( base, 2, 36 )
        end

        if base == 2 then
            return self:toBinaryString()
        elseif base == 16 then
            return self:toHexString()
        end

        local bytes = self.bytes

        ---@type integer
        local byte_count = bytes[ 0 ]
        if byte_count == 0 then
            if self.sign then
                return "-0"
            end

            return "0"
        end

        ---@type integer[]
        local buffer = {}

        ---@type integer
        local buffer_size = 0

        for i = byte_count, 1, -1 do
            -- buffer = (buffer * 0x100) + bytes[i], done in one pass
            local carry = bytes[ i ]
            for j = 1, buffer_size, 1 do
                local product = buffer[ j ] * 0x100 + carry
                buffer[ j ] = product % base
                carry = math_floor( product / base )
            end

            while carry ~= 0 do
                buffer_size = buffer_size + 1
                buffer[ buffer_size ] = carry % base
                carry = math_floor( carry / base )
            end
        end

        ---@type string[]
        local symbols = {}

        for i = 1, buffer_size, 1 do
            symbols[ i ] = digits[ buffer[ (buffer_size - i) + 1 ] ]
        end

        local str = table_concat( symbols, "", 1, buffer_size )

        if self.sign then
            return "-" .. str
        end

        return str
    end

end

--- [SHARED AND MENU]
---
--- Converts the big integer into a hex string.
---
---@return string hex_str The hex string representation of the big integer.
function BigInteger:toHexString()
    local bytes = self.bytes

    ---@type integer
    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        if self.sign then
            return "-0x0"
        end

        return "0x0"
    end

    ---@type string[]
    local result = {}

    result[ 1 ] = string_format( "%X", bytes[ byte_count ] ) -- MSB, unpadded

    for i = 2, byte_count, 1 do
        result[ i ] = string_format( "%02X", bytes[ (byte_count - i) + 1 ] )
    end

    local str = table_concat( result )

    if self.sign then
        return "-0x" .. str
    end

    return "0x" .. str
end

--- [SHARED AND MENU]
---
--- Converts the big integer to a binary [01] string.
---
---@return string str The binary string representation of the big integer.
function BigInteger:toBinaryString()
    local bytes = self.bytes

    ---@type integer
    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        if self.sign then
            return "-0b0"
        end

        return "0b0"
    end

    ---@type integer
    local bit_count = byte_count * 8

    ---@type integer[]
    local result = {}

    for i = 1, byte_count, 1 do
        local base_index = bit_count - (i - 1) * 8
        local byte_value = bytes[ i ]

        for j = 0, 7, 1 do
            result[ base_index - j ] = byte_value % 2
            byte_value = math_floor( byte_value * 0.5 )
        end
    end

    local str = table_concat( result, "", 1, bit_count )

    if self.sign then
        return "-0b" .. str
    end

    return "0b" .. str
end

do

    local BigInteger_toString = BigInteger.toString

    ---@return string
    ---@protected
    function BigInteger:__tostring()
        return BigInteger_toString( self, 10 )
    end

    ---@return string
    ---@protected
    function BigInteger:__represent()
        return string_format( "BigInteger: %p [%s]", self, self:toHexString() )
    end

    ---@param b any
    ---@return string
    ---@protected
    function BigInteger:__concat( b )
        return BigInteger_toString( self, 10 ) .. tostring( b )
    end

end

---@param writer dreamwork.std.BinaryWriter
function BigInteger:__serialize( writer )
    local bytes = self.bytes
    local byte_count = bytes[ 0 ]
    writer:writeBoolean( self.sign )
    writer:writeCountedString( string.char( table_unpack( self.bytes, 1, byte_count ) ), 48 )
end

---@param reader dreamwork.std.BinaryReader
function BigInteger:__deserialize( reader )
    self.sign = reader:readBoolean()
    local bytes, byte_count = reader:readCountedString( 48 )
    self.bytes = { [ 0 ] = byte_count, string_byte( bytes, 1, byte_count ) }
end

local BigInteger_negate = BigInteger.negate
local BigInteger_copy = BigInteger.copy

---@return dreamwork.std.BigInteger new_obj The new negated big integer object.
---@protected
function BigInteger:__unm()
    return BigInteger_negate( BigInteger_copy( self ) )
end

--- [SHARED AND MENU]
---
--- Makes a big integer object absolute (simply removes the sign).
---
---@return dreamwork.std.BigInteger self The absolute big integer object.
function BigInteger:abs()
    self.sign = false
    return self
end

--- [SHARED AND MENU]
---
--- Summarizes the current `BigInteger` with the specified value.
---
---@param value any The second value to be converted into `BigInteger`.
---@return dreamwork.std.BigInteger object The result of the operation.
function BigInteger:add( value )
    local b = toBigInteger( value )

    -- b is empty/zero
    local b_bytes = b.bytes

    local b_byte_count = b_bytes[ 0 ]
    if b_byte_count == 0 then
        return self
    end

    -- a is empty/zero
    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        self.bytes = bytes_copy( b_bytes, b_byte_count )
        self.sign = b.sign
        return self
    end

    -- determine sign, operation, and order of operands
    local subtract, swap_order, change_sign = false, false, false

    if self.sign == b.sign then
        if byte_count < b_byte_count then
            swap_order = true
        end
    else

        local compare_result = bytes_unsigned_compare( bytes, byte_count, b_bytes, b_byte_count )
        if compare_result == 0 then
            self.sign = false
            return self
        end

        if compare_result == -1 then
            swap_order, change_sign = true, true
        end

        subtract = true

    end

    local bytes1, bytes1_count
    local bytes2, bytes2_count

    if swap_order then
        bytes1, bytes1_count = b_bytes, b_byte_count
        bytes2, bytes2_count = bytes, byte_count
    else
        bytes1, bytes1_count = bytes, byte_count
        bytes2, bytes2_count = b_bytes, b_byte_count
    end

    ---@type integer
    local carry = 0

    if subtract then
        -- 1. Subtraction Phase (Up to the size of the smaller magnitude)
        for i = 1, bytes2_count, 1 do
            local total = (bytes1[ i ] - bytes2[ i ]) + carry
            if total < 0 then
                bytes[ i ], carry = total + 0x100, -1
            else
                bytes[ i ], carry = total, 0
            end
        end

        -- 2. Subtraction Phase (Propagate carry into the remaining larger magnitude)
        for i = bytes2_count + 1, bytes1_count, 1 do
            if carry == 0 then
                -- No carry left, safely break and copy remainder if needed
                if swap_order then
                    for j = i, bytes1_count do
                        bytes[ j ] = bytes1[ j ]
                    end
                end

                break
            end

            local total = bytes1[ i ] + carry
            if total < 0 then
                bytes[ i ], carry = total + 0x100, -1
            else
                bytes[ i ], carry = total, 0
            end
        end

        if bytes_rstrip( bytes, bytes1_count ) == 0 then
            self.sign = false
            return self
        end
    else
        -- 1. Addition Phase (Up to the size of the smaller number)
        for i = 1, bytes2_count do
            local total = (bytes1[ i ] + bytes2[ i ]) + carry
            if total >= 0x100 then
                bytes[ i ], carry = total - 0x100, 1
            else
                bytes[ i ], carry = total, 0
            end
        end

        -- 2. Addition Phase (Propagate carry into the remainder of the larger number)
        for i = bytes2_count + 1, bytes1_count do
            if carry == 0 then
                -- No carry left, safely break and copy remainder if needed
                if swap_order then
                    for j = i, bytes1_count do
                        bytes[ j ] = bytes1[ j ]
                    end
                end

                break
            end

            local total = bytes1[ i ] + carry
            if total >= 0x100 then
                bytes[ i ], carry = total - 0x100, 1
            else
                bytes[ i ], carry = total, 0
            end
        end

        -- Handle final overflow carry at the highest end
        if carry > 0 then
            bytes1_count = bytes1_count + 1
            bytes[ bytes1_count ] = carry
        end

        -- Crucial: Save the new total length!
        bytes[ 0 ] = bytes1_count
    end

    -- Apply inverted sign if self < b during subtraction
    if change_sign then
        BigInteger_negate( self )
    end

    return self
end

local BigInteger_add = BigInteger.add

---@param b any
---@return dreamwork.std.BigInteger new_object
---@protected
function BigInteger:__add( b )
    return BigInteger_add( BigInteger_copy( self ), toBigInteger( b ) )
end

--- [SHARED AND MENU]
---
--- Subtract the current `BigInteger` by the specified value.
---
---@param value any The second value to be converted into `BigInteger`.
---@return dreamwork.std.BigInteger object The result of the operation.
function BigInteger:sub( value )
    return BigInteger_add( self, BigInteger_negate( toBigInteger( value ) ) )
end

---@param b any
---@return dreamwork.std.BigInteger new_object
---@protected
function BigInteger:__sub( b )
    return BigInteger_add( BigInteger_copy( self ), BigInteger_negate( BigIntegerClass( b ) ) )
end

--- [SHARED AND MENU]
---
--- Multiplies the current `BigInteger` by the specified value.
---
---@param value any The second value to be converted into `BigInteger`.
---@return dreamwork.std.BigInteger object The result of the operation.
function BigInteger:mul( value )
    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        return self -- self is zero
    end

    local b = toBigInteger( value )

    local b_bytes = b.bytes

    local b_byte_count = b_bytes[ 0 ]

    if b_byte_count == 0 then
        bytes[ 0 ] = 0
        self.sign = false
        return self -- b is zero
    end

    if b_byte_count == 1 and b_bytes[ 1 ] == 1 then
        if b.sign then
            self:negate()
        end

        return self -- b is +-1
    end

    if byte_count == 1 and bytes[ 1 ] == 1 then
        self.bytes = bytes_copy( b_bytes, b_byte_count )

        local is_negative = self.sign
        self.sign = b.sign

        if is_negative then
            self:negate()
        end

        return self -- self is +-1
    end

    -- capture the correct sign BEFORE any mutation
    local is_negative = self.sign ~= b.sign

    -- general multiplication: outer loop over the shorter operand,
    -- inner loop over the longer one
    local object1, object1_size
    local object2, object2_size
    if b_byte_count > byte_count then
        object1, object1_size = b_bytes, b_byte_count
        object2, object2_size = bytes, byte_count
    else
        object1, object1_size = bytes, byte_count
        object2, object2_size = b_bytes, b_byte_count
    end

    ---@type integer[]
    local result = {}

    -- self.bytes is only overwritten here, AFTER all reads from
    -- object1 / object2 ( which may alias `bytes`, e.g. self:mul( self ) )
    -- are already complete, so this is safe even for squaring
    ---@type integer
    local max_len = object1_size + object2_size

    for i = 1, object2_size, 1 do
        local digit = object2[ i ]
        if digit ~= 0 then
            local carry = 0
            local j = 1

            while j <= object1_size do
                local ri = i + j - 1
                local product = object1[ j ] * digit + carry + (result[ ri ] or 0)
                result[ ri ] = product % 0x100
                carry = math_floor( product * 0.00390625 )
                j = j + 1
            end

            while carry ~= 0 do
                local ri = i + j - 1
                local sum = (result[ ri ] or 0) + carry
                result[ ri ] = sum % 0x100
                carry = math_floor( sum * 0.00390625 )
                j = j + 1
            end
        end
    end

    for i = 1, max_len, 1 do
        bytes[ i ] = result[ i ] or 0
    end

    self.sign = bytes_rstrip( bytes, max_len ) ~= 0 and is_negative

    return self
end

local BigInteger_mul = BigInteger.mul

---@param value any
---@return dreamwork.std.BigInteger new_object
---@protected
function BigInteger:__mul( value )
    return BigInteger_mul( BigInteger_copy( self ), value )
end

--- [SHARED AND MENU]
---
--- Shifts a big integer object to the left by a given number of bits (positive or negative).
---
---@param shift integer The number of bits to shift by.
---@return dreamwork.std.BigInteger object The shifted big integer object.
function BigInteger:lshift( shift )
    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 or shift == 0 then
        return self
    end

    if shift < 0 then
        return self:rshift( -shift )
    end

    -- shift whole bytes
    local shift_bytes = math_floor( shift * 0.125 )
    local shift_bits = shift % 8

    -- shift whole bytes up, fill vacated low bytes with 0
    for i = byte_count, 1, -1 do
        bytes[ i + shift_bytes ] = bytes[ i ]
    end

    for i = 1, shift_bytes do
        bytes[ i ] = 0
    end

    byte_count = byte_count + shift_bytes

    -- shift remaining bits, carrying overflow upward
    if shift_bits ~= 0 then
        local shift_size = 2 ^ shift_bits
        local overflow = 0

        for i = shift_bytes + 1, byte_count do
            local value = (bytes[ i ] * shift_size) + overflow
            bytes[ i ] = value % 0x100
            overflow = math_floor( value * 0.00390625 ) -- /256
        end

        if overflow ~= 0 then
            byte_count = byte_count + 1
            bytes[ byte_count ] = overflow
        end
    end

    bytes[ 0 ] = byte_count

    return self
end

--- [SHARED AND MENU]
---
--- Checks if `BigInteger` is a power of two.
---
---@return boolean is_pot `true` if a number is a valid power-of-two, otherwise `false`.
function BigInteger:isPowerOfTwo()
    return bytes_power_of_two( self.bytes ) ~= nil
end

do

    local BigInteger_lshift = BigInteger.lshift

    ---@param shift integer
    ---@return dreamwork.std.BigInteger new_object
    ---@protected
    function BigInteger:__shl( shift )
        return BigInteger_lshift( BigInteger_copy( self ), shift )
    end

    --- [SHARED AND MENU]
    ---
    --- Raises a big integer object to a power.
    ---
    ---@param value integer The value to raise to.
    ---@return dreamwork.std.BigInteger self The result of the operation.
    function BigInteger:pow( value )
        if value == 0 then
            self.bytes = { [ 0 ] = 1, 1 }
            return self
        elseif value == 1 then
            return self
        end

        local bytes = self.bytes

        local byte_count = bytes[ 0 ]
        if byte_count == 0 then
            return self
        end

        if value < 0 then
            error( "negative exponent is not supported", 2 )
        end

        if self.sign and (value % 2) == 0 then
            self.sign = false
        end

        -- fast path: self's magnitude is an exact power of two
        local power = bytes_power_of_two( bytes, byte_count )
        if power ~= nil then
            BigInteger_lshift( self, power * (value - 1) )
            self.sign = self.sign and (value % 2) == 1
            return self
        end

        -- general case: exponentiation by squaring
        local base = BigInteger_copy( self )
        local result = toBigInteger( 1 )

        while value ~= 0 do
            if (value % 2) == 1 then
                BigInteger_mul( result, base )
            end

            value = math_floor( value * 0.5 )

            if value ~= 0 then
                BigInteger_mul( base, base )
            end
        end

        self.bytes = result.bytes
        self.sign = result.sign
        return self
    end

end

do

    local BigInteger_pow = BigInteger.pow

    ---@param value integer
    ---@return dreamwork.std.BigInteger new_object
    ---@protected
    function BigInteger:__pow( value )
        return BigInteger_pow( BigInteger_copy( self ), value )
    end

end

do

    ---
    ---  multiplies a byte array in place by a small scalar (0-255); returns new length
    ---
    ---@param bytes integer[]
    ---@param byte_count integer
    ---@param factor integer
    ---@return integer byte_count
    local function bytes_mul_small( bytes, byte_count, factor )
        local carry = 0

        for i = 1, byte_count, 1 do
            local product = bytes[ i ] * factor + carry
            bytes[ i ] = product % 0x100
            carry = math_floor( product * 0.00390625 )
        end

        if carry ~= 0 then
            byte_count = byte_count + 1
            bytes[ byte_count ] = carry
        end

        return byte_count
    end

    ---
    ---  divides a byte array in place by a small scalar (1-255), MSB to LSB; returns new length
    ---
    ---@param bytes integer[]
    ---@param byte_count integer
    ---@param divisor integer
    ---@return integer byte_count
    local function bytes_div_small( bytes, byte_count, divisor )
        local remainder = 0

        for i = byte_count, 1, -1 do
            local cur = (remainder * 0x100) + bytes[ i ]
            bytes[ i ] = math_floor( cur / divisor )
            remainder = cur % divisor
        end

        return bytes_rstrip( bytes, byte_count )
    end

    --- [SHARED AND MENU]
    ---
    --- Divides the current `BigInteger` with the specified value.
    ---
    ---@param value any The second value to divide by (will be converted into `BigInteger`).
    ---@return dreamwork.std.BigInteger quotient The quotient.
    ---@return dreamwork.std.BigInteger remainder The remainder.
    function BigInteger:div( value )
        local bytes = self.bytes
        local byte_count = bytes[ 0 ]

        local b = toBigInteger( value )

        local b_bytes = b.bytes
        local b_byte_count = b_bytes[ 0 ]

        if b_byte_count == 0 then
            error( "attempt to divide by zero", 2 )
        end

        if byte_count == 0 then
            bytes[ 0 ] = 0
            self.sign = false

            return self,
                setmetatable( { -- 0
                    bytes = { [ 0 ] = 0 },
                    sign = false
                }, BigInteger )
        end

        local is_negative = self.sign ~= b.sign

        if b_byte_count == 1 and b_bytes[ 1 ] == 1 then
            self.sign = byte_count ~= 0 and is_negative

            return self,
                setmetatable( { -- 0
                    bytes = { [ 0 ] = 0 },
                    sign = false
                }, BigInteger )
        end

        local compare_result = bytes_unsigned_compare( bytes, byte_count, b_bytes, b_byte_count )

        if compare_result == -1 then
            local remainder = BigInteger_copy( self )

            bytes[ 0 ] = 0
            self.sign = false

            return self, remainder
        end

        if compare_result == 0 then
            bytes[ 0 ], bytes[ 1 ] = 1, 1
            self.sign = is_negative

            return self,
                setmetatable( { -- 0
                    bytes = { [ 0 ] = 0 },
                    sign = false
                }, BigInteger )
        end

        -- normalize: scale both operands so the divisor's top byte >= 0x80
        local divisor_bytes = bytes_copy( b_bytes, b_byte_count )
        local remainder_bytes = bytes_copy( bytes, byte_count )
        local remainder_len = byte_count

        local d = math_floor( 0x100 / (divisor_bytes[ b_byte_count ] + 1) )
        if d > 1 then
            b_byte_count = bytes_mul_small( divisor_bytes, b_byte_count, d )
            remainder_len = bytes_mul_small( remainder_bytes, byte_count, d )
        end

        local divisor_top = divisor_bytes[ b_byte_count ]

        local digit_count = byte_count - (b_bytes[ 0 ]) + 1 -- based on ORIGINAL divisor length
        bytes[ 0 ] = digit_count

        for di = digit_count, 1, -1 do
            local factor = math_min( 0xFF, math_floor(
                (
                    (remainder_bytes[ di + b_byte_count ] or 0) * 0x100 +
                    (remainder_bytes[ di + b_byte_count - 1 ] or 0)
                ) / divisor_top
            ) )

            while factor > 0 do
                local carry, borrow = 0, 0
                local temp = {}

                for i = 1, b_byte_count + 1, 1 do
                    local sub = (divisor_bytes[ i ] or 0) * factor + carry
                    carry = math_floor( sub * 0.00390625 )
                    sub = sub % 0x100

                    local diff = (remainder_bytes[ di + i - 1 ] or 0) - sub - borrow
                    if diff < 0 then
                        diff = diff + 0x100
                        borrow = 1
                    else
                        borrow = 0
                    end

                    temp[ i ] = diff
                end

                if borrow == 0 then
                    for i = 1, b_byte_count + 1, 1 do
                        remainder_bytes[ di + i - 1 ] = temp[ i ]
                    end

                    break
                end

                factor = factor - 1
            end

            bytes[ di ] = factor
        end

        -- undo normalization on the remainder
        if d > 1 then
            remainder_len = bytes_div_small( remainder_bytes, remainder_len, d )
        else
            remainder_len = bytes_rstrip( remainder_bytes, remainder_len )
        end

        self.sign = bytes_rstrip( bytes, digit_count ) ~= 0 and is_negative

        return self,
            setmetatable( {
                bytes = remainder_bytes,
                sign = remainder_len ~= 0 and self.sign
            }, BigInteger )
    end

    local BigInteger_div = BigInteger.div

    ---@param value any
    ---@return dreamwork.std.BigInteger quotient
    ---@protected
    function BigInteger:__div( value )
        return (BigInteger_div( BigInteger_copy( self ), value ))
    end

    BigInteger.__idiv = BigInteger.__div

    --- [SHARED AND MENU]
    ---
    --- Calculates modulus (remainder after division);
    ---
    --- Handles Lua-to-BigInteger conversions and non-positive cases correctly.
    ---
    ---@param value any The value to divide by.
    ---@return dreamwork.std.BigInteger remainder The remainder (same sign as self, or zero).
    function BigInteger:mod( value )
        return raw_select( 2, BigInteger_div( BigIntegerClass( self ), value ) )
    end

    ---@param value any
    ---@return dreamwork.std.BigInteger remainder
    ---@protected
    function BigInteger:__mod( value )
        return raw_select( 2, BigInteger_div( self, value ) )
    end

end

--- [SHARED AND MENU]
---
--- Returns the log2 of a big integer object.
---
---@return number result The base-2 logarithm of the big integer object. NaN for negative values, -inf for zero.
function BigInteger:log2()
    if self.sign then
        return math.nan
    end

    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        return math.tiny
    end

    local take = math_min( 6, byte_count )

    local value = 0
    for i = byte_count, byte_count - take + 1, -1 do
        value = (value * 0x100) + bytes[ i ]
    end

    local mantissa, exponent = math_frexp( value )
    return math_log2( mantissa ) + exponent + (byte_count - take) * 8
end

--- [SHARED AND MENU]
---
--- Shifts a big integer object to the right by a given number of bits (positive or negative).
---
---@param shift integer The number of bits to shift by.
---@return dreamwork.std.BigInteger object The shifted big integer object.
function BigInteger:rshift( shift )
    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 or shift == 0 then
        return self
    end

    if shift < 0 then
        return self:lshift( -shift )
    end

    -- shift whole bytes
    local shift_bytes = math_floor( shift * 0.125 )
    if shift_bytes >= byte_count then
        self.bytes = { [ 0 ] = 0 }
        self.sign = false
        return self
    end

    -- shift whole bytes down
    for i = shift_bytes + 1, byte_count, 1 do
        bytes[ i - shift_bytes ] = bytes[ i ]
    end

    for i = byte_count - shift_bytes + 1, byte_count, 1 do
        bytes[ i ] = nil
    end

    byte_count = byte_count - shift_bytes

    -- shift remaining bits, carrying overflow downward
    local shift_bits = shift % 8

    if shift_bits ~= 0 then
        local shift_size, unshift_size = 2 ^ shift_bits, 2 ^ (8 - shift_bits)
        for i = 1, byte_count do
            local overflow = bytes[ i ] % shift_size
            bytes[ i ] = math_floor( bytes[ i ] / shift_size )

            if i ~= 1 then
                bytes[ i - 1 ] = bytes[ i - 1 ] + overflow * unshift_size
            end
        end
    end

    -- strip any leading zero bytes (there can be more than one)
    while byte_count ~= 0 and bytes[ byte_count ] == 0 do
        bytes[ byte_count ] = nil
        byte_count = byte_count - 1
    end

    bytes[ 0 ] = byte_count
    return self
end

do

    local BigInteger_rshift = BigInteger.rshift

    ---@param shift integer
    ---@return dreamwork.std.BigInteger new_object
    ---@protected
    function BigInteger:__shr( shift )
        return BigInteger_rshift( BigInteger_copy( self ), shift )
    end

end

---@type integer[]
local a_buffer = {}

---@type integer[]
local b_buffer = {}

--- [SHARED AND MENU]
---
--- Performs a bitwise OR operation between two big integer objects.
---
---@param value any The value to perform the operation on.
---@return dreamwork.std.BigInteger object The result of the operation.
function BigInteger:bor( value )
    local b = toBigInteger( value )

    local b_bytes = b.bytes

    local b_byte_count = b_bytes[ 0 ]
    if b_byte_count == 0 then
        return self
    end

    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        self.bytes = bytes_copy( b_bytes, b_byte_count )
        self.sign = b.sign
        return self
    end

    local target_len = math_max( byte_count, b_byte_count ) + 1

    twos_complement_extend( bytes, byte_count, self.sign, target_len, a_buffer )
    twos_complement_extend( b_bytes, b_byte_count, b.sign, target_len, b_buffer )

    for i = 1, target_len, 1 do
        bytes[ i ] = bit_bor( a_buffer[ i ], b_buffer[ i ] )
    end

    local result_len, is_negative = twos_complement_to_magnitude( bytes, target_len )
    self.sign = result_len ~= 0 and is_negative

    return self
end

do

    local BigInteger_bor = BigInteger.bor

    ---@param ... any
    ---@return dreamwork.std.BigInteger new_object
    ---@protected
    function BigInteger:__bor( ... )
        local object = BigInteger_copy( self )

        for i = 1, raw_select( "#", ... ), 1 do
            BigInteger_bor( object, (raw_select( i, ... )) )
        end

        return object
    end

end

--- [SHARED AND MENU]
---
--- Performs a bitwise AND operation between two big integer objects.
---
---@param value any The value to perform the operation on.
---@return dreamwork.std.BigInteger new_object The result of the operation.
function BigInteger:band( value )
    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        return self
    end

    local b = toBigInteger( value )
    local b_bytes = b.bytes

    local b_byte_count = b_bytes[ 0 ]
    if b_byte_count == 0 then
        self.bytes = { [ 0 ] = 0 }
        self.sign = false
        return self
    end

    ---@type integer
    local target_len = math_max( byte_count, b_byte_count ) + 1

    twos_complement_extend( bytes, byte_count, self.sign, target_len, a_buffer )
    twos_complement_extend( b_bytes, b_byte_count, b.sign, target_len, b_buffer )

    for i = 1, target_len, 1 do
        bytes[ i ] = bit_band( a_buffer[ i ], b_buffer[ i ] )
    end

    local result_len, is_negative = twos_complement_to_magnitude( bytes, target_len )
    self.sign = result_len ~= 0 and is_negative

    return self
end

do

    local BigInteger_band = BigInteger.band

    ---@param ... any
    ---@return dreamwork.std.BigInteger new_object
    ---@protected
    function BigInteger:__band( ... )
        local object = BigInteger_copy( self )

        for i = 1, raw_select( "#", ... ), 1 do
            BigInteger_band( object, (raw_select( i, ... )) )
        end

        return object
    end

end

do

    --- [SHARED AND MENU]
    ---
    --- Performs a bitwise NOT operation on a big integer object.
    ---
    ---@return dreamwork.std.BigInteger object The result of the operation.
    function BigInteger:bnot()
        local bytes = self.bytes

        local byte_count = bytes[ 0 ]
        if byte_count == 0 then
            self.bytes = { [ 0 ] = 1, 1 }
            self.sign = true
            return self
        end

        local target_len = byte_count + 1 -- extra pad byte to capture the sign flip correctly
        twos_complement_extend( bytes, byte_count, self.sign, target_len, a_buffer )

        for i = 1, target_len, 1 do
            bytes[ i ] = 0xFF - a_buffer[ i ]
        end

        local result_len, is_negative = twos_complement_to_magnitude( bytes, target_len )
        self.sign = result_len ~= 0 and is_negative

        return self
    end

    local BigInteger_bnot = BigInteger.bnot

    ---@return dreamwork.std.BigInteger
    ---@protected
    function BigInteger:__bnot()
        return BigInteger_bnot( BigInteger_copy( self ) )
    end

    --- [SHARED AND MENU]
    ---
    --- Converts unsigned `BigInteger` to signed one.
    ---
    ---@param byte_width integer The byte width to interpret the raw magnitude at (e.g. 1 for int8, 4 for int32).
    ---@return dreamwork.std.BigInteger object Self, reinterpreted as a signed integer of the given byte width.
    function BigInteger:toSigned( byte_width )
        local bytes = self.bytes

        local byte_count = bytes[ 0 ]
        if byte_count == 0 then
            return self
        end

        local top_byte
        if byte_width > byte_count then
            top_byte = 0
        else
            top_byte = bytes[ byte_width ]
        end

        if top_byte <= 0x7F then
            -- non-negative at this width; just truncate if the raw value is wider than byte_width
            if byte_count > byte_width and bytes_rstrip( bytes, byte_width ) == 0 then
                self.sign = false
            end

            return self
        end

        -- top bit set at byte_width: negative. Raw flip+increment over exactly byte_width bytes.
        for i = byte_count + 1, byte_width do
            bytes[ i ] = 0
        end

        for i = 1, byte_width do
            bytes[ i ] = 0xFF - bytes[ i ]
        end

        local carry = 1
        for i = 1, byte_width do
            local total = bytes[ i ] + carry
            if total < 0x100 then
                bytes[ i ], carry = total, 0
            else
                bytes[ i ], carry = total - 0x100, 1
                break
            end
        end

        self.sign = bytes_rstrip( bytes, byte_width ) ~= 0
        self.bytes = bytes

        return self
    end

    --- [SHARED AND MENU]
    ---
    --- Converts signed `BigInteger` to unsigned one.
    ---
    ---@param byte_width integer The byte width to encode as (e.g. 1 for uint8, 4 for uint32).
    ---@return dreamwork.std.BigInteger self
    function BigInteger:toUnsigned( byte_width )
        local bytes = self.bytes

        local byte_count = bytes[ 0 ]
        if byte_count == 0 then
            return self
        end

        if not self.sign and byte_count <= byte_width then
            return self
        end

        twos_complement_extend( bytes, byte_count, self.sign, byte_width, bytes )
        bytes_rstrip( bytes, byte_width )
        self.sign = false

        return self
    end

end

--- [SHARED AND MENU]
---
--- Performs a bitwise XOR operation between two big integer objects.
---
---@param value any The value to perform the operation on.
---@return dreamwork.std.BigInteger object The result of the operation.
function BigInteger:bxor( value )
    local b = toBigInteger( value )

    local b_bytes = b.bytes

    local b_byte_count = b_bytes[ 0 ]
    if b_byte_count == 0 then
        return self
    end

    local bytes = self.bytes

    local byte_count = bytes[ 0 ]
    if byte_count == 0 then
        self.bytes = bytes_copy( b_bytes, b_byte_count )
        self.sign = b.sign
        return self
    end

    local target_len = math_max( byte_count, b_byte_count ) + 1

    twos_complement_extend( bytes, byte_count, self.sign, target_len, a_buffer )
    twos_complement_extend( b_bytes, b_byte_count, b.sign, target_len, b_buffer )

    for i = 1, target_len do
        bytes[ i ] = bit_bxor( a_buffer[ i ], b_buffer[ i ] )
    end

    local result_len, is_negative = twos_complement_to_magnitude( bytes, target_len )
    self.sign = result_len ~= 0 and is_negative
    bytes[ 0 ] = result_len

    return self
end

do

    local BigInteger_bxor = BigInteger.bxor

    ---@param b any
    ---@return dreamwork.std.BigInteger
    ---@protected
    function BigInteger:__bxor( b )
        return BigInteger_bxor( BigIntegerClass( self ), b )
    end

end

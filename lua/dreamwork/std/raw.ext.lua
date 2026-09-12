local std = dreamwork.std

---@class dreamwork.std.raw
local raw = std.raw
local raw_select = raw.select

local math = std.math
local math_floor = math.floor

local string = std.string
local string_format = string.format

local pcall = std.pcall
local error = std.error
local loadstring = std.loadstring

--- [SHARED AND MENU]
---
--- Native **32-bit integer only** bit library.
---
---@class dreamwork.std.raw.bit
local rbit = raw.bit or {}
raw.bit = rbit

if std.LUA_VERSION == 5.3 then

    local fn, error_msg = loadstring( [[
        local raw = std.raw
        local rbit = raw.bit
        local raw_select = raw.select

        function rbit.bor( x, ... )
            for i = 1, raw_select( "#", ... ), 1 do
                x = x | raw_select( i, ... )
            end

            return x
        end

        function rbit.bxor( x, ... )
            for i = 1, raw_select( "#", ... ), 1 do
                x = x ~ raw_select( i, ... )
            end

            return x
        end

        function rbit.band( x, ... )
            for i = 1, raw_select( "#", ... ), 1 do
                x = x & raw_select( i, ... )
            end

            return x
        end

        function rbit.bnot( x )
            return ~x
        end

        function rbit.lshift( x, n )
            return x << n
        end

        function rbit.rshift( x, n )
            return x >> n
        end
    ]], "dreamwork.std.raw.bit", std )

    if fn == nil then
        error( "bitwise operators compile failed, " .. error_msg )
    else
        local status, result = pcall( fn )
        if not status then
            error( "bitwise operators compile failed, " .. result )
        end
    end

else

    ---@class dreamwork.GModBitLib : bitlib
    ---@field bshift fun( x: integer, disp: integer ): integer
    ---@field brotate fun( x: integer, disp: integer ): integer
    ---@field btest fun( ...: integer ): boolean
    ---@field extract fun( x: integer, field: integer, width: integer ): integer
    ---@field replace fun( x: integer, extract: integer, field: integer, width: integer ): integer
    ---@diagnostic disable-next-line: undefined-global
    local glua_bit = bit or bit32

    rbit.bor = glua_bit.bor
    rbit.bxor = glua_bit.bxor

    rbit.band = glua_bit.band
    rbit.bnot = glua_bit.bnot

    rbit.lshift = glua_bit.lshift
    rbit.rshift = glua_bit.rshift

    rbit.lrotate = glua_bit.rol
    rbit.rrotate = glua_bit.ror

    rbit.bshift = glua_bit.bshift
    rbit.brotate = glua_bit.brotate

    rbit.arshift = glua_bit.arshift

    rbit.btest = glua_bit.btest
    rbit.extract = glua_bit.extract
    rbit.replace = glua_bit.replace

    rbit.bswap = glua_bit.bswap

    rbit.tobit = glua_bit.tobit
    rbit.tohex = glua_bit.tohex

end

if rbit.tobit == nil then

    --- [SHARED AND MENU]
    ---
    --- Normalizes the specified value and clamps it in the range of a signed 32bit integer.
    ---
    ---@param x integer The value to be normalized.
    ---@return integer result The normalized value.
    function rbit.tobit( x )
        x = x % 0x100000000
        return (x < 0x80000000) and x or (x - 0x100000000)
    end

end

local rbit_tobit = rbit.tobit

if rbit.tohex == nil then

    --- [SHARED AND MENU]
    ---
    --- Returns the hexadecimal representation of the number with the specified digits.
    ---
    ---@param x integer The value to be converted.
    ---@param length integer? The number of digits. Defaults to 8.
    ---@return string str The hexadecimal representation.
    function rbit.tohex( x, length )
        return string_format( "%0" .. (length or 8) .. "x", x )
    end

end

if rbit.band == nil then

    --- [SHARED AND MENU]
    ---
    --- Performs a bitwise AND operation on all the specified 32bit integers.
    ---
    ---@param x integer The first value.
    ---@param ... integer Additional values to AND together with the first.
    ---@return integer result The bitwise AND of all given values, normalized to a signed 32bit integer.
    function rbit.band( x, ... )
        ---@type boolean[]
        local bits = {}

        ---@type integer
        local result = 0xFFFFFFFF

        for i = 1, raw_select( "#", x, ... ), 1 do
            local value = raw_select( i, x, ... )
            for j = 1, 32, 1 do
                if value % 2 == 0 and bits[ j ] == nil then
                    bits[ j ] = true
                    result = result - (2 ^ (j - 1))
                end

                value = math_floor( value * 0.5 )
            end
        end

        return rbit_tobit( result )
    end

end

local rbit_band = rbit.band

if rbit.bor == nil then

    --- [SHARED AND MENU]
    ---
    --- Performs a bitwise OR operation on all the specified 32bit integers.
    ---
    ---@param x integer The first value.
    ---@param ... integer Additional values to OR together with the first.
    ---@return integer result The bitwise OR of all given values, normalized to a signed 32bit integer.
    function rbit.bor( x, ... )
        ---@type boolean[]
        local bits = {}

        ---@type integer
        local result = 0

        for i = 1, raw_select( "#", x, ... ), 1 do
            local value = raw_select( i, x, ... )
            for j = 1, 32, 1 do
                if value % 2 ~= 0 and bits[ j ] == nil then
                    bits[ j ] = true
                    result = result + 2 ^ (j - 1)
                end

                value = math_floor( value * 0.5 )
            end
        end

        return rbit_tobit( result )
    end

end

local rbit_bor = rbit.bor

if rbit.bxor == nil then

    --- [SHARED AND MENU]
    ---
    --- Performs a bitwise XOR (exclusive OR) operation on all the specified 32bit integers.
    ---
    ---@param x integer The first value.
    ---@param ... integer Additional values to XOR together with the first.
    ---@return integer result The bitwise XOR of all given values, normalized to a signed 32bit integer.
    function rbit.bxor( x, ... )
        ---@type boolean[]
        local bits = {}

        for i = 1, raw_select( "#", x, ... ), 1 do
            local value = raw_select( i, x, ... )
            for _ = 1, 32, 1 do
                if value % 2 ~= 0 then
                    bits[ i ] = not bits[ i ]
                end

                value = math_floor( value * 0.5 )
            end
        end

        ---@type integer
        local result = 0

        for i = 1, 32, 1 do
            if bits[ i ] then
                result = result + (2 ^ (i - 1))
            end
        end

        return rbit_tobit( result )
    end

end

if rbit.bnot == nil then

    --- [SHARED AND MENU]
    ---
    --- Performs a bitwise NOT (one's complement) operation on the specified 32bit integer.
    ---
    ---@param x integer The value to be inverted.
    ---@return integer result The bitwise complement of the given value, normalized to a signed 32bit integer.
    function rbit.bnot( x )
        ---@type integer
        local result = 0

        for i = 0, 31, 1 do
            if (x % 2) == 0 then
                result = result + (2 ^ i)
            end

            x = math_floor( x * 0.5 )
        end

        return rbit_tobit( result )
    end

end

local rbit_bnot = rbit.bnot

if rbit.lshift == nil then

    local rbit_bshift = rbit.bshift
    if rbit_bshift == nil then

        --- [SHARED AND MENU]
        ---
        --- Performs a logical left shift of the specified 32bit integer by the given number of bits.
        --- Bits shifted out of the top are discarded and zero bits are shifted in from the bottom.
        ---
        ---@param x integer The value to be shifted.
        ---@param disp integer The number of bits to shift left by.
        ---@return integer result The shifted value, normalized to a signed 32bit integer.
        function rbit.lshift( x, disp )
            return rbit_tobit( x * (2 ^ disp) )
        end

    else

        --- [SHARED AND MENU]
        ---
        --- Performs a logical left shift of the specified 32bit integer by the given number of bits.
        --- Bits shifted out of the top are discarded and zero bits are shifted in from the bottom.
        ---
        ---@param x integer The value to be shifted.
        ---@param disp integer The number of bits to shift left by.
        ---@return integer result The shifted value, normalized to a signed 32bit integer.
        function rbit.lshift( x, disp )
            return rbit_bshift( x, disp )
        end

    end

end

local rbit_lshift = rbit.lshift

if rbit.rshift == nil then

    local rbit_bshift = rbit.bshift
    if rbit_bshift == nil then

        --- [SHARED AND MENU]
        ---
        --- Performs a logical right shift of the specified 32bit integer by the given number of bits.
        --- Bits shifted out of the bottom are discarded and zero bits are shifted in from the top,
        --- regardless of the sign of the value.
        ---
        ---@param x integer The value to be shifted.
        ---@param disp integer The number of bits to shift right by.
        ---@return integer result The shifted value, normalized to a signed 32bit integer.
        function rbit.rshift( x, disp )
            return rbit_tobit( math_floor( x / (2 ^ disp) ) )
        end

    else

        --- [SHARED AND MENU]
        ---
        --- Performs a logical right shift of the specified 32bit integer by the given number of bits.
        --- Bits shifted out of the bottom are discarded and zero bits are shifted in from the top,
        --- regardless of the sign of the value.
        ---
        ---@param x integer The value to be shifted.
        ---@param disp integer The number of bits to shift right by.
        ---@return integer result The shifted value, normalized to a signed 32bit integer.
        function rbit.rshift( x, disp )
            return rbit_bshift( x, -disp )
        end

    end

end

local rbit_rshift = rbit.rshift

if rbit.bshift == nil then

    --- [SHARED AND MENU]
    ---
    --- Performs a logical bit shift of the specified 32bit integer.
    --- A positive displacement shifts left, a negative displacement shifts right.
    ---
    ---@param x integer The value to be shifted.
    ---@param disp integer The number of bits to shift by. Positive shifts left, negative shifts right.
    ---@return integer result The shifted value, normalized to a signed 32bit integer.
    function rbit.bshift( x, disp )
        if disp > 0 then
            return rbit_lshift( x, disp )
        end

        return rbit_rshift( x, -disp )
    end

end

if rbit.arshift == nil then

    --- [SHARED AND MENU]
    ---
    --- Performs an arithmetic right shift of the specified 32bit integer by the given number of bits.
    --- Bits shifted out of the bottom are discarded and the sign bit is copied into the vacated
    --- high-order bits, preserving the sign of the value.
    ---
    ---@param x integer The value to be shifted.
    ---@param disp integer The number of bits to shift right by.
    ---@return integer result The shifted value, normalized to a signed 32bit integer.
    function rbit.arshift( x, disp )
        if x < 0x80000000 then
            return rbit_tobit( math_floor( x / (2 ^ disp) ) )
        end

        return rbit_tobit( -math_floor( x / (2 ^ disp) ) )
    end

end

if rbit.lrotate == nil then

    local rbit_brotate = rbit.brotate
    if rbit_brotate == nil then

        --- [SHARED AND MENU]
        ---
        --- Rotates the bits of the specified 32bit integer to the left by the given number of bits.
        --- Bits shifted out of the top are wrapped around and shifted in at the bottom.
        ---
        ---@param x integer The value to be rotated.
        ---@param disp integer The number of bits to rotate left by.
        ---@return integer result The rotated value, normalized to a signed 32bit integer.
        function rbit.lrotate( x, disp )
            return rbit_bor( rbit_lshift( x, disp ), rbit_rshift( x, 32 - disp ) )
        end

    else

        --- [SHARED AND MENU]
        ---
        --- Rotates the bits of the specified 32bit integer to the left by the given number of bits.
        --- Bits shifted out of the top are wrapped around and shifted in at the bottom.
        ---
        ---@param x integer The value to be rotated.
        ---@param disp integer The number of bits to rotate left by.
        ---@return integer result The rotated value, normalized to a signed 32bit integer.
        function rbit.lrotate( x, disp )
            return rbit_brotate( x, disp )
        end

    end

end

local rbit_lrotate = rbit.lrotate

if rbit.rrotate == nil then

    local rbit_brotate = rbit.brotate
    if rbit_brotate == nil then

        --- [SHARED AND MENU]
        ---
        --- Rotates the bits of the specified 32bit integer to the right by the given number of bits.
        --- Bits shifted out of the bottom are wrapped around and shifted in at the top.
        ---
        ---@param x integer The value to be rotated.
        ---@param disp integer The number of bits to rotate right by.
        ---@return integer result The rotated value, normalized to a signed 32bit integer.
        function rbit.rrotate( x, disp )
            return rbit_bor( rbit_rshift( x, disp ), rbit_lshift( x, 32 - disp ) )
        end
    else

        --- [SHARED AND MENU]
        ---
        --- Rotates the bits of the specified 32bit integer to the right by the given number of bits.
        --- Bits shifted out of the bottom are wrapped around and shifted in at the top.
        ---
        ---@param x integer The value to be rotated.
        ---@param disp integer The number of bits to rotate right by.
        ---@return integer result The rotated value, normalized to a signed 32bit integer.
        function rbit.rrotate( x, disp )
            return rbit_brotate( x, -disp )
        end
    end

end

local rbit_rrotate = rbit.rrotate

if rbit.brotate == nil then

    --- [SHARED AND MENU]
    ---
    --- Rotates the bits of the specified 32bit integer.
    --- A positive displacement rotates left, a negative displacement rotates right.
    ---
    ---@param x integer The value to be rotated.
    ---@param disp integer The number of bits to rotate by. Positive rotates left, negative rotates right.
    ---@return integer result The rotated value, normalized to a signed 32bit integer.
    function rbit.brotate( x, disp )
        if disp > 0 then
            return rbit_lrotate( x, disp )
        end

        return rbit_rrotate( x, -disp )
    end

end

if rbit.btest == nil then

    --- [SHARED AND MENU]
    ---
    --- Performs a bitwise AND operation on all the specified 32bit integers and returns whether
    --- the result is non-zero.
    ---
    ---@param x integer The first value.
    ---@param ... integer Additional values to AND together with the first.
    ---@return boolean result `true` if the bitwise AND of all given values is non-zero, `false` otherwise.
    function rbit.btest( x, ... )
        return rbit_band( x, ... ) ~= 0
    end

end

if rbit.extract == nil then

    --- [SHARED AND MENU]
    ---
    --- Extracts a bit field of the given width from the specified 32bit integer, starting at
    --- the given bit position (0-indexed, counted from the least significant bit).
    ---
    ---@param x integer The value to extract the bit field from.
    ---@param field integer The starting bit position of the field (0-indexed).
    ---@param width integer? The number of bits in the field. Defaults to 1.
    ---@return integer result The extracted bit field, right-aligned as an unsigned integer.
    function rbit.extract( x, field, width )
        return rbit_band( rbit_rshift( x, field ), 2 ^ (width or 1) - 1 )
    end

end

if rbit.replace == nil then

    --- [SHARED AND MENU]
    ---
    --- Replaces a bit field of the given width in the specified 32bit integer, starting at the
    --- given bit position (0-indexed, counted from the least significant bit), with the bits
    --- taken from `extract`.
    ---
    ---@param x integer The value whose bit field is to be replaced.
    ---@param extract integer The value providing the replacement bits (only the lowest `width` bits are used).
    ---@param field integer The starting bit position of the field to replace (0-indexed).
    ---@param width integer? The number of bits in the field. Defaults to 1.
    ---@return integer result The value of `x` with the specified bit field replaced, normalized to a signed 32bit integer.
    function rbit.replace( x, extract, field, width )
        local mask = 2 ^ (width or 1) - 1
        return rbit_band( x, rbit_bnot( rbit_lshift( mask, field ) ) ) +
            rbit_lshift( rbit_band( extract, mask ), field )
    end

end

if rbit.bswap == nil then

    --- [SHARED AND MENU]
    ---
    --- Swaps the byte order (endianness) of the specified 32bit integer, reversing the order
    --- of its four constituent bytes.
    ---
    ---@param x integer The value whose byte order is to be swapped.
    ---@return integer result The byte-swapped value, normalized to a signed 32bit integer.
    function rbit.bswap( x )
        return rbit_bor(
            rbit_lshift( rbit_band( x, 0xFF ), 24 ),
            rbit_lshift( rbit_band( x, 0xFF00 ), 8 ),
            rbit_rshift( rbit_band( x, 0xFF0000 ), 8 ),
            rbit_rshift( x, 24 )
        )
    end

end

---@class dreamwork.std
local std = dreamwork.std

local debug = std.debug
local debug_getmetavalue = debug.getmetavalue

local raw = std.raw
local rbit = raw.bit

local rbit_bor = rbit.bor
local rbit_bxor = rbit.bxor
local rbit_band = rbit.band
local rbit_bnot = rbit.bnot

local rbit_lshift = rbit.lshift
local rbit_rshift = rbit.rshift
local rbit_arshift = rbit.arshift

local rbit_lrotate = rbit.lrotate
local rbit_rrotate = rbit.rrotate

local rbit_bswap = rbit.bswap

local lessEqual = std.lessEqual
local lessThan = std.lessThan
local equal = std.equal


--- [SHARED AND MENU]
---
--- The bit library.
---
---@class dreamwork.std.bit
local bit = {
    tobit = rbit.tobit,
    tohex = rbit.tohex,
}

std.bit = bit

if rbit.operators then

    bit.bor = rbit.bor
    bit.bxor = rbit.bxor

    bit.band = rbit.band
    bit.bnot = rbit.bnot

    bit.lshift = rbit.lshift
    bit.rshift = rbit.rshift

else

    --- [SHARED AND MENU]
    ---
    --- Returns the bitwise OR of all provided values.
    ---
    --- Each bit is tested against the following truth table:
    ---
    --- | A | B | Output |
    --- |:-:|:-:|:------:|
    --- | 0 | 0 |   0    |
    --- | 1 | 0 |   1    |
    --- | 0 | 1 |   1    |
    --- | 1 | 1 |   1    |
    ---
    --- ```
    ---     0101 0001   81
    ---     0001 0101   21
    --- OR  0000 0101   5
    --- _____________
    ---     0101 0101   85
    --- ```
    ---
    ---@generic T: integer | { __bor: function }
    ---@param x T The value to be manipulated.
    ---@param ... T? Values bit or with. Optional.
    ---@return T result The bitwise OR result between all values.
    function bit.bor( x, ... )
        ---@generic T
        ---@type fun( self: T, ...: T ): T
        local fn = debug_getmetavalue( x, "__bor" )
        if fn == nil then
            return rbit_bor( x, ... )
        end

        return fn( x, ... )
    end

    --- [SHARED AND MENU]
    ---
    --- Returns the bitwise XOR of all provided numbers.
    ---
    --- Each bit is tested against the following truth table:
    ---
    --- | A | B | Output |
    --- |:-:|:-:|:------:|
    --- | 0 | 0 |   0    |
    --- | 1 | 0 |   1    |
    --- | 0 | 1 |   1    |
    --- | 1 | 1 |   0    |
    ---
    --- <br/>
    ---
    --- ```
    ---     0101 0001   81
    ---     0001 0101   21
    --- XOR 0000 0101   5
    --- _____________
    ---     0100 0001   65
    --- ```
    ---
    ---@generic T: integer | { __bxor: function }
    ---@param x T The value to be manipulated.
    ---@param ... T? Values bit XOR with. Optional.
    ---@return T result Result of bitwise XOR` operation.
    function bit.bxor( x, ... )
        ---@generic T
        ---@type fun( self: T, ...: T ): T
        local fn = debug_getmetavalue( x, "__bxor" )
        if fn == nil then
            return rbit_bxor( x, ... )
        end

        return fn( x, ... )
    end

    --- [SHARED AND MENU]
    ---
    --- Returns the bitwise AND of all provided values.
    ---
    --- Each bit is tested against the following truth table:
    ---
    --- | A | B | Output |
    --- |:-:|:-:|:------:|
    --- | 0 | 0 |   0    |
    --- | 1 | 0 |   0    |
    --- | 0 | 1 |   0    |
    --- | 1 | 1 |   1    |
    ---
    --- ```
    ---     1100 1110   222
    ---     0101 1000   88
    --- AND 0100 1001   73
    --- _____________
    ---     0100 1000   72
    --- ```
    ---
    ---@generic T: integer | { __band: function }
    ---@param x T The value to be manipulated.
    ---@param ... T? Values bit to perform bitwise AND with. Optional.
    ---@return T result The bitwise AND result between all values.
    function bit.band( x, ... )
        ---@generic T
        ---@type fun( self: T, ...: T ): T
        local fn = debug_getmetavalue( x, "__band" )
        if fn == nil then
            return rbit_band( x, ... )
        end

        return fn( x, ... )
    end

    --- [SHARED AND MENU]
    ---
    --- Returns the bitwise NOT ( negation ) of `x`.
    ---
    --- Inverts every bit of the 32-bit integer.
    ---
    --- ```
    --- NOT 1111 0000   240
    --- _____________
    ---     0000 1111   15
    --- ```
    ---
    --- <br/>
    ---
    --- For any integer `x`, the following identity holds:
    ---
    --- ```lua
    --- assert( bit.bnot( x ) == ( -1 - x ) % 2 ^ 32 )
    --- ````
    ---
    ---@generic T: integer | { __bnot: function }
    ---@param x T The value to be manipulated/inverted.
    ---@return T result The result of bitwise `NOT` (`0101` becomes `1010`).
    function bit.bnot( x )
        ---@generic T
        ---@type fun( self: T ): T
        local fn = debug_getmetavalue( x, "__bnot" )
        if fn == nil then
            return rbit_bnot( x )
        end

        return fn( x )
    end

    --- [SHARED AND MENU]
    ---
    --- Returns the number `x` shifted `disp` bits to the left.
    ---
    --- The number `disp` may be any representable integer.
    ---
    --- Negative displacements shift to the right.
    ---
    --- In any direction, vacant bits are filled with zeros.
    ---
    --- In particular, displacements with absolute values higher than 31 result in zero (all bits are shifted out).
    ---
    --- ```
    ---     0000 1111   15
    --- LSH 0000 0011   3
    --- _____________
    ---     0111 1000   120
    --- ```
    ---
    --- **NOTE**: The returned value will be clamped to a signed 32-bit integer, even on 64-bit builds.
    ---
    --- See [this wiki article](https://en.wikipedia.org/wiki/Bitwise_operation#Bit_shifts) for more details.
    ---
    ---@generic T: integer | { __shl: function }
    ---@param x T The value to be manipulated.
    ---@param disp integer Amounts of bits to shift left by.
    ---@return T result The left shifted value. Input of `0b1001` will become `0b10010` for one left shift, etc.
    function bit.lshift( x, disp )
        ---@generic T
        ---@type fun( self: T, disp: integer ): T
        local fn = debug_getmetavalue( x, "__shl" )
        if fn == nil then
            if disp > 31 then
                return 0
            end

            return rbit_lshift( x, disp )
        end

        return fn( x, disp )
    end

    --- [SHARED AND MENU]
    ---
    --- Returns the number `x` shifted `disp` bits to the right.
    ---
    --- The number `disp` may be any representable integer.
    ---
    --- Negative displacements shift to the left. In any direction, vacant bits are filled with zeros.
    ---
    --- In particular, displacements with absolute values higher than 31 result in zero (all bits are shifted out).
    ---
    --- ```
    ---     0111 1000   120
    --- RSH 0000 0011   3
    --- _____________
    ---     0000 1111   15
    --- ```
    ---
    --- **NOTE**: The returned value will be clamped to a signed 32-bit integer, even on 64-bit builds.
    ---
    --- See [this wiki article](https://en.wikipedia.org/wiki/Bitwise_operation#Bit_shifts) for more details.
    ---
    ---@generic T: integer | { __shr: function }
    ---@param x T The value to be manipulated.
    ---@param disp integer Amounts of bits to shift right by.
    ---@return T result The right shifted value.
    function bit.rshift( x, disp )
        ---@generic T
        ---@type fun( self: T, disp: integer ): T
        local fn = debug_getmetavalue( x, "__shr" )
        if fn == nil then
            if disp > 31 then
                return 0
            end

            return rbit_rshift( x, disp )
        end

        return fn( x, disp )
    end

end

--- [SHARED AND MENU]
---
--- Returns the number `x` arithmetically shifted `disp` bits to the right.
---
--- Unlike `bit.rshift`, the vacated high-order bits are filled with copies of the sign bit
--- of `x` rather than zeros, so the sign of the value is preserved.
---
--- Negative displacements shift to the left, behaving identically to `bit.lshift` in that case.
---
--- ```
---     1111 1000   -8  (as a signed 8-bit value)
--- ARSH 0000 0010   2
--- _____________
---     1111 1110   -2
--- ```
---
---@generic T: integer | { __shar: function }
---@param x T The value to be manipulated.
---@param disp integer Amounts of bits to shift.
---@return T result The arithmetically shifted value.
function bit.arshift( x, disp )
    ---@generic T
    ---@type fun( self: T, disp: integer ): T
    local fn = debug_getmetavalue( x, "__shar" )
    if fn == nil then
        return rbit_arshift( x, disp )
    end

    return fn( x, disp )
end

--- [SHARED AND MENU]
---
--- Returns the number `x` rotated `disp` bits to the left.
---
--- The number `disp` may be any representable integer.
---
--- For any valid displacement, the following identity holds:
---
--- ```lua
--- assert( bit.lrotate( x, disp ) == bit.lrotate( x, disp % 32 ) )
--- ```
---
---@generic T: integer | { __brol: function }
---@param x T The value to be manipulated.
---@param disp integer Amounts of bits to rotate left by.
---@return T result The left rotated value.
function bit.rol( x, disp )
    ---@generic T
    ---@type fun( self: T, disp: integer ): T
    local fn = debug_getmetavalue( x, "__brol" )
    if fn == nil then
        return rbit_lrotate( x, disp )
    end

    return fn( x, disp )
end

--- [SHARED AND MENU]
---
--- Returns the number `x` rotated `disp` bits to the right.
---
--- The number `disp` may be any representable integer.
---
--- For any valid displacement, the following identity holds:
---
--- ```lua
--- assert( bit.rrotate( x, disp ) == bit.rrotate( x, disp % 32 ) )
--- ```
---
--- In particular, negative displacements rotate to the left.
---
---@generic T: integer | { __bror: function }
---@param x T The value to be manipulated.
---@param disp integer Amounts of bits to rotate right by.
---@return T result The right rotated value.
function bit.ror( x, disp )
    ---@generic T
    ---@type fun( self: T, disp: integer ): T
    local fn = debug_getmetavalue( x, "__bror" )
    if fn == nil then
        return rbit_rrotate( x, disp )
    end

    return fn( x, disp )
end

--- [SHARED AND MENU]
---
--- Swaps the byte order of a 32-bit integer.
---
---@generic T: integer | { __bswp: function }
---@param x T The 32-bit integer to be byte-swapped.
---@return T result The byte-swapped value.
function bit.bswap( x )
    ---@generic T
    ---@type fun( self: T ): T
    local fn = debug_getmetavalue( x, "__bswp" )
    if fn == nil then
        return rbit_bswap( x )
    end

    return fn( x )
end

local bit_lshift, bit_rshift = bit.lshift, bit.rshift
local bit_bnot, bit_bxor = bit.bnot, bit.bxor
local bit_band, bit_bor = bit.band, bit.bor

--- [SHARED AND MENU]
---
--- Returns whether the bitwise AND of all provided values is non-zero, i.e. whether
--- `x` and every value in `...` have at least one bit in common.
---
--- Equivalent to `bit.band( x, ... ) ~= 0`, but without needing to look at the result.
---
---@generic T: integer | { __band: function, __eq: function }
---@param x T The first value to test.
---@param ... integer Additional values to test against the first. Optional.
---@return boolean result `true` if any bit is set in every given value, `false` otherwise.
function bit.btest( x, ... )
    return not equal( bit_band( x, ... ), 0 )
end

--- [SHARED AND MENU]
---
--- Extracts a bit field of the given `width` from `x`, starting at bit position `field`
--- (0-indexed, counted from the least significant bit).
---
--- Equivalent to shifting `x` right by `field` bits and then masking off everything above `width` bits.
---
--- ```
--- extract( 0b10110100, 2, 3 ) --> 0b101 ( 5 )
--- ```
---
---@generic T: integer | { __rshift: function, __band: function }
---@param x T The value to extract the bit field from.
---@param field integer The starting bit position of the field (0-indexed).
---@param width integer? The number of bits in the field. Defaults to 1.
---@return T result The extracted bit field, right-aligned as an unsigned integer.
function bit.extract( x, field, width )
    return bit_band( bit_rshift( x, field ), 2 ^ (width or 1) - 1 )
end

--- [SHARED AND MENU]
---
--- Replaces a bit field of the given `width` in `x`, starting at bit position `field`
--- (0-indexed, counted from the least significant bit), with the low `width` bits of `extract`.
---
--- All bits of `x` outside the targeted field are left unchanged.
---
---@generic T: integer | { __band: function, __bnot: function, __lshift: function }
---@param x T The value whose bit field is to be replaced.
---@param extract integer The value providing the replacement bits (only the lowest `width` bits are used).
---@param field integer The starting bit position of the field to replace (0-indexed).
---@param width integer? The number of bits in the field. Defaults to 1.
---@return T result The value of `x` with the specified bit field replaced.
function bit.replace( x, extract, field, width )
    local mask = 2 ^ (width or 1) - 1
    return bit_band( x, bit_bnot( bit_lshift( mask, field ) ) ) +
        bit_lshift( bit_band( extract, mask ), field )
end

--- [SHARED AND MENU]
---
--- Reverses the order of the lowest `bit_count` bits of `x`, so the least significant bit
--- becomes the most significant bit (within that range) and vice versa.
---
--- ```
--- reverse( 0b1011000, 7 ) --> 0b0001101
--- ```
---
---@generic T: integer | { __bor: function, __band: function, __lshift: function, __rshift: function }
---@param x T The value whose bits are to be reversed.
---@param bit_count integer? The number of low-order bits to reverse. Defaults to `32`.
---@return T result The value of `x` with its bits reversed.
function bit.reverse( x, bit_count )
    if bit_count == nil then
        bit_count = 32
    end

    local result = bit_band( x, 1 )
    x = bit_rshift( x, 1 )

    for i = 2, bit_count do
        result = bit_bor( bit_lshift( result, 1 ), bit_band( x, 1 ) )
        x = bit_rshift( x, 1 )
    end

    return result
end

--- [SHARED AND MENU]
---
--- Counts the number of leading zero bits in `x`, starting from the most significant bit
--- of the `bit_count`-bit window and stopping at the first `1` bit.
---
--- Returns `bit_count` if `x` is zero (i.e. all bits within the window are zero).
---
---@generic T: integer | { __band: function, __bxor: function, __rshift: function }
---@param x T The value to count the leading zeros of.
---@param bit_count integer? The width, in bits, of the window to inspect. Defaults to `32`.
---@return T result The number of leading zero bits.
function bit.clz( x, bit_count )
    if bit_count == nil then
        bit_count = 32
    end

    local zero = bit_bxor( x, x )

    if x == zero then
        return bit_count
    end

    ---@type integer
    local count = 0

    for i = (bit_count - 1), 0, -1 do
        if bit_band( bit_rshift( x, i ), 1 ) ~= zero then
            break
        end

        count = count + 1
    end

    return count
end

--- [SHARED AND MENU]
---
--- Counts the number of trailing zero bits in `x`, starting from the least significant bit
--- and stopping at the first `1` bit.
---
--- Returns `bit_count` if `x` is zero (i.e. all bits within the window are zero).
---
---@generic T: integer | { __band: function, __bxor: function, __rshift: function }
---@param x T The value to count the trailing zeros of.
---@param bit_count integer? The width, in bits, of the window to inspect. Defaults to `32`.
---@return T result The number of trailing zero bits.
function bit.ctz( x, bit_count )
    if bit_count == nil then
        bit_count = 32
    end

    local zero = bit_bxor( x, x )

    if x == zero then
        return bit_count
    end

    for count = 0, bit_count - 1 do
        if bit_band( x, 1 ) ~= zero then
            return count
        end

        x = bit_rshift( x, 1 )
    end

    return bit_count
end

--- [SHARED AND MENU]
---
--- Bitwise multiplexer (also known as "choose"). For each bit position, selects the
--- corresponding bit of `b` where `a` is `1`, and the corresponding bit of `c` where `a` is `0`.
---
--- Equivalent to `c ~ (a & (b ~ c))`, and often used as the `Ch` function in hash algorithms
--- such as SHA-2.
---
---@generic T: integer | { __band: function, __bxor: function }
---@param a T The selector value: a `1` bit picks from `b`, a `0` bit picks from `c`.
---@param b T The value to select bits from where `a` is `1`.
---@param c T The value to select bits from where `a` is `0`.
---@return T result The bitwise multiplexed value.
function bit.mux( a, b, c )
    return bit_bxor( c, bit_band( a, bit_bxor( b, c ) ) )
end

--- [SHARED AND MENU]
---
--- Bitwise majority function. For each bit position, returns `1` if at least two of the three
--- corresponding bits of `a`, `b` and `c` are `1`, and `0` otherwise.
---
--- Equivalent to `(a & (b | c)) | (b & c)`, and often used as the `Maj` function in hash
--- algorithms such as SHA-2.
---
---@generic T: integer | { __band: function, __bor: function }
---@param a T The first value.
---@param b T The second value.
---@param c T The third value.
---@return T result The bitwise majority value.
function bit.maj( a, b, c )
    return bit_bor( bit_band( a, bit_bor( b, c ) ), bit_band( b, c ) )
end

--- [SHARED AND MENU]
---
--- Returns the sign of an integer.
---
---@generic T: integer | { __le: function, __sub: function }
---@param x T The integer to get the sign of.
---@param bit_count? integer The amount of bits to unsign to, `32` by default.
---@return integer result The sign of the integer: 1 for positive, 0 for zero, -1 for negative.
function bit.sign( x, bit_count )
    return lessEqual( x, 0 ) and x or (x - ((bit_count == nil) and 0x100000000 or (2 ^ bit_count)))
end

--- [SHARED AND MENU]
---
--- Returns the unsigned value of an integer.
---
---@generic T: integer | { __lt: function, __add: function }
---@param x T The integer to get the unsigned value of.
---@param bit_count? integer The amount of bits to unsign to, `32` by default.
---@return T result The unsigned value of the integer.
function bit.unsign( x, bit_count )
    return lessThan( x, 0 ) and (x + ((bit_count == nil) and 0x100000000 or (2 ^ bit_count))) or x
end

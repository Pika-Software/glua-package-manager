-- Based on https://github.com/kikito/md5.lua

local std = dreamwork.std

---@class dreamwork.std.crypto
local crypto = std.crypto

local class = std.class

local bit = std.bit
local bit_bxor = bit.bxor
local bit_band, bit_bor = bit.band, bit.bor
local bit_lshift, bit_rshift = bit.lshift, bit.rshift

local string = std.string
local string_len = string.len
local string_rep = string.rep
local string_format = string.format
local string_char, string_byte = string.char, string.byte

local math = std.math
local math_floor = math.floor

local bytepack = std.bytepack
local bytepack_readUInt32 = bytepack.readUInt32BE
local bytepack_writeUInt32 = bytepack.writeUInt32BE

--- [SHARED AND MENU]
---
--- MD5 object.
---
---@class dreamwork.std.crypto.MD5 : dreamwork.std.Object
---@field __class dreamwork.std.crypto.MD5Class
local MD5 = class.base( "MD5" )

--- [SHARED AND MENU]
---
--- The class used to create new `MD5` hash calculation instances.
---
--- Computes a cryptographic 128-bit hash value.
---
--- Like other hash classes, it takes input data ( string ) and
--- produces a digest ( string ) — a fixed-size output string that
--- represents that data.
---
--- **MD5 is insecure**
---
--- Because of collision attacks,
--- attackers can find two different inputs
--- that produce the same hash.
---
--- This violates one of the basic principles
--- of a secure hash function - collision resistance.
---
---@class dreamwork.std.crypto.MD5Class : dreamwork.std.crypto.MD5
---@field __base dreamwork.std.crypto.MD5
---@field digest_size integer
---@field block_size integer
---@overload fun(): dreamwork.std.crypto.MD5
local MD5Class = class.create( MD5 )
crypto.MD5 = MD5Class

MD5Class.digest_size = 16
MD5Class.block_size = 64

---@param x integer
---@param y integer
---@param z integer
---@return integer
local function f( x, y, z )
    return bit_bor( bit_band( x, y ), bit_band( -x - 1, z ) )
end

---@param x integer
---@param y integer
---@param z integer
---@return integer
local function g( x, y, z )
    return bit_bor( bit_band( x, z ), bit_band( y, -(z + 1) ) )
end

---@param x integer
---@param y integer
---@param z integer
---@return integer
local function i( x, y, z )
    return bit_bxor( y, bit_bor( x, -(z + 1) ) )
end

---@param a integer
---@param b integer
---@param c integer
---@param x integer
---@param shift integer
---@param constant integer
---@return integer
local function z( a, b, c, x, shift, constant )
    -- a = bit_band( a + c + x + constant, 0xFFFFFFFF )
    a = a + c + x + constant
    -- be *very* careful that left shift does not cause rounding!
    return bit_bor( bit_lshift( bit_band( a, bit_rshift( 0xFFFFFFFF, shift ) ), shift ), bit_rshift( a, 32 - shift ) ) + b
end

--- [SHARED AND MENU]
---
--- Performs a single MD5 transformation.
---
---@param in_str string
---@param index integer
---@param in_a integer
---@param in_b integer
---@param in_c integer
---@param in_d integer
---@return integer
---@return integer
---@return integer
---@return integer
local function transform( in_str, index, in_a, in_b, in_c, in_d )
    local uint32_1 = bytepack_readUInt32( string_byte( in_str, index, index + 3 ) )
    local uint32_2 = bytepack_readUInt32( string_byte( in_str, index + 4, index + 7 ) )
    local uint32_3 = bytepack_readUInt32( string_byte( in_str, index + 8, index + 11 ) )
    local uint32_4 = bytepack_readUInt32( string_byte( in_str, index + 12, index + 15 ) )
    local uint32_5 = bytepack_readUInt32( string_byte( in_str, index + 16, index + 19 ) )
    local uint32_6 = bytepack_readUInt32( string_byte( in_str, index + 20, index + 23 ) )
    local uint32_7 = bytepack_readUInt32( string_byte( in_str, index + 24, index + 27 ) )
    local uint32_8 = bytepack_readUInt32( string_byte( in_str, index + 28, index + 31 ) )
    local uint32_9 = bytepack_readUInt32( string_byte( in_str, index + 32, index + 35 ) )
    local uint32_10 = bytepack_readUInt32( string_byte( in_str, index + 36, index + 39 ) )
    local uint32_11 = bytepack_readUInt32( string_byte( in_str, index + 40, index + 43 ) )
    local uint32_12 = bytepack_readUInt32( string_byte( in_str, index + 44, index + 47 ) )
    local uint32_13 = bytepack_readUInt32( string_byte( in_str, index + 48, index + 51 ) )
    local uint32_14 = bytepack_readUInt32( string_byte( in_str, index + 52, index + 55 ) )
    local uint32_15 = bytepack_readUInt32( string_byte( in_str, index + 56, index + 59 ) )
    local uint32_16 = bytepack_readUInt32( string_byte( in_str, index + 60, index + 63 ) )

    local out_a, out_b, out_c, out_d = in_a, in_b, in_c, in_d

    out_a = z( out_a, out_b, f( out_b, out_c, out_d ), uint32_1, 7, 0xd76aa478 )
    out_d = z( out_d, out_a, f( out_a, out_b, out_c ), uint32_2, 12, 0xe8c7b756 )
    out_c = z( out_c, out_d, f( out_d, out_a, out_b ), uint32_3, 17, 0x242070db )
    out_b = z( out_b, out_c, f( out_c, out_d, out_a ), uint32_4, 22, 0xc1bdceee )
    out_a = z( out_a, out_b, f( out_b, out_c, out_d ), uint32_5, 7, 0xf57c0faf )
    out_d = z( out_d, out_a, f( out_a, out_b, out_c ), uint32_6, 12, 0x4787c62a )
    out_c = z( out_c, out_d, f( out_d, out_a, out_b ), uint32_7, 17, 0xa8304613 )
    out_b = z( out_b, out_c, f( out_c, out_d, out_a ), uint32_8, 22, 0xfd469501 )
    out_a = z( out_a, out_b, f( out_b, out_c, out_d ), uint32_9, 7, 0x698098d8 )
    out_d = z( out_d, out_a, f( out_a, out_b, out_c ), uint32_10, 12, 0x8b44f7af )
    out_c = z( out_c, out_d, f( out_d, out_a, out_b ), uint32_11, 17, 0xffff5bb1 )
    out_b = z( out_b, out_c, f( out_c, out_d, out_a ), uint32_12, 22, 0x895cd7be )
    out_a = z( out_a, out_b, f( out_b, out_c, out_d ), uint32_13, 7, 0x6b901122 )
    out_d = z( out_d, out_a, f( out_a, out_b, out_c ), uint32_14, 12, 0xfd987193 )
    out_c = z( out_c, out_d, f( out_d, out_a, out_b ), uint32_15, 17, 0xa679438e )
    out_b = z( out_b, out_c, f( out_c, out_d, out_a ), uint32_16, 22, 0x49b40821 )

    out_a = z( out_a, out_b, g( out_b, out_c, out_d ), uint32_2, 5, 0xf61e2562 )
    out_d = z( out_d, out_a, g( out_a, out_b, out_c ), uint32_7, 9, 0xc040b340 )
    out_c = z( out_c, out_d, g( out_d, out_a, out_b ), uint32_12, 14, 0x265e5a51 )
    out_b = z( out_b, out_c, g( out_c, out_d, out_a ), uint32_1, 20, 0xe9b6c7aa )
    out_a = z( out_a, out_b, g( out_b, out_c, out_d ), uint32_6, 5, 0xd62f105d )
    out_d = z( out_d, out_a, g( out_a, out_b, out_c ), uint32_11, 9, 0x02441453 )
    out_c = z( out_c, out_d, g( out_d, out_a, out_b ), uint32_16, 14, 0xd8a1e681 )
    out_b = z( out_b, out_c, g( out_c, out_d, out_a ), uint32_5, 20, 0xe7d3fbc8 )
    out_a = z( out_a, out_b, g( out_b, out_c, out_d ), uint32_10, 5, 0x21e1cde6 )
    out_d = z( out_d, out_a, g( out_a, out_b, out_c ), uint32_15, 9, 0xc33707d6 )
    out_c = z( out_c, out_d, g( out_d, out_a, out_b ), uint32_4, 14, 0xf4d50d87 )
    out_b = z( out_b, out_c, g( out_c, out_d, out_a ), uint32_9, 20, 0x455a14ed )
    out_a = z( out_a, out_b, g( out_b, out_c, out_d ), uint32_14, 5, 0xa9e3e905 )
    out_d = z( out_d, out_a, g( out_a, out_b, out_c ), uint32_3, 9, 0xfcefa3f8 )
    out_c = z( out_c, out_d, g( out_d, out_a, out_b ), uint32_8, 14, 0x676f02d9 )
    out_b = z( out_b, out_c, g( out_c, out_d, out_a ), uint32_13, 20, 0x8d2a4c8a )

    out_a = z( out_a, out_b, bit_bxor( out_b, bit_bxor( out_c, out_d ) ), uint32_6, 4, 0xfffa3942 )
    out_d = z( out_d, out_a, bit_bxor( out_a, bit_bxor( out_b, out_c ) ), uint32_9, 11, 0x8771f681 )
    out_c = z( out_c, out_d, bit_bxor( out_d, bit_bxor( out_a, out_b ) ), uint32_12, 16, 0x6d9d6122 )
    out_b = z( out_b, out_c, bit_bxor( out_c, bit_bxor( out_d, out_a ) ), uint32_15, 23, 0xfde5380c )
    out_a = z( out_a, out_b, bit_bxor( out_b, bit_bxor( out_c, out_d ) ), uint32_2, 4, 0xa4beea44 )
    out_d = z( out_d, out_a, bit_bxor( out_a, bit_bxor( out_b, out_c ) ), uint32_5, 11, 0x4bdecfa9 )
    out_c = z( out_c, out_d, bit_bxor( out_d, bit_bxor( out_a, out_b ) ), uint32_8, 16, 0xf6bb4b60 )
    out_b = z( out_b, out_c, bit_bxor( out_c, bit_bxor( out_d, out_a ) ), uint32_11, 23, 0xbebfbc70 )
    out_a = z( out_a, out_b, bit_bxor( out_b, bit_bxor( out_c, out_d ) ), uint32_14, 4, 0x289b7ec6 )
    out_d = z( out_d, out_a, bit_bxor( out_a, bit_bxor( out_b, out_c ) ), uint32_1, 11, 0xeaa127fa )
    out_c = z( out_c, out_d, bit_bxor( out_d, bit_bxor( out_a, out_b ) ), uint32_4, 16, 0xd4ef3085 )
    out_b = z( out_b, out_c, bit_bxor( out_c, bit_bxor( out_d, out_a ) ), uint32_7, 23, 0x04881d05 )
    out_a = z( out_a, out_b, bit_bxor( out_b, bit_bxor( out_c, out_d ) ), uint32_10, 4, 0xd9d4d039 )
    out_d = z( out_d, out_a, bit_bxor( out_a, bit_bxor( out_b, out_c ) ), uint32_13, 11, 0xe6db99e5 )
    out_c = z( out_c, out_d, bit_bxor( out_d, bit_bxor( out_a, out_b ) ), uint32_16, 16, 0x1fa27cf8 )
    out_b = z( out_b, out_c, bit_bxor( out_c, bit_bxor( out_d, out_a ) ), uint32_3, 23, 0xc4ac5665 )

    out_a = z( out_a, out_b, i( out_b, out_c, out_d ), uint32_1, 6, 0xf4292244 )
    out_d = z( out_d, out_a, i( out_a, out_b, out_c ), uint32_8, 10, 0x432aff97 )
    out_c = z( out_c, out_d, i( out_d, out_a, out_b ), uint32_15, 15, 0xab9423a7 )
    out_b = z( out_b, out_c, i( out_c, out_d, out_a ), uint32_6, 21, 0xfc93a039 )
    out_a = z( out_a, out_b, i( out_b, out_c, out_d ), uint32_13, 6, 0x655b59c3 )
    out_d = z( out_d, out_a, i( out_a, out_b, out_c ), uint32_4, 10, 0x8f0ccc92 )
    out_c = z( out_c, out_d, i( out_d, out_a, out_b ), uint32_11, 15, 0xffeff47d )
    out_b = z( out_b, out_c, i( out_c, out_d, out_a ), uint32_2, 21, 0x85845dd1 )
    out_a = z( out_a, out_b, i( out_b, out_c, out_d ), uint32_9, 6, 0x6fa87e4f )
    out_d = z( out_d, out_a, i( out_a, out_b, out_c ), uint32_16, 10, 0xfe2ce6e0 )
    out_c = z( out_c, out_d, i( out_d, out_a, out_b ), uint32_7, 15, 0xa3014314 )
    out_b = z( out_b, out_c, i( out_c, out_d, out_a ), uint32_14, 21, 0x4e0811a1 )
    out_a = z( out_a, out_b, i( out_b, out_c, out_d ), uint32_5, 6, 0xf7537e82 )
    out_d = z( out_d, out_a, i( out_a, out_b, out_c ), uint32_12, 10, 0xbd3af235 )
    out_c = z( out_c, out_d, i( out_d, out_a, out_b ), uint32_3, 15, 0x2ad7d2bb )
    out_b = z( out_b, out_c, i( out_c, out_d, out_a ), uint32_10, 21, 0xeb86d391 )

    return (in_a + out_a) % 0xFFFFFFFF,
        (in_b + out_b) % 0xFFFFFFFF,
        (in_c + out_c) % 0xFFFFFFFF,
        (in_d + out_d) % 0xFFFFFFFF
end

--- [SHARED AND MENU]
---
--- Resets the MD5 object to its initial state.
---
--- This instance method resets the MD5 object to its initial state.
---
--- It returns the MD5 object for method chaining.
---
---@return dreamwork.std.crypto.MD5 obj The reset MD5 object.
function MD5:reset()
    self.a, self.b, self.c, self.d = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476

    self.message_length = 0
    self.message = ""

    self.position = 0
    return self
end

MD5.__init = MD5.reset

local bucket64 = math.bucketize( 64 )

--- [SHARED AND MENU]
---
--- Updates the MD5 object with the given string.
---
--- This instance method updates the MD5 object with the given string.
---
--- It returns the MD5 object for method chaining.
---
---@param str string The string to update the MD5 object with.
---@return dreamwork.std.crypto.MD5 obj The updated MD5 object.
function MD5:update( str )
    local message_length = self.message_length + string_len( str )
    self.message_length = message_length

    if message_length < 64 then
        self.message = self.message .. str
        return self
    end

    local message, position, blocks_size = self.message .. str, self.position, bucket64( message_length )

    local a, b, c, d = self.a, self.b, self.c, self.d

    for index = position + 1, blocks_size, 64 do
        a, b, c, d = transform( message, index, a, b, c, d )
    end

    self.a, self.b, self.c, self.d = a, b, c, d

    self.position = position + blocks_size
    self.message = message

    return self
end

--- [SHARED AND MENU]
---
--- Calculates the MD5 digest based on the current state or input of the object.
---
--- This instance method returns the MD5 hash of the data associated with the object.
--- Useful when the MD5 object has been incrementally updated with input data.
---
---@param as_hex? boolean If true, the result will be a hex string.
---@return string str_result The MD5 string of the message.
function MD5:digest( as_hex )
    local position = self.position
    local message_length = self.message_length
    local remaining = message_length - position
    local padding = 64 - (remaining + 9)

    local bit_count = message_length * 8

    if message_length > 0x20000000 then
        bit_count = bit_count % 0x100000000
    end

    local block = self.message .. "\128" .. string_rep( "\0", padding ) ..
        string_char( bytepack_writeUInt32( bit_count ) ) ..
        string_char( bytepack_writeUInt32( math_floor( message_length / 0x20000000 ) ) )

    local a, b, c, d = self.a, self.b, self.c, self.d

    for index = position + 1, message_length + 1 + padding + 8, 64 do
        a, b, c, d = transform( block, index, a, b, c, d )
    end

    local uint8_1, uint8_2, uint8_3, uint8_4 = bytepack_writeUInt32( a )
    local uint8_5, uint8_6, uint8_7, uint8_8 = bytepack_writeUInt32( b )
    local uint8_9, uint8_10, uint8_11, uint8_12 = bytepack_writeUInt32( c )
    local uint8_13, uint8_14, uint8_15, uint8_16 = bytepack_writeUInt32( d )

    if as_hex then
        return string_format( "%08x%08x%08x%08x",
            bytepack_readUInt32( uint8_4, uint8_3, uint8_2, uint8_1 ),
            bytepack_readUInt32( uint8_8, uint8_7, uint8_6, uint8_5 ),
            bytepack_readUInt32( uint8_12, uint8_11, uint8_10, uint8_9 ),
            bytepack_readUInt32( uint8_16, uint8_15, uint8_14, uint8_13 )
        )
    end

    return string_char( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8, uint8_9, uint8_10, uint8_11, uint8_12, uint8_13, uint8_14, uint8_15, uint8_16 )
end

local engine_MD5 = dreamwork.engine.MD5

if engine_MD5 == nil then

    --- [SHARED AND MENU]
    ---
    --- Computes the MD5 digest of the given input string.
    ---
    --- This static method takes a string and returns its MD5 hash as a hexadecimal string.
    --- Commonly used for checksums, data integrity validation, and password hashing.
    ---
    ---@param message string The message to compute MD5 for.
    ---@param as_hex? boolean If true, the result will be a hex string.
    ---@return string str_result The MD5 string of the message.
    function MD5Class.digest( message, as_hex )
        local message_length = string_len( message )
        local padding = 64 - (message_length % 64 + 9)

        local bit_count = message_length * 8

        if message_length > 0x20000000 then
            bit_count = bit_count % 0x100000000
        end

        local block = message .. "\128" .. string_rep( "\0", padding ) ..
            string_char( bytepack_writeUInt32( bit_count ) ) ..
            string_char( bytepack_writeUInt32( math_floor( message_length / 0x20000000 ) ) )

        local a, b, c, d = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476

        for index = 1, message_length + 1 + padding + 8, 64 do
            a, b, c, d = transform( block, index, a, b, c, d )
        end

        local uint8_1, uint8_2, uint8_3, uint8_4 = bytepack_writeUInt32( a )
        local uint8_5, uint8_6, uint8_7, uint8_8 = bytepack_writeUInt32( b )
        local uint8_9, uint8_10, uint8_11, uint8_12 = bytepack_writeUInt32( c )
        local uint8_13, uint8_14, uint8_15, uint8_16 = bytepack_writeUInt32( d )

        if as_hex then
            return string_format( "%08x%08x%08x%08x",
                bytepack_readUInt32( uint8_4, uint8_3, uint8_2, uint8_1 ),
                bytepack_readUInt32( uint8_8, uint8_7, uint8_6, uint8_5 ),
                bytepack_readUInt32( uint8_12, uint8_11, uint8_10, uint8_9 ),
                bytepack_readUInt32( uint8_16, uint8_15, uint8_14, uint8_13 )
            )
        end

        return string_char( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8, uint8_9, uint8_10, uint8_11, uint8_12, uint8_13, uint8_14, uint8_15, uint8_16 )
    end

else

    local base16_decode = std.base16.decode

    --- [SHARED AND MENU]
    ---
    --- Computes the MD5 digest of the given input string.
    ---
    --- This static method takes a string and returns its MD5 hash as a hexadecimal string.
    --- Commonly used for checksums, data integrity validation, and password hashing.
    ---
    ---@param message string The message to compute MD5 for.
    ---@param as_hex? boolean If true, the result will be a hex string.
    ---@return string str_result The MD5 string of the message.
    function MD5Class.digest( message, as_hex )
        local hex_str = engine_MD5( message )
        if as_hex then
            return hex_str
        else
            return base16_decode( hex_str )
        end
    end

end

local std = dreamwork.std

---@class dreamwork.std.crypto
local crypto = std.crypto

local bit = std.bit
local bit_bxor = bit.bxor
local bit_lrotate = bit.lrotate
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
--- SHA1 object.
---
---@class dreamwork.std.crypto.SHA1 : dreamwork.std.Object
---@field __class dreamwork.std.crypto.SHA1Class
local SHA1 = std.class.base( "SHA1" )

--- [SHARED AND MENU]
---
--- The class used to create new `SHA1` hash calculation instances.
---
--- Computes a cryptographic 160-bit hash value.
---
--- Like other hash classes, it takes input data ( string )
--- and produces a digest ( string ) — a
--- fixed-size output string that represents that data.
---
--- **SHA1 is insecure**
---
--- Because of collision attacks,
--- attackers can find two different inputs
--- that produce the same hash.
---
--- This violates one of the basic principles
--- of a secure hash function - collision resistance.
---
---@class dreamwork.std.crypto.SHA1Class : dreamwork.std.crypto.SHA1
---@field __base dreamwork.std.crypto.SHA1
---@field digest_size integer
---@field block_size integer
---@overload fun(): dreamwork.std.crypto.SHA1
local SHA1Class = std.class.create( SHA1 )
crypto.SHA1 = SHA1Class

SHA1Class.digest_size = 20
SHA1Class.block_size = 64

local blk0

-- if std.SYSTEM_ENDIANNESS then
--     function blk0( block, index )
--         print( "blk0", index )
--         return block[ index ]
--     end
-- else
--     function blk0( block, index )
--         local initial_value = block[ index ]

--         local value = bit_bor(
--             bit_band( bit_lrotate( initial_value, 0x18 ), 0xff00ff00 ),
--             bit_band( bit_lrotate( initial_value, 0x08 ), 0x00ff00ff )
--         )

--         block[ index ] = value
--         print( "blk0", index )
--         return value
--     end
-- end

local function blk( block, index )
    local initial_index = bit_band( index, 0xf )

    local value = bit_lrotate( bit_bxor(
        block[ initial_index ] or 0,
        block[ bit_band( index + 2, 0x0f ) ] or 0,
        block[ bit_band( index + 8, 0x0f ) ] or 0,
        block[ bit_band( index + 13, 0xf ) ] or 0
    ), 1 )

    block[ initial_index ] = value
    return value
end

--- [SHARED AND MENU]
---
--- Perform a single SHA1 transformation.
---
---@param block integer[]
---@param h1 integer
---@param h2 integer
---@param h3 integer
---@param h4 integer
---@param h5 integer
---@return integer h1
---@return integer h2
---@return integer h3
---@return integer h4
---@return integer h5
local function transform( block, h1, h2, h3, h4, h5 )
    -- Round 0
    h5 = h5 + bit_bxor( bit_band( h2, bit_bxor( h3, h4 ) ), h4 ) + blk0( block, 1 ) + 0x5A827999 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( bit_band( h1, bit_bxor( h2, h3 ) ), h3 ) + blk0( block, 2 ) + 0x5A827999 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( bit_band( h5, bit_bxor( h1, h2 ) ), h2 ) + blk0( block, 3 ) + 0x5A827999 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( bit_band( h4, bit_bxor( h5, h1 ) ), h1 ) + blk0( block, 4 ) + 0x5A827999 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( bit_band( h3, bit_bxor( h4, h5 ) ), h5 ) + blk0( block, 5 ) + 0x5A827999 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( bit_band( h2, bit_bxor( h3, h4 ) ), h4 ) + blk0( block, 6 ) + 0x5A827999 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( bit_band( h1, bit_bxor( h2, h3 ) ), h3 ) + blk0( block, 7 ) + 0x5A827999 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( bit_band( h5, bit_bxor( h1, h2 ) ), h2 ) + blk0( block, 8 ) + 0x5A827999 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( bit_band( h4, bit_bxor( h5, h1 ) ), h1 ) + blk0( block, 9 ) + 0x5A827999 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( bit_band( h3, bit_bxor( h4, h5 ) ), h5 ) + blk0( block, 10 ) + 0x5A827999 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( bit_band( h2, bit_bxor( h3, h4 ) ), h4 ) + blk0( block, 11 ) + 0x5A827999 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( bit_band( h1, bit_bxor( h2, h3 ) ), h3 ) + blk0( block, 12 ) + 0x5A827999 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( bit_band( h5, bit_bxor( h1, h2 ) ), h2 ) + blk0( block, 13 ) + 0x5A827999 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( bit_band( h4, bit_bxor( h5, h1 ) ), h1 ) + blk0( block, 14 ) + 0x5A827999 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( bit_band( h3, bit_bxor( h4, h5 ) ), h5 ) + blk0( block, 15 ) + 0x5A827999 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( bit_band( h2, bit_bxor( h3, h4 ) ), h4 ) + blk0( block, 16 ) + 0x5A827999 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    -- Round 1
    h4 = h4 + bit_bxor( bit_band( h1, bit_bxor( h2, h3 ) ), h3 ) + blk( block, 17 ) + 0x5A827999 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( bit_band( h5, bit_bxor( h1, h2 ) ), h2 ) + blk( block, 18 ) + 0x5A827999 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( bit_band( h4, bit_bxor( h5, h1 ) ), h1 ) + blk( block, 19 ) + 0x5A827999 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( bit_band( h3, bit_bxor( h4, h5 ) ), h5 ) + blk( block, 20 ) + 0x5A827999 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    -- Round 2
    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 21 ) + 0x6ED9EBA1 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 22 ) + 0x6ED9EBA1 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 23 ) + 0x6ED9EBA1 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 24 ) + 0x6ED9EBA1 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 25 ) + 0x6ED9EBA1 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 26 ) + 0x6ED9EBA1 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 27 ) + 0x6ED9EBA1 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 28 ) + 0x6ED9EBA1 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 29 ) + 0x6ED9EBA1 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 30 ) + 0x6ED9EBA1 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 31 ) + 0x6ED9EBA1 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 32 ) + 0x6ED9EBA1 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 33 ) + 0x6ED9EBA1 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 34 ) + 0x6ED9EBA1 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 35 ) + 0x6ED9EBA1 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 36 ) + 0x6ED9EBA1 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 37 ) + 0x6ED9EBA1 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 38 ) + 0x6ED9EBA1 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 39 ) + 0x6ED9EBA1 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 40 ) + 0x6ED9EBA1 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    -- Round 3
    h5 = h5 + bit_bor( bit_band( bit_bor( h2, h3 ), h4 ), bit_band( h2, h3 ) ) + blk( block, 41 ) + 0x8F1BBCDC + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bor( bit_band( bit_bor( h1, h2 ), h3 ), bit_band( h1, h2 ) ) + blk( block, 42 ) + 0x8F1BBCDC + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bor( bit_band( bit_bor( h5, h1 ), h2 ), bit_band( h5, h1 ) ) + blk( block, 43 ) + 0x8F1BBCDC + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bor( bit_band( bit_bor( h4, h5 ), h1 ), bit_band( h4, h5 ) ) + blk( block, 44 ) + 0x8F1BBCDC + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bor( bit_band( bit_bor( h3, h4 ), h5 ), bit_band( h3, h4 ) ) + blk( block, 45 ) + 0x8F1BBCDC + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bor( bit_band( bit_bor( h2, h3 ), h4 ), bit_band( h2, h3 ) ) + blk( block, 46 ) + 0x8F1BBCDC + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bor( bit_band( bit_bor( h1, h2 ), h3 ), bit_band( h1, h2 ) ) + blk( block, 47 ) + 0x8F1BBCDC + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bor( bit_band( bit_bor( h5, h1 ), h2 ), bit_band( h5, h1 ) ) + blk( block, 48 ) + 0x8F1BBCDC + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bor( bit_band( bit_bor( h4, h5 ), h1 ), bit_band( h4, h5 ) ) + blk( block, 49 ) + 0x8F1BBCDC + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bor( bit_band( bit_bor( h3, h4 ), h5 ), bit_band( h3, h4 ) ) + blk( block, 50 ) + 0x8F1BBCDC + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bor( bit_band( bit_bor( h2, h3 ), h4 ), bit_band( h2, h3 ) ) + blk( block, 51 ) + 0x8F1BBCDC + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bor( bit_band( bit_bor( h1, h2 ), h3 ), bit_band( h1, h2 ) ) + blk( block, 52 ) + 0x8F1BBCDC + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bor( bit_band( bit_bor( h5, h1 ), h2 ), bit_band( h5, h1 ) ) + blk( block, 53 ) + 0x8F1BBCDC + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bor( bit_band( bit_bor( h4, h5 ), h1 ), bit_band( h4, h5 ) ) + blk( block, 54 ) + 0x8F1BBCDC + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bor( bit_band( bit_bor( h3, h4 ), h5 ), bit_band( h3, h4 ) ) + blk( block, 55 ) + 0x8F1BBCDC + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bor( bit_band( bit_bor( h2, h3 ), h4 ), bit_band( h2, h3 ) ) + blk( block, 56 ) + 0x8F1BBCDC + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bor( bit_band( bit_bor( h1, h2 ), h3 ), bit_band( h1, h2 ) ) + blk( block, 57 ) + 0x8F1BBCDC + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bor( bit_band( bit_bor( h5, h1 ), h2 ), bit_band( h5, h1 ) ) + blk( block, 58 ) + 0x8F1BBCDC + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bor( bit_band( bit_bor( h4, h5 ), h1 ), bit_band( h4, h5 ) ) + blk( block, 59 ) + 0x8F1BBCDC + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bor( bit_band( bit_bor( h3, h4 ), h5 ), bit_band( h3, h4 ) ) + blk( block, 60 ) + 0x8F1BBCDC + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    -- Round 4
    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 61 ) + 0xCA62C1D6 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 62 ) + 0xCA62C1D6 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 63 ) + 0xCA62C1D6 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 64 ) + 0xCA62C1D6 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 65 ) + 0xCA62C1D6 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 66 ) + 0xCA62C1D6 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 67 ) + 0xCA62C1D6 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 68 ) + 0xCA62C1D6 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 69 ) + 0xCA62C1D6 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 70 ) + 0xCA62C1D6 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 71 ) + 0xCA62C1D6 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 72 ) + 0xCA62C1D6 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 73 ) + 0xCA62C1D6 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 74 ) + 0xCA62C1D6 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 75 ) + 0xCA62C1D6 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    h5 = h5 + bit_bxor( h2, h3, h4 ) + blk( block, 76 ) + 0xCA62C1D6 + bit_lrotate( h1, 5 )
    h2 = bit_lrotate( h2, 30 )

    h4 = h4 + bit_bxor( h1, h2, h3 ) + blk( block, 77 ) + 0xCA62C1D6 + bit_lrotate( h5, 5 )
    h1 = bit_lrotate( h1, 30 )

    h3 = h3 + bit_bxor( h5, h1, h2 ) + blk( block, 78 ) + 0xCA62C1D6 + bit_lrotate( h4, 5 )
    h5 = bit_lrotate( h5, 30 )

    h2 = h2 + bit_bxor( h4, h5, h1 ) + blk( block, 79 ) + 0xCA62C1D6 + bit_lrotate( h3, 5 )
    h4 = bit_lrotate( h4, 30 )

    h1 = h1 + bit_bxor( h3, h4, h5 ) + blk( block, 80 ) + 0xCA62C1D6 + bit_lrotate( h2, 5 )
    h3 = bit_lrotate( h3, 30 )

    std.printf( "%x %x %x %x %x", h1, h2, h3, h4, h5 )

    return h1, h2, h3, h4, h5
    -- return h1 % 0xFFFFFFFF, h2 % 0xFFFFFFFF, h3 % 0xFFFFFFFF, h4 % 0xFFFFFFFF, h5 % 0xFFFFFFFF
end

function SHA1:reset()
    self.h1 = 0x67452301
    self.h2 = 0xefcdab89
    self.h3 = 0x98badcfe
    self.h4 = 0x10325476
    self.h5 = 0xc3d2e1f0

    self.message_length = 0
    -- self.message = ""

    self.position = 0
    self.buffer = {}
    return self
end

SHA1.__init = SHA1.reset

local bucket64 = math.bucketize( 64 )

local block_metatable = {
    __index = function( self, index )
        local uint8_1 = string_byte( self.data, index, index ) or 0x00
        self[ index ] = uint8_1
        return uint8_1
    end
}

function SHA1:update( data )
    local data_length = string_len( data )
    -- local message_length = self.message_length + str_length
    -- self.message_length = message_length

    -- if message_length < 64 then
    --     self.message = self.message .. str
    --     return self
    -- end

    -- local message, position, blocks_size = self.message .. str, self.position, bucket64( message_length )
    -- local a, b, c, d, e = self.a, self.b, self.c, self.d, self.e

    -- for index = position + 1, blocks_size, 64 do
    --     a, b, c, d, e = transform( { string_byte( message, index, index + 63 ) }, a, b, c, d, e )
    -- end

    -- self.a, self.b, self.c, self.d, self.e = a, b, c, d, e
    -- self.position = position + blocks_size
    -- self.message = message

    -- return self

    local i = 0

    local position = self.position
    local new_position = position + bit_lshift( data_length, 3 )
    self.position = new_position

    local message_length = self.message_length
    if new_position < position then
        message_length = message_length + 1
    end

    self.message_length = message_length + bit_rshift( data_length, 29 )

    position = bit_band( bit_rshift( position, 3 ), 63 )

    if (position + data_length) > 63 then
        local h1, h2, h3, h4, h5 = self.h1, self.h2, self.h3, self.h4, self.h5
        i = 64 - position

        local buffer = self.buffer

        for j = position + 1, 63, 1 do
            buffer[ j ] = string_byte( data, i )
            i = i + 1
        end

        -- memcpy(&context->buffer[j], data, (i = 64 - j));
        -- SHA1Transform(context->state, context->buffer);
        -- for (; i + 63 < len; i += 64)
        -- {
        --     SHA1Transform(context->state, &data[i]);
        -- }

        -- local block = setmetatable( {
        --     data_length = data_length,
        --     data = data
        -- }, block_metatable )

        h1, h2, h3, h4, h5 = transform( buffer, h1, h2, h3, h4, h5 )

        for j = i, data_length - 64, 64 do
            h1, h2, h3, h4, h5 = transform( { string_byte( data, j, j + 63 ) }, h1, h2, h3, h4, h5 )
        end

        self.h1, self.h2, self.h3, self.h4, self.h5 = h1, h2, h3, h4, h5

        position = 0
    else
        i = 0
    end

    local count = data_length - i

    -- for k = 1, count do
    --     buffer[ position + k ] = data[i + k]
    -- end

    -- memcpy( &context->buffer[ position ], &data[ i ], data_length - i )
end

-- abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopqaaadswed
-- abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq

function SHA1:digest( as_hex )
    local position = self.position
    local message_length = self.message_length
    local remaining = message_length - position
    local padding = 64 - (remaining + 9)

    local bit_count = message_length * 8

    if message_length > 0x20000000 then
        bit_count = bit_count % 0x100000000
    end

    local block = { string_byte( self.message, 1, -1 ) }
    table.insert( block, 128 )

    for i = 1, padding, 1 do
        table.insert( block, 0 )
    end

    local x1, x2, x3, x4 = bytepack_writeUInt32( math_floor( message_length * 8 ) )
    table.insert( block, x1 )
    table.insert( block, x2 )
    table.insert( block, x3 )
    table.insert( block, x4 )

    local x5, x6, x7, x8 = bytepack_writeUInt32( math_floor( message_length / 0x20000000 ) )
    table.insert( block, x5 )
    table.insert( block, x6 )
    table.insert( block, x7 )
    table.insert( block, x8 )

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

-- TODO: implement (example: md5)
local engine_SHA1 = dreamwork.engine.SHA1

if engine_SHA1 == nil then

    -- TODO: implement (example: md5)

else

    local base16_decode = std.base16.decode

    --- [SHARED AND MENU]
    ---
    --- Computes the SHA1 digest of the given input string.
    ---
    --- This static method takes a string and returns its SHA1 hash as a hexadecimal string.
    --- Commonly used for checksums, data integrity validation, and password hashing.
    ---
    ---@param message string The message to compute SHA1 for.
    ---@param as_hex? boolean If true, the result will be a hex string.
    ---@return string str_result The SHA1 string of the message.
    function SHA1Class.digest( message, as_hex )
        local hex_str = engine_SHA1( message )
        if as_hex then
            return hex_str
        else
            return base16_decode( hex_str )
        end
    end

end

-- local s = SHA1Class()

-- local str = "abc"

-- s:update( str )

-- transform( setmetatable( {}, { __index = function() return 0 end } ), 0, 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476 )

-- print( s:digest( true ) )

-- print( engine_SHA1( str ) )

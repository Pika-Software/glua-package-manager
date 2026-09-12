--- Based on https://github.com/nmap/nmap/blob/master/nselib/base32.lua

---@class dreamwork.std
local std = dreamwork.std

local raw = std.raw

local string = std.string
local string_len = string.len
local string_byte, string_char = string.byte, string.char

local table = std.table
local table_concat = table.concat

local rbit = raw.bit
local rbit_band, rbit_bor = rbit.band, rbit.bor
local rbit_lshift, rbit_rshift = rbit.lshift, rbit.rshift

local error = std.error


--- [SHARED AND MENU]
---
--- Base32 encoding/decoding library.
---
--- See https://en.wikipedia.org/wiki/Base32
---
---@class dreamwork.std.base32
local base32 = std.base32 or {}
std.base32 = base32

--- [SHARED AND MENU]
---
--- The base32 encoding/decoding alphabet.
---
---@class dreamwork.std.base32.Alphabet
---@field [1] table<integer, string> The encoding map.
---@field [2] table<integer, integer> The decoding map.

--- [SHARED AND MENU]
---
--- Creates a base32 alphabet with encoding and decoding maps.
---
---@param alphabet_str string The alphabet string.
---@return dreamwork.std.base32.Alphabet alphabet The alphabet.
function base32.alphabet( alphabet_str )
    if string_len( alphabet_str ) ~= 32 then
        error( "alphabet must be 32 characters long", 2 )
    end

    local bytes = { string_byte( alphabet_str, 1, 32 ) }

    ---@type table<integer, string>
    local encode_map = {}

    for i = 1, 32, 1 do
        encode_map[ i - 1 ] = string_char( bytes[ i ] )
    end

    ---@type table<integer, integer>
    local decode_map = {}

    for i = 1, 32, 1 do
        local uint8 = bytes[ i ]
        if decode_map[ uint8 ] == nil then
            decode_map[ uint8 ] = i - 1
        elseif uint8 > 32 and uint8 < 127 then
            error( "alphabet characters must be unique, duplicate character: '" .. string_char( uint8 ) .. "' [" .. i .. "]", 2 )
        else
            error( "alphabet characters must be unique, duplicate character: '\\" .. uint8 .. "' [" .. i .. "]", 2 )
        end
    end

    return { encode_map, decode_map }
end

local standard = base32.alphabet( "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567" )
local extended = base32.alphabet( "0123456789ABCDEFGHIJKLMNOPQRSTUV" )

---@param encode_map table<integer, string>
---@param segments string[]
---@param segment_count integer
---@param do_padding boolean
---@param uint8_1? integer
---@param uint8_2? integer
---@param uint8_3? integer
---@param uint8_4? integer
---@param uint8_5? integer
---@return integer
local function block_encode( encode_map, segments, segment_count, do_padding, uint8_1, uint8_2, uint8_3, uint8_4, uint8_5 )
    if uint8_1 == nil then
        return segment_count
    end

    segment_count = segment_count + 1
    segments[ segment_count ] = encode_map[ rbit_band( rbit_rshift( uint8_1, 3 ), 0x1f ) ]

    segment_count = segment_count + 1

    if uint8_2 == nil then
        segments[ segment_count ] = encode_map[ rbit_band( rbit_lshift( uint8_1, 2 ), 0x1f ) ]

        if do_padding then
            segment_count = segment_count + 1
            segments[ segment_count ] = "======"
        end

        return segment_count
    end

    segments[ segment_count ] = encode_map[ rbit_band( rbit_bor( rbit_band( rbit_lshift( uint8_1, 2 ), 0x1c ), rbit_band( rbit_rshift( uint8_2, 6 ), 0x03 ) ), 0x1f ) ]

    segment_count = segment_count + 1
    segments[ segment_count ] = encode_map[ rbit_band( rbit_rshift( uint8_2, 1 ), 0x1f ) ]

    segment_count = segment_count + 1

    if uint8_3 == nil then
        segments[ segment_count ] = encode_map[ rbit_band( rbit_lshift( uint8_2, 4 ), 0x1f ) ]

        if do_padding then
            segment_count = segment_count + 1
            segments[ segment_count ] = "===="
        end

        return segment_count
    end

    segments[ segment_count ] = encode_map[ rbit_band( rbit_bor( rbit_band( rbit_lshift( uint8_2, 4 ), 0x10 ), rbit_band( rbit_rshift( uint8_3, 4 ), 0x0f ) ), 0x1f ) ]

    segment_count = segment_count + 1

    if uint8_4 == nil then
        segments[ segment_count ] = encode_map[ rbit_band( rbit_lshift( uint8_3, 1 ), 0x1f ) ]

        if do_padding then
            segment_count = segment_count + 1
            segments[ segment_count ] = "==="
        end

        return segment_count
    end

    segments[ segment_count ] = encode_map[ rbit_band( rbit_bor( rbit_band( rbit_lshift( uint8_3, 1 ), 0x1e ), rbit_band( rbit_rshift( uint8_4, 7 ), 0x01 ) ), 0x1f ) ]

    segment_count = segment_count + 1
    segments[ segment_count ] = encode_map[ rbit_band( rbit_rshift( uint8_4, 2 ), 0x1f ) ]

    segment_count = segment_count + 1

    if uint8_5 == nil then
        segments[ segment_count ] = encode_map[ rbit_band( rbit_lshift( uint8_4, 3 ), 0x1f ) ]

        if do_padding then
            segment_count = segment_count + 1
            segments[ segment_count ] = "="
        end

        return segment_count
    end

    segments[ segment_count ] = encode_map[ rbit_band( rbit_bor( rbit_band( rbit_lshift( uint8_4, 3 ), 0x18 ), rbit_band( rbit_rshift( uint8_5, 5 ), 0x07 ) ), 0x1f ) ]

    segment_count = segment_count + 1
    segments[ segment_count ] = encode_map[ rbit_band( uint8_5, 0x1f ) ]

    return segment_count
end

--- [SHARED AND MENU]
---
--- Encodes the specified string to base32.
---
---@param raw_str string The string to encode.
---@param ignore_padding? boolean Whether to ignore padding.
---@param alphabet? "standard" | "extended" | dreamwork.std.base32.Alphabet The alphabet to use.
---@return string base32_str The encoded string.
function base32.encode( raw_str, ignore_padding, alphabet )
    local encode_map

    if alphabet == nil or alphabet == "standard" then
        encode_map = standard[ 1 ]
    elseif alphabet == "extended" then
        encode_map = extended[ 1 ]
    else
        encode_map = alphabet[ 1 ]
    end

    local raw_str_length = string_len( raw_str )

    local do_padding = ignore_padding ~= true
    local segments, segment_count = {}, 0
    local remainder = raw_str_length % 5

    for i = 1, raw_str_length - remainder, 5 do
        segment_count = block_encode( encode_map, segments, segment_count, do_padding, string_byte( raw_str, i, i + 4 ) )
    end

    if remainder ~= 0 then
        local index = raw_str_length - remainder
        segment_count = block_encode( encode_map, segments, segment_count, do_padding, string_byte( raw_str, index + 1, index + remainder ) )
    end

    return table_concat( segments, "", 1, segment_count )
end

---@param decode_map table<integer, integer>
---@param uint8_1? integer
---@param uint8_2? integer
---@param uint8_3? integer
---@param uint8_4? integer
---@param uint8_5? integer
---@param uint8_6? integer
---@param uint8_7? integer
---@param uint8_8? integer
---@return string
local function block_decode( decode_map, uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6, uint8_7, uint8_8 )
    if uint8_1 == nil then
        return ""
    end

    if uint8_2 == nil then
        return string_char(
            rbit_band( rbit_lshift( decode_map[ uint8_1 ], 3 ), 0xf8 )
        )
    end

    local a = rbit_bor( rbit_band( rbit_lshift( decode_map[ uint8_1 ], 3 ), 0xf8 ), rbit_band( rbit_rshift( decode_map[ uint8_2 ], 2 ), 0x07 ) )

    if uint8_3 == nil then
        return string_char( a,
            rbit_band( rbit_lshift( decode_map[ uint8_2 ], 6 ), 0xc0 )
        )
    end

    if uint8_4 == nil then
        return string_char( a,
            rbit_bor( rbit_band( rbit_lshift( decode_map[ uint8_2 ], 6 ), 0xc0 ), rbit_band( rbit_lshift( decode_map[ uint8_3 ], 1 ), 0x3e ) )
        )
    end

    local b = rbit_bor( rbit_band( rbit_lshift( decode_map[ uint8_2 ], 6 ), 0xc0 ), rbit_band( rbit_lshift( decode_map[ uint8_3 ], 1 ), 0x3e ), rbit_band( rbit_rshift( decode_map[ uint8_4 ], 4 ), 0x01 ) )

    if uint8_5 == nil then
        return string_char( a, b,
            rbit_band( rbit_lshift( decode_map[ uint8_4 ], 4 ), 0xf0 )
        )
    end

    local c = rbit_bor( rbit_band( rbit_lshift( decode_map[ uint8_4 ], 4 ), 0xf0 ), rbit_band( rbit_rshift( decode_map[ uint8_5 ], 1 ), 0x0f ) )

    if uint8_6 == nil then
        return string_char( a, b, c )
    end

    if uint8_7 == nil then
        return string_char( a, b, c,
            rbit_bor( rbit_band( rbit_lshift( decode_map[ uint8_5 ], 7 ), 0x80 ), rbit_band( rbit_lshift( decode_map[ uint8_6 ], 2 ), 0x7c ) )
        )
    end

    local d = rbit_bor( rbit_band( rbit_lshift( decode_map[ uint8_5 ], 7 ), 0x80 ), rbit_band( rbit_lshift( decode_map[ uint8_6 ], 2 ), 0x7c ), rbit_band( rbit_rshift( decode_map[ uint8_7 ], 3 ), 0x03 ) )

    if uint8_8 == nil then
        return string_char( a, b, c, d,
            rbit_band( rbit_lshift( decode_map[ uint8_7 ], 5 ), 0xe0 )
        )
    end

    return string_char( a, b, c, d,
        rbit_bor( rbit_band( rbit_lshift( decode_map[ uint8_7 ], 5 ), 0xe0 ), rbit_band( decode_map[ uint8_8 ], 0x1f ) )
    )
end

--- [SHARED AND MENU]
---
--- Decodes the specified base32 encoded string.
---
---@param base32_str string The base32 encoded string to decode.
---@param ignore_padding? boolean Whether to ignore padding.
---@param alphabet? "standard" | "extended" | dreamwork.std.base32.Alphabet The alphabet to use.
---@return string str_raw The decoded string.
function base32.decode( base32_str, ignore_padding, alphabet )
    local base32_str_length = string_len( base32_str )

    if ignore_padding ~= true then

        if base32_str_length % 8 ~= 0 then
            error( "base32_str length must be a multiple of 8", 2 )
        end

        local padding = 0

        while string_byte( base32_str, base32_str_length, base32_str_length ) == 0x3D --[[ "=" ]] do
            base32_str_length = base32_str_length - 1
            padding = padding + 1
        end

        if padding > 6 then
            error( "base32_str cannot have more than 6 padding characters", 2 )
        end

        if base32_str_length == 0 then
            error( "base32_str cannot be empty", 2 )
        end

    end

    local decode_map

    if alphabet == nil or alphabet == "standard" then
        decode_map = standard[ 2 ]
    elseif alphabet == "extended" then
        decode_map = extended[ 2 ]
    else
        decode_map = alphabet[ 2 ]
    end

    local remainder = base32_str_length % 8
    local segments, segment_count = {}, 0

    for i = 1, base32_str_length - remainder, 8 do
        segment_count = segment_count + 1
        segments[ segment_count ] = block_decode( decode_map, string_byte( base32_str, i, i + 7 ) )
    end

    if remainder ~= 0 then
        segment_count = segment_count + 1
        local index = base32_str_length - remainder
        segments[ segment_count ] = block_decode( decode_map, string_byte( base32_str, index + 1, index + remainder ) )
    end

    return table_concat( segments, "", 1, segment_count )
end

--- [SHARED AND MENU]
---
--- Checks if the specified base32 encoded string is valid.
---
---@param base32_str string The base32 encoded string to check.
---@param ignore_padding? boolean Whether to ignore padding.
---@param alphabet? "standard" | "extended" | dreamwork.std.base32.Alphabet The alphabet to use.
---@return boolean is_valid `true` if the base32 string is valid, `false` otherwise
---@return nil | string err_msg The error message.
function base32.validate( base32_str, ignore_padding, alphabet )
    local base32_str_length = string_len( base32_str )

    if ignore_padding ~= true then

        if base32_str_length % 8 ~= 0 then
            return false, "string length must be a multiple of 8"
        end

        local padding = 0

        while string_byte( base32_str, base32_str_length, base32_str_length ) == 0x3D --[[ "=" ]] do
            base32_str_length = base32_str_length - 1
            padding = padding + 1
        end

        if padding > 6 then
            return false, "string cannot have more than 6 padding characters"
        end

        if base32_str_length == 0 then
            return false, "string cannot be empty"
        end

    end

    local decode_map

    if alphabet == nil or alphabet == "standard" then
        decode_map = standard[ 2 ]
    elseif alphabet == "extended" then
        decode_map = extended[ 2 ]
    else
        decode_map = alphabet[ 2 ]
    end

    for index = 1, base32_str_length, 1 do
        if decode_map[ string_byte( base32_str, index, index ) or -1 ] == nil then
            return false, "string contains invalid characters"
        end
    end

    return true
end

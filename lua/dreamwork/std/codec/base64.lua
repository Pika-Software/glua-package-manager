---@class dreamwork.GModUtilLib
---@field Base64Encode fun( input_str: string, inline: true ): string
---@field Base64Decode fun( input_str: string ): string
---@diagnostic disable-next-line: undefined-global
local glua_util = util
local glue_encode = glua_util ~= nil and glua_util.Base64Encode
local glue_decode = glua_util ~= nil and glua_util.Base64Decode

---@class dreamwork.std
local std = dreamwork.std

local raw = std.raw

local math = std.math
local math_floor = math.floor

local table = std.table
local table_remove = table.remove
local table_concat = table.concat

local string = std.string
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

local rbit = raw.bit
local rbit_extract = rbit.extract

local error = std.error


--- [SHARED AND MENU]
---
--- Base64 encoding/decoding library.
---
--- Library references:
--- - [iskolbin/lbase64](https://github.com/iskolbin/lbase64)
--- - [ErnieE5/ee5_base64](https://github.com/ErnieE5/ee5_base64)
--- - [BaseSixtyFour](http://lua-users.org/wiki/BaseSixtyFour)
---
---@see https://en.wikipedia.org/wiki/Base64
---@class dreamwork.std.base64
local base64 = {}
std.base64 = base64

--- [SHARED AND MENU]
---
--- The base64 encoding/decoding alphabet.
---
---@class dreamwork.std.base64.Alphabet
---@field [1] table<integer, integer> The encoding map.
---@field [2] table<integer, integer> The decoding map.

--- [SHARED AND MENU]
---
--- Creates a base64 alphabet with encoding and decoding maps.
---
---@param alphabet_str string The alphabet string.
---@return dreamwork.std.base64.Alphabet alphabet The alphabet.
function base64.alphabet( alphabet_str )
    if string_len( alphabet_str ) ~= 64 then
        error( "alphabet must be 64 characters long", 2 )
    end

    local encode_map = { string_byte( alphabet_str, 1, 64 ) }
    encode_map[ 0 ] = table_remove( encode_map, 1 )

    local decode_map = {}

    for i = 0, 63, 1 do
        local uint8 = encode_map[ i ]
        if decode_map[ uint8 ] == nil then
            decode_map[ uint8 ] = i
        elseif uint8 > 32 and uint8 < 127 then
            error( "alphabet characters must be unique, duplicate character: '" .. string_char( uint8 ) .. "' [" .. (i + 1) .. "]", 2 )
        else
            error( "alphabet characters must be unique, duplicate character: '\\" .. uint8 .. "' [" .. (i + 1) .. "]", 2 )
        end
    end

    return { encode_map, decode_map }
end

local standard = base64.alphabet( "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" )
local urlsafe = base64.alphabet( "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_" )

--- [SHARED AND MENU]
---
--- Base64 encoding/decoding options variant.
---
---@class dreamwork.std.base64.Variant
---@field alphabet dreamwork.std.base64.Alphabet The 64-character alphabet used for encoding and decoding.
---@field pad string | nil Optional padding character (usually "="). When `nil`, padding is disabled.
---@field wrap integer | nil Optional line wrap length. If `nil`, no wrapping is applied.
---@field eol string | nil Optional end-of-line character(s) used if `wrap` is set (e.g., "\r\n").
---@field ignore_cache boolean | nil Whether to ignore the cache during decoding. Default is `false`.
---@field encode_cache table<integer, string> | nil A cache of encoded strings.
---@field decode_cache table<integer, string> | nil A cache of decoded strings.

---@type table<string, dreamwork.std.base64.Variant>
local variants = {
    standard = {
        alphabet = standard,
        pad = "="
    },

    urlsafe = {
        alphabet = urlsafe
    },

    mime = {
        alphabet = standard,
        pad = "=",
        wrap = 76,
        eol = "\r\n"
    }
}

variants.jwt = variants.urlsafe

--- [SHARED AND MENU]
---
--- Base64 encoding/decoding options.
---
---@class dreamwork.std.base64.Options : dreamwork.std.base64.Variant
---@field variant "standard" | "urlsafe" | "mime" | "jwt" | "custom" The base64 variant to use.
---@field alphabet dreamwork.std.base64.Alphabet | nil The 64-character alphabet used for encoding and decoding.

---@param options dreamwork.std.base64.Options
local function perform_options( options )
    local variant = options.variant or "standard"
    options.variant = nil

    if variant == "custom" then
        local variant_options = variants.standard
        options.alphabet = options.alphabet or variant_options.alphabet
        return
    end

    local variant_options = variants[ variant ]
    if variant_options == nil then
        error( "unknown base64 variant", 3 )
    end

    local alphabet = options.alphabet
    if alphabet == nil then
        options.alphabet = variant_options.alphabet
    end

    local pad = options.pad
    if pad == nil then
        options.pad = variant_options.pad
    elseif string_len( pad ) ~= 1 then
        error( "pad must be a single character", 3 )
    end

    local wrap = options.wrap
    if wrap == nil then
        options.wrap = variant_options.wrap
    end

    local eol = options.eol
    if eol == nil then
        options.eol = variant_options.eol or "\r\n"
    end

    local ignore_cache = options.ignore_cache
    if ignore_cache == nil then
        options.ignore_cache = variant_options.ignore_cache == true
    else
        options.ignore_cache = ignore_cache == true
    end
end

---@param encode_map table<integer, integer>
---@param do_cache boolean
---@param cache_map table<integer, string> | nil
---@param uint8_1 integer
---@param uint8_2 integer | nil
---@param uint8_3 integer | nil
---@return string
local function block_encode( encode_map, do_cache, cache_map, uint8_1, uint8_2, uint8_3 )
    local bit_sum

    if uint8_1 == nil then
        error( "block must have at least one byte", 2 )
    elseif uint8_2 == nil then
        bit_sum = uint8_1 * 0x10000
    elseif uint8_3 == nil then
        bit_sum = uint8_1 * 0x10000 + uint8_2 * 0x100
    else
        bit_sum = uint8_1 * 0x10000 + uint8_2 * 0x100 + uint8_3
    end

    local str_block

    if do_cache then
        ---@diagnostic disable-next-line: need-check-nil
        str_block = cache_map[ bit_sum ]
        if str_block ~= nil then
            return str_block
        end
    end

    if uint8_2 == nil then
        str_block = string_char(
            encode_map[ rbit_extract( bit_sum, 18, 6 ) ],
            encode_map[ rbit_extract( bit_sum, 12, 6 ) ]
        )
    elseif uint8_3 == nil then
        str_block = string_char(
            encode_map[ rbit_extract( bit_sum, 18, 6 ) ],
            encode_map[ rbit_extract( bit_sum, 12, 6 ) ],
            encode_map[ rbit_extract( bit_sum, 6, 6 ) ]
        )
    else
        str_block = string_char(
            encode_map[ rbit_extract( bit_sum, 18, 6 ) ],
            encode_map[ rbit_extract( bit_sum, 12, 6 ) ],
            encode_map[ rbit_extract( bit_sum, 6, 6 ) ],
            encode_map[ rbit_extract( bit_sum, 0, 6 ) ]
        )
    end

    if do_cache then
        cache_map[ bit_sum ] = str_block
    end

    return str_block
end

--- [SHARED AND MENU]
---
--- Encodes the specified string to base64.
---
---@param raw_str string The string to encode.
---@param options? dreamwork.std.base64.Options The base64 encoding options.
---@return string base64_str The encoded string.
function base64.encode( raw_str, options )
    if options == nil then
        if glue_encode == nil then
            ---@diagnostic disable-next-line: cast-local-type
            options = variants.standard
        else
            ---@diagnostic disable-next-line: need-check-nil
            return glue_encode( raw_str, true )
        end
    else
        perform_options( options )
    end

    local encode_map = options.alphabet[ 1 ]
    local do_cache = not options.ignore_cache
    local pad = options.pad

    local str_length = string_len( raw_str )
    local remainder = str_length % 3

    ---@type string[]
    local blocks = {}

    ---@type integer
    local block_count = 0

    local cache_map

    if do_cache then
        cache_map = options.encode_cache or {}
    end

    for i = 1, str_length - remainder, 3 do
        block_count = block_count + 1
        blocks[ block_count ] = block_encode( encode_map, do_cache, cache_map, string_byte( raw_str, i, i + 2 ) )
    end

    if remainder == 2 then
        local str_block = block_encode( encode_map, do_cache, cache_map, string_byte( raw_str, str_length - 1, str_length ) )

        if pad ~= nil then
            str_block = str_block .. pad
        end

        block_count = block_count + 1
        blocks[ block_count ] = str_block
    elseif remainder == 1 then
        local str_block = block_encode( encode_map, do_cache, cache_map, string_byte( raw_str, str_length ) )

        if pad ~= nil then
            str_block = str_block .. pad .. pad
        end

        block_count = block_count + 1
        blocks[ block_count ] = str_block
    end

    local str_base64 = table_concat( blocks, "", 1, block_count )

    local wrap = options.wrap
    if wrap and wrap > 0 then
        local cursor, str_base64_length = 0, string_len( str_base64 )
        local segments, segment_count = {}, 0

        while cursor < str_base64_length do
            segment_count = segment_count + 1
            segments[ segment_count ] = string_sub( str_base64, cursor + 1, cursor + wrap )
            cursor = cursor + wrap
        end

        return table_concat( segments, options.eol, 1, segment_count )
    end

    return str_base64
end

---@param decode_map table<integer, integer>
---@param cache_map table<integer, string> | nil
---@param uint8_1 integer
---@param uint8_2 integer
---@param uint8_3 integer | nil
---@param uint8_4 integer | nil
---@return string
local function block_decode( decode_map, cache_map, uint8_1, uint8_2, uint8_3, uint8_4 )
    if cache_map == nil then
        if uint8_3 == nil then
            return string_char(
                rbit_extract(
                    (decode_map[ uint8_1 ] * 0x40000) +
                    (decode_map[ uint8_2 ] * 0x1000),
                    16, 8 )
            )
        end

        if uint8_4 == nil then
            local bit_sum = (decode_map[ uint8_1 ] * 0x40000) +
                (decode_map[ uint8_2 ] * 0x1000) +
                (decode_map[ uint8_3 ] * 0x40)

            return string_char(
                rbit_extract( bit_sum, 16, 8 ),
                rbit_extract( bit_sum, 8, 8 )
            )
        end

        local bit_sum = (decode_map[ uint8_1 ] * 0x40000) +
            (decode_map[ uint8_2 ] * 0x1000) +
            (decode_map[ uint8_3 ] * 0x40) +
            decode_map[ uint8_4 ]

        return string_char(
            rbit_extract( bit_sum, 16, 8 ),
            rbit_extract( bit_sum, 8, 8 ),
            rbit_extract( bit_sum, 0, 8 )
        )
    end

    local cache_key

    if uint8_1 == nil then
        error( "block must have at least one byte", 2 )
    elseif uint8_3 == nil then
        cache_key = (uint8_1 * 0x1000000) + (uint8_2 * 0x10000)
    elseif uint8_4 == nil then
        cache_key = (uint8_1 * 0x1000000) + (uint8_2 * 0x10000) + (uint8_3 * 0x100)
    else
        cache_key = (uint8_1 * 0x1000000) + (uint8_2 * 0x10000) + (uint8_3 * 0x100) + uint8_4
    end

    local str_block = cache_map[ cache_key ]
    if str_block ~= nil then
        return str_block
    end

    str_block = block_decode( decode_map, nil, uint8_1, uint8_2, uint8_3, uint8_4 )
    cache_map[ cache_key ] = str_block
    return str_block
end

--- [SHARED AND MENU]
---
--- Decodes the specified base64 encoded string.
---
---@param base64_str string The base64 encoded string to decode.
---@param options? dreamwork.std.base64.Options The base64 encoding options.
---@return string str_raw The decoded string.
function base64.decode( base64_str, options )
    if options == nil then
        if glue_decode == nil then
            ---@diagnostic disable-next-line: cast-local-type
            options = variants.standard
        else
            ---@diagnostic disable-next-line: need-check-nil
            return glue_decode( base64_str )
        end
    else
        perform_options( options )
    end

    local base_str_length = string_len( base64_str )

    ---@type integer
    local remainder

    local str_pad = options.pad
    if str_pad == nil then
        remainder = 0
    else

        local uint8_3, uint8_4 = string_byte( base64_str, base_str_length - 1, base_str_length )
        local pad_byte = string_byte( str_pad, 1, 1 )

        if uint8_3 == pad_byte and uint8_4 == pad_byte then
            base_str_length = base_str_length - 4
            remainder = 2
        elseif uint8_4 == pad_byte then
            base_str_length = base_str_length - 4
            remainder = 1
        else
            remainder = 0
        end

    end

    ---@type string[]
    local blocks = {}

    ---@type integer
    local block_count = 0

    local decode_map = options.alphabet[ 2 ]
    local cache_map

    if not options.ignore_cache then
        cache_map = options.decode_cache or {}
    end

    for i = 1, base_str_length, 4 do
        block_count = block_count + 1
        blocks[ block_count ] = block_decode( decode_map, cache_map, string_byte( base64_str, i, i + 3 ) )
    end

    if remainder ~= 0 then
        block_count = block_count + 1
        blocks[ block_count ] = block_decode( decode_map, cache_map, string_byte( base64_str, base_str_length - 3, base_str_length - remainder ) )
    end

    return table_concat( blocks, "", 1, block_count )
end

--- [SHARED AND MENU]
---
--- Checks if the specified base64 encoded string is valid.
---
---@param base64_str string The base64 encoded string to check.
---@param options? dreamwork.std.base64.Options The base64 encoding options.
---@return boolean is_valid `true` if the base64 string is valid, `false` otherwise
---@return nil | string err_msg The error message.
function base64.validate( base64_str, options )
    if options == nil then
        ---@diagnostic disable-next-line: cast-local-type
        options = variants.standard
    else
        perform_options( options )
    end

    local base_str_length = string_len( base64_str )

    local wrap = options.wrap
    if wrap ~= nil and wrap > 0 then
        local eol = options.eol
        if eol ~= nil then
            local eol_length = string_len( eol )

            local buffer_str = base64_str
            base64_str = ""

            local step_size = wrap + eol_length

            for i = wrap, base_str_length, step_size do
                if string_sub( buffer_str, i + 1, i + eol_length ) == eol then
                    local next_cursor = i + step_size
                    if next_cursor > base_str_length then
                        base64_str = base64_str .. string_sub( buffer_str, i - wrap + 1, i ) .. string_sub( buffer_str, i + eol_length + 1, base_str_length )
                    else
                        base64_str = base64_str .. string_sub( buffer_str, i - wrap + 1, i )
                    end
                else
                    return false, "invalid string eol"
                end
            end

            base_str_length = base_str_length - step_size * math_floor( base_str_length / step_size )
        end
    end

    if base_str_length % 4 ~= 0 then
        return false, "invalid string length"
    end

    local pad_byte

    local pad = options.pad
    if pad == nil then
        pad_byte = -1
    else
        pad_byte = string_byte( pad, 1, 1 )
    end

    local alphabet = options.alphabet[ 2 ]

    for start_position = 1, base_str_length, 4 do
        local end_position = start_position + 3
        local uint8_1, uint8_2, uint8_3, uint8_4 = string_byte( base64_str, start_position, end_position )

        if not (alphabet[ uint8_1 ] and alphabet[ uint8_2 ]) then
            return false, "string contains invalid characters"
        end

        if end_position == base_str_length then
            if not ((alphabet[ uint8_3 ] or uint8_3 == pad_byte) and (alphabet[ uint8_4 ] or uint8_4 == pad_byte)) then
                return false, "string contains invalid characters"
            end
        elseif not (alphabet[ uint8_3 ] and alphabet[ uint8_4 ]) then
            return false, "string contains invalid characters"
        end
    end

    return true
end

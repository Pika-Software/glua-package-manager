local std = dreamwork.std

local raw = std.raw

local rbit = raw.bit
local rbit_bxor = rbit.bxor
local rbit_lshift = rbit.lshift

local math = std.math
local math_min = math.min
local math_relative = math.relative

local table = std.table
local table_concat = table.concat

---@class dreamwork.std.string
local string = std.string
local string_sub = string.sub
local string_len = string.len
local string_char = string.char
local string_byte = string.byte

local bytepack = std.bytepack
local bytepack_readHex8 = bytepack.readHex8
local bytepack_writeHex8 = bytepack.writeHex8

do

    ---@type table<integer, string>
    local escape_sequences = {
        [ 0x5C ] = "\\\\",
        [ 0x07 ] = "\\a",
        [ 0x08 ] = "\\b",
        [ 0x0C ] = "\\f",
        [ 0x0A ] = "\\n",
        [ 0x0D ] = "\\r",
        [ 0x09 ] = "\\t",
        [ 0x0B ] = "\\v",
        [ 0x22 ] = "\\\"",
        [ 0x27 ] = "\\\'"
    }

    --- [SHARED AND MENU]
    ---
    --- Escapes special characters in a string.
    ---
    ---@param str string The string to escape.
    ---@param start_position? integer The start index.
    ---@param end_position? integer The end index.
    ---@param encode_spaces? boolean Whether to encode spaces.
    ---@return string escaped_str The escaped string.
    function string.escape( str, start_position, end_position, encode_spaces )
        ---@type integer
        local str_length = string_len( str )

        if str_length == 0 then
            return str
        end

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

        local sequence_position = start_position
        local segments, segment_count = {}, 0

        local in_range = encode_spaces and 0x21 or 0x20

        for index = start_position, end_position, 1 do
            local uint8 = string_byte( str, index, index )
            local escape_sequence = escape_sequences[ uint8 ]
            if escape_sequence ~= nil then
                segment_count = segment_count + 1
                segments[ segment_count ] = string_sub( str, sequence_position, index - 1 ) .. escape_sequence
                sequence_position = index + 1
            elseif uint8 < in_range or uint8 > 0x7F then
                segment_count = segment_count + 1
                segments[ segment_count ] = string_sub( str, sequence_position, index - 1 ) .. string_char( 0x5C, 0x78, bytepack_writeHex8( uint8 ) )
                sequence_position = index + 1
            end
        end

        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, sequence_position, end_position )

        return table_concat( segments, "", 1, segment_count )
    end

end

do

    ---@type table<integer, string>
    local unescape_sequences = {
        [ 0x5C ] = "\\",
        [ 0x61 ] = "\a",
        [ 0x62 ] = "\b",
        [ 0x66 ] = "\f",
        [ 0x6E ] = "\n",
        [ 0x72 ] = "\r",
        [ 0x74 ] = "\t",
        [ 0x76 ] = "\v",
        [ 0x22 ] = "\"",
        [ 0x27 ] = "\'"
    }

    --- [SHARED AND MENU]
    ---
    --- Unescapes special characters in a string.
    ---
    ---@param escaped_str string The string to unescape.
    ---@param start_position? integer The start index.
    ---@param end_position? integer The end index.
    ---@return string str The unescaped string.
    function string.unescape( escaped_str, start_position, end_position )
        ---@type integer
        local str_length = string_len( escaped_str )

        if str_length == 0 then
            return escaped_str
        end

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

        local segments, segment_count = {}, 0

        while true do
            local uint8_1 = string_byte( escaped_str, start_position, start_position )
            if uint8_1 == nil then
                break
            end

            segment_count = segment_count + 1

            if uint8_1 == 0x5C --[[ "\" ]] then
                start_position = start_position + 1

                local uint8_2 = string_byte( escaped_str, start_position, start_position )
                if uint8_2 == nil then
                    segments[ segment_count ] = string_char( uint8_1 )
                    break
                elseif uint8_2 == 0x78 --[[ "x" ]] then
                    start_position = start_position + 1

                    local uint8_3, uint8_4 = string_byte( escaped_str, start_position, start_position + 1 )
                    if uint8_3 == nil then
                        segments[ segment_count ] = string_char( uint8_1, uint8_2 )
                        break
                    elseif uint8_4 == nil then
                        segments[ segment_count ] = string_char( uint8_1, uint8_2, uint8_3 )
                        break
                    end

                    start_position = start_position + 1

                    local decoded_uint8 = bytepack_readHex8( uint8_3, uint8_4 )
                    if decoded_uint8 == nil then
                        segments[ segment_count ] = string_char( uint8_1, uint8_2, uint8_3, uint8_4 )
                    else
                        segments[ segment_count ] = string_char( decoded_uint8 )
                    end
                else
                    local unescape_sequence = unescape_sequences[ uint8_2 ]
                    if unescape_sequence == nil then
                        segments[ segment_count ] = string_char( uint8_1, uint8_2 )
                    else
                        segments[ segment_count ] = unescape_sequence
                    end
                end
            else
                segments[ segment_count ] = string_char( uint8_1 )
            end

            if start_position == end_position then
                break
            else
                start_position = start_position + 1
            end
        end

        if segment_count == 0 then
            return ""
        elseif segment_count == 1 then
            return segments[ 1 ]
        else
            return table_concat( segments, "", 1, segment_count )
        end
    end

end


--- [SHARED AND MENU]
---
--- Returns the Fowler-Noll-Vo (FNV-0) [deprecated] hash of the string.
---
--- [Wiki Page](https://en.wikipedia.org/wiki/Fowler–Noll–Vo_hash_function)
---
---@param str string The string used to calculate the Fowler-Noll-Vo hash.
---@return integer hash_int The Fowler-Noll-Vo hash, which is greater or equal to 0, and less than 2^32 (0x100000000).
function string.fnv0( str )
    local hash_int = 0

    for index = 1, string_len( str ), 1 do
        hash_int = hash_int + rbit_lshift( hash_int, 1 ) + rbit_lshift( hash_int, 4 ) + rbit_lshift( hash_int, 7 ) + rbit_lshift( hash_int, 8 ) + rbit_lshift( hash_int, 24 )
        hash_int = rbit_bxor( hash_int, string_byte( str, index, index ) )
    end

    return hash_int % 0xFFFFFFFF
end

--- [SHARED AND MENU]
---
--- Returns the Fowler-Noll-Vo (FNV-1) hash of the string.
---
--- [Wiki Page](https://en.wikipedia.org/wiki/Fowler–Noll–Vo_hash_function)
---
---@param str string The string used to calculate the Fowler-Noll-Vo hash.
---@return integer hash_int The Fowler-Noll-Vo hash, which is greater or equal to 0, and less than 2^32 (0x100000000).
function string.fnv1( str )
    local hash_int = 0x811c9dc5

    for index = 1, string_len( str ), 1 do
        hash_int = hash_int + rbit_lshift( hash_int, 1 ) + rbit_lshift( hash_int, 4 ) + rbit_lshift( hash_int, 7 ) + rbit_lshift( hash_int, 8 ) + rbit_lshift( hash_int, 24 )
        hash_int = rbit_bxor( hash_int, string_byte( str, index, index ) )
    end

    return hash_int % 0xFFFFFFFF
end

--- [SHARED AND MENU]
---
--- Returns the Fowler-Noll-Vo (FNV-1a) hash of the string.
---
--- [Wiki Page](https://en.wikipedia.org/wiki/Fowler–Noll–Vo_hash_function)
---
---@param str string The string used to calculate the Fowler-Noll-Vo hash.
---@return integer hash_int The Fowler-Noll-Vo hash, which is greater or equal to 0, and less than 2^32 (0x100000000).
function string.fnv1a( str )
    local hash_int = 0x811c9dc5

    for index = 1, string_len( str ), 1 do
        hash_int = rbit_bxor( hash_int, string_byte( str, index, index ) )
        hash_int = hash_int + rbit_lshift( hash_int, 1 ) + rbit_lshift( hash_int, 4 ) + rbit_lshift( hash_int, 7 ) + rbit_lshift( hash_int, 8 ) + rbit_lshift( hash_int, 24 )
    end

    return hash_int % 0xFFFFFFFF
end

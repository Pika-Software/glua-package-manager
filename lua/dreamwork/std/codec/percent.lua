---@class dreamwork.std
local std = dreamwork.std

local bytepack = std.bytepack
local bytepack_readHex8 = bytepack.readHex8
local bytepack_writeHex8 = bytepack.writeHex8

local math = std.math
local math_min = math.min

local string = std.string
local string_len = string.len
local string_char, string_byte = string.char, string.byte

local table = std.table
local table_concat = table.concat

--- [SHARED AND MENU]
---
--- Percent (URL/URI) encoding/decoding library.
---
--- Percent-encoding is a mechanism to encode 8-bit characters that have specific meaning in the context of URLs.
---
--- It is sometimes called **URL encoding**.
---
--- The encoding consists of substitution: A '%' followed by the hexadecimal representation of the ASCII value of the replace character.
---
--- See https://en.wikipedia.org/wiki/Percent-encoding & https://datatracker.ietf.org/doc/html/rfc3986#section-2.1
---
---@class dreamwork.std.percent
local percent = {}
std.percent = percent

--- [SHARED AND MENU]
---
--- Creates a character whitelist for the given pattern.
---
---@param pattern_str string The pattern.
---@param base? table The base table, optional.
---@return table whitelist The character whitelist.
function percent.whitelist( pattern_str, base )
    local whitelist = {}

    if base ~= nil then
        for uint8 in std.raw.pairs( base ) do
            whitelist[ uint8 ] = true
        end
    end

    pattern_str = "[" .. pattern_str .. "]"

    for uint8 = 0, 255, 1 do
        local char_str = string_char( uint8 )
        if string.match( char_str, pattern_str ) then
            whitelist[ uint8 ] = true
        end
    end

    return whitelist
end

do

    local default_whitelist = percent.whitelist( "%w%-_%.~" )

    --- [SHARED AND MENU]
    ---
    --- Encodes the specified string to percent encoding.
    ---
    ---@param raw_str string The string to encode.
    ---@param whitelist? table The character whitelist, optional.
    ---@param ignore_spaces? boolean Ignore spaces, optional.
    ---@return string percent_str The encoded string.
    function percent.encode( raw_str, whitelist, ignore_spaces )
        local segments, segment_count = {}, 0

        if whitelist == nil then
            whitelist = default_whitelist
        end

        ignore_spaces = ignore_spaces ~= true

        local uint8_last

        for i = 1, string_len( raw_str ), 1 do
            local uint8 = string_byte( raw_str, i, i )

            if whitelist[ uint8 ] then
                segment_count = segment_count + 1
                segments[ segment_count ] = string_char( uint8 )
            elseif uint8 == 0x0A --[[ "\n" ]] and uint8_last ~= 0x0D --[[ "\r" ]] then
                segment_count = segment_count + 1
                segments[ segment_count ] = "%0D%0A"
            elseif ignore_spaces and uint8 == 0x20 --[[ " " ]] then
                segment_count = segment_count + 1
                segments[ segment_count ] = "+"
            else
                segment_count = segment_count + 1
                segments[ segment_count ] = string_char( 0x25 --[[ "%" ]], bytepack_writeHex8( uint8 ) )
            end

            uint8_last = uint8
        end

        return table_concat( segments, "", 1, segment_count )
    end

    do

        ---@type table<integer, boolean>
        local hex_bytes = {
            [ 0x30 --[[ "0" ]] ] = true,
            [ 0x31 --[[ "1" ]] ] = true,
            [ 0x32 --[[ "2" ]] ] = true,
            [ 0x33 --[[ "3" ]] ] = true,
            [ 0x34 --[[ "4" ]] ] = true,
            [ 0x35 --[[ "5" ]] ] = true,
            [ 0x36 --[[ "6" ]] ] = true,
            [ 0x37 --[[ "7" ]] ] = true,
            [ 0x38 --[[ "8" ]] ] = true,
            [ 0x39 --[[ "9" ]] ] = true,
            [ 0x41 --[[ "A" ]] ] = true,
            [ 0x42 --[[ "B" ]] ] = true,
            [ 0x43 --[[ "C" ]] ] = true,
            [ 0x44 --[[ "D" ]] ] = true,
            [ 0x45 --[[ "E" ]] ] = true,
            [ 0x46 --[[ "F" ]] ] = true,
            [ 0x61 --[[ "a" ]] ] = true,
            [ 0x62 --[[ "b" ]] ] = true,
            [ 0x63 --[[ "c" ]] ] = true,
            [ 0x64 --[[ "d" ]] ] = true,
            [ 0x65 --[[ "e" ]] ] = true,
            [ 0x66 --[[ "f" ]] ] = true
        }

        --- [SHARED AND MENU]
        ---
        --- Validates the specified percent string.
        ---
        ---@param percent_str string The percent string to validate.
        ---@param whitelist? table The character whitelist, optional.
        ---@param ignore_spaces? boolean Ignore spaces, optional.
        ---@param percent_str_length? integer The length of the string. Optionally, it should be used to speed up calculations.
        ---@return boolean is_valid `true` if the percent string is valid, otherwise `false`.
        ---@return nil | string err_msg The error message.
        function percent.validate( percent_str, whitelist, ignore_spaces, percent_str_length )
            if whitelist == nil then
                whitelist = default_whitelist
            end

            ignore_spaces = ignore_spaces ~= true

            if percent_str_length == nil then
                percent_str_length = string_len( percent_str )
            end

            percent_str_length = percent_str_length + 1

            local position = 1

            while position ~= percent_str_length do
                local uint8_0 = string_byte( percent_str, position, position )
                if uint8_0 == 0x25 --[[ "%" ]] then
                    local uint8_1, uint8_2 = string_byte( percent_str, position + 1, position + 2 )
                    if hex_bytes[ uint8_1 ] == nil or hex_bytes[ uint8_2 ] == nil then
                        return false, "string contains invalid characters"
                    end

                    position = math_min( position + 3, percent_str_length )
                elseif (ignore_spaces and uint8_0 == 0x2B --[[ "+" ]]) or whitelist[ uint8_0 ] ~= nil then
                    position = position + 1
                else
                    return false, "string contains invalid characters"
                end
            end

            return true
        end

    end

end

--- [SHARED AND MENU]
---
--- Decodes the specified string from percent encoding.
---
---@param percent_str string The string to decode.
---@param ignore_spaces? boolean Ignore spaces, optional.
---@param percent_str_length? integer The length of the string. Optionally, it should be used to speed up calculations.
---@return string raw_str The decoded string.
function percent.decode( percent_str, ignore_spaces, percent_str_length )
    ignore_spaces = ignore_spaces ~= true

    if percent_str_length == nil then
        percent_str_length = string_len( percent_str )
    end

    local segments, segment_count = {}, 0
    local position = 1

    while position ~= percent_str_length do
        local uint8_1 = string_byte( percent_str, position, position )
        if uint8_1 == 0x25 --[[ "%" ]] then
            segment_count = segment_count + 1

            local uint8_2, uint8_3 = string_byte( percent_str, position + 1, position + 2 )

            local decoded_uint8 = bytepack_readHex8( uint8_2, uint8_3 )
            if decoded_uint8 == nil then
                segments[ segment_count ] = string_char( uint8_1, uint8_2, uint8_3 )
            else
                segments[ segment_count ] = string_char( decoded_uint8 )
            end

            position = math_min( position + 3, percent_str_length )
        elseif uint8_1 == 0x2B --[[ "+" ]] and not ignore_spaces then
            segment_count = segment_count + 1
            segments[ segment_count ] = "\32"
            position = position + 1
        else
            segment_count = segment_count + 1
            segments[ segment_count ] = string_char( uint8_1 )
            position = position + 1
        end
    end

    return table_concat( segments, "", 1, segment_count )
end

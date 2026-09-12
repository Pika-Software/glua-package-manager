local glua_string = _G.string

---@class dreamwork.std
local std = dreamwork.std

local ascii = std.ascii
local ascii_isSpace = ascii.isSpace

local len = std.len
local isTable = std.isTable
local represent = std.represent

local raw = std.raw
local raw_tonumber = raw.tonumber

local math = std.math
local math_abs = math.abs
local math_floor = math.floor
local math_random = math.random
local math_relative = math.relative
local math_min, math_max = math.min, math.max

local table = std.table
local table_unpack = table.unpack
local table_concat = table.concat

--- [SHARED AND MENU]
---
--- The string type is a sequence of characters.
---
--- The string library is a standard Lua library which provides functions for the manipulation of strings.
---
--- In dreamwork string library contains additional functions.
---
---@class dreamwork.std.string
---@field PatternBytes table<integer, string>
local string = {
    byte = glua_string.byte,
    char = glua_string.char,
    dump = glua_string.dump,
    find = glua_string.find,
    format = glua_string.format,
    ---@diagnostic disable-next-line: deprecated, undefined-field
    gmatch = glua_string.gmatch or glua_string.gfind,
    gsub = glua_string.gsub,
    len = glua_string.len,
    lower = glua_string.lower,
    match = glua_string.match,
    rep = glua_string.rep,
    reverse = glua_string.reverse,
    sub = glua_string.sub,
    upper = glua_string.upper,

    --- A table of bytes that map to pattern sequences.
    PatternBytes = {
        -- ()
        [ 0x28 ] = "%(",
        [ 0x29 ] = "%)",

        -- []
        [ 0x5B ] = "%[",
        [ 0x5D ] = "%]",

        -- .
        [ 0x2E ] = "%.",

        -- %
        [ 0x25 ] = "%%",

        -- +-
        [ 0x2B ] = "%+",
        [ 0x2D ] = "%-",

        -- *
        [ 0x2A ] = "%*",

        -- ?
        [ 0x3F ] = "%?",

        -- ^
        [ 0x5E ] = "%^",

        -- $
        [ 0x24 ] = "%$"
    }
}

std.string = string

local string_sub, string_rep, string_len = string.sub, string.rep, string.len
local string_match, string_find = string.match, string.find
local string_char, string_byte = string.char, string.byte

local pattern_bytes = string.PatternBytes

---@class dreamwork.std.string.ByteMapRange
---@field leading_byte string The start byte of the range.
---@field trailing_byte string The end byte of the range.
---@field step_size integer? The step size for the range.

--- [SHARED AND MENU]
---
--- Creates a byte map from the given strings or byte ranges.
---
---@param ... string | dreamwork.std.string.ByteMapRange A list of bytes or byte ranges to include in the map.
---@return table<integer, boolean> The byte map.
function string.byteMap( ... )
    ---@type table<integer, boolean>
    local byte_map = {}

    for i = 1, select( "#", ... ), 1 do
        local value = select( i, ... )

        if isTable( value ) then
            for j = string_byte( value.leading_byte ), string_byte( value.trailing_byte ), (value.step_size or 1) do
                byte_map[ j ] = true
            end
        else
            byte_map[ string_byte( value, 1, 1 ) ] = true
        end
    end

    return byte_map
end

--- [SHARED AND MENU]
---
--- Finds the first byte of the given byte in the string.
---
---@param str string The string to search in.
---@param searchable_byte integer The byte to search for.
---@param start_position? integer The start position of the search.
---@param end_position? integer The end position of the search.
---@return integer | nil index The index of the byte if found, `nil` otherwise.
function string.findByte( str, searchable_byte, start_position, end_position )
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

    for index = start_position, end_position, 1 do
        if string_byte( str, index, index ) == searchable_byte then
            return index
        end
    end

    return nil
end

--- [SHARED AND MENU]
---
--- Checks if the string is empty.
---
---@param str string The string to check.
---@return boolean result True if the string is empty.
function string.isEmpty( str )
    return string_byte( str, 1, 1 ) == nil
end

--- [SHARED AND MENU]
---
--- Splits the string into segments of the specified size.
---
---@param str string The string to split.
---@param size? integer The size of the segments.
---@return string[] segments The array of segments.
---@return integer segment_count The number of segments.
function string.divide( str, size )
    local str_length = string_len( str )

    if size == nil then
        size = 1
    else
        size = math_max( math_min( size, str_length ), 1 )
    end

    local segments, segment_count = {}, 0
    size = size - 1

    for index = 1, str_length, size + 1 do
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, index, math_min( index + size, str_length ) )
    end

    return segments, segment_count
end

--- [SHARED AND MENU]
---
--- Extracts a string from the other string.
---
---@param str             string       The string to extract from.
---@param searchable      string       The pattern or searchable to extract by.
---@param start_position? integer      The start position to extract from.
---@param default?        string | nil The default string that is returned if no matches are found.
---@param with_pattern?   boolean      When `true`, `searchable` is interpreted as a Lua pattern. Defaults to `false` (plain match).
---@return string new_string The new string without the extracted string.
---@return string | nil extracted The extracted string, otherwise the default string.
function string.extract( str, searchable, start_position, default, with_pattern )
    local extraction_start, extraction_end, str_matched = string_find( str, searchable, start_position or 1, with_pattern ~= true )
    if extraction_start == nil then
        return str, default
    end

    return string_sub( str, 1, extraction_start - 1 ) .. string_sub( str, extraction_end + 1 ), str_matched or default
end

--- [SHARED AND MENU]
---
--- Inserts a value into the string.
---
---@param str string
---@param index integer The string insertion index.
---@param value string The string value to insert.
---@return string result
---@overload fun( str: string, value: string ): string
function string.insert( str, index, value )
    if value == nil then
        return str .. index
    end

    local str_length = string_len( str )

    if index == nil then
        index = str_length + 1
    elseif index < 0 then
        index = math_relative( index, str_length )
    else
        index = math_min( index, str_length + 1 )
    end

    if index == 0 then
        return value .. str
    elseif index == (str_length + 1) then
        return str .. value
    end

    return string_sub( str, 1, index - 1 ) .. value .. string_sub( str, index, str_length )
end

--- [SHARED AND MENU]
---
--- Removes the specified interval from the string.
---
---@param str string The string to remove from.
---@param start_position integer The start position of the removal interval.
---@param end_position integer The end position of the removal interval.
---@return string new_string A string without a specified byte interval.
function string.remove( str, start_position, end_position )
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

    if start_position == 1 and end_position == str_length then
        return ""
    end

    return string_sub( str, 1, start_position - 1 ) .. string_sub( str, end_position + 1, str_length )
end

--- [SHARED AND MENU]
---
--- Checks if the string starts with the prefix.
---
---@param str string The string to check.
---@param prefix string The prefix to check for.
---@param prefix_length? integer The length of the prefix to check for. Optionally, it should be used to speed up calculations.
---@param start_position? integer The position to start checking from. Optionally, it should be used to speed up calculations.
---@return boolean has_prefix `true` if the string starts with the prefix, `false` otherwise.
function string.hasPrefix( str, prefix, prefix_length, start_position )
    return str == prefix or string_sub( str, (start_position or 1), prefix_length or string_len( prefix ) ) == prefix
end

--- [SHARED AND MENU]
---
--- Checks if the string ends with the suffix.
---
---@param str string The string to check.
---@param suffix string The suffix to check for.
---@return boolean has_suffix `true` if the string ends with the suffix, `false` otherwise.
function string.hasSuffix( str, suffix )
    return string_byte( suffix, 1, 1 ) == nil or -- suffix is empty
        str == suffix or                         -- suffix is the same as the string
        string_sub( str, -string_len( suffix ), string_len( str ) ) == suffix
end

--- [SHARED AND MENU]
---
--- Checks if the string contains the searchable string.
---
---@param str           string  The string to search in.
---@param searchable    string  The substring or pattern to search for.
---@param position?     integer The position to start from.
---@param with_pattern? boolean When `true`, `searchable` is interpreted as a Lua pattern. Defaults to `false` (plain match).
---@return integer index The index of the searchable string, otherwise `-1`.
function string.indexOf( str, searchable, position, with_pattern )
    if searchable == nil or string_byte( searchable, 1, 1 ) == nil then
        return 0
    end

    local str_length = string_len( str )

    if position == nil then
        position = 1
    elseif position < 0 then
        position = math_relative( position, str_length )
    elseif position > str_length then
        return -1
    end

    return string_find( str, searchable, position, with_pattern ~= true ) or -1
end

--- [SHARED AND MENU]
---
--- Pads the string to a desired length on the left or right.
---
---@param str string The string to pad.
---@param desired_length integer The desired length of the string.
---@param padding? string The padding compensation symbol. Space by default.
---@param left? boolean Whether to pad on the left.
---@param right? boolean Whether to pad on the right.
---@return string padded_str The padded string.
function string.pad( str, desired_length, padding, left, right )
    if not (left or right) then
        return str
    end

    local char_length
    if padding == nil then
        char_length = 1
        padding = " "
    else
        char_length = string_len( padding )
    end

    local missing_length = math_max( 0, desired_length - string_len( str ) )
    if missing_length == 0 then
        return str
    end

    if left and right then
        local half_reps = math_floor( (missing_length / char_length) * 0.5 )
        local padding_str = string_rep( padding, half_reps )

        local remainder = missing_length - ((half_reps * 2) * char_length)
        if remainder == 0 then
            return padding_str .. str .. padding_str
        end

        local half_remainder = math_floor( remainder * 0.5 )
        padding_str          = padding_str .. string_sub( padding, 1, half_remainder )
        remainder            = remainder - (half_remainder * 2)

        if remainder == 0 then
            return padding_str .. str .. padding_str
        end

        return padding_str .. str .. padding_str .. string_sub( padding, 1, remainder )
    end

    local full_reps = math_floor( missing_length / char_length )
    local remainder = missing_length - (full_reps * char_length)

    if left then
        local result = string_rep( padding, full_reps )

        if remainder ~= 0 then
            result = result .. string_sub( padding, 1, remainder )
        end

        return result .. str
    end

    if right then
        local result = str .. string_rep( padding, full_reps )

        if remainder ~= 0 then
            result = result .. string_sub( padding, 1, remainder )
        end

        return result
    end

    return str
end

do

    --- [SHARED AND MENU]
    ---
    --- Splits the string into an array, using the specified pattern.
    ---
    ---@param str             string  The string to split.
    ---@param searchable?     string  The substring or pattern to split by.
    ---@param with_pattern?   boolean When `true`, `searchable` is interpreted as a Lua pattern. Defaults to `false` (plain match).
    ---@param start_position? integer The start position to split from.
    ---@param end_position?   integer The end position to split to.
    ---@return string[] segments The string array.
    ---@return integer segment_count The length of the array.
    local function split( str, searchable, with_pattern, start_position, end_position )
        local str_length = string_len( str )

        ---@type string[]
        local segments = {}

        if searchable == nil or string_byte( searchable, 1, 1 ) == nil then
            for index = 1, str_length, 1 do
                segments[ index ] = string_sub( str, index, index )
            end

            return segments, str_length
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

        with_pattern = with_pattern ~= true

        ---@type integer
        local segment_count = 0

        ::split_loop::

        local segment_start, segment_end = string_find( str, searchable, start_position, with_pattern )
        if segment_end == nil then
            segment_count = segment_count + 1
            segments[ segment_count ] = string_sub( str, start_position, end_position )
            return segments, segment_count
        end

        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, start_position, math_min( segment_start - 1, end_position ) )

        local split_position = segment_end + 1

        if split_position > end_position then
            segment_count = segment_count + 1
            segments[ segment_count ] = string_sub( str, split_position, end_position )

            return segments, segment_count
        end

        start_position = split_position

        ---@diagnostic disable-next-line: missing-return
        goto split_loop
    end

    string.split = split

    --- [SHARED AND MENU]
    ---
    --- Replaces all occurrences of the supplied second string.
    ---
    ---@param str           string  The string we are seeking to replace an occurrence(s) in.
    ---@param searchable?   string  What we are seeking to replace, or the substring or pattern to split by.
    ---@param replaceable?  string  What to replace it with. If `nil`, occurrences are removed.
    ---@param with_pattern?   boolean When `true`, `searchable` is interpreted as a Lua pattern. Defaults to `false` (plain match).
    ---@param start_position? integer The start position to replace from.
    ---@param end_position?   integer The end position to replace to.
    ---@return string str_replaced The new string with the occurrences replaced.
    function string.replace( str, searchable, replaceable, with_pattern, start_position, end_position )
        local segments, segment_count = split( str, searchable, with_pattern, start_position, end_position )

        if segment_count == 0 then
            return str
        elseif segment_count == 1 then
            return segments[ 1 ]
        end

        if replaceable == nil then
            replaceable = ""
        end

        if segment_count == 2 then
            return segments[ 1 ] .. replaceable .. segments[ 2 ]
        end

        return table_concat( segments, replaceable, 1, segment_count )
    end

end

--- [SHARED AND MENU]
---
--- Returns the number of matches of a string.
---
---@param str           string  The string to count.
---@param searchable    string  The substring or pattern to count by.
---@param with_pattern? boolean When `true`, `searchable` is interpreted as a Lua pattern. Defaults to `false` (plain match).
---@return integer match_count The number of matches.
function string.count( str, searchable, with_pattern )
    local str_length = string_len( str )
    if searchable == nil or string_byte( searchable, 1, 1 ) == nil then
        return str_length
    end

    with_pattern = with_pattern ~= true

    local index, length = 1, 0

    ::count_loop::

    local start_position, end_position = string_find( str, searchable, index, with_pattern )
    if start_position == nil or index > str_length then
        return length
    end

    index, length = end_position + 1, length + 1

    ---@diagnostic disable-next-line: missing-return
    goto count_loop
end

--- [SHARED AND MENU]
---
--- Returns the number of specified byte repetitions.
---
---@param str string The string to count.
---@param counted_byte? integer The byte to count.
---@param direction? boolean If `true`, the direction will be from left to right. If `false`, the direction will be from right to left.
---@param start_position? integer The start position to count from.
---@param end_position? integer The end position to count to.
---@return integer byte_count The number of occurrences.
function string.countByte( str, counted_byte, direction, start_position, end_position )
    if counted_byte == nil or string_byte( str, 1, 1 ) == nil then
        return 0
    end

    local str_length = string_len( str )

    if start_position == nil then
        if direction then
            start_position = 1
        else
            start_position = str_length
        end
    elseif start_position < 0 then
        start_position = math_relative( start_position, str_length )
    else
        start_position = math_min( start_position, str_length )
    end

    if end_position == nil then
        if direction then
            end_position = str_length
        else
            end_position = 1
        end
    elseif end_position < 0 then
        end_position = math_relative( end_position, str_length )
    else
        end_position = math_min( end_position, str_length )
    end

    local byte_count = 0

    if direction then
        if start_position > end_position then
            return byte_count
        end
    elseif start_position < end_position then
        return byte_count
    end

    ::byte_count_loop::

    if string_byte( str, start_position, start_position ) == counted_byte then
        byte_count = byte_count + 1
    end

    if start_position == end_position then
        return byte_count
    end

    if direction then
        start_position = start_position + 1
    else
        start_position = start_position - 1
    end

    ---@diagnostic disable-next-line: missing-return
    goto byte_count_loop
end

--- [SHARED AND MENU]
---
--- Returns the number of consecutive repetitions of the specified byte.
---
---@param str string The string to count.
---@param counted_byte? integer The byte to count.
---@param direction? boolean If `true`, the direction will be from left to right. If `false`, the direction will be from right to left.
---@param start_position? integer The start position to count from.
---@param end_position? integer The end position to count to.
---@return integer byte_count The number of occurrences.
function string.countConsecutiveByte( str, counted_byte, direction, start_position, end_position )
    if counted_byte == nil or string_byte( str, 1, 1 ) == nil then
        return 0
    end

    local str_length = string_len( str )

    if start_position == nil then
        if direction then
            start_position = 1
        else
            start_position = str_length
        end
    elseif start_position < 0 then
        start_position = math_relative( start_position, str_length )
    else
        start_position = math_min( start_position, str_length )
    end

    if end_position == nil then
        if direction then
            end_position = str_length
        else
            end_position = 1
        end
    elseif end_position < 0 then
        end_position = math_relative( end_position, str_length )
    else
        end_position = math_min( end_position, str_length )
    end

    local byte_count = 0

    if direction then
        if start_position > end_position then
            return byte_count
        end
    elseif start_position < end_position then
        return byte_count
    end

    ::byte_count_consecutive_loop::

    if string_byte( str, start_position, start_position ) == counted_byte then
        byte_count = byte_count + 1
    else
        return byte_count
    end

    if start_position == end_position then
        return byte_count
    end

    if direction then
        start_position = start_position + 1
    else
        start_position = start_position - 1
    end

    ---@diagnostic disable-next-line: missing-return
    goto byte_count_consecutive_loop
end

--- [SHARED AND MENU]
---
--- Returns the string trimmed by the specified byte.
---
---@param str string The string to trim.
---@param trailing_byte? integer The byte to trim trailing characters.
---@param direction boolean | nil The trim direction, `true` for right, `false` for left, `nil` for both.
---@param start_position? integer The start position to trim from.
---@param end_position? integer The end position to trim to.
---@return string trimmed_str The trimmed string.
---@return integer trimmed_length The length of the trimmed string.
function string.trimByte( str, trailing_byte, direction, start_position, end_position )
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

    if trailing_byte == nil then
        trailing_byte = 0x20 --[[ Space ]]
    end

    if direction ~= true then
        while string_byte( str, start_position, start_position ) == trailing_byte do
            if start_position == end_position then
                return string_sub( str, end_position + 1, str_length ), str_length - end_position
            else
                start_position = start_position + 1
            end
        end
    end

    if direction ~= false then
        while string_byte( str, end_position, end_position ) == trailing_byte do
            if end_position == 1 then
                return "", 0
            else
                end_position = end_position - 1
            end
        end
    end

    ---@cast start_position integer

    return string_sub( str, start_position, end_position ), end_position - start_position + 1
end

--- [SHARED AND MENU]
---
--- Returns the trimmed string (without leading/trailing space characters) and its length.
---
---@param str string The string to trim.
---@param direction boolean | nil The trim direction, `true` for right, `false` for left, `nil` for both.
---@param start_position? integer The start position to trim from.
---@param end_position? integer The end position to trim to.
---@return string trimmed_str The trimmed string.
---@return integer trimmed_length The length of the trimmed string.
function string.trimSpaces( str, direction, start_position, end_position )
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

    if direction ~= true then
        while ascii_isSpace( string_byte( str, start_position, start_position ) ) do
            if start_position == end_position then
                return string_sub( str, end_position + 1, str_length ), str_length - end_position
            else
                start_position = start_position + 1
            end
        end
    end

    if direction ~= false then
        while ascii_isSpace( string_byte( str, end_position, end_position ) ) do
            if end_position == 1 then
                return "", 0
            else
                end_position = end_position - 1
            end
        end
    end

    ---@cast start_position integer

    return string_sub( str, start_position, end_position ), end_position - start_position + 1
end

--- [SHARED AND MENU]
---
--- Splits the string into an array, using the specified byte.
---
---@param str string The string to split.
---@param searchable_byte? integer The byte to split by.
---@param start_position? integer The start position to split from.
---@param end_position? integer The end position to split to.
---@return string[] segments The string array.
---@return integer segment_count The length of the array.
local function byte_split( str, searchable_byte, start_position, end_position )
    if searchable_byte == nil then
        searchable_byte = 0x20 --[[ Space ]]
    end

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

    local segments, segment_count = {}, 0

    if start_position > end_position then
        return segments, segment_count
    end

    local split_position = start_position - 1

    ::byte_split_loop::

    if string_byte( str, start_position, start_position ) == searchable_byte then
        if split_position ~= start_position then
            segment_count = segment_count + 1
            segments[ segment_count ] = string_sub( str, split_position + 1, start_position - 1 )
        end

        split_position = start_position
    end

    if start_position ~= end_position then
        start_position = start_position + 1
        goto byte_split_loop
    end

    segment_count = segment_count + 1
    segments[ segment_count ] = string_sub( str, split_position + 1, start_position )

    return segments, segment_count
end

string.byteSplit = byte_split

--- [SHARED AND MENU]
---
--- Replaces all occurrences of the supplied second string.
---
---@param str           string  The string we are seeking to replace an occurrence(s) in.
---@param searchable_byte? integer The byte to split by.
---@param replaceable?  string  What to replace it with. If `nil`, occurrences are removed.
---@param start_position? integer The start position to replace from.
---@param end_position?   integer The end position to replace to.
---@return string str_replaced The new string with the occurrences replaced.
function string.byteReplace( str, searchable_byte, replaceable, start_position, end_position )
    local segments, segment_count = byte_split( str, searchable_byte, start_position, end_position )

    if segment_count == 0 then
        return str
    elseif segment_count == 1 then
        return segments[ 1 ]
    end

    if replaceable == nil then
        replaceable = ""
    end

    if segment_count == 2 then
        return segments[ 1 ] .. replaceable .. segments[ 2 ]
    end

    return table_concat( segments, replaceable, 1, segment_count )
end

--- [SHARED AND MENU]
---
--- Checks if `str` contains `searchable`.
---
--- Wraps `string.find` and returns `true` if a match is found at or after
--- `start_position`. By default the search is treated as a plain substring
--- match; pass `with_pattern = true` to interpret `searchable` as a Lua
--- pattern instead.
---
---@param str             string  The string to search in.
---@param searchable      string  The substring or pattern to search for.
---@param with_pattern?   boolean When `true`, `searchable` is interpreted as a Lua pattern. Defaults to `false` (plain match).
---@param start_position? integer The byte position to start searching from. Defaults to `1`. Negative values count from the end of the string.
---@return boolean found `true` if `searchable` was found within `str`, `false` otherwise.
function string.contains( str, searchable, with_pattern, start_position )
    return string_find( str, searchable, start_position, with_pattern ~= true ) ~= nil
end

--- [SHARED AND MENU]
---
--- Checks if the string contains the specified byte.
---
---@param str string The string to check.
---@param byte integer The byte to check for.
---@param start_position? integer The start position to check from.
---@param end_position? integer The end position to check to.
---@return boolean has_byte `true` if the string contains the byte, `false` otherwise.
function string.containsByte( str, byte, start_position, end_position )
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

    local step = (start_position < end_position) and 1 or -1

    for index = start_position, end_position, step do
        if string_byte( str, index, index ) == byte then return true end
    end

    return false
end

--- [SHARED AND MENU]
---
--- Checks if the string contains any byte from specified byte map.
---
---@param str string The string to check.
---@param byte_map table<integer, boolean> The bytes array to check in.
---@param start_position? integer The start position to check from.
---@param end_position? integer The end position to check to.
---@return boolean has_byte `true` if the string contains the byte, `false` otherwise.
function string.containsBytes( str, byte_map, start_position, end_position )
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

    for index = start_position, end_position, ((start_position < end_position) and 1 or -1) do
        if byte_map[ string_byte( str, index, index ) ] then
            return true
        end
    end

    return false
end

--- [SHARED AND MENU]
---
--- Removes all instances of a byte from a string.
---
---@param str string The string to purge.
---@param byte integer The byte to purge.
---@param start_position? integer The start position in the string.
---@param end_position? integer The end position in the string.
---@return string str_purged The purged string.
function string.purge( str, byte, start_position, end_position )
    local segments, segment_count = byte_split( str, byte, start_position, end_position )
    return table_concat( segments, "", 1, segment_count )
end

do

    --- [SHARED AND MENU]
    ---
    --- Converts a string to a number.
    ---
    ---@param str string The string to convert.
    ---@param base? integer The base to convert the string in.
    ---@param start_position? integer The start position to convert from.
    ---@param end_position? integer The end position to convert to.
    ---@return number | nil num The converted number, or `nil` if the string is not a number.
    local function toNumber( str, base, start_position, end_position )
        if base == nil then
            local uint8_1, uint8_2, uint8_3 = string_byte( str, (start_position or 1), (start_position or 1) + 2 )
            if uint8_1 == 0x30 --[[ 0 ]] and (uint8_2 == 0x78 --[[ x ]] or uint8_2 == 0x58 --[[ X ]]) then
                if uint8_3 == nil then
                    return 0
                end

                base = 16
            elseif uint8_1 == 0x30 --[[ 0 ]] and uint8_2 ~= nil then
                base = 8
            else
                base = 10
            end
        elseif base == 16 then
            local uint8_1, uint8_2, uint8_3 = string_byte( str, (start_position or 1), (start_position or 1) + 2 )
            if uint8_1 == 0x30 --[[ 0 ]] and (uint8_2 == 0x78 --[[ x ]] or uint8_2 == 0x58 --[[ X ]]) and uint8_3 == nil then
                return 0
            end
        end

        if start_position == nil and end_position == nil then
            return raw_tonumber( str, base )
        end

        return raw_tonumber( string_sub( str, start_position or 1, end_position ), base )
    end

    string.toNumber = toNumber

    --- [SHARED AND MENU]
    ---
    --- Checks if the string is a number.
    ---
    ---@param str string The string to check.
    ---@param base? integer The base to check the string in.
    ---@param start_position? integer The start position to check from.
    ---@param end_position? integer The end position to check to.
    ---@return boolean is_number `true` if the string is a number, otherwise `false`.
    function string.isNumber( str, base, start_position, end_position )
        return toNumber( str, base, start_position, end_position ) ~= nil
    end

end

--- [SHARED AND MENU]
---
--- Checks if a string is a URL.
---
---@param str string The string to check.
---@return boolean result `true` if the string is a URL, otherwise `false`.
function string.isURL( str )
    return string_match( str, "^%l[%l+-.]+%:[^%z\x01-\x20\x7F-\xFF\"<>^`:{-}]*$" ) ~= nil
end

--- [SHARED AND MENU]
---
--- Checks if a string is bytecode.
---
--- The string should be a LuaJIT bytecode chunk.
---
---@param str string The string to check.
---@param jit_version `0x01` | `0x02` | integer The JIT version to check for. (Basically `jit.version_byte`)
---@param start_position? integer The start position of the string.
---@return boolean result `true` if the string is bytecode, otherwise `false`.
function string.isBytecode( str, jit_version, start_position )
    if start_position == nil then
        start_position = 1
    end

    local uint8_1, uint8_2, uint8_3, uint8_4 = string_byte( str, start_position, start_position + 3 )
    return uint8_1 == 0x1B and uint8_2 == 0x4C and uint8_3 == 0x4A and uint8_4 == jit_version
end

--- [SHARED AND MENU]
---
--- Escapes a string for use it as a pattern.
---
---@param str string The string to escape.
---@param start_position? integer The start position to escape from.
---@param end_position? integer The end position to escape to.
---@return string escaped_str The escaped string.
function string.escapePattern( str, start_position, end_position )
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

    local escape_position = start_position - 1
    local segments, segment_count = {}, 0

    ::escape_pattern_loop::

    local uint8_1 = string_byte( str, start_position, start_position )
    local replacement

    if uint8_1 == 0x0 then
        replacement = "%z"
    else
        replacement = pattern_bytes[ uint8_1 ]
    end

    if replacement ~= nil then
        if escape_position ~= start_position then
            segment_count = segment_count + 1
            segments[ segment_count ] = string_sub( str, escape_position + 1, start_position - 1 ) .. replacement
        end

        escape_position = start_position
    end

    if start_position ~= end_position then
        start_position = start_position + 1
        goto escape_pattern_loop
    end

    if escape_position ~= start_position then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, escape_position + 1, start_position )
    end

    if segment_count == 0 then
        return str
    elseif segment_count == 1 then
        return segments[ 1 ]
    end

    return table_concat( segments, "", 1, segment_count )
end

--- [SHARED AND MENU]
---
--- Removes leading/trailing matches of a string.
---
---@param str string The string to trim.
---@param pattern_str? string The pattern to match, `%s` for whitespace.
---@param direction boolean | nil The trim direction, `true` for right, `false` for left, `nil` for both.
---@return string trimmed_str The trimmed string.
function string.trim( str, pattern_str, direction )
    if pattern_str == nil then
        pattern_str = "%s"
    else
        local uint8_1, uint8_2, uint8_3 = string_byte( pattern_str, 1, 3 )

        if uint8_1 == nil then
            pattern_str = "%s"
        elseif uint8_2 == nil then
            pattern_str = pattern_bytes[ uint8_1 ] or pattern_str
        elseif uint8_3 ~= nil or uint8_1 ~= 0x25 --[[ % ]] then
            pattern_str = "[" .. pattern_str .. "]"
        end
    end

    if direction == true then
        return string_match( str, "^(.-)" .. pattern_str .. "*$" ) or str
    elseif direction == false then
        return string_match( str, "^" .. pattern_str .. "*(.+)$" ) or str
    end

    return string_match( str, "^" .. pattern_str .. "*(.-)" .. pattern_str .. "*$" ) or str
end

do

    local numberic_alphabet = { [ 0 ] = 10, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39 }
    local lowercase_alphabet = { [ 0 ] = 26, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A }
    local uppercase_alphabet = { [ 0 ] = 26, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A }
    local symbol_alphabet = { [ 0 ] = 32, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F, 0x40, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x7B, 0x7C, 0x7D, 0x7E }
    local extended_alphabet = { [ 0 ] = 128, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF, 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF, 0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF }

    --- [SHARED AND MENU]
    ---
    --- Generates a random string.
    ---
    --- Can be used to generate a password/key/secret.
    ---
    --- The length of the string is 8 by default.
    ---
    ---@param length? integer The length of the string, defaults to 8.
    ---@param lowercase? boolean Whether to include lowercase letters.
    ---@param uppercase? boolean Whether to include uppercase letters.
    ---@param numbers? boolean Whether to include numbers.
    ---@param symbols? boolean Whether to include symbols.
    ---@param extended_ascii? boolean Whether to include extended ASCII characters.
    ---@return string
    function string.random( length, lowercase, uppercase, numbers, symbols, extended_ascii )
        if length == nil then
            length = 8
        elseif length == 0 then
            return ""
        end

        ---@type integer[][]
        local alphabets = {}

        ---@type integer
        local alphabet_count = 0

        if lowercase ~= false then
            alphabet_count = alphabet_count + 1
            alphabets[ alphabet_count ] = lowercase_alphabet
        end

        if uppercase then
            alphabet_count = alphabet_count + 1
            alphabets[ alphabet_count ] = uppercase_alphabet
        end

        if numbers ~= false then
            alphabet_count = alphabet_count + 1
            alphabets[ alphabet_count ] = numberic_alphabet
        end

        if symbols then
            alphabet_count = alphabet_count + 1
            alphabets[ alphabet_count ] = symbol_alphabet
        end

        if extended_ascii then
            alphabet_count = alphabet_count + 1
            alphabets[ alphabet_count ] = extended_alphabet
        end

        ---@type integer[]
        local chars = {}

        for index = 1, length, 1 do
            local alphabet = alphabets[ math_random( 1, alphabet_count ) ]
            chars[ index ] = alphabet[ math_random( 1, alphabet[ 0 ] ) ]
        end

        return string_char( table_unpack( chars, 1, length ) )
    end

end

--- [SHARED AND MENU]
---
--- Interpolates a string with the given arguments.
---
--- The arguments are replaced in the string using the following format:
---
--- `{1}`, `{2}`, `{3}`, `{4}`, `{5}`, `{6}`, `{7}`, `{8}`, `{9}`
---
--- It's also supports named arguments:
---
--- `{key}`, `{my_val}`, `{something}` and etc.
---
---@see string.format
---
---@param str string The string to interpolate.
---@param variables string[] | table<string, string> The variables to interpolate into the string.
---@param start_position? integer The start position to interpolate from.
---@param end_position? integer The end position to interpolate to.
---@return string str The interpolated string.
function string.interpolate( str, variables, start_position, end_position )
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

    ---@type integer
    local break_position = start_position

    ---@type string[]
    local segments = {}

    ---@type integer
    local segment_count = 0

    if start_position ~= 1 then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, 1, start_position - 1 )
    end

    repeat

        local uint8_1 = string_byte( str, start_position, start_position )

        if uint8_1 == 0x7B --[[ { ]] then
            ---@type integer
            local index_start = start_position + 1
            if index_start >= end_position then
                break
            end

            ---@type integer
            local index = index_start

            repeat

                local uint8_2 = string_byte( str, index, index )

                if uint8_2 == 0x7D --[[ } ]] then
                    local index_end = index - 1
                    start_position = index + 1

                    if index_start > index_end then
                        break
                    end

                    local arg_value = variables[ string_sub( str, index_start, index_end ) ]
                    if arg_value ~= nil then
                        if break_position ~= start_position then
                            segment_count = segment_count + 1
                            segments[ segment_count ] = string_sub( str, break_position, index_start - 2 )
                        end

                        break_position = start_position

                        segment_count = segment_count + 1
                        segments[ segment_count ] = arg_value
                    end

                    break
                elseif uint8_2 == 0x5C --[[ \ ]] then
                    index = index + 2
                else
                    index = index + 1
                end

            until index_start >= end_position

            if start_position <= index_start then
                start_position = index_start
            end
        elseif uint8_1 == 0x5C --[[ \ ]] then
            start_position = start_position + 2
        else
            start_position = start_position + 1
        end

    until start_position > end_position

    if break_position ~= start_position then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, break_position, end_position )
    end

    if end_position ~= str_length then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, end_position + 1, str_length )
    end

    if segment_count == 0 then
        return ""
    end

    return table_concat( segments, "", 1, segment_count )
end

--- [SHARED AND MENU]
---
--- Replaces a byte in the string with the given variables.
---
--- Works the same way as [string.interpolate](#string.interpolate)
--- but uses byte count as index instead of direct key names.
---
---@param str string The string to interpolate.
---@param interpolate_byte integer The byte to interpolate.
---@param variables string[] The variables to interpolate into the string.
---@param variable_count? integer The size of the map. Optionally, it should be used to speed up calculations.
---@param start_position? integer The start position to interpolate from.
---@param end_position? integer The end position to interpolate to.
---@return string str The interpolated string.
function string.interpolateByte( str, interpolate_byte, variables, variable_count, start_position, end_position )
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

    if start_position > end_position then
        return str
    end

    if variable_count == nil then
        variable_count = len( variables )
    end

    if variable_count == 0 then
        return str
    end

    ---@type string[]
    local segments = {}

    ---@type integer
    local segment_count = 0

    if start_position ~= 1 then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, 1, start_position - 1 )
    end

    local break_point = start_position - 1
    local index = 0

    ::byte_interpolate_loop::

    if string_byte( str, start_position, start_position ) == interpolate_byte then
        if break_point ~= start_position then
            segment_count = segment_count + 1
            segments[ segment_count ] = string_sub( str, break_point + 1, start_position - 1 )
        end

        index = index + 1
        segment_count = segment_count + 1
        segments[ segment_count ] = variables[ index ]

        break_point = start_position
    end

    if start_position ~= end_position and index ~= variable_count then
        start_position = start_position + 1
        goto byte_interpolate_loop
    end

    if break_point ~= end_position then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, break_point + 1, end_position )
    end

    if end_position ~= str_length then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_sub( str, end_position + 1, str_length )
    end

    if segment_count == 0 then
        return ""
    end

    return table_concat( segments, "", 1, segment_count )
end

--- [SHARED AND MENU]
---
--- Packs a sequence of bytes into a string.
---
---@param bytes integer[] The sequence of bytes. (integers<0-255>)
---@param byte_count? integer The number of bytes to pack, default is `len( bytes )`.
---@return string str The packed bytes.
function string.pack( bytes, byte_count )
    if byte_count == nil then
        byte_count = len( bytes )
    end

    if byte_count == 0 then
        return ""
    end

    local segments, segment_count = {}, 0
    local remaining = byte_count % 32

    local split_position = byte_count - remaining

    for i = 0, split_position - 1, 32 do
        segment_count = segment_count + 1
        segments[ segment_count ] = string_char(
            bytes[ i + 1 ], bytes[ i + 2 ], bytes[ i + 3 ], bytes[ i + 4 ],
            bytes[ i + 5 ], bytes[ i + 6 ], bytes[ i + 7 ], bytes[ i + 8 ],
            bytes[ i + 9 ], bytes[ i + 10 ], bytes[ i + 11 ], bytes[ i + 12 ],
            bytes[ i + 13 ], bytes[ i + 14 ], bytes[ i + 15 ], bytes[ i + 16 ],
            bytes[ i + 17 ], bytes[ i + 18 ], bytes[ i + 19 ], bytes[ i + 20 ],
            bytes[ i + 21 ], bytes[ i + 22 ], bytes[ i + 23 ], bytes[ i + 24 ],
            bytes[ i + 25 ], bytes[ i + 26 ], bytes[ i + 27 ], bytes[ i + 28 ],
            bytes[ i + 29 ], bytes[ i + 30 ], bytes[ i + 31 ], bytes[ i + 32 ]
        )
    end

    if remaining ~= 0 then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_char( table_unpack( bytes, split_position + 1, byte_count ) )
    end

    return table_concat( segments, "", 1, segment_count )
end

--- [SHARED AND MENU]
---
--- Unpacks a string into a sequence of bytes.
---
---@param str string The string to unpack.
---@param start_position? integer The start position of the string, default is `1`.
---@param end_position? integer The end position of the string, default is `len( str )`.
---@return integer[] bytes The unpacked bytes.
---@return integer byte_count The number of bytes unpacked.
function string.unpack( str, start_position, end_position )
    local str_length = string_len( str )
    if str_length == 0 then
        return {}, 0
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

    if start_position > end_position then
        return {}, 0
    end

    local segments = {}

    local total = end_position - start_position + 1
    local remaining = total % 32

    local split_position = total - remaining

    for i = start_position, split_position - 1, 32 do
        segments[ i ], segments[ i + 1 ], segments[ i + 2 ], segments[ i + 3 ],
        segments[ i + 4 ], segments[ i + 5 ], segments[ i + 6 ], segments[ i + 7 ],
        segments[ i + 8 ], segments[ i + 9 ], segments[ i + 10 ], segments[ i + 11 ],
        segments[ i + 12 ], segments[ i + 13 ], segments[ i + 14 ], segments[ i + 15 ],
        segments[ i + 16 ], segments[ i + 17 ], segments[ i + 18 ], segments[ i + 19 ],
        segments[ i + 20 ], segments[ i + 21 ], segments[ i + 22 ], segments[ i + 23 ],
        segments[ i + 24 ], segments[ i + 25 ], segments[ i + 26 ], segments[ i + 27 ],
        segments[ i + 28 ], segments[ i + 29 ], segments[ i + 30 ], segments[ i + 31 ] = string_byte( str, i, i + 31 )
    end

    if remaining ~= 0 then
        split_position = split_position + 1

        segments[ split_position ], segments[ split_position + 1 ], segments[ split_position + 2 ], segments[ split_position + 3 ],
        segments[ split_position + 4 ], segments[ split_position + 5 ], segments[ split_position + 6 ], segments[ split_position + 7 ],
        segments[ split_position + 8 ], segments[ split_position + 9 ], segments[ split_position + 10 ], segments[ split_position + 11 ],
        segments[ split_position + 12 ], segments[ split_position + 13 ], segments[ split_position + 14 ], segments[ split_position + 15 ],
        segments[ split_position + 16 ], segments[ split_position + 17 ], segments[ split_position + 18 ], segments[ split_position + 19 ],
        segments[ split_position + 20 ], segments[ split_position + 21 ], segments[ split_position + 22 ], segments[ split_position + 23 ],
        segments[ split_position + 24 ], segments[ split_position + 25 ], segments[ split_position + 26 ], segments[ split_position + 27 ],
        segments[ split_position + 28 ], segments[ split_position + 29 ], segments[ split_position + 30 ] = string_byte( str, split_position, split_position + 30 )
    end

    return segments, total
end

--- [SHARED AND MENU]
---
--- Formats a number with a separator (e.g. comma) for thousands.
---
---@param str string The string to format.
---@param separator? string The separator to use, default is `,`.
---@param offset? integer The offset to use, default is `3`.
---@return string str The formatted string.
function string.comma( str, separator, offset )
    local str_length = string_len( str )
    if str_length == 0 then return str end

    if separator == nil then
        separator = ","
    end

    if offset == nil then
        offset = 3
    else
        offset = math_max( 0, math_floor( math_abs( offset ) ) )
        if offset == 0 then return str end
    end

    for i = str_length - offset, 1, -offset do
        str = string_sub( str, 1, i ) .. separator .. string_sub( str, i + 1 )
    end

    return str
end

--- [SHARED AND MENU]
---
--- Returns a string that is the concatenation of `repetitions` copies of the byte `rep_byte`.
---
---@param rep_byte integer The byte to repeat.
---@param repetitions? integer The number of times to repeat the byte. Defaults to 1.
---@return string rep_str The repeated byte as a string.
function string.byteRep( rep_byte, repetitions )
    if repetitions == nil then
        repetitions = 1
    end

    if repetitions == 1 then
        return string_char( rep_byte )
    elseif repetitions == 2 then
        return string_char( rep_byte, rep_byte )
    elseif repetitions == 3 then
        return string_char( rep_byte, rep_byte, rep_byte )
    elseif repetitions == 4 then
        return string_char( rep_byte, rep_byte, rep_byte, rep_byte )
    elseif repetitions == 5 then
        return string_char( rep_byte, rep_byte, rep_byte, rep_byte, rep_byte )
    elseif repetitions == 6 then
        return string_char( rep_byte, rep_byte, rep_byte, rep_byte, rep_byte, rep_byte )
    elseif repetitions == 7 then
        return string_char( rep_byte, rep_byte, rep_byte, rep_byte, rep_byte, rep_byte, rep_byte )
    elseif repetitions == 8 then
        return string_char( rep_byte, rep_byte, rep_byte, rep_byte, rep_byte, rep_byte, rep_byte, rep_byte )
    end

    ---@type integer[]
    local bytes = {}

    for i = 1, repetitions, 1 do
        bytes[ i ] = rep_byte
    end

    return string_char( table_unpack( bytes, 1, repetitions ) )
end

do

    local string_replace = string.replace

    --- [SHARED AND MENU]
    ---
    --- Quotes a string using single or double quotes.
    ---
    ---@param str string The string to quote.
    ---@param use_single? boolean Whether to use single quotes (true) or double quotes (false).
    ---@return string The quoted string.
    function string.quote( str, use_single )
        if use_single then
            return "'" .. string_replace( str, "'", "\\'" ) .. "'"
        end

        return '"' .. string_replace( str, '"', '\\"' ) .. '"'
    end

    --- [SHARED AND MENU]
    ---
    --- Unquotes a string using single or double quotes.
    ---
    ---@param str string The string to unquote.
    ---@param use_single? boolean Whether to use single quotes (true) or double quotes (false).
    ---@return string The unquoted string.
    function string.unQuote( str, use_single )
        if use_single then
            return string_replace( string_match( str, "^'(.*)'$" ) or str, "\\'", "'" )
        end

        return string_replace( string_match( str, "^\"(.*)\"$" ) or str, '\\"', '"' )
    end

end

do

    local string_trimSpaces = string.trimSpaces
    local string_byteRep = string.byteRep

    --- [SHARED AND MENU]
    ---
    --- Pads a string with a byte on the left or right.
    ---
    ---@param str string The string to pad.
    ---@param desired_length integer The desired length of the padded string.
    ---@param padding_byte? integer The byte value to use for padding. (Default: `0x20`)
    ---@param left? boolean Whether to pad on the left (`true`) or right (`false`).
    ---@param right? boolean Whether to pad on the right (`true`) or left (`false`).
    ---@return string padded_str The padded string.
    function string.bytePad( str, desired_length, padding_byte, left, right )
        local missing_length = math_max( 0, desired_length - string_len( str ) )
        if missing_length == 0 then
            return str
        end

        if padding_byte == nil then
            padding_byte = 0x20 --[[ space ]]
        end

        if left then
            if right then
                local missing_length_half = math_floor( missing_length * 0.5 )
                return string_byteRep( padding_byte, missing_length_half ) .. str .. string_byteRep( padding_byte, missing_length_half + (missing_length - (missing_length_half * 2)) )
            end

            return string_byteRep( padding_byte, missing_length ) .. str
        end

        if right then
            return str .. string_byteRep( padding_byte, missing_length )
        end

        return str
    end

    --- [SHARED AND MENU]
    ---
    --- Unindents a string by removing leading spaces.
    ---
    ---@param str string The string to unindent.
    ---@return string unindented The unindented string.
    local function unIndent( str )
        return (string_trimSpaces( str, false ))
    end

    string.unIndent = unIndent

    --- [SHARED AND MENU]
    ---
    --- Sets the space indentation size for a string.
    ---
    ---@param str string The string to indent.
    ---@param size integer The number of spaces to indent.
    ---@return string indented The indented string.
    function string_indent( str, size )
        return string_byteRep( 0x20, size ) .. unIndent( str )
    end

    string.indent = string_indent

    --- [SHARED AND MENU]
    ---
    --- Indents a string by adding leading spaces on each line.
    ---
    ---@param str string The string to indent.
    ---@param size integer The number of spaces to indent.
    ---@return string indented The indented string.
    function string.indentLines( str, size )
        local lines, line_count = byte_split( str, 0x0A )

        if line_count == 0 then
            return ""
        elseif line_count == 1 then
            return string_indent( str, size )
        end

        ---@type string[]
        local output = {}

        for i = 1, line_count, 1 do
            output[ i ] = string_indent( lines[ i ], size )
        end

        return table_concat( output, "\n", 1, line_count )
    end

    --- [SHARED AND MENU]
    ---
    --- Unindents a string by removing leading spaces on each line.
    ---
    ---@param str string The string to unindent.
    ---@return string unindented The unindented string.
    function string.unindentLines( str )
        local lines, line_count = byte_split( str, 0x0A )

        if line_count == 0 then
            return ""
        elseif line_count == 1 then
            return unIndent( str )
        end

        ---@type string[]
        local output = {}

        for i = 1, line_count, 1 do
            output[ i ] = unIndent( lines[ i ] )
        end

        return table_concat( output, "\n", 1, line_count )
    end

end

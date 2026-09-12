---@class dreamwork.std
local std = dreamwork.std

local debug = std.debug
local debug_getfmain = debug.getfmain
local debug_getfsource = debug.getfsource

local string = std.string
local string_len = string.len
local string_trimByte = string.trimByte
local pattern_bytes = string.PatternBytes
local string_byteSplit = string.byteSplit
local string_sub, string_gsub = string.sub, string.gsub
local string_char, string_byte = string.char, string.byte

local table = std.table
local table_concat = table.concat
local table_insert, table_remove = table.insert, table.remove

local len = std.len
local getfenv = std.getfenv
local isFunction = std.isFunction

--- [SHARED AND MENU]
---
--- The file path library.
---
---@class dreamwork.std.path
---@field delimiter string The path delimiter.
---@field sep string The path separator.
local path = {}
std.path = path

path.delimiter = ":"
path.sep = "/"

--- [SHARED AND MENU]
---
--- Check to see if the file path is absolute.
---
---@param file_path string The file path.
---@return boolean is_abs `true` if the file path is absolute, `false` otherwise.
function path.isAbsolute( file_path )
    return string_byte( file_path, 1, 1 ) == 0x2F --[[ / ]]
end

--- [SHARED AND MENU]
---
--- Check to see if the file path is relative.
---
---@param file_path string The file path.
---@return boolean is_rel `true` if the file path is relative, `false` otherwise.
function path.isRelative( file_path )
    return string_byte( file_path, 1, 1 ) ~= 0x2F --[[ / ]]
end

local equals

if std.SYSTEM_WINDOWS or std.SYSTEM_OSX then

    local string_lower = string.lower

    --- [SHARED AND MENU]
    ---
    --- Check to see if the paths are equal.
    ---
    ---@param file_path1 string The first file path.
    ---@param file_path2 string The second file path.
    ---@return boolean is_equal `true` if the paths are equal, `false` otherwise.
    function equals( file_path1, file_path2 )
        return string_lower( file_path1 ) == string_lower( file_path2 )
    end

else

    --- [SHARED AND MENU]
    ---
    --- Check to see if the paths are equal.
    ---
    ---@param file_path1 string The first file path.
    ---@param file_path2 string The second file path.
    ---@return boolean is_equal `true` if the paths are equal, `false` otherwise.
    function equals( file_path1, file_path2 )
        return file_path1 == file_path2
    end

end

path.equals = equals

--- [SHARED AND MENU]
---
--- Get the name of the file path.
---
---@param file_path string The file path.
---@param keep_extension? boolean `true` to keep the extension, `false` otherwise
---@return string file_name The name of the file.
function path.getFile( file_path, keep_extension )
    if keep_extension then
        for index = string_len( file_path ), 1, -1 do
            if string_byte( file_path, index ) == 0x2F --[[ / ]] then
                return string_sub( file_path, index + 1 )
            end
        end

        return file_path
    end

    local dot_position

    for index = string_len( file_path ), 1, -1 do
        local byte = string_byte( file_path, index )
        if byte == 0x2E --[[ . ]] then
            if dot_position == nil then
                dot_position = index
            end
        elseif byte == 0x2F --[[ / ]] then
            if dot_position == nil then
                return string_sub( file_path, index + 1 )
            else
                return string_sub( file_path, index + 1, dot_position - 1 )
            end
        end
    end

    if dot_position == nil then
        return file_path
    end

    return string_sub( file_path, 1, dot_position - 1 )
end

--- [SHARED AND MENU]
---
--- Get the directory of the file path.
---
---@param file_path string The file path.
---@param keep_trailing_slash? boolean `true` to keep the trailing slash, `false` otherwise.
---@return string | nil directory The directory of the file, or `nil` if the file path is invalid.
local function getDirectory( file_path, keep_trailing_slash )
    for index = string_len( file_path ), 1, -1 do
        if string_byte( file_path, index ) == 0x2F --[[ / ]] then
            if not keep_trailing_slash then
                index = index - 1
            end

            return string_sub( file_path, 1, index )
        end
    end

    return nil
end

path.getDirectory = getDirectory

--- [SHARED AND MENU]
---
--- Get the extension of the file path.
---
---@param file_path string The file path.
---@param keep_dot? boolean `true` to keep the dot, `false` otherwise.
---@return string extension The extension of the file.
function path.getExtension( file_path, keep_dot )
    for index = string_len( file_path ), 1, -1 do
        local byte = string_byte( file_path, index )
        if byte == 0x2F --[[ / ]] then
            break
        elseif byte == 0x2E --[[ . ]] then
            if not keep_dot then
                index = index + 1
            end

            return string_sub( file_path, index )
        end
    end

    return ""
end

--- [SHARED AND MENU]
---
--- Split a file path into a directory and a file name.
---
---@param file_path string The file path.
---@param keep_trailing_slash? boolean `true` to keep the trailing slash, `false` otherwise.
---@return string directory_path The directory from the file path.
---@return string file_name The file from the file path.
local function split( file_path, keep_trailing_slash )
    for index = string_len( file_path ), 1, -1 do
        if string_byte( file_path, index ) == 0x2F --[[ / ]] then
            return string_sub( file_path, 1, keep_trailing_slash and index or (index - 1) ), string_sub( file_path, index + 1 )
        end
    end

    return "", file_path
end

path.split = split

--- [SHARED AND MENU]
---
--- Split a file path into a file name and an extension.
---
---@param file_path string The file path.
---@param keep_dot? boolean `true` to keep the extension dot, `false` otherwise.
---@return string file_name The file name from the file path.
---@return string extension The extension from the file path.
local function splitExtension( file_path, keep_dot )
    for index = string_len( file_path ), 1, -1 do
        local byte = string_byte( file_path, index )
        if byte == 0x2F --[[ / ]] then
            return file_path, ""
        elseif byte == 0x2E --[[ . ]] then
            return string_sub( file_path, 1, index - 1 ), string_sub( file_path, keep_dot and index or (index + 1) )
        end
    end

    return file_path, ""
end

path.splitExtension = splitExtension

--- [SHARED AND MENU]
---
--- Replaces the file name in the file path.
---
---@param file_path string The file path.
---@param file_name string The new file name.
---@return string new_file_path The new file path.
function path.replaceName( file_path, file_name )
    return split( file_path, true ) .. file_name
end

--- [SHARED AND MENU]
---
--- Replaces the directory in the file path.
---
---@param file_path string The file path.
---@param dir_name string The new directory.
---@return string new_file_path The new file path.
function path.replaceDirectory( file_path, dir_name )
    if string_byte( dir_name, string_len( dir_name ) ) ~= 0x2F --[[ / ]] then
        dir_name = dir_name .. "/"
    end

    local _, file_name = split( file_path, false )
    return dir_name .. file_name
end

--- [SHARED AND MENU]
---
--- Replaces the extension in the file path.
---
---@param file_path string The file path.
---@param ext_name string The new extension.
---@return string new_file_path The new file path.
function path.replaceExtension( file_path, ext_name )
    return splitExtension( file_path, false ) .. "." .. ext_name
end

--- [SHARED AND MENU]
---
--- Strips the trailing slash from the file path.
---
---@param file_path string The file path.
---@return string new_file_path The new file path.
function path.stripTrailingSlash( file_path )
    return (string_gsub( file_path, "[/\\]+$", "" ))
end

--- [SHARED AND MENU]
---
--- Ensures the file path has a trailing slash.
---
---@param file_path string The file path.
---@return string new_file_path The new file path.
function path.ensureTrailingSlash( file_path )
    if string_byte( file_path, string_len( file_path ) ) == 0x2F --[[ / ]] then
        return file_path
    else
        return file_path .. "/"
    end
end

--- [SHARED AND MENU]
---
--- Strips the leading slash from the file path.
---
---@param file_path string The file path.
---@return string new_file_path The new file path.
function path.stripLeadingSlash( file_path )
    return (string_gsub( file_path, "^[/\\]+", "" ))
end

--- [SHARED AND MENU]
---
--- Ensures the file path has a leading slash.
---
---@param file_path string The file path.
---@return string new_file_path The new file path.
function path.ensureLeadingSlash( file_path )
    if string_byte( file_path, 1 ) == 0x2F --[[ / ]] then
        return file_path
    else
        return "/" .. file_path
    end
end

--- [SHARED AND MENU]
---
--- Normalizes the slashes in the file path.
---
---@param file_path string The file path.
---@return string new_file_path The new file path.
function path.normalizeSlashes( file_path )
    return (string_gsub( file_path, "[/\\]+", "/" ))
end

--- [SHARED AND MENU]
---
--- Parse a file path into [root, dir, basename, ext, name, abs] table.
---
---     ┌─────────────────────┬────────────┐
---     │          dir        │    base    │
---     ├──────┬              ├──────┬─────┤
---     │ root │              │ name │ ext │
---     "  /    home/user/dir/  file  .txt "
---     └──────┴──────────────┴──────┴─────┘
--- (All spaces in the "" line should be ignored. They are purely for formatting.)
---
---@param file_path string The file path.
---@return dreamwork.std.path.Data data The parsed file path data.
function path.parse( file_path )
    local is_abs = string_byte( file_path, 1 ) == 0x2F --[[ / ]]
    local directory, base = split( file_path, true )
    local name, ext = splitExtension( base, true )

    return { root = is_abs and "/" or "", dir = directory, base = base, ext = ext, name = name, abs = is_abs }
end

--- [SHARED AND MENU]
---
--- Normalizes a file path by removing all "." and ".." parts.
---
---@param file_path string The file path.
---@param keep_trailing_slash? boolean `true` to keep the trailing slash, `false` otherwise.
---@return string new_file_path The normalized file path.
local function normalize( file_path, keep_trailing_slash )
    local file_path_length = string_len( file_path )
    if file_path_length == 0 then
        return "."
    end

    local has_trailing_slash = string_byte( file_path, file_path_length ) == 0x2F --[[ / ]]
    local is_abs = string_byte( file_path, 1 ) == 0x2F --[[ / ]]

    local segments, segment_count = string_byteSplit( file_path, 0x2F --[[ / ]], is_abs and 2 or 1, has_trailing_slash and (file_path_length - 1) or file_path_length )
    local skip = 0

    for index = segment_count, 1, -1 do
        local uint8_1, uint8_2, uint8_3 = string_byte( segments[ index ], 1, 3 )
        if uint8_2 == nil and uint8_1 == 0x2E --[[ . ]] then
            table_remove( segments, index )
            segment_count = segment_count - 1
        elseif uint8_3 == nil and uint8_1 == 0x2E --[[ . ]] and uint8_2 == 0x2E --[[ . ]] then
            table_remove( segments, index )
            segment_count = segment_count - 1
            skip = skip + 1
        elseif skip > 0 then
            table_remove( segments, index )
            segment_count = segment_count - 1
            skip = skip - 1
        end
    end

    if not is_abs then
        while skip > 0 do
            table_insert( segments, 1, ".." )
            segment_count = segment_count + 1
            skip = skip - 1
        end
    end

    has_trailing_slash = has_trailing_slash and keep_trailing_slash == true

    if segment_count == 0 or (segment_count == 1 and string_byte( segments[ 1 ], 1, 1 ) == nil) then
        if has_trailing_slash then
            return "./"
        elseif is_abs then
            return "/"
        else
            return "."
        end
    end

    local normalized_path = table_concat( segments, "/", 1, segment_count )

    if has_trailing_slash and is_abs then
        return "/" .. normalized_path .. "/"
    elseif has_trailing_slash then
        return normalized_path .. "/"
    elseif is_abs then
        return "/" .. normalized_path
    else
        return normalized_path
    end
end

path.normalize = normalize

do

    local function get( f )
        local fn
        if not isFunction( f ) then
            if f == nil then
                f = 2
            else
                f = f + 1
            end

            ---@type table | nil
            local env = getfenv( f )
            if env ~= nil then
                ---@type dreamwork.std.fs.File | nil
                local file_path = env.__file
                if file_path ~= nil then
                    return file_path.path
                end
            end

            fn = debug_getfmain( f )
        end

        if fn ~= nil then
            local file_path = debug_getfsource( fn )
            if file_path ~= nil then
                return file_path
            end
        end

        return "/workspace/lua/unknown.lua"
    end

    path.get = get

    --- [SHARED AND MENU]
    ---
    --- Resolves a file path to an absolute file path.
    ---
    ---@param file_path string The file path.
    ---@param stack_level? number The stack level to get the directory from.
    ---@return string abs_path The resolved file path.
    local function resolve( file_path, stack_level )
        if string_byte( file_path, 1, 1 ) == 0x2F --[[ / ]] then
            return normalize( file_path, false )
        end

        if stack_level == nil then
            stack_level = 2
        else
            stack_level = stack_level + 1
        end

        return normalize( (getDirectory( get( stack_level ), true ) or "/") .. file_path, false )
    end

    path.resolve = resolve

    do

        local math_min = std.math.min

        --- [SHARED AND MENU]
        ---
        --- Returns the relative path from from to to based on the current working directory.
        ---
        --- If from and to each resolve to the same path (after calling path.resolve() on each), returns "."
        ---
        ---@param from string The path to get the relative path from.
        ---@param to string The path to get the relative path to.
        ---@param stack_level? integer The stack level to get the directory from.
        ---@return string relative_path The relative path.
        function path.relative( from, to, stack_level )
            if stack_level == nil then
                stack_level = 2
            else
                stack_level = stack_level + 1
            end

            local from_path, to_path = resolve( from, stack_level ), resolve( to, stack_level )

            if equals( from_path, to_path ) then
                return "."
            end

            local from_parts, from_part_count = string_byteSplit( from_path, 0x2F --[[ / ]] )
            local to_parts, to_part_count = string_byteSplit( to_path, 0x2F --[[ / ]] )
            local equal_count = 0

            for index = 1, math_min( from_part_count, to_part_count ), 1 do
                if equals( from_parts[ index ], to_parts[ index ] ) then
                    equal_count = equal_count + 1
                else
                    break
                end
            end

            local result_parts, result_part_count = {}, 0
            for _ = equal_count + 1, from_part_count, 1 do
                result_part_count = result_part_count + 1
                result_parts[ result_part_count ] = ".."
            end

            for index = equal_count + 1, to_part_count, 1 do
                result_part_count = result_part_count + 1
                result_parts[ result_part_count ] = to_parts[ index ]
            end

            if result_part_count == 0 then
                return "."
            else
                return table_concat( result_parts, "/", 1, result_part_count )
            end
        end

    end

end

--- [SHARED AND MENU]
---
--- Join the file paths into a single file path and normalize it.
---
---@param segments string[] The file paths to join.
---@param segment_count? integer The number of file paths to join.
---@return string file_path The joined file path.
function path.join( segments, segment_count )
    if segment_count == nil then
        segment_count = len( segments )
    end

    for index = 1, segment_count, 1 do
        local segment = string_trimByte( segments[ index ], 0x2F --[[ / ]] )
        if string_byte( segment, 1, 1 ) == nil then
            segments[ index ] = "."
        else
            segments[ index ] = segment
        end
    end

    return normalize( table_concat( segments, "/", 1, segment_count ) )
end

do

    ---@type table<integer, fun( str: string, position: integer, str_length: integer ): string, integer, boolean>
    local wildcard_handlers = {
        -- ? (question mark)
        [ 0x3F --[[ ? ]] ] = function( str, position, str_length )
            if position == str_length then
                return "[^/]", position, true
            else
                return "[^/]", position + 1, false
            end
        end,
        -- * (asterisk)
        [ 0x2A --[[ * ]] ] = function( str, position, str_length )
            if position == str_length then
                return "[^/]*", position, true
            end

            position = position + 1

            local uint8_1 = string_byte( str, position, position )

            if position == str_length then
                if uint8_1 == 0x2A --[[ * ]] then
                    return ".*", position, true
                else
                    return "[^/]*", position, false
                end
            end

            position = position + 1

            local uint8_2 = string_byte( str, position, position )

            if uint8_2 == 0x2F --[[ / ]] then
                if position == str_length then
                    return ".*%f[^%z/]", position, true
                else
                    return ".*%f[^%z/]", position + 1, false
                end
            elseif uint8_1 == 0x2A --[[ * ]] then
                return ".*", position, false
            else
                return "[^/]*", position - 1, false
            end
        end,
        -- [ ] (square brackets)
        [ 0x5B --[[ [ ]] ] = function( str, position, str_length )
            if position == str_length then
                return "%[", position, true
            end

            local range_start = position
            position = position + 1

            if string_byte( str, position, position ) == 0x5D --[[ ] ]] then
                if position == str_length then
                    return "[]", position, true
                else
                    return "[]", position + 1, false
                end
            elseif position == str_length then
                return "%[", position, false
            end

            local loop_index = range_start + 1

            ::wildcard_range_loop::

            if string_byte( str, loop_index, loop_index ) == 0x5D --[[ ] ]] then
                local range_end = loop_index
                local range_length = range_end - (range_start + 1)

                if range_length == 0 then
                    if range_end == str_length then
                        return "[]", loop_index, true
                    else
                        return "[]", loop_index + 1, false
                    end
                end

                loop_index = range_start + 1

                if range_length == 1 then
                    local uint8_1 = string_byte( str, loop_index, loop_index )

                    local safe_segment = pattern_bytes[ uint8_1 ]
                    if safe_segment == nil then
                        safe_segment = string_char( 0x5B --[[ [ ]], uint8_1, 0x5D --[[ ] ]] )
                    else
                        safe_segment = "[" .. safe_segment .. "]"
                    end

                    if range_end == str_length then
                        return safe_segment, range_end, true
                    else
                        return safe_segment, range_end + 1, false
                    end
                elseif range_length == 2 then
                    local uint8_1 = string_byte( str, loop_index, loop_index )

                    loop_index = loop_index + 1

                    local uint8_2 = string_byte( str, loop_index, loop_index )

                    local safe_segment_1 = pattern_bytes[ uint8_1 ]
                    if safe_segment_1 == nil then
                        safe_segment_1 = string_char( 0x5B --[[ [ ]], uint8_1 )
                    else
                        safe_segment_1 = "[" .. safe_segment_1
                    end

                    local safe_segment_2 = pattern_bytes[ uint8_2 ]
                    if safe_segment_2 == nil then
                        safe_segment_2 = string_char( uint8_2, 0x5D --[[ ] ]] )
                    else
                        safe_segment_2 = safe_segment_2 .. "]"
                    end

                    if range_end == str_length then
                        return safe_segment_1 .. safe_segment_2, range_end, true
                    else
                        return safe_segment_1 .. safe_segment_2, range_end + 1, false
                    end
                end

                range_start = range_start + 1
                range_end = range_end - 1

                local segments, segment_count = { "[" }, 1

                local safe_segment_1, safe_segment_2
                local uint8_1, uint8_2, uint8_3 = 0x00, 0x00, 0x00

                ::wildcard_range_segment_loop::

                uint8_1 = string_byte( str, loop_index, loop_index )

                if loop_index == range_start and (uint8_1 == 0x21 --[[ ! ]] or uint8_1 == 0x5E --[[ ^ ]]) then
                    safe_segment_1 = "^"
                else

                    safe_segment_1 = pattern_bytes[ uint8_1 ]

                    if safe_segment_1 == nil then
                        safe_segment_1 = string_char( uint8_1 )
                    end

                end

                if loop_index == range_end then
                    segment_count = segment_count + 1
                    segments[ segment_count ] = safe_segment_1
                    goto wildcard_range_segment_loop_end
                end

                loop_index = loop_index + 1

                uint8_2 = string_byte( str, loop_index, loop_index )
                if uint8_2 == 0x2D --[[ - ]] and loop_index ~= range_end then
                    if loop_index == range_end then
                        segment_count = segment_count + 1
                        segments[ segment_count ] = safe_segment_1 .. "%-"
                        goto wildcard_range_segment_loop_end
                    end

                    loop_index = loop_index + 1

                    uint8_3 = string_byte( str, loop_index, loop_index )

                    safe_segment_2 = pattern_bytes[ uint8_3 ]
                    if safe_segment_2 == nil then
                        safe_segment_2 = string_char( uint8_3 )
                    end

                    segment_count = segment_count + 1
                    segments[ segment_count ] = safe_segment_1 .. "-" .. safe_segment_2

                    if loop_index == range_end then
                        goto wildcard_range_segment_loop_end
                    end

                    loop_index = loop_index + 1
                    goto wildcard_range_segment_loop
                end

                safe_segment_2 = pattern_bytes[ uint8_2 ]
                if safe_segment_2 == nil then
                    safe_segment_2 = string_char( uint8_2 )
                end

                segment_count = segment_count + 1
                segments[ segment_count ] = safe_segment_1 .. safe_segment_2

                if loop_index ~= range_end then
                    loop_index = loop_index + 1
                    goto wildcard_range_segment_loop
                end

                ::wildcard_range_segment_loop_end::

                segment_count = segment_count + 1
                segments[ segment_count ] = "]"

                range_end = range_end + 1

                if range_end == str_length then
                    return table_concat( segments, "", 1, segment_count ), range_end, true
                else
                    return table_concat( segments, "", 1, segment_count ), range_end + 1, false
                end
            end

            if loop_index == str_length then
                return "%[", range_start + 1, false
            end

            loop_index = loop_index + 1
            ---@diagnostic disable-next-line: missing-return
            goto wildcard_range_loop
        end,
        -- { } (curly brackets) - not supported
        -- \ (backslash)
        [ 0x5C --[[ \ ]] ] = function( str, position, str_length )
            if position == str_length then
                return "\\", position, true
            end

            position = position + 1

            local uint8_1 = string_byte( str, position, position )

            local safe_segment_1 = pattern_bytes[ uint8_1 ]
            if safe_segment_1 == nil then
                safe_segment_1 = string_char( 0x5C --[[ \ ]], uint8_1 )
            end

            if position == str_length then
                return safe_segment_1, position, true
            else
                return safe_segment_1, position + 1, false
            end
        end
    }

    --- [SHARED AND MENU]
    ---
    --- Converts a wildcard string to a Lua pattern.
    ---
    ---@param wildcard_str string The path wildcard string.
    ---@param anchor_to_slash? boolean If set to `true`, the pattern will be anchored to the first slash.
    ---@return string pattern_str The Lua pattern that represents the wildcard string.
    function path.wildcard( wildcard_str, anchor_to_slash )
        if string_byte( wildcard_str, 1, 1 ) == nil then
            return wildcard_str
        end

        local str_length = string_len( wildcard_str )
        local break_position = 1
        local position = 1

        local segments, segment_count = { anchor_to_slash and "%f[^%z/]" or "^" }, 1
        local segment, is_last

        ::wildcard_loop_start::

        local uint8_1 = string_byte( wildcard_str, position, position )

        local wildcard_handler = wildcard_handlers[ uint8_1 ]
        if wildcard_handler ~= nil then
            if break_position ~= position then
                segment_count = segment_count + 1
                segments[ segment_count ] = string_sub( wildcard_str, break_position, position - 1 )
            end

            segment, position, is_last = wildcard_handler( wildcard_str, position, str_length )
            break_position = position

            if segment ~= nil then
                segment_count = segment_count + 1
                segments[ segment_count ] = segment
            end

            if is_last then
                goto wildcard_loop_end
            else
                goto wildcard_loop_start
            end
        end

        segment = pattern_bytes[ uint8_1 ]
        if segment ~= nil then
            if break_position ~= position then
                segment_count = segment_count + 1
                segments[ segment_count ] = string_sub( wildcard_str, break_position, position - 1 )
            end

            segment_count = segment_count + 1
            segments[ segment_count ] = segment

            if position == str_length then
                break_position = position
                goto wildcard_loop_end
            end

            position = position + 1
            break_position = position
            goto wildcard_loop_start
        end

        if position ~= str_length then
            position = position + 1
            goto wildcard_loop_start
        end

        ::wildcard_loop_end::

        if break_position ~= position then
            segment_count = segment_count + 1
            segments[ segment_count ] = string_sub( wildcard_str, break_position, str_length )
        end

        if segment_count == 1 then
            return ""
        end

        segment_count = segment_count + 1
        segments[ segment_count ] = "$"

        return table_concat( segments, "", 1, segment_count )
    end

end

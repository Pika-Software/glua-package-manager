local std = dreamwork.std

local math = std.math
local math_min = math.min
local math_relative = math.relative

local string = std.string
local string_len = string.len
local string_sub = string.sub
local string_byte = string.byte

local isTable = std.isTable

---@class dreamwork.std.table
local table = std.table

--- [SHARED AND MENU]
---
--- Returns the value of the given key path.
---
--- If the key path does not exist, returns `nil`.
---
--- Example:
---
--- ```lua
---     local t = { a = { b = { c = { d = { e = "e value!" } } } } }
---     print( table.get( t, "a.b.c.d.e" ) ) -- e value!
--- ```
---
---@param tbl table The table to get the value from.
---@param str string The key path to get.
---@param separator? integer The separator of the key path, default is `0x2E`.
---@return any value The value of the key path.
function table.get( tbl, str, separator, start_position, end_position )
    if separator == nil then
        separator = 0x2E --[[ "." ]]
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

    if start_position > end_position then
        return nil
    end

    local split_position = start_position - 1

    ::table_lookup_loop::

    if string_byte( str, start_position, start_position ) == separator then
        if split_position ~= start_position then
            tbl = tbl[ string_sub( str, split_position + 1, start_position - 1 ) ]
            if tbl == nil then return nil end
        end

        split_position = start_position
    end

    if start_position ~= end_position then
        start_position = start_position + 1
        goto table_lookup_loop
    end

    if split_position ~= start_position then
        tbl = tbl[ string_sub( str, split_position + 1, start_position ) ]
    end

    return tbl
end

--- [SHARED AND MENU]
---
--- Sets the value of the given key path.
---
--- Tables are created if they do not exist.
---
--- Example:
---
--- ```lua
---     local t = {}
---     table.set( t, "a.b.c.d.e", "e value!" )
---     print( t.a.b.c.d.e ) -- e value!
--- ```
---
---@param tbl table The table to set the value in.
---@param str string The key path.
---@param value any The value to set.
---@param separator? integer The separator of the key path, default is `0x2E`.
function table.set( tbl, str, value, separator )
    if separator == nil then
        separator = 0x2E --[[ "." ]]
    end

    local str_length = string_len( str )

    local split_position = 0
    local position = 1

    while true do
        local uint8 = string_byte( str, position, position )
        if uint8 == separator then
            if split_position ~= position then
                local key = string_sub( str, split_position + 1, position - 1 )

                if position == str_length then
                    tbl[ key ] = value
                    return
                end

                local tbl_value = tbl[ key ]
                if tbl_value ~= nil and isTable( tbl_value ) then
                    tbl = tbl_value
                else
                    local new_tbl = {}
                    tbl[ key ] = new_tbl
                    tbl = new_tbl
                end
            end

            split_position = position
        end

        if position == str_length then
            break
        else
            position = position + 1
        end
    end

    if split_position ~= position then
        tbl[ string_sub( str, split_position + 1, position ) ] = value
    end
end

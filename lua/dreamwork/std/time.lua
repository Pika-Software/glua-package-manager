---@class dreamwork.std
local std = dreamwork.std

local raw = std.raw
local raw_get = raw.get
local raw_tonumber = raw.tonumber

local rbit = raw.bit
local rbit_bor = rbit.bor
local rbit_lshift = rbit.lshift

local math = std.math
local math_floor = math.floor

local os = std.os
local os_time = os.time
local os_date = os.date

local table = std.table
local table_concat = table.concat

local string = std.string
local string_byte = string.byte
local string_format = string.format
local string_gmatch = string.gmatch
local string_byteSplit = string.byteSplit
local string_interpolate = string.interpolate

local error = std.error


--- [SHARED AND MENU]
---
--- A library for working with time and date.
---
---@class dreamwork.std.time
---@field zone integer The timezone offset from UTC.
---@field dst boolean Whether the timezone is currently in daylight saving time.
---@field zone_dst integer The timezone offset from UTC during daylight saving time.
local time = {}
std.time = time

---@type integer
local zone = raw_tonumber( os_date( "%H", 0 ) ) - raw_tonumber( os_date( "!%H", 0 ) )
if (os_date( "%d", 0 ) - os_date( "!%d", 0 )) == 30 then
    zone = zone - 24
end

time.zone = zone
time.dst = ((raw_tonumber( os_date( "%z" ) ) * 0.01) - zone) ~= 0
time.zone_dst = zone + (time.dst and 1 or 0)

---@alias dreamwork.std.time.Unit
---| "ns" Nanoseconds
---| "us" Microseconds
---| "ms" Milliseconds
---| "s" Seconds
---| "m" Minutes
---| "h" Hours
---| "d" Days
---| "w" Weeks
---| "mo" Months
---| "y" Years

---@alias dreamwork.std.time.Duration
---| "1ms 1us 1ns" One millisecond, one microsecond and one nanosecond.
---| "1h 1m 1s" One hour, one minute and one second.
---| "1y 1w 1d" One year, one week and one day.
---| "1w 1d" One week and one day.
---| "1y" One year.
---| string

local transform
do

    ---@type table<integer, fun( ts: number ): number>
    local transformation_map

    do

        local function ts_m1e_3( ts )
            return ts * 1e-3
        end

        local function ts_m1e_6( ts )
            return ts * 1e-6
        end

        local function ts_m1e3( ts )
            return ts * 1e3
        end

        local function ts_m1e6( ts )
            return ts * 1e6
        end

        local function ts_d60( ts )
            return ts / 60
        end

        transformation_map = {
            -- ns -> other
            [ 0x7375736E ] = ts_m1e_3,                                         -- ns to us
            [ 0x736D736E ] = ts_m1e_6,                                         -- ns to ms
            [ 0x73736E ]   = function( ts ) return ts * 1e-9 end,              -- ns to s
            [ 0x6D736E ]   = function( ts ) return (ts * 1e-9) / 60 end,       -- ns to m
            [ 0x68736E ]   = function( ts ) return (ts * 1e-9) / 3600 end,     -- ns to h
            [ 0x64736E ]   = function( ts ) return (ts * 1e-9) / 86400 end,    -- ns to d
            [ 0x77736E ]   = function( ts ) return (ts * 1e-9) / 604800 end,   -- ns to w
            [ 0x6F6D736E ] = function( ts ) return (ts * 1e-9) / 2592000 end,  -- ns to mo
            [ 0x79736E ]   = function( ts ) return (ts * 1e-9) / 31536000 end, -- ns to y

            -- us -> other
            [ 0x736E7375 ] = ts_m1e3,                                          -- us to ns
            [ 0x736D7375 ] = ts_m1e_3,                                         -- us to ms
            [ 0x737375 ]   = ts_m1e_6,                                         -- us to s
            [ 0x6D7375 ]   = function( ts ) return (ts * 1e-6) / 60 end,       -- us to m
            [ 0x687375 ]   = function( ts ) return (ts * 1e-6) / 3600 end,     -- us to h
            [ 0x647375 ]   = function( ts ) return (ts * 1e-6) / 86400 end,    -- us to d
            [ 0x777375 ]   = function( ts ) return (ts * 1e-6) / 604800 end,   -- us to w
            [ 0x6F6D7375 ] = function( ts ) return (ts * 1e-6) / 2592000 end,  -- us to mo
            [ 0x797375 ]   = function( ts ) return (ts * 1e-6) / 31536000 end, -- us to y

            -- ms -> other
            [ 0x736E736D ] = ts_m1e6,                                          -- ms to ns
            [ 0x7375736D ] = ts_m1e3,                                          -- ms to us
            [ 0x73736D ]   = ts_m1e_3,                                         -- ms to s
            [ 0x6D736D ]   = function( ts ) return (ts * 1e-3) / 60 end,       -- ms to m
            [ 0x68736D ]   = function( ts ) return (ts * 1e-3) / 3600 end,     -- ms to h
            [ 0x64736D ]   = function( ts ) return (ts * 1e-3) / 86400 end,    -- ms to d
            [ 0x77736D ]   = function( ts ) return (ts * 1e-3) / 604800 end,   -- ms to w
            [ 0x6F6D736D ] = function( ts ) return (ts * 1e-3) / 2592000 end,  -- ms to mo
            [ 0x79736D ]   = function( ts ) return (ts * 1e-3) / 31536000 end, -- ms to y

            -- s -> other
            [ 0x736E0073 ] = function( ts ) return ts * 1e9 end,      -- s to ns
            [ 0x73750073 ] = ts_m1e6,                                 -- s to us
            [ 0x736D0073 ] = ts_m1e3,                                 -- s to ms
            [ 0x6D0073 ]   = ts_d60,                                  -- s to m
            [ 0x680073 ]   = function( ts ) return ts / 3600 end,     -- s to h
            [ 0x640073 ]   = function( ts ) return ts / 86400 end,    -- s to d
            [ 0x770073 ]   = function( ts ) return ts / 604800 end,   -- s to w
            [ 0x6F6D0073 ] = function( ts ) return ts / 2592000 end,  -- s to mo
            [ 0x790073 ]   = function( ts ) return ts / 31536000 end, -- s to y

            -- m -> other
            [ 0x736E006D ] = function( ts ) return (ts * 60) * 1e9 end, -- m to ns
            [ 0x7375006D ] = function( ts ) return (ts * 60) * 1e6 end, -- m to us
            [ 0x736D006D ] = function( ts ) return (ts * 60) * 1e3 end, -- m to ms
            [ 0x73006D ]   = function( ts ) return (ts * 60) end,       -- m to s
            [ 0x68006D ]   = ts_d60,                                    -- m to h
            [ 0x64006D ]   = function( ts ) return ts / 1440 end,       -- m to d
            [ 0x77006D ]   = function( ts ) return ts / 10080 end,      -- m to w
            [ 0x6F6D006D ] = function( ts ) return ts / 43200 end,      -- m to mo
            [ 0x79006D ]   = function( ts ) return ts / 525600 end,     -- m to y

            -- h -> other
            [ 0x736E0068 ] = function( ts ) return (ts * 3600) * 1e9 end, -- h to ns
            [ 0x73750068 ] = function( ts ) return (ts * 3600) * 1e6 end, -- h to us
            [ 0x736D0068 ] = function( ts ) return (ts * 3600) * 1e3 end, -- h to ms
            [ 0x730068 ]   = function( ts ) return (ts * 3600) end,       -- h to s
            [ 0x6D0068 ]   = function( ts ) return (ts * 60) end,         -- h to m
            [ 0x640068 ]   = function( ts ) return ts / 24 end,           -- h to d
            [ 0x770068 ]   = function( ts ) return ts / 168 end,          -- h to w
            [ 0x6F6D0068 ] = function( ts ) return ts / 720 end,          -- h to mo
            [ 0x790068 ]   = function( ts ) return ts / 8760 end,         -- h to y

            -- d -> other
            [ 0x736E0064 ] = function( ts ) return (ts * 86400) * 1e9 end, -- d to ns
            [ 0x73750064 ] = function( ts ) return (ts * 86400) * 1e6 end, -- d to us
            [ 0x736D0064 ] = function( ts ) return (ts * 86400) * 1e3 end, -- d to ms
            [ 0x730064 ]   = function( ts ) return (ts * 86400) end,       -- d to s
            [ 0x6D0064 ]   = function( ts ) return ts * 1440 end,          -- d to m
            [ 0x680064 ]   = function( ts ) return ts * 24 end,            -- d to h
            [ 0x770064 ]   = function( ts ) return ts / 7 end,             -- d to w
            [ 0x6F6D0064 ] = function( ts ) return ts / 30 end,            -- d to mo
            [ 0x790064 ]   = function( ts ) return ts / 365 end,           -- d to y

            -- w -> other
            [ 0x736E0077 ] = function( ts ) return (ts * 604800) * 1e9 end, -- w to ns
            [ 0x73750077 ] = function( ts ) return (ts * 604800) * 1e6 end, -- w to us
            [ 0x736D0077 ] = function( ts ) return (ts * 604800) * 1e3 end, -- w to ms
            [ 0x730077 ]   = function( ts ) return (ts * 604800) end,       -- w to s
            [ 0x6D0077 ]   = function( ts ) return ts * 10080 end,          -- w to m
            [ 0x680077 ]   = function( ts ) return ts * 168 end,            -- w to h
            [ 0x640077 ]   = function( ts ) return ts * 7 end,              -- w to d
            [ 0x6F6D0077 ] = function( ts ) return ts / 4.285714286 end,    -- w to mo
            [ 0x790077 ]   = function( ts ) return ts / 52.142857143 end,   -- w to y

            -- mo -> other
            [ 0x736E6F6D ] = function( ts ) return (ts * 2592000) * 1e9 end, -- mo to ns
            [ 0x73756F6D ] = function( ts ) return (ts * 2592000) * 1e6 end, -- mo to us
            [ 0x736D6F6D ] = function( ts ) return (ts * 2592000) * 1e3 end, -- mo to ms
            [ 0x736F6D ]   = function( ts ) return (ts * 2592000) end,       -- mo to s
            [ 0x6D6F6D ]   = function( ts ) return ts * 43200 end,           -- mo to m
            [ 0x686F6D ]   = function( ts ) return ts * 720 end,             -- mo to h
            [ 0x646F6D ]   = function( ts ) return ts * 30 end,              -- mo to d
            [ 0x776F6D ]   = function( ts ) return ts * 4.285714286 end,     -- mo to w
            [ 0x796F6D ]   = function( ts ) return ts / 12 end,              -- mo to y

            -- y -> other
            [ 0x736E0079 ] = function( ts ) return (ts * 31536000) * 1e9 end, -- y to ns
            [ 0x73750079 ] = function( ts ) return (ts * 31536000) * 1e6 end, -- y to us
            [ 0x736D0079 ] = function( ts ) return (ts * 31536000) * 1e3 end, -- y to ms
            [ 0x730079 ]   = function( ts ) return (ts * 31536000) end,       -- y to s
            [ 0x6D0079 ]   = function( ts ) return ts * 525600 end,           -- y to m
            [ 0x680079 ]   = function( ts ) return ts * 8760 end,             -- y to h
            [ 0x640079 ]   = function( ts ) return ts * 365 end,              -- y to d
            [ 0x770079 ]   = function( ts ) return ts * 52.142857143 end,     -- y to w
            [ 0x6F6D0079 ] = function( ts ) return ts * 12 end                -- y to mo
        }

    end

    --- [SHARED AND MENU]
    ---
    --- Transforms a timestamp from one unit to another.
    ---
    ---@param timestamp integer The timestamp to transform.
    ---@param unit? dreamwork.std.time.Unit The unit to transform the timestamp from, 's' by default.
    ---@param target? dreamwork.std.time.Unit The unit to transform the timestamp to, 's' by default.
    ---@param as_float? boolean Whether to return the timestamp as a float, `false` by default.
    ---@param error_level? integer The error level to use, 2 by default.
    ---@return number timestamp The transformed timestamp.
    function transform( timestamp, unit, target, as_float, error_level )
        local unit_uint8_1, unit_uint8_2
        if unit == nil then
            unit_uint8_1, unit_uint8_2 = 0x73 --[[ `s` ]], 0x0
        else

            unit_uint8_1, unit_uint8_2 = string_byte( unit, 1, 2 )

            if unit_uint8_1 == nil then
                error( "unit cannot be empty string", (error_level or 1) + 1 )
            end

            if unit_uint8_2 == nil then
                unit_uint8_2 = 0x0
            end

        end

        local target_uint8_1, target_uint8_2
        if target == nil then
            target_uint8_1, target_uint8_2 = 0x73 --[[ `s` ]], 0x0
        else

            target_uint8_1, target_uint8_2 = string_byte( target, 1, 2 )

            if target_uint8_1 == nil then
                error( "target cannot be empty string", (error_level or 1) + 1 )
            elseif target_uint8_2 == nil then
                target_uint8_2 = 0x0
            end

        end

        ---@cast target_uint8_1 integer

        if unit_uint8_1 ~= target_uint8_1 or unit_uint8_2 ~= target_uint8_2 then
            local transform_fn = transformation_map[ rbit_bor(
                rbit_lshift( target_uint8_2, 24 ),
                rbit_lshift( target_uint8_1, 16 ),
                rbit_lshift( unit_uint8_2, 8 ),
                unit_uint8_1
            ) ]

            if transform_fn == nil then
                error( "unknown transformation from '" .. unit .. "' to '" .. target .. "'", (error_level or 1) + 1 )
            end

            ---@cast transform_fn fun( ts: number ): number
            timestamp = transform_fn( timestamp )
        end

        if as_float then
            return timestamp
        end

        return math_floor( timestamp )
    end

end

--- [SHARED AND MENU]
---
--- Transforms a timestamp to a different unit.
---
---@param timestamp integer The timestamp to transform.
---@param unit? dreamwork.std.time.Unit The unit to transform the timestamp from, 's' by default.
---@param target? dreamwork.std.time.Unit The unit to transform the timestamp to, 's' by default.
---@param as_float? boolean Whether to return the timestamp as a float, `false` by default.
---@return integer
function time.transform( timestamp, unit, target, as_float )
    return transform( timestamp, unit, target, as_float, 2 )
end

---@diagnostic disable-next-line: undefined-global
local milliseconds_elapsed = SysTime or os.clock

--- [SHARED AND MENU]
---
--- Returns the time elapsed since lua/game was started.
---
---@param unit? dreamwork.std.time.Unit The unit to return the elapsed time in, 's' by default.
---@param as_float? boolean Whether to return the elapsed time as a float, `true` by default.
---@return number timestamp The elapsed time in the specified unit.
function time.elapsed( unit, as_float )
    if unit == "ns" then
        local float = milliseconds_elapsed() * 1e9
        if as_float ~= false then
            return float
        else
            return math_floor( float )
        end
    elseif unit == "us" then
        local float = milliseconds_elapsed() * 1e6
        if as_float ~= false then
            return float
        else
            return math_floor( float )
        end
    elseif unit == "ms" then
        local float = milliseconds_elapsed() * 1e3
        if as_float ~= false then
            return float
        else
            return math_floor( float )
        end
    elseif unit == "s" or unit == nil then
        local float = milliseconds_elapsed()
        if as_float ~= false then
            return float
        else
            return math_floor( float )
        end
    end

    return transform( milliseconds_elapsed(), "s", unit, as_float ~= false, 2 )
end

do

    ---@type number
    local previous = 0

    --- [SHARED AND MENU]
    ---
    --- Returns the time elapsed since the last call to this function.
    ---
    ---@param unit? dreamwork.std.time.Unit The unit to return the elapsed time in, 's' by default.
    ---@param as_float? boolean Whether to return the elapsed time as a float, `true` by default.
    ---@return number delta The elapsed time in the specified unit.
    function time.tick( unit, as_float )
        local elapsed = milliseconds_elapsed()

        local delta = transform( elapsed - previous, nil, unit, as_float ~= false, 2 )
        previous = elapsed

        return delta
    end

end

--- [SHARED AND MENU]
---
--- Returns the current time in the specified unit.
---
---@param unit? dreamwork.std.time.Unit The unit to return the current time in, `s` by default.
---@param as_float? boolean Whether to return the timestamp as a float, `false` by default.
---@return integer | number timestamp The current timestamp in the specified unit.
local function now( unit, as_float )
    local timestamp = os_time()

    local current_timezone = time.zone
    if current_timezone ~= zone then
        timestamp = timestamp + (current_timezone - zone) * 3600
    end

    if not as_float and (unit == nil or unit == "s") then
        return timestamp
    end

    return transform( timestamp + (milliseconds_elapsed() % 1), nil, unit, as_float, 2 )
end

time.now = now

do

    --- [SHARED AND MENU]
    ---
    --- Checks if a year is a leap year.
    ---
    ---@param year? integer The year to check, the current year by default.
    ---@return boolean is_leap_year Returns `true` if the year is a leap year, otherwise `false`.
    local function is_leap_year( year )
        if year == nil then
            year = now() / 31536000
        end

        return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
    end

    -- based on https://github.com/Nak2/NikNaks/blob/c0686a65a3bd4b30e0c683b07a9822a11fd54d83/lua/niknaks/modules/sh_datetime.lua#L23-L25
    time.isLeapYear = is_leap_year

    -- based on https://github.com/Nak2/NikNaks/blob/c0686a65a3bd4b30e0c683b07a9822a11fd54d83/lua/niknaks/modules/sh_datetime.lua#L41-L48
    do

        local months = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

        --- [SHARED AND MENU]
        ---
        --- Returns the number of days in a month.
        ---
        ---@param month? integer The month to get the number of days in, the current month by default.
        ---@param year? integer The year to get the number of days in, the current year by default.
        ---@return integer days_in_month The number of days in the month.
        function time.daysInMonth( month, year )
            if month == nil then
                month = math_floor( now() / 86400 )
            end

            month = (month - 1) % 12 + 1

            if year == nil then
                year = 1970 + math_floor( now() / 31536000 )
            end

            if month == 2 and is_leap_year( year ) then
                return 29
            else
                return months[ month ]
            end
        end

    end

end

do

    ---@param duration_str dreamwork.std.time.Duration The duration string to convert.
    ---@param unit? dreamwork.std.time.Unit The unit to convert the duration to, 's' by default.
    ---@param as_float? boolean Whether to return the duration as a float, `false` by default.
    ---@param error_level? integer The error level to use, 2 by default.
    ---@return integer timestamp The duration in the specified unit.
    local function fromDuration( duration_str, unit, as_float, error_level )
        local seconds, milliseconds, microseconds, nanoseconds = 0, 0, 0, 0

        for number_str, unit_str in string_gmatch( duration_str, "(%-?%d+%.?%d*)(%l*)" ) do
            local integer = raw_tonumber( number_str, 10 ) or 0

            if unit_str == "s" then
                seconds = seconds + integer
            elseif unit_str == "ms" then
                milliseconds = milliseconds + integer
            elseif unit_str == "us" then
                microseconds = microseconds + integer
            elseif unit_str == "ns" then
                nanoseconds = nanoseconds + integer
            else
                seconds = seconds + transform( integer, unit_str, "s", as_float, (error_level or 1) + 1 )
            end
        end

        if unit == "ms" then
            local float = seconds * 1e3 + milliseconds + microseconds * 1e-3 + nanoseconds * 1e-6

            if as_float then
                return float
            else
                return math_floor( float )
            end
        elseif unit == "us" then
            local float = seconds * 1e6 + milliseconds * 1e3 + microseconds + nanoseconds * 1e-3

            if as_float then
                return float
            else
                return math_floor( float )
            end
        elseif unit == "ns" then
            local float = seconds * 1e9 + milliseconds * 1e6 + microseconds * 1e3 + nanoseconds

            if as_float then
                return float
            else
                return math_floor( float )
            end
        end

        return transform( seconds + nanoseconds * 1e-9 + microseconds * 1e-6 + milliseconds * 1e-3, nil, unit, as_float, 2 )
    end

    --- [SHARED AND MENU]
    ---
    --- Converts a duration string to the specified unit.
    ---
    --- The duration string can have the following units: `ns`, `us`, `ms`, `s`, `m`, `h`, `d`, `w`, `y`.
    ---
    --- | Suffix | Name         | Value                         |
    --- |--------|--------------|-------------------------------|
    --- | `ns`     | Nanosecond   | 1 / 1,000,000,000 seconds   |
    --- | `us`     | Microsecond  | 1 / 1,000,000 seconds       |
    --- | `ms`     | Millisecond  | 1 / 1,000 seconds           |
    --- | `s`      | Second       | 1 second                    |
    --- | `m`      | Minute       | 60 seconds                  |
    --- | `h`      | Hour         | 60 minutes                  |
    --- | `d`      | Day          | 24 hours                    |
    --- | `w`      | Week         | 7 days                      |
    --- | `mo`     | Month        | ~30 days                    |
    --- | `y`      | Year         | 365 days                    |
    ---
    ---@param duration_str dreamwork.std.time.Duration The duration string to convert.
    ---@param unit? dreamwork.std.time.Unit The unit to convert the duration to, 's' by default.
    ---@param as_float? boolean Whether to return the duration as a float, `false` by default.
    ---@return integer timestamp The duration in the specified unit.
    function time.fromDuration( duration_str, unit, as_float )
        return fromDuration( duration_str, unit, as_float, 2 )
    end

    --- [SHARED AND MENU]
    ---
    --- Adds a duration to a timestamp.
    ---
    --- The duration string can have the following units:
    --- `ns`, `us`, `ms`, `s`, `m`, `h`, `d`, `w`, `y`.
    ---
    --- | Suffix | Name         | Value                         |
    --- |--------|--------------|-------------------------------|
    --- | `ns`     | Nanosecond   | 1 / 1,000,000,000 seconds   |
    --- | `us`     | Microsecond  | 1 / 1,000,000 seconds       |
    --- | `ms`     | Millisecond  | 1 / 1,000 seconds           |
    --- | `s`      | Second       | 1 second                    |
    --- | `m`      | Minute       | 60 seconds                  |
    --- | `h`      | Hour         | 60 minutes                  |
    --- | `d`      | Day          | 24 hours                    |
    --- | `w`      | Week         | 7 days                      |
    --- | `mo`     | Month        | ~30 days                    |
    --- | `y`      | Year         | 365 days                    |
    ---
    ---@param timestamp integer The timestamp to add the duration to.
    ---@param unit? dreamwork.std.time.Unit The unit to add the duration to, 's' by default.
    ---@param duration_str dreamwork.std.time.Duration The duration string to add.
    ---@param as_float? boolean Whether to return the timestamp as a float, `false` by default.
    ---@return integer
    function time.add( timestamp, unit, duration_str, as_float )
        return timestamp + fromDuration( duration_str, unit, as_float, 2 )
    end

    --- [SHARED AND MENU]
    ---
    --- Subtracts a duration from a timestamp.
    ---
    --- The duration string can have the following units: `ns`, `us`, `ms`, `s`, `m`, `h`, `d`, `w`, `y`.
    ---
    --- | Suffix | Name         | Value                         |
    --- |--------|--------------|-------------------------------|
    --- | `ns`     | Nanosecond   | 1 / 1,000,000,000 seconds   |
    --- | `us`     | Microsecond  | 1 / 1,000,000 seconds       |
    --- | `ms`     | Millisecond  | 1 / 1,000 seconds           |
    --- | `s`      | Second       | 1 second                    |
    --- | `m`      | Minute       | 60 seconds                  |
    --- | `h`      | Hour         | 60 minutes                  |
    --- | `d`      | Day          | 24 hours                    |
    --- | `w`      | Week         | 7 days                      |
    --- | `mo`     | Month        | ~30 days                    |
    --- | `y`      | Year         | 365 days                    |
    ---
    ---@param timestamp integer The timestamp to subtract the duration from.
    ---@param unit? dreamwork.std.time.Unit The unit to subtract the duration from, 's' by default.
    ---@param duration_str dreamwork.std.time.Duration The duration string to subtract.
    ---@param as_float? boolean Whether to return the timestamp as a float, `false` by default.
    ---@return integer
    function time.sub( timestamp, unit, duration_str, as_float )
        return timestamp - fromDuration( duration_str, unit, as_float, 2 )
    end

end

--- [SHARED AND MENU]
---
--- Splits a timestamp into seconds, milliseconds, microseconds and nanoseconds.
---
---@param timestamp integer
---@param unit? dreamwork.std.time.Unit
---@param error_level? integer
---@return integer seconds
---@return integer milliseconds
---@return integer microseconds
---@return integer nanoseconds
local function split( timestamp, unit, error_level )
    error_level = (error_level or 1) + 1

    local seconds = transform( timestamp, unit, "s", false, error_level )
    timestamp = timestamp - transform( seconds, "s", unit, true, error_level )

    local milliseconds = transform( timestamp, unit, "ms", false, error_level )
    timestamp = timestamp - transform( milliseconds, "ms", unit, true, error_level )

    local microseconds = transform( timestamp, unit, "us", false, error_level )
    timestamp = timestamp - transform( microseconds, "us", unit, true, error_level )

    return seconds, milliseconds, microseconds, transform( timestamp, unit, "ns", false, error_level )
end

--- [SHARED AND MENU]
---
--- Represents a date and time.
---
---@class dreamwork.std.time.Date
---@field is_dst boolean Is the date in summer time (daylight saving)?
---@field week_day integer The day of the week.
---@field milliseconds integer The number of milliseconds.
---@field microseconds integer The number of microseconds.
---@field nanoseconds integer The number of nanoseconds.
---@field hours12 integer The number of hours in 12-hour format.
---@field hours integer The number of hours.
---@field minutes integer The number of minutes.
---@field seconds integer The number of seconds.
---@field period "AM" | "PM" The period of the day.
---@field day integer The day of the month.
---@field month integer The month of the year.
---@field year integer The year.
---@field year_day integer The day of the year.
---@field year_week integer The week number of the year.

do

    --- [SHARED AND MENU]
    ---
    --- Returns a table with the date and time components.
    ---
    ---@param timestamp? integer The timestamp to parse.
    ---@param unit? dreamwork.std.time.Unit The unit to parse the timestamp from, 's' by default.
    ---@param in_utc? boolean Whether the timestamp is in UTC, `false` by default.
    ---@return dreamwork.std.time.Date date_tbl The date and time components.
    function time.parse( timestamp, unit, in_utc )
        local seconds, milliseconds, microseconds, nanoseconds = split( timestamp or now( unit, true ), unit, 2 )
        in_utc = in_utc == true

        local tbl = os_date( in_utc and "!*t" or "*t", seconds )
        ---@cast tbl table

        tbl.is_dst = tbl.isdst
        tbl.isdst = nil

        tbl.week_day = (tbl.wday + 5) % 7 + 1
        tbl.wday = nil

        tbl.year_day = tbl.yday
        tbl.yday = nil

        tbl.milliseconds = milliseconds or 0
        tbl.microseconds = microseconds or 0
        tbl.nanoseconds = nanoseconds or 0

        tbl.hours = tbl.hour
        tbl.hour = nil

        tbl.minutes = tbl.min
        tbl.min = nil

        tbl.seconds = tbl.sec
        tbl.sec = nil

        ---@diagnostic disable-next-line: param-type-mismatch
        local values = string_byteSplit( os_date( in_utc and "!%I;%p;%W" or "%I;%p;%W", seconds ), 0x3B --[[ ";" ]] )

        tbl.hours12 = tonumber( values[ 1 ], 10 ) or 0
        tbl.period = values[ 2 ] or "AM"

        tbl.year_week = (tonumber( values[ 3 ], 10 ) or 0) + 1

        return tbl
    end

end


local duration_units = {
    { 31536000, "y" },
    { 2592000,  "mo" },
    { 604800,   "w" },
    { 86400,    "d" },
    { 3600,     "h" },
    { 60,       "m" }
}

--- [SHARED AND MENU]
---
--- Converts a number of seconds to a duration string.
---
--- The duration string can have the following units: `ns`, `us`, `ms`, `s`, `m`, `h`, `d`, `w`, `y`.
---
--- | Suffix | Name         | Value                         |
--- |--------|--------------|-------------------------------|
--- | `ns`     | Nanosecond   | 1 / 1,000,000,000 seconds     |
--- | `us`     | Microsecond  | 1 / 1,000,000 seconds         |
--- | `ms`     | Millisecond  | 1 / 1,000 seconds             |
--- | `s`      | Second       | 1 second                      |
--- | `m`      | Minute       | 60 seconds                    |
--- | `h`      | Hour         | 60 minutes                    |
--- | `d`      | Day          | 24 hours                      |
--- | `w`      | Week         | 7 days                        |
--- | `mo`     | Month        | ~30 days                      |
--- | `y`      | Year         | 365 days                      |
---
---@param timestamp integer The timestamp to convert.
---@param unit? dreamwork.std.time.Unit The unit to convert the timestamp to, 's' by default.
---@return string duration_str The duration string.
function time.toDuration( timestamp, unit )
    local seconds, milliseconds, microseconds, nanoseconds = split( timestamp, unit, 2 )
    local segments, segment_count = {}, 0

    if seconds ~= 0 then

        for i = 1, 6, 1 do
            local lst = duration_units[ i ]

            local value = lst[ 1 ]
            if seconds >= value then
                local count = math_floor( seconds / value )
                seconds = seconds - (count * value)

                segment_count = segment_count + 1
                segments[ segment_count ] = string_format( "%d%s", count, lst[ 2 ] )
            end

            if seconds <= 0 then
                break
            end
        end

    end

    if seconds ~= 0 then
        local second_count = math_floor( seconds )
        if second_count > 0 then
            seconds = seconds - second_count

            segment_count = segment_count + 1
            segments[ segment_count ] = string_format( "%ds", second_count )
        end
    end

    if milliseconds ~= 0 then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_format( "%03dms", milliseconds )
    end

    if microseconds ~= 0 then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_format( "%03dus", microseconds )
    end

    if nanoseconds ~= 0 then
        segment_count = segment_count + 1
        segments[ segment_count ] = string_format( "%03dns", nanoseconds )
    end

    if segment_count == 0 then
        return "0s"
    else
        return table_concat( segments, " ", 1, segment_count )
    end
end

---@type table<string, string>
local keys = {
    -- %d	Day of the month [01-31]	16
    day = "%d",
    -- %m	Month [01-12]	09
    month = "%m",
    -- %B	Full month name	September
    month_name = "%B",
    -- %b	Abbreviated month name	Sep
    month_short_name = "%b",

    -- %Y	Full year	1998
    year = "%Y",
    -- %y	Two-digit year [00-99]	98
    year_short = "%y",
    -- %W	Week of the year [00-53]	37
    year_week = "%W",
    -- %j	Day of the year [001-365]	259
    year_day = "%j",

    -- %H	Hour, using a 24-hour clock [00-23]	23
    hours = "%H",
    -- %M	Minute [00-59]	48
    minutes = "%M",
    -- %S	Second [00-60]	10
    seconds = "%S",

    -- %I	Hour, using a 12-hour clock [01-12]	11
    hours12 = "%I",
    -- %p	Either am or pm	pm
    period = "%p",

    -- %w	Weekday [0-6 = Sunday-Saturday]	3
    week_day = "%w",
    -- %A	Full weekday name	Wednesday
    week_day_name = "%A",
    -- %a	Abbreviated weekday name	Wed
    week_day_short_name = "%a",

    -- %z	Timezone	-0300
    timezone = "%z",

    -- %X	Time (Same as %H:%M:%S)	23:48:10
    time = "%X",
    -- %x	Date (Same as %m/%d/%y)	09/16/98
    date = "%x",

    -- %c	Locale-appropriate date and time	Varies by platform and language settings
    date_time = "%c"
}

---@class dreamwork.std.time.FormatBuffer : dreamwork.std.Metatable
---@field [ 1 ] integer seconds
---@field seconds string
---@field [ 2 ] integer milliseconds
---@field milliseconds string
---@field [ 3 ] integer microseconds
---@field microseconds string
---@field [ 4 ] integer nanoseconds
---@field nanoseconds string
---@field timezone string
local FormatBuffer = {}

---@type table<string, integer>
local key_to_index = {
    milliseconds = 2,
    microseconds = 3,
    nanoseconds = 4
}

function FormatBuffer:__index( key )
    if key == "milliseconds" or key == "microseconds" or key == "nanoseconds" then
        local value = string_format( "%03d", raw_get( self, key_to_index[ key ] ) or 0 )
        ---@diagnostic disable-next-line: assign-type-mismatch
        self[ key ] = value
        return value
    end

    if key == "timezone" then
        local timezone

        local value = time.zone * 0x64
        if value < 0 then
            timezone = string_format( "-%04d", -value )
        else
            timezone = string_format( "+%04d", value )
        end

        self.timezone = timezone
        return timezone
    end

    local pattern_str = keys[ key ]
    if pattern_str == nil then
        error( string_format( "unknown value name - '%s'", key ), 4 )
    end

    local value

    if raw_get( self, 0 ) --[[ in_utc ]] then
        value = os_date( "!" .. pattern_str, raw_get( self, 1 ) )
    else
        value = os_date( pattern_str, raw_get( self, 1 ) )
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    self[ key ] = value
    return value
end

--- [SHARED AND MENU]
---
--- Converts a timestamp to a formatted string.
---
--- ### Format Keys
--- | Key                     | Description                                            | Example                    |
--- |-------------------------|--------------------------------------------------------|----------------------------|
--- | `{day}`                 | Day of the month [01–31]                               | `16`                       |
--- | `{week_day}`            | Weekday number [0–6, Sunday = 0]                       | `3`                        |
--- | `{week_day_name}`       | Full weekday name                                      | `Wednesday`                |
--- | `{week_day_short_name}` | Abbreviated weekday name                               | `Wed`                      |
--- | `{month}`               | Month number [01–12]                                   | `09`                       |
--- | `{month_name}`          | Full month name                                        | `September`                |
--- | `{month_short_name}`    | Abbreviated month name                                 | `Sep`                      |
--- | `{year}`                | Full year                                              | `1998`                     |
--- | `{year_day}`            | Day of the year [001–365]                              | `259`                      |
--- | `{year_week}`           | Week number of the year [00–53]                        | `37`                       |
--- | `{year_short}`          | Two-digit year [00–99]                                 | `98`                       |
--- | `{hours}`               | Hour in 24-hour format [00–23]                         | `23`                       |
--- | `{minutes}`             | Minute [00–59]                                         | `48`                       |
--- | `{seconds}`             | Second [00–60] (leap second included)                  | `10`                       |
--- | `{milliseconds}`        | Millisecond [000–999]                                  | `010`                      |
--- | `{microseconds}`        | Microsecond [000–999]                                  | `010`                      |
--- | `{nanoseconds}`         | Nanosecond [000–999]                                   | `010`                      |
--- | `{hours12}`             | Hour in 12-hour format [01–12]                         | `11`                       |
--- | `{period}`              | AM or PM                                               | `pm`                       |
--- | `{date}`                | Localized date (same as `{month}/{day}/{year}`)  | `09/16/98`                 |
--- | `{time}`                | Localized time (same as `{hours}:{minutes}:{seconds}`) | `23:48:10`                 |
--- | `{date_time}`           | Localized full date and time                           | `Wed Sep 16 23:48:10 1998` |
--- | `{timezone}`            | Timezone offset                                        | `-0300`                    |
---
---@param fmt string The format string.
---@param timestamp? integer The timestamp to format.
---@param unit? dreamwork.std.time.Unit The timestamp unit, 's' by default.
---@param in_utc? boolean Use UTC instead of local timezone, `false` by default.
---@return string str The formatted string.
function time.format( fmt, timestamp, unit, in_utc )
    return string_interpolate( fmt, setmetatable( { [ 0 ] = in_utc, split( timestamp or now( unit, true ), unit, 2 ) }, FormatBuffer ) )
end

-- TODO: add JS like data to/from string functions for compability

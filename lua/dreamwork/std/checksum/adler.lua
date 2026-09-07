---@class dreamwork.std
local std = dreamwork.std

local string = std.string
local string_len = string.len
local string_byte = string.byte

local class = std.class

--- [SHARED AND MENU]
---
--- The Adler-32 checksum calculation object.
---
---@class dreamwork.std.Adler32 : dreamwork.std.Object
---@field __class dreamwork.std.Adler32Class
---@field DigestSize integer The size of the checksum in bytes.
---@field BlockSize integer The block size in bytes.
---@field protected a integer The first part of the checksum.
---@field protected b integer The second part of the checksum.
local Adler32 = class.base( "Adler32", false )

Adler32.DigestSize = 4
Adler32.BlockSize = 16

---@alias Adler32 dreamwork.std.Adler32

---@protected
function Adler32:__init()
    self:reset()
end

--- [SHARED AND MENU]
---
--- Resets checksum to the initial value.
---
---@return dreamwork.std.Adler32 self
function Adler32:reset()
    self.a, self.b = 1, 0
    return self
end

--- [SHARED AND MENU]
---
--- Updates checksum with the specified string.
---
---@param raw_str string The string is used to update checksum.
---@return dreamwork.std.Adler32 self
function Adler32:update( raw_str )
    local str_length = string_len( raw_str )
    if str_length == 0 then
        return self
    end

    local position = str_length % 16
    local a, b = self.a, self.b

    if position ~= 0 then
        if position == 1 then
            a = (
                a +
                string_byte( raw_str, 1, position )
            ) % 0xFFF1

            b = (
                b +
                a
            ) % 0xFFF1
        elseif position == 2 then
            local uint8_1, uint8_2 = string_byte( raw_str, 1, position )

            b = (
                b +
                2 * a +
                2 * uint8_1 +
                uint8_2
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2
            ) % 0xFFF1
        elseif position == 3 then
            local uint8_1, uint8_2, uint8_3 = string_byte( raw_str, 1, position )

            b = (
                b +
                3 * a +
                3 * uint8_1 +
                2 * uint8_2 +
                uint8_3
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3
            ) % 0xFFF1
        elseif position == 4 then
            local uint8_1, uint8_2, uint8_3, uint8_4 = string_byte( raw_str, 1, position )

            b = (
                b +
                4 * a +
                4 * uint8_1 +
                3 * uint8_2 +
                2 * uint8_3 +
                uint8_4
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4
            ) % 0xFFF1
        elseif position == 5 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5 = string_byte( raw_str, 1, position )

            b = (
                b +
                5 * a +
                5 * uint8_1 +
                4 * uint8_2 +
                3 * uint8_3 +
                2 * uint8_4 +
                uint8_5
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5
            ) % 0xFFF1
        elseif position == 6 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6 = string_byte( raw_str, 1, position )

            b = (
                b +
                6 * a +
                6 * uint8_1 +
                5 * uint8_2 +
                4 * uint8_3 +
                3 * uint8_4 +
                2 * uint8_5 +
                uint8_6
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6
            ) % 0xFFF1
        elseif position == 7 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7 = string_byte( raw_str, 1, position )

            b = (
                b +
                7 * a +
                7 * uint8_1 +
                6 * uint8_2 +
                5 * uint8_3 +
                4 * uint8_4 +
                3 * uint8_5 +
                2 * uint8_6 +
                uint8_7
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7
            ) % 0xFFF1
        elseif position == 8 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8 = string_byte( raw_str, 1, position )

            b = (
                b +
                8 * a +
                8 * uint8_1 +
                7 * uint8_2 +
                6 * uint8_3 +
                5 * uint8_4 +
                4 * uint8_5 +
                3 * uint8_6 +
                2 * uint8_7 +
                uint8_8
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8
            ) % 0xFFF1
        elseif position == 9 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8,
            uint8_9 = string_byte( raw_str, 1, position )

            b = (
                b +
                9 * a +
                9 * uint8_1 +
                8 * uint8_2 +
                7 * uint8_3 +
                6 * uint8_4 +
                5 * uint8_5 +
                4 * uint8_6 +
                3 * uint8_7 +
                2 * uint8_8 +
                uint8_9
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8 +
                uint8_9
            ) % 0xFFF1
        elseif position == 10 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8,
            uint8_9, uint8_10 = string_byte( raw_str, 1, position )

            b = (
                b +
                10 * a +
                10 * uint8_1 +
                9 * uint8_2 +
                8 * uint8_3 +
                7 * uint8_4 +
                6 * uint8_5 +
                5 * uint8_6 +
                4 * uint8_7 +
                3 * uint8_8 +
                2 * uint8_9 +
                uint8_10
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8 +
                uint8_9 +
                uint8_10
            ) % 0xFFF1
        elseif position == 11 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8,
            uint8_9, uint8_10, uint8_11 = string_byte( raw_str, 1, position )

            b = (
                b +
                11 * a +
                11 * uint8_1 +
                10 * uint8_2 +
                9 * uint8_3 +
                8 * uint8_4 +
                7 * uint8_5 +
                6 * uint8_6 +
                5 * uint8_7 +
                4 * uint8_8 +
                3 * uint8_9 +
                2 * uint8_10 +
                uint8_11
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8 +
                uint8_9 +
                uint8_10 +
                uint8_11
            ) % 0xFFF1
        elseif position == 12 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8,
            uint8_9, uint8_10, uint8_11, uint8_12 = string_byte( raw_str, 1, position )

            b = (
                b +
                12 * a +
                12 * uint8_1 +
                11 * uint8_2 +
                10 * uint8_3 +
                9 * uint8_4 +
                8 * uint8_5 +
                7 * uint8_6 +
                6 * uint8_7 +
                5 * uint8_8 +
                4 * uint8_9 +
                3 * uint8_10 +
                2 * uint8_11 +
                uint8_12
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8 +
                uint8_9 +
                uint8_10 +
                uint8_11 +
                uint8_12
            ) % 0xFFF1
        elseif position == 13 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8,
            uint8_9, uint8_10, uint8_11, uint8_12,
            uint8_13 = string_byte( raw_str, 1, position )

            b = (
                b +
                13 * a +
                13 * uint8_1 +
                12 * uint8_2 +
                11 * uint8_3 +
                10 * uint8_4 +
                9 * uint8_5 +
                8 * uint8_6 +
                7 * uint8_7 +
                6 * uint8_8 +
                5 * uint8_9 +
                4 * uint8_10 +
                3 * uint8_11 +
                2 * uint8_12 +
                uint8_13
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8 +
                uint8_9 +
                uint8_10 +
                uint8_11 +
                uint8_12 +
                uint8_13
            ) % 0xFFF1
        elseif position == 14 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8,
            uint8_9, uint8_10, uint8_11, uint8_12,
            uint8_13, uint8_14 = string_byte( raw_str, 1, position )

            b = (
                b +
                14 * a +
                14 * uint8_1 +
                13 * uint8_2 +
                12 * uint8_3 +
                11 * uint8_4 +
                10 * uint8_5 +
                9 * uint8_6 +
                8 * uint8_7 +
                7 * uint8_8 +
                6 * uint8_9 +
                5 * uint8_10 +
                4 * uint8_11 +
                3 * uint8_12 +
                2 * uint8_13 +
                uint8_14
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8 +
                uint8_9 +
                uint8_10 +
                uint8_11 +
                uint8_12 +
                uint8_13 +
                uint8_14
            ) % 0xFFF1
        elseif position == 15 then
            local uint8_1, uint8_2, uint8_3, uint8_4,
            uint8_5, uint8_6, uint8_7, uint8_8,
            uint8_9, uint8_10, uint8_11, uint8_12,
            uint8_13, uint8_14, uint8_15 = string_byte( raw_str, 1, position )

            b = (
                b +
                15 * a +
                15 * uint8_1 +
                14 * uint8_2 +
                13 * uint8_3 +
                12 * uint8_4 +
                11 * uint8_5 +
                10 * uint8_6 +
                9 * uint8_7 +
                8 * uint8_8 +
                7 * uint8_9 +
                6 * uint8_10 +
                5 * uint8_11 +
                4 * uint8_12 +
                3 * uint8_13 +
                2 * uint8_14 +
                uint8_15
            ) % 0xFFF1

            a = (
                a +
                uint8_1 +
                uint8_2 +
                uint8_3 +
                uint8_4 +
                uint8_5 +
                uint8_6 +
                uint8_7 +
                uint8_8 +
                uint8_9 +
                uint8_10 +
                uint8_11 +
                uint8_12 +
                uint8_13 +
                uint8_14 +
                uint8_15
            ) % 0xFFF1
        end
    end

    str_length = str_length - 15
    position = position + 1

    ::perform_block::

    if position > str_length then
        self.a, self.b = a, b
        return self
    end

    local uint8_1, uint8_2, uint8_3, uint8_4,
    uint8_5, uint8_6, uint8_7, uint8_8,
    uint8_9, uint8_10, uint8_11, uint8_12,
    uint8_13, uint8_14, uint8_15, uint8_16 = string_byte( raw_str, position, position + 15 )

    b = (
        b +
        16 * a +
        16 * uint8_1 +
        15 * uint8_2 +
        14 * uint8_3 +
        13 * uint8_4 +
        12 * uint8_5 +
        11 * uint8_6 +
        10 * uint8_7 +
        9 * uint8_8 +
        8 * uint8_9 +
        7 * uint8_10 +
        6 * uint8_11 +
        5 * uint8_12 +
        4 * uint8_13 +
        3 * uint8_14 +
        2 * uint8_15 +
        uint8_16
    ) % 0xFFF1

    a = (
        a +
        uint8_1 +
        uint8_2 +
        uint8_3 +
        uint8_4 +
        uint8_5 +
        uint8_6 +
        uint8_7 +
        uint8_8 +
        uint8_9 +
        uint8_10 +
        uint8_11 +
        uint8_12 +
        uint8_13 +
        uint8_14 +
        uint8_15 +
        uint8_16
    ) % 0xFFF1

    position = position + 16
    ---@diagnostic disable-next-line: missing-return
    goto perform_block
end

--- [SHARED AND MENU]
---
--- Finalizes checksum calculation and returns the resulting checksum.
---
---@return integer checksum The final checksum value, which is greater or equal to 0, and less than 2^32 (0x100000000).
function Adler32:digest()
    return (self.b * 0x10000) + self.a
end

--- [SHARED AND MENU]
---
--- The class used to create new Adler-32 checksum calculation instances.
---
--- See [RFC1950](https://tools.ietf.org/html/rfc1950) for the definition of the Adler-32 checksum.
---
--- [Adler32 Online](https://md5calc.com/hash/adler32)
---
---@class dreamwork.std.Adler32Class : dreamwork.std.Adler32
---@field __base dreamwork.std.Adler32
---@overload fun(): dreamwork.std.Adler32
local Adler32Class = class.create( Adler32 )
std.Adler32 = Adler32Class

do

    local adler32 = Adler32Class()

    --- [SHARED AND MENU]
    ---
    --- Calculates the Adler-32 checksum of the specified string.
    ---
    ---@param raw_str string The string is used to calculate checksum.
    function Adler32Class.digest( raw_str )
        return adler32:reset():update( raw_str ):digest()
    end

end

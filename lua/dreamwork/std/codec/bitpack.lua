---@class dreamwork.std
local std = dreamwork.std

local string = std.string
local string_len = string.len
local string_rep = string.rep
local string_byte, string_char = string.byte, string.char

local math = std.math
local math_ceil = math.ceil
local math_floor = math.floor

local error = std.error
local len = std.len


--- [SHARED AND MENU]
---
--- Library that packs/unpacks types as bit sequences.
---
---@class dreamwork.std.bits
local bitpack = {}
std.bitpack = bitpack

---@alias dreamwork.std.bitpack.Sequence boolean[] The sequence of bits (booleans).

--- [SHARED AND MENU]
---
--- Reads unsigned integer from table of bits (booleans).
---
---@param bit_sequence dreamwork.std.bitpack.Sequence The sequence of bits.
---@param bit_sequence_size? integer The size of the bit sequence.
---@param start_position? integer The start position in the bit sequence.
---@return integer uint The unsigned integer.
local function bitpack_readUInt( bit_sequence, bit_sequence_size, start_position )
    if start_position == nil then
        start_position = 1
    end

    if bit_sequence_size == nil then
        bit_sequence_size = len( bit_sequence )
    elseif bit_sequence_size == 0 then
        return 0
    elseif bit_sequence_size < 0 then
        error( "bit count cannot be negative", 2 )
    end

    local value = 0

    for i = start_position, bit_sequence_size + (start_position - 1), 1 do
        if bit_sequence[ i ] then
            value = value * 2 + 1
        else
            value = value * 2
        end
    end

    return value
end

bitpack.readUInt = bitpack_readUInt

--- [SHARED AND MENU]
---
--- Writes unsigned integer as table of bits (booleans).
---
---@param value integer	The unsigned integer.
---@param bit_sequence_size? integer The size of the bit sequence.
---@return dreamwork.std.bitpack.Sequence bit_sequence The sequence of bits.
local function bitpack_writeUInt( value, bit_sequence_size )
    if bit_sequence_size == nil then
        bit_sequence_size = 8
    end

    if value < 0 then
        error( "integer is too small to write", 1 )
    elseif value > (2 ^ bit_sequence_size) - 1 then
        error( "integer is too large to write", 2 )
    end

    local bit_sequence = {}

    for i = bit_sequence_size, 1, -1 do
        if value == 0 then
            bit_sequence[ i ] = false
        else
            bit_sequence[ i ] = value % 2 == 1
            value = math_floor( value * 0.5 )
        end
    end

    return bit_sequence
end

bitpack.writeUInt = bitpack_writeUInt

--- [SHARED AND MENU]
---
--- Reads signed integer from table of bits (booleans).
---
---@param bit_sequence dreamwork.std.bitpack.Sequence The sequence of bits.
---@param bit_sequence_size integer The size of the bit sequence.
---@param start_position integer The start position in the bit sequence.
---@return integer value The signed integer.
function bitpack.readInt( bit_sequence, bit_sequence_size, start_position )
    return bitpack_readUInt( bit_sequence, bit_sequence_size, start_position ) - (2 ^ (bit_sequence_size - 1))
end

--- [SHARED AND MENU]
---
--- Writes signed integer as table of bits (booleans).
---
---@param value integer The number to explode.
---@param bit_sequence_size integer
---@return dreamwork.std.bitpack.Sequence bit_sequence
function bitpack.writeInt( value, bit_sequence_size )
    return bitpack_writeUInt( value + (2 ^ (bit_sequence_size - 1)), bit_sequence_size )
end

--- [SHARED AND MENU]
---
--- Writes table of bits (booleans) as bytecodes.
---
---@param bit_sequence dreamwork.std.bitpack.Sequence The table of bits (booleans).
---@param bit_sequence_size? integer The size of the bit sequence.
---@param big_endian? boolean `true` for big endian, `false` for little endian.
---@return dreamwork.std.bytepack.Sequence bytes The sequence of bytes.
---@return integer byte_count The number of bytes.
function bitpack.pack( bit_sequence, bit_sequence_size, big_endian )
    if bit_sequence_size == nil then
        bit_sequence_size = len( bit_sequence )
    elseif bit_sequence_size < 1 then
        error( "bit count cannot be less than 1", 1 )
    end

    local byte_count = math.ceil( bit_sequence_size * 0.125 )
    local bytes = {}

    if big_endian then
        for i = byte_count, 1, -1 do
            bytes[ i ] = bitpack_readUInt( bit_sequence, 8, i * 8 - 7 )
        end
    else
        bit_sequence_size = bit_sequence_size + 1

        for i = 1, byte_count, 1 do
            bytes[ i ] = bitpack_readUInt( bit_sequence, 8, bit_sequence_size - i * 8 )
        end
    end

    return bytes, byte_count
end

--- [SHARED AND MENU]
---
--- Reads bytecodes as table of bits (booleans).
---
---@param big_endian? boolean `true` for big endian, `false` for little endian.
---@param bytes dreamwork.std.bytepack.Sequence The bytecodes (bytes as integers<0-255>).
---@param byte_count? integer The number of bytes.
---@return dreamwork.std.bitpack.Sequence bit_sequence The table of bits (booleans).
---@return integer bit_sequence_size The size of the bit table.
function bitpack.unpack( big_endian, bytes, byte_count )
    if byte_count == nil then
        byte_count = len( bytes )
    end

    local bit_sequence, bit_sequence_size = {}, 0

    for i = big_endian and 1 or byte_count, big_endian and byte_count or 1, big_endian and 1 or -1 do
        local uint8 = bytes[ i ]

        for j = 8, 1, -1 do
            if uint8 == 0 then
                bit_sequence[ bit_sequence_size + j ] = false
            else
                bit_sequence[ bit_sequence_size + j ] = (uint8 % 2) == 1
                uint8 = math_floor( uint8 * 0.5 )
            end
        end

        bit_sequence_size = bit_sequence_size + 8
    end

    return bit_sequence, bit_sequence_size
end

do

    local table_concat = std.table.concat

    --- [SHARED AND MENU]
    ---
    --- Converts table of bits (booleans) to string of 0s and 1s.
    ---
    ---@param bit_sequence dreamwork.std.bitpack.Sequence The table of bits (booleans).
    ---@param bit_sequence_size? integer The size of the bit table.
    ---@param full_bytes? boolean `true` for full bytes, `false` for bit count.
    ---@return string bit_str The string of 0s and 1s.
    function bitpack.toString( bit_sequence, bit_sequence_size, full_bytes )
        if bit_sequence_size == nil then
            bit_sequence_size = len( bit_sequence )
        end

        local bytes = {}

        for index = 1, bit_sequence_size, 1 do
            bytes[ index ] = bit_sequence[ index ] and "1" or "0"
        end

        local bit_str = table_concat( bytes, "", 1, bit_sequence_size )

        if full_bytes then
            return string_rep( "0", (math_ceil( bit_sequence_size * 0.125 ) * 8) - bit_sequence_size ) .. bit_str
        end

        return bit_str
    end

end

do

    local string_find = string.find

    --- [SHARED AND MENU]
    ---
    --- Reads bit sequence from string of 0s and 1s.
    ---
    ---@param bit_str string The string of 0s and 1s.
    ---@param bit_str_length? integer The length of the string.
    ---@return dreamwork.std.bitpack.Sequence bit_sequence The table of bits (booleans).
    ---@return integer bit_sequence_size The size of the bit table.
    function bitpack.fromString( bit_str, bit_str_length )
        if bit_str_length == nil then
            bit_str_length = string_len( bit_str )
        end

        local bit_sequence = {}

        local first_true = string_find( bit_str, "1", 1, true )
        if first_true == nil then
            for index = 1, bit_str_length, 1 do
                bit_sequence[ index ] = false
            end
        else

            first_true = first_true - 1

            for index = first_true + 1, bit_str_length, 1 do
                bit_sequence[ index - first_true ] = string_byte( bit_str, index, index ) == 0x31
            end

        end

        return bit_sequence, bit_str_length
    end

end

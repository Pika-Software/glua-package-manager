--[[
    Based on LibDeflate by safeteeWow
    https://github.com/safeteeWow/LibDeflate

    Edit by Unknown Developer
--]]

---@class dreamwork.std
local std = dreamwork.std

local raw = std.raw
local raw_pairs = raw.pairs

local math = std.math
local math_max = math.max

local table = std.table
local table_sort = table.sort
local table_concat = table.concat
local table_insert = table.insert

local string = std.string
local string_len = string.len
local string_find = string.find
local string_gsub, string_sub = string.gsub, string.sub
local string_byte, string_char = string.byte, string.char

local Adler32 = std.Adler32
local Adler32_digest = Adler32.digest

local error = std.error


--- [SHARED AND MENU]
---
--- A library for compressing and decompressing data using the deflate algorithm and more.
---
---@class dreamwork.std.deflate
local deflate = {}
std.deflate = deflate

--- [SHARED AND MENU]
---
--- A library for compressing and decompressing data using the zlib algorithm and more.
---
---@class dreamwork.std.zlib
local zlib = {}
std.zlib = zlib

-- TODO: remove this crap and replace with luajited fucntions :p
-- Converts i to 2^i, (0<=i<=32)
-- This is used to implement bit left shift and bit right shift.
-- "x >> y" in C:   "(x-x%_pow2[y])/_pow2[y]" in Lua
-- "x << y" in C:   "x*_pow2[y]" in Lua
local _pow2 = {}

-- _reverseBitsTbl[len][val] stores the bit reverse of the number with bit length "len" and value "val"
-- For example, decimal number 6 with bits length 5 is binary 00110
-- It's reverse is binary 01100, which is decimal 12 and 12 == _reverseBitsTbl[5][6]
-- 1<=len<=9, 0<=val<=2^len-1
-- The reason for 1<=len<=9 is that the max of min bitlen of huffman code of a huffman alphabet is 9?
local _reverse_bits_tbl = {}

-- TODO: maybe move this into separate libraries like LZ77 and huffman libs
-- Convert a LZ77 length (3<=len<=258) to a deflate literal/LZ77_length code (257<=code<=285)
local _length_to_deflate_code = {}

-- convert a LZ77 length (3<=len<=258) to a deflate literal/LZ77_length code extra bits.
local _length_to_deflate_extra_bits = {}

-- Convert a LZ77 length (3<=len<=258) to a deflate literal/LZ77_length code extra bit length.
local _length_to_deflate_extra_bitlen = {}

-- Convert a small LZ77 distance (1<=dist<=256) to a deflate code.
local _dist256_to_deflate_code = {}

-- Convert a small LZ77 distance (1<=dist<=256) to a deflate distance code extra bits.
local _dist256_to_deflate_extra_bits = {}

-- Convert a small LZ77 distance (1<=dist<=256) to a deflate distance code extra bit length.
local _dist256_to_deflate_extra_bitlen = {}

-- Convert a literal/LZ77_length deflate code to LZ77 base length
-- The key of the table is (code - 256), 257<=code<=285
local _literal_deflate_code_to_base_len = {
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67,
    83, 99, 115, 131, 163, 195, 227, 258
}

-- Convert a literal/LZ77_length deflate code to base LZ77 length extra bits
-- The key of the table is (code - 256), 257<=code<=285
local _literal_deflate_code_to_extra_bitlen = {
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5,
    5, 5, 5, 0
}

-- Convert a distance deflate code to base LZ77 distance. (0<=code<=29)
local _dist_deflate_code_to_base_dist = {
    [ 0 ] = 1,
    2,
    3,
    4,
    5,
    7,
    9,
    13,
    17,
    25,
    33,
    49,
    65,
    97,
    129,
    193,
    257,
    385,
    513,
    769,
    1025,
    1537,
    2049,
    3073,
    4097,
    6145,
    8193,
    12289,
    16385,
    24577
}

-- Convert a distance deflate code to LZ77 bits length. (0<=code<=29)
local _dist_deflate_code_to_extra_bitlen = {
    [ 0 ] = 0,
    0,
    0,
    0,
    1,
    1,
    2,
    2,
    3,
    3,
    4,
    4,
    5,
    5,
    6,
    6,
    7,
    7,
    8,
    8,
    9,
    9,
    10,
    10,
    11,
    11,
    12,
    12,
    13,
    13
}

-- The code order of the first huffman header in the dynamic deflate block. See the page 12 of RFC1951
local _rle_codes_huffman_bitlen_order = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

-- The following tables are used by fixed deflate block. The value of these tables are assigned at the bottom of the source.

-- The huffman code of the literal/LZ77_length deflate codes, in fixed deflate block.
local _fix_block_literal_huffman_code

-- Convert huffman code of the literal/LZ77_length to deflate codes, in fixed deflate block.
local _fix_block_literal_huffman_to_deflate_code

-- The bit length of the huffman code of literal/LZ77_length deflate codes, in fixed deflate block.
local _fix_block_literal_huffman_bitlen

-- The count of each bit length of the literal/LZ77_length deflate codes, in fixed deflate block.
local _fix_block_literal_huffman_bitlen_count

-- The huffman code of the distance deflate codes, in fixed deflate block.
local _fix_block_dist_huffman_code

-- Convert huffman code of the distance to deflate codes, in fixed deflate block.
local _fix_block_dist_huffman_to_deflate_code

-- The bit length of the huffman code of the distance deflate codes, in fixed deflate block.
local _fix_block_dist_huffman_bitlen

-- The count of each bit length of the huffman code of the distance deflate codes, in fixed deflate block.
local _fix_block_dist_huffman_bitlen_count

do
    local pow = 1
    for i = 0, 32 do
        _pow2[ i ] = pow
        pow = pow * 2
    end
end

for i = 1, 9 do
    _reverse_bits_tbl[ i ] = {}
    for j = 0, 2 ^ (i + 1) - 1 do
        local reverse = 0
        local value = j
        for _ = 1, i do
            -- The following line is equivalent to "res | (code %2)" in C.
            reverse = reverse - reverse % 2 + (((reverse % 2 == 1) or (value % 2) == 1) and 1 or 0)
            value = (value - value % 2) / 2
            reverse = reverse * 2
        end

        _reverse_bits_tbl[ i ][ j ] = (reverse - reverse % 2) / 2
    end
end

-- The source code is written according to the pattern in the numbers in RFC1951 Page10.
do

    local a = 18
    local b = 16
    local c = 265
    local bitlen = 1

    for len = 3, 258 do
        if len <= 10 then
            _length_to_deflate_code[ len ] = len + 254
            _length_to_deflate_extra_bitlen[ len ] = 0
        elseif len == 258 then
            _length_to_deflate_code[ len ] = 285
            _length_to_deflate_extra_bitlen[ len ] = 0
        else
            if len > a then
                a = a + b
                b = b * 2
                c = c + 4
                bitlen = bitlen + 1
            end

            local t = len - a - 1 + b / 2
            _length_to_deflate_code[ len ] = (t - (t % (b / 8))) / (b / 8) + c
            _length_to_deflate_extra_bitlen[ len ] = bitlen
            _length_to_deflate_extra_bits[ len ] = t % (b / 8)
        end
    end

end

-- The source code is written according to the pattern in the numbers in RFC1951 Page11.
do

    _dist256_to_deflate_code[ 1 ] = 0
    _dist256_to_deflate_code[ 2 ] = 1
    _dist256_to_deflate_extra_bitlen[ 1 ] = 0
    _dist256_to_deflate_extra_bitlen[ 2 ] = 0

    local a = 3
    local b = 4
    local code = 2
    local bitlen = 0
    for dist = 3, 256 do
        if dist > b then
            a = a * 2
            b = b * 2
            code = code + 2
            bitlen = bitlen + 1
        end

        _dist256_to_deflate_code[ dist ] = (dist <= a) and code or (code + 1)
        _dist256_to_deflate_extra_bitlen[ dist ] = (bitlen < 0) and 0 or bitlen

        if b >= 8 then
            _dist256_to_deflate_extra_bits[ dist ] = (dist - b / 2 - 1) % (b / 4)
        end
    end

end

--- Compare adler32 checksum.
--- adler32 should be compared with a mod to avoid sign problem 4072834167 (unsigned) is the same adler32 as -222133129
local function isEqualAdler32( actual, expected )
    return (actual % 0x100000000) == (expected % 0x100000000)
end

--- Create a preset dictionary.
---
--- This function is not fast, and the memory consumption of the produced
--- dictionary is about 50 times of the input string. Therefore, it is suggestted
--- to run this function only once in your program.
---
--- It is very important to know that if you do use a preset dictionary,
--- compressors and decompressors MUST USE THE SAME dictionary. That is,
--- dictionary must be created using the same string. If you update your program
--- with a new dictionary, people with the old version won't be able to transmit
--- data with people with the new version. Therefore, changing the dictionary must be very careful.
---
---
--- The parameters "strlen" and "adler32" add a layer of verification to ensure
--- the parameter "str" is not modified unintentionally during the program development.
---
---
---@usage local dict_str = "1234567890"
---
--- print(dict_str:len(), deflate.calculateAdler32(dict_str))
--- Hardcode the print result below to verify it to avoid acciently
--- modification of 'str' during the program development.
--- string length: 10, Adler-32: 187433486,
--- Don't calculate string length and its Adler-32 at run-time.
---
--- local dict = deflate.createDictionary(dict_str, 10, 187433486)
---
---@param str string The string used as the preset dictionary.
---
---You should put stuffs that frequently appears in the dictionary
---string and preferablely put more frequently appeared stuffs toward the end of the string.
---
---
--- Empty string and string longer than 32768 bytes are not allowed.
---@return table dict The dictionary used for preset dictionary compression and decompression.
---@raise error if 'strlen' does not match the length of 'str',
--- or if 'adler32' does not match the Adler-32 checksum of 'str'.
function deflate.createDictionary( str )
    local strlen = string_len( str )
    if strlen == 0 then
        error( "Empty string is not allowed.", 2 )
    elseif strlen > 32768 then
        error( "String longer than 32768 bytes is not allowed. Got " .. strlen .. " bytes.", 2 )
    end

    local string_table = { string_byte( str, 1, 2 ) }
    local hash_tables = {}

    local dictionary = {
        [ "adler32" ] = Adler32_digest( str ),
        [ "string_table" ] = string_table,
        [ "hash_tables" ] = hash_tables,
        [ "strlen" ] = strlen
    }

    if strlen >= 3 then
        local i = 1
        local hash = string_table[ 1 ] * 0x100 + string_table[ 2 ]

        while i <= (strlen - 5) do
            local x1, x2, x3, x4 = string_byte( str, i + 2, i + 5 )

            string_table[ i + 2 ] = x1
            string_table[ i + 3 ] = x2
            string_table[ i + 4 ] = x3
            string_table[ i + 5 ] = x4

            hash = (hash * 0x100 + x1) % 0x1000000

            local t = hash_tables[ hash ]
            if t == nil then
                t = {}; hash_tables[ hash ] = t
            end

            table_insert( t, i - strlen )
            i = i + 1

            hash = (hash * 0x100 + x2) % 0x1000000
            t = hash_tables[ hash ]

            if t == nil then
                t = {}; hash_tables[ hash ] = t
            end

            table_insert( t, i - strlen )
            i = i + 1

            hash = (hash * 0x100 + x3) % 0x1000000
            t = hash_tables[ hash ]

            if t == nil then
                t = {}; hash_tables[ hash ] = t
            end

            table_insert( t, i - strlen )
            i = i + 1

            hash = (hash * 0x100 + x4) % 0x1000000
            t = hash_tables[ hash ]

            if t == nil then
                t = {}; hash_tables[ hash ] = t
            end

            table_insert( t, i - strlen )
            i = i + 1
        end

        while i <= (strlen - 2) do
            local x = string_byte( str, i + 2 )
            string_table[ i + 2 ] = x

            hash = (hash * 0x100 + x) % 0x1000000

            local t = hash_tables[ hash ]
            if t == nil then
                t = {}; hash_tables[ hash ] = t
            end

            table_insert( t, i - strlen )
            i = i + 1
        end
    end

    return dictionary
end

--[[
    key of the configuration table is the compression level,
    and its value stores the compression setting.
    These numbers come from zlib source code.

    Higher compression level usually means better compression.
    (Because LibDeflate uses a simplified version of zlib algorithm,
    there is no guarantee that higher compression level does not create
    bigger file than lower level, but I can say it's 99% likely)

    Be careful with the high compression level. This is a pure lua
    implementation compressor/decompressor, which is significant slower than
    a C/C++ equivalant compressor/decompressor. Very high compression level
    costs significant more CPU time, and usually compression size won't be
    significant smaller when you increase compression level by 1, when the
    level is already very high. Benchmark yourself if you can afford it.

    See also https://github.com/madler/zlib/blob/master/doc/algorithm.txt,
    https://github.com/madler/zlib/blob/master/deflate.c for more information.

    The meaning of each field:
    @field 1 use_lazy_evaluation:
        true/false. Whether the program uses lazy evaluation.
        See what is "lazy evaluation" in the link above.
        lazy_evaluation improves ratio, but relatively slow.
    @field 2 good_prev_length:
        Only effective if lazy is set, Only use 1/4 of max_chain,
        if prev length of lazy match is above this.
    @field 3 max_insert_length/max_lazy_match:
        If not using lazy evaluation,
        insert new strings in the hash table only if the match length is not
        greater than this length.
        If using lazy evaluation, only continue lazy evaluation,
        if previous match length is strictly smaller than this value.
    @field 4 nice_length:
        Number. Don't continue to go down the hash chain,
        if match length is above this.
    @field 5 max_chain:
        Number. The maximum number of hash chains we look.
--]]
local _compression_level_configs = {
    [ 0 ] = { false, nil, 0, 0, 0 },      -- level 0, no compression
    [ 1 ] = { false, nil, 4, 8, 4 },      -- level 1, similar to zlib level 1
    [ 2 ] = { false, nil, 5, 18, 8 },     -- level 2, similar to zlib level 2
    [ 3 ] = { false, nil, 6, 32, 32 },    -- level 3, similar to zlib level 3
    [ 4 ] = { true, 4, 4, 16, 16 },       -- level 4, similar to zlib level 4
    [ 5 ] = { true, 8, 16, 32, 32 },      -- level 5, similar to zlib level 5
    [ 6 ] = { true, 8, 16, 128, 128 },    -- level 6, similar to zlib level 6
    [ 7 ] = { true, 8, 32, 128, 256 },    -- (SLOW) level 7, similar to zlib level 7
    [ 8 ] = { true, 32, 128, 258, 1024 }, -- (SLOW) level 8,similar to zlib level 8
    [ 9 ] = { true, 32, 258, 258, 4096 }  -- (VERY SLOW) level 9, similar to zlib level 9
}

local validate_dictionary, validate_configs
do

    local isTable, isNumber = std.isTable, std.isNumber

    function validate_dictionary( dictionary, error_level )
        if error_level == nil then error_level = 1 end

        error_level = error_level + 1

        if not isNumber( dictionary.adler32 ) then
            error( "'dictionary' - missing required field 'adler32'.", error_level )
        end

        local string_table = dictionary.string_table
        if not isTable( dictionary.string_table ) then
            error( "'dictionary' - missing required field 'string_table'.", error_level )
        end

        if not isNumber( dictionary.strlen ) then
            error( "'dictionary' - missing required field 'strlen'.", error_level )
        end

        local strlen = dictionary.strlen
        if strlen <= 0 or strlen > 32768 then
            error( "'dictionary' - 'strlen' must be between 1 and 32768.", error_level )
        end

        if strlen ~= #string_table then
            error( "'dictionary' - 'strlen' does not match the length of 'string_table'.", error_level )
        end

        if not isTable( dictionary.hash_tables ) then
            error( "'dictionary' - missing required field 'hash_tables'.", error_level )
        end
    end

    function validate_configs( configs, error_level )
        if error_level == nil then error_level = 1 end

        error_level = error_level + 1

        local level = configs.level
        if level == nil then
            error( "'configs' - missing required field 'level'.", error_level )
        end

        if not _compression_level_configs[ level ] then
            error( "'configs' - unsupported 'level': '" .. std.tostring( level ) .. "'.", error_level )
        end

        local strategy = configs.strategy
        if strategy == nil then
            error( "'configs' - missing required field 'strategy'.", error_level )
        end

        -- random_block_type is for testing purpose
        if not (strategy == "fixed" or strategy == "huffman_only" or strategy == "dynamic") then
            error( "'configs' - unsupported 'strategy': '" .. std.tostring( strategy ) .. "'.", error_level )
        end
    end

end

-- Compress code --

-- partial flush to save memory
local _FLUSH_MODE_MEMORY_CLEANUP = 0

-- full flush with partial bytes
local _FLUSH_MODE_OUTPUT = 1

-- write bytes to get to byte boundary
local _FLUSH_MODE_BYTE_BOUNDARY = 2

-- no flush, just get num of bits written so far
local _FLUSH_MODE_NO_FLUSH = 3

--[[
    Create an empty writer to easily write stuffs as the unit of bits.
    Return values:
    1. writeBits(code, bitlen):
    2. writeString(str):
    3. Flush(mode):
--]]
local function createWriter()
    local buffer_size = 0
    local cache = 0
    local cache_bitlen = 0
    local total_bitlen = 0
    local buffer = {}

    -- When buffer is big enough, flush into result_buffer to save memory.
    local result_buffer, result_buffer_size = {}, 0

    --- Write bits with value "value" and bit length of "bitlen" into writer.
    ---@param value number The value being written
    ---@param bitlen number The bit length of "value"
    local function writeBits( value, bitlen )
        cache = cache + value * _pow2[ cache_bitlen ]
        cache_bitlen = cache_bitlen + bitlen
        total_bitlen = total_bitlen + bitlen

        -- Only bulk to buffer every 4 bytes. This is quicker.
        if cache_bitlen >= 32 then
            buffer_size = buffer_size + 1
            buffer[ buffer_size ] = string_char(
                cache % 0x100,
                (cache - cache % 0x100) / 0x100 % 0x100,
                (cache - cache % 0x10000) / 0x10000 % 0x100,
                (cache - cache % 0x1000000) / 0x1000000 % 0x100
            )

            local rshift_mask = _pow2[ 32 - cache_bitlen + bitlen ]
            cache = (value - value % rshift_mask) / rshift_mask

            cache_bitlen = cache_bitlen - 32
        end
    end

    --- Write the entire string into the writer.
    ---@param str string The string being written
    ---@return nil
    local function writeString( str )
        for _ = 1, cache_bitlen, 8 do
            buffer_size = buffer_size + 1
            buffer[ buffer_size ] = string_char( cache % 0x100 )

            cache = (cache - cache % 0x100) / 0x100
        end

        cache_bitlen = 0

        buffer_size = buffer_size + 1
        buffer[ buffer_size ] = str

        total_bitlen = total_bitlen + string_len( str ) * 8
    end

    --- Flush current stuffs in the writer and return it.
    --- This operation will free most of the memory.
    ---@param mode number See the descrtion of the constant and the source code.
    ---@return integer bit_count The total number of bits stored in the writer right now.
    --- for byte boundary mode, it includes the padding bits.
    --- for output mode, it does not include padding bits.
    ---@return string? result Return the outputs if mode is output.
    local function flushWriter( mode )
        if mode == _FLUSH_MODE_NO_FLUSH then
            return total_bitlen
        end

        if mode == _FLUSH_MODE_OUTPUT or mode == _FLUSH_MODE_BYTE_BOUNDARY then
            -- Full flush, also output cache.
            -- Need to pad some bits if cache_bitlen is not multiple of 8.
            local padding_bitlen = (8 - cache_bitlen % 8) % 8

            if cache_bitlen > 0 then
                -- padding with all 1 bits, mainly because "\000" is not
                -- good to be tranmitted. I do this so "\000" is a little bit
                -- less frequent.
                cache = cache - _pow2[ cache_bitlen ] + _pow2[ cache_bitlen + padding_bitlen ]

                for _ = 1, cache_bitlen, 8 do
                    buffer_size = buffer_size + 1
                    buffer[ buffer_size ] = string_char( cache % 0x100 )
                    cache = (cache - cache % 0x100) / 0x100
                end

                cache = 0
                cache_bitlen = 0
            end

            if mode == _FLUSH_MODE_BYTE_BOUNDARY then
                total_bitlen = total_bitlen + padding_bitlen
                return total_bitlen
            end
        end

        local flushed = table_concat( buffer )

        buffer = {}
        buffer_size = 0

        result_buffer_size = result_buffer_size + 1
        result_buffer[ result_buffer_size ] = flushed

        if mode == _FLUSH_MODE_MEMORY_CLEANUP then
            return total_bitlen
        elseif result_buffer_size == 1 then
            return total_bitlen, result_buffer[ 1 ]
        elseif result_buffer_size == 2 then
            return total_bitlen, result_buffer[ 1 ] .. result_buffer[ 2 ]
        else
            return total_bitlen, table_concat( result_buffer, "", 1, result_buffer_size )
        end
    end

    return writeBits, writeString, flushWriter
end

--- Push an element into a max heap
---@param heap table A max heap whose max element is at index 1.
---@param e table The element to be pushed. Assume element "e" is a table
--- and comparison is done via its first entry e[1]
---@param heap_size number current number of elements in the heap.
--- NOTE: There may be some garbage stored in
--- heap[heap_size+1], heap[heap_size+2], etc..
local function minHeapPush( heap, e, heap_size )
    heap_size = heap_size + 1
    heap[ heap_size ] = e

    local value = e[ 1 ]
    local pos = heap_size
    local parent_pos = (pos - pos % 2) / 2

    while (parent_pos >= 1 and heap[ parent_pos ][ 1 ] > value) do
        local t = heap[ parent_pos ]
        heap[ parent_pos ] = e
        heap[ pos ] = t
        pos = parent_pos
        parent_pos = (parent_pos - parent_pos % 2) / 2
    end
end

--- Pop an element from a max heap
---@param heap table A max heap whose max element is at index 1.
---@param heap_size number current number of elements in the heap.
---@return any top the poped element
--- Note: This function does not change table size of "heap" to save CPU time.
local function minHeapPop( heap, heap_size )
    local top = heap[ 1 ]
    local e = heap[ heap_size ]
    local value = e[ 1 ]

    heap[ 1 ] = e
    heap[ heap_size ] = top
    heap_size = heap_size - 1

    local pos = 1
    local left_child_pos = pos * 2
    local right_child_pos = left_child_pos + 1

    while left_child_pos <= heap_size do
        local left_child = heap[ left_child_pos ]
        if (right_child_pos <= heap_size and heap[ right_child_pos ][ 1 ] < left_child[ 1 ]) then
            local right_child = heap[ right_child_pos ]
            if right_child[ 1 ] < value then
                heap[ right_child_pos ] = e
                heap[ pos ] = right_child
                pos = right_child_pos
                left_child_pos = pos * 2
                right_child_pos = left_child_pos + 1
            else
                break
            end
        else
            if left_child[ 1 ] < value then
                heap[ left_child_pos ] = e
                heap[ pos ] = left_child
                pos = left_child_pos
                left_child_pos = pos * 2
                right_child_pos = left_child_pos + 1
            else
                break
            end
        end
    end

    return top
end

--- Deflate defines a special huffman tree, which is unique once the bit length of huffman code of all symbols are known.
---@param bitlen_counts table Number of symbols with a specific bitlen
---@param symbol_bitlens table The bit length of a symbol
---@param max_symbol number The max symbol among all symbols, which is (number of symbols - 1)
---@param max_bitlen number The max huffman bit length among all symbols.
---@return table symbol_huffman_codes The huffman code of all symbols.
local function getHuffmanCodeFromBitlen( bitlen_counts, symbol_bitlens, max_symbol, max_bitlen )
    local huffman_code = 0
    local next_codes = {}
    local symbol_huffman_codes = {}

    for bitlen = 1, max_bitlen do
        huffman_code = (huffman_code + (bitlen_counts[ bitlen - 1 ] or 0)) * 2
        next_codes[ bitlen ] = huffman_code
    end

    for symbol = 0, max_symbol do
        local bitlen = symbol_bitlens[ symbol ]
        if bitlen then
            huffman_code = next_codes[ bitlen ]
            next_codes[ bitlen ] = huffman_code + 1

            ---Reverse the bits of huffman code,
            ---because most signifant bits of huffman code
            ---is stored first into the compressed data.
            ---@see RFC1951 Page5 Section 3.1.1
            if bitlen <= 9 then -- Have cached reverse for small bitlen.
                symbol_huffman_codes[ symbol ] = _reverse_bits_tbl[ bitlen ][ huffman_code ]
            else
                local reverse = 0
                for _ = 1, bitlen do
                    reverse = reverse - reverse % 2 + (((reverse % 2 == 1) or (huffman_code % 2) == 1) and 1 or 0)
                    huffman_code = (huffman_code - huffman_code % 2) / 2
                    reverse = reverse * 2
                end

                symbol_huffman_codes[ symbol ] = (reverse - reverse % 2) / 2
            end
        end
    end

    return symbol_huffman_codes
end

--- A helper function to sort heap elements
--- a[1], b[1] is the huffman frequency
--- a[2], b[2] is the symbol value.
local function sortByFirstThenSecond( a, b )
    return a[ 1 ] < b[ 1 ] or (a[ 1 ] == b[ 1 ] and a[ 2 ] < b[ 2 ])
end

--- Calculate the huffman bit length and huffman code.
---@param symbol_counts table A table whose table key is the symbol, and table value is the symbol frenquency (nil means 0 frequency).
---@param max_bitlen number See description of return value.
---@param max_symbol number The maximum symbol
---@return table symbol_bitlens A table whose key is the symbol, and the value is the huffman bit bit length. We guarantee that all bit length <= max_bitlen.
---For 0<=symbol<=max_symbol, table value could be nil if the frequency of the symbol is 0 or nil.
---@return table symbol_codes A table whose key is the symbol, and the value is the huffman code.
---@return number max_non_zero_bitlen_symbol A number indicating the maximum symbol whose bitlen is not 0.
local function getHuffmanBitlenAndCode( symbol_counts, max_bitlen, max_symbol )
    local heap_size
    local max_non_zero_bitlen_symbol = -1
    local leafs = {}
    local heap = {}
    local symbol_bitlens = {}
    local symbol_codes = {}
    local bitlen_counts = {}

    --[[
        tree[1]: weight, temporarily used as parent and bitLengths
        tree[2]: symbol
        tree[3]: left child
        tree[4]: right child
    --]]
    local number_unique_symbols = 0
    for symbol, count in raw_pairs( symbol_counts ) do
        number_unique_symbols = number_unique_symbols + 1
        leafs[ number_unique_symbols ] = { count, symbol }
    end

    if number_unique_symbols == 0 then
        -- no code.
        return {}, {}, -1
    elseif number_unique_symbols == 1 then
        -- Only one code. In this case, its huffman code
        -- needs to be assigned as 0, and bit length is 1.
        -- This is the only case that the return result
        -- represents an imcomplete huffman tree.
        local symbol = leafs[ 1 ][ 2 ]
        symbol_bitlens[ symbol ] = 1
        symbol_codes[ symbol ] = 0

        return symbol_bitlens, symbol_codes, symbol
    else
        table_sort( leafs, sortByFirstThenSecond )
        heap_size = number_unique_symbols

        for i = 1, heap_size do
            heap[ i ] = leafs[ i ]
        end

        while heap_size > 1 do
            -- Note: pop does not change table size of heap
            local leftChild = minHeapPop( heap, heap_size )
            heap_size = heap_size - 1

            local rightChild = minHeapPop( heap, heap_size )
            heap_size = heap_size - 1

            local newNode = { leftChild[ 1 ] + rightChild[ 1 ], -1, leftChild, rightChild }
            minHeapPush( heap, newNode, heap_size )
            heap_size = heap_size + 1
        end

        -- Number of leafs whose bit length is greater than max_len.
        local number_bitlen_overflow = 0

        -- Calculate bit length of all nodes
        local fifo = { heap[ 1 ], 0, 0, 0 } -- preallocate some spaces.
        local fifo_size = 1
        local index = 1
        heap[ 1 ][ 1 ] = 0

        while index <= fifo_size do -- Breath first search
            local e = fifo[ index ]
            local bitlen = e[ 1 ]
            local symbol = e[ 2 ]
            local left_child = e[ 3 ]
            local right_child = e[ 4 ]

            if left_child then
                fifo_size = fifo_size + 1
                fifo[ fifo_size ] = left_child
                left_child[ 1 ] = bitlen + 1
            end

            if right_child then
                fifo_size = fifo_size + 1
                fifo[ fifo_size ] = right_child
                right_child[ 1 ] = bitlen + 1
            end

            index = index + 1

            if bitlen > max_bitlen then
                number_bitlen_overflow = number_bitlen_overflow + 1
                bitlen = max_bitlen
            end

            if symbol >= 0 then
                symbol_bitlens[ symbol ] = bitlen
                max_non_zero_bitlen_symbol = (symbol > max_non_zero_bitlen_symbol) and symbol or max_non_zero_bitlen_symbol
                bitlen_counts[ bitlen ] = (bitlen_counts[ bitlen ] or 0) + 1
            end
        end

        ---Resolve bit length overflow
        ---@see ZLib/trees.c:gen_bitlen(s, desc), for reference
        if number_bitlen_overflow > 0 then
            repeat
                local bitlen = max_bitlen - 1
                while (bitlen_counts[ bitlen ] or 0) == 0 do
                    bitlen = bitlen - 1
                end

                -- move one leaf down the tree
                bitlen_counts[ bitlen ] = bitlen_counts[ bitlen ] - 1

                -- move one overflow item as its brother
                bitlen_counts[ bitlen + 1 ] = (bitlen_counts[ bitlen + 1 ] or 0) + 2
                bitlen_counts[ max_bitlen ] = bitlen_counts[ max_bitlen ] - 1

                -- TODO: check that math_max is necessary here
                number_bitlen_overflow = math_max( number_bitlen_overflow - 2, 0 )
            until number_bitlen_overflow == 0

            index = 1
            for bitlen = max_bitlen, 1, -1 do
                local n = bitlen_counts[ bitlen ] or 0
                while n > 0 do
                    local symbol = leafs[ index ][ 2 ]
                    symbol_bitlens[ symbol ] = bitlen

                    n = n - 1
                    index = index + 1
                end
            end
        end

        return symbol_bitlens, getHuffmanCodeFromBitlen( bitlen_counts, symbol_bitlens, max_symbol, max_bitlen ), max_non_zero_bitlen_symbol
    end
end

--- Calculate the first huffman header in the dynamic huffman block
---@see RFC1951 Page 12
---@param lcode_bitlens table The huffman bit length of literal/LZ77_length.
---@param max_non_zero_bitlen_lcode number The maximum literal/LZ77_length symbol whose huffman bit length is not zero.
---@param dcode_bitlens table The huffman bit length of LZ77 distance.
---@param max_non_zero_bitlen_dcode number The maximum LZ77 distance symbol whose huffman bit length is not zero.
---@return table rle_codes The run length encoded codes.
---@return table rle_extra_bits The extra bits. One entry for each rle code that needs extra bits. (code == 16 or 17 or 18).
---@return table rle_code_counts The count of appearance of each rle codes.
local function runLengthEncodeHuffmanBitlen( lcode_bitlens, max_non_zero_bitlen_lcode, dcode_bitlens, max_non_zero_bitlen_dcode )
    local rle_code_tblsize = 0
    local rle_codes = {}
    local rle_code_counts = {}
    local rle_extra_bits_tblsize = 0
    local rle_extra_bits = {}
    local prev = nil
    local count = 0

    -- If there is no distance code, assume one distance code of bit length 0.
    -- RFC1951: One distance code of zero bits means that
    -- there are no distance codes used at all (the data is all literals).
    max_non_zero_bitlen_dcode = (max_non_zero_bitlen_dcode < 0) and 0 or max_non_zero_bitlen_dcode
    local max_code = max_non_zero_bitlen_lcode + max_non_zero_bitlen_dcode + 1

    for code = 0, max_code + 1 do
        local len = (code <= max_non_zero_bitlen_lcode) and
            (lcode_bitlens[ code ] or 0) or ((code <= max_code) and
                (dcode_bitlens[ code - max_non_zero_bitlen_lcode - 1 ] or 0) or nil)

        if len == prev then
            count = count + 1

            if len ~= 0 and count == 6 then
                rle_code_tblsize = rle_code_tblsize + 1
                rle_codes[ rle_code_tblsize ] = 16
                rle_extra_bits_tblsize = rle_extra_bits_tblsize + 1
                rle_extra_bits[ rle_extra_bits_tblsize ] = 3
                rle_code_counts[ 16 ] = (rle_code_counts[ 16 ] or 0) + 1
                count = 0
            elseif len == 0 and count == 138 then
                rle_code_tblsize = rle_code_tblsize + 1
                rle_codes[ rle_code_tblsize ] = 18
                rle_extra_bits_tblsize = rle_extra_bits_tblsize + 1
                rle_extra_bits[ rle_extra_bits_tblsize ] = 127
                rle_code_counts[ 18 ] = (rle_code_counts[ 18 ] or 0) + 1
                count = 0
            end
        else
            if count == 1 then
                rle_code_tblsize = rle_code_tblsize + 1
                rle_codes[ rle_code_tblsize ] = prev
                ---@diagnostic disable-next-line: need-check-nil
                rle_code_counts[ prev ] = (rle_code_counts[ prev ] or 0) + 1
            elseif count == 2 then
                rle_code_tblsize = rle_code_tblsize + 1
                rle_codes[ rle_code_tblsize ] = prev
                rle_code_tblsize = rle_code_tblsize + 1
                rle_codes[ rle_code_tblsize ] = prev
                ---@diagnostic disable-next-line: need-check-nil
                rle_code_counts[ prev ] = (rle_code_counts[ prev ] or 0) + 2
            elseif count >= 3 then
                rle_code_tblsize = rle_code_tblsize + 1

                local rleCode = (prev ~= 0) and 16 or (count <= 10 and 17 or 18)
                rle_codes[ rle_code_tblsize ] = rleCode
                rle_code_counts[ rleCode ] = (rle_code_counts[ rleCode ] or 0) + 1
                rle_extra_bits_tblsize = rle_extra_bits_tblsize + 1
                rle_extra_bits[ rle_extra_bits_tblsize ] = (count <= 10) and (count - 3) or (count - 11)
            end

            prev = len

            if len and len ~= 0 then
                rle_code_tblsize = rle_code_tblsize + 1
                rle_codes[ rle_code_tblsize ] = len
                rle_code_counts[ len ] = (rle_code_counts[ len ] or 0) + 1
                count = 0
            else
                count = 1
            end
        end
    end

    return rle_codes, rle_extra_bits, rle_code_counts
end

--- Load the string into a table, in order to speed up LZ77.
--- Loop unrolled 16 times to speed this function up.
---@param str string The string to be loaded.
---@param t table The load destination
---@param start number str[index] will be the first character to be loaded.
---@param stop number str[index] will be the last character to be loaded
---@param offset number str[index] will be loaded into t[index-offset]
---@return table t
local function loadStringToTable( str, t, start, stop, offset )
    local i = start - offset
    while i <= (stop - 15 - offset) do
        t[ i ], t[ i + 1 ], t[ i + 2 ], t[ i + 3 ], t[ i + 4 ], t[ i + 5 ], t[ i + 6 ], t[ i + 7 ], t[ i + 8 ], t[ i + 9 ], t[ i + 10 ], t[ i + 11 ], t[ i + 12 ], t[ i + 13 ], t[ i + 14 ], t[ i + 15 ] = string_byte( str, i + offset, i + 15 + offset )
        i = i + 16
    end

    while i <= (stop - offset) do
        t[ i ] = string_byte( str, i + offset, i + offset )
        i = i + 1
    end

    return t
end

-- deflate.loadStringToTable = loadStringToTable

--- Do LZ77 process. This function uses the majority of the CPU time.
---@see zlib/deflate.c:deflate_fast(), zlib/deflate.c:deflate_slow()
---@see https://github.com/madler/zlib/blob/master/doc/algorithm.txt
--- This function uses the algorithms used above. You should read the
--- algorithm.txt above to understand what is the hash function and the lazy evaluation.
---
---
--- The special optimization used here is hash functions used here.
--- The hash function is just the multiplication of the three consective characters.
--- So if the hash matches, it guarantees 3 characters are matched.
--- This optimization can be implemented because Lua table is a hash table.
---
---@param level number number that describes compression level.
---@param string_table table table that stores the value of string to be compressed.
---			The index of this table starts from 1.
---			The caller needs to make sure all values needed by this function are loaded.
---
---			Assume "str" is the origin input string into the compressor
---			str[block_start]..str[block_end+3] needs to be loaded into
---			string_table[block_start-offset]..string_table[block_end-offset]
---			If dictionary is presented, the last 258 bytes of the dictionary
---			needs to be loaded into sing_table[-257..0]
---			(See more in the description of offset.)
---@param hash_tables table The table key is the hash value (0<=hash<=16777216=256^3)
---			The table value is an array0 that stores the indexes of the
---			input data string to be compressed, such that
---			hash == str[index]*str[index+1]*str[index+2]
---			Indexes are ordered in this array.
---@param block_start number The indexes of the input data string to be compressed. that starts the LZ77 block.
---@param block_end number The indexes of the input data string to be compressed. that stores the LZ77 block.
---@param offset number str[index] is stored in string_table[index-offset],
---			This offset is mainly an optimization to limit the index
---			of string_table, so lua can access this table quicker.
---@param dictionary table See deflate.createDictionary
---@return table lcodes literal/LZ77_length deflate codes.
---@return table lextra_bits the extra bits of literal/LZ77_length deflate codes.
---@return table lcodes_counts the count of each literal/LZ77 deflate code.
---@return table dcodes LZ77 distance deflate codes.
---@return table dextra_bits the extra bits of LZ77 distance deflate codes.
---@return table dcodes_counts the count of each LZ77 distance deflate code.
local function getBlockLZ77Result( level, string_table, hash_tables, block_start, block_end, offset, dictionary )
    local config = _compression_level_configs[ level ]
    local config_use_lazy, config_good_prev_length, config_max_lazy_match, config_nice_length, config_max_hash_chain = config[ 1 ], config[ 2 ], config[ 3 ], config[ 4 ], config[ 5 ]
    local config_max_insert_length = (not config_use_lazy) and config_max_lazy_match or 2147483646
    local config_good_hash_chain = (config_max_hash_chain - config_max_hash_chain % 4 / 4)

    local hash

    local dict_hash_tables
    local dict_string_table
    local dict_string_len = 0

    if dictionary then
        dict_hash_tables = dictionary.hash_tables
        dict_string_table = dictionary.string_table
        dict_string_len = dictionary.strlen
        assert( block_start == 1 )

        if block_end >= block_start and dict_string_len >= 2 then
            hash = dict_string_table[ dict_string_len - 1 ] * 0x10000 + dict_string_table[ dict_string_len ] * 0x100 + string_table[ 1 ]

            local t = hash_tables[ hash ]
            if t == nil then
                t = {}; hash_tables[ hash ] = t
            end

            table_insert( t, -1 )
        end

        if block_end >= block_start + 1 and dict_string_len >= 1 then
            hash = dict_string_table[ dict_string_len ] * 0x10000 + string_table[ 1 ] * 0x100 + string_table[ 2 ]

            local t = hash_tables[ hash ]
            if t == nil then
                t = {}; hash_tables[ hash ] = t
            end

            table_insert( t, 0 )
        end
    end

    local dict_string_len_plus3 = dict_string_len + 3

    hash = (string_table[ block_start - offset ] or 0) * 0x100 + (string_table[ block_start + 1 - offset ] or 0)

    local lcodes = {}
    local lcode_tblsize = 0
    local lcodes_counts = {}
    local dcodes = {}
    local dcodes_tblsize = 0
    local dcodes_counts = {}

    local lextra_bits = {}
    local lextra_bits_tblsize = 0
    local dextra_bits = {}
    local dextra_bits_tblsize = 0

    local match_available = false
    local prev_len
    local prev_dist
    local cur_len = 0
    local cur_dist = 0

    local index = block_start
    local index_end = block_end + (config_use_lazy and 1 or 0)

    -- the zlib source code writes separate code for lazy evaluation and
    -- not lazy evaluation, which is easier to understand.
    -- I put them together, so it is a bit harder to understand.
    -- because I think this is easier for me to maintain it.
    while index <= index_end do
        local string_table_index = index - offset
        local offset_minus_three = offset - 3

        prev_len = cur_len
        prev_dist = cur_dist
        cur_len = 0

        hash = (hash * 0x100 + (string_table[ string_table_index + 2 ] or 0)) % 0x1000000

        local chain_index
        local cur_chain
        local hash_chain = hash_tables[ hash ]
        local chain_old_size

        if not hash_chain then
            chain_old_size = 0
            hash_chain = {}
            hash_tables[ hash ] = hash_chain

            if dict_hash_tables then
                cur_chain = dict_hash_tables[ hash ]
                chain_index = cur_chain and #cur_chain or 0
            else
                chain_index = 0
            end
        else
            chain_old_size = #hash_chain
            cur_chain = hash_chain
            chain_index = chain_old_size
        end

        if index <= block_end then
            hash_chain[ chain_old_size + 1 ] = index
        end

        if (chain_index > 0 and index + 2 <= block_end and (not config_use_lazy or prev_len < config_max_lazy_match)) then
            local depth = (config_use_lazy and prev_len >= config_good_prev_length) and config_good_hash_chain or config_max_hash_chain
            local max_len_minus_one = block_end - index
            max_len_minus_one = (max_len_minus_one >= 257) and 257 or max_len_minus_one
            max_len_minus_one = max_len_minus_one + string_table_index

            local string_table_index_plus_three = string_table_index + 3

            while chain_index >= 1 and depth > 0 do
                local prev = cur_chain[ chain_index ]
                if index - prev > 32768 then
                    break
                end

                if prev < index then
                    local sj = string_table_index_plus_three
                    if prev >= -257 then
                        local pj = prev - offset_minus_three
                        while (sj <= max_len_minus_one and string_table[ pj ] == string_table[ sj ]) do
                            sj = sj + 1
                            pj = pj + 1
                        end
                    else
                        local pj = dict_string_len_plus3 + prev
                        while (sj <= max_len_minus_one and dict_string_table[ pj ] == string_table[ sj ]) do
                            sj = sj + 1
                            pj = pj + 1
                        end
                    end

                    local j = sj - string_table_index
                    if j > cur_len then
                        cur_len = j
                        cur_dist = index - prev
                    end

                    if cur_len >= config_nice_length then
                        break
                    end
                end

                chain_index = chain_index - 1
                depth = depth - 1

                if chain_index == 0 and prev > 0 and dict_hash_tables then
                    cur_chain = dict_hash_tables[ hash ]
                    chain_index = cur_chain and #cur_chain or 0
                end
            end
        end

        if not config_use_lazy then
            prev_len, prev_dist = cur_len, cur_dist
        end

        if ((not config_use_lazy or match_available) and (prev_len > 3 or (prev_len == 3 and prev_dist < 4096)) and cur_len <= prev_len) then
            local code = _length_to_deflate_code[ prev_len ]
            local length_extra_bits_bitlen = _length_to_deflate_extra_bitlen[ prev_len ]
            local dist_code, dist_extra_bits_bitlen, dist_extra_bits

            if prev_dist <= 0x100 then -- have cached code for small distance.
                dist_code = _dist256_to_deflate_code[ prev_dist ]
                dist_extra_bits = _dist256_to_deflate_extra_bits[ prev_dist ]
                dist_extra_bits_bitlen = _dist256_to_deflate_extra_bitlen[ prev_dist ]
            else
                dist_code = 0x10
                dist_extra_bits_bitlen = 7

                local a = 384
                local b = 512

                while true do
                    if prev_dist <= a then
                        dist_extra_bits = (prev_dist - (b / 2) - 1) % (b / 4)
                        break
                    elseif prev_dist <= b then
                        dist_extra_bits = (prev_dist - (b / 2) - 1) % (b / 4)
                        dist_code = dist_code + 1
                        break
                    else
                        dist_code = dist_code + 2
                        dist_extra_bits_bitlen = dist_extra_bits_bitlen + 1

                        a = a * 2
                        b = b * 2
                    end
                end
            end

            lcode_tblsize = lcode_tblsize + 1
            lcodes[ lcode_tblsize ] = code
            lcodes_counts[ code ] = (lcodes_counts[ code ] or 0) + 1

            dcodes_tblsize = dcodes_tblsize + 1
            dcodes[ dcodes_tblsize ] = dist_code
            dcodes_counts[ dist_code ] = (dcodes_counts[ dist_code ] or 0) + 1

            if length_extra_bits_bitlen > 0 then
                local lenExtraBits = _length_to_deflate_extra_bits[ prev_len ]
                lextra_bits_tblsize = lextra_bits_tblsize + 1
                lextra_bits[ lextra_bits_tblsize ] = lenExtraBits
            end

            if dist_extra_bits_bitlen > 0 then
                dextra_bits_tblsize = dextra_bits_tblsize + 1
                dextra_bits[ dextra_bits_tblsize ] = dist_extra_bits
            end

            for i = index + 1, index + prev_len - (config_use_lazy and 2 or 1) do
                hash = (hash * 0x100 + (string_table[ i - offset + 2 ] or 0)) % 0x1000000

                if prev_len <= config_max_insert_length then
                    hash_chain = hash_tables[ hash ]
                    if hash_chain == nil then
                        hash_chain = {}; hash_tables[ hash ] = hash_chain
                    end

                    table_insert( hash_chain, i )
                end
            end

            index = index + prev_len - (config_use_lazy and 1 or 0)
            match_available = false
        elseif (not config_use_lazy) or match_available then
            local code = string_table[ config_use_lazy and (string_table_index - 1) or string_table_index ]
            lcode_tblsize = lcode_tblsize + 1
            lcodes[ lcode_tblsize ] = code
            lcodes_counts[ code ] = (lcodes_counts[ code ] or 0) + 1
            index = index + 1
        else
            match_available = true
            index = index + 1
        end
    end

    -- Write "end of block" symbol
    lcode_tblsize = lcode_tblsize + 1
    lcodes[ lcode_tblsize ] = 0x100
    lcodes_counts[ 0x100 ] = (lcodes_counts[ 0x100 ] or 0) + 1

    return lcodes, lextra_bits, lcodes_counts, dcodes, dextra_bits, dcodes_counts
end

--- Get the header data of dynamic block.
---@param lcodes_counts table The count of each literal/LZ77_length codes.
---@param dcodes_counts table The count of each Lz77 distance codes.
---@return number HLIT The number of literal/LZ77_length codes.
---@return number HDIST The number of LZ77 distance codes.
---@return number HCLEN The number of Huffman codes.
---@return table rle_codes_huffman_bitlens The huffman bit length of literal codes.
---@return table rle_codes_huffman_codes The huffman symbol of literal codes.
---@return table lcodes_huffman_bitlens The huffman bit length of literal codes.
---@return table lcodes_huffman_codes The huffman symbol of literal codes.
---@return table dcodes_huffman_bitlens The huffman bit length of distance codes.
---@return table dcodes_huffman_codes The huffman symbol of distance codes.
---@return table rle_deflate_codes The huffman symbol of literal codes.
---@return table rle_extra_bits The extra bits of literal codes.
---@see RFC1951 Page 12
local function getBlockDynamicHuffmanHeader( lcodes_counts, dcodes_counts )
    local lcodes_huffman_bitlens, lcodes_huffman_codes, max_non_zero_bitlen_lcode = getHuffmanBitlenAndCode( lcodes_counts, 15, 285 )
    local dcodes_huffman_bitlens, dcodes_huffman_codes, max_non_zero_bitlen_dcode = getHuffmanBitlenAndCode( dcodes_counts, 15, 29 )

    local rle_deflate_codes, rle_extra_bits, rle_codes_counts = runLengthEncodeHuffmanBitlen( lcodes_huffman_bitlens, max_non_zero_bitlen_lcode, dcodes_huffman_bitlens, max_non_zero_bitlen_dcode )
    local rle_codes_huffman_bitlens, rle_codes_huffman_codes = getHuffmanBitlenAndCode( rle_codes_counts, 7, 18 )

    local HCLEN = 0
    for i = 1, 19 do
        if (rle_codes_huffman_bitlens[ _rle_codes_huffman_bitlen_order[ i ] ] or 0) ~= 0 then
            HCLEN = i
        end
    end

    HCLEN = HCLEN - 4

    local HLIT = max_non_zero_bitlen_lcode + 1 - 257
    local HDIST = max_non_zero_bitlen_dcode + 1 - 1
    if HDIST < 0 then
        HDIST = 0
    end

    return HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens, rle_codes_huffman_codes, rle_deflate_codes, rle_extra_bits, lcodes_huffman_bitlens, lcodes_huffman_codes, dcodes_huffman_bitlens, dcodes_huffman_codes
end

--- Get the size of dynamic block without writing any bits into the writer.
---@param lcodes table
---@param dcodes table
---@param HCLEN number
---@param rle_codes_huffman_bitlens table
---@param rle_deflate_codes table
---@param lcodes_huffman_bitlens table
---@param dcodes_huffman_bitlens table
---@return number block_bitlen the bit length of the dynamic block
local function getDynamicHuffmanBlockSize( lcodes, dcodes, HCLEN, rle_codes_huffman_bitlens, rle_deflate_codes, lcodes_huffman_bitlens, dcodes_huffman_bitlens )
    local block_bitlen = 17 -- 1+2+5+5+4
    block_bitlen = block_bitlen + (HCLEN + 4) * 3

    for i = 1, #rle_deflate_codes, 1 do
        local code = rle_deflate_codes[ i ]
        block_bitlen = block_bitlen + rle_codes_huffman_bitlens[ code ]

        if code >= 16 then
            block_bitlen = block_bitlen + ((code == 16) and 2 or (code == 17 and 3 or 7))
        end
    end

    local length_code_count = 0

    for i = 1, #lcodes, 1 do
        local code = lcodes[ i ]
        block_bitlen = block_bitlen + lcodes_huffman_bitlens[ code ]

        if code > 256 then -- Length code
            length_code_count = length_code_count + 1

            if code > 264 and code < 285 then -- Length code with extra bits
                local extra_bits_bitlen = _literal_deflate_code_to_extra_bitlen[ code - 256 ]
                block_bitlen = block_bitlen + extra_bits_bitlen
            end

            local dist_code = dcodes[ length_code_count ]
            block_bitlen = block_bitlen + dcodes_huffman_bitlens[ dist_code ]

            if dist_code > 3 then -- dist code with extra bits
                block_bitlen = block_bitlen + (dist_code - dist_code % 2) * 0.5 - 1
            end
        end
    end

    return block_bitlen
end

--- Write dynamic block.
---@param writeBits any
---@param is_last_block any
---@param lcodes any
---@param lextra_bits any
---@param dcodes any
---@param dextra_bits any
---@param HLIT any
---@param HDIST any
---@param HCLEN any
---@param rle_codes_huffman_bitlens any
---@param rle_codes_huffman_codes any
---@param rle_deflate_codes any
---@param rle_extra_bits any
---@param lcodes_huffman_bitlens any
---@param lcodes_huffman_codes any
---@param dcodes_huffman_bitlens any
---@param dcodes_huffman_codes any
local function compressDynamicHuffmanBlock( writeBits, is_last_block, lcodes, lextra_bits, dcodes, dextra_bits, HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens, rle_codes_huffman_codes, rle_deflate_codes, rle_extra_bits, lcodes_huffman_bitlens, lcodes_huffman_codes, dcodes_huffman_bitlens, dcodes_huffman_codes )
    writeBits( is_last_block and 1 or 0, 1 ) -- Last block identifier
    writeBits( 2, 2 )                        -- Dynamic Huffman block identifier

    writeBits( HLIT, 5 )
    writeBits( HDIST, 5 )
    writeBits( HCLEN, 4 )

    for i = 1, HCLEN + 4 do
        writeBits( rle_codes_huffman_bitlens[ _rle_codes_huffman_bitlen_order[ i ] ] or 0, 3 )
    end

    local rleExtraBitsIndex = 0

    for i = 1, #rle_deflate_codes, 1 do
        local code = rle_deflate_codes[ i ]
        writeBits( rle_codes_huffman_codes[ code ], rle_codes_huffman_bitlens[ code ] )

        if code >= 16 then
            rleExtraBitsIndex = rleExtraBitsIndex + 1
            writeBits( rle_extra_bits[ rleExtraBitsIndex ], (code == 16) and 2 or (code == 17 and 3 or 7) )
        end
    end

    local length_code_count = 0
    local length_code_with_extra_count = 0
    local dist_code_with_extra_count = 0

    for i = 1, #lcodes, 1 do
        local deflate_codee = lcodes[ i ]
        writeBits( lcodes_huffman_codes[ deflate_codee ], lcodes_huffman_bitlens[ deflate_codee ] )

        if deflate_codee > 256 then -- Length code
            length_code_count = length_code_count + 1

            if deflate_codee > 264 and deflate_codee < 285 then
                -- Length code with extra bits
                length_code_with_extra_count = length_code_with_extra_count + 1
                writeBits( lextra_bits[ length_code_with_extra_count ], _literal_deflate_code_to_extra_bitlen[ deflate_codee - 256 ] )
            end

            -- Write distance code
            local dist_deflate_code = dcodes[ length_code_count ]
            writeBits( dcodes_huffman_codes[ dist_deflate_code ], dcodes_huffman_bitlens[ dist_deflate_code ] )

            if dist_deflate_code > 3 then -- dist code with extra bits
                dist_code_with_extra_count = dist_code_with_extra_count + 1
                writeBits( dextra_bits[ dist_code_with_extra_count ], (dist_deflate_code - dist_deflate_code % 2) * 0.5 - 1 )
            end
        end
    end
end

--- Get the size of fixed block without writing any bits into the writer.
---@param lcodes table literal/LZ77_length deflate codes
---@param dcodes table LZ77 distance deflate codes
---@return number block_bitlen the bit length of the fixed block
local function getFixedHuffmanBlockSize( lcodes, dcodes )
    local block_bitlen = 3
    local length_code_count = 0

    for i = 1, #lcodes, 1 do
        local code = lcodes[ i ]

        block_bitlen = block_bitlen + _fix_block_literal_huffman_bitlen[ code ]

        if code > 256 then -- Length code
            length_code_count = length_code_count + 1

            if code > 264 and code < 285 then -- Length code with extra bits
                block_bitlen = block_bitlen + _literal_deflate_code_to_extra_bitlen[ code - 256 ]
            end

            local dist_code = dcodes[ length_code_count ]
            block_bitlen = block_bitlen + 5

            if dist_code > 3 then -- dist code with extra bits
                block_bitlen = block_bitlen + ((dist_code - dist_code % 2) / 2 - 1)
            end
        end
    end

    return block_bitlen
end

--- Write fixed block.
---@param lcodes table literal/LZ77_length deflate codes
---@param dcodes table LZ77 distance deflate codes
local function compressFixedHuffmanBlock( writeBits, is_last_block, lcodes, lextra_bits, dcodes, dextra_bits )
    writeBits( is_last_block and 1 or 0, 1 ) -- Last block identifier
    writeBits( 1, 2 )                        -- Fixed Huffman block identifier

    local length_code_count = 0
    local length_code_with_extra_count = 0
    local dist_code_with_extra_count = 0

    for i = 1, #lcodes, 1 do
        local deflate_code = lcodes[ i ]

        writeBits( _fix_block_literal_huffman_code[ deflate_code ], _fix_block_literal_huffman_bitlen[ deflate_code ] )

        if deflate_code > 256 then -- Length code
            length_code_count = length_code_count + 1

            if deflate_code > 264 and deflate_code < 285 then
                -- Length code with extra bits
                length_code_with_extra_count = length_code_with_extra_count + 1
                writeBits( lextra_bits[ length_code_with_extra_count ], _literal_deflate_code_to_extra_bitlen[ deflate_code - 256 ] )
            end

            -- Write distance code
            local dist_code = dcodes[ length_code_count ]
            writeBits( _fix_block_dist_huffman_code[ dist_code ], 5 )

            if dist_code > 3 then -- dist code with extra bits
                dist_code_with_extra_count = dist_code_with_extra_count + 1
                writeBits( dextra_bits[ dist_code_with_extra_count ], (dist_code - dist_code % 2) / 2 - 1 )
            end
        end
    end
end

--- Get the size of store block without writing any bits into the writer.
---@param block_start number The start index of the origin input string
---@param block_end number The end index of the origin input string
---@param total_bitlen number bit lens had been written into the compressed result before, because store block needs to shift to byte boundary.
---@return number block_bitlen the bit length of the fixed block
local function getStoreBlockSize( block_start, block_end, total_bitlen )
    assert( block_end - block_start + 1 <= 65535 )

    local block_bitlen = 3
    total_bitlen = total_bitlen + 3

    local padding_bitlen = (8 - total_bitlen % 8) % 8
    block_bitlen = block_bitlen + padding_bitlen
    block_bitlen = block_bitlen + 32
    block_bitlen = block_bitlen + (block_end - block_start + 1) * 8

    return block_bitlen
end

--- Write the store block.
local function compressStoreBlock( writeBits, writeString, is_last_block, str, block_start, block_end, total_bitlen )
    assert( block_end - block_start + 1 <= 65535 )

    writeBits( is_last_block and 1 or 0, 1 ) -- Last block identifer.
    writeBits( 0, 2 )                        -- Store block identifier.
    total_bitlen = total_bitlen + 3

    local padding_bitlen = (8 - total_bitlen % 8) % 8
    if padding_bitlen > 0 then
        writeBits( _pow2[ padding_bitlen ] - 1, padding_bitlen )
    end

    local size = block_end - block_start + 1
    writeBits( size, 16 )

    -- Write size's one's complement
    writeBits( (255 - size % 256) + (255 - (size - size % 256) / 256) * 256, 16 )
    writeString( string_sub( str, block_start, block_end ) )
end

--- Do the deflate
--- Currently using a simple way to determine the block size
--- (This is why the compression ratio is little bit worse than zlib when
--- the input size is very large
--- The first block is 64KB, the following block is 32KB.
--- After each block, there is a memory cleanup operation.
--- This is not a fast operation, but it is needed to save memory usage, so
--- the memory usage does not grow unboundly. If the data size is less than 64KB,
--- then memory cleanup won't happen.
--- This function determines whether to use store/fixed/dynamic blocks by
--- calculating the block size of each block type and chooses the smallest one.
local function deflate_fn( configs, writeBits, writeString, flushWriter, str, dictionary )
    local string_table = {}
    local hash_tables = {}
    local is_last_block = nil
    local block_start
    local block_end
    local bitlen_written
    local total_bitlen = flushWriter( _FLUSH_MODE_NO_FLUSH )
    local strlen = string_len( str )
    local offset

    local level
    local strategy
    if configs then
        if configs.level then level = configs.level end

        if configs.strategy then strategy = configs.strategy end
    end

    if not level then
        if strlen < 2048 then
            level = 7
        elseif strlen > 65536 then
            level = 3
        else
            level = 5
        end
    end

    while not is_last_block do
        if not block_start then
            block_start = 1
            block_end = 64 * 1024 - 1
            offset = 0
        else
            block_start = block_end + 1
            block_end = block_end + 32 * 1024
            offset = block_start - 32 * 1024 - 1
        end

        if block_end >= strlen then
            block_end = strlen
            is_last_block = true
        else
            is_last_block = false
        end

        local lcodes, lextra_bits, lcodes_counts, dcodes, dextra_bits, dcodes_counts
        local HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens, rle_codes_huffman_codes, rle_deflate_codes, rle_extra_bits, lcodes_huffman_bitlens, lcodes_huffman_codes, dcodes_huffman_bitlens, dcodes_huffman_codes

        local dynamic_block_bitlen
        local fixed_block_bitlen
        local store_block_bitlen

        if level ~= 0 then
            -- GetBlockLZ77 needs block_start to block_end+3 to be loaded.
            loadStringToTable( str, string_table, block_start, block_end + 3, offset )

            if block_start == 1 and dictionary then
                local dict_string_table = dictionary.string_table
                local dict_strlen = dictionary.strlen

                for i = 0, (-dict_strlen + 1) < -257 and -257 or (-dict_strlen + 1), -1 do
                    string_table[ i ] = dict_string_table[ dict_strlen + i ]
                end
            end

            if strategy == "huffman_only" then
                lcodes = {}
                loadStringToTable( str, lcodes, block_start, block_end, block_start - 1 )

                lextra_bits = {}
                lcodes_counts = {}
                lcodes[ block_end - block_start + 2 ] = 256 -- end of block

                for i = 1, block_end - block_start + 2 do
                    local code = lcodes[ i ]
                    lcodes_counts[ code ] = (lcodes_counts[ code ] or 0) + 1
                end

                dcodes = {}
                dextra_bits = {}
                dcodes_counts = {}
            else
                lcodes, lextra_bits, lcodes_counts, dcodes, dextra_bits, dcodes_counts = getBlockLZ77Result( level, string_table, hash_tables, block_start, block_end, offset, dictionary )
            end

            HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens, rle_codes_huffman_codes, rle_deflate_codes, rle_extra_bits, lcodes_huffman_bitlens, lcodes_huffman_codes, dcodes_huffman_bitlens, dcodes_huffman_codes = getBlockDynamicHuffmanHeader( lcodes_counts, dcodes_counts )
            dynamic_block_bitlen = getDynamicHuffmanBlockSize( lcodes, dcodes, HCLEN, rle_codes_huffman_bitlens, rle_deflate_codes, lcodes_huffman_bitlens, dcodes_huffman_bitlens )
            fixed_block_bitlen = getFixedHuffmanBlockSize( lcodes, dcodes )
        end

        store_block_bitlen = getStoreBlockSize( block_start, block_end, total_bitlen )

        local min_bitlen = store_block_bitlen
        min_bitlen = (fixed_block_bitlen and fixed_block_bitlen < min_bitlen) and fixed_block_bitlen or min_bitlen
        min_bitlen = (dynamic_block_bitlen and dynamic_block_bitlen < min_bitlen) and dynamic_block_bitlen or min_bitlen

        if level == 0 or (strategy ~= "fixed" and strategy ~= "dynamic" and store_block_bitlen == min_bitlen) then
            compressStoreBlock( writeBits, writeString, is_last_block, str, block_start, block_end, total_bitlen )
            total_bitlen = total_bitlen + store_block_bitlen
        elseif strategy ~= "dynamic" and (strategy == "fixed" or fixed_block_bitlen == min_bitlen) then
            compressFixedHuffmanBlock( writeBits, is_last_block, lcodes, lextra_bits, dcodes, dextra_bits )
            total_bitlen = total_bitlen + fixed_block_bitlen
        elseif strategy == "dynamic" or dynamic_block_bitlen == min_bitlen then
            compressDynamicHuffmanBlock( writeBits, is_last_block, lcodes, lextra_bits, dcodes, dextra_bits, HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens, rle_codes_huffman_codes, rle_deflate_codes, rle_extra_bits, lcodes_huffman_bitlens, lcodes_huffman_codes, dcodes_huffman_bitlens, dcodes_huffman_codes )
            total_bitlen = total_bitlen + dynamic_block_bitlen
        end

        if is_last_block then
            bitlen_written = flushWriter( _FLUSH_MODE_NO_FLUSH )
        else
            bitlen_written = flushWriter( _FLUSH_MODE_MEMORY_CLEANUP )
        end

        assert( bitlen_written == total_bitlen )

        -- Memory clean up, so memory consumption does not always grow linearly, even if input string is > 64K.
        -- Not a very efficient operation, but this operation won't happen
        -- when the input data size is less than 64K.
        if not is_last_block then
            local j
            if dictionary and block_start == 1 then
                j = 0

                while string_table[ j ] do
                    string_table[ j ] = nil
                    j = j - 1
                end
            end

            dictionary = nil
            j = 1

            for i = block_end - 32767, block_end do
                string_table[ j ] = string_table[ i - offset ]
                j = j + 1
            end

            for k, t in raw_pairs( hash_tables ) do
                local tSize = #t
                if tSize > 0 and (block_end + 1 - t[ 1 ]) > 32768 then
                    if tSize == 1 then
                        hash_tables[ k ] = nil
                    else
                        local new = {}
                        local newSize = 0

                        for i = 2, tSize do
                            j = t[ i ]

                            if (block_end + 1 - j) <= 32768 then
                                newSize = newSize + 1
                                new[ newSize ] = j
                            end
                        end

                        hash_tables[ k ] = new
                    end
                end
            end
        end
    end
end

--- The description to compression configuration table.
---
--- Any field can be nil to use its default.
---
--- Table with keys other than those below is an invalid table.
---@class compression_configs
---@field level number The compression level ranged from 0 to 9. 0 is no compression. 9 is the slowest but best compression. Use nil for default level.
---@field strategy string The compression strategy. "fixed" to only use fixed deflate compression block. "dynamic" to only use dynamic block. "huffman_only" to do no LZ77 compression. Only do huffman compression.


--- Compress using the raw deflate format.
---@param str string The data to be compressed.
---@param configs? table The configuration table to control the compression.
---@param dictionary? table The dictionary to use.
--- If nil, use the default configuration.
---@return string? result The compressed data.
---@return number bit_count The number of bits padded at the end of output.
--- 0 <= bits < 8
---
--- This means the most significant "bits" of the last byte of the returned
--- compressed data are padding bits and they don't affect decompression.
--- You don't need to use this value unless you want to do some postprocessing
--- to the compressed data.
---@see compression_configs
---@see deflate.decompress
function deflate.compress( str, configs, dictionary )
    if configs ~= nil then
        validate_configs( configs, 2 )
    end

    if dictionary ~= nil then
        validate_dictionary( dictionary, 2 )
    end

    local writeBits, writeString, flushWriter = createWriter()
    deflate_fn( configs, writeBits, writeString, flushWriter, str, dictionary )

    local total_bitlen, result = flushWriter( _FLUSH_MODE_OUTPUT )
    return result, (8 - total_bitlen % 8) % 8
end

--- Compress using the zlib format.
---@param str string the data to be compressed.
---@param configs? table The configuration table to control the compression. If `nil`, use the default configuration.
---@param dictionary? table A preset dictionary produced by deflate.createDictionary()
---@return string? result The compressed data.
---@return number bit_count The number of bits padded at the end of output.
--- Should always be 0.
--- Zlib formatted compressed data never has padding bits at the end.
---@see compression_configs
---@see zlib.compress
---@see zlib.decompress
function zlib.compress( str, configs, dictionary )
    if configs ~= nil then
        validate_configs( configs, 2 )
    end

    if dictionary ~= nil then
        validate_dictionary( dictionary, 2 )
    end

    local writeBits, writeString, flushWriter = createWriter()

    local CM = 8    -- Compression method
    local CINFO = 7 -- Window Size = 32K
    local CMF = CINFO * 16 + CM
    writeBits( CMF, 8 )

    local FDIST = dictionary and 1 or 0
    local FLEVEL = 2 -- Default compression
    local FLG = FLEVEL * 64 + FDIST * 32
    local FCHECK = (31 - (CMF * 256 + FLG) % 31)

    -- The FCHECK value must be such that CMF and FLG, when viewed as a 16-bit unsigned integer stored in MSB order (CMF*256 + FLG), is a multiple of 31.
    FLG = FLG + FCHECK
    writeBits( FLG, 8 )

    if FDIST == 1 then
        ---@cast dictionary table
        local adler32 = dictionary.adler32
        local byte0 = adler32 % 0x100

        adler32 = (adler32 - byte0) / 0x100
        local byte1 = adler32 % 0x100

        adler32 = (adler32 - byte1) / 0x100
        local byte2 = adler32 % 0x100

        adler32 = (adler32 - byte2) / 0x100
        local byte3 = adler32 % 0x100

        writeBits( byte3, 8 )
        writeBits( byte2, 8 )
        writeBits( byte1, 8 )
        writeBits( byte0, 8 )
    end

    deflate_fn( configs, writeBits, writeString, flushWriter, str, dictionary )
    flushWriter( _FLUSH_MODE_BYTE_BOUNDARY )

    -- Most significant byte first
    local adler32 = Adler32_digest( str )
    local byte3 = adler32 % 0x100

    adler32 = (adler32 - byte3) / 0x100
    local byte2 = adler32 % 0x100

    adler32 = (adler32 - byte2) / 0x100
    local byte1 = adler32 % 0x100

    adler32 = (adler32 - byte1) / 0x100
    local byte0 = adler32 % 0x100

    writeBits( byte0, 8 )
    writeBits( byte1, 8 )
    writeBits( byte2, 8 )
    writeBits( byte3, 8 )

    local total_bitlen, result = flushWriter( _FLUSH_MODE_OUTPUT )
    return result, (8 - total_bitlen % 8) % 8
end

-- Decompress code --

--[[
    Create a reader to easily reader stuffs as the unit of bits.
    Return values:
    1. readBits(bitlen)
    2. readBytes(bytelen, buffer, buffer_size)
    3. Decode(huffman_bitlen_count, huffman_symbol, min_bitlen)
    4. readerBitlenLeft()
    5. skipToByteBoundary()
--]]
local function createReader( input )
    local input_strlen = string_len( input )
    local input_next_byte_pos = 1
    local cache_bitlen = 0
    local cache = 0

    --- Read some bits.
    --- To improve speed, this function does not
    --- check if the input has been exhausted.
    --- Use readerBitlenLeft() < 0 to check it.
    ---@param bitlen number the number of bits to read
    ---@return number code the data is read.
    local function readBits( bitlen )
        local rshift_mask = _pow2[ bitlen ]
        local code

        if bitlen <= cache_bitlen then
            code = cache % rshift_mask
            cache = (cache - code) / rshift_mask
            cache_bitlen = cache_bitlen - bitlen
        else -- Whether input has been exhausted is not checked.
            local lshift_mask = _pow2[ cache_bitlen ]
            local byte1, byte2, byte3, byte4 = string_byte( input, input_next_byte_pos, input_next_byte_pos + 3 )

            -- This requires lua number to be at least double ()
            cache = cache + ((byte1 or 0) + (byte2 or 0) * 256 + (byte3 or 0) * 65536 + (byte4 or 0) * 16777216) * lshift_mask
            input_next_byte_pos = input_next_byte_pos + 4
            cache_bitlen = cache_bitlen + 32 - bitlen
            code = cache % rshift_mask

            cache = (cache - code) / rshift_mask
        end

        return code
    end

    --- Read some bytes from the reader.
    --- Assume reader is on the byte boundary.
    ---@param bytelen number The number of bytes to be read.
    ---@param buffer table The byte read will be stored into this buffer.
    ---@param buffer_size number The buffer will be modified starting from
    ---	buffer[buffer_size+1], ending at buffer[buffer_size+bytelen-1]
    ---@return number size the new buffer_size
    local function readBytes( bytelen, buffer, buffer_size )
        assert( cache_bitlen % 8 == 0 )

        local byte_from_cache = (cache_bitlen / 8 < bytelen) and (cache_bitlen / 8) or bytelen
        for _ = 1, byte_from_cache do
            local byte = cache % 0x100
            buffer_size = buffer_size + 1
            buffer[ buffer_size ] = string_char( byte )
            cache = (cache - byte) / 0x100
        end

        cache_bitlen = cache_bitlen - byte_from_cache * 8
        bytelen = bytelen - byte_from_cache

        if (input_strlen - input_next_byte_pos - bytelen + 1) * 8 + cache_bitlen < 0 then
            return -1 -- out of input
        end

        for i = input_next_byte_pos, input_next_byte_pos + bytelen - 1 do
            buffer_size = buffer_size + 1
            buffer[ buffer_size ] = string_sub( input, i, i )
        end

        input_next_byte_pos = input_next_byte_pos + bytelen
        return buffer_size
    end

    --- Decode huffman code
    --- To improve speed, this function does not check
    --- if the input has been exhausted.
    --- Use readerBitlenLeft() < 0 to check it.
    --- Credits for Mark Adler. This code is from puff:decode()
    ---@see puff:decode(...)
    ---@param huffman_bitlen_counts number
    ---@param huffman_symbols number
    ---@param min_bitlen number The minimum huffman bit length of all symbols
    ---@return number code The decoded deflate code.
    ---	Negative value is returned if decoding fails.
    local function decode( huffman_bitlen_counts, huffman_symbols, min_bitlen )
        local code = 0
        local first = 0
        local index = 0
        local count

        if min_bitlen > 0 then
            if cache_bitlen < 15 and input then
                local lshift_mask = _pow2[ cache_bitlen ]
                local byte1, byte2, byte3, byte4 = string_byte( input, input_next_byte_pos, input_next_byte_pos + 3 )

                -- This requires lua number to be at least double ()
                cache = cache + ((byte1 or 0) + (byte2 or 0) * 0x100 + (byte3 or 0) * 0x10000 + (byte4 or 0) * 0x1000000) * lshift_mask
                input_next_byte_pos = input_next_byte_pos + 4
                cache_bitlen = cache_bitlen + 32
            end

            local rshift_mask = _pow2[ min_bitlen ]
            cache_bitlen = cache_bitlen - min_bitlen
            code = cache % rshift_mask
            cache = (cache - code) / rshift_mask

            -- Reverse the bits
            code = _reverse_bits_tbl[ min_bitlen ][ code ]

            count = huffman_bitlen_counts[ min_bitlen ]
            if code < count then
                return huffman_symbols[ code ]
            end

            index = count
            first = count * 2
            code = code * 2
        end

        for bitlen = min_bitlen + 1, 15 do
            local bit = cache % 2
            cache = (cache - bit) / 2
            cache_bitlen = cache_bitlen - 1

            code = (bit == 1) and (code + 1 - code % 2) or code
            count = huffman_bitlen_counts[ bitlen ] or 0

            local diff = code - first
            if diff < count then
                return huffman_symbols[ index + diff ]
            end

            index = index + count
            first = first + count
            first = first * 2
            code = code * 2
        end

        -- invalid literal/length or distance code in fixed or dynamic block (run out of code)
        return -10
    end

    local function readerBitlenLeft()
        return (input_strlen - input_next_byte_pos + 1) * 8 + cache_bitlen
    end

    local function skipToByteBoundary()
        local skipped_bitlen = cache_bitlen % 8
        local rshift_mask = _pow2[ skipped_bitlen ]
        cache_bitlen = cache_bitlen - skipped_bitlen
        cache = (cache - cache % rshift_mask) / rshift_mask
    end

    return readBits, readBytes, decode, readerBitlenLeft, skipToByteBoundary
end

--- Create a deflate state, so I can pass in less arguments to functions.
---@param str string the whole string to be decompressed.
---@param dictionary? table The preset dictionary. nil if not provided.
--- This dictionary should be produced by deflate.createDictionary(str)
---@return table state The decomrpess state.
local function createDecompressState( str, dictionary )
    local readBits, readBytes, decode, readerBitlenLeft, skipToByteBoundary = createReader( str )
    return {
        [ "readBits" ] = readBits,
        [ "readBytes" ] = readBytes,
        [ "decode" ] = decode,
        [ "readerBitlenLeft" ] = readerBitlenLeft,
        [ "skipToByteBoundary" ] = skipToByteBoundary,
        [ "buffer_size" ] = 0,
        [ "buffer" ] = {},
        [ "result_buffer" ] = {},
        [ "dictionary" ] = dictionary
    }
end

--- Get the stuffs needed to decode huffman codes
---@see puff.c:construct(...)
---@param huffman_bitlens table The huffman bit length of the huffman codes.
---@param max_symbol number The maximum symbol
---@param max_bitlen number The min huffman bit length of all codes
---@return number left zero or positive for success, negative for failure.
---@return table huffman_bitlen_counts The count of each huffman bit length.
---@return table huffman_symbols A table to convert huffman codes to deflate codes.
---@return number min_bitlen The minimum huffman bit length.
local function getHuffmanForDecode( huffman_bitlens, max_symbol, max_bitlen )
    local huffman_bitlen_counts = {}
    local min_bitlen = max_bitlen

    for symbol = 0, max_symbol do
        local bitlen = huffman_bitlens[ symbol ] or 0
        min_bitlen = (bitlen > 0 and bitlen < min_bitlen) and bitlen or min_bitlen
        huffman_bitlen_counts[ bitlen ] = (huffman_bitlen_counts[ bitlen ] or 0) + 1
    end

    if huffman_bitlen_counts[ 0 ] == max_symbol + 1 then -- No Codes
        return 0, huffman_bitlen_counts, {}, 0           -- Complete, but decode will fail
    end

    local left = 1
    for len = 1, max_bitlen do
        left = left * 2
        left = left - (huffman_bitlen_counts[ len ] or 0)
        if left < 0 then
            return left, huffman_bitlen_counts, {}, 0 -- Over-subscribed, return negative
        end
    end

    -- Generate offsets info symbol table for each length for sorting
    local offsets = {
        [ 1 ] = 0
    }

    for len = 1, max_bitlen - 1 do
        offsets[ len + 1 ] = offsets[ len ] + (huffman_bitlen_counts[ len ] or 0)
    end

    local huffman_symbols = {}
    for symbol = 0, max_symbol do
        local bitlen = huffman_bitlens[ symbol ] or 0
        if bitlen ~= 0 then
            local offset = offsets[ bitlen ]
            huffman_symbols[ offset ] = symbol
            offsets[ bitlen ] = offsets[ bitlen ] + 1
        end
    end

    -- Return zero for complete set, positive for incomplete set.
    return left, huffman_bitlen_counts, huffman_symbols, min_bitlen
end

--- Decode a fixed or dynamic huffman blocks, excluding last block identifier
--- and block type identifer.
---@see puff.c:codes()
---@param state table decompression state that will be modified by this function.
---@param lcodes_huffman_bitlens table The huffman bit length of literal codes.
---@param lcodes_huffman_symbols table The huffman symbol of literal codes.
---@param lcodes_huffman_min_bitlen number The minimum huffman bit length of literal codes.
---@param dcodes_huffman_bitlens table The huffman bit length of distance codes.
---@param dcodes_huffman_symbols table The huffman symbol of distance codes.
---@param dcodes_huffman_min_bitlen number The minimum huffman bit length of distance codes.
---@return number status 0 on success, other value on failure.
local function decodeUntilEndOfBlock( state, lcodes_huffman_bitlens, lcodes_huffman_symbols, lcodes_huffman_min_bitlen, dcodes_huffman_bitlens, dcodes_huffman_symbols, dcodes_huffman_min_bitlen )
    local buffer, buffer_size, readBits, decode, readerBitlenLeft, result_buffer = state.buffer, state.buffer_size, state.readBits, state.decode, state.readerBitlenLeft, state.result_buffer
    local dictionary = state.dictionary
    local dict_string_table
    local dict_strlen

    local buffer_end = 1
    if dictionary and not buffer[ 0 ] then
        -- If there is a dictionary, copy the last 258 bytes into
        -- the string_table to make the copy in the main loop quicker.
        -- This is done only once per decompression.
        dict_string_table = dictionary.string_table
        dict_strlen = dictionary.strlen
        buffer_end = -dict_strlen + 1

        for i = 0, (-dict_strlen + 1) < -257 and -257 or (-dict_strlen + 1), -1 do
            buffer[ i ] = string_char( dict_string_table[ dict_strlen + i ] )
        end
    end

    repeat
        local symbol = decode( lcodes_huffman_bitlens, lcodes_huffman_symbols, lcodes_huffman_min_bitlen )
        if symbol < 0 or symbol > 285 then
            -- invalid literal/length or distance code in fixed or dynamic block
            return -10
        elseif symbol < 256 then -- Literal
            buffer_size = buffer_size + 1
            buffer[ buffer_size ] = string_char( symbol )
        elseif symbol > 256 then -- Length code
            symbol = symbol - 256
            local bitlen = _literal_deflate_code_to_base_len[ symbol ]
            bitlen = (symbol >= 8) and (bitlen + readBits( _literal_deflate_code_to_extra_bitlen[ symbol ] )) or bitlen
            symbol = decode( dcodes_huffman_bitlens, dcodes_huffman_symbols, dcodes_huffman_min_bitlen )

            if symbol < 0 or symbol > 29 then
                -- invalid literal/length or distance code in fixed or dynamic block
                return -10
            end

            local dist = _dist_deflate_code_to_base_dist[ symbol ]
            dist = (dist > 4) and (dist + readBits( _dist_deflate_code_to_extra_bitlen[ symbol ] )) or dist

            local char_buffer_index = buffer_size - dist + 1
            if char_buffer_index < buffer_end then
                -- distance is too far back in fixed or dynamic block
                return -11
            end

            if char_buffer_index >= -257 then
                for _ = 1, bitlen do
                    buffer_size = buffer_size + 1
                    buffer[ buffer_size ] = buffer[ char_buffer_index ]
                    char_buffer_index = char_buffer_index + 1
                end
            else
                char_buffer_index = dict_strlen + char_buffer_index
                for _ = 1, bitlen do
                    buffer_size = buffer_size + 1
                    buffer[ buffer_size ] = string_char( dict_string_table[ char_buffer_index ] )
                    char_buffer_index = char_buffer_index + 1
                end
            end
        end

        if readerBitlenLeft() < 0 then
            return 2 -- available inflate data did not terminate
        end

        if buffer_size >= 65536 then
            table_insert( result_buffer, table_concat( buffer, "", 1, 32768 ) )

            for i = 32769, buffer_size do
                buffer[ i - 32768 ] = buffer[ i ]
            end

            buffer_size = buffer_size - 32768
            buffer[ buffer_size + 1 ] = nil

            -- NOTE: buffer[32769..end] and buffer[-257..0] are not cleared.
            -- This is why "buffer_size" variable is needed.
        end
    until symbol == 256

    state.buffer_size = buffer_size

    return 0
end

--- Decompress a store block
---@param state table decompression state that will be modified by this function.
---@return number status 0 if succeeds, other value if fails.
local function decompressStoreBlock( state )
    local buffer, buffer_size, readBits, readBytes, readerBitlenLeft, skipToByteBoundary, result_buffer = state.buffer, state.buffer_size, state.readBits, state.readBytes, state.readerBitlenLeft, state.skipToByteBoundary, state.result_buffer
    skipToByteBoundary()

    local bytelen = readBits( 16 )
    if readerBitlenLeft() < 0 then
        return 2 -- available inflate data did not terminate
    end

    local bytelenComp = readBits( 16 )
    if readerBitlenLeft() < 0 then
        return 2 -- available inflate data did not terminate
    end

    if bytelen % 256 + bytelenComp % 256 ~= 255 then
        return -2 -- Not one's complement
    end

    if (bytelen - bytelen % 256) / 256 + (bytelenComp - bytelenComp % 256) / 256 ~= 255 then
        return -2 -- Not one's complement
    end

    -- Note that readBytes will skip to the next byte boundary first.
    buffer_size = readBytes( bytelen, buffer, buffer_size )
    if buffer_size < 0 then
        return 2 -- available inflate data did not terminate
    end

    -- memory clean up when there are enough bytes in the buffer.
    if buffer_size >= 65536 then
        table_insert( result_buffer, table_concat( buffer, "", 1, 32768 ) )

        for i = 32769, buffer_size do
            buffer[ i - 32768 ] = buffer[ i ]
        end

        buffer_size = buffer_size - 32768
        buffer[ buffer_size + 1 ] = nil
    end

    state.buffer_size = buffer_size
    return 0
end

--- Decompress a fixed block
---@param state table decompression state that will be modified by this function.
---@return number status 0 if succeeds other value if fails.
local function decompressFixBlock( state )
    return decodeUntilEndOfBlock( state, _fix_block_literal_huffman_bitlen_count, _fix_block_literal_huffman_to_deflate_code, 7, _fix_block_dist_huffman_bitlen_count, _fix_block_dist_huffman_to_deflate_code, 5 )
end

--- Decompress a dynamic block
---@param state table decompression state that will be modified by this function.
---@return number status 0 if success, other value if fails.
local function decompressDynamicBlock( state )
    local readBits, decode = state.readBits, state.decode

    local nlen = readBits( 5 ) + 257
    local ndist = readBits( 5 ) + 1
    local ncode = readBits( 4 ) + 4

    -- dynamic block code description: too many length or distance codes
    if nlen > 286 or ndist > 30 then
        return -3
    end

    local rle_codes_huffman_bitlens = {}
    for i = 1, ncode do
        rle_codes_huffman_bitlens[ _rle_codes_huffman_bitlen_order[ i ] ] = readBits( 3 )
    end

    local rle_codes_err, rle_codes_huffman_bitlen_counts, rle_codes_huffman_symbols, rle_codes_huffman_min_bitlen = getHuffmanForDecode( rle_codes_huffman_bitlens, 18, 7 )

    -- dynamic block code description: code lengths codes incomplete
    if rle_codes_err ~= 0 then -- Require complete code set here
        return -4
    end

    local lcodes_huffman_bitlens = {}
    local dcodes_huffman_bitlens = {}

    -- Read length/literal and distance code length tables
    local index = 0
    while index < (nlen + ndist) do
        -- Decoded value
        local symbol = decode( rle_codes_huffman_bitlen_counts, rle_codes_huffman_symbols, rle_codes_huffman_min_bitlen )

        -- Last length to repeat
        local bitlen

        if symbol < 0 then
            return symbol -- Invalid symbol
        elseif symbol < 16 then
            if index < nlen then
                lcodes_huffman_bitlens[ index ] = symbol
            else
                dcodes_huffman_bitlens[ index - nlen ] = symbol
            end

            index = index + 1
        else
            bitlen = 0

            if symbol == 16 then
                -- dynamic block code description: repeat lengths with no first length
                if index == 0 then
                    return -5
                end

                if index - 1 < nlen then
                    bitlen = lcodes_huffman_bitlens[ index - 1 ]
                else
                    bitlen = dcodes_huffman_bitlens[ index - nlen - 1 ]
                end

                symbol = 3 + readBits( 2 )
            elseif symbol == 17 then -- Repeat zero 3..10 times
                symbol = 3 + readBits( 3 )
            else                     -- == 18, repeat zero 11.138 times
                symbol = 11 + readBits( 7 )
            end

            -- dynamic block code description:
            -- repeat more than specified lengths
            if index + symbol > nlen + ndist then
                return -6
            end

            while symbol > 0 do -- Repeat last or zero symbol times
                symbol = symbol - 1

                if index < nlen then
                    lcodes_huffman_bitlens[ index ] = bitlen
                else
                    dcodes_huffman_bitlens[ index - nlen ] = bitlen
                end

                index = index + 1
            end
        end
    end

    -- dynamic block code description: missing end-of-block code
    if (lcodes_huffman_bitlens[ 0x100 ] or 0) == 0 then
        return -9
    end

    local lcodes_err, lcodes_huffman_bitlen_counts, lcodes_huffman_symbols, lcodes_huffman_min_bitlen = getHuffmanForDecode( lcodes_huffman_bitlens, nlen - 1, 15 )

    -- dynamic block code description: invalid literal/length code lengths,
    -- Incomplete code ok only for single length 1 code
    ---@diagnostic disable-next-line: need-check-nil
    if (lcodes_err ~= 0 and (lcodes_err < 0 or nlen ~= (lcodes_huffman_bitlen_counts[ 0 ] or 0) + (lcodes_huffman_bitlen_counts[ 1 ] or 0))) then
        return -7
    end

    local dcodes_err, dcodes_huffman_bitlen_counts, dcodes_huffman_symbols, dcodes_huffman_min_bitlen = getHuffmanForDecode( dcodes_huffman_bitlens, ndist - 1, 15 )

    -- dynamic block code description: invalid distance code lengths,
    -- Incomplete code ok only for single length 1 code
    ---@diagnostic disable-next-line: need-check-nil
    if (dcodes_err ~= 0 and (dcodes_err < 0 or ndist ~= (dcodes_huffman_bitlen_counts[ 0 ] or 0) + (dcodes_huffman_bitlen_counts[ 1 ] or 0))) then
        return -8
    end

    ---Build buffman table for literal/length codes
    return decodeUntilEndOfBlock( state, lcodes_huffman_bitlen_counts, lcodes_huffman_symbols, lcodes_huffman_min_bitlen, dcodes_huffman_bitlen_counts, dcodes_huffman_symbols, dcodes_huffman_min_bitlen )
end

--- Decompress a deflate stream
---
---@param state table a decompression state
---@return string | nil str the decompressed string if succeeds. nil if fails.
---@return number | nil status 0 if succeeds, other value if fails
local function inflate( state )
    local readBits = state.readBits

    local is_last_block
    while not is_last_block do
        is_last_block = readBits( 1 ) == 1

        local block_type = readBits( 2 )
        local status
        if block_type == 0 then
            status = decompressStoreBlock( state )
        elseif block_type == 1 then
            status = decompressFixBlock( state )
        elseif block_type == 2 then
            status = decompressDynamicBlock( state )
        else
            return nil, -1 -- invalid block type (type == 3)
        end

        if status ~= 0 then
            return nil, status
        end
    end

    local result_buffer = state.result_buffer
    return table_concat( result_buffer, "", 1, table_insert( result_buffer, table_concat( state.buffer, "", 1, state.buffer_size ) ) )
end

--- Decompress a raw deflate compressed data.
---@param str string The data to be decompressed.
---@param dictionary? table The dictionary to be used.
---@return string | nil data If the decompression succeeds, return the decompressed data.
--- If the decompression fails, return nil. You should check if this return
--- value is non-nil to know if the decompression succeeds.
---@return number | nil byte_count If the decompression succeeds, return the number of
--- unprocessed bytes in the input compressed data. This return value is a
--- positive integer if the input data is a valid compressed data appended by an
--- arbitary non-empty string. This return value is 0 if the input data does not
--- contain any extra bytes.
---
--- If the decompression fails (The first return value of this function is nil),
--- this return value is undefined.
---@see deflate.compress
---@see deflate.decompress(str)
function deflate.decompress( str, dictionary )
    if dictionary ~= nil then
        validate_dictionary( dictionary, 2 )
    end

    local state = createDecompressState( str, dictionary )

    local result, status = inflate( state )
    if not result then
        return nil, status
    end

    local bitlen_left = state.readerBitlenLeft()
    return result, (bitlen_left - bitlen_left % 8) * 0.125
end

--- Decompress a zlib compressed data.
---@param str string The data to be decompressed
---@param dictionary? table The dictionary to be used
---@return string | nil data If the decompression succeeds, return the decompressed data.
--- If the decompression fails, return nil. You should check if this return
--- value is non-nil to know if the decompression succeeds.
---@return number | nil byte_count If the decompression succeeds, return the number of
--- unprocessed bytes in the input compressed data. This return value is a
--- positive integer if the input data is a valid compressed data appended by an
--- arbitary non-empty string. This return value is 0 if the input data does not
--- contain any extra bytes.
---
--- If the decompression fails (The first return value of this function is nil),
--- this return value is undefined.
---@see zlib.compress
---@see zlib.decompress(str)
function zlib.decompress( str, dictionary )
    if dictionary ~= nil then
        validate_dictionary( dictionary, 2 )
    end

    local state = createDecompressState( str, dictionary )
    local readBits = state.readBits

    local CMF = readBits( 8 )
    if state.readerBitlenLeft() < 0 then
        return nil, 2 -- available inflate data did not terminate
    end

    local CM = CMF % 16
    local CINFO = (CMF - CM) * 0.0625

    if CM ~= 8 then
        return nil, -12 -- invalid compression method
    end

    if CINFO > 7 then
        return nil, -13 -- invalid window size
    end

    local FLG = readBits( 8 )
    if state.readerBitlenLeft() < 0 then
        return nil, 2 -- available inflate data did not terminate
    end

    if (CMF * 256 + FLG) % 31 ~= 0 then
        return nil, -14 -- invalid header checksum
    end

    local FDIST = ((FLG - FLG % 32) / 32 % 2)
    -- luacheck: ignore FLEVEL
    -- local FLEVEL = ( ( FLG - FLG % 64 ) / 64 % 4 )

    if FDIST == 1 then
        if not dictionary then
            return nil, -16 -- need dictonary, but dictionary is not provided.
        end

        local actual_adler32 = readBits( 8 ) * 0x1000000 + readBits( 8 ) * 0x10000 + readBits( 8 ) * 0x100 + readBits( 8 )

        if state.readerBitlenLeft() < 0 then
            return nil, 2 -- available inflate data did not terminate
        end

        if not isEqualAdler32( actual_adler32, dictionary.adler32 ) then
            return nil, -17 -- dictionary adler32 does not match
        end
    end

    local result, status = inflate( state )
    if not result then
        return nil, status
    end

    state.skipToByteBoundary()

    local adler_byte0 = readBits( 8 )
    local adler_byte1 = readBits( 8 )
    local adler_byte2 = readBits( 8 )
    local adler_byte3 = readBits( 8 )

    if state.readerBitlenLeft() < 0 then
        return nil, 2 -- available inflate data did not terminate
    end

    local adler32_expected = adler_byte0 * 0x1000000 + adler_byte1 * 0x10000 + adler_byte2 * 0x100 + adler_byte3

    local adler32_actual = Adler32_digest( result )
    if not isEqualAdler32( adler32_expected, adler32_actual ) then
        return nil, -15 -- adler32 checksum does not match
    end

    local bitlen_left = state.readerBitlenLeft()
    return result, (bitlen_left - bitlen_left % 8) * 0.125
end

-- Calculate the huffman code of fixed block
do

    _fix_block_literal_huffman_bitlen = {}
    for sym = 0, 143 do _fix_block_literal_huffman_bitlen[ sym ] = 8 end

    for sym = 144, 255 do _fix_block_literal_huffman_bitlen[ sym ] = 9 end

    for sym = 256, 279 do _fix_block_literal_huffman_bitlen[ sym ] = 7 end

    for sym = 280, 287 do _fix_block_literal_huffman_bitlen[ sym ] = 8 end

    _fix_block_dist_huffman_bitlen = {}
    for dist = 0, 31 do
        _fix_block_dist_huffman_bitlen[ dist ] = 5
    end

    local status

    status, _fix_block_literal_huffman_bitlen_count, _fix_block_literal_huffman_to_deflate_code = getHuffmanForDecode( _fix_block_literal_huffman_bitlen, 287, 9 )
    assert( status == 0 )

    status, _fix_block_dist_huffman_bitlen_count, _fix_block_dist_huffman_to_deflate_code = getHuffmanForDecode( _fix_block_dist_huffman_bitlen, 31, 5 )
    assert( status == 0 )

    _fix_block_literal_huffman_code = getHuffmanCodeFromBitlen( _fix_block_literal_huffman_bitlen_count, _fix_block_literal_huffman_bitlen, 287, 9 )
    _fix_block_dist_huffman_code = getHuffmanCodeFromBitlen( _fix_block_dist_huffman_bitlen_count, _fix_block_dist_huffman_bitlen, 31, 5 )

end

-- Prefix encoding algorithm
-- Credits to LibCompress.
-- The code has been rewritten by the author of deflate.
------------------------------------------------------------------------------

-- to be able to match any requested byte value, the search
-- string must be preprocessed characters to escape with %:
-- ( ) . % + - * ? [ ] ^ $
-- "illegal" byte values:
-- 0 is replaces %z
local escape_for_gsub
do

    local escape_table = {
        [ "\000" ] = "%z",
        [ "(" ] = "%(",
        [ ")" ] = "%)",
        [ "." ] = "%.",
        [ "%" ] = "%%",
        [ "+" ] = "%+",
        [ "-" ] = "%-",
        [ "*" ] = "%*",
        [ "?" ] = "%?",
        [ "[" ] = "%[",
        [ "]" ] = "%]",
        [ "^" ] = "%^",
        [ "$" ] = "%$"
    }

    function escape_for_gsub( str )
        return string_gsub( str, "([%z%(%)%.%%%+%-%*%?%[%]%^%$])", escape_table )
    end

end

--- Create a custom codec with encoder and decoder.
---
--- This codec is used to convert an input string to make it not contain some specific bytes.
---
--- This created codec and the parameters of this function do NOT take
--- localization into account. One byte (0-255) in the string is exactly one character (0-255).
---
--- Credits to LibCompress.
--- The code has been rewritten by the author of deflate.
---
---@param reserved_chars string The created encoder will ensure encoded
--- data does not contain any single character in reserved_chars. This parameter should be non-empty.
---
---@param escape_chars string The escape character(s) used in the created codec.
--- The codec converts any character included in reserved\_chars /
--- escape\_chars / map\_chars to (one escape char + one character not in
--- reserved\_chars / escape\_chars / map\_chars).
--- You usually only need to provide a length-1 string for this parameter.
--- Length-2 string is only needed when
--- reserved\_chars + escape\_chars + map\_chars is longer than 127.
--- This parameter should be non-empty.
---@param map_chars string The created encoder will map every
--- reserved\_chars:sub(i, i) (1 <= i <= #map\_chars) to map\_chars:sub(i, i).
--- This parameter CAN be empty string.
---@return table? codec  If the codec cannot be created, return nil.
---
--- If the codec can be created according to the given
--- parameters, return the codec, which is a encode/decode table.
--- The table contains two functions:
---
--- t:encode(str) returns the encoded string.
---
--- t:decode(str) returns the decoded string if succeeds. nil if fails.
---@return string? message  If the codec is successfully created, return nil.
--- If not, return a string that describes the reason why the codec cannot be created.
---
---@usage
--- Create an encoder/decoder that maps all "\000" to "\003",
--- and escape "\001" (and "\002" and "\003") properly
--- local codec = deflate.createCodec("\000\001", "\002", "\003")
---
--- local encoded = codec:encode(SOME_STRING)
--- "encoded" does not contain "\000" or "\001"
--- local decoded = codec:decode(encoded)
--- assert(decoded == SOME_STRING)
function deflate.createCodec( reserved_chars, escape_chars, map_chars )
    if string_byte( escape_chars, 1, 1 ) == nil then
        return nil, "No escape characters supplied."
    end

    local map_chars_length = string_len( map_chars )
    if string_len( reserved_chars ) < map_chars_length then
        return nil, "The number of reserved characters must be at least as many as the number of mapped chars."
    end

    if string_byte( reserved_chars, 1, 1 ) == nil then
        return nil, "No characters to encode."
    end

    local encode_bytes = reserved_chars .. escape_chars .. map_chars
    local encode_bytes_length = string_len( encode_bytes )

    -- build list of bytes not available as a suffix to a prefix byte
    local encode_bytes_lst = { string_byte( encode_bytes, 1, encode_bytes_length ) }
    local taken = {}

    for i = 1, encode_bytes_length, 1 do
        local byte = encode_bytes_lst[ i ]
        if taken[ byte ] then
            return nil, "There must be no duplicate characters in the concatenation of reserved_chars, escape_chars and map_chars."
        end

        taken[ byte ] = true
    end

    local decode_patterns, decode_patterns_count = {}, 0
    local decode_repls = {}

    -- the encoding can be a single gsub, but the decoding can require multiple gsubs
    local encode_search, encode_search_size = {}, 0
    local encode_translate = {}

    -- map single byte to single byte
    if map_chars_length > 0 then
        local decode_search = {}
        local decode_translate = {}

        for i = 1, map_chars_length, 1 do
            local from = string_sub( reserved_chars, i, i )
            local to = string_sub( map_chars, i, i )

            encode_translate[ from ] = to
            encode_search_size = encode_search_size + 1
            encode_search[ encode_search_size ] = from

            decode_translate[ to ] = from
            table_insert( decode_search, to )
        end

        decode_patterns_count = decode_patterns_count + 1
        decode_patterns[ decode_patterns_count ] = "([" .. escape_for_gsub( table_concat( decode_search ) ) .. "])"

        table_insert( decode_repls, decode_translate )
    end

    local escape_char_index = 1
    local escape_char = string_sub( escape_chars, escape_char_index, escape_char_index )

    -- map single byte to double-byte
    local r = 0 -- suffix char value to the escapeChar

    local decode_search = {}
    local decode_translate = {}

    for i = 1, encode_bytes_length, 1 do
        local char = string_sub( encode_bytes, i, i )
        if encode_translate[ char ] == nil then
            while r >= 256 or taken[ r ] do
                r = r + 1

                if r > 255 then -- switch to next escapeChar
                    decode_patterns_count = decode_patterns_count + 1
                    decode_patterns[ decode_patterns_count ] = escape_for_gsub( escape_char ) .. "([" .. escape_for_gsub( table_concat( decode_search ) ) .. "])"

                    table_insert( decode_repls, decode_translate )

                    escape_char_index = escape_char_index + 1
                    escape_char = string_sub( escape_chars, escape_char_index, escape_char_index )

                    r = 0
                    decode_search = {}
                    decode_translate = {}

                    if escape_char == nil or string_byte( escape_char, 1, 1 ) == nil then
                        -- actually I don't need to check
                        -- "not ecape_char", but what if Lua changes
                        -- the behavior of string.sub() in the future?
                        -- we are out of escape chars and we need more!
                        return nil, "Out of escape characters."
                    end
                end
            end

            local char_r = string_char( r )

            encode_translate[ char ] = escape_char .. char_r

            encode_search_size = encode_search_size + 1
            encode_search[ encode_search_size ] = char

            decode_translate[ char_r ] = char
            table_insert( decode_search, char_r )

            r = r + 1
        end

        if i == encode_bytes_length then
            decode_patterns_count = decode_patterns_count + 1
            decode_patterns[ decode_patterns_count ] = escape_for_gsub( escape_char ) .. "([" .. escape_for_gsub( table_concat( decode_search ) ) .. "])"

            table_insert( decode_repls, decode_translate )
        end
    end

    local codec = {}

    local encode_pattern = "([" .. escape_for_gsub( table_concat( encode_search, "", 1, encode_search_size ) ) .. "])"

    function codec:encode( str )
        return string_gsub( str, encode_pattern, encode_translate )
    end

    local decode_fail_pattern = "([" .. escape_for_gsub( reserved_chars ) .. "])"

    function codec:decode( str )
        if string_find( str, decode_fail_pattern ) then return nil end

        for i = 1, decode_patterns_count, 1 do
            str = string_gsub( str, decode_patterns[ i ], decode_repls[ i ] )
        end

        return str
    end

    return codec
end

do

    local _addon_channel_codec

    ---@return table? codec
    ---@return string? err_msg
    local function generateWoWAddonChannelCodec()
        return deflate.createCodec( "\000", "\001", "" )
    end

    --- encode the string to make it ready to be transmitted in World of Warcraft addon channel.
    ---
    ---
    --- The encoded string is guaranteed to contain no NULL ("\000") character.
    ---@param str string The string to be encoded.
    ---@return string result The encoded string.
    ---@see deflate.decodeForWoWAddonChannel
    function deflate.encodeForWoWAddonChannel( str )
        if _addon_channel_codec == nil then
            _addon_channel_codec = generateWoWAddonChannelCodec()
        end

        ---@cast _addon_channel_codec table

        return _addon_channel_codec:encode( str )
    end

    --- Decode the string produced by deflate.encodeForWoWAddonChannel
    ---@param str string The string to be decoded.
    ---@return string | nil result The decoded string if succeeds. nil if fails.
    ---@see deflate.encodeForWoWAddonChannel
    function deflate.decodeForWoWAddonChannel( str )
        if _addon_channel_codec == nil then
            _addon_channel_codec = generateWoWAddonChannelCodec()
        end

        ---@cast _addon_channel_codec table

        return _addon_channel_codec:decode( str )
    end

    --- For World of Warcraft Chat Channel Encoding
    --- Credits to LibCompress.
    --- The code has been rewritten by the author of deflate.
    ---
    --- Following byte values are not allowed:
    --- \000, s, S, \010, \013, \124, %
    --- Because SendChatMessage will error
    --- if an UTF8 multibyte character is incomplete,
    --- all character values above 127 have to be encoded to avoid this.
    --- This costs quite a bit of bandwidth (about 13-14%)
    --- Also, because drunken status is unknown for the received,
    --- strings used with SendChatMessage should be terminated with
    --- an identifying byte value, after which the server MAY add "...hic!"
    --- or as much as it can fit(!).
    --- Pass the identifying byte as a reserved character to this function
    --- to ensure the encoding doesn't contain that value.
    --- or use this: local message, match = arg1:gsub("^(.*)\029.-$", "%1")
    --- arg1 is message from channel, \029 is the string terminator,
    --- but may be used in the encoded datastream as well. :-)
    --- This encoding will expand data anywhere from:
    --- 0% (average with pure ascii text)
    --- 53.5% (average with random data valued zero to 255)
    --- 100% (only encoding data that encodes to two bytes)
    ---@return table? codec
    ---@return string? err_msg
    local function generateWoWChatChannelCodec()
        local r = {}
        for i = 128, 255 do
            r[ i - 127 ] = string_char( i )
        end

        return deflate.createCodec( "sS\000\010\013\124%" .. table_concat( r ), "\029\031", "\015\020" )
    end

    local _chat_channel_codec

    --- encode the string to make it ready to be transmitted in World of Warcraft chat channel.
    ---
    --- See also https://wow.gamepedia.com/ValidChatMessageCharacters
    ---@param str string The string to be encoded.
    ---@return string The encoded string.
    ---@see deflate.decodeForWoWChatChannel
    function deflate.encodeForWoWChatChannel( str )
        if _chat_channel_codec == nil then
            _chat_channel_codec = generateWoWChatChannelCodec()
        end

        ---@cast _chat_channel_codec table

        return _chat_channel_codec:encode( str )
    end

    --- Decode the string produced by deflate.encodeForWoWChatChannel.
    ---@param str string The string to be decoded.
    ---@return string | nil result The decoded string if succeeds. nil if fails.
    ---@see deflate.encodeForWoWChatChannel
    function deflate.decodeForWoWChatChannel( str )
        if _chat_channel_codec == nil then
            _chat_channel_codec = generateWoWChatChannelCodec()
        end

        ---@cast _chat_channel_codec table

        return _chat_channel_codec:decode( str )
    end

    --- Clear the cache of the World of Warcraft addon channel codec.
    function deflate.clearWoWCache()
        _addon_channel_codec = nil
        _chat_channel_codec = nil
    end

end

-- Credits to WeakAuras2 and Galmok for the 6 bit encoding algorithm.
-- The code has been rewritten by the author of deflate.
-- The result of encoding will be 25% larger than the
-- origin string, but every single byte of the encoding result will be
-- printable characters as the following.
local _byte_to_6bit_char = {
    [ 0 ] = "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "(",
    ")"
}

local _6bit_to_byte = {
    [ 97 ] = 0,
    [ 98 ] = 1,
    [ 99 ] = 2,
    [ 100 ] = 3,
    [ 101 ] = 4,
    [ 102 ] = 5,
    [ 103 ] = 6,
    [ 104 ] = 7,
    [ 105 ] = 8,
    [ 106 ] = 9,
    [ 107 ] = 10,
    [ 108 ] = 11,
    [ 109 ] = 12,
    [ 110 ] = 13,
    [ 111 ] = 14,
    [ 112 ] = 15,
    [ 113 ] = 16,
    [ 114 ] = 17,
    [ 115 ] = 18,
    [ 116 ] = 19,
    [ 117 ] = 20,
    [ 118 ] = 21,
    [ 119 ] = 22,
    [ 120 ] = 23,
    [ 121 ] = 24,
    [ 122 ] = 25,
    [ 65 ] = 26,
    [ 66 ] = 27,
    [ 67 ] = 28,
    [ 68 ] = 29,
    [ 69 ] = 30,
    [ 70 ] = 31,
    [ 71 ] = 32,
    [ 72 ] = 33,
    [ 73 ] = 34,
    [ 74 ] = 35,
    [ 75 ] = 36,
    [ 76 ] = 37,
    [ 77 ] = 38,
    [ 78 ] = 39,
    [ 79 ] = 40,
    [ 80 ] = 41,
    [ 81 ] = 42,
    [ 82 ] = 43,
    [ 83 ] = 44,
    [ 84 ] = 45,
    [ 85 ] = 46,
    [ 86 ] = 47,
    [ 87 ] = 48,
    [ 88 ] = 49,
    [ 89 ] = 50,
    [ 90 ] = 51,
    [ 48 ] = 52,
    [ 49 ] = 53,
    [ 50 ] = 54,
    [ 51 ] = 55,
    [ 52 ] = 56,
    [ 53 ] = 57,
    [ 54 ] = 58,
    [ 55 ] = 59,
    [ 56 ] = 60,
    [ 57 ] = 61,
    [ 40 ] = 62,
    [ 41 ] = 63
}

--- encode the string to make it printable.
---
---
--- Credit to WeakAuras2, this function is equivalant to the implementation it is using right now.
---
--- The code has been rewritten by the author of deflate.
---
--- The encoded string will be 25% larger than the origin string. However, every
--- single byte of the encoded string will be one of 64 printable ASCII
--- characters, which are can be easier copied, pasted and displayed.
--- (26 lowercase letters, 26 uppercase letters, 10 numbers digits, left parenthese, or right parenthese)
---@param str string The string to be encoded.
---@return string result The encoded string.
function deflate.encodeForPrint( str )
    local strlen = string_len( str )
    local strlenMinus2 = strlen - 2
    local i = 1
    local buffer = {}
    local buffer_size = 0

    while i <= strlenMinus2 do
        local x1, x2, x3 = string_byte( str, i, i + 2 )
        i = i + 3

        local cache = x1 + x2 * 256 + x3 * 65536
        local uint8_1 = cache % 64
        cache = (cache - uint8_1) / 64

        local uint8_2 = cache % 64
        cache = (cache - uint8_2) / 64

        local uint8_3 = cache % 64
        local uint8_4 = (cache - uint8_3) / 64
        buffer_size = buffer_size + 1
        buffer[ buffer_size ] = _byte_to_6bit_char[ uint8_1 ] .. _byte_to_6bit_char[ uint8_2 ] .. _byte_to_6bit_char[ uint8_3 ] .. _byte_to_6bit_char[ uint8_4 ]
    end

    local cache = 0
    local cache_bitlen = 0

    while i <= strlen do
        local x = string_byte( str, i, i )
        cache = cache + x * _pow2[ cache_bitlen ]
        cache_bitlen = cache_bitlen + 8
        i = i + 1
    end

    while cache_bitlen > 0 do
        local bit6 = cache % 64
        buffer_size = buffer_size + 1
        buffer[ buffer_size ] = _byte_to_6bit_char[ bit6 ]
        cache = (cache - bit6) / 64
        cache_bitlen = cache_bitlen - 6
    end

    return table_concat( buffer )
end

--- Decode the printable string produced by deflate.encodeForPrint.
--- "str" will have its prefixed and trailing control characters or space
--- removed before it is decoded, so it is easier to use if "str" comes form
--- user copy and paste with some prefixed or trailing spaces.
--- Then decode fails if the string contains any characters cant be produced by deflate.encodeForPrint.
--- That means, decode fails if the string contains a
--- characters NOT one of 26 lowercase letters, 26 uppercase letters,
--- 10 numbers digits, left parenthese, or right parenthese.
---@param str string The string to be decoded
---@return string | nil result The decoded string if succeeds. nil if fails.
function deflate.decodeForPrint( str )
    str = string_gsub( str, "^[%c ]+", "" )
    str = string_gsub( str, "[%c ]+$", "" )

    local strlen = string_len( str )
    if strlen == 1 then
        return nil
    end

    local strlenMinus3 = strlen - 3
    local i = 1
    local buffer = {}
    local buffer_size = 0

    while i <= strlenMinus3 do
        local x1, x2, x3, x4 = string_byte( str, i, i + 3 )
        x1 = _6bit_to_byte[ x1 ]
        x2 = _6bit_to_byte[ x2 ]
        x3 = _6bit_to_byte[ x3 ]
        x4 = _6bit_to_byte[ x4 ]

        if not (x1 and x2 and x3 and x4) then return nil end

        i = i + 4

        local cache = x1 + x2 * 64 + x3 * 4096 + x4 * 262144
        local uint8_1 = cache % 0x100
        cache = (cache - uint8_1) / 0x100

        local uint8_2 = cache % 0x100
        local uint8_3 = (cache - uint8_2) / 0x100
        buffer_size = buffer_size + 1
        buffer[ buffer_size ] = string_char( uint8_1, uint8_2, uint8_3 )
    end

    local cache = 0
    local cache_bitlen = 0
    while i <= strlen do
        local x = string_byte( str, i, i )
        x = _6bit_to_byte[ x ]
        if not x then return nil end

        cache = cache + x * _pow2[ cache_bitlen ]
        cache_bitlen = cache_bitlen + 6
        i = i + 1
    end

    while cache_bitlen >= 8 do
        local byte = cache % 0x100

        buffer_size = buffer_size + 1
        buffer[ buffer_size ] = string_char( byte )

        cache = (cache - byte) / 0x100
        cache_bitlen = cache_bitlen - 8
    end

    return table_concat( buffer )
end

-- TODO: https://github.com/SafeteeWoW/LibDeflate/issues/9

-- TODO: make it async as chacha20

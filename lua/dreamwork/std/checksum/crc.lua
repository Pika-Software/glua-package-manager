---@class dreamwork.GModUtilLib
---@diagnostic disable-next-line: undefined-global
local glua_util = util
local util_CRC = glua_util ~= nil and glua_util.CRC

---@class dreamwork.std
local std = dreamwork.std

local raw = std.raw
local raw_tonumber = raw.tonumber

local rbit = raw.bit
local rbit_bxor = rbit.bxor
local rbit_reverse = rbit.reverse
local rbit_band, rbit_bor = rbit.band, rbit.bor
local rbit_lshift, rbit_rshift = rbit.lshift, rbit.rshift

local string = std.string
local string_len = string.len
local string_byte = string.byte

local class = std.class


--- [SHARED AND MENU]
---
--- The CRC-8 checksum calculation object.
---
---@class dreamwork.std.checksum.CRC8 : dreamwork.std.Object
---@field __class dreamwork.std.checksum.CRC8Class
---@field protected poly integer The polynomial is used to calculate checksum.
---@field protected init integer The initial value of checksum.
---@field protected ref_in boolean `true` if input checksum is reversed, otherwise `false`.
---@field protected ref_out boolean `true` if output checksum is reversed, otherwise `false`.
---@field protected xor_out integer | nil The value to be XORed with output checksum.
---@field protected value integer The current value of the checksum.
---@field DigestSize integer The size of the checksum in bytes.
local CRC8 = class.base( "CRC8", false )

CRC8.DigestSize = 1

---@param poly? integer
---@param init? integer
---@param ref_in? boolean
---@param ref_out? boolean
---@param xor_out? integer
---@protected
function CRC8:__init( poly, init, ref_in, ref_out, xor_out )
    if poly == nil then
        self.poly = 0x07
    else
        self.poly = poly % 0x100
    end

    if init == nil then
        self.init = 0x00
    else
        self.init = init % 0x100
    end

    self.ref_in = ref_in == true
    self.ref_out = ref_out == true

    if xor_out ~= nil then
        self.xor_out = xor_out % 0x100
    end

    self:reset()
end

--- [SHARED AND MENU]
---
--- Resets checksum to the initial value.
---
---@return dreamwork.std.checksum.CRC8 self
function CRC8:reset()
    self.value = self.init
    return self
end

do

    ---@type table<integer, table<integer, integer>>
    local crc8_lookup = {}

    setmetatable( crc8_lookup, {
        __index = function( self, poly )
            ---@type table<integer, integer>
            local hash_map = {}

            for i = 0, 255, 1 do
                local value = i

                for _ = 1, 8, 1 do
                    if rbit_band( value, 0x80 ) == 0x00 then
                        value = rbit_lshift( value, 0x01 )
                    else
                        value = rbit_bxor( rbit_lshift( value, 0x01 ), poly )
                    end
                end

                hash_map[ i ] = rbit_band( value, 0xFF )
            end

            self[ poly ] = hash_map
            return hash_map
        end
    } )

    --- [SHARED AND MENU]
    ---
    --- Updates checksum with the specified string.
    ---
    ---@param raw_str string The string is used to update checksum.
    ---@return dreamwork.std.checksum.CRC8 self
    function CRC8:update( raw_str )
        local hash_map = crc8_lookup[ self.poly ]
        local ref_in = self.ref_in
        local value = self.value

        for index = 1, string_len( raw_str ), 1 do
            if ref_in then
                value = hash_map[ rbit_bxor( value, rbit_reverse( string_byte( raw_str, index, index ), 0x08 ) ) ]
            else
                value = hash_map[ rbit_bxor( value, string_byte( raw_str, index, index ) ) ]
            end
        end

        self.value = value
        return self
    end

end

--- [SHARED AND MENU]
---
--- Finalizes checksum calculation and returns the resulting checksum.
---
---@return integer checksum The final checksum value, which is greater or equal to 0, and less than 2^8 (0x100).
function CRC8:digest()
    local value = self.value

    if self.ref_out then
        value = rbit_reverse( value, 0x08 )
    end

    local xor_out = self.xor_out
    if xor_out ~= nil then
        value = rbit_bxor( value, xor_out )
    end

    return rbit_band( value, 0xFF )
end

--- [SHARED AND MENU]
---
--- The class used to create new CRC-8 checksum calculation instances.
---
--- See https://en.wikipedia.org/wiki/Cyclic_redundancy_check for the definition of the CRC-8 checksum.
---
--- [CRC Online](https://www.texttool.com/crc-online)
---
---@class dreamwork.std.checksum.CRC8Class : dreamwork.std.checksum.CRC8
---@field __base dreamwork.std.checksum.CRC8
---@overload fun( poly?: integer, init?: integer, ref_in?: boolean, ref_out?: boolean, xor_out?: integer ): dreamwork.std.checksum.CRC8
local CRC8Class = class.create( CRC8 )
std.CRC8 = CRC8Class

--- [SHARED AND MENU]
---
--- Calculates the CRC-8 checksum of the specified string.
---
---@param raw_str string The string is used to calculate checksum.
---@param poly? integer The polynomial is used to calculate checksum.
---@param init? integer The initial value of checksum.
---@param ref_in? boolean `true` if input checksum is reversed, otherwise `false`.
---@param ref_out? boolean `true` if output checksum is reversed, otherwise `false`.
---@param xor_out? integer The value to be XORed with output checksum.
---@return integer checksum The CRC-8 checksum, which is greater or equal to 0, and less than 2^8 (0x100).
function CRC8Class.digest( raw_str, poly, init, ref_in, ref_out, xor_out )
    return CRC8Class( poly, init, ref_in, ref_out, xor_out ):update( raw_str ):digest()
end

--- [SHARED AND MENU]
---
--- The CRC-8 checksum class that uses MAXIM algorithm parameters.
---
---@return dreamwork.std.checksum.CRC8 object
function CRC8Class.MAXIM()
    return CRC8Class( 0x31, 0x00, true, true )
end

--- [SHARED AND MENU]
---
--- The CRC-8 checksum class that uses ROHC algorithm parameters.
---
---@return dreamwork.std.checksum.CRC8 object
function CRC8Class.ROHC()
    return CRC8Class( 0x07, 0xFF, true, true )
end

--- [SHARED AND MENU]
---
--- The CRC-8 checksum class that uses CDMA2000 algorithm parameters.
---
---@return dreamwork.std.checksum.CRC8 object
function CRC8Class.CDMA2000()
    return CRC8Class( 0x9B, 0xFF, false, false )
end

--- [SHARED AND MENU]
---
--- The class used to create new CRC-16 checksum calculation instances.
---
---@class dreamwork.std.checksum.CRC16 : dreamwork.std.checksum.CRC8
---@field __parent dreamwork.std.checksum.CRC8
---@field __class dreamwork.std.checksum.CRC16Class
---@field protected hash_key integer The hash key is used to generate the hash map.
---@field DigestSize integer The size of the checksum in bytes.
local CRC16 = class.base( "CRC16", false, CRC8Class )

CRC16.DigestSize = 2

---@param poly? integer
---@param init? integer
---@param ref_in? boolean
---@param ref_out? boolean
---@param xor_out? integer
---@protected
function CRC16:__init( poly, init, ref_in, ref_out, xor_out )
    if poly == nil then
        self.poly = 0x8005
    else
        self.poly = poly % 0x10000
    end

    if init == nil then
        self.init = 0x00
    else
        self.init = init % 0x10000
    end

    self.ref_in = ref_in == true
    self.ref_out = ref_out == true

    if xor_out ~= nil then
        self.xor_out = xor_out % 0x10000
    end

    self.hash_key = rbit_bor(
        self.poly,
        self.ref_in and 0x10000 or 0x00,
        self.ref_out and 0x20000 or 0x00
    )

    self:reset()
end

do

    ---@type table<integer, table<integer, integer>>
    local crc16_lookup = {}

    setmetatable( crc16_lookup, {
        __index = function( self, uint17 )
            local ref_out = rbit_band( uint17, 0x20000 ) ~= 0x00
            local ref_in = rbit_band( uint17, 0x10000 ) ~= 0x00
            local poly = rbit_band( uint17, 0xFFFF )

            ---@type table<integer, integer>
            local hash_map = {}

            for i = 0, 255, 1 do
                local value

                if ref_in then
                    value = rbit_reverse( i, 0x08 )
                else
                    value = i
                end

                value = rbit_lshift( value, 0x08 )

                for _ = 1, 8, 1 do
                    if rbit_band( value, 0x8000 ) == 0x00 then
                        value = rbit_lshift( value, 0x01 )
                    else
                        value = rbit_bxor( rbit_lshift( value, 0x01 ), poly )
                    end
                end

                value = rbit_band( value, 0xFFFF )

                if ref_out then
                    value = rbit_reverse( value, 0x10 )
                end

                hash_map[ i ] = value
            end

            self[ uint17 ] = hash_map
            return hash_map
        end
    } )

    --- [SHARED AND MENU]
    ---
    --- Updates checksum with the specified string.
    ---
    ---@param raw_str string The string is used to update checksum.
    ---@return dreamwork.std.checksum.CRC16 self
    function CRC16:update( raw_str )
        local hash_map = crc16_lookup[ self.hash_key ]
        local ref_in = self.ref_in
        local value = self.value

        for index = 1, string_len( raw_str ), 1 do
            if ref_in then
                value = rbit_bxor( rbit_rshift( value, 0x08 ), hash_map[ rbit_band( rbit_bxor( value, string_byte( raw_str, index, index ) ), 0xFF ) ] )
            else
                value = rbit_bxor( rbit_lshift( value, 0x08 ), hash_map[ rbit_band( rbit_bxor( rbit_rshift( value, 0x08 ), string_byte( raw_str, index, index ) ), 0xFF ) ] )
            end
        end

        self.value = value
        return self
    end

end

--- [SHARED AND MENU]
---
--- Finalizes checksum calculation and returns the resulting checksum.
---
---@return integer checksum The final checksum value, which is greater or equal to 0, and less than 2^16 (0x10000).
function CRC16:digest()
    local value = self.value

    local xor_out = self.xor_out
    if xor_out ~= nil then
        value = rbit_bxor( value, xor_out )
    end

    return rbit_band( value, 0xFFFF )
end

--- [SHARED AND MENU]
---
--- The class used to create new CRC-16 checksum calculation instances.
---
--- See https://en.wikipedia.org/wiki/Cyclic_redundancy_check for the definition of the CRC-16 checksum.
---
--- [CRC Online](https://www.texttool.com/crc-online)
---
---@class dreamwork.std.checksum.CRC16Class : dreamwork.std.checksum.CRC16
---@field __parent dreamwork.std.checksum.CRC8Class
---@field __base dreamwork.std.checksum.CRC16
---@overload fun( poly?: integer, init?: integer, ref_in?: boolean, ref_out?: boolean, xor_out?: integer ): dreamwork.std.checksum.CRC16
local CRC16Class = class.create( CRC16 )
std.CRC16 = CRC16Class

--- [SHARED AND MENU]
---
--- Calculates the CRC-16 checksum of the specified string.
---
---@param raw_str string The string is used to calculate checksum.
---@param poly? integer The polynomial is used to calculate checksum.
---@param init? integer The initial value is used to calculate checksum.
---@param ref_in? boolean Whether to reflect the input data before processing.
---@param ref_out? boolean Whether to reflect the output data after processing.
---@param xor_out? integer The XOR value is used to calculate checksum.
---@return integer checksum The CRC-16 checksum, which is greater or equal to 0, and less than 2^16 (0x10000).
function CRC16Class.digest( raw_str, poly, init, ref_in, ref_out, xor_out )
    return CRC16Class( poly, init, ref_in, ref_out, xor_out ):update( raw_str ):digest()
end

--- [SHARED AND MENU]
---
--- The CRC-16 checksum class that uses MAXIM algorithm parameters.
---
---@return dreamwork.std.checksum.CRC16 object
function CRC16Class.MAXIM()
    return CRC16Class( 0x8005, 0x0000, true, true )
end

--- [SHARED AND MENU]
---
--- The CRC-16 checksum class that uses XMODEM algorithm parameters.
---
---@return dreamwork.std.checksum.CRC16 object
function CRC16Class.XMODEM()
    return CRC16Class( 0x1021, 0x0000, false, false )
end

--- [SHARED AND MENU]
---
--- The CRC-16 checksum class that uses USB algorithm parameters.
---
---@return dreamwork.std.checksum.CRC16 object
function CRC16Class.USB()
    return CRC16Class( 0x8005, 0xFFFF, true, true, 0xFFFF )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum calculation object.
---
---@class dreamwork.std.checksum.CRC32 : dreamwork.std.checksum.CRC16
---@field __parent dreamwork.std.checksum.CRC16
---@field __class dreamwork.std.checksum.CRC32Class
---@field DigestSize integer The size of the checksum in bytes.
local CRC32 = class.base( "CRC32", false, CRC16Class )

CRC32.DigestSize = 4

---@param poly? integer
---@param init? integer
---@param ref_in? boolean
---@param ref_out? boolean
---@param xor_out? integer
---@protected
function CRC32:__init( poly, init, ref_in, ref_out, xor_out )
    if poly == nil then
        self.poly = 0x04C11DB7
    else
        self.poly = poly % 0x100000000
    end

    if init == nil then
        self.init = 0xFFFFFFFF
    else
        self.init = init % 0x100000000
    end

    self.ref_in = ref_in == true
    self.ref_out = ref_out == true

    if xor_out == nil then
        self.xor_out = 0xFFFFFFFF
    else
        self.xor_out = xor_out % 0x100000000
    end

    -- self.hash_key = rbit_bor(
    --     self.poly,
    --     self.ref_in and 0x10000 or 0x00,
    --     self.ref_out and 0x20000 or 0x00
    -- )

    self:reset()
end

do

    ---@type table<integer, table<integer, integer>>
    local crc32_lookup = {}

    setmetatable( crc32_lookup, {
        __index = function( self, poly )
            local hash_map = {}

            for i = 0, 255, 1 do
                local value = rbit_lshift( i, 0x18 )

                for _ = 1, 8, 1 do
                    if rbit_band( value, 0x80000000 ) == 0 then
                        value = rbit_lshift( value, 1 )
                    else
                        value = rbit_bxor( rbit_lshift( value, 1 ), poly )
                    end
                end

                hash_map[ i ] = value % 0x100000000
            end

            self[ poly ] = hash_map
            return hash_map
        end
    } )

    --- [SHARED AND MENU]
    ---
    --- Updates checksum with the specified string.
    ---
    ---@param raw_str string The string is used to update checksum.
    ---@return dreamwork.std.checksum.CRC32 self
    function CRC32:update( raw_str )
        local hash_map = crc32_lookup[ self.poly ]
        local ref_in = self.ref_in
        local value = self.value

        for index = 1, string_len( raw_str ), 1 do
            if ref_in then
                value = rbit_bxor( rbit_lshift( value, 8 ), hash_map[ rbit_band( rbit_bxor( rbit_band( rbit_rshift( value, 24 ), 0xFF ), rbit_reverse( string_byte( raw_str, index, index ), 8 ) ), 0xFF ) ] )
            else
                value = rbit_bxor( rbit_lshift( value, 8 ), hash_map[ rbit_band( rbit_bxor( rbit_band( rbit_rshift( value, 24 ), 0xFF ), string_byte( raw_str, index, index ) ), 0xFF ) ] )
            end
        end

        self.value = value
        return self
    end

end

--- [SHARED AND MENU]
---
--- Finalizes checksum calculation and returns the resulting checksum.
---
---@return integer checksum The final checksum value, which is greater or equal to 0, and less than 2^32 (0x100000000).
function CRC32:digest()
    local value = self.value

    local ref_out = self.ref_out
    if ref_out then
        value = rbit_reverse( value, 0x20 )
    end

    local xor_out = self.xor_out
    if xor_out ~= nil then
        value = rbit_bxor( value, xor_out )
    end

    return value % 0x100000000
end

--- [SHARED AND MENU]
---
--- The class used to create new CRC-32 checksum calculation instances.
---
--- See https://en.wikipedia.org/wiki/Cyclic_redundancy_check for the definition of the CRC-32 checksum.
---
--- [CRC Online](https://www.texttool.com/crc-online)
---
---@class dreamwork.std.checksum.CRC32Class : dreamwork.std.checksum.CRC32
---@field __parent dreamwork.std.checksum.CRC16Class
---@field __base dreamwork.std.checksum.CRC32
---@overload fun( poly?: integer, init?: integer, ref_in?: boolean, ref_out?: boolean, xor_out?: integer ): dreamwork.std.checksum.CRC32
local CRC32Class = class.create( CRC32 )
std.CRC32 = CRC32Class

--- [SHARED AND MENU]
---
--- Calculates the CRC-32 checksum of the specified string.
---
---@param raw_str string The string is used to calculate checksum.
---@param poly? integer The polynomial is used to calculate checksum.
---@param init? integer The initial value is used to calculate checksum.
---@param ref_in? boolean Whether to reflect the input data before processing.
---@param ref_out? boolean Whether to reflect the output data after processing.
---@param xor_out? integer The XOR value is used to calculate checksum.
---@return integer checksum The CRC-32 checksum, which is greater or equal to 0, and less than 2^32 (0x100000000).
function CRC32Class.digest( raw_str, poly, init, ref_in, ref_out, xor_out )
    ref_in = ref_in ~= false
    ref_out = ref_out ~= false

    if init == nil then
        init = 0xFFFFFFFF
    else
        init = init % 0x100000000
    end

    if poly == nil then
        poly = 0x04C11DB7
    else
        poly = poly % 0x100000000
    end

    if xor_out == nil then
        xor_out = 0xFFFFFFFF
    else
        xor_out = xor_out % 0x100000000
    end

    if util_CRC ~= nil and poly == 0x04C11DB7 and init == 0xFFFFFFFF and ref_in and ref_out and xor_out == 0xFFFFFFFF then
        return raw_tonumber( util_CRC( raw_str ) or 0, 10 ) or 0
    else
        return CRC32Class( poly, init, ref_in, ref_out, xor_out ):update( raw_str ):digest()
    end
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses BZIP2 algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.BZIP2()
    return CRC32Class( 0x04C11DB7, 0xFFFFFFFF, false, false, 0xFFFFFFFF )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses Castagnoli/C algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.C()
    return CRC32Class( 0x1EDC6F41, 0xFFFFFFFF, true, true, 0xFFFFFFFF )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses D algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.D()
    return CRC32Class( 0xA833982B, 0xFFFFFFFF, true, true, 0xFFFFFFFF )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses JamCRC algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.JAMCRC()
    return CRC32Class( 0x04C11DB7, 0xFFFFFFFF, true, true, 0x00000000 )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses MPEG-2 algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.MPEG2()
    return CRC32Class( 0x04C11DB7, 0xFFFFFFFF, false, false, 0x00000000 )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses POSIX algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.POSIX()
    return CRC32Class( 0x04C11DB7, 0x00000000, false, false, 0xFFFFFFFF )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses Q algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.Q()
    return CRC32Class( 0x814141AB, 0x00000000, false, false, 0x00000000 )
end

--- [SHARED AND MENU]
---
--- The CRC-32 checksum class that uses XFER algorithm parameters.
---
---@return dreamwork.std.checksum.CRC32 object
function CRC32Class.XFER()
    return CRC32Class( 0x000000AF, 0x00000000, false, false, 0x00000000 )
end

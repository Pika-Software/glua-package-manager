---@class dreamwork.std
local std                         = dreamwork.std

local math                        = std.math
local math_clamp                  = math.clamp
local math_relative               = math.relative
local math_min                    = math.min

local string                      = std.string
local string_len                  = string.len
local string_format               = string.format
local string_findByte             = string.findByte
local string_toNumber             = string.toNumber

local bit                         = std.bit
local bit_bnot                    = bit.bnot
local bit_lshift                  = bit.lshift
local bit_unsign                  = bit.unsign
local bit_bxor, bit_band, bit_bor = bit.bxor, bit.band, bit.bor

local bytepack                    = std.bytepack
local bytepack_readUInt32         = bytepack.readUInt32BE
local bytepack_writeUInt32        = bytepack.writeUInt32BE

---@alias dreamwork.std.IPv4.Class "A" | "B" | "C" | "D" | "E"
---@alias dreamwork.std.IPv4 integer

--- [SHARED AND MENU]
---
--- Provides utility functions for working with Internet Protocol v4 addresses as integers.
---
---@class dreamwork.std.ipv4
local ipv4                        = {}
std.ipv4                          = ipv4

local bin_masks                   = {}

for i = 0, 32, 1 do
    bin_masks[ i ] = bit_lshift( (2 ^ i) - 1, 32 - i )
end

local bin_inverted_masks = {}

for i = 0, 32, 1 do
    bin_inverted_masks[ i ] = bit_bxor( bin_masks[ i ], bin_masks[ 32 ] )
end

--- [SHARED AND MENU]
---
--- Returns the octets of an IPv4 address.
---
---@param ip_address dreamwork.std.IPv4 The IP address.
---@return integer a The first octet. <0-255>
---@return integer b The second octet. <0-255>
---@return integer c The third octet. <0-255>
---@return integer d The fourth octet. <0-255>
function ipv4.octets( ip_address )
    local d, c, b, a = bytepack_writeUInt32( ip_address )
    return a, b, c, d
end

--- [SHARED AND MENU]
---
--- Build IPv4 address from octets.
---
---@param a integer The first octet. <0-255>
---@param b integer The second octet. <0-255>
---@param c integer The third octet. <0-255>
---@param d integer The fourth octet. <0-255>
---@return dreamwork.std.IPv4
local function fromOctets( a, b, c, d )
    return bytepack_readUInt32(
        math_clamp( d, 0, 255 ),
        math_clamp( c, 0, 255 ),
        math_clamp( b, 0, 255 ),
        math_clamp( a, 0, 255 )
    )
end

ipv4.fromOctets = fromOctets

--- [SHARED AND MENU]
---
--- Parses an IPv4 address octets string into an IP address and subnet mask.
---
---  Supports:
--- - **Hexadecimal**: prefixed with `0x` or `0X` (e.g., `0x7F`). Returns `0` if empty after prefix.
--- - **Octal**: prefixed with `0` followed by numbers (e.g., `0177`).
--- - **Decimal**: standard base-10 digits (e.g., `127`).
--- - **Empty/Missing**: returns `0` if the position is empty or invalid.
---
---@param ipv4_str string The full IPv4 address string to parse.
---@param start_position? integer The start position in the ipv4 string.
---@param end_position? integer The end position in the ipv4 string.
---@param str_length? integer The length of the ipv4 string. Optionally, it should be used to speed up calculations.
---@return dreamwork.std.IPv4 ip_address The parsed IP address.
---@return integer mask The subnet mask.
function ipv4.parse( ipv4_str, start_position, end_position, str_length )
    if str_length == nil then
        str_length = string_len( ipv4_str )
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

    ---@type { [ 1 ]: integer, [ 2 ]: integer, [ 3 ]: integer, [ 4 ]: integer }
    local octets = { 0, 0, 0, 0 }

    ---@type integer
    local octet_index = 1

    local cdir_position = string_findByte( ipv4_str, 0x2F --[[ / ]], start_position, end_position )

    ::parse_octet::

    local octet_position = string_findByte( ipv4_str, 0x2E --[[ . ]], start_position, end_position )

    local octet_length
    if octet_position == nil then
        if cdir_position == nil then
            octet_length = (end_position - start_position) + 1
        else
            octet_length = cdir_position - start_position
        end
    else
        octet_length = octet_position - start_position
    end

    if octet_length > 0 then
        local octet = string_toNumber( ipv4_str, nil, start_position, start_position + (octet_length - 1) )
        if octet == nil then
            std.errorf( 2, false, "invalid characters in ipv4 octet %d", octet_index )
        elseif octet > 255 then
            std.errorf( 2, false, "ipv4 octet %d out of range %d > 255", octet_index, octet )
        elseif octet < 0 then
            std.errorf( 2, false, "ipv4 octet %d cannot be negative", octet_index )
        else
            octets[ octet_index ] = math_clamp( octet, 0, 255 )
        end

        if octet_position ~= nil then
            if octet_index == 4 then
                std.errorf( 2, false, "too many ipv4 octets, max 4" )
            end

            start_position = octet_position + 1
            octet_index = octet_index + 1
            goto parse_octet
        end
    else
        octet_index = octet_index - 1
    end

    if octet_index ~= 4 then
        octets[ 4 ], octets[ octet_index ] = octets[ octet_index ], 0
    end

    local mask = 32

    if cdir_position ~= nil then
        mask = math_clamp( string_toNumber( ipv4_str, 10, cdir_position + 1, end_position ) or 32, 0, 32 )
    end

    return fromOctets( octets[ 1 ], octets[ 2 ], octets[ 3 ], octets[ 4 ] ), mask
end

--- [SHARED AND MENU]
---
--- Returns the network address and boardcast address for a given IPv4 address and subnet mask.
---
---@param ip_address dreamwork.std.IPv4 The IP address.
---@param mask integer The subnet mask.
---@return dreamwork.std.IPv4 network_address The parsed network address.
---@return dreamwork.std.IPv4 boardcast_address The parsed boardcast address.
function ipv4.cdir( ip_address, mask )
    local network_address   = bit_band( ip_address, bin_masks[ mask ] )
    local boardcast_address = bit_bor( network_address, bin_inverted_masks[ mask ] )

    return bit_unsign( network_address ), bit_unsign( boardcast_address )
end

--- [SHARED AND MENU]
---
--- Returns the wildcard address of a network address and boardcast address.
---
---@param network_address dreamwork.std.IPv4 The network address.
---@param boardcast_address dreamwork.std.IPv4 The boardcast address.
---@return dreamwork.std.IPv4 wildcard_address The wildcard address.
function ipv4.wildcard( network_address, boardcast_address )
    return bit_bxor( network_address, boardcast_address )
end

--- [SHARED AND MENU]
---
--- Returns the mask of a network address and boardcast address.
---
---@param network_address dreamwork.std.IPv4 The network address.
---@param boardcast_address dreamwork.std.IPv4 The boardcast address.
---@return dreamwork.std.IPv4 mask_address The mask of the network address and boardcast address.
function ipv4.mask( network_address, boardcast_address )
    return bit_bnot( bit_bxor( network_address, boardcast_address ) )
end

--- [SHARED AND MENU]
---
--- Returns the range of an IPv4 address range.
---
---@param network_address dreamwork.std.IPv4 The network address.
---@param boardcast_address dreamwork.std.IPv4 The boardcast address.
---@return dreamwork.std.IPv4 first The first address in the range.
---@return dreamwork.std.IPv4 last The last address in the range.
function ipv4.range( network_address, boardcast_address )
    return network_address + 1, boardcast_address - 1
end

--- [SHARED AND MENU]
---
--- Returns the number of addresses in an IPv4 address range.
---
---@param network_address dreamwork.std.IPv4 The network address.
---@param boardcast_address dreamwork.std.IPv4 The boardcast address.
---@return dreamwork.std.IPv4 total_count The total number of addresses in the range.
---@return dreamwork.std.IPv4 usable_count The number of usable addresses in the range.
function ipv4.count( network_address, boardcast_address )
    local diff = boardcast_address - network_address
    return diff + 1, diff - 1
end

--- [SHARED AND MENU]
---
--- Returns the string representation of an IPv4 address.
---
---@param ip_address dreamwork.std.IPv4 The IP address.
---@return string str The string representation of the IP address.
function ipv4.toString( ip_address )
    local d, c, b, a = bytepack_writeUInt32( ip_address )
    return string_format( "%d.%d.%d.%d", a, b, c, d )
end

--- [SHARED AND MENU]
---
--- Returns the reverse pointer of an IPv4 address.
---
---@param ip_address dreamwork.std.IPv4 The IP address.
---@return string str The reverse pointer of the IP address.
function ipv4.reversePointer( ip_address )
    local d, c, b, a = bytepack_writeUInt32( ip_address )
    return string_format( "%d.%d.%d.%d.in-addr.arpa", a, b, c, d )
end

do

    --- [SHARED AND MENU]
    ---
    --- Returns whether an IP address is within a given range.
    ---
    ---@param ip_address dreamwork.std.IPv4 The IP address.
    ---@param network_address dreamwork.std.IPv4 The network address.
    ---@param boardcast_address dreamwork.std.IPv4 The boardcast address.
    ---@return boolean in_range Whether the IP address is within the range.
    local function inRange( ip_address, network_address, boardcast_address )
        return ip_address >= network_address and ip_address <= boardcast_address
    end

    ipv4.inRange = inRange

    ---@param str string The network address in CIDR notation.
    ---@return fun( ip_address: dreamwork.std.IPv4 ): boolean
    local function gen_in_range( str )
        local network_address, boardcast_address = ipv4.cdir( ipv4.parse( str ) )
        return function( ip_address )
            return inRange( ip_address, network_address, boardcast_address )
        end
    end

    --- [SHARED AND MENU]
    ---
    --- Returns whether an IP address is a link-local address.
    ---
    ipv4.isLinkLocal = gen_in_range( "169.254.0.0/16" )

    --- [SHARED AND MENU]
    ---
    --- Returns whether an IP address is a loopback address.
    ---
    ipv4.isLoopback = gen_in_range( "127.0.0.0/8" )

    --- [SHARED AND MENU]
    ---
    --- Returns whether an IP address is a multicast address.
    ---
    ipv4.isMulticast = gen_in_range( "224.0.0.0/4" )

    --- [SHARED AND MENU]
    ---
    --- Returns whether an IP address is reserved.
    ---
    ipv4.isReserved = gen_in_range( "240.0.0.0/4" )

    --- [SHARED AND MENU]
    ---
    --- Returns whether an IP address is the unspecified address.
    ---
    ---@param ip_address dreamwork.std.IPv4 The IP address to check.
    ---@return boolean Whether the IP address is the unspecified address.
    function ipv4.isUnspecified( ip_address )
        return ip_address == 0
    end

    ---@class dreamwork.std.ip.ipv4.NetworkVar
    ---@field [1] dreamwork.std.IPv4 The network address.
    ---@field [2] dreamwork.std.IPv4 The broadcast address.

    ---@param ranges string[]
    ---@return dreamwork.std.ip.ipv4.NetworkVar[], integer
    local function network_ranges( ranges )
        local range_count = #ranges
        local result = {}

        for i = 1, range_count, 1 do
            result[ i ] = { ipv4.cdir( ipv4.parse( ranges[ i ] ) ) }
        end

        return result, range_count
    end

    local private_ranges, private_count = network_ranges( {
        "0.0.0.0/8",
        "10.0.0.0/8",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "172.16.0.0/12",
        "192.0.0.0/24",
        "192.0.0.170/31",
        "192.0.2.0/24",
        "192.168.0.0/16",
        "198.18.0.0/15",
        "198.51.100.0/24",
        "203.0.113.0/24",
        "240.0.0.0/4",
        "255.255.255.255/32",
    } )

    local private_range_exceptions, exception_count = network_ranges( {
        "192.0.0.9/32",
        "192.0.0.10/32",
        "100.64.0.0/10",
    } )

    --- [SHARED AND MENU]
    ---
    --- Returns whether the given IP address is private.
    ---
    ---@param ip_address dreamwork.std.IPv4 The IP address.
    ---@return boolean is_private Whether the IP address is private.
    local function isPrivate( ip_address )
        for i = 1, exception_count, 1 do
            local data = private_range_exceptions[ i ]
            if inRange( ip_address, data[ 1 ], data[ 2 ] ) then
                return false
            end
        end

        for i = 1, private_count, 1 do
            local data = private_ranges[ i ]
            if inRange( ip_address, data[ 1 ], data[ 2 ] ) then
                return true
            end
        end

        return false
    end

    ipv4.isPrivate = isPrivate

    --- [SHARED AND MENU]
    ---
    --- Returns whether the given IP address is public.
    ---
    ---@param ip_address dreamwork.std.IPv4 The IP address.
    ---@return boolean is_public Whether the IP address is public.
    function ipv4.isPublic( ip_address )
        return not isPrivate( ip_address )
    end

    local classes = {
        { "A", ipv4.parse( "0.0.0.0" ),   ipv4.parse( "127.255.255.255" ) },
        { "B", ipv4.parse( "128.0.0.0" ), ipv4.parse( "191.255.255.255" ) },
        { "C", ipv4.parse( "192.0.0.0" ), ipv4.parse( "223.255.255.255" ) },
        { "D", ipv4.parse( "224.0.0.0" ), ipv4.parse( "239.255.255.255" ) },
        -- { "E", ipv4.parse( "240.0.0.0" ), ipv4.parse( "255.255.255.255" ) },
    }

    --- [SHARED AND MENU]
    ---
    --- Returns the class of the given IP address.
    ---
    ---@param ip_address dreamwork.std.IPv4
    ---@return dreamwork.std.IPv4.Class
    function ipv4.class( ip_address )
        for i = 1, 4, 1 do
            local data = classes[ i ]
            if inRange( ip_address, data[ 2 ], data[ 3 ] ) then
                return data[ 1 ]
            end
        end

        return "E"
    end

end

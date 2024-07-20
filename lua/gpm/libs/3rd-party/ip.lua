--
-- IP address manipulation library in Lua (IPAML)
--
-- @author    leite (xico@simbio.se)
-- @license   MIT
-- @copyright Simbiose 2015, Mashape, Inc. 2017
-- https://github.com/Kong/lua-resty-mediador
-- edited by Unknown Developer for gmod in 2024

local ip = {}

local concat = table.concat
local insert = table.insert

local bit = bit
local rshift = bit.rshift
local lshift = bit.lshift
local band = bit.band
local bor = bit.bor

local format = string.format
local match = string.match
local find = string.find

local setmetatable = setmetatable
local tonumber = tonumber
local assert = assert
local error = error
local pcall = pcall
local type = type

local OCTETS = "^((0?[xX]?)[%da-fA-F]+)%.((0?[xX]?)[%da-fA-F]+)%.((0?[xX]?)[%da-fA-F]+)%.((0?[xX]?)[%da-fA-F]+)/?(%d*)$"
local OCTET = "^((0?[xX]?)[%da-fA-F]+)((/?)(%d*))$"
local PARTS = "^([:%dxXa-fA-F]-::?)(([%dxXa-fA-F]*)[%.%dxXa-fA-F]*)/?(%d*)$"
local PART = "(:?)([^:/$]*)(:?)"

local function match_octets(address)
    return match(address, OCTETS)
end

local function match_octet(address)
    return match(address, OCTET)
end

local function match_parts(address)
    return match(address, PARTS)
end

local function find_octets(address)
    return find(address, OCTETS)
end

local function find_octet(address)
    return find(address, OCTET)
end

local function find_parts(address)
    return find(address, PARTS)
end

local function find_part(address, init)
    return find(address, PART, init)
end

local EMPTY = ""
local COLON = ":"
local ZERO = "0"
local RANGES = {
    ipv4 = {
        {
            "unspecified",
            octets = {0, 0, 0, 0},
            _cidr = 8
        },
        {
            "broadcast",
            octets = {255, 255, 255, 255},
            _cidr = 32
        },
        {
            "multicast",
            octets = {224, 0, 0, 0},
            _cidr = 4
        },
        {
            "linkLocal",
            octets = {169, 254, 0, 0},
            _cidr = 16
        },
        {
            "loopback",
            octets = {127, 0, 0, 0},
            _cidr = 8
        },
        {
            "private",
            {
                octets = {10, 0, 0, 0},
                _cidr = 8
            },
            {
                octets = {172, 16, 0, 0},
                _cidr = 12
            },
            {
                octets = {192, 168, 0, 0},
                _cidr = 16
            }
        },
        {
            "reserved",
            {
                octets = {192, 0, 0, 0},
                _cidr = 24
            },
            {
                octets = {192, 0, 2, 0},
                _cidr = 24
            },
            {
                octets = {192, 88, 99, 0},
                _cidr = 24
            },
            {
                octets = {198, 51, 100, 0},
                _cidr = 24
            },
            {
                octets = {203, 0, 113, 0},
                _cidr = 24
            },
            {
                octets = {240, 0, 0, 0},
                _cidr = 4
            }
        }
    },
    ipv6 = {
        {
            "unspecified",
            parts = {0, 0, 0, 0, 0, 0, 0, 0},
            _cidr = 128
        },
        {
            "linkLocal",
            parts = {0xfe80, 0, 0, 0, 0, 0, 0, 0},
            _cidr = 10
        },
        {
            "multicast",
            parts = {0xff00, 0, 0, 0, 0, 0, 0, 0},
            _cidr = 8
        },
        {
            "loopback",
            parts = {0, 0, 0, 0, 0, 0, 0, 1},
            _cidr = 128
        },
        {
            "uniqueLocal",
            parts = {0xfc00, 0, 0, 0, 0, 0, 0, 0},
            _cidr = 7
        },
        {
            "ipv4Mapped",
            parts = {0, 0, 0, 0, 0, 0xffff, 0, 0},
            _cidr = 96
        },
        {
            "rfc6145",
            parts = {0, 0, 0, 0, 0xffff, 0, 0, 0},
            _cidr = 96
        },
        {
            "rfc6052",
            parts = {0x64, 0xff9b, 0, 0, 0, 0, 0, 0},
            _cidr = 96
        },
        {
            "6to4",
            parts = {0x2002, 0, 0, 0, 0, 0, 0, 0},
            _cidr = 16
        },
        {
            "teredo",
            parts = {0x2001, 0, 0, 0, 0, 0, 0, 0},
            _cidr = 32
        },
        {
            "reserved",
            parts = {0x2001, 0xdb8, 0, 0, 0, 0, 0, 0},
            _cidr = 32
        }
    }
}

-- assert ipv4 octets
--
-- @table  octets
-- @return boolean, [string]
local function assert_ipv4(octets)
    if not (octets and type(octets) == "table") then return false, "octets should be a table" end
    if not (#octets == 4) then return false, "ipv4 octet count should be 4" end
    if not ((-1 < octets[1] and 256 > octets[1]) and (-1 < octets[2] and 256 > octets[2]) and (-1 < octets[3] and 256 > octets[3]) and (-1 < octets[4] and 256 > octets[4])) then return false, "ipv4 octet is a byte" end

    return true
end

-- assert ipv6 parts
--
-- @table  parts
-- @return boolean, [string]
local function assert_ipv6(parts)
    if not (parts and type(parts) == "table") then return false, "parts should be a table" end
    if not (#parts == 8) then return false, "ipv6 part count should be 8" end
    if not ((-1 < parts[1] and 0x10000 > parts[1]) and (-1 < parts[2] and 0x10000 > parts[2]) and (-1 < parts[3] and 0x10000 > parts[3]) and (-1 < parts[4] and 0x10000 > parts[4]) and (-1 < parts[5] and 0x10000 > parts[5]) and (-1 < parts[6] and 0x10000 > parts[6]) and (-1 < parts[7] and 0x10000 > parts[7]) and (-1 < parts[8] and 0x10000 > parts[8])) then return false, "ipv6 part should fit to two octets" end

    return true
end

-- generic CIDR matcher
--
-- @table  first
-- @table  second
-- @number part_size
-- @number cidr_bits
-- @return boolean
local function match_cidr(first, second, part_size, cidr_bits)
    assert(#first == #second, "cannot match CIDR for objects with different lengths")
    local part = 0
    while cidr_bits > 0 do
        part = part + 1
        local shift = part_size - cidr_bits
        shift = shift < 0 and 0 or shift
        if rshift(first[part], shift) ~= rshift(second[part], shift) then return false end
        cidr_bits = cidr_bits - part_size
    end

    return true
end

-- funct address named range matching
--
-- @table  address
-- @table  range_list
-- @string default_name
-- @return string
local function subnet_match(address, range_list, default_name)
    for i = 1, #range_list do
        local subnet = range_list[i]
        if #subnet == 1 then
            if address:match(subnet) then return subnet[1] end
        else
            for j = 2, #subnet do
                if address:match(subnet[j]) then return subnet[1] end
            end
        end
    end

    return default_name or "unicast"
end

-- parse IP version 4
--
-- @string address
-- @table  octets
-- @number cidr
-- @return boolean, [string]
local function parse_v4(address, octets, cidr)
    local value, hex, _, _, _cidr = match_octet(address)
    if value then
        value = tonumber(value, hex == ZERO and 8 or nil)
        if value > 0xffffffff or value < 0 then return false, "address outside defined range" end
        octets[1], octets[2], octets[3], octets[4] = band(rshift(value, 24), 0xff), band(rshift(value, 16), 0xff), band(rshift(value, 8), 0xff), band(value, 0xff)

        return tonumber(_cidr == EMPTY and 32 or _cidr)
    end

    local st, _st, nd, _nd, rd, _rd, th, _th, _cr = match_octets(address)
    if not st then return false, "invalid ip address" end
    octets[1], octets[2], octets[3], octets[4] = tonumber(st, _st == ZERO and 8 or nil), tonumber(nd, _nd == ZERO and 8 or nil), tonumber(rd, _rd == ZERO and 8 or nil), tonumber(th, _th == ZERO and 8 or nil)

    return tonumber(_cr == EMPTY and (cidr and cidr or 32) or _cr)
end

-- parse IP version 6
--
-- @string address
-- @table  parts
-- @table  octets
-- @number cidr
-- @return boolean, [string]
local function parse_v6(address, parts, octets, cidr)
    local l_sep, count, double, addr, octets_st, sep, _cidr = false, 1, 0, match_parts(address)
    if not addr or EMPTY == addr then return false, "invalid ipv6 format" end
    if #octets_st == #sep then
        addr = addr .. sep
    else
        local err, message = parse_v4(octets_st, octets)
        if not err then return err, message end
    end

    local _cr, length, index, last, separator, part, nd_sep = tonumber(_cidr == EMPTY and (cidr and cidr or 128) or _cidr), #addr, find_part(addr)
    while index and index <= length do
        if separator == COLON and nd_sep == COLON then
            if part == EMPTY or l_sep then
                if double > 0 then return false, "string is not formatted like ip address" end
                double = count
            end
        elseif separator == COLON or nd_sep == COLON then
            if l_sep and separator == COLON then
                if double > 0 then return false, "string is not formatted like ip address" end
                double = count
            end
        end

        insert(parts, tonumber(part == EMPTY and "0" or part, 16))
        l_sep, count, index, last, separator, part, nd_sep = nd_sep == COLON, count + 1, find_part(addr, last + 1)
    end

    if #octets > 0 then
        insert(parts, bor(lshift(octets[1], 8), octets[2]))
        insert(parts, bor(lshift(octets[3], 8), octets[4]))
        length = 7
    else
        length = 9
    end

    for _ = 1, length - count do
        insert(parts, double, 0)
    end

    return _cr
end

-- ip metatable
local ip_metatable = {
    -- set CIDR -- -- @number cidr -- @return metatable
    cidr = function(self, cidr)
        self._cidr = cidr

        return self
    end,
    -- get address named range -- -- @return string
    range = function(self) return subnet_match(self, RANGES[self:kind()]) end,
    -- get or match address kind -- -- @string [kind] -- @return string|boolean
    kind = function(self, kind)
        local _kind = #self.parts > 0 and "ipv6" or (#self.octets > 0 and "ipv4" or EMPTY)
        if kind then return kind == _kind end

        return _kind
    end,
    -- match two addresses -- -- @table  address -- @number cidr -- @return boolean
    match = function(self, address, cidr)
        if cidr and address._cidr then
            address._cidr = cidr
        end

        return self.__eq(self, address)
    end,
    -- converts ipv4 to ipv4-mapped ipv6 address -- -- @return string|nil
    ipv4_mapped_address = function(self) return self:kind("ipv4") and ip.parsev6("::ffff:" .. self:__tostring()) or nil end,
    -- check if it"s a ipv4 mapped address -- -- @return boolean
    is_ipv4_mapped = function(self) return self:range() == "ipv4Mapped" end,
    -- converts ipv6 ipv4-mapped address to ipv4 address -- -- @return metatable
    ipv4_address = function(self)
        assert(self:is_ipv4_mapped(), "trying to convert a generic ipv6 address to ipv4")
        local high, low = self.parts[7], self.parts[8]

        return ip.v4({rshift(high, 8), band(high, 0xff), rshift(low, 8), band(low, 0xff)})
    end,
    -- IP table to string -- -- @return string
    __tostring = function(self)
        if self:kind("ipv4") then return concat(self.octets, ".") end
        local state, size, output = 0, #self.parts, {}
        for i = 1, size do
            local part = format("%x", self.parts[i])
            if 0 == state then
                insert(output, ZERO == part and EMPTY or part)
                state = 1
            elseif 1 == state then
                if ZERO == part then
                    state = 2
                else
                    insert(output, part)
                end
            elseif 2 == state then
                if ZERO ~= part then
                    insert(output, EMPTY)
                    insert(output, part)
                    state = 3
                end
            else
                insert(output, part)
            end
        end

        if 2 == state then
            insert(output, COLON)
        end

        return concat(output, COLON)
    end,
    -- compare two IP addresses -- -- @table  value -- @return boolean
    __eq = function(self, value)
        if #self.parts > 0 then
            assert(value.parts and #value.parts > 0, "cannot match different address version")

            return match_cidr(self.parts, value.parts, 16, value._cidr)
        end

        assert(value.octets and #value.octets > 0, "cannot match different address version")

        return match_cidr(self.octets, value.octets, 8, value._cidr)
    end
}

ip_metatable.__index = ip_metatable
-- create new IP metatable
--
-- @table  parts
-- @table  octets
-- @number cidr
-- @return metatable
local function new(parts, octets, cidr)
    return setmetatable(
        {
            octets = octets,
            parts = parts,
            _cidr = cidr
        }, ip_metatable
    )
end

-- assert IP version 4 octets and create it"s metatable
--
-- @table  octets
-- @number cidr
-- @return metatable
function ip.v4(octets, cidr)
    local err, message = assert_ipv4(octets)
    assert(err, message)

    return new({}, octets, cidr or 32)
end

-- assert IP version 6 parts and create it"s metatable
--
-- @table  parts
-- @number cidr
-- @table  [octets]
-- @return metatable
function ip.v6(parts, cidr, octets)
    local err, message = assert_ipv6(parts)
    assert(err, message)
    if octets and #octets > 0 then
        err, message = assert_ipv4(octets)
        assert(err, message)
    end

    return new(parts, octets or {}, cidr or 128)
end

-- parse string to IP version 4 metatable
--
-- @string address
-- @number [cidr]
-- @return metatable
function ip.parsev4(address, cidr)
    local octets = {}
    local cr, message = parse_v4(address, octets, cidr)
    assert(cr ~= false, message)

    return ip.v4(octets, cr)
end

-- parse string to IP version 6 metatable
--
-- @string address
-- @number [cidr]
-- @return metatable
function ip.parsev6(address, cidr)
    local parts, octets = {}, {}
    local cr, message = parse_v6(address, parts, octets, cidr)
    assert(cr ~= false, message)

    return ip.v6(parts, cr, octets)
end

-- check and parse string to IP metatable
--
-- @string address
-- @return metatable
function ip.parse(address)
    if ip.isv6(address) then
        return ip.parsev6(address)
    elseif ip.isv4(address) then
        return ip.parsev4(address)
    end

    error("the address has neither IPv6 nor IPv4 format")
end

-- check if string is a IP version 4 address
--
-- @string  address
-- @boolean validate
-- @return  boolean
function ip.isv4(address, validate)
    if validate then
        local octets = {}

        return parse_v4(address, octets) ~= false and assert_ipv4(octets)
    end

    return find_octet(address) ~= nil or find_octets(address) ~= nil
end

-- check if string is a IP version 6 address
--
-- @string  address
-- @boolean validate
-- @return  boolean
function ip.isv6(address, validate)
    if validate then
        local octets, parts = {}, {}

        return parse_v6(address, parts, octets) ~= false and assert_ipv6(parts)
    end

    return find_parts(address) ~= nil
end

-- check if IP address is valid
--
-- @string address
-- @return boolean
function ip.valid(address)
    return pcall(ip.parse, address)
end

return ip

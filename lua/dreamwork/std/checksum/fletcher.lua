---@class dreamwork.std
local std = dreamwork.std

local string = std.string
local string_len = string.len
local string_byte = string.byte

local class = std.class

--- [SHARED AND MENU]
---
--- The Fletcher-16 checksum calculation object.
---
---@class dreamwork.std.Fletcher16 : dreamwork.std.Object
---@field __class dreamwork.std.Fletcher16Class
---@field DigestSize integer The size of the checksum in bytes.
---@field protected a integer The first part of the checksum.
---@field protected b integer The second part of the checksum.
local Fletcher16 = class.base( "Fletcher16", false )

Fletcher16.DigestSize = 2

---@alias Fletcher16 dreamwork.std.Fletcher16

---@protected
function Fletcher16:__init()
    self:reset()
end

--- [SHARED AND MENU]
---
--- Resets checksum to the initial value.
---
---@return dreamwork.std.Fletcher16 self
function Fletcher16:reset()
    self.a, self.b = 0, 0
    return self
end

--- [SHARED AND MENU]
---
--- Updates checksum with the specified string.
---
---@param raw_str string The string is used to update checksum.
---@return dreamwork.std.Fletcher16 self
function Fletcher16:update( raw_str )
    local a, b = self.a, self.b

    for i = 1, string_len( raw_str ), 1 do
        a = (a + string_byte( raw_str, i, i )) % 0xFF
        b = (b + a) % 0xFF
    end

    self.a, self.b = a, b
    return self
end

--- [SHARED AND MENU]
---
--- Finalizes checksum calculation and returns the resulting checksum.
---
---@return integer checksum The final checksum value, which is greater or equal to 0, and less than 2^16 (0x10000).
function Fletcher16:digest()
    return (self.b * 0x0100) + self.a
end

--- [SHARED AND MENU]
---
--- The class used to create new Fletcher-16 checksum calculation instances.
---
--- See [Fletcher's checksum](https://en.wikipedia.org/wiki/Fletcher%27s_checksum) for the definition of the Fletcher-16 checksum.
---
--- [Fletcher Online](https://www.convertcase.com/hashing/fletcher-checksum)
---
---@class dreamwork.std.Fletcher16Class : dreamwork.std.Fletcher16
---@field __base dreamwork.std.Fletcher16
---@overload fun(): dreamwork.std.Fletcher16
local Fletcher16Class = class.create( Fletcher16 )
std.Fletcher16 = Fletcher16Class

do

    local fletcher16 = Fletcher16Class()

    --- [SHARED AND MENU]
    ---
    --- Calculates the Fletcher-16 checksum of the specified string.
    ---
    ---@param raw_str string The string is used to calculate checksum.
    ---@return integer checksum The checksum value, which is greater or equal to 0, and less than 2^16 (0x10000).
    function Fletcher16Class.digest( raw_str )
        return fletcher16:reset():update( raw_str ):digest()
    end

end

--- [SHARED AND MENU]
---
--- The Fletcher-32 checksum calculation object.
---
---@class dreamwork.std.Fletcher32 : dreamwork.std.Fletcher16
---@field __parent dreamwork.std.Fletcher16
---@field __class dreamwork.std.Fletcher32Class
local Fletcher32 = class.base( "Fletcher32", false, Fletcher16Class )

Fletcher32.DigestSize = 4

---@alias Fletcher32 dreamwork.std.Fletcher32

---@protected
function Fletcher32:__init()
    self:reset()
end

--- [SHARED AND MENU]
---
--- Updates checksum with the specified string.
---
---@param raw_str string The string is used to update checksum.
---@return dreamwork.std.Fletcher32 self
function Fletcher32:update( raw_str )
    local a, b = self.a, self.b

    for i = 1, string_len( raw_str ), 1 do
        a = (a + string_byte( raw_str, i, i )) % 0xFFFF
        b = (b + a) % 0xFFFF
    end

    self.a, self.b = a, b
    return self
end

--- [SHARED AND MENU]
---
--- Finalizes checksum calculation and returns the resulting checksum.
---
---@return integer checksum The final checksum value, which is greater or equal to 0, and less than 2^32 (0x100000000).
function Fletcher32:digest()
    return (self.b * 0x10000) + self.a
end

--- [SHARED AND MENU]
---
--- The class used to create new Fletcher-32 checksum calculation instances.
---
--- See [Fletcher's checksum](https://en.wikipedia.org/wiki/Fletcher%27s_checksum) for the definition of the Fletcher-32 checksum.
---
--- [Fletcher Online](https://www.convertcase.com/hashing/fletcher-checksum)
---
---@class dreamwork.std.Fletcher32Class : dreamwork.std.Fletcher32
---@field __parent dreamwork.std.Fletcher16Class
---@field __base dreamwork.std.Fletcher32
---@overload fun(): dreamwork.std.Fletcher32
local Fletcher32Class = class.create( Fletcher32 )
std.Fletcher32 = Fletcher32Class

do

    local fletcher32 = Fletcher32Class()

    --- [SHARED AND MENU]
    ---
    --- Calculates the Fletcher-32 checksum of the specified string.
    ---
    ---@param raw_str string The string is used to calculate checksum.
    ---@return integer checksum The checksum value, which is greater or equal to 0, and less than 2^32 (0x100000000).
    function Fletcher32Class.digest( raw_str )
        return fletcher32:reset():update( raw_str ):digest()
    end

end

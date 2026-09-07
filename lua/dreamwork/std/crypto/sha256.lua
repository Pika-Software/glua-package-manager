---@class dreamwork.std
local std = dreamwork.std

---@class dreamwork.std.crypto
local crypto = std.crypto

--- [SHARED AND MENU]
---
--- SHA256 object.
---
---@class dreamwork.std.crypto.SHA256 : dreamwork.std.Object
---@field __class dreamwork.std.crypto.SHA256Class
local SHA256 = std.class.base( "SHA256" )

--- [SHARED AND MENU]
---
--- The class used to create new `SHA256` hash calculation instances.
---
--- Secure Hash Algorithm 256-bit, part of the SHA-2 family.
---
--- This hash algorithm is recommended because it is fast and secure.
---
--- Like other hash classes, it takes input data ( string )
--- and produces a digest ( string ) — a
--- fixed-size output string that represents that data.
---
---@class dreamwork.std.crypto.SHA256Class : dreamwork.std.crypto.SHA256
---@field __base dreamwork.std.crypto.SHA256
---@field digest_size integer
---@field block_size integer
---@overload fun(): dreamwork.std.crypto.SHA256
local SHA256Class = std.class.create( SHA256 )
crypto.SHA256 = SHA256Class

SHA256Class.digest_size = 32
SHA256Class.block_size = 64

-- TODO: implement (example: md5)

local engine_SHA256 = dreamwork.engine.SHA256

if engine_SHA256 == nil then

    -- TODO: implement (example: md5)

else

    local base16_decode = std.base16.decode

    --- [SHARED AND MENU]
    ---
    --- Computes the SHA256 digest of the given input string.
    ---
    --- This static method takes a string and returns its SHA256 hash as a hexadecimal string.
    --- Commonly used for checksums, data integrity validation, and password hashing.
    ---
    ---@param message string The message to compute SHA256 for.
    ---@param as_hex? boolean If true, the result will be a hex string.
    ---@return string str_result The SHA256 string of the message.
    function SHA256Class.digest( message, as_hex )
        local hex_str = engine_SHA256( message )
        if as_hex then
            return hex_str
        else
            return base16_decode( hex_str )
        end
    end

end

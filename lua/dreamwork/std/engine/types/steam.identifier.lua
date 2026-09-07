local std = dreamwork.std
local string = std.string
local table = std.table
local bit = std.bit

local setmetatable = std.setmetatable
local math_floor = std.math.floor
local tonumber = std.raw.tonumber

---@class dreamwork.std.steam
local steam = {}
std.steam = steam

--- [SHARED AND MENU]
---
--- [Steam Account Type](https://developer.valvesoftware.com/wiki/SteamID#Types_of_Steam_Accounts)
---
---@alias dreamwork.std.steam.Identifier.type
---| `"Invalid"`
---| `"Individual"`
---| `"Multiseat"`
---| `"GameServer"`
---| `"AnonGameServer"`
---| `"Pending"`
---| `"ContentServer"`
---| `"Clan"`
---| `"Chat"`
---| `"ConsoleUser"`
---| `"AnonUser"

--- [SHARED AND MENU]
---
--- [Steam Account Universe](https://developer.valvesoftware.com/wiki/SteamID#Universes_Available_for_Steam_Accounts)
---
---@alias dreamwork.std.steam.Identifier.universe
---| `"Invalid"`
---| `"Public"`
---| `"Beta"`
---| `"Internal"`
---| `"Dev"`
---| `"RC"`

---@type table<dreamwork.std.steam.Identifier.type, integer>
local type2int = {
    Invalid = 0,
    Individual = 1,
    Multiseat = 2,
    GameServer = 3,
    AnonGameServer = 4,
    Pending = 5,
    ContentServer = 6,
    Clan = 7,
    Chat = 8,
    ConsoleUser = 9,
    AnonUser = 10
}

---@type table<dreamwork.std.steam.Identifier.universe, integer>
local universe2int = {
    Invalid = 0,
    Public = 1,
    Beta = 2,
    Internal = 3,
    Dev = 4,
    RC = 5
}

---@type table<string, integer>
local letter2int = {
    I = 0,
    i = 0,
    U = 1,
    M = 2,
    G = 3,
    A = 4,
    P = 5,
    C = 6,
    g = 7,
    T = 8,
    L = 8,
    c = 8,
    a = 10
}

local int2universe = table.flipped( universe2int )
local int2type = table.flipped( type2int )

--- [SHARED AND MENU]
---
--- The Steam ID object.
---
---@class dreamwork.std.steam.Identifier : dreamwork.std.Object
---@field __class dreamwork.std.steam.IdentifierClass
---@field universe dreamwork.std.steam.Identifier.universe Indicates the Steam environment (e.g., public, beta).
---@field type dreamwork.std.steam.Identifier.type Specifies the entity type (e.g., individual user, group, game server).
---@field instance integer Differentiates between multiple instances of the same type within a universe. For individual user accounts, this is typically set to 1, representing the desktop instance.
---@field id integer The unique account number.
---@operator add( integer ): dreamwork.std.steam.Identifier
---@operator sub( integer ): dreamwork.std.steam.Identifier
local Identifier = std.class.base( "Identifier" )

--- [SHARED AND MENU]
---
--- The class used to create new `steam.Identifier` instances.
---
---@class dreamwork.std.steam.IdentifierClass : dreamwork.std.steam.Identifier
---@field __base dreamwork.std.steam.Identifier
---@overload fun( universe?: dreamwork.std.steam.Identifier.universe, type?: dreamwork.std.steam.Identifier.type, id?: integer, instance?: integer ): dreamwork.std.steam.Identifier
local IdentifierClass = std.class.create( Identifier )
steam.Identifier = IdentifierClass

---@protected
function Identifier:__add( int32 )
    return setmetatable( {
        universe = self.universe,
        type = self.type,
        instance = self.instance,
        id = self.id + int32
    }, Identifier )
end

---@protected
function Identifier:__sub( int32 )
    return setmetatable( {
        universe = self.universe,
        type = self.type,
        instance = self.instance,
        id = self.id - int32
    }, Identifier )
end

---@protected
function IdentifierClass:__new( universe, type, id, instance )
    return setmetatable( {
        universe = universe or "Public",
        type = type or "Individual",
        instance = instance or 1,
        id = id or 0
    }, Identifier )
end

do

    local string_format = string.format

    --- [SHARED AND MENU]
    ---
    --- Converts a SteamID object to a Steam2 identifier.
    ---
    ---@param ignore_universe? boolean
    ---@return string
    function Identifier:toSteam2( ignore_universe )
        local id = self.id
        local y = id % 2
        return string_format( "STEAM_%d:%d:%d", ignore_universe and 0 or (universe2int[ self.universe ] or 1), y, (id - y) * 0.5 )
    end

    ---@type table<dreamwork.std.steam.Identifier.type, string>
    local type2letter = {
        Invalid = "I",
        Individual = "U",
        Multiseat = "M",
        GameServer = "G",
        AnonGameServer = "A",
        Pending = "P",
        ContentServer = "C",
        Clan = "g",
        Chat = "T",
        ConsoleUser = "i",
        AnonUser = "a"
    }

    --- [SHARED AND MENU]
    ---
    --- Converts a SteamID object to a Steam3 identifier.
    ---
    ---@return string steam3_str Steam3 identifier.
    function Identifier:toSteam3()
        return string_format( "[%s:%d:%d]", type2letter[ self.type ] or "I", universe2int[ self.universe ] or 0, self.id )
    end

    ---@return string
    ---@protected
    function Identifier:__tostring()
        return string_format( "Steam Identifier: %p %s", self, self:toSteam3() )
    end

end

do

    local string_reverse = string.reverse
    local table_concat = table.concat
    local bit_lshift = bit.lshift
    local bit_bor = bit.bor

    --- [SHARED AND MENU]
    ---
    --- Converts a SteamID object to a 64-bit integer.
    ---
    ---@param object dreamwork.std.steam.Identifier
    ---@return string uint64_str SteamID as a 64-bit integer
    local function to64( object )
        local high = bit_bor(
            bit_lshift( universe2int[ object.universe ] or 0, 24 ),
            bit_lshift( type2int[ object.type ] or 0, 20 ),
            object.instance
        )

        local low = object.id

        local segments, segment_count = {}, 0

        while high ~= 0 or low ~= 0 do
            local temp = ((high % 10) * 0x100000000) + low

            low = math_floor( temp / 10 )
            high = math_floor( high / 10 )

            segment_count = segment_count + 1
            segments[ segment_count ] = temp % 10
        end

        if segment_count == 0 then
            return "0"
        else
            return string_reverse( table_concat( segments, "", 1, segment_count ) )
        end
    end

    Identifier.to64 = to64

    do

        local int2path = {
            [ 1 ] = "profiles",
            [ 7 ] = "groups"
        }

        --- [SHARED AND MENU]
        ---
        --- Gets the URL for a SteamID object.
        ---
        ---@param http? boolean If `true`, returns the HTTP URL, otherwise returns the HTTPS URL.
        ---@return string | nil url_str The URL for the SteamID object.
        function Identifier:getURL( http )
            local path = int2path[ self.type ]
            if path == nil then
                return nil
            else
                return (http and "http" or "https") .. "://steamcommunity.com/" .. path .. "/" .. to64( self )
            end
        end

    end

end

do

    local string_byte = string.byte
    local string_len = string.len

    local bit_rshift = bit.rshift
    local bit_band = bit.band

    local byte2int = {
        [ 0x30 ] = 0,
        [ 0x31 ] = 1,
        [ 0x32 ] = 2,
        [ 0x33 ] = 3,
        [ 0x34 ] = 4,
        [ 0x35 ] = 5,
        [ 0x36 ] = 6,
        [ 0x37 ] = 7,
        [ 0x38 ] = 8,
        [ 0x39 ] = 9
    }

    --- [SHARED AND MENU]
    ---
    --- Checks if a string is a valid 64-bit identifier.
    ---
    ---@param uint64_str string The 64-bit identifier to check.
    ---@return boolean is_valid `true` if the string is a valid 64-bit identifier, `false` otherwise
    ---@return nil | string error_message The error message if the string is not a valid 64-bit identifier.
    function IdentifierClass.isValid64( uint64_str )
        local uint64_str_length = string_len( uint64_str )

        if uint64_str_length == 0 or uint64_str_length > 20 then
            return false, "invalid length"
        end

        for i = 1, uint64_str_length, 1 do
            if byte2int[ string_byte( uint64_str, i, i ) ] == nil then
                return false, "invalid character at position " .. i
            end
        end

        return true
    end

    --- [SHARED AND MENU]
    ---
    --- Creates a new SteamID object from a 64-bit number string.
    ---
    ---@param uint64_str string The 64-bit number string.
    ---@return dreamwork.std.steam.Identifier
    function IdentifierClass.from64( uint64_str )
        -- original variant was replaced with a more efficient implementation from Be1zebub: https://github.com/Be1zebub/Small-GLua-Things/blob/master/libs/steamid64-parse.lua
        local high, low = 0, 0

        for i = 1, string_len( uint64_str ), 1 do
            local temp = (low * 10) + byte2int[ string_byte( uint64_str, i, i ) ]
            high = (high * 10) + math_floor( temp / 0x100000000 )
            low = temp % 0x100000000
        end

        return setmetatable( {
            universe = int2universe[ bit_band( bit_rshift( high, 24 ), 0xFF ) ] or "Invalid",
            type = int2type[ bit_band( bit_rshift( high, 20 ), 0xF ) ] or "Invalid",
            instance = bit_band( high, 0xFFFFF ),
            id = low
        }, Identifier )
    end

end

do

    local string_match = string.match

    --- [SHARED AND MENU]
    ---
    --- Checks if a string is a valid Steam2 identifier.
    ---
    ---@param steam2_str string The Steam2 identifier to check.
    ---@return boolean is_valid `true` if the string is a valid Steam2 identifier, `false` otherwise
    function IdentifierClass.isValidSteam2( steam2_str )
        local x, y, z = string_match( steam2_str, "^STEAM_(%d+):(%d+):(%d+)$" )
        if not (x and y and z) then
            return false
        end

        local universe = tonumber( x, 10 )
        if universe == nil or universe > 255 then -- 2 ^ 8 ( 8 bits )
            return false
        end

        if not (y == "0" or y == "1") then -- 0 or 1 ( 1 bit )
            return false
        end

        local id = tonumber( z, 10 )
        if id == nil or id > 2147483648 then -- 2 ^ 31 ( 31 bits )
            return false
        end

        return true
    end

    --- [SHARED AND MENU]
    ---
    --- Checks if a string is a valid Steam3 identifier.
    ---
    ---@param steam3_str string The Steam3 identifier to check.
    ---@return boolean is_valid `true` if the string is a valid Steam3 identifier, `false` otherwise
    function IdentifierClass.isValidSteam3( steam3_str )
        local letter, universe_str, id_str = string_match( steam3_str, "^%[(%a):(%d+):(%d+)%]$" )
        if not (letter and universe_str and id_str) or letter2int[ letter ] == nil then
            return false
        end

        local universe = tonumber( universe_str, 10 )
        if universe == nil or universe > 255 then -- 2 ^ 8 ( 8 bits )
            return false
        end

        local id = tonumber( id_str, 10 )
        if id == nil or id > 4294967296 then -- 2 ^ 32 ( 32 bits )
            return false
        end

        return true
    end

    --- [SHARED AND MENU]
    ---
    --- Creates a new SteamID object from a steam2 string.
    ---
    ---@param steam2_str string The steam2 string to parse.
    ---@param allow_zero_universe? boolean Whether to allow the universe to be zero.
    ---@return dreamwork.std.steam.Identifier object The SteamID object.
    function IdentifierClass.fromSteam2( steam2_str, allow_zero_universe )
        local x, y, z = string_match( steam2_str, "^STEAM_([12]?%d?%d):([01]):(%d+)$" )
        if x == nil or y == nil or z == nil then
            error( "steam identifier steam2 is invalid", 2 )
        end

        local universe = tonumber( x, 10 )
        if universe == 0 and not allow_zero_universe then
            universe = 1
        end

        return setmetatable( {
            universe = int2universe[ universe ] or "Invalid",
            type = "Individual",
            instance = 1,
            id = (tonumber( z, 10 ) * 2) + (y == "1" and 1 or 0)
        }, Identifier )
    end

    --- [SHARED AND MENU]
    ---
    --- Creates a new SteamID object from a steam3 string.
    ---
    ---@param steam3_str string The steam3 string to parse.
    ---@return dreamwork.std.steam.Identifier object The SteamID object.
    function IdentifierClass.fromSteam3( steam3_str )
        local letter, universe, id = string_match( steam3_str, "^%[?(%a):(%d+):(%d+)%]?$" )
        if letter == nil or universe == nil or id == nil then
            error( "steam identifier steam3 is invalid", 2 )
        end

        return setmetatable( {
            universe = int2universe[ tonumber( universe, 10 ) or 0 ] or "Invalid",
            type = int2type[ letter2int[ letter ] or 0 ] or "Invalid",
            instance = 1,
            id = tonumber( id, 10 ) or 0
        }, Identifier )
    end

end

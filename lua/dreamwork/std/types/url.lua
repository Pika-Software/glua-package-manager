---@class dreamwork.std
local std                      = dreamwork.std

local tostring                 = std.tostring

local isString                 = std.isString
local isNumber                 = std.isNumber
local isTable                  = std.isTable

local raw                      = std.raw
local raw_pairs                = raw.pairs
local raw_tonumber             = raw.tonumber
local raw_get, raw_set         = raw.get, raw.set

local math                     = std.math
local math_floor               = math.floor

local table                    = std.table
local table_concat             = table.concat
local table_remove             = table.remove

local ascii                    = std.ascii
local ascii_isLower            = ascii.isLower
local ascii_isUpper            = ascii.isUpper
local ascii_isAlpha            = ascii.isAlpha
local ascii_isDigit            = ascii.isDigit
local ascii_isHexDigit         = ascii.isHexDigit

local string                   = std.string
local string_format            = string.format
local string_containsBytes     = string.containsBytes
local string_sub, string_gsub  = string.sub, string.gsub
local string_len, string_lower = string.len, string.lower
local string_byte, string_char = string.byte, string.char

local bit                      = std.bit
local bit_band, bit_bor        = bit.band, bit.bor
local bit_rshift, bit_lshift   = bit.rshift, bit.lshift

local utf8                     = std.utf8

local ipv4                     = std.ipv4
local ipv4_parse               = ipv4.parse

local class                    = std.class

local percent                  = std.percent


--- [SHARED AND MENU]
---
--- The URL object.
---
---@class dreamwork.std.URL : dreamwork.std.Object, dreamwork.std.URL.State
---@field __class dreamwork.std.URLClass
---@field state dreamwork.std.URL.State internal state of URL
---@field href string full url
---@field origin string? *readonly* scheme + hostname + port
---@field protocol string? just a scheme with ':' appended at the end
---@field username string? used for basic auth as username
---@field password string? used for basic auth as password
---@field host string hostname + port
---@field hostname string?
---@field port number?
---@field pathname string?
---@field query string?
---@field search string? a query with '?' prepended
---@field searchParams dreamwork.std.URL.SearchParams
---@field fragment string?
---@field hash string? fragment with # prepended
local URL = class.base( "URL" )

--- [SHARED AND MENU]
---
--- The class used to create new `URL` instances.
---
--- Parses given URL string and returns a new URL object
--- using URL object with tostring(...) will result in getting `.href`
--- ```lua
--- local baseUrl = "https://developer.mozilla.org"
---
--- local A = URL("/", baseURL)
--- -- => 'https://developer.mozilla.org/'
---
--- local B = URL(baseURL)
--- -- => 'https://developer.mozilla.org/'
---
--- URL("en-US/docs", B)
--- -- => 'https://developer.mozilla.org/en-US/docs'
---
--- local D = URL("/en-US/docs", B)
--- -- => 'https://developer.mozilla.org/en-US/docs'
---
--- URL("/en-US/docs", D)
--- -- => 'https://developer.mozilla.org/en-US/docs'
---
--- URL("/en-US/docs", A)
--- -- => 'https://developer.mozilla.org/en-US/docs'
---
--- URL("/en-US/docs", "https://developer.mozilla.org/fr-FR/toto")
--- -- => 'https://developer.mozilla.org/en-US/docs'
--- ```
---@class dreamwork.std.URLClass : dreamwork.std.URL
---@field __base dreamwork.std.URL
---@overload fun( url: string, base: string | dreamwork.std.URL | nil ): dreamwork.std.URL
local URLClass = class.create( URL )
std.URL = URLClass


--- [SHARED AND MENU]
---
--- The URL search parameters object.
---
---@class dreamwork.std.URL.SearchParams : dreamwork.std.Object
---@field __class dreamwork.std.URL.SearchParamsClass
local SearchParams = class.base( "URLSearchParams" )

--- [SHARED AND MENU]
---
--- The class used to create new `URL.SearchParams` instances.
---
--- Parses given `init` and returns a new `URLSearchParams` object
--- if `init` is table, then it must be a list that consists of tables
--- that have two value, name and value
--- e.g. `{ {"name", "value"}, {"foo", "bar"}, {"good"} }`
---
--- also calling tostring(...) with `URLSearchParams` given will result in getting serialized query
--- also `#` can be used to get a total count of parameters (e.g. #searchParams)
---
---@class dreamwork.std.URL.SearchParamsClass : dreamwork.std.URL.SearchParams
---@field __base dreamwork.std.URL.SearchParams
---@operator len:integer
---@return dreamwork.std.URL.SearchParams
local SearchParamsClass = class.create( SearchParams )

local PUNYCODE_PREFIX = {
    0x78,
    0x6E,
    0x2D,
    0x2D
}

local SPECIAL_SCHEMAS = {
    ftp = 21,
    file = true,
    http = 80,
    https = 443,
    ws = 80,
    wss = 443
}

local FORBIDDEN_HOST_CODE_POINTS = string.byteMap(
    "\0", "\t", "\n", "\r", " ", "#", "/", ":",
    "<", ">", "?", "@", "[", "\\", "]", "^", "|"
)

local FORBIDDEN_DOMAIN_CODE_POINTS = string.byteMap(
    "\0", "\t", "\n", "\r", " ", "#", "/", ":", "<", ">",
    "?", "@", "[", "\\", "]", "^", "|",
    { leading_byte = "\0", trailing_byte = "\x1F" },
    "%", "\x7F"
)

local FILE_OTHERWISE_CODE_POINTS = string.byteMap(
    "/", "\\", "?", "#"
)

local DECODE_LOOKUP_TABLE = {}

for i = 0x00, 0xFF do
    local hex = bit.tohex( i, 2 )
    DECODE_LOOKUP_TABLE[ hex ] = string_char( i )
    DECODE_LOOKUP_TABLE[ hex:upper() ] = string_char( i )
end

local URI_DECODE_SET = table.shallowCopy( DECODE_LOOKUP_TABLE )

for _, i in raw.ipairs( { 0x2D, 0x2E, 0x21, 0x7E, 0x2A, 0x27, 0x28, 0x29 } ) do
    local hex = bit.tohex( i, 2 )
    URI_DECODE_SET[ hex ] = nil
    URI_DECODE_SET[ string.upper( hex ) ] = nil
end

---@param str string
---@param decodeSet table
---@return string
local function percentDecode( str, decodeSet )
    return (string_gsub( str, "%%(%x%x)", decodeSet ))
end

local function compilePercentEncodeSet( encodeSet, ... )

    -- Lookup table for decoding percent-encoded characters and encoding special characters
    -- Using HEX_TABLE will result in a double speedup compared to using functions

    do

        local _tab_0 = {}
        local _idx_0 = 1

        for _key_0, _value_0 in raw_pairs( encodeSet ) do
            if _idx_0 == _key_0 then
                _tab_0[ #_tab_0 + 1 ] = _value_0
                _idx_0 = _idx_0 + 1
            else
                _tab_0[ _key_0 ] = _value_0
            end
        end

        encodeSet = _tab_0
    end

    local _list_1 = { ... }
    for _index_0 = 1, #_list_1 do
        local ch = _list_1[ _index_0 ]
        if isString( ch ) then
            ch = string_byte( ch )
        end

        if isNumber( ch ) then
            encodeSet[ string_char( ch ) ] = "%" .. bit.tohex( ch, 2 ):upper()
        elseif isTable( ch ) then
            for i = isString( ch[ 1 ] ) and string_byte( ch[ 1 ] ) or ch[ 1 ], isString( ch[ 2 ] ) and string_byte( ch[ 2 ] ) or ch[ 2 ], 1 do
                encodeSet[ string_char( i ) ] = "%" .. bit.tohex( i, 2 ):upper()
            end
        end
    end

    return encodeSet
end

local function percentEncode( s, encodeSet, spaceAsPlus )
    local old = nil
    if spaceAsPlus == true then
        old = encodeSet[ " " ]
        encodeSet[ " " ] = "+"
    end

    s = string_gsub( s, "%W", encodeSet )

    if old then
        encodeSet[ " " ] = old
    end

    return s
end

-- local c0_percent_whitelist       = percent.whitelist( "^\x00-\x1F" )

local C0_ENCODE_SET            = compilePercentEncodeSet(
    {},
    { 0x00, 0x1F },
    { 0x7F, 0xFF }
)

-- local fragment_percent_whitelist = percent.whitelist(
--     "^ \"<>`"
-- )

local FRAGMENT_ENCODE_SET      = compilePercentEncodeSet( C0_ENCODE_SET,
    " ", "\"", "<", ">", "`"
)

local QUERY_ENCODE_SET         = compilePercentEncodeSet( C0_ENCODE_SET,
    " ", "\"", "#", "<", ">"
)

local SPECIAL_QUERY_ENCODE_SET = compilePercentEncodeSet( QUERY_ENCODE_SET,
    "'"
)

local PATH_ENCODE_SET          = compilePercentEncodeSet( QUERY_ENCODE_SET,
    "?", "`", "{", "}"
)

local USERINFO_ENCODE_SET      = compilePercentEncodeSet( PATH_ENCODE_SET,
    "/", ":", ";", "=", "@", { 0x5B, 0x5E }, "|"
)

local COMPONENT_ENCODE_SET     = compilePercentEncodeSet( USERINFO_ENCODE_SET,
    { 0x24, 0x26 }, "+", ","
)

local URLENCODED_ENCODE_SET    = compilePercentEncodeSet( COMPONENT_ENCODE_SET,
    "!", { 0x27, 0x29 }, "~"
)

local URI_ENCODE_SET           = compilePercentEncodeSet( C0_ENCODE_SET,
    0x20,
    0x22,
    0x25,
    0x3C,
    0x3E,
    { 0x42, 0x59 },
    { 0x5B, 0x5E },
    0x60,
    { 0x62, 0x79 },
    { 0x7B, 0x7D }
)

---@param str string
---@param str_length integer
---@return boolean
local function isSingleDot( str, str_length )
    if str_length == 1 then
        return string_byte( str, 1, 1 ) == 0x2E -- .
    elseif str_length == 3 then
        return string_lower( str ) == "%2e"
    end

    return false
end

---@param str string
---@param segment_length integer
---@return boolean
local function isDoubleDot( str, segment_length )
    if segment_length == 2 then
        local uint8_1, uint8_2 = string_byte( str, 1, 2 )
        return uint8_1 == 0x2E and uint8_2 == 0x2E -- .
    elseif segment_length == 4 then
        str = string_lower( str )
        return str == "%2e." or str == ".%2e"
    elseif segment_length == 6 then
        return string_lower( str ) == "%2e%2e"
    end

    return false
end

local function isWindowsDriveLetterCodePoints( ch1, ch2, normalized )
    return ascii_isAlpha( ch1 ) and (ch2 == 0x3A or (normalized == false and ch2 == 0x7C))
end

local function isWindowsDriveLetter( str, normalized )
    return #str == 2 and isWindowsDriveLetterCodePoints( string_byte( str, 1 ), string_byte( str, 2 ), normalized )
end

local function startsWithWindowsDriveLetter( str, startPos, endPos )
    local len = endPos - startPos + 1
    return len >= 2 and isWindowsDriveLetterCodePoints( string_byte( str, startPos ), string_byte( str, startPos + 1 ), false ) and (len == 2 or FILE_OTHERWISE_CODE_POINTS[ string_byte( str, startPos + 2 ) ])
end

-- Converts character to digit,
-- if given non valid character it will return invalid number
local function charToDec( ch )
    return ch - 0x30
end

local function hexToDec( ch )
    if ch >= 0x61 then
        return ch - 0x61 + 10
    elseif ch >= 0x41 then
        return ch - 0x41 + 10
    else
        return charToDec( ch )
    end
end

-- Finds nearest non whitespace character from startPos to endPos
-- And returns the position of that character
local function trimInput( str, startPos, endPos )
    for i = startPos, endPos, (startPos < endPos and 1 or -1) do
        local ch = string_byte( str, i )
        if not ch or ch > 0x20 then return i end
    end

    return endPos - 1
end

-- RFC 3492 Punycode encode
local function punycodeEncode( str, startPos, endPos )
    local base = 36
    local tMin = 1
    local tMax = 26
    local skew = 38
    local damp = 700
    local initialBias = 72
    local initialN = 0x80
    local delimiter = 0x2D

    -- Initialize the state
    local n = initialN

    local input, inputLen = utf8.unpack( str, startPos, endPos, true )

    local output = {}
    local delta = 0
    local out = 0
    local bias = initialBias

    -- Handle the basic code points
    for _index_0 = 1, #input do
        local ch = input[ _index_0 ]
        if ch < 0x80 then
            out = out + 1
            output[ out ] = string_char( ch )
        end
    end

    -- h is the number of code points that have been handled, b is the number of basic code points
    -- that have been handled, and out is the number of characters that have been output.
    local h = out
    local b = out
    if b > 0 then
        out = out + 1
        output[ out ] = string_char( delimiter )
    end

    -- Main encoding loop
    while h < inputLen do
        -- All non-basic code points < n have been handled already. Find the next larger one
        local m = 0x7FFFFFFF
        for _index_0 = 1, #input do
            local ch = input[ _index_0 ]
            if ch >= n and ch < m then
                m = ch
            end
        end

        -- Increase delta enough to advance the decoder's <n,i> state to <m,0>, but guard against overflow
        if m - n > (0x7FFFFFFF - delta) / (h + 1) then
            error( "Invalid URL: Punycode overflow" )
        end

        delta = delta + ((m - n) * (h + 1))
        n = m

        for _index_0 = 1, #input do
            local ch = input[ _index_0 ]
            -- Punycode does not need to check whether input[j] is basic:
            if ch < n then
                delta = delta + 1
                if delta + 1 > 0x7FFFFFFF then
                    error( "Invalid URL: Punycode overflow" )
                end
            end

            if ch == n then
                -- Represent delta as a generalized variable-length integer
                local q = delta
                local k = base
                while true do
                    local t = k <= bias and tMin or k >= bias + tMax and tMax or k - bias
                    if q < t then
                        break
                    end

                    local d = t + (q - t) % (base - t)
                    out = out + 1
                    output[ out ] = string_char( d + 22 + (d < 26 and 75 or 0) )
                    q = math_floor( (q - t) / (base - t) )
                    k = k + base
                end

                out = out + 1
                output[ out ] = string_char( q + 22 + (q < 26 and 75 or 0) )
                k = 0

                delta = h == b and math_floor( delta / damp ) or bit_rshift( delta, 1 )
                delta = delta + math_floor( delta / (h + 1) )
                while delta > ((base - tMin) * tMax) / 2 do
                    delta = math_floor( delta / (base - tMin) )
                    k = k + base
                end

                bias = math_floor( k + (base - tMin + 1) * delta / (delta + skew) )
                delta = 0
                h = h + 1
            end
        end

        delta = delta + 1
        n = n + 1
    end

    return table_concat( output, "", 1, out )
end

local function parseIPv4InIPv6( str, pointer, endPos, address, pieceIndex )
    local numbersSeen = 0
    while pointer <= endPos do
        local ipv4Piece = nil
        local ch = string_byte( str, pointer )
        if numbersSeen > 0 then
            if not (ch == 0x2E and numbersSeen < 4) then
                error( "Invalid URL: IPv4 in IPv6 invalid code point" )
            end

            pointer = pointer + 1
            ch = pointer <= endPos and string_byte( str, pointer )
        end

        while ch and ascii_isDigit( ch ) do
            local num = charToDec( ch )
            if not ipv4Piece then
                ipv4Piece = num
            elseif ipv4Piece == 0 then
                error( "Invalid URL: IPv4 in IPv6 invalid code point" )
            else
                ipv4Piece = ipv4Piece * 10 + num
            end

            if ipv4Piece > 255 then
                error( "Invalid URL: IPv4 in IPv6 out of range part" )
            end

            pointer = pointer + 1
            ch = pointer <= endPos and string_byte( str, pointer )
        end

        if not ipv4Piece then
            error( "Invalid URL: IPv4 in IPv6 invalid code point" )
        end

        address[ pieceIndex ] = address[ pieceIndex ] * 0x100 + ipv4Piece
        numbersSeen = numbersSeen + 1

        if numbersSeen == 2 or numbersSeen == 4 then
            pieceIndex = pieceIndex + 1
        end
    end

    if numbersSeen ~= 4 then
        error( "Invalid URL: IPv4 in IPv6 too few parts" )
    end

    return pieceIndex
end

local function parseIPv6( str, startPos, endPos )
    local address = { 0, 0, 0, 0, 0, 0, 0, 0 }
    local pointer = startPos
    local pieceIndex = 1
    local compress = nil

    if string_byte( str, startPos ) == 0x3A then
        if startPos == endPos or string_byte( str, startPos + 1 ) ~= 0x3A then
            error( "Invalid URL: IPv6 invalid compression" )
        end

        pointer = pointer + 2
        pieceIndex = 2
        compress = 2
    end

    while pointer <= endPos do
        if pieceIndex == 9 then
            error( "Invalid URL: IPv6 too many pieces" )
        end

        local ch = string_byte( str, pointer )
        if ch == 0x3A then
            if compress then
                error( "Invalid URL: IPv6 multiple compression" )
            end

            pointer = pointer + 1
            pieceIndex = pieceIndex + 1
            compress = pieceIndex
            goto _continue_0
        end

        local value = 0
        local length = 0
        while length < 4 and ch and ascii_isHexDigit( ch ) do
            value = value * 0x10 + hexToDec( ch )
            pointer = pointer + 1
            length = length + 1
            ch = pointer <= endPos and string_byte( str, pointer )
        end

        if ch == 0x2E then
            if length == 0 then
                error( "Invalud URL: IPv4 in IPv6 invalid code point" )
            end

            pointer = pointer - length
            if pieceIndex > 7 then
                error( "Invalid URL: IPv4 in IPv6 too many pieces" )
            end

            pieceIndex = parseIPv4InIPv6( str, pointer, endPos, address, pieceIndex )
            break
        elseif ch == 0x3A then
            pointer = pointer + 1
            if pointer > endPos then
                error( "Invalid URL: IPv6 invalid code point" )
            end
        elseif pointer <= endPos then
            error( "Invalid URL: IPv6 invalid code point" )
        end

        address[ pieceIndex ] = value
        pieceIndex = pieceIndex + 1
        ::_continue_0::
    end

    if compress then
        local swaps = pieceIndex - compress
        pieceIndex = 8
        while pieceIndex ~= 1 and swaps > 0 do
            local value = address[ pieceIndex ]
            address[ pieceIndex ] = address[ compress + swaps - 1 ]
            address[ compress + swaps - 1 ] = value
            swaps = swaps - 1
            pieceIndex = pieceIndex - 1
        end
    elseif pieceIndex ~= 9 then
        error( "Invalid URL: IPv6 too few pieces" )
    end

    return address
end

local function endsInANumberChecker( str, startPos, endPos )
    -- find a starting point for number
    local numStart, numEnd = startPos, endPos

    for i = numEnd, numStart, -1 do
        if string_byte( str, i ) == 0x2E --[[ . ]] then
            if i == endPos then
                numEnd = i - 1
            else
                numStart = i + 1
                break
            end
        end
    end

    -- sanity check, do not invoke parser if we have ONLY digits
    for i = numStart, numEnd, 1 do
        if not ascii_isDigit( string_byte( str, i ) ) then
            -- welp, let us try at least parse it, what if it is a hex number
            local uint8_1, uint8_2 = string_byte( str, numStart, numStart + 1 )
            return uint8_1 == 0x30 --[[ 0 ]] and (uint8_2 == 0x78 --[[ x ]] or uint8_2 == 0x58 --[[ X ]])
        end
    end

    -- every charactar was a digit, yay!
    return numStart <= numEnd
end


local function domainToASCII( domain )
    for i = 1, #domain do
        if string_byte( domain, i ) > 0x7F then
            -- Remove special symbols that are ignored
            -- I probably really should implement some proper punycode
            domain = string_gsub( domain, "\xC2\xAD", "" )
            domain = string_gsub( domain, "\xE3\x80\x82", "." )

            -- remove space characters
            domain = string_gsub( domain, "\xE2\x80\x8B", "" )
            domain = string_gsub( domain, "\xE2\x81\xA0", "" )
            domain = string_gsub( domain, "\xEF\xBB\xBF", "" )
            break
        end
    end

    local containsNonASCII = false
    local doLowerCase = false

    local punycodePrefix = 0

    local partStart = 1
    local pointer = 1

    local segments = {}
    local segment_count = 0

    while true do
        local ch = string_byte( domain, pointer )
        if not ch or ch == 0x2E then
            -- decode an find errors
            if punycodePrefix == 4 and containsNonASCII then
                error( "Invalid URL: Domain invalid code point" )
            end

            local domainPart = containsNonASCII and "xn--" .. punycodeEncode( domain, partStart, pointer - 1 ) or string_sub( domain, partStart, pointer - 1 )

            -- btw, punycode decode lowercases the domain, so we need to lowercase it
            -- in ideal sutiation I should have written punycodeDecode, but I am not in the mood to write it
            if doLowerCase then
                domainPart = string_lower( domainPart )
            end

            segment_count = segment_count + 1
            segments[ segment_count ] = domainPart

            partStart = pointer + 1

            containsNonASCII = false
            doLowerCase = false
            punycodePrefix = 0

            if not ch then
                break
            end
        elseif ch > 0x7F then
            containsNonASCII = true
        elseif PUNYCODE_PREFIX[ pointer - partStart + 1 ] == ch then
            punycodePrefix = punycodePrefix + 1
        elseif ascii_isUpper( ch ) then
            doLowerCase = true
        end

        pointer = pointer + 1
    end

    if segment_count == 0 then
        return ""
    elseif segment_count == 1 then
        return segments[ 1 ]
    elseif segment_count == 2 then
        return segments[ 1 ] .. "." .. segments[ 2 ]
    else
        return table_concat( segments, ".", 1, segment_count )
    end
end


local function parseHostString( str, startPos, endPos, isSpecial )
    if string_byte( str, startPos ) == 0x5B --[[ [ ]] then
        if string_byte( str, endPos ) ~= 0x5D --[[ ] ]] then
            error( "Invalid URL: IPv6 unclosed", 2 )
        end

        return parseIPv6( str, startPos + 1, endPos - 1 )
    elseif not isSpecial then
        -- opaque host parsing
        if string_containsBytes( str, FORBIDDEN_HOST_CODE_POINTS, startPos, endPos ) then
            error( "Invalid URL: Host invalid code point", 2 )
        end

        return percentEncode( string_sub( str, startPos, endPos ), C0_ENCODE_SET )
    end

    local ascii_domain = domainToASCII( percentDecode( string_sub( str, startPos, endPos ), DECODE_LOOKUP_TABLE ) )
    local ascii_domain_length = string_len( ascii_domain )

    if string_containsBytes( ascii_domain, FORBIDDEN_DOMAIN_CODE_POINTS ) then
        error( "Invalid URL: Domain invalid code point", 2 )
    end

    if endsInANumberChecker( ascii_domain, 1, ascii_domain_length ) then
        return ipv4_parse( ascii_domain, nil, nil, ascii_domain_length )
    end

    return ascii_domain
end

-- Predefine locals so we can make functions in the order I want (as if you were reading specs)
local parseScheme, parseNoScheme, parseSpecialRelativeOrAuthority, parsePathOrAuthority
local parseRelative, parseRelativeSlash, parseSpecialAuthorityIgnoreSlashes, parseAuthority
local parseHost, parsePort, parseFile, parseFileSlash, parseFileHost, parsePathStart, parsePath, parseOpaquePath
local parseQuery, parseFragment

parseScheme = function( self, str, startPos, endPos, base, stateOverride )
    -- scheme start state
    if startPos <= endPos and ascii_isAlpha( string_byte( str, startPos ) ) then
        -- scheme state
        local doLowerCase = false
        local scheme = nil
        for i = startPos, endPos do
            local ch = string_byte( str, i )
            if ch == 0x3A then
                scheme = string_sub( str, startPos, i - 1 )
                if doLowerCase then
                    scheme = string_lower( scheme )
                end

                local isSpecial = SPECIAL_SCHEMAS[ scheme ]
                if stateOverride then
                    local isUrlSpecial = self.scheme and SPECIAL_SCHEMAS[ self.scheme ]
                    if isUrlSpecial and not isSpecial then
                        return
                    end

                    if not isUrlSpecial and isSpecial then
                        return
                    end

                    if self.username or self.password or self.port and isSpecial == true then
                        return
                    end

                    if isUrlSpecial == true and self.hostname ~= "" then
                        return
                    end
                end

                self.scheme = scheme

                if stateOverride then
                    if self.port == isSpecial then
                        self.port = nil
                    end
                elseif isSpecial == true then
                    -- file state
                    parseFile( self, str, i + 1, endPos, base )
                elseif isSpecial and base and base.scheme == scheme then
                    -- special relative or authority state
                    parseSpecialRelativeOrAuthority( self, str, i + 1, endPos, base, isSpecial )
                elseif isSpecial then
                    -- special authority slashes state
                    parseSpecialAuthorityIgnoreSlashes( self, str, i + 1, endPos, base, isSpecial )
                elseif string_byte( str, i + 1 ) == 0x2F then
                    -- path or authority state
                    parsePathOrAuthority( self, str, i + 2, endPos, base )
                else
                    -- opaque path state
                    parseOpaquePath( self, str, i + 1, endPos )
                end

                return
            elseif ascii_isUpper( ch ) then
                doLowerCase = true
            elseif not ascii_isLower( ch ) and not ascii_isDigit( ch ) and ch ~= 0x2B and ch ~= 0x2D and ch ~= 0x2E then
                -- scheme have an invalid character, so it's not a scheme
                break
            end
        end
    end

    if not stateOverride then
        -- no scheme state
        return parseNoScheme( self, str, startPos, endPos, base )
    end
end

parseNoScheme = function( self, str, startPos, endPos, base )
    local startsWithFragment = string_byte( str, startPos ) == 0x23
    local baseHasOpaquePath = base and isString( base.path )
    if not base or (baseHasOpaquePath and not startsWithFragment) then
        error( "Invalid URL: Missing scheme" )
    end

    if baseHasOpaquePath and startsWithFragment then
        self.scheme = base.scheme
        self.path = base.path
        self.query = base.query
        return parseFragment( self, str, startPos + 1, endPos )
    elseif base.scheme ~= "file" then
        return parseRelative( self, str, startPos, endPos, base, SPECIAL_SCHEMAS[ base.scheme ] )
    else
        self.scheme = "file"
        return parseFile( self, str, startPos, endPos, base )
    end
end

parseSpecialRelativeOrAuthority = function( self, str, startPos, endPos, base, isSpecial )
    if string_byte( str, startPos ) == 0x2F and string_byte( str, startPos + 1 ) == 0x2F then
        -- special authority slashes state
        return parseSpecialAuthorityIgnoreSlashes( self, str, startPos + 2, endPos, base, isSpecial )
    else
        -- relative state
        self.scheme = base.scheme
        return parseRelative( self, str, startPos, endPos, base, isSpecial )
    end
end

parsePathOrAuthority = function( self, str, startPos, endPos, base )
    if string_byte( str, startPos ) == 0x2F then
        return parseAuthority( self, str, startPos + 1, endPos )
    else
        return parsePath( self, str, startPos, endPos )
    end
end

parseRelative = function( self, str, startPos, endPos, base, isSpecial )
    self.scheme = base.scheme

    local ch = startPos <= endPos and string_byte( str, startPos )
    if ch == 0x2F or (isSpecial and ch == 0x5C) then
        -- relative slash state
        return parseRelativeSlash( self, str, startPos + 1, endPos, base, isSpecial )
    else
        self.username = base.username
        self.password = base.password
        self.hostname = base.hostname
        self.port = base.port

        local path
        do
            local _tab_0 = {}
            local _obj_0 = (base.path or {})
            local _idx_0 = 1
            for _key_0, _value_0 in raw_pairs( _obj_0 ) do
                if _idx_0 == _key_0 then
                    _tab_0[ #_tab_0 + 1 ] = _value_0
                    _idx_0 = _idx_0 + 1
                else
                    _tab_0[ _key_0 ] = _value_0
                end
            end

            path = _tab_0
        end

        self.path = path

        if ch == 0x3F then
            return parseQuery( self, str, startPos + 1, endPos )
        elseif ch == 0x23 then
            self.query = base.query
            return parseFragment( self, str, startPos + 1, endPos )
        elseif ch then
            local pathLen = #path
            if pathLen ~= 1 or not isWindowsDriveLetter( path[ 1 ] ) then
                path[ pathLen ] = nil
            end

            return parsePath( self, str, startPos, endPos, isSpecial, path )
        end
    end
end

function parseRelativeSlash( self, str, startPos, endPos, base, isSpecial )
    local ch = string_byte( str, startPos )
    if isSpecial and (ch == 0x2F or ch == 0x5C) then
        -- special authority ignore slashes state
        return parseSpecialAuthorityIgnoreSlashes( self, str, startPos + 1, endPos, base, isSpecial )
    elseif ch == 0x2F then
        -- authority state
        return parseAuthority( self, str, startPos + 1, endPos, isSpecial )
    else
        self.username = base.username
        self.password = base.password
        self.hostname = base.hostname
        self.port = base.port
        return parsePath( self, str, startPos, endPos, isSpecial )
    end
end

function parseSpecialAuthorityIgnoreSlashes( self, str, startPos, endPos, base, isSpecial )
    for i = startPos, endPos, 1 do
        local ch = string_byte( str, i )
        if ch ~= 0x2F and ch ~= 0x5C then
            parseAuthority( self, str, i, endPos, isSpecial )
            break
        end
    end
end

function parseAuthority( self, str, startPos, endPos, isSpecial )
    -- authority state
    local atSignSeen, passwordTokenSeen
    local pathEndPos = endPos
    for i = startPos, endPos, 1 do
        local ch = string_byte( str, i )
        if ch == 0x2F or ch == 0x3F or ch == 0x23 or (isSpecial and ch == 0x5C) then
            endPos = i - 1
            break
        elseif ch == 0x40 then
            atSignSeen = i
        elseif ch == 0x3A and not passwordTokenSeen and not atSignSeen then
            passwordTokenSeen = i
        end
    end

    -- After @ there is no hostname
    if atSignSeen == endPos then
        error( "Invalid URL: Missing host", 2 )
    end

    if atSignSeen then
        if passwordTokenSeen then
            self.username = percentEncode( string_sub( str, startPos, passwordTokenSeen - 1 ), USERINFO_ENCODE_SET )
            self.password = percentEncode( string_sub( str, passwordTokenSeen + 1, atSignSeen - 1 ), USERINFO_ENCODE_SET )
        else
            self.username = percentEncode( string_sub( str, startPos, atSignSeen - 1 ), USERINFO_ENCODE_SET )
        end
    end

    parseHost( self, str, atSignSeen and atSignSeen + 1 or startPos, endPos, isSpecial )
    return parsePathStart( self, str, endPos + 1, pathEndPos, isSpecial )
end

function parseHost( self, str, startPos, endPos, isSpecial, stateOverride )
    if stateOverride and isSpecial == true then
        return parseFileHost( self, str, startPos, endPos, stateOverride )
    end

    local insideBrackets = false
    for i = startPos, endPos, 1 do
        local ch = string_byte( str, i )
        if ch == 0x3A and not insideBrackets then
            if i == startPos then
                error( "Invalid URL: Missing host", 2 )
            end

            if stateOverride == "hostname" then
                return
            end

            parsePort( self, str, i + 1, endPos, isSpecial, stateOverride )
            endPos = i - 1
            break
        elseif ch == 0x5B then
            insideBrackets = true
        elseif ch == 0x5D then
            insideBrackets = false
        end
    end

    if isSpecial and startPos > endPos then
        error( "Invalid URL: Missing host" )
    elseif stateOverride and startPos == endPos and (self.username or self.password or self.port) then
        return
    end

    self.hostname = parseHostString( str, startPos, endPos, isSpecial )
end

function parsePort( self, str, startPos, endPos, defaultPort, stateOverride )
    if startPos > endPos then
        return
    end

    local port = raw_tonumber( string_sub( str, startPos, endPos ), 10 )
    if not port or (port > 2 ^ 16 - 1) or port < 0 then
        if stateOverride then return end

        error( "Invalid URL: Invalid port" )
    end

    if port ~= defaultPort then
        self.port = port
    end
end

function parseFile( self, str, startPos, endPos, base )
    self.scheme = "file"
    self.hostname = ""

    local ch = startPos <= endPos and string_byte( str, startPos )
    if ch == 0x2F or ch == 0x5C then
        return parseFileSlash( self, str, startPos + 1, endPos, base )
    elseif base and base.scheme == "file" then
        self.hostname = base.hostname

        local path = {}
        self.path = path

        local index = 1

        for key, value in raw_pairs( base.path or {} ) do
            if index == key then
                path[ index ] = value
                index = index + 1
            else
                path[ key ] = value
            end
        end

        if ch == 0x3F then
            return parseQuery( self, str, startPos + 1, endPos )
        elseif ch == 0x23 then
            self.query = base.query
            return parseFragment( self, str, startPos + 1, endPos )
        elseif ch then
            local path_length = #path
            if not startsWithWindowsDriveLetter( str, startPos, endPos ) then
                if path_length ~= 1 or not isWindowsDriveLetter( path[ 1 ] ) then
                    path[ path_length ] = nil
                end
            else
                path = nil
            end

            return parsePath( self, str, startPos, endPos, true, path )
        end
    else
        return parsePath( self, str, startPos, endPos, true )
    end
end

function parseFileSlash( self, str, startPos, endPos, base )
    local ch = string_byte( str, startPos )
    if ch == 0x2F or ch == 0x5C then
        return parseFileHost( self, str, startPos + 1, endPos )
    else
        local path = {}
        if base and base.scheme == "file" then
            self.hostname = base.hostname

            if not startsWithWindowsDriveLetter( str, startPos, endPos ) and isWindowsDriveLetter( base.path[ 1 ], false ) then
                path[ 1 ] = base.path[ 1 ]
            end
        end

        return parsePath( self, str, startPos, endPos, true, path )
    end
end

function parseFileHost( self, str, startPos, endPos, stateOverride )
    local i = startPos
    while true do
        local ch = i <= endPos and string_byte( str, i )
        if ch == 0x2F or ch == 0x5C or ch == 0x3F or ch == 0x23 or not ch then
            local hostLen = i - startPos
            if not stateOverride and hostLen == 2 and isWindowsDriveLetterCodePoints( string_byte( str, startPos ), string_byte( str, startPos + 1 ), false ) then
                parsePath( self, str, startPos, endPos, true )
            elseif hostLen == 0 then
                self.hostname = ""
                if stateOverride then
                    return
                end

                parsePathStart( self, str, i, endPos, true )
            else
                local hostname = parseHostString( str, startPos, i - 1, true )
                if hostname == "localhost" then
                    hostname = ""
                end

                self.hostname = hostname

                if stateOverride then
                    return
                end

                parsePathStart( self, str, i, endPos, true )
            end

            break
        end

        i = i + 1
    end
end

function parsePathStart( self, str, startPos, endPos, isSpecial, stateOverride )
    local ch = startPos <= endPos and string_byte( str, startPos )
    if isSpecial then
        if ch == 0x2F or ch == 0x5C then
            startPos = startPos + 1
        end

        return parsePath( self, str, startPos, endPos, isSpecial, nil, stateOverride )
    elseif not stateOverride and ch == 0x3F then
        return parseQuery( self, str, startPos + 1, endPos )
    elseif not stateOverride and ch == 0x23 then
        return parseFragment( self, str, startPos + 1, endPos )
    elseif ch then
        if ch == 0x2F then
            startPos = startPos + 1
        end

        return parsePath( self, str, startPos, endPos, isSpecial, nil, stateOverride )
    elseif stateOverride and not self.hostname then
        local path = self.path
        path[ #path + 1 ] = ""
    end
end

function parsePath( self, str, startPos, endPos, isSpecial, segments, stateOverride )
    if segments == nil then
        segments = {}
    end

    local segmentsCount = #segments
    local hasWindowsLetter = segmentsCount ~= 0 and isWindowsDriveLetter( segments[ 1 ], false )
    local segmentStart = startPos
    local i = startPos

    while true do
        local ch = i <= endPos and string_byte( str, i )
        if ch == 0x2F or (isSpecial and ch == 0x5C) or (not stateOverride and (ch == 0x3F or ch == 0x23)) or not ch then
            local segment = percentEncode( string_sub( str, segmentStart, i - 1 ), PATH_ENCODE_SET )
            local segment_length = string_len( segment )
            segmentStart = i + 1

            if isDoubleDot( segment, segment_length ) then
                if segmentsCount ~= 1 or not hasWindowsLetter then
                    segments[ segmentsCount ] = nil
                    segmentsCount = segmentsCount - 1

                    if segmentsCount == -1 then
                        segmentsCount = 0
                    end
                end

                if ch ~= 0x2F and (isSpecial and ch ~= 0x5C) then
                    segmentsCount = segmentsCount + 1
                    segments[ segmentsCount ] = ""
                end
            elseif not isSingleDot( segment, segment_length ) then
                if isSpecial == true and segmentsCount == 0 and isWindowsDriveLetter( segment, false ) then
                    segment = string_gsub( segment, "|", ":" )
                    hasWindowsLetter = true
                end

                segmentsCount = segmentsCount + 1
                segments[ segmentsCount ] = segment
            elseif ch ~= 0x2F and (isSpecial and ch ~= 0x5C) then
                segmentsCount = segmentsCount + 1
                segments[ segmentsCount ] = ""
            end

            if ch == 0x3F then
                parseQuery( self, str, i + 1, endPos )
                break
            elseif ch == 0x23 then
                parseFragment( self, str, i + 1, endPos )
                break
            elseif not ch then
                break
            end
        end

        i = i + 1
    end

    self.path = segments
end

function parseOpaquePath( self, str, startPos, endPos )
    for i = startPos, endPos, 1 do
        local ch = string_byte( str, i )
        if ch == 0x3F then
            parseQuery( self, str, i + 1, endPos )
            endPos = i - 1
            break
        elseif ch == 0x23 then
            parseFragment( self, str, i + 1, endPos )
            endPos = i - 1
            break
        end
    end

    self.path = percentEncode( string_sub( str, startPos, endPos ), C0_ENCODE_SET )
end

function parseQuery( self, str, startPos, endPos, isSpecial, stateOverride )
    for i = startPos, endPos, 1 do
        if not stateOverride and string_byte( str, i ) == 0x23 then
            parseFragment( self, str, i + 1, endPos )
            endPos = i - 1
            break
        end
    end

    self.query = percentEncode( string_sub( str, startPos, endPos ), isSpecial and SPECIAL_QUERY_ENCODE_SET or QUERY_ENCODE_SET )
end

-- This methods parses given query string to a list of name-value tuple
local function parseQueryString( str, output )
    if output == nil then output = {} end

    local pointer = 1
    local startPos = 1
    local name, value
    local containsPlus = false
    local count = 0

    while true do
        local ch = string_byte( str, pointer )
        if ch == 0x26 or not ch then
            value = string_sub( str, startPos, pointer - 1 )
            if name == nil then
                name = value
                value = nil
            end

            if containsPlus then
                value = string_gsub( name, "%+", " " )
                containsPlus = false
            end

            if name ~= "" or value then
                name = percentDecode( name, DECODE_LOOKUP_TABLE )
                value = value and percentDecode( value, DECODE_LOOKUP_TABLE ) or nil
                count = count + 1
                output[ count ] = { name, value }
            end

            name = nil
            value = nil
            startPos = pointer + 1

            if not ch then
                break
            end
        elseif ch == 0x3D then
            name = string_sub( str, startPos, pointer - 1 )
            startPos = pointer + 1
            if containsPlus then
                name = string_gsub( name, "%+", " " )
                containsPlus = false
            end
        elseif ch == 0x2B then
            containsPlus = true
        end

        pointer = pointer + 1
    end

    return output
end

function parseFragment( self, str, startPos, endPos )
    self.fragment = percentEncode( string_sub( str, startPos, endPos ), FRAGMENT_ENCODE_SET )
end

local function parse( self, str, base )
    if not isString( str ) then
        error( "Invalid URL: URL must be a string" )
    end

    if isString( base ) then
        -- yeah, we dont even need to full URL object for this
        local url = {}
        parse( url, base )
        base = url
    end

    str = string_gsub( str, "[\t\n\r]", "" )

    local startPos = 1
    local endPos = #str

    -- Trim leading and trailing whitespaces
    startPos = trimInput( str, startPos, endPos )
    endPos = trimInput( str, endPos, startPos )

    parseScheme( self, str, startPos, endPos, base )

    return self
end

local function serializeIPv6( address )
    local output = {}

    local len = 0
    local compress = 0
    local compressLen = 0
    local zeroStart = 0

    -- Find first longest sequence of zeros
    for i = 1, 8 do
        if address[ i ] == 0 then
            if zeroStart == 0 then
                zeroStart = i
            elseif i - zeroStart > compressLen then
                compress = zeroStart
                compressLen = i - zeroStart
            end
        else
            zeroStart = 0
        end
    end

    local ignore0 = false
    for i = 1, 8 do
        if ignore0 then
            if address[ i ] == 0 then
                goto _continue_0
            end

            ignore0 = false
        end

        if compress == i then
            len = len + 1
            output[ len ] = i == 1 and "::" or ":"
            ignore0 = true
            goto _continue_0
        end

        len = len + 1
        output[ len ] = string_format( "%x", address[ i ] )

        -- why format? because it returns hex without zeros (aka smallest hex value)
        if i ~= 8 then
            len = len + 1
            output[ len ] = ":"
        end

        ::_continue_0::
    end

    return table_concat( output, "", 1, len )
end

local function serializeHost( host )
    if isTable( host ) then
        return "[" .. serializeIPv6( host ) .. "]"
    elseif isNumber( host ) then
        local address = {}
        for i = 1, 4 do
            address[ 5 - i ] = string_format( "%u", host % 256 )
            host = math_floor( host / 256 )
        end

        return table_concat( address, "." )
    end

    return host
end

local function serializeQuery( query )
    if not isTable( query ) then
        return query
    end

    local output, length = {}, 0

    for i = 1, #query, 1 do
        local t = query[ i ]
        if length > 0 then
            length = length + 1
            output[ length ] = "&"
        end

        length = length + 1
        output[ length ] = t[ 1 ] and percentEncode( t[ 1 ], URLENCODED_ENCODE_SET, true ) or ""

        local value = t[ 2 ] and percentEncode( t[ 2 ], URLENCODED_ENCODE_SET, true ) or ""
        if value ~= "" then
            length = length + 1
            output[ length ] = "="

            length = length + 1
            output[ length ] = value
        end
    end

    if length == 0 then
        return ""
    else
        return table_concat( output, "", 1, length )
    end
end

--- [SHARED AND MENU]
---
--- Serializes given URLState object to full url string
--- basically same as accessing ``.href`` of URL object
---@param state dreamwork.std.URL.State
---@param excludeFragment? boolean if true, fragment will be excluded (default: false)
---@return string
local function serialize( state, excludeFragment )
    local scheme = state.scheme
    local hostname = state.hostname
    local path = state.path
    local query = state.query
    local fragment = state.fragment
    local isOpaque = isString( path )

    local output, length = {}, 0

    if scheme then
        length = length + 1
        output[ length ] = scheme

        length = length + 1
        output[ length ] = ":"
    end

    if hostname then
        length = length + 1
        output[ length ] = "//"

        local username, password = state.username, state.password
        if username or password then
            length = length + 1
            output[ length ] = username

            if password and password ~= "" then
                length = length + 1
                output[ length ] = ":"

                length = length + 1
                output[ length ] = password
            end

            length = length + 1
            output[ length ] = "@"
        end

        length = length + 1
        output[ length ] = serializeHost( hostname )

        local port = state.port
        if port then
            length = length + 1
            output[ length ] = ":"

            length = length + 1
            output[ length ] = tostring( port )
        end
    elseif path and not isOpaque and #path > 1 and path[ 1 ] == "" then
        length = length + 1
        output[ length ] = "./"
    end

    if path then
        length = length + 1
        if isOpaque then
            ---@cast path string
            output[ length ] = path
        else
            ---@cast path table
            output[ length ] = "/" .. table_concat( path, "/" )
        end
    end

    if query and #query ~= 0 then
        length = length + 1
        output[ length ] = "?"

        length = length + 1
        if isString( query ) then
            ---@cast query string
            output[ length ] = query
        else
            ---@cast query dreamwork.std.URL.SearchParams
            output[ length ] = serializeQuery( query )
        end
    end

    if fragment and excludeFragment ~= true then
        length = length + 1
        output[ length ] = "#"

        length = length + 1
        output[ length ] = fragment
    end

    return table_concat( output, "", 1, length )
end

local function getOrigin( self )
    local scheme = self.scheme
    if scheme == "ftp" or scheme == "http" or scheme == "https" or scheme == "ws" or scheme == "wss" then
        return self.scheme, self.hostname, self.port
    elseif scheme == "blob" then
        local pathURL = self.path
        if not isString( pathURL ) then
            return
        end

        local ok, url = pcall( parse, {}, pathURL )
        if ok then
            return getOrigin( url )
        end
    end
end

local function serializeOrigin( self )
    local scheme, hostname, port = getOrigin( self )
    if scheme then
        local output = scheme .. "://" .. serializeHost( hostname )
        if port then
            output = output .. ":" .. port
        end

        return output
    end
end

local function update( self )
    if self.url then
        self.url.query = self
    end
end

---@protected
function SearchParams:__init( query, url )
    self.url = url

    if isString( query ) then
        if string_byte( query, 1 ) == 0x3F then
            query = string_sub( query, 2 )
        end

        parseQueryString( query, self )
    elseif isTable( query ) then
        for i = 1, #query do
            self[ i ] = query[ i ]
        end
    end

    if self.url then
        -- yeah, URLState.query may be a string or URLSearchParams
        -- when we access URL.searchParams, it will look for URLState.query
        self.url.state.query = self
    end
end

---@protected
function SearchParams:__tostring()
    return string.format( "URLSearchParams: %p [%s]", self, serializeQuery( self ) )
end

-- SearchParams.__tostring = serializeQuery

--- [SHARED AND MENU]
---
--- Appends name and value to the end
---@param name string
---@param value string?
function SearchParams:append( name, value )
    self[ #self + 1 ] = { name, value }
    update( self )
end

--- [SHARED AND MENU]
---
--- searches all parameters with given name, and deletes them
--- if `value` is given, then searches for exactly given name AND value
---@param name string
---@param value string?
function SearchParams:delete( name, value )
    for i = #self, 1, -1 do
        local t = self[ i ]
        if t[ 1 ] == name and (not value or t[ 2 ] == value) then
            table_remove( self, i )
        end
    end

    update( self )
end

--- [SHARED AND MENU]
---
--- Finds first value associated with given name
---@param name string
---@return string | nil
function SearchParams:get( name )
    for i = 1, #self, 1 do
        local t = self[ i ]
        if t[ 1 ] == name then
            return t[ 2 ]
        end
    end
end

--- [SHARED AND MENU]
---
--- Finds all values associated with given name and returns them as list.
---@param name string
---@return table
function SearchParams:getAll( name )
    local values = {}
    for i = 1, #self, 1 do
        local t = self[ i ]
        if t[ 1 ] == name then
            values[ #values + 1 ] = t[ 2 ]
        end
    end

    return values
end

--- [SHARED AND MENU]
---
--- Returns true if parameters with given name exists and value if given.
---@param name string
---@param value string?
---@return boolean
function SearchParams:has( name, value )
    for i = 1, #self, 1 do
        local t = self[ i ]
        if t[ 1 ] == name and (not value or t[ 2 ] == value) then
            return true
        end
    end

    return false
end

--- [SHARED AND MENU]
---
--- Sets first name to a given value (or appends [name, value])
--- and deletes other parameters with the same name
---@param name string
---@param value string?
function SearchParams:set( name, value )
    for i = 1, #self, 1 do
        local t = self[ i ]
        if t[ 1 ] == name then
            -- replace first value
            t[ 2 ] = value

            -- remove all other values
            for j = #self, i + 1, -1 do
                if self[ j ][ 1 ] == name then
                    table_remove( self, j )
                end
            end

            update( self )
            return
        end
    end

    -- if name is not found, append new value
    self[ #self + 1 ] = { name, value }
    update( self )
end

--- [SHARED AND MENU]
---
--- Sorts parameters inside `URLSearchParams`.
function SearchParams:sort()
    for index = 1, #self - 1 do
        local jMin = index
        for j = index + 1, #self, 1 do
            if self[ j ][ 1 ] < self[ jMin ][ 1 ] then
                jMin = j
            end
        end

        if jMin ~= index then
            local old = self[ index ]
            self[ index ] = self[ jMin ]
            self[ jMin ] = old
        end
    end

    update( self )
end

--- [SHARED AND MENU]
---
--- returns iterator that can be used in for loops
--- e.g. `for name, value in searchParams:entries() do ... end`
---@return fun(): string | nil, string | nil
function SearchParams:iterator()
    local index = 0

    return function()
        index = index + 1

        local tbl = self[ index ]
        if tbl then
            return tbl[ 1 ], tbl[ 2 ]
        end
    end
end

--- [SHARED AND MENU]
---
--- returns iterator that can be used in for loops
---@return fun(): string | nil
function SearchParams:keys()
    local index = 0

    return function()
        index = index + 1

        local tbl = self[ index ]
        if tbl then
            return tbl[ 1 ]
        end
    end
end

--- [SHARED AND MENU]
---
--- returns iterator that can be used in for loops
---@return fun(): string | nil
function SearchParams:values()
    local index = 0

    return function()
        index = index + 1

        local tbl = self[ index ]
        if tbl then
            return tbl[ 2 ]
        end
    end
end

local STATE_FIELDS = {
    scheme = true,
    username = true,
    password = true,
    hostname = true,
    port = true,
    path = true,
    query = true,
    fragment = true
}

---@param obj dreamwork.std.URL
local function resetCache( obj )
    raw_set( obj, "_href", nil )
    raw_set( obj, "_origin", nil )
    raw_set( obj, "_host", nil )
    raw_set( obj, "_hostname", nil )
    raw_set( obj, "_pathname", nil )
    raw_set( obj, "_query", nil )
end

---@generic V: string | number
---@param obj dreamwork.std.URL
---@param key string
---@param value V
---@return V
local function cacheValue( obj, key, value )
    raw_set( obj, key, value )
    return value
end

URLClass.SearchParams = SearchParamsClass

local isURLSearchParams
do

    local debug_getmetatable = std.debug.getmetatable

    --- [SHARED AND MENU]
    ---
    --- Checks if the given value is a `URLSearchParams`.
    ---@param any any The value to check.
    ---@return boolean result Returns `true` if the value is a `URLSearchParams`, otherwise `false`.
    function isURLSearchParams( any )
        return debug_getmetatable( any ) == SearchParams
    end

    std.isURLSearchParams = isURLSearchParams

    --- [SHARED AND MENU]
    ---
    --- Checks if the given value is a `URL`.
    ---@param value any The value to check.
    ---@return boolean result Returns `true` if the value is a URL, otherwise `false`.
    function std.isURL( value )
        return debug_getmetatable( value ) == URL
    end

end

-- TODO: write missing fields

---@protected
function URL:__index( key )
    local state = raw_get( self, "state" )
    ---@cast state dreamwork.std.URL.State

    -- State fields
    if STATE_FIELDS[ key ] then
        if "hostname" == key then
            return raw_get( self, "_hostname" ) or cacheValue( self, "_hostname", serializeHost( state.hostname ) )
        elseif "query" == key then
            local cached = raw_get( self, "_query" )
            if cached ~= nil then
                return cached
            end

            local query = state.query
            if isURLSearchParams( query ) then
                return cacheValue( self, "_query", serializeQuery( query ) )
            else
                ---@cast query string
                return cacheValue( self, "_query", query )
            end
        else
            return state[ key ]
        end
    end

    -- Special fields
    if "href" == key then
        return raw_get( self, "_href" ) or cacheValue( self, "_href", serialize( state ) )
    elseif "origin" == key then
        return raw_get( self, "_origin" ) or cacheValue( self, "_origin", serializeOrigin( state ) )
    elseif "protocol" == key then
        local scheme = state.scheme
        if scheme == nil then
            return nil
        else
            scheme = scheme .. ":"
        end
    elseif "host" == key then
        local cached = raw_get( self, "_host" )
        if cached ~= nil then
            return cached
        end

        if state.hostname then
            local port = state.port
            if port == nil then
                return cacheValue( self, "_host", self.hostname )
            else
                return cacheValue( self, "_host", self.hostname .. ":" .. port )
            end
        else
            return ""
        end
    elseif "pathname" == key then
        local cached = raw_get( self, "_pathname" )
        if cached ~= nil then
            return cached
        end

        local path = state.path
        if isTable( path ) then
            ---@cast path table
            return cacheValue( self, "_pathname", "/" .. table_concat( path, "/" ) )
        else
            return path
        end
    elseif "search" == key then
        local query = self.query
        if query and query ~= "" then
            return "?" .. query
        else
            return ""
        end
    elseif "searchParams" == key then
        local query = state.query
        if isURLSearchParams( query ) then
            ---@cast query dreamwork.std.URL.SearchParams
            return query
        else
            ---@cast query string
            return SearchParamsClass( query, self )
        end
    elseif "hash" == key then
        local fragment = state.fragment
        if fragment and fragment ~= "" then
            return "#" .. fragment
        else
            return ""
        end
    end
end

---@protected
function URL:__newindex( key, value )
    local state = raw_get( self, "state" )

    -- State fields
    if STATE_FIELDS[ key ] then
        resetCache( self )

        if "username" == key then
            if not state.hostname or state.hostname == "" or state.scheme == "file" then return end

            state.username = value
        elseif "password" == key then
            if not state.hostname or state.hostname == "" or state.scheme == "file" then return end

            state.password = value
        elseif "hostname" == key then
            if isString( state.path ) then return end

            parseHost( state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[ state.scheme ], "hostname" )
        elseif "port" == key then
            if not state.hostname or state.hostname == "" or state.scheme == "file" then
                return
            end

            if not value or value == "" then
                state.port = nil
                return
            else
                value = tostring( value )
                parsePort( state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[ state.scheme ], true )
            end
        else
            state[ key ] = value
        end

        return
    end

    -- Special fields
    if "href" == key then
        resetCache( self )

        state = {}
        parse( state, value )
        raw_set( self, "state", state )
        -- elseif "origin" == key then
        -- 	return
    elseif "protocol" == key then
        resetCache( self )
        parseScheme( state, value, 1, #value, nil, true )
    elseif "host" == key then
        if isString( state.path ) then return end

        resetCache( self )
        parseHost( state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[ state.scheme ], "host" )
    elseif "pathname" == key then
        if isString( state.path ) then return end

        resetCache( self )

        state.path = {}
        parsePathStart( state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[ state.scheme ], true )
    elseif "search" == key then
        resetCache( self )
        parseQuery( state, value, (string_byte( value, 1 ) == 0x3F) and 2 or 1, #value, state.scheme and SPECIAL_SCHEMAS[ state.scheme ], true )
    elseif "searchParams" == key then
        return
    elseif "hash" == key then
        if not value or value == "" then
            state.fragment = nil
            return
        end

        resetCache( self )
        parseFragment( state, value, (string_byte( value, 1 ) == 0x23) and 2 or 1, #value )
    else
        raw_set( self, key, value )
    end
end

---@return string
---@protected
function URL:__tostring()
    return string.format( "URL: %p [%s]", self, self.href )
end

---@protected
function URL:__init( str, base )
    local state = {}
    self.state = state
    parse( state, str, base )
end

--- [SHARED AND MENU]
---
--- Parses given dreamwork.std.URL string but returns URLState object instead
---@see dreamwork.std.URL
---@param url string
---@param base string | dreamwork.std.URL | nil
---@return dreamwork.std.URL.State
function URLClass.parse( url, base )
    return parse( {}, url, base )
end

--- [SHARED AND MENU]
---
--- Returns true if given url can be parsed with URLState
--- otherwise returns false and error string
---@param url string
---@param base string | dreamwork.std.URL | nil
---@return boolean
---@return dreamwork.std.URL.State | string
function URLClass.canParse( url, base )
    return pcall( URLClass.parse, url, base )
end

URLClass.serialize = serialize
-- URLClass.deserialize = parse

--- [SHARED AND MENU]
---
--- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURI
---@param uri string
---@return string
function URLClass.encodeURI( uri )
    return percentEncode( uri, URI_ENCODE_SET )
end

--- [SHARED AND MENU]
---
--- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/decodeURI
---@param uri string
---@return string
function URLClass.decodeURI( uri )
    return percentDecode( uri, URI_DECODE_SET )
end

--- [SHARED AND MENU]
---
--- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent
---@param uri string
---@return string
function URLClass.encodeURIComponent( uri )
    return percentEncode( uri, COMPONENT_ENCODE_SET, true )
end

--- [SHARED AND MENU]
---
--- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/decodeURIComponent
---@param uri string
---@return string
function URLClass.decodeURIComponent( uri )
    return percentDecode( uri, DECODE_LOOKUP_TABLE )
end

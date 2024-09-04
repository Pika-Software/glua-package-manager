local _G = _G

--[[

    Lua Bint - (c) 2020 Eduardo Bart (MIT)
    https://github.com/edubart/lua-bint

    Rewritten by Unknown Developer
        specially for
            gLua Package Manager

]]

local environment = _G.gpm.environment
local string = environment.string
local table = environment.table
local class = environment.class
local math = environment.math

local band, bnot, bor, bxor, lshift, rshift
do
    local bit = _G.bit
    band, bnot, bor, bxor, lshift, rshift = bit.band, bit.bnot, bit.bor, bit.bxor, bit.lshift, bit.rshift
end

local getmetatable = _G.getmetatable
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber
local isstring = _G.isstring
local isnumber = _G.isnumber
local assert = _G.assert

local struct_Read, struct_Write
do
    local struct = environment.struct
    struct_Read, struct_Write = struct.Read, struct.Write
end

local math_abs = math.abs
local math_type = math.type
local math_floor = math.floor
local math_ceil = math.ceil
local math_modf = math.modf
local math_max = math.max
local math_min = math.min
local math_fdiv = math.fdiv

local math_mininteger = math.mininteger
local math_maxinteger = math.maxinteger

local string_reverse = string.reverse
local string_format = string.format
local string_match = string.match
local string_lower = string.lower
local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local string_rep = string.rep
local string_len = string.len

local table_insert = table.insert
local table_concat = table.concat

-- Returns number of bits of the internal lua integer type.
local function luainteger_bitsize()
    local n, i = -1, 0
    repeat
        n, i = rshift( n, 16 ), i + 16
    until n == 0

    return i
end

local memo = {}

--- Create a new bint module representing integers of the desired bit size.
-- This is the returned function when `require 'bint'` is called.
-- @function newmodule
-- @param bits Number of bits for the integer representation, must be multiple of wordbits and
-- at least 64.
-- @param[opt] wordbits Number of the bits for the internal word,
-- defaults to half of Lua's integer size.
function environment.util.Bint( bits, wordbits )
    local intbits = luainteger_bitsize()
    bits = bits or 256
    wordbits = wordbits or math_fdiv( intbits, 2 )

    -- Memoize bint modules
    local memoindex = bits * 64 + wordbits
    if memo[ memoindex ] then
        return memo[ memoindex ]
    end

    -- Validate
    assert( ( bits % wordbits ) == 0, 'bitsize is not multiple of word bitsize' )
    assert( 2 * wordbits <= intbits, 'word bitsize must be half of the lua integer bitsize' )
    assert( bits >= 64, 'bitsize must be >= 64' )
    assert( wordbits >= 8, 'wordbits must be at least 8' )
    assert( ( bits % 8 ) == 0, 'bitsize must be multiple of 8' )

    local bint_band, bint_bor

    local static = {}
    local internal = {}
    internal.__index = internal

    --- Number of bits representing a bint instance.
    internal.Bits = bits

    -- Constants used internally
    local BINT_BITS = bits
    local BINT_BYTES = math_fdiv( bits, 8 )
    local BINT_WORDBITS = wordbits
    local BINT_SIZE = math_fdiv( BINT_BITS, BINT_WORDBITS )
    local BINT_WORDMAX = lshift( 1, BINT_WORDBITS ) - 1
    local BINT_WORDMSB = lshift( 1, BINT_WORDBITS - 1 )
    local BINT_LEPACKFMT = '<' .. string_rep( 'I' .. math_fdiv( wordbits, 8 ), BINT_SIZE )
    local BINT_MATHMININTEGER, BINT_MATHMAXINTEGER
    local BINT_MININTEGER

    -- Base letters to use in internal.ToBase
    local BASE_LETTERS = { [ 0 ] = '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' }

    --- Create a new bint with 0 value.
    local bint_zero = function()
        local x = setmetatable( {}, internal )
        for i = 1, BINT_SIZE do
            x[ i ] = 0
        end

        return x
    end

    internal.zero = bint_zero

    --- Create a new bint with 1 value.
    local bint_one = function()
        local x = setmetatable( { [ 1 ] = 1 }, internal )
        for i = 2, BINT_SIZE do
            x[ i ] = 0
        end

        return x
    end

    static.One = bint_one

    -- Convert a value to a lua integer without losing precision.
    local function tointeger( x )
        x = tonumber( x )

        local ty = math_type( x )
        if ty == 'float' then
            local floorx = math_floor( x )
            if floorx == x then
                x = floorx
                ty = math_type( x )
            end
        end

        if ty == 'integer' then
            return x
        end
    end

    --- Create a bint from an unsigned integer.
    -- Treats signed integers as an unsigned integer.
    -- @param x A value to initialize from convertible to a lua integer.
    -- @return A new bint or nil in case the input cannot be represented by an integer.
    -- @see internal.frominteger
    local bint_fromuinteger = function( x )
        x = tointeger( x )
        if x then
            if x == 1 then
                return bint_one()
            elseif x == 0 then
                return bint_zero()
            end

            local n = setmetatable( {}, internal )
            for i = 1, BINT_SIZE do
                n[ i ] = band( x, BINT_WORDMAX )
                x = rshift( x, BINT_WORDBITS )
            end

            return n
        end
    end

    static.FromUInteger = bint_fromuinteger

    --- Create a bint from a signed integer.
    -- @param x A value to initialize from convertible to a lua integer.
    -- @return A new bint or nil in case the input cannot be represented by an integer.
    -- @see internal.fromuinteger
    local bint_frominteger = function( x )
        x = tointeger( x )
        if x then
            if x == 1 then
                return bint_one()
            elseif x == 0 then
                return bint_zero()
            end

            local neg = false
            if x < 0 then
                x = math_abs( x )
                neg = true
            end

            local n = setmetatable( {}, internal )
            for i = 1, BINT_SIZE do
                n[ i ] = band( x, BINT_WORDMAX )
                x = rshift( x, BINT_WORDBITS )
            end

            if neg then
                n:_unm()
            end

            return n
        end
    end

    static.FromInteger = bint_frominteger

    local basesteps = {}

    -- Compute the read step for frombase function
    local function getbasestep( base )
        local step = basesteps[ base ]
        if step then
            return step
        end

        step = 0

        local dmax = 1
        local limit = math_fdiv( math_maxinteger, base )

        repeat
            step = step + 1
            dmax = dmax * base
        until dmax >= limit

        basesteps[ base ] = step
        return step
    end

    -- Compute power with lua integers.
    local function ipow( y, x, n )
        if n == 1 then
            return y * x
        elseif band( n, 1 ) == 0 then
            return ipow( y, x * x, math_fdiv( n, 2 ) ) -- even
        end

        return ipow( x * y, x * x, math_fdiv( n - 1, 2 ) ) -- odd
    end

    --- Create a bint from a string of the desired base.
    -- @param s The string to be converted from,
    -- must have only alphanumeric and '+-' characters.
    -- @param[opt] base Base that the number is represented, defaults to 10.
    -- Must be at least 2 and at most 36.
    -- @return A new bint or nil in case the conversion failed.
    local bint_frombase = function( s, base )
        if not isstring( s ) then
            return nil
        end

        base = base or 10

        -- number base is too large
        if not ( base >= 2 and base <= 36 ) then
            return nil
        end

        local step = getbasestep( base )
        if string_len( s ) < step then
            -- string is small, use tonumber (faster)
            return bint_frominteger( tonumber( s, base ) )
        end

        local sign, int = string_match( string_lower( s ), '^([+-]?)(%w+)$' )
        if not ( sign and int ) then
            -- invalid integer string representation
            return nil
        end

        local n = bint_zero()
        for i = 1, string_len( int ), step do
            local part = string_sub( int, i, i + step - 1 )
            local d = tonumber( part, base )
            if not d then
                -- invalid integer string representation
                return nil
            end

            if i > 1 then
                n = n * ipow( 1, base, string_len( part ) )
            end

            if d ~= 0 then
                n:_add( d )
            end
        end

        if sign == '-' then
            n:_unm()
        end

        return n
    end

    static.FromBase = bint_frombase

    --- Create a new bint from a string.
    -- The string can by a decimal number, binary number prefixed with '0b' or hexadecimal number prefixed with '0x'.
    -- @param s A string convertible to a bint.
    -- @return A new bint or nil in case the conversion failed.
    -- @see internal.FromBase
    local bint_fromstring = function( s )
        if not isstring( s ) then
            return nil
        end

        if string_find( s, '^[+-]?[0-9]+$', 1, false ) then -- decimal
            return bint_frombase( s, 10 )
        elseif string_find( s, '^[+-]?0[xX][0-9a-fA-F]+$', 1, false ) then -- hex
            return bint_frombase( string_gsub( s, '0[xX]', '', 1 ), 16 )
        elseif string_find( s, '^[+-]?0[bB][01]+$', 1, false ) then -- binary
            return bint_frombase( string_gsub( s, '0[bB]', '', 1 ), 2 )
        end
    end

    static.FromString = bint_fromstring

    --- Create a new bint from a buffer of little-endian bytes.
    -- @param buffer Buffer of bytes, extra bytes are trimmed from the right, missing bytes are padded to the right.
    -- @raise An assert is thrown in case buffer is not an string.
    -- @return A bint.
    function static.FromLittleEndian( buffer )
        assert( isstring( buffer ), 'buffer is not a string' )

        if string_len( buffer ) > BINT_BYTES then -- trim extra bytes from the right
            buffer = string_sub( buffer, 1, BINT_BYTES )
        elseif string_len( buffer ) < BINT_BYTES then -- add missing bytes to the right
            buffer = buffer .. string_rep( '\x00', BINT_BYTES - string_len( buffer ) )
        end

        return setmetatable( struct_Read( BINT_LEPACKFMT, buffer ), internal )
    end

    --- Create a new bint from a buffer of big-endian bytes.
    -- @param buffer Buffer of bytes, extra bytes are trimmed from the left, missing bytes are padded to the left.
    -- @raise An assert is thrown in case buffer is not an string.
    -- @return A bint.
    function static.FromBigEndian( buffer )
        assert( isstring( buffer ), 'buffer is not a string' )

        if string_len( buffer ) > BINT_BYTES then -- trim extra bytes from the left
            buffer = string_sub( buffer, -BINT_BYTES, string_len( buffer ) )
        elseif string_len( buffer ) < BINT_BYTES then -- add missing bytes to the left
            buffer = string_rep( '\x00', BINT_BYTES - string_len( buffer ) ) .. buffer
        end

        return setmetatable( struct_Read( BINT_LEPACKFMT, string_reverse( buffer ) ), internal )
    end

    --- Create a new bint from a value.
    -- @param x A value convertible to a bint (string, number or another bint).
    -- @return A new bint, guaranteed to be a new reference in case needed.
    -- @raise An assert is thrown in case x is not convertible to a bint.
    -- @see static.ToBint
    -- @see static.Parse
    local bint_new = function( x )
        -- return a clone
        if getmetatable( x ) == internal then
            local n = setmetatable( {}, internal )
            for i = 1, BINT_SIZE do
                n[ i ] = x[ i ]
            end

            return n
        end

        if isnumber( x ) then
            return bint_frominteger( x )
        end

        if isstring( x ) then
            return bint_fromstring( x )
        end

        assert( x, 'value cannot be represented by a bint' )
        return x
    end

    internal.new = function( self, x )
        if getmetatable( x ) == internal then
            for i = 1, BINT_SIZE do
                self[ i ] = x[ i ]
            end

            return nil
        end

        return true, bint_new( x )
    end

    --- Convert a value to a bint if possible.
    -- @param x A value to be converted (string, number or another bint).
    -- @param[opt] clone A boolean that tells if a new bint reference should be returned.
    -- Defaults to false.
    -- @return A bint or nil in case the conversion failed.
    -- @see internal.new
    -- @see internal.Parse
    local tobint = function( x, clone )
        if getmetatable( x ) == internal then
            if not clone then
                return x
            end

            -- return a clone
            local n = setmetatable( {}, internal )
            for i = 1, BINT_SIZE do
                n[ i ] = x[ i ]
            end

            return n
        end

        if isnumber( x ) then
            return bint_frominteger( x )
        end

        if isstring( x ) then
            return bint_fromstring( x )
        end

        return nil
    end

    static.ToBint = tobint

    --- Convert a value to a bint if possible otherwise to a lua number.
    -- Useful to prepare values that you are unsure if it's going to be an integer or float.
    -- @param x A value to be converted (string, number or another bint).
    -- @param[opt] clone A boolean that tells if a new bint reference should be returned.
    -- Defaults to false.
    -- @return A bint or a lua number or nil in case the conversion failed.
    -- @see internal.new
    -- @see internal.tobint
    local bint_parse = function( x, clone )
        local i = tobint( x, clone )
        if i then
            return i
        end

        return tonumber( x, 10 )
    end

    static.Parse = bint_parse

    --- Convert a bint to an unsigned integer.
    -- Note that large unsigned integers may be represented as negatives in lua integers.
    -- Note that lua cannot represent values larger than 64 bits,
    -- in that case integer values wrap around.
    -- @param x A bint or a number to be converted into an unsigned integer.
    -- @return An integer or nil in case the input cannot be represented by an integer.
    -- @see internal.ToInteger
    function internal.ToUInteger( x )
        if getmetatable( x ) == internal then
            local n = 0
            for i = 1, BINT_SIZE do
                n = bor( n, lshift( x[ i ], BINT_WORDBITS * ( i - 1 ) ) )
            end

            return n
        end

        return tointeger( x )
    end

    --- Convert a bint to a signed integer.
    -- It works by taking absolute values then applying the sign bit in case needed.
    -- Note that lua cannot represent values larger than 64 bits,
    -- in that case integer values wrap around.
    -- @param x A bint or value to be converted into an unsigned integer.
    -- @return An integer or nil in case the input cannot be represented by an integer.
    -- @see internal.ToUInteger
    local bint_tointeger = function( x )
        if getmetatable( x ) == internal then
            local neg = x:IsNegative()
            if neg then
                x = -x
            end

            local n = 0
            for i = 1, BINT_SIZE do
                n = bor( n, lshift( x[ i ], BINT_WORDBITS * ( i - 1 ) ) )
            end

            if neg then
                n = -n
            end

            return n
        end

        return tointeger( x )
    end

    internal.ToInteger = bint_tointeger

    local function bint_assert_tointeger( x )
        x = bint_tointeger( x )
        if not x then
            error( 'value has no integer representation', 2 )
        end

        return x
    end

    --- Convert a bint to a lua float in case integer would wrap around or lua integer otherwise.
    -- Different from @{internal.ToInteger} the operation does not wrap around integers,
    -- but digits precision are lost in the process of converting to a float.
    -- @param x A bint or value to be converted into a lua number.
    -- @return A lua number or nil in case the input cannot be represented by a number.
    -- @see internal.ToInteger
    local bint_tonumber = function( x )
        if getmetatable( x ) == internal then
            if x <= BINT_MATHMAXINTEGER and x >= BINT_MATHMININTEGER then
                return x:ToInteger()
            end

            return tonumber( tostring( x ), 10 )
        end

        return tonumber( x, 10 )
    end

    internal.tonumber = bint_tonumber

    --- Convert a bint to a string in the desired base.
    -- @param x The bint to be converted from.
    -- @param[opt] base Base to be represented, defaults to 10.
    -- Must be at least 2 and at most 36.
    -- @param[opt] unsigned Whether to output as an unsigned integer.
    -- Defaults to false for base 10 and true for others.
    -- When unsigned is false the symbol '-' is prepended in negative values.
    -- @return A string representing the input.
    -- @raise An assert is thrown in case the base is invalid.
    function internal.ToBase( x, base, unsigned )
        x = tobint( x )
        if not x then
            -- x is a fractional float or something else
            return nil
        end

        base = base or 10

        if not ( base >= 2 and base <= 36 ) then
            -- number base is too large
            return nil
        end

        if unsigned == nil then
            unsigned = base ~= 10
        end

        local isxneg = x:IsNegative()
        if ( ( base == 10 and not unsigned ) or ( base == 16 and unsigned and not isxneg ) ) and ( x <= BINT_MATHMAXINTEGER and x >= BINT_MATHMININTEGER ) then
            -- integer is small, use tostring or string.format (faster)
            local n = x:ToInteger()
            if base == 10 then
                return tostring( n )
            elseif unsigned then
                return string_format( '%x', n )
            end
        end

        local ss = {}
        local neg = not unsigned and isxneg
        x = neg and x:abs() or bint_new( x )

        local xiszero = x:IsZero()
        if xiszero then
            return '0'
        end

        -- calculate basepow
        local step = 0
        local basepow = 1
        local limit = math_fdiv( BINT_WORDMSB - 1, base )

        repeat
            step = step + 1
            basepow = basepow * base
        until basepow >= limit

        -- serialize base digits
        local size = BINT_SIZE
        local xd, carry, d

        repeat
            -- single word division
            carry = 0
            xiszero = true
            for i = size, 1, -1 do
                carry = bor( carry, x[ i ] )
                d, xd = math_fdiv( carry, basepow ), carry % basepow
                if xiszero and d ~= 0 then
                    size = i
                    xiszero = false
                end

                x[ i ] = d
                carry = lshift( xd, BINT_WORDBITS )
            end

            -- digit division
            for _ = 1, step do
                xd, d = math_fdiv( xd, base ), xd % base
                if xiszero and xd == 0 and d == 0 then
                    -- stop on leading zeros
                    break
                end

                table_insert( ss, 1, BASE_LETTERS[ d ] )
            end
        until xiszero

        if neg then
            table_insert( ss, 1, '-' )
        end

        return table_concat( ss )
    end

    local function bint_assert_convert( x )
        return assert( tobint( x ), 'value has not integer representation' )
    end

    --- Convert a bint to a buffer of little-endian bytes.
    -- @param x A bint or lua integer.
    -- @param[opt] trim If true, zero bytes on the right are trimmed.
    -- @return A buffer of bytes representing the input.
    -- @raise Asserts in case input is not convertible to an integer.
    function internal.ToLittleEndian( x, trim )
        local s = struct_Write( BINT_LEPACKFMT, bint_assert_convert( x ), nil )
        if trim then
            s = string_gsub( s, '\x00+$', '' )
            if s == '' then
                s = '\x00'
            end
        end

        return s
    end

    --- Convert a bint to a buffer of big-endian bytes.
    -- @param x A bint or lua integer.
    -- @param[opt] trim If true, zero bytes on the left are trimmed.
    -- @return A buffer of bytes representing the input.
    -- @raise Asserts in case input is not convertible to an integer.
    function internal.ToBigEndian( x, trim )
        local s = string_reverse( struct_Write( BINT_LEPACKFMT, bint_assert_convert( x ), nil ) )
        if trim then
            s = string_gsub( s, '^\x00+', '' )
            if s == '' then
                s = '\x00'
            end
        end

        return s
    end

    --- Check if a number is 0 considering bints.
    -- @param x A bint or a lua number.
    function internal.IsZero( x )
        if getmetatable( x ) == internal then
            for i = 1, BINT_SIZE do
                if x[ i ] ~= 0 then
                    return false
                end
            end

            return true
        end

        return x == 0
    end

    --- Check if a number is 1 considering bints.
    -- @param x A bint or a lua number.
    function internal.IsOne( x )
        if getmetatable( x ) == internal then
            if x[ 1 ] ~= 1 then
                return false
            end

            for i = 2, BINT_SIZE do
                if x[ i ] ~= 0 then
                    return false
                end
            end

            return true
        end

        return x == 1
    end

    --- Check if a number is -1 considering bints.
    -- @param x A bint or a lua number.
    local bint_isminusone = function( x )
        if getmetatable( x ) == internal then
            for i = 1, BINT_SIZE do
                if x[ i ] ~= BINT_WORDMAX then
                    return false
                end
            end

            return true
        end

        return x == -1
    end

    internal.IsMinusOne = bint_isminusone

    --- Check if the input is a bint.
    -- @param x Any lua value.
    function static.IsBint( x )
        return getmetatable( x ) == internal
    end

    --- Check if the input is a lua integer or a bint.
    -- @param x Any lua value.
    function static.IsIntegral( x )
        return getmetatable( x ) == internal or math_type( x ) == 'integer'
    end

    --- Check if the input is a bint or a lua number.
    -- @param x Any lua value.
    function static.IsNumeric( x )
        return getmetatable( x ) == internal or isnumber( x )
    end

    --- Get the number type of the input (bint, integer or float).
    -- @param x Any lua value.
    -- @return Returns "bint" for bints, "integer" for lua integers,
    -- "float" from lua floats or nil otherwise.
    function internal.type( x )
        if getmetatable( x ) == internal then
            return 'bint'
        end

        return math_type( x )
    end

    --- Check if a number is negative considering bints.
    -- Zero is guaranteed to never be negative for bints.
    -- @param x A bint or a lua number.
    local bint_isneg = function( x )
        if getmetatable( x ) == internal then
            return band( x[ BINT_SIZE ], BINT_WORDMSB ) ~= 0
        end

        return x < 0
    end

    internal.IsNegative = bint_isneg

    --- Check if a number is positive considering bints.
    -- @param x A bint or a lua number.
    function internal.IsPositive( x )
        if getmetatable( x ) == internal then
            return not x:IsNegative() and not x:IsZero()
        end

        return x > 0
    end

    --- Check if a number is even considering bints.
    -- @param x A bint or a lua number.
    function internal.IsEven( x )
        if getmetatable( x ) == internal then
            return bint_band( x[ 1 ], 1 ) == 0
        end

        return math_abs( x ) % 2 == 0
    end

    --- Check if a number is odd considering bints.
    -- @param x A bint or a lua number.
    function internal.IsOdd( x )
        if getmetatable( x ) == internal then
            return bint_band( x[ 1 ], 1 ) == 1
        end

        return math_abs( x ) % 2 == 1
    end

    --- Create a new bint with the maximum possible integer value.
    function static.MaxInteger()
        local x = setmetatable( {}, internal )
        for i = 1, BINT_SIZE - 1 do
            x[ i ] = BINT_WORDMAX
        end

        x[ BINT_SIZE ] = bxor( BINT_WORDMAX, BINT_WORDMSB )
        return x
    end

    --- Create a new bint with the minimum possible integer value.
    function static.MinInteger()
        local x = setmetatable( {}, internal )
        for i = 1, BINT_SIZE - 1 do
            x[ i ] = 0
        end

        x[ BINT_SIZE ] = BINT_WORDMSB
        return x
    end

    --- Bitwise left shift a bint in one bit (in-place).
    function internal:_shlone()
        local wordbitsm1 = BINT_WORDBITS - 1
        for i = BINT_SIZE, 2, -1 do
            self[ i ] = band( bor( lshift( self[ i ], 1 ), rshift( self[ i - 1 ], wordbitsm1 ) ), BINT_WORDMAX )
        end

        self[ 1 ] = band( lshift( self[ 1 ], 1 ), BINT_WORDMAX )
        return self
    end

    --- Bitwise right shift a bint in one bit (in-place).
    function internal:_shrone()
        local wordbitsm1 = BINT_WORDBITS - 1
        for i = 1, BINT_SIZE - 1 do
            self[ i ] = band( bor( rshift( self[ i ], 1 ), lshift( self[ i + 1 ], wordbitsm1 ) ), BINT_WORDMAX )
        end

        self[ BINT_SIZE ] = rshift( self[ BINT_SIZE ], 1 )
        return self
    end

    -- Bitwise left shift words of a bint (in-place). Used only internally.
    function internal:_shlwords( n )
        for i = BINT_SIZE, n + 1, -1 do
            self[ i ] = self[ i - n ]
        end

        for i = 1, n do
            self[ i ] = 0
        end

        return self
    end

    -- Bitwise right shift words of a bint (in-place). Used only internally.
    function internal:_shrwords( n )
        if n < BINT_SIZE then
            for i = 1, BINT_SIZE - n do
                self[ i ] = self[ i + n ]
            end

            for i = BINT_SIZE - n + 1, BINT_SIZE do
                self[ i ] = 0
            end
        else
            for i = 1, BINT_SIZE do
                self[ i ] = 0
            end
        end

        return self
    end

    --- Increment a bint by one (in-place).
    function internal:_inc()
        for i = 1, BINT_SIZE do
            local tmp = self[ i ]

            local v = band( tmp + 1, BINT_WORDMAX )
            self[ i ] = v

            if v > tmp then
                break
            end
        end

        return self
    end

    --- Increment a number by one considering bints.
    -- @param x A bint or a lua number to increment.
    function internal.increment( x )
        local ix = tobint( x, true )
        if ix then
            return ix:_inc()
        end

        return x + 1
    end

    --- Decrement a bint by one (in-place).
    function internal:_dec()
        for i = 1, BINT_SIZE do
            local tmp = self[ i ]

            local v = band( tmp - 1, BINT_WORDMAX )
            self[ i ] = v

            if v <= tmp then
                break
            end
        end

        return self
    end

    --- Decrement a number by one considering bints.
    -- @param x A bint or a lua number to decrement.
    function internal.decrement( x )
        local ix = tobint( x, true )
        if ix then
            return ix:_dec()
        end

        return x - 1
    end

    --- Assign a bint to a new value (in-place).
    -- @param y A value to be copied from.
    -- @raise Asserts in case inputs are not convertible to integers.
    function internal:_assign( y )
        y = bint_assert_convert( y )

        for i = 1, BINT_SIZE do
            self[ i ] = y[ i ]
        end

        return self
    end

    --- Take absolute of a bint (in-place).
    function internal:_abs()
        if self:IsNegative() then
            self:_unm()
        end

        return self
    end

    --- Take absolute of a number considering bints.
    -- @param x A bint or a lua number to take the absolute.
    local bint_abs = function( x )
        local ix = tobint( x, true )
        if ix then
            return ix:_abs()
        end

        return math_abs( x )
    end

    internal.abs = bint_abs

    --- Take the floor of a number considering bints.
    -- @param x A bint or a lua number to perform the floor operation.
    function internal.floor( x )
        if getmetatable( x ) == internal then
            return bint_new( x )
        end

        return bint_new( math_floor( tonumber( x, 10 ) ) )
    end

    --- Take ceil of a number considering bints.
    -- @param x A bint or a lua number to perform the ceil operation.
    function internal.ceil( x )
        if getmetatable( x ) == internal then
            return bint_new( x )
        end

        return bint_new( math_ceil( tonumber( x ) ) )
    end

    --- Wrap around bits of an integer (discarding left bits) considering bints.
    -- @param x A bint or a lua integer.
    -- @param y Number of right bits to preserve.
    function internal.bwrap( x, y )
        x = bint_assert_convert( x )

        if y <= 0 then
            return bint_zero()
        elseif y < BINT_BITS then

            return bint_band( x, bint_one():__shl( y ) ):_dec()
        end

        return bint_new( x )
    end

    --- Rotate left integer x by y bits considering bints.
    -- @param x A bint or a lua integer.
    -- @param y Number of bits to rotate.
    function internal.brol( x, y )
        x, y = bint_assert_convert( x ), bint_assert_tointeger( y )

        if y > 0 then
            return bint_bor( x:__shl( y ), x:__shr( BINT_BITS - y ) )
        elseif y < 0 then
            if y ~= math_mininteger then
                return x:bror( -y )
            else
                x:bror( -( y + 1 ) )
                x:bror( 1 )
            end
        end

        return x
    end

    --- Rotate right integer x by y bits considering bints.
    -- @param x A bint or a lua integer.
    -- @param y Number of bits to rotate.
    function internal.bror( x, y )
        x, y = bint_assert_convert( x ), bint_assert_tointeger( y )

        if y > 0 then
            return bint_bor( x:__shr( y ), x:__shl( BINT_BITS - y ) )
        elseif y < 0 then
            if y ~= math_mininteger then
                return x:brol( -y )
            else
                x:brol( -( y + 1 ) )
                x:brol( 1 )
            end
        end

        return x
    end

    --- Truncate a number to a bint.
    -- Floats numbers are truncated, that is, the fractional port is discarded.
    -- @param x A number to truncate.
    -- @return A new bint or nil in case the input does not fit in a bint or is not a number.
    function internal.trunc( x )
        if getmetatable( x ) == internal then
            return bint_new( x )
        end

        x = tonumber( x, 10 )
        if x then
            if math_type( x ) == 'float' then
                -- truncate to integer
                x = math_modf( x )
            end

            return bint_frominteger( x )
        end

        return nil
    end

    --- Take maximum between two numbers considering bints.
    -- @param x A bint or lua number to compare.
    -- @param y A bint or lua number to compare.
    -- @return A bint or a lua number. Guarantees to return a new bint for integer values.
    local bint_max = function( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            return bint_new( ix > iy and ix or iy )
        end

        return bint_parse( math_max( x, y ) )
    end

    internal.max = bint_max

    --- Take minimum between two numbers considering bints.
    -- @param x A bint or lua number to compare.
    -- @param y A bint or lua number to compare.
    -- @return A bint or a lua number. Guarantees to return a new bint for integer values.
    local bint_min = function( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            return bint_new( ix < iy and ix or iy )
        end

        return bint_parse( math_min( x, y ) )
    end

    internal.min = bint_min

    -- Take minimum and maximum between two numbers considering bints.
    -- @param x A bint or lua number to compare.
    -- @param min A bint or lua number to compare.
    -- @param max A bint or lua number to compare.
    -- @return A bint or a lua number. Guarantees to return a new bint for integer values.
    function internal.clamp( x, min, max )
        return bint_max( bint_min( x, max ), min )
    end

    --- Add an integer to a bint (in-place).
    -- @param y An integer to be added.
    -- @raise Asserts in case inputs are not convertible to integers.
    function internal:_add( y )
        y = bint_assert_convert( y )

        local carry = 0
        for i = 1, BINT_SIZE do
            local tmp = self[ i ] + y[ i ] + carry
            carry = rshift( tmp, BINT_WORDBITS )
            self[ i ] = band( tmp, BINT_WORDMAX )
        end

        return self
    end

    --- Add two numbers considering bints.
    -- @param x A bint or a lua number to be added.
    -- @param y A bint or a lua number to be added.
    function internal.__add( x, y )
        local ix, iy = tobint( x ), tobint( y )

        if ix and iy then
            local z, carry = setmetatable( {}, internal ), 0
            for i = 1, BINT_SIZE do
                local tmp = ix[ i ] + iy[ i ] + carry
                carry = rshift( tmp, BINT_WORDBITS )
                z[ i ] = band( tmp, BINT_WORDMAX )
            end

            return z
        end

        return bint_tonumber( x ) + bint_tonumber( y )
    end

    --- Subtract an integer from a bint (in-place).
    -- @param y An integer to subtract.
    -- @raise Asserts in case inputs are not convertible to integers.
    function internal:_sub( y )
        y = bint_assert_convert( y )

        local borrow = 0
        local wordmaxp1 = BINT_WORDMAX + 1

        for i = 1, BINT_SIZE do
            local res = self[ i ] + wordmaxp1 - y[ i ] - borrow
            self[ i ] = band( res, BINT_WORDMAX )
            borrow = bxor( rshift( res, BINT_WORDBITS ), 1 )
        end

        return self
    end

    --- Subtract two numbers considering bints.
    -- @param x A bint or a lua number to be subtracted from.
    -- @param y A bint or a lua number to subtract.
    function internal.__sub( x, y )
        local ix, iy = tobint( x ), tobint( y )

        if ix and iy then
            local wordmaxp1, borrow = BINT_WORDMAX + 1, 0
            local z = setmetatable( {}, internal )

            for i = 1, BINT_SIZE do
                local res = ix[ i ] + wordmaxp1 - iy[ i ] - borrow
                z[ i ] = band( res, BINT_WORDMAX )
                borrow = bxor( rshift( res, BINT_WORDBITS ), 1 )
            end

            return z
        end

        return bint_tonumber( x ) - bint_tonumber( y )
    end

    --- Multiply two numbers considering bints.
    -- @param x A bint or a lua number to multiply.
    -- @param y A bint or a lua number to multiply.
    function internal.__mul( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            local sizep1 = BINT_SIZE + 1
            local z = bint_zero()
            local s = sizep1
            local e = 0

            for i = 1, BINT_SIZE do
                if ix[ i ] ~= 0 or iy[ i ] ~= 0 then
                    e = math_max( e, i )
                    s = math_min( s, i )
                end
            end

            for i = s, e do
                for j = s, math_min( sizep1 - i, e ) do
                    local a = ix[ i ] * iy[ j ]
                    if a ~= 0 then
                        local carry = 0
                        for k = i + j - 1, BINT_SIZE do
                            local tmp = z[ k ] + band( a, BINT_WORDMAX ) + carry
                            carry = rshift( tmp, BINT_WORDBITS )
                            z[ k ] = band( tmp, BINT_WORDMAX )
                            a = rshift( a, BINT_WORDBITS )
                        end
                    end
                end
            end

            return z
        end

        return bint_tonumber( x ) * bint_tonumber( y )
    end

    --- Check if bints are equal.
    -- @param x A bint to compare.
    -- @param y A bint to compare.
    function internal.__eq( x, y )
        for i = 1, BINT_SIZE do
            if x[ i ] ~= y[ i ] then
                return false
            end
        end

        return true
    end

    --- Check if numbers are equal considering bints.
    -- @param x A bint or lua number to compare.
    -- @param y A bint or lua number to compare.
    local bint_eq = function( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            return ix == iy
        end

        return x == y
    end

    internal.eq = bint_eq

    local function findleftbit( x )
        for i = BINT_SIZE, 1, -1 do
            local v = x[ i ]
            if v ~= 0 then
                local j = 0

                repeat
                    v = rshift( v, 1 )
                    j = j + 1
                until v == 0

                return ( i - 1 ) * BINT_WORDBITS + j - 1, i
            end
        end
    end

    -- Single word division modulus
    local function sudivmod( nume, deno )
        local carry = 0
        local rema

        for i = BINT_SIZE, 1, -1 do
            carry = bor( carry, nume[ i ] )
            nume[ i ] = math_fdiv( carry, deno )
            rema = carry % deno
            carry = lshift( rema, BINT_WORDBITS )
        end

        return rema
    end

    --- Perform unsigned division and modulo operation between two integers considering bints.
    -- This is effectively the same of @{internal.udiv} and @{internal.umod}.
    -- @param x The numerator, must be a bint or a lua integer.
    -- @param y The denominator, must be a bint or a lua integer.
    -- @return The quotient following the remainder, both bints.
    -- @raise Asserts on attempt to divide by zero
    -- or if inputs are not convertible to integers.
    -- @see internal.udiv
    -- @see internal.umod
    local bint_udivmod = function( x, y )
        local nume, deno = bint_new( x ), bint_assert_convert( y )

        -- compute if high bits of denominator are all zeros
        local ishighzero = true
        for i = 2, BINT_SIZE do
            if deno[ i ] ~= 0 then
                ishighzero = false
                break
            end
        end

        if ishighzero then
            -- try to divide by a single word (optimization)
            local low = deno[ 1 ]
            assert( low ~= 0, 'attempt to divide by zero' )

            -- denominator is one
            if low == 1 then
                return nume, bint_zero()

            -- can do single word division
            elseif low <= ( BINT_WORDMSB - 1 ) then
                return nume, bint_fromuinteger( sudivmod( nume, low ) )
            end
        end

        if nume:ult( deno ) then
            -- denominator is greater than numerator
            return bint_zero(), nume
        end

        -- align leftmost digits in numerator and denominator
        local denolbit = findleftbit( deno )
        local numelbit, numesize = findleftbit( nume )

        local bit = numelbit - denolbit
        deno = deno:__shl( bit )

        local wordmaxp1 = BINT_WORDMAX + 1
        local wordbitsm1 = BINT_WORDBITS - 1
        local denosize = numesize
        local quot = bint_zero()

        while bit >= 0 do
            -- compute denominator <= numerator
            local size = math_max( numesize, denosize )
            local le = true

            for i = size, 1, -1 do
                local a, b = deno[ i ], nume[ i ]
                if a ~= b then
                    le = a < b
                    break
                end
            end

            -- if the portion of the numerator above the denominator is greater or equal than to the denominator
            if le then
                -- subtract denominator from the portion of the numerator
                local borrow = 0
                for i = 1, size do
                    local res = nume[ i ] + wordmaxp1 - deno[ i ] - borrow
                    nume[ i ] = band( res, BINT_WORDMAX )
                    borrow = bxor( rshift( res, BINT_WORDBITS ), 1 )
                end

                -- concatenate 1 to the right bit of the quotient
                local i = math_fdiv( bit, BINT_WORDBITS ) + 1
                quot[ i ] = bor( quot[ i ], lshift( 1, bit % BINT_WORDBITS ) )
            end

            -- shift right the denominator in one bit
            for i = 1, denosize - 1 do
                deno[ i ] = band( bor( rshift( deno[ i ], 1 ), lshift( deno[ i + 1 ], wordbitsm1 ) ), BINT_WORDMAX )
            end

            local lastdenoword = rshift( deno[ denosize ], 1 )
            deno[ denosize ] = lastdenoword

            -- recalculate denominator size (optimization)
            if lastdenoword == 0 then
                while deno[ denosize ] == 0 do
                    denosize = denosize - 1
                end

                if denosize == 0 then
                    break
                end
            end

            -- decrement current set bit for the quotient
            bit = bit - 1
        end

        -- the remaining numerator is the remainder
        return quot, nume
    end

    internal.udivmod = bint_udivmod

    --- Perform unsigned division between two integers considering bints.
    -- @param x The numerator, must be a bint or a lua integer.
    -- @param y The denominator, must be a bint or a lua integer.
    -- @return The quotient, a bint.
    -- @raise Asserts on attempt to divide by zero
    -- or if inputs are not convertible to integers.
    function internal.udiv( x, y )
        return bint_udivmod( x, y ), nil
    end

    --- Perform unsigned integer modulo operation between two integers considering bints.
    -- @param x The numerator, must be a bint or a lua integer.
    -- @param y The denominator, must be a bint or a lua integer.
    -- @return The remainder, a bint.
    -- @raise Asserts on attempt to divide by zero
    -- or if the inputs are not convertible to integers.
    local bint_umod = function( x, y )
        local _, rema = bint_udivmod( x, y )
        return rema
    end

    internal.umod = bint_umod

    --- Perform integer truncate division and modulo operation between two numbers considering bints.
    -- This is effectively the same of @{internal.tdiv} and @{internal.tmod}.
    -- @param x The numerator, a bint or lua number.
    -- @param y The denominator, a bint or lua number.
    -- @return The quotient following the remainder, both bint or lua number.
    -- @raise Asserts on attempt to divide by zero or on division overflow.
    -- @see internal.tdiv
    -- @see internal.tmod
    local bint_tdivmod = function( x, y )
        local ax, ay = bint_abs( x ), bint_abs( y )
        local quot, rema

        local ix, iy = tobint( ax ), tobint( ay )
        if ix and iy then
            assert( not ( bint_eq( x, BINT_MININTEGER ) and bint_isminusone( y ) ), 'division overflow')
            quot, rema = bint_udivmod( ix, iy )
        else
            quot, rema = math_fdiv( ax, ay ), ax % ay
        end

        local isxneg, isyneg = bint_isneg( x ), bint_isneg( y )
        if isxneg ~= isyneg then
            quot = -quot
        end

        if isxneg then
            rema = -rema
        end

        return quot, rema
    end

    internal.tdivmod = bint_tdivmod

    --- Perform truncate division between two numbers considering bints.
    -- Truncate division is a division that rounds the quotient towards zero.
    -- @param x The numerator, a bint or lua number.
    -- @param y The denominator, a bint or lua number.
    -- @return The quotient, a bint or lua number.
    -- @raise Asserts on attempt to divide by zero or on division overflow.
    function internal.tdiv( x, y )
        return bint_tdivmod( x, y ), nil
    end

    --- Perform integer truncate modulo operation between two numbers considering bints.
    -- The operation is defined as the remainder of the truncate division
    -- (division that rounds the quotient towards zero).
    -- @param x The numerator, a bint or lua number.
    -- @param y The denominator, a bint or lua number.
    -- @return The remainder, a bint or lua number.
    -- @raise Asserts on attempt to divide by zero or on division overflow.
    function internal.tmod( x, y )
        local _, rema = bint_tdivmod( x, y )
        return rema
    end

    --- Perform integer floor division and modulo operation between two numbers considering bints.
    -- This is effectively the same of @{internal.__idiv} and @{internal.__mod}.
    -- @param x The numerator, a bint or lua number.
    -- @param y The denominator, a bint or lua number.
    -- @return The quotient following the remainder, both bint or lua number.
    -- @raise Asserts on attempt to divide by zero.
    -- @see internal.__idiv
    -- @see internal.__mod
    local bint_idivmod = function( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            local isnumeneg = band( ix[ BINT_SIZE ], BINT_WORDMSB ) ~= 0
            local isdenoneg = band( iy[ BINT_SIZE ], BINT_WORDMSB ) ~= 0

            if isnumeneg then
                ix = ix:__unm()
            end

            if isdenoneg then
                iy = iy:__unm()
            end

            local quot, rema = bint_udivmod( ix, iy )
            if isnumeneg ~= isdenoneg then
                quot:_unm()

                -- round quotient towards minus infinity
                if not rema:IsZero() then
                    quot:_dec()

                    -- adjust the remainder
                    if isnumeneg and not isdenoneg then
                        rema:_unm():_add( y )
                    elseif isdenoneg and not isnumeneg then
                        rema:_add( y )
                    end
                end
            elseif isnumeneg then
                -- adjust the remainder
                rema:_unm()
            end

            return quot, rema
        end

        local nx, ny = bint_tonumber( x ), bint_tonumber( y )
        return math_fdiv( nx, ny ), nx % ny
    end

    internal.idivmod = bint_idivmod

    --- Perform floor division between two numbers considering bints.
    -- Floor division is a division that rounds the quotient towards minus infinity,
    -- resulting in the floor of the division of its operands.
    -- @param x The numerator, a bint or lua number.
    -- @param y The denominator, a bint or lua number.
    -- @return The quotient, a bint or lua number.
    -- @raise Asserts on attempt to divide by zero.
    function internal.__idiv( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            local isnumeneg = band( ix[ BINT_SIZE ], BINT_WORDMSB ) ~= 0
            local isdenoneg = band( iy[ BINT_SIZE ], BINT_WORDMSB ) ~= 0

            if isnumeneg then
                ix = ix:__unm()
            end

            if isdenoneg then
                iy = iy:__unm()
            end

            local quot, rema = bint_udivmod( ix, iy )
            if isnumeneg ~= isdenoneg then
                quot:_unm()

                -- round quotient towards minus infinity
                if not rema:IsZero() then
                    quot:_dec()
                end
            end

            return quot, rema
        end

        return math_fdiv( bint_tonumber( x ), bint_tonumber( y ) )
    end

    --- Perform division between two numbers considering bints.
    -- This always casts inputs to floats, for integer division only use @{internal.__idiv}.
    -- @param x The numerator, a bint or lua number.
    -- @param y The denominator, a bint or lua number.
    -- @return The quotient, a lua number.
    function internal.__div( x, y )
        return bint_tonumber( x ) / bint_tonumber( y )
    end

    --- Perform integer floor modulo operation between two numbers considering bints.
    -- The operation is defined as the remainder of the floor division
    -- (division that rounds the quotient towards minus infinity).
    -- @param x The numerator, a bint or lua number.
    -- @param y The denominator, a bint or lua number.
    -- @return The remainder, a bint or lua number.
    -- @raise Asserts on attempt to divide by zero.
    function internal.__mod( x, y )
        local _, rema = bint_idivmod( x, y )
        return rema
    end

    --- Perform integer power between two integers considering bints.
    -- If y is negative then pow is performed as an unsigned integer.
    -- @param x The base, an integer.
    -- @param y The exponent, an integer.
    -- @return The result of the pow operation, a bint.
    -- @raise Asserts in case inputs are not convertible to integers.
    -- @see internal.__pow
    -- @see internal.upowmod
    function internal.ipow( x, y )
        y = bint_assert_convert( y )
        if y:IsZero() then
            return bint_one()
        elseif y:IsOne() then
            return bint_new( x )
        end

        -- compute exponentiation by squaring
        x, y = bint_new( x ), bint_new( y )
        local z = bint_one()

        repeat
            if y:IsEven() then
                x = x * x
                y:_shrone()
            else
                z = x * z
                x = x * x
                y:_dec():_shrone()
            end
        until y:IsOne()

        return x * z
    end

    --- Perform integer power between two unsigned integers over a modulus considering bints.
    -- @param x The base, an integer.
    -- @param y The exponent, an integer.
    -- @param m The modulus, an integer.
    -- @return The result of the pow operation, a bint.
    -- @raise Asserts in case inputs are not convertible to integers.
    -- @see internal.__pow
    -- @see internal.ipow
    function internal.upowmod( x, y, m )
        m = bint_assert_convert( m )
        if m:IsOne() then
            return bint_zero()
        end

        x, y = bint_new( x ), bint_new( y )
        x = bint_umod( x, m )

        local z = bint_one()
        while not y:IsZero() do
            if y:IsOdd() then
                z = bint_umod( z * x, m )
            end

            y:_shrone()
            x = bint_umod( x * x, m )
        end

        return z
    end

    --- Perform numeric power between two numbers considering bints.
    -- This always casts inputs to floats, for integer power only use @{internal.ipow}.
    -- @param x The base, a bint or lua number.
    -- @param y The exponent, a bint or lua number.
    -- @return The result of the pow operation, a lua number.
    -- @see internal.ipow
    function internal.__pow( x, y )
        return bint_tonumber( x ) ^ bint_tonumber( y )
    end

    --- Bitwise left shift integers considering bints.
    -- @param x An integer to perform the bitwise shift.
    -- @param y An integer with the number of bits to shift.
    -- @return The result of shift operation, a bint.
    -- @raise Asserts in case inputs are not convertible to integers.
    function internal.__shl( x, y )
        x, y = bint_new( x ), bint_assert_tointeger( y )
        if y == math_mininteger or math_abs( y ) >= BINT_BITS then
            return bint_zero()
        end

        if y < 0 then
            return x:__shr( -y )
        end

        local nvals = math_fdiv( y, BINT_WORDBITS )
        if nvals ~= 0 then
            x:_shlwords( nvals )
            y = y - ( nvals * BINT_WORDBITS )
        end

        if y ~= 0 then
            local wordbitsmy = BINT_WORDBITS - y
            for i = BINT_SIZE, 2, -1 do
                x[ i ] = band( bor( lshift( x[ i ], y ), rshift( x[ i - 1 ], wordbitsmy ) ), BINT_WORDMAX )
            end

            x[ 1 ] = band( lshift( x[ 1 ], y ), BINT_WORDMAX )
        end

        return x
    end

    --- Bitwise right shift integers considering bints.
    -- @param x An integer to perform the bitwise shift.
    -- @param y An integer with the number of bits to shift.
    -- @return The result of shift operation, a bint.
    -- @raise Asserts in case inputs are not convertible to integers.
    function internal.__shr( x, y )
        x, y = bint_new( x ), bint_assert_tointeger( y )
        if y == math_mininteger or math_abs( y ) >= BINT_BITS then
            return bint_zero()
        end

        if y < 0 then
            return x:__shl( -y )
        end

        local nvals = math_fdiv( y, BINT_WORDBITS )
        if nvals ~= 0 then
            x:_shrwords( nvals )
            y = y - ( nvals * BINT_WORDBITS )
        end

        if y ~= 0 then
            local wordbitsmy = BINT_WORDBITS - y
            for i = 1, BINT_SIZE - 1 do
                x[ i ] = band( bor( rshift( x[ i ], y ), lshift( x[ i + 1 ], wordbitsmy ) ), BINT_WORDMAX )
            end

            x[ BINT_SIZE ] = rshift( x[ BINT_SIZE ], y )
        end

        return x
    end

    -- BAND ( a & b )
    do

        --- Bitwise AND bints (in-place).
        -- @param y An integer to perform bitwise AND.
        -- @raise Asserts in case inputs are not convertible to integers.
        local internal_band = function( self, y )
            y = bint_assert_convert( y )

            for i = 1, BINT_SIZE do
                self[ i ] = band( self[ i ], y[ i ] )
            end

            return self
        end

        internal.band = internal_band
        internal.__band = internal_band

        --- Bitwise AND two integers considering bints.
        -- @param x An integer to perform bitwise AND.
        -- @param y An integer to perform bitwise AND.
        -- @raise Asserts in case inputs are not convertible to integers.
        bint_band = function( x, y )
            return internal_band( bint_new( x ), y )
        end

        static.band = bint_band

    end

    -- BOR ( a | b )
    do

        --- Bitwise OR bints (in-place).
        -- @param y An integer to perform bitwise OR.
        -- @raise Asserts in case inputs are not convertible to integers.
        local internal_bor = function( self, y )
            y = bint_assert_convert( y )

            for i = 1, BINT_SIZE do
                self[ i ] = bor( self[ i ], y[ i ] )
            end

            return self
        end

        internal.bor = internal_bor
        internal.__bor = internal_bor

        --- Bitwise OR two integers considering bints.
        -- @param x An integer to perform bitwise OR.
        -- @param y An integer to perform bitwise OR.
        -- @raise Asserts in case inputs are not convertible to integers.
        bint_bor = function( x, y )
            return internal_bor( bint_new( x ), y )
        end

        static.bor = bint_bor

    end

    -- BXOR ( a ~ b )
    do

        --- Bitwise XOR bints (in-place).
        -- @param y An integer to perform bitwise XOR.
        -- @raise Asserts in case inputs are not convertible to integers.
        local internal_bxor = function( self, y )
            y = bint_assert_convert( y )

            for i = 1, BINT_SIZE do
                self[ i ] = bxor( self[ i ], y[ i ] )
            end

            return self
        end

        internal.bxor = internal_bxor
        internal.__bxor = internal_bxor

        --- Bitwise XOR two integers considering bints.
        -- @param x An integer to perform bitwise XOR.
        -- @param y An integer to perform bitwise XOR.
        -- @raise Asserts in case inputs are not convertible to integers.
        static.bxor = function( x, y )
            return internal_bxor( bint_new( x ), y )
        end

    end

    --- Bitwise NOT a bint (in-place).
    function internal:_bnot()
        for i = 1, BINT_SIZE do
            self[ i ] = band( bnot( self[ i ] ), BINT_WORDMAX )
        end

        return self
    end

    --- Bitwise NOT a bint.
    -- @param x An integer to perform bitwise NOT.
    -- @raise Asserts in case inputs are not convertible to integers.
    function internal.__bnot( x )
        local y = setmetatable( {}, internal )
        for i = 1, BINT_SIZE do
            y[ i ] = band( bnot( x[ i ] ), BINT_WORDMAX )
        end

        return y
    end

    --- Negate a bint (in-place). This effectively applies two's complements.
    function internal:_unm()
        return self:_bnot():_inc()
    end

    --- Negate a bint. This effectively applies two's complements.
    -- @param x A bint to perform negation.
    function internal.__unm( x )
       return x:__bnot():_inc()
    end

    --- Compare if integer x is less than y considering bints (unsigned version).
    -- @param x Left integer to compare.
    -- @param y Right integer to compare.
    -- @raise Asserts in case inputs are not convertible to integers.
    -- @see internal.__lt
    function internal.ult( x, y )
        x, y = bint_assert_convert( x ), bint_assert_convert( y )
        for i = BINT_SIZE, 1, -1 do
            local a, b = x[ i ], y[ i ]
            if a ~= b then
                return a < b
            end
        end

        return false
    end

    --- Compare if bint x is less or equal than y considering bints (unsigned version).
    -- @param x Left integer to compare.
    -- @param y Right integer to compare.
    -- @raise Asserts in case inputs are not convertible to integers.
    -- @see internal.__le
    function internal.ule( x, y )
        x, y = bint_assert_convert( x ), bint_assert_convert( y )
        for i = BINT_SIZE, 1, -1 do
            local a, b = x[ i ], y[ i ]
            if a ~= b then
                return a < b
            end
        end

        return true
    end

    --- Compare if number x is less than y considering bints and signs.
    -- @param x Left value to compare, a bint or lua number.
    -- @param y Right value to compare, a bint or lua number.
    -- @see internal.ult
    function internal.__lt( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            local xneg = band( ix[ BINT_SIZE ], BINT_WORDMSB ) ~= 0
            local yneg = band( iy[ BINT_SIZE ], BINT_WORDMSB ) ~= 0

            if xneg == yneg then
                for i = BINT_SIZE, 1, -1 do
                    local a, b = ix[ i ], iy[ i ]
                    if a ~= b then
                        return a < b
                    end
                end

                return false
            end

            return xneg and not yneg
        end

        return bint_tonumber( x ) < bint_tonumber( y )
    end

    --- Compare if number x is less or equal than y considering bints and signs.
    -- @param x Left value to compare, a bint or lua number.
    -- @param y Right value to compare, a bint or lua number.
    -- @see internal.ule
    function internal.__le( x, y )
        local ix, iy = tobint( x ), tobint( y )
        if ix and iy then
            local xneg = band( ix[ BINT_SIZE ], BINT_WORDMSB ) ~= 0
            local yneg = band( iy[ BINT_SIZE ], BINT_WORDMSB ) ~= 0

            if xneg == yneg then
                for i = BINT_SIZE, 1, -1 do
                    local a, b = ix[ i ], iy[ i ]
                    if a ~= b then
                        return a < b
                    end
                end

                return true
            end

            return xneg and not yneg
        end

        return bint_tonumber( x ) <= bint_tonumber( y )
    end

    --- Convert a bint to a string on base 10.
    -- @see internal.ToBase
    function internal:__tostring()
        return self:ToBase( 10 )
    end

    BINT_MATHMININTEGER, BINT_MATHMAXINTEGER = bint_new( math.mininteger ), bint_new( math.maxinteger )
    BINT_MININTEGER = static.MinInteger()

    local cls = class( 'Int' .. bits, internal, static )
    memo[ memoindex ] = cls
    return cls
end

--[[
    Lua 5.1 Bigint by soupstream
    https://github.com/soupstream/lua-5.1-bigint/tree/master
    Modified by Unknown Developer
]]

local _G = _G
local environment = _G.gpm.environment

--##### FORWARD DECLARATIONS #####--

local bigint_mt
local bigint_digits
local bigint_comparatorMap

local bigint_maxnumber
local bigint_negone
local bigint_zero
local bigint_one

local bigint_new
local bigint_fromstring
local bigint_fromnumber
local bigint_fromarray
local bigint_constructor
local bigint_rstrip
local bigint_ensureBigInt
local bigint_ensureInt
local bigint_ensureString
local bigint_ensureBool
local bigint_ensureArray

local table_reverse
local table_copy

--##### MODULE FUNCTIONS #####--

local table_concat, unpack
do
    local table = environment.table
    table_concat, unpack = table.concat, table.unpack
end

local isstring, isnumber, isbool, istable = environment.isstring, environment.isnumber, environment.isbool, environment.istable
local tonumber, getmetatable, setmetatable = _G.tonumber, _G.getmetatable, _G.setmetatable
local math_floor = environment.math.floor

local string_sub, string_len, string_rep, string_byte, string_char, string_format
do
    local string = environment.string
    string_sub, string_len, string_rep, string_byte, string_char, string_format = string.sub, string.len, string.rep, string.byte, string.char, string.format
end

--##### CONSTRUCTORS #####--

local bigint = {}

function bigint_new()
    return setmetatable( { sign = 0, bytes = {}, mutable = false }, bigint_mt )
end

do

    local type = environment.type

    function bigint_constructor( self, value, base )
        if isstring( value ) then
            return bigint_fromstring( self, value, base )
        end

        if isnumber( value ) then
            return bigint_fromnumber( self, value )
        end

        if getmetatable( value ) == bigint_mt then
            return value
        end

        if istable( value ) then
            return bigint_fromarray( self, value, true )
        end

        error( "cannot construct bigint from type: " .. type( value ) )
    end

end

-- parse integer from a string
function bigint_fromstring( self, value, base )
    value = bigint_ensureString( value )

    self.sign = 1

    local digitsStart = 1
    local digitsEnd = string_len( value )
    if string_byte( value, digitsStart ) == 0x2d then -- "-"
        self.sign = -1
        digitsStart = digitsStart + 1
    end

    if string_byte( value, digitsStart ) == 0x30 then -- "0"
        digitsStart = digitsStart + 1
        local prefix = string_byte( value, digitsStart )
        if ( base == nil or base == 16 ) and prefix == 0x78 then      -- "x"
            base = 16
            digitsStart = digitsStart + 1
        elseif ( base == nil or base == 2 ) and prefix == 0x62 then   -- "b"
            base = 2
            digitsStart = digitsStart + 1
        end
    end

    while string_byte( value, digitsStart ) == 0x30 do -- "0"
        digitsStart = digitsStart + 1
    end

    if digitsStart > digitsEnd then
        self.sign = 0
        return self
    end

    base = bigint_ensureInt( base, 2, 36, 10 )
    if base == 2 or base == 16 then
        -- fast bin/hex parser
        local width = 8
        if base == 16 then
            width = 2
        end

        local i = 1
        for j = digitsEnd, digitsStart, -width do
            if j - width + 1 <= digitsStart then
                self.bytes[ i ] = tonumber( string_sub( value, digitsStart, j ), base )
            else
                self.bytes[ i ] = tonumber( string_sub( value, j - width + 1, j ), base )
            end

            i = i + 1
        end

        return self
    end

    -- general parser
    local j, carry = 1, 0
    for i = digitsStart, digitsEnd, 1 do
        -- multiply by base
        j, carry = 1, 0
        while self.bytes[ j ] ~= nil or carry ~= 0 do
            local product = ( self.bytes[ j ] or 0 ) * base + carry
            self.bytes[ j ] = product % 256
            carry = math_floor( product / 256 )
            j = j + 1
        end

        -- add digit
        j, carry = 1, tonumber( string_sub( value, i, i ), base )
        while carry ~= 0 do
            local sum = ( self.bytes[ j ] or 0 ) + carry
            self.bytes[ j ] = sum % 256
            carry = math_floor( sum / 256 )
            j = j + 1
        end
    end

    return self
end

function bigint_fromnumber( self, value )
    value = bigint_ensureInt( value )
    if value < 0 then
        value = -value
        self.sign = -1
    elseif value > 0 then
        self.sign = 1
    end

    local i = 1
    while value > 0 do
        self.bytes[ i ] = value % 256
        i = i + 1

        value = math_floor( value / 256 )
    end

    return self
end

function bigint_fromarray( self, array, littleEndian )
    array = bigint_ensureArray( array )
    littleEndian = bigint_ensureBool( littleEndian, false )

    self.bytes = table_copy( array )

    if not littleEndian then
        table_reverse( self.bytes )
    end

    self.sign = 1
    bigint_rstrip( self )
    return self
end

function bigint.FromBytes( binary, littleEndian )
    binary = bigint_ensureString( binary )
    littleEndian = bigint_ensureBool( littleEndian, false )

    local bytes = { string_byte( binary, 1, string_len( binary ) ) }
    if not littleEndian then
        table_reverse( bytes )
    end

    local obj = setmetatable( { sign = 1, bytes = bytes, mutable = false }, bigint_mt )
    bigint_rstrip( obj )
    return obj
end

--##### ARITHMETIC OPERATORS #####--

function bigint:Unm()
    if self.sign == 0 then
        return self
    end

    local this = self:CopyIfImmutable()
    this.sign = -this.sign
    return this
end

function bigint:Abs()
    if self.sign >= 0 then
        return self
    end

    local this = self:CopyIfImmutable()
    this.sign = 1
    return this
end

function bigint:SetSign( sign )
    sign = bigint_ensureInt( sign, -1, 1 )

    if self.sign == 0 or sign == self.sign then
        return self
    elseif sign == 0 then
        return bigint_zero
    elseif sign == -1 or sign == 1 then
        local this = self:CopyIfImmutable()
        this.sign = sign
        return this
    end

    error( "invalid sign", 2 )
end

function bigint:Add( other )
    other = bigint_ensureBigInt( other )

    -- addition of 0
    if other.sign == 0 then
        return self
    elseif self.sign == 0 then
        return other
    end

    -- determine sign, operation, and order of operands
    local subtract = false
    local swapOrder = false
    local changeSign = false

    if self.sign == other.sign then
        if #self.bytes < #other.bytes then
            swapOrder = true
        end
    else
        local ucomp = self:CompareU( other )
        if ucomp == 0 then
            return bigint_zero
        end

        subtract = true

        if ucomp == -1 then
            swapOrder = true
            changeSign = true
        end
    end

    -- perform operation
    local this = self:CopyIfImmutable()

    local bytes, otherBytes
    if swapOrder then
        bytes, otherBytes = other.bytes, self.bytes
    else
        bytes, otherBytes = self.bytes, other.bytes
    end

    local byteCount, otherByteCount = #bytes, #otherBytes

    local carry = 0
    for i = 1, byteCount, 1 do
        local byte = bytes[ i ]

        local otherByte = otherBytes[ i ] or 0
        if subtract then
            otherByte = -otherByte
        end

        local sum = byte + otherByte + carry
        if not subtract and sum >= 256 then
            this.bytes[ i ] = sum - 256
            carry = 1
        elseif subtract and sum < 0 then
            this.bytes[ i ] = sum + 256
            carry = -1
        else
            this.bytes[ i ] = sum
            carry = 0
        end

        -- end loop as soon as possible
        if i >= otherByteCount and carry == 0 then
            if swapOrder then
                -- just need to copy remaining bytes
                for j = i + 1, byteCount, 1 do
                    this.bytes[ j ] = bytes[ j ]
                end
            end

            break
        end
    end

    if carry > 0 then
        this.bytes[ byteCount + 1 ] = carry
    end

    if subtract then
        bigint_rstrip( this )
    end

    if changeSign then
        this.sign = -this.sign
    end

    return this
end

function bigint:Sub( other )
    other = bigint_ensureBigInt( other )
    return self:Add( other:Unm() )
end

function bigint:Mul( other )
    other = bigint_ensureBigInt( other )

    -- multiplication by 0
    if self.sign == 0 or other.sign == 0 then
        return bigint_zero
    end

    -- multiplication by 1
    if self:IsOne() then
        if self.sign == -1 then
            return other:Unm()
        end

        return other
    end

    if other:IsOne() then
        if other.sign == -1 then
            return self:Unm()
        end

        return self
    end

    -- general multiplication
    local this = self:CopyIfImmutable()
    local bytes, otherBytes = this.bytes, other.bytes

    local byteCount, otherByteCount = #bytes, #otherBytes

    if otherByteCount > byteCount then
        -- swap order so that number with more bytes comes first
        bytes, otherBytes = other.bytes, this.bytes

        local tmp = byteCount
        byteCount = otherByteCount
        otherByteCount = tmp
    end

    local result = {}
    local carry = 0

    for i = 1, otherByteCount, 1 do
        if otherBytes[ i ] == 0 then
            if result[ i ] == nil then
                result[ i ] = 0
            end
        else
            -- multiply each byte
            local j = 1
            while j <= byteCount do
                local resultIdx = i + j - 1
                local product = bytes[ j ] * otherBytes[ i ] + carry + ( result[ resultIdx ] or 0 )

                -- add product to result
                result[ resultIdx ] = product % 256
                carry = math_floor( product / 256 )
                j = j + 1
            end

            -- finish adding carry
            while carry ~= 0 do
                local resultIdx = i + j - 1
                local sum = ( result[ resultIdx ] or 0 ) + carry
                result[ resultIdx ] = sum % 256
                carry = math_floor( sum / 256 )
                j = j + 1
            end
        end
    end

    table_copy( this.bytes, result )

    this.sign = this.sign * other.sign
    return this
end

function bigint:DivWithRemainder( other, ignoreRemainder )
    other = bigint_ensureBigInt( other )
    ignoreRemainder = bigint_ensureBool( ignoreRemainder, false )

    -- division of/by 0
    if self.sign == 0 then
        return self, self
    elseif other.sign == 0 then
        return other, other
    end

    -- division by 1
    if other:IsOne() then
        if other.sign == -1 then
            return self:Unm(), bigint_zero
        end

        return self, bigint_zero
    end

    -- division by bigger number or self
    local ucomp = self:CompareU( other )
    if ucomp == -1 then
        if self.sign == other.sign then
            return bigint_zero, self
        end

        if ignoreRemainder then
            return bigint_zero, self
        end

        return bigint_zero, self:Add( other )
    elseif ucomp == 0 then
        if self.sign == other.sign then
            return bigint_one, bigint_zero
        end

        return bigint_negone, bigint_zero
    end

    -- general division
    local this = self:CopyIfImmutable()
    local another = other:CopyIfImmutable()

    local resultIdx = 1
    local result = {}

    local byteCount, otherByteCount = #this.bytes, #another.bytes

    local divIdx = byteCount - otherByteCount + 1
    while divIdx >= 1 do
        local factor = 0
        repeat
            -- check if divisor is smaller
            local foundFactor = false

            local sliceSize = otherByteCount
            if divIdx + sliceSize <= byteCount and this.bytes[ divIdx + sliceSize ] ~= 0 then
                sliceSize = sliceSize + 1
            end

            for i = sliceSize, 1, -1 do
                local byte = this.bytes[ divIdx + i - 1 ] or 0
                local otherByte = another.bytes[ i ] or 0
                if otherByte < byte then
                    foundFactor = false
                    break
                elseif otherByte > byte then
                    foundFactor = true
                    break
                end
            end

            -- subtract divisor
            if not foundFactor then
                factor = factor + 1
                local carry = 0
                local i = 1

                while i <= sliceSize or carry ~= 0 do
                    local j = divIdx + i - 1
                    local diff = ( this.bytes[ j ] or 0 ) - ( another.bytes[ i ] or 0 ) + carry
                    if diff < 0 then
                        carry = -1
                        diff = diff + 256
                    else
                        carry = 0
                    end

                    this.bytes[ j ] = diff
                    i = i + 1
                end
            end
        until foundFactor

        -- set digit
        result[ resultIdx ] = factor
        resultIdx = resultIdx + 1

        divIdx = divIdx - 1
    end

    local sign = this.sign
    local otherSign = another.sign
    local divSign = sign * otherSign

    bigint_rstrip( this )

    -- if remainder is negative, add divisor to make it positive
    if not ignoreRemainder and sign == -otherSign and this.sign ~= 0 then
        this = this:Add( another )
    end

    table_reverse( result )

    table_copy( another.bytes, result )
    another.sign = divSign

    bigint_rstrip( another )

    if this.sign ~= 0 and otherSign == -1 then
        this.sign = -1
    end

    return another, this
end

function bigint:Div( other )
    local quotient, _ = self:DivWithRemainder( other, true )
    return quotient
end

function bigint:Mod( other )
    local _, remainder = self:DivWithRemainder( other )
    return remainder
end

function bigint:Pow( other )
    other = bigint_ensureBigInt( other )

    if other.sign == 0 then
        return bigint_one
    elseif other.sign == -1 then
        return bigint_zero
    elseif other:IsOne() then
        return self
    end

    local sign = self.sign
    if sign == -1 and other:IsEven() then
        sign = 1
    end

    -- fast exponent if self is a power of 2
    local power = self:ExactLog2()
    if power ~= nil then
        -- assumes other isn't so big that precision becomes an issue
        local shift = ( other:ToNumber() - 1 ) * power
        return self:Shl( shift ):SetSign( sign )
    end

    -- multiply by self repeatedly
    local this = self:Copy()
    this.mutable = true

    local another = other:CopyIfImmutable():Abs():Add( bigint_negone )

    local otherMutable = another.mutable
    another.mutable = true

    while another.sign ~= 0 do
        this = this:Mul( self )
        another = another:Add( bigint_negone )
    end

    this.mutable = false
    another.mutable = otherMutable

    this.sign = sign
    return this
end

-- calculate log2 by finding highest 1 bit
function bigint:Log2()
    if self.sign == 0 then
        return nil
    end

    local byteCount = #self.bytes
    local byte = self.bytes[ byteCount ]
    local bitNum = ( byteCount - 1 ) * 8

    while byte >= 1 do
        bitNum = bitNum + 1
        byte = byte / 2
    end

    return bigint_fromnumber( bigint_new(), bitNum - 1 )
end

-- return log2 if it's an integer, else nil
function bigint:ExactLog2()
    if self.sign == 0 then
        return nil
    end

    local i = 1
    local power = 0
    local foundOne = false

    while self.bytes[ i ] ~= nil do
        local byte = self.bytes[ i ]
        for _ = 1, 8, 1 do
            if byte % 2 < 1 then
                if not foundOne then
                    power = power + 1
                end
            else
                if foundOne then
                    return nil
                end

                foundOne = true
            end

            byte = byte / 2
        end

        i = i + 1
    end

    return power
end

--##### BITWISE OPERATORS #####--

function bigint:Shr( n )
    n = bigint_ensureInt( n )

    if self.sign == 0 or n == 0 then
        return self
    end

    if n < 0 then
        return self:Shl( -n )
    end

    -- shift whole bytes
    local shiftBytes = math_floor( n / 8 )
    local byteCount = #self.bytes
    if shiftBytes >= byteCount then
        return bigint_zero
    end

    local this = self:CopyIfImmutable()
    for i = shiftBytes + 1, byteCount, 1 do
        this.bytes[ i - shiftBytes ] = this.bytes[ i ]
    end

    for i = byteCount - shiftBytes + 1, byteCount, 1 do
        this.bytes[ i ] = nil
    end

    byteCount = byteCount - shiftBytes

    -- shift bits
    local shiftBits = n % 8
    if shiftBits == 0 then
        return this
    end

    local shiftNum = 2 ^ shiftBits
    local unshiftNum = 2 ^ ( 8 - shiftBits )
    for i = 1, byteCount, 1 do
        local overflow = this.bytes[ i ] % shiftNum
        this.bytes[ i ] = math_floor( this.bytes[ i ] / shiftNum )

        if i ~= 1 then
            this.bytes[ i - 1 ] = this.bytes[ i - 1 ] + overflow * unshiftNum
        end
    end

    -- strip zero
    if this.bytes[ byteCount ] == 0 then
        this.bytes[ byteCount ] = nil
        if byteCount == 1 then
            this.sign = 0
        end
    end

    return this
end

function bigint:Shl( n )
    n = bigint_ensureInt( n )

    if self.sign == 0 or n == 0 then
        return self
    end

    if n < 0 then
        return self:Shr( -n )
    end

    -- shift whole bytes
    local shiftBytes = math_floor( n / 8 )
    local byteCount = #self.bytes

    local this = self:CopyIfImmutable()

    for i = byteCount + 1, byteCount + shiftBytes, 1 do
        this.bytes[ i ] = 0
    end

    for i = byteCount + shiftBytes, shiftBytes + 1, -1 do
        this.bytes[ i ] = this.bytes[ i - shiftBytes ]
    end

    for i = shiftBytes, 1, -1 do
        this.bytes[ i ] = 0
    end

    byteCount = byteCount + shiftBytes

    -- shift bits
    local shiftBits = n % 8
    if shiftBits == 0 then
        return this
    end

    local shiftNum = 2 ^ shiftBits
    local unshiftNum = 2 ^ ( 8 - shiftBits )
    for i = byteCount, shiftBytes + 1, -1 do
        local overflow = math_floor( this.bytes[ i ] / unshiftNum )
        this.bytes[ i ] = ( this.bytes[ i ] * shiftNum ) % 256

        if overflow ~= 0 then
            this.bytes[ i + 1 ] = ( this.bytes[ i + 1 ] or 0 ) + overflow
        end
    end

    return this
end

function bigint:Bor( other )
    other = bigint_ensureBigInt( other )

    if other.sign == 0 then
        return self
    end

    if self.sign == 0 then
        return other:Abs()
    end

    if self:CompareU( other ) == 0 then
        return self
    end

    local this
    local count, otherCount = #self.bytes, #other.bytes
    if otherCount > count then
        count = otherCount
    end

    for i = 1, count, 1 do
        local result = 0
        local bit = 1

        local byte = ( this or self ).bytes[ i ]
        local origByte = byte
        byte = byte or 0

        local otherByte = other.bytes[ i ] or 0
        for _ = 1, 8, 1 do
            if ( byte % 2 ) >= 1 or ( otherByte % 2 ) >= 1 then
                result = result + bit
            end

            byte = byte / 2
            otherByte = otherByte / 2
            bit = bit * 2
        end

        if result ~= origByte then
            if this == nil then
                -- lazy copy
                this = self:CopyIfImmutable()
            end

            this.bytes[ i ] = result
        end
    end

    return this or self
end

function bigint:Band( other )
    other = bigint_ensureBigInt( other )

    if self.sign == 0 then
        return self
    end

    if other.sign == 0 then
        return other:Abs()
    end

    if self:CompareU( other ) == 0 then
        return self
    end

    local this
    local count, otherCount = #self.bytes, #other.bytes
    if otherCount > count then
        count = otherCount
    end

    for i = 1, count, 1 do
        local result = 0
        local bit = 1

        local byte = ( this or self ).bytes[ i ]
        byte = byte or 0

        local origByte = byte
        local otherByte = other.bytes[ i ] or 0
        for _ = 1, 8, 1 do
            if ( byte % 2 ) >= 1 and ( otherByte % 2 ) >= 1 then
                result = result + bit
            end

            byte = byte / 2
            otherByte = otherByte / 2
            bit = bit * 2
        end

        if result ~= origByte then
            if this == nil then
                -- lazy copy
                this = self:CopyIfImmutable()
            end

            this.bytes[ i ] = result
        end
    end

    if this == nil then
        this = self
    else
        bigint_rstrip( this )
    end

    return this
end

function bigint:Bxor( other )
    other = bigint_ensureBigInt( other )

    if other.sign == 0 then
        return self
    end

    if self.sign == 0 then
        return other:Abs()
    end

    if self:CompareU( other ) == 0 then
        return bigint_zero
    end

    local this = self:CopyIfImmutable()

    local count, otherCount = #self.bytes, #other.bytes
    if otherCount > count then
        count = otherCount
    end

    for i = 1, count, 1 do
        local result = 0
        local bit = 1

        local byte = this.bytes[ i ]
        byte = byte or 0

        local otherByte = other.bytes[ i ] or 0
        for _ = 1, 8, 1 do
            if ( ( byte % 2 ) >= 1 ) ~= ( ( otherByte % 2 ) >= 1 ) then
                result = result + bit
            end

            byte = byte / 2
            otherByte = otherByte / 2
            bit = bit * 2
        end

        this.bytes[ i ] = result
    end

    bigint_rstrip( this )
    return this
end

function bigint:Bnot( size )
    local this = self:CopyIfImmutable()
    local byteCount = #self.bytes

    size = bigint_ensureInt( size, 1, nil, byteCount )

    if this.sign == 0 then
        this.bytes[ 1 ] = 0xff
        this.sign = 1
        return this
    end

    for i = 1, byteCount, 1 do
        local result = 0
        local bit = 1

        local byte = this.bytes[ i ]
        for _ = 1, 8, 1 do
            if ( byte % 2 ) < 1 then
                result = result + bit
            end

            byte = byte / 2
            bit = bit * 2
        end

        this.bytes[ i ] = result
    end

    for i = byteCount + 1, size, 1 do
        this.bytes[ i ] = 0xff
    end

    bigint_rstrip( this )
    return this
end

function bigint:SetBits( ... )
    local arg = {...}

    local count = #arg
    if count == 0 then
        return self
    end

    local this
    local byteCount = #self.bytes
    for i = 1, count, 1 do
        local bit = bigint_ensureInt( arg[ i ], 1 )
        bit = bit - 1

        local byteNum = math_floor( bit / 8 ) + 1
        if byteNum > byteCount then
            if this == nil then
                -- lazy copy
                this = self:CopyIfImmutable()
                if this.sign == 0 then
                    this.sign = 1
                end
            end

            for j = byteCount + 1, byteNum, 1 do
                this.bytes[ j ] = 0
            end

            byteCount = byteNum
        end

        local byte = ( this or self ).bytes[ byteNum ]
        local bitNum = 2 ^ ( bit % 8 )
        if ( byte / bitNum ) % 2 < 1 then
            if this == nil then
                -- lazy copy
                this = self:CopyIfImmutable()
                if this.sign == 0 then
                    this.sign = 1
                end
            end

            this.bytes[ byteNum ] = byte + bitNum
        end
    end

    return this or self
end

function bigint:UnsetBits( ... )
    local arg = {...}
    if self.sign == 0 then
        return self
    end

    local count = #arg
    if count == 0 then
        return self
    end

    local this
    for i = 1, count, 1 do
        local bit = bigint_ensureInt( arg[ i ], 1 )
        bit = bit - 1

        local byteNum = math_floor( bit / 8 ) + 1
        local byte = ( this or self ).bytes[ byteNum ]
        if byte ~= nil then
            local bitNum = 2 ^ ( bit % 8 )
            if ( byte / bitNum ) % 2 >= 1 then
                if this == nil then
                    -- lazy copy
                    this = self:CopyIfImmutable()
                end

                this.bytes[ byteNum ] = byte - bitNum
            end
        end
    end

    if this == nil then
        this = self
    else
        bigint_rstrip( this )
    end

    return this
end

function bigint:GetBit( i )
    i = bigint_ensureInt( i, 1 )
    if i < 1 then
        return nil
    end

    if self.sign == 0 then
        return 0
    end

    i = i - 1

    local byteNum = math_floor( i / 8 ) + 1
    local byte = self.bytes[ byteNum ]
    if byte == nil or byte == 0 then
        return 0
    end

    local bitNum = i % 8
    return math_floor( byte / ( 2 ^ bitNum ) ) % 2
end

-- convert 2's complement unsigned number to signed
function bigint:CastSigned( size )
    local byteCount = #self.bytes
    size = bigint_ensureInt( size, 1, nil, byteCount )

    if self.sign == 0 then
        return self
    end

    if byteCount > size then
        error( "twos complement overflow", 2 )
    end

    if self.sign == 1 and ( self.bytes[ size ] or 0 ) > 0x7f then
        local this = self:CopyIfImmutable()

        local mutable = this.mutable
        this.mutable = true

        this = this:Bnot( size ):Add( bigint_one )

        this.sign = -1
        this.mutable = mutable
        return this
    end

    return self
end

-- convert 2's complement signed number to unsigned
function bigint:CastUnsigned( size )
    local byteCount = #self.bytes
    size = bigint_ensureInt( size, 1, nil, byteCount )

    if self.sign == 0 then
        return self
    end

    if byteCount > size then
        error( "twos complement overflow", 2 )
    end

    if self.sign == 1 then
        return self
    end

    local this = self:CopyIfImmutable()

    local mutable = this.mutable
    this.mutable = true
    this.sign = 1

    this = this:Bnot( size ):Add( bigint_one )
    this.mutable = mutable
    return this
end

--##### EQUALITY OPERATORS #####--

-- compare unsigned
function bigint:CompareU( other )
    other = bigint_ensureBigInt( other )

    local byteCount = #self.bytes
    local otherByteCount = #other.bytes

    if byteCount < otherByteCount then
        return -1
    elseif byteCount > otherByteCount then
        return 1
    end

    for i = byteCount, 1, -1 do
        if self.bytes[ i ] < other.bytes[ i ] then
            return -1
        elseif self.bytes[ i ] > other.bytes[ i ] then
            return 1
        end
    end

    return 0
end

function bigint:Compare( other )
    other = bigint_ensureBigInt( other )

    if self.sign > other.sign then
        return 1
    elseif self.sign < other.sign then
        return -1
    end

    local ucomp = self:CompareU( other )
    if ucomp == 0 then
        return 0
    elseif self.sign == 1 then
        return ucomp
    elseif self.sign == -1 then
        return -ucomp
    end

    return 0
end

function bigint:CompareOp( other, op )
    local comparator = bigint_comparatorMap[ op ]
    if comparator == nil then
        error( "invalid argument; expected comparison operator", 2 )
    end

    return comparator( self, other )
end

function bigint:Eq( other )
    return self:Compare( other ) == 0
end

function bigint:Ne( other )
    return self:Compare( other ) ~= 0
end

function bigint:Lt( other )
    return self:Compare( other ) == -1
end

function bigint:Le( other )
    return self:Compare( other ) <= 0
end

function bigint:Gt( other )
    return self:Compare( other ) == 1
end

function bigint:Ge( other )
    return self:Compare( other ) >= 0
end

--##### CONVERSION #####--

-- convert to string of bytes
function bigint:ToBytes( size, littleEndian )
    littleEndian = bigint_ensureBool( littleEndian, false )

    -- avoid copying array
    local bytes = self.bytes
    local byteCount = #bytes

    size = bigint_ensureInt( size, 1, nil, byteCount )
    if byteCount < size then
        for i = byteCount + 1, size, 1 do
            bytes[ i ] = 0
        end
    end

    local byteStr
    if littleEndian then
        byteStr = string_char( unpack( bytes, 1, size ) )
    else
        table_reverse( bytes )

        if byteCount <= size then
            byteStr = string_char( unpack( bytes ) )
        else
            byteStr = string_char( unpack( bytes, byteCount - size + 1, byteCount ) )
        end

        table_reverse( bytes )
    end

    -- restore original state
    for i = size, byteCount + 1, -1 do
        bytes[ i ] = nil
    end

    return byteStr
end

function bigint:ToNumber()
    if self:CompareU( bigint_maxnumber ) == 1 then
        error( "integer too big to convert to lua number", 2 )
    end

    local total = 0
    for i = #self.bytes, 1, -1 do
        total = ( total * 256 ) + self.bytes[ i ]
    end

    return total * self.sign
end

function bigint:ToBool()
    return self.sign ~= 0
end

-- fast hex base conversion
function bigint:ToHex( noPrefix )
    noPrefix = bigint_ensureBool( noPrefix, false )

    if self.sign == 0 then
        if noPrefix then
            return "0"
        end

        return "0x0"
    end

    local bytes = table_copy( self.bytes )
    table_reverse( bytes )

    local result = string_format( "%x" .. string_rep( "%02x", #bytes - 1 ), unpack( bytes ) )
    if not noPrefix then
        result = "0x" .. result
    end

    if self.sign == -1 then
        result = "-" .. result
    end

    return result
end

-- fast bin base conversion
function bigint:ToBin( noPrefix )
    noPrefix = bigint_ensureBool( noPrefix, false )

    if self.sign == 0 then
        if noPrefix then
            return "0"
        end

        return "0b0"
    end

    local t = {}
    local bytesCount = #self.bytes

    for i = 1, bytesCount, 1 do
        local byte = self.bytes[ i ]
        local start = ( i - 1 ) * 8 + 1
        for j = start, start + 7, 1 do
            if byte == 0 then
                if i == bytesCount then
                    break
                end

                t[ j ] = 0
            else
                t[ j ] = byte % 2
                byte = math_floor( byte / 2 )
            end
        end
    end

    table_reverse( t )

    local result = table_concat( t )
    if not noPrefix then
        result = "0b" .. result
    end

    if self.sign == -1 then
        result = "-" .. result
    end

    return result
end

function bigint:ToDec()
    return self:ToBase( 10 )
end

-- general base conversion
function bigint:ToBase( base )
    base = bigint_ensureInt( base, 1, 36 )

    if base == 2 then
        return self:ToBin( true )
    elseif base == 16 then
        return self:ToHex( true )
    end

    if self.sign == 0 then
        return "0"
    end

    local result = {}

    local j, carry = 1, 0
    for i = #self.bytes, 1, -1 do
        -- multiply by 256
        j, carry = 1, 0
        while result[ j ] ~= nil or carry ~= 0 do
            local product = ( result[ j ] or 0 ) * 256 + carry
            result[ j ] = product % base
            j, carry = j + 1, math_floor( product / base )
        end

        -- add byte
        j, carry = 1, self.bytes[ i ]
        while carry ~= 0 do
            local sum = ( result[ j ] or 0 ) + carry
            result[ j ] = sum % base
            j, carry = j + 1, math_floor( sum / base )
        end
    end

    table_reverse( result )

    for i = #result, 1, -1 do
        result[ i ] = bigint_digits[ result[ i ] + 1 ]
    end

    local str = table_concat( result )
    if self.sign == -1 then
        str = "-" .. str
    end

    return str
end

--##### METATABLE #####--

local function ensureSelfIsBigInt( f )
    return function( self, ... )
        return f( bigint_ensureBigInt( self ), ... )
    end
end

bigint_mt = {
    __index = bigint,
    __unm = bigint.Unm,
    __add = ensureSelfIsBigInt( bigint.Add ),
    __sub = ensureSelfIsBigInt( bigint.Sub ),
    __mul = ensureSelfIsBigInt( bigint.Mul ),
    __div = ensureSelfIsBigInt( bigint.Div ),
    __mod = ensureSelfIsBigInt( bigint.Mod ),
    __pow = ensureSelfIsBigInt( bigint.Pow ),
    __eq = ensureSelfIsBigInt( bigint.Eq ),
    __lt = ensureSelfIsBigInt( bigint.Lt ),
    __le = ensureSelfIsBigInt( bigint.Le ),

    -- not supported in 5.1
    __idiv = ensureSelfIsBigInt( bigint.Div ),
    __band = ensureSelfIsBigInt( bigint.Band ),
    __bor = ensureSelfIsBigInt( bigint.Bor ),
    __bxor = ensureSelfIsBigInt( bigint.Bxor ),
    __bnot = function( self ) return self:Bnot() end,
    __shl = ensureSelfIsBigInt( bigint.Shl ),
    __shr = ensureSelfIsBigInt( bigint.Shr ),
    __tostring = bigint.ToDec
}

--##### HELPERS #####--

function bigint:Copy()
    local copy = bigint_new()
    table_copy( copy.bytes, self.bytes )
    copy.sign = self.sign
    return copy
end

-- return a copy if immutable or self otherwise
-- if other is not nil, copy it instead
function bigint:CopyIfImmutable()
    return self.mutable and self or self:Copy()
end

function bigint:IsEven()
    return self.sign == 0 or self.bytes[ 1 ] % 2 == 0
end

function bigint:IsOne()
    return self.bytes[ 2 ] == nil and self.bytes[ 1 ] == 1
end

function bigint_rstrip( self )
    local i = #self.bytes
    while self.bytes[ i ] == 0 do
        self.bytes[ i ] = nil
        i = i - 1
    end

    if i == 0 then
        self.sign = 0
    end
end

function bigint_ensureBigInt( obj )
    if getmetatable( obj ) == bigint_mt then
        return obj
    end

    return bigint_constructor( bigint_new(), obj )
end

function bigint_ensureInt( obj, minValue, maxValue, default )
    if obj == nil and default ~= nil then
        return default
    end

    if getmetatable( obj ) == bigint_mt then
        obj = obj:ToNumber()
    end

    if isnumber( obj ) then
        if obj % 1 ~= 0 then
            if obj < 0 then
                obj = obj + ( obj % 1 )
            else
                obj = obj - ( obj % 1 )
            end
        end

        if ( minValue == nil or obj >= minValue ) and ( maxValue == nil or obj <= maxValue ) then
            return obj
        end
    end

    error( "invalid argument; expected integer in range [" .. ( minValue or "" ) .. ", " .. ( maxValue or "" ) .. "]" )
end

function bigint_ensureArray( obj, default )
    if obj == nil and default ~= nil then
        return default
    end

    if istable( obj ) and getmetatable( obj ) ~= bigint_mt then
        return obj
    end

    error( "invalid argument; expected array" )
end

function bigint_ensureString( obj, default )
    if obj == nil and default ~= nil then
        return default
    end

    if isstring( obj ) then
        return obj
    end

    error( "invalid argument; expected string" )
end

function bigint_ensureBool( obj, default )
    if obj == nil and default ~= nil then
        return default
    end

    if isbool( obj ) then
        return obj
    end

    error( "invalid argument; expected boolean" )
end

function table_reverse( t )
    local size = #t
    local mid = size / 2
    for i = 1, mid, 1 do
        local j = size - i + 1
        t[ i ], t[ j ] = t[ j ], t[ i ]
    end

    return t
end

-- copy t2 into t1
-- or return copy of t1 if t2 is nil
function table_copy( t1, t2 )
    if t2 == nil then
        return { unpack( t1 ) }
    end

    local size, t2Size = #t1, #t2
    if t2Size > size then
        size = t2Size
    end

    for i = 1, size, 1 do
        t1[ i ] = t2[ i ]
    end

    return t1
end

bigint_digits = {
    "0", "1", "2",
    "3", "4", "5",
    "6", "7", "8",
    "9", "a", "b",
    "c", "d", "e",
    "f", "g", "h",
    "i", "j", "k",
    "l", "m", "n",
    "o", "p", "q",
    "r", "s", "t",
    "u", "v", "w",
    "x", "y", "z"
}

bigint_comparatorMap = {
    ["=="] = bigint.Eq,
    ["~="] = bigint.Ne,
    ["<"] = bigint.Lt,
    [">"] = bigint.Gt,
    ["<="] = bigint.Le,
    [">="] = bigint.Ge
}

bigint_zero = bigint_new()
bigint.Zero = bigint_zero

bigint_one = bigint_fromnumber( bigint_new(), 1 )
bigint.One = bigint_one

bigint_negone = bigint_fromnumber( bigint_new(), -1 )
bigint.NegOne = bigint_negone

bigint.Two = bigint_fromnumber( bigint_new(), 2 )

-- determine the max accurate integer supported by this build of Lua
if 0x1000000 == 0x1000001 then
    -- max integer that can be accurately represented by a float
    bigint_maxnumber = bigint_fromstring( bigint_new(), "0xffffff" )
else
    -- double
    bigint_maxnumber = bigint_fromstring( bigint_new(), "0x1FFFFFFFFFFFFF" )
end

bigint.MaxNumber = bigint_maxnumber

bigint_mt.new = function( self, ... )
    self.sign = 0
    self.bytes = {}
    self.mutable = false
    bigint_constructor( self, ... )
    return nil
end

function bigint.FromString( value, base )
    return bigint_fromstring( bigint_new(), value, base )
end

function bigint.FromNumber( value )
    return bigint_fromnumber( bigint_new(), value )
end

function bigint.FromArray( array, littleEndian )
    return bigint_fromarray( bigint_new(), array, littleEndian )
end

environment.BInt = environment.class( "BInt", bigint_mt, bigint )

function environment.IsBInt( obj )
    return getmetatable( obj ) == bigint_mt
end

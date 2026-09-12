---@class dreamwork.std
local std = dreamwork.std

local ascii = std.ascii
local ascii_isHexDigit = ascii.isHexDigit

local string = std.string
local string_len = string.len
local string_format = string.format
local string_byte, string_char = string.byte, string.char

local bit = std.bit
local bit_band, bit_bor = bit.band, bit.bor
local bit_lshift, bit_rshift = bit.lshift, bit.rshift

local math = std.math
local math_abs = math.abs
local math_lerp = math.lerp
local math_min, math_max = math.min, math.max
local math_ceil, math_floor = math.ceil, math.floor

local bytepack = std.bytepack
local bytepack_readHex8 = bytepack.readHex8

local error = std.error


local DIV255_CONST = 1 / 255


---@alias dreamwork.std.Color integer

--- [SHARED AND MENU]
---
--- Library for color manipulation.
---
---@class dreamwork.std.color
local color_lib = {}
std.color = color_lib

--- [SHARED AND MENU]
---
--- Converts RGBA components to a color value.
---
---@param red integer The 8-bit red channel, in the range [0, 255].
---@param green integer The 8-bit green channel, in the range [0, 255].
---@param blue integer The 8-bit blue channel, in the range [0, 255].
---@return dreamwork.std.Color color The color value.
local function fromRGB( red, green, blue )
    return bit_bor(
        bit_lshift( bit_band( red, 0xFF ), 16 ),
        bit_lshift( bit_band( green, 0xFF ), 8 ),
        bit_band( blue, 0xFF )
    )
end

color_lib.fromRGB = fromRGB

--- [SHARED AND MENU]
---
--- Converts a color value to RGBA components.
---
---@param color dreamwork.std.Color The color value to convert.
---@return integer red The 8-bit red channel, in the range [0, 255].
---@return integer green The 8-bit green channel, in the range [0, 255].
---@return integer blue The 8-bit blue channel, in the range [0, 255].
local function toRGB( color )
    return bit_band( bit_rshift( color, 16 ), 0xFF ),
        bit_band( bit_rshift( color, 8 ), 0xFF ),
        bit_band( color, 0xFF )
end

color_lib.toRGB = toRGB

--- [SHARED AND MENU]
---
--- Inverts a color value.
---
---@param color dreamwork.std.Color The color value to invert.
---@return dreamwork.std.Color The inverted color value.
function color_lib.invert( color )
    local r, g, b = toRGB( color )

    return fromRGB(
        math_abs( 255 - r ),
        math_abs( 255 - g ),
        math_abs( 255 - b )
    )
end

--- [SHARED AND MENU]
---
--- Adds two colors.
---
---@param value1 dreamwork.std.Color The first color to add.
---@param value2 dreamwork.std.Color The second color to add.
function color_lib.add( value1, value2 )
    local r1, g1, b1 = toRGB( value1 )
    local r2, g2, b2 = toRGB( value2 )

    return fromRGB(
        math_ceil( r1 + r2 ),
        math_ceil( g1 + g2 ),
        math_ceil( b1 + b2 )
    )
end

--- [SHARED AND MENU]
---
--- Subtracts two colors.
---
---@param value1 dreamwork.std.Color The first color to subtract.
---@param value2 dreamwork.std.Color The second color to subtract.
---@return dreamwork.std.Color new_color The result of the subtraction.
function color_lib.sub( value1, value2 )
    local r1, g1, b1 = toRGB( value1 )
    local r2, g2, b2 = toRGB( value2 )

    return fromRGB(
        math_ceil( r1 - r2 ),
        math_ceil( g1 - g2 ),
        math_ceil( b1 - b2 )
    )
end

--- [SHARED AND MENU]
---
--- Multiplies two colors.
---
---@param value1 dreamwork.std.Color The first color to multiply.
---@param value2 dreamwork.std.Color The second color to multiply.
---@return dreamwork.std.Color new_color The result of the multiplication.
function color_lib.mul( value1, value2 )
    local r1, g1, b1 = toRGB( value1 )
    local r2, g2, b2 = toRGB( value2 )

    return fromRGB(
        math_ceil( r1 * r2 ),
        math_ceil( g1 * g2 ),
        math_ceil( b1 * b2 )
    )
end

--- [SHARED AND MENU]
---
--- Divides two colors.
---
---@param value1 dreamwork.std.Color The first color to divide.
---@param value2 dreamwork.std.Color The second color to divide.
---@return dreamwork.std.Color new_color The result of the division.
function color_lib.div( value1, value2 )
    local r1, g1, b1 = toRGB( value1 )
    local r2, g2, b2 = toRGB( value2 )

    return fromRGB(
        math_ceil( r1 / r2 ),
        math_ceil( g1 / g2 ),
        math_ceil( b1 / b2 )
    )
end

--- [SHARED AND MENU]
---
--- Returns the color as binary string.
---
---@param color dreamwork.std.Color The color to convert.
---@return string binary_string The color as binary string.
function color_lib.toString( color )
    return string_char( toRGB( color ) )
end

--- [SHARED AND MENU]
---
--- Parses a color from a binary string.
---
---@param str string The binary string to parse.
---@param start_position? integer The starting position in the string.
---@param str_length? integer The length of the string to parse.
---@return dreamwork.std.Color new_color The parsed color.
function color_lib.fromString( str, start_position, str_length )
    if start_position == nil then
        start_position = 1
    end

    if str_length == nil then
        str_length = string_len( str )
    end

    if (str_length - start_position + 1) < 4 then
        error( "not enough bytes in string to parse color", 2 )
    end

    return fromRGB( string_byte( str, start_position, start_position + 3 ) )
end

--- [SHARED AND MENU]
---
--- Smoothing two colors by fraction.
---
---@param frac number The interpolation factor.
---@param color dreamwork.std.Color The starting color.
---@param color2 dreamwork.std.Color The ending color.
---@return dreamwork.std.Color The interpolated color.
function color_lib.lerp( frac, color, color2 )
    local r, g, b = toRGB( color )
    local r2, g2, b2 = toRGB( color2 )

    return fromRGB(
        math_lerp( frac, r, r2 ),
        math_lerp( frac, g, g2 ),
        math_lerp( frac, b, b2 )
    )
end

--- [SHARED AND MENU]
---
--- Converts a color value to a hexadecimal string.
---
---@param color dreamwork.std.Color The color to convert.
---@return string The hexadecimal representation of the color.
local function toHex( color )
    return string_format( "%02x%02x%02x", toRGB( color ) )
end

color_lib.toHex = toHex

---@param uint8 integer | nil
---@return integer | nil
local function fromByte( uint8 )
    if uint8 == nil then
        return nil
    elseif ascii_isHexDigit( uint8 ) then
        return bytepack_readHex8( uint8, uint8 )
    else
        return uint8
    end
end

---@param uint8_1 integer
---@param uint8_2 integer
---@param uint8_3 integer
---@param uint8_4 integer
---@param uint8_5 integer
---@param uint8_6 integer
---@return integer | nil
---@return integer | nil
---@return integer | nil
local function fromBytes( uint8_1, uint8_2, uint8_3, uint8_4, uint8_5, uint8_6 )
    if uint8_1 == nil then
        return 0x000000
    elseif uint8_2 == nil then
        return bytepack_readHex8( uint8_1, 0x00 ), 0x00, 0x00
    elseif uint8_3 == nil then
        return bytepack_readHex8( uint8_1, uint8_2 ), 0x00, 0x00
    elseif uint8_4 == nil then
        return bytepack_readHex8( uint8_1, uint8_2 ), bytepack_readHex8( uint8_3, 0x00 ), 0x00
    elseif uint8_5 == nil then
        return bytepack_readHex8( uint8_1, uint8_2 ), bytepack_readHex8( uint8_3, uint8_4 ), 0x00
    elseif uint8_6 == nil then
        return bytepack_readHex8( uint8_1, uint8_2 ),
            bytepack_readHex8( uint8_3, uint8_4 ),
            bytepack_readHex8( uint8_5, 0x00 )
    else
        return bytepack_readHex8( uint8_1, uint8_2 ),
            bytepack_readHex8( uint8_3, uint8_4 ),
            bytepack_readHex8( uint8_5, uint8_6 )
    end
end

--- [SHARED AND MENU]
---
--- Converts a hexadecimal color string to color.
---
--- Formats:
---
--- `0xRRGGBB` / `#RRGGBB` / `RRGGBB`
---
---@param hex_str string The hexadecimal color string to convert.
---@return dreamwork.std.Color color The color value.
local function fromHex( hex_str )
    local uint8_1 = string_byte( hex_str, 1, 1 )
    if uint8_1 == nil then
        return 0x000000
    end

    local uint8_2 = string_byte( hex_str, 2, 2 )
    if uint8_2 == nil then
        return fromRGB( fromByte( uint8_1 ) or 0, 0, 0 )
    end

    local r, g, b

    if uint8_1 == 0x23 --[[ # ]] then
        r, g, b = fromBytes( uint8_2, string_byte( hex_str, 3, 9 ) )
    elseif uint8_1 == 0x30 --[[ 0 ]] and (uint8_2 == 0x58 --[[ X ]] or uint8_2 == 0x78 --[[ x ]]) then
        r, g, b = fromBytes( string_byte( hex_str, 3, 10 ) )
    else
        r, g, b = fromBytes( uint8_1, uint8_2, string_byte( hex_str, 3, 8 ) )
    end

    return fromRGB( r or 0, g or 0, b or 0 )
end

color_lib.fromHex = fromHex

--- [SHARED AND MENU]
---
--- Creates a color from HSL values (hue, saturation, lightness).
---
---@param hue integer The hue in degrees [0, 360].
---@param saturation number The saturation [0, 1].
---@param lightness number The lightness [0, 1].
---@return dreamwork.std.Color new_color The new color.
local function fromHSL( hue, saturation, lightness )
    hue = hue % 360

    local c = (1 - math_abs( 2 * lightness - 1 )) * saturation
    local x = c * (1 - math_abs( (hue / 60) % 2 - 1 ))
    local m = lightness - (c * 0.5)

    local r, g, b
    if hue < 60 then
        r, g, b = c, x, 0
    elseif hue < 120 then
        r, g, b = x, c, 0
    elseif hue < 180 then
        r, g, b = 0, c, x
    elseif hue < 240 then
        r, g, b = 0, x, c
    elseif hue < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    return fromRGB(
        math_floor( (r + m) * 255 ),
        math_floor( (g + m) * 255 ),
        math_floor( (b + m) * 255 )
    )
end

color_lib.fromHSL = fromHSL

--- [SHARED AND MENU]
---
--- Converts a color to HSL values (hue, saturation, lightness).
---
---@param color dreamwork.std.Color The color to convert.
---@return integer hue The hue in degrees [0, 360].
---@return number saturation The saturation as fraction [0, 1].
---@return number lightness The lightness as fraction [0, 1].
local function toHSL( color )
    local red, green, blue = toRGB( color )
    red, green, blue = red * DIV255_CONST, green * DIV255_CONST, blue * DIV255_CONST

    local min_value, max_value = math_min( red, green, blue ), math_max( red, green, blue )

    local lightness = (max_value + min_value) * 0.5

    local delta = max_value - min_value
    if delta ~= 0 then
        local saturation
        if lightness > 0.5 then
            saturation = delta / (2.0 - (max_value - min_value))
        else
            saturation = delta / (max_value + min_value)
        end

        local hue
        if max_value == red then
            hue = ((green - blue) / delta) % 6
        elseif max_value == green then
            hue = ((blue - red) / delta) + 2
        else
            hue = ((red - green) / delta) + 4
        end

        hue = hue * 60

        return hue < 0 and hue + 360 or hue, saturation, lightness
    end

    return 0, 0, lightness
end

color_lib.toHSL = toHSL

--- [SHARED AND MENU]
---
--- Creates a color from HSV values.
---
---@param hue integer The hue in degrees [0, 360].
---@param saturation number The saturation [0, 1].
---@param brightness number The brightness [0, 1].
---@return dreamwork.std.Color new_color The new color.
local function fromHSV( hue, saturation, brightness )
    hue = hue % 360

    local c = brightness * saturation
    local x = c * (1 - math_abs( (hue / 60) % 2 - 1 ))
    local m = brightness - c

    local r, g, b
    if hue < 60 then
        r, g, b = c, x, 0
    elseif hue < 120 then
        r, g, b = x, c, 0
    elseif hue < 180 then
        r, g, b = 0, c, x
    elseif hue < 240 then
        r, g, b = 0, x, c
    elseif hue < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    return fromRGB(
        math_floor( (r + m) * 255 ),
        math_floor( (g + m) * 255 ),
        math_floor( (b + m) * 255 )
    )
end

color_lib.fromHSV = fromHSV

--- [SHARED AND MENU]
---
--- Returns the color as HSV values (hue, saturation, value).
---
---@param color dreamwork.std.Color The color to convert.
---@return integer hue The hue in degrees [0, 360].
---@return number saturation The saturation as fraction [0, 1].
---@return number value The value as fraction [0, 1].
local function toHSV( color )
    local red, green, blue = toRGB( color )
    red, green, blue = red * DIV255_CONST, green * DIV255_CONST, blue * DIV255_CONST

    local min_value, max_value = math_min( red, green, blue ), math_max( red, green, blue )
    local delta = max_value - min_value

    local saturation
    if max_value == 0 then
        saturation = 0
    else
        saturation = delta / max_value
    end

    local hue
    if delta == 0 then
        hue = 0
    elseif max_value == red then
        hue = ((green - blue) / delta) % 6
    elseif max_value == green then
        hue = ((blue - red) / delta) + 2
    else
        hue = ((red - green) / delta) + 4
    end

    hue = hue * 60

    return hue < 0 and hue + 360 or hue, saturation, max_value
end

color_lib.toHSV = toHSV

--- [SHARED AND MENU]
---
--- Creates a color from HWB values.
---
---@param hue integer The hue in degrees [0, 360].
---@param saturation number The saturation [0, 1].
---@param brightness number The brightness [0, 1].
---@return dreamwork.std.Color new_color The new color.
local function fromHWB( hue, saturation, brightness )
    brightness = 1 - brightness
    return fromHSV( hue, (brightness > 0) and (1 - (saturation / brightness)) or 0, brightness )
end

color_lib.fromHWB = fromHWB

--- [SHARED AND MENU]
---
--- Returns the color as HWB values (hue, whiteness, blackness).
---
---@param color dreamwork.std.Color The color to convert to HWB.
---@return integer hue The hue in degrees [0, 360].
---@return number whiteness The whiteness as fraction [0, 1].
---@return number blackness The blackness as fraction [0, 1].
local function toHWB( color )
    local hue, saturation, brightness = toHSL( color )
    return hue, (1 - saturation) * brightness, 1 - brightness
end

color_lib.toHWB = toHWB

--- [SHARED AND MENU]
---
--- Creates a color from CMYK values.
---
---@param cyan number The cyan as fraction [0, 1].
---@param magenta number The magenta as fraction [0, 1].
---@param yellow number The yellow as fraction [0, 1].
---@param black number The black as fraction [0, 1].
---@return dreamwork.std.Color new_color The new color.
function color_lib.fromCMYK( cyan, magenta, yellow, black )
    cyan, magenta, yellow, black = cyan * 0.01, magenta * 0.01, yellow * 0.01, black * 0.01

    local mk = 1 - black

    return fromRGB(
        math_floor( ((1 - cyan) * mk) * 255 ),
        math_floor( ((1 - magenta) * mk) * 255 ),
        math_floor( ((1 - yellow) * mk) * 255 )
    )
end

--- [SHARED AND MENU]
---
--- Returns the color as CMYK values (cyan, magenta, yellow, black).
---
---@param color dreamwork.std.Color The color to convert to CMYK.
---@return number cyan The cyan as fraction [0, 1].
---@return number magenta The magenta as fraction [0, 1].
---@return number yellow The yellow as fraction [0, 1].
---@return number black The black as fraction [0, 1].
function color_lib.toCMYK( color )
    local red, green, blue = toRGB( color )
    local m = math_max( red, green, blue )
    return (m - red) / m, (m - green) / m, (m - blue) / m, math_min( red, green, blue ) * DIV255_CONST
end

--- [SHARED AND MENU]
---
--- Returns the color's hue.
---
---@param color dreamwork.std.Color The color to get the hue of.
---@return integer hue The hue in degrees [0, 360].
function color_lib.getHue( color )
    local red, green, blue = toRGB( color )
    red, green, blue = red * DIV255_CONST, green * DIV255_CONST, blue * DIV255_CONST

    local max_value = math_max( red, green, blue )
    local delta = max_value - math_min( red, green, blue )

    if delta == 0 then
        return 0
    end

    local hue
    if max_value == red then
        hue = ((green - blue) / delta) % 6
    elseif max_value == green then
        hue = ((blue - red) / delta) + 2
    else
        hue = ((red - green) / delta) + 4
    end

    hue = hue * 60

    return hue < 0 and hue + 360 or hue
end

--- [SHARED AND MENU]
---
--- Sets the color's hue.
---
---@param color dreamwork.std.Color The color to set the hue of.
---@param hue integer The hue in degrees [0, 360].
---@return dreamwork.std.Color new_color The new color.
function color_lib.setHue( color, hue )
    local _, saturation, lightness = toHSL( color )
    return fromHSL( hue, saturation, lightness )
end

--- [SHARED AND MENU]
---
--- Returns the color's saturation.
---
---@param color dreamwork.std.Color The color to get the saturation of.
---@return number saturation The saturation as fraction [0, 1].
function color_lib.getSaturation( color )
    local red, green, blue = toRGB( color )
    red, green, blue = red * DIV255_CONST, green * DIV255_CONST, blue * DIV255_CONST

    local max_value = math_max( red, green, blue )
    return max_value == 0 and 0 or (max_value - math_min( red, green, blue )) / max_value
end

--- [SHARED AND MENU]
---
--- Sets the color's saturation.
---
---@param color dreamwork.std.Color The color to set the saturation of.
---@param saturation number The saturation as fraction [0, 1].
---@return dreamwork.std.Color new_color The new color.
function color_lib.setSaturation( color, saturation )
    local hue, _, lightness = toHSL( color )
    return fromHSL( hue, saturation, lightness )
end

--- [SHARED AND MENU]
---
--- Returns the color's brightness.
---
---@param color dreamwork.std.Color The color to get the brightness of.
---@return number brightness The brightness as fraction [0, 1].
function color_lib.getBrightness( color )
    local red, green, blue = toRGB( color )
    return math_max( red, green, blue ) * DIV255_CONST
end

--- [SHARED AND MENU]
---
--- Sets the color's brightness.
---
---@param color dreamwork.std.Color The color to set the brightness of.
---@param brightness number The brightness as fraction [0, 1].
---@return dreamwork.std.Color new_color The new color.
function color_lib.setBrightness( color, brightness )
    local hue, saturation, _ = toHSV( color )
    return fromHSV( hue, saturation, brightness )
end

--- [SHARED AND MENU]
---
--- Returns the color's lightness.
---
---@param color dreamwork.std.Color The color to get the lightness of.
---@return number lightness The lightness as fraction [0, 1].
function color_lib.getLightness( color )
    local red, green, blue = toRGB( color )
    red, green, blue = red * DIV255_CONST, green * DIV255_CONST, blue * DIV255_CONST

    return (math_max( red, green, blue ) + math_min( red, green, blue )) * 0.5
end

--- [SHARED AND MENU]
---
--- Sets the color's lightness.
---
---@param color dreamwork.std.Color The color to set the lightness of.
---@param lightness number The lightness as fraction [0, 1].
---@return dreamwork.std.Color new_color The new color.
function color_lib.setLightness( color, lightness )
    local hue, saturation, _ = toHSL( color )
    return fromHSL( hue, saturation, lightness )
end

--- [SHARED AND MENU]
---
--- Returns the color's whiteness.
---
---@param color dreamwork.std.Color The color to get the whiteness of.
---@return number whiteness The whiteness as fraction [0, 1].
function color_lib.getWhiteness( color )
    local _, saturation, brightness = toHSL( color )
    return (1 - saturation) * brightness
end

--- [SHARED AND MENU]
---
--- Sets the color's whiteness.
---
---@param color dreamwork.std.Color The color to set the whiteness of.
---@param whiteness number The whiteness as fraction [0, 1].
---@return dreamwork.std.Color new_color The new color.
function color_lib.setWhiteness( color, whiteness )
    local hue, _, blackness = toHWB( color )
    return fromHWB( hue, whiteness, blackness )
end

--- [SHARED AND MENU]
---
--- Returns the color's blackness.
---
---@param color dreamwork.std.Color The color to get the blackness of.
---@return number blackness The blackness as fraction [0, 1].
function color_lib.getBlackness( color )
    local _, __, brightness = toHSL( color )
    return 1 - brightness
end

--- [SHARED AND MENU]
---
--- Sets the color's blackness.
---
---@param color dreamwork.std.Color The color to set the blackness of.
---@param blackness number The blackness as fraction [0, 1].
---@return dreamwork.std.Color new_color The new color.
function color_lib.setBlackness( color, blackness )
    local hue, saturation, _ = toHSL( color )
    return fromHSL( hue, saturation, blackness )
end

--- [SHARED AND MENU]
---
--- Returns the color's luminance.
---
---@param color dreamwork.std.Color The color to get the luminance of.
---@return number luminance The luminance as integer [0, 255].
function color_lib.getLuminance( color )
    local red, green, blue = toRGB( color )
    return math_ceil( red * 0.2126 + green * 0.7152 + blue * 0.0722 )
end

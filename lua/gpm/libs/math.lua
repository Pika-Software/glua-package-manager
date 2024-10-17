local _module_0 = { }
local _G = _G
local math, tonumber = _G.math, _G.tonumber
local abs, atan2, ceil, min, max, random, sqrt, pow, floor, log, pi = math.abs, math.atan2, math.ceil, math.min, math.max, math.random, math.sqrt, math.pow, math.floor, math.log, math.pi
local rep, format
do
	local _obj_0 = _G.string
	rep, format = _obj_0.rep, _obj_0.format
end
local concat
do
	local _obj_0 = _G.table
	concat = _obj_0.concat
end
-- Constants
local e = math.exp(1)
_module_0["e"] = e
local ln10 = log(10)
_module_0["ln10"] = ln10
local ln2 = log(2)
_module_0["ln2"] = ln2
local log10e = log(e, 10)
_module_0["log10e"] = log10e
local log2e = log(e, 2)
_module_0["log2e"] = log2e
local sqrt1_2 = sqrt(0.5)
_module_0["sqrt1_2"] = sqrt1_2
local sqrt2 = sqrt(2)
_module_0["sqrt2"] = sqrt2
local maxinteger = 0x7FFFFFFF
_module_0["maxinteger"] = maxinteger
local mininteger = -0x80000000
_module_0["mininteger"] = mininteger
local pow2 = setmetatable({
	[0] = 1.0,
	[1] = 2.0,
	[2] = 4.0,
	[3] = 8.0,
	[4] = 16.0,
	[5] = 32.0,
	[6] = 64.0,
	[7] = 128.0,
	[8] = 256.0,
	[9] = 512.0,
	[10] = 1024.0
}, {
	__index = function(self, n)
		local v = pow(2.0, n)
		rawset(self, n, v)
		return v
	end
})
_module_0["pow2"] = pow2
local mod2 = setmetatable({
	[0] = 0,
	[1] = 1,
	[2] = 0,
	[3] = 1,
	[4] = 0,
	[5] = 1,
	[6] = 0,
	[7] = 1,
	[8] = 0,
	[9] = 1,
	[10] = 0
}, {
	__index = function(self, n)
		local v = n % 2
		rawset(self, n, v)
		return v
	end
})
_module_0["mod2"] = mod2
-- https://github.com/ToxicFrog/vstruct/blob/master/frexp.lua
local frexp = math.frexp or function(x)
	if x == 0 then
		return 0.0, 0.0
	end
	e = floor(log(abs(x)) / ln2)
	if e > 0 then
		x = x * pow2[-e]
	else
		x = x / pow2[e]
	end
	-- Normalize to the range [0.5,1)
	if abs(x) >= 1.0 then
		x, e = x / 2, e + 1
	end
	return x, e
end
_module_0["frexp"] = frexp
-- is checks
local isuint
isuint = function(n)
	return n >= 0 and (n % 1) == 0
end
_module_0["isuint"] = isuint
local isfloat
isfloat = function(n)
	return (n % 1) ~= 0
end
_module_0["isfloat"] = isfloat
local isint
isint = function(n)
	return (n % 1) == 0
end
_module_0["isint"] = isint
local isequalwith
isequalwith = function(a, b, tolerance)
	return abs(a - b) <= tolerance
end
_module_0["isequalwith"] = isequalwith
local isdivideable
isdivideable = function(n, d)
	return (n % d) == 0
end
_module_0["isdivideable"] = isdivideable
local isbool
isbool = function(n)
	return n == 0 or n == 1
end
_module_0["isbool"] = isbool
local iseven
iseven = function(n)
	return mod2[n] == 0
end
_module_0["iseven"] = iseven
local isodd
isodd = function(n)
	return mod2[n] == 1
end
_module_0["isodd"] = isodd
local inf = 1 / 0
_module_0["inf"] = inf
local isinf
isinf = function(n)
	return n == inf
end
_module_0["isinf"] = isinf
local nan = 0 / 0
_module_0["nan"] = nan
local isnan
isnan = function(n)
	return n == nan
end
_module_0["isnan"] = isnan
local isfinite
isfinite = function(n)
	return not (isinf(n) or isnan(n))
end
_module_0["isfinite"] = isfinite
local ispositive
ispositive = function(n)
	return n > 0 or 1 / n == inf
end
_module_0["ispositive"] = ispositive
local isnegative
isnegative = function(n)
	return n < 0 or 1 / n == -inf
end
_module_0["isnegative"] = isnegative
-- Sign
local sign
sign = function(n)
	return ispositive(n) and 1 or -1
end
_module_0["sign"] = sign
-- Rounding
local round
round = function(n, d)
	if d then
		local l = pow(10, d)
		return floor(n * l + 0.5) / l
	end
	return floor(n + 0.5)
end
_module_0["round"] = round
local nearest
nearest = function(n, d)
	return round(n / d) * d
end
_module_0["nearest"] = nearest
local trunc
trunc = function(n, d)
	if d then
		local l = pow(10, d)
		return (n < 0 and ceil or floor)(n * l) / l
	end
	return (n < 0 and ceil or floor)(n)
end
_module_0["trunc"] = trunc
-- Logarithms
local log1p
log1p = function(n)
	return log(n + 1)
end
_module_0["log1p"] = log1p
local log2
log2 = function(n)
	return log(n) / ln2
end
_module_0["log2"] = log2
-- Other
local rand
rand = function(a, b)
	return a + (b - a) * random()
end
_module_0["rand"] = rand
local fdiv
fdiv = function(a, b)
	return floor(a / b)
end
_module_0["fdiv"] = fdiv
local hypot
hypot = function(...)
	local s = 0
	local _list_0 = {
		...
	}
	for _index_0 = 1, #_list_0 do
		local n = _list_0[_index_0]
		s = s + pow(n, 2)
	end
	return sqrt(s)
end
_module_0["hypot"] = hypot
local cbrt
cbrt = function(n)
	return pow(n, 1 / 3)
end
_module_0["cbrt"] = cbrt
local root
root = function(n, d)
	return pow(n, 1 / d)
end
_module_0["root"] = root
local timef
timef = function(c, s, f)
	return (c - s) / (f - s)
end
_module_0["timef"] = timef
local approach
approach = function(a, b, d)
	local c = b - a
	return a + sign(c) * min(abs(c), d)
end
_module_0["approach"] = approach
-- Binary/Decimal/Hexadecimal
local binary2decimal
binary2decimal = function(s)
	return tonumber(s, 2)
end
_module_0["binary2decimal"] = binary2decimal
local decimal2binary
decimal2binary = function(n, complement)
	if n == 0 then
		if complement then
			return "00000000", 8
		end
		return "0", 1
	end
	sign = n < 0
	if sign then
		n = -n
	end
	local bits, length
	if sign then
		bits, length = {
			"-"
		}, 1
	else
		bits, length = { }, 0
	end
	while n > 0 do
		length = length + 1
		bits[length] = n % 2 == 0 and "0" or "1"
		n = floor(n / 2)
	end
	length = length + 1
	for index = 1, floor(length / 2), 1 do
		bits[index], bits[length - index] = bits[length - index], bits[index]
	end
	length = length - 1
	if complement then
		local zeros = max(8, 2 ^ ceil(log(length) / ln2)) - length
		return rep("0", zeros) .. concat(bits, "", 1, length), length + zeros
	end
	return concat(bits, "", 1, length), length
end
_module_0["decimal2binary"] = decimal2binary
local hex2decimal
hex2decimal = function(s)
	return tonumber(s, 16)
end
_module_0["hex2decimal"] = hex2decimal
local decimal2hex
decimal2hex = function(n)
	return format("%X", n)
end
_module_0["decimal2hex"] = decimal2hex
local hex2binary
hex2binary = function(s)
	return decimal2binary(hex2decimal(s))
end
_module_0["hex2binary"] = hex2binary
local binary2hex
binary2hex = function(s)
	return decimal2hex(binary2decimal(s))
end
_module_0["binary2hex"] = binary2hex
-- Arithmetic
local add
add = function(a, b)
	return a + b
end
_module_0["add"] = add
local sub
sub = function(a, b)
	return a - b
end
_module_0["sub"] = sub
local mul
mul = function(a, b)
	return a * b
end
_module_0["mul"] = mul
local div
div = function(a, b)
	return a / b
end
_module_0["div"] = div
local mod
mod = function(n, d)
	return n - d * floor(n / d)
end
_module_0["mod"] = mod
local split
split = function(a)
	return floor(a), a % 1
end
_module_0["split"] = split
-- Clamp
local clamp
clamp = function(n, a, b)
	return min(max(n, a), b)
end
_module_0["clamp"] = clamp
local clamp01
clamp01 = function(n)
	return clamp(n, 0, 1)
end
_module_0["clamp01"] = clamp01
-- Lerp
local lerp
lerp = function(d, a, b)
	return a + (b - a) * d
end
_module_0["lerp"] = lerp
local lerp01
lerp01 = function(d, a, b)
	return lerp(a, b, clamp01(d))
end
_module_0["lerp01"] = lerp01
-- Inverse Lerp
local ilerp
ilerp = function(d, a, b)
	return (d - a) / (b - a)
end
_module_0["ilerp"] = ilerp
local ilerp01
ilerp01 = function(d, a, b)
	return ilerp(clamp01(d), a, b)
end
_module_0["ilerp01"] = ilerp01
-- Remap
local remap
remap = function(n, a, b, c, d)
	return c + (d - c) * (n - a) / (b - a)
end
_module_0["remap"] = remap
local remap01
remap01 = function(n, a, b)
	return remap(n, a, b, 0, 1)
end
_module_0["remap01"] = remap01
-- Snap
local snap
snap = function(n, a)
	return floor(n / a + 0.5) * a
end
_module_0["snap"] = snap
-- Degrees and Radians
local dtor
dtor = function(n)
	return n * pi / 180
end
_module_0["dtor"] = dtor
local rtod
rtod = function(n)
	return n * 180 / pi
end
_module_0["rtod"] = rtod
-- Angle
local angle
angle = function(x1, y1, x2, y2)
	return rtod(atan2(y2 - y1, x2 - x1))
end
_module_0["angle"] = angle
local anorm
anorm = function(a)
	return ((a + 180) % 360) - 180
end
_module_0["anorm"] = anorm
local adiff
adiff = function(a1, a2)
	local diff = anorm(a1 - a2)
	if diff < 180 then
		return diff
	end
	return diff - 360
end
_module_0["adiff"] = adiff
-- Magnitude
local magnitude
magnitude = function(x1, y1, x2, y2)
	return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2))
end
_module_0["magnitude"] = magnitude
-- Normalize
local direction
direction = function(x1, y1, x2, y2)
	local diff = magnitude(x1, y1, x2, y2)
	if diff == 0 then
		return 0, 0
	end
	return (x2 - x1) / diff, (y2 - y1) / diff
end
_module_0["direction"] = direction
-- Dot
local dot
dot = function(x1, y1, x2, y2)
	return x1 * x2 + y1 * y2
end
_module_0["dot"] = dot
-- Range
local isinrange
isinrange = function(n, a, b)
	return n >= a and n <= b
end
_module_0["isinrange"] = isinrange
local trianglesign
trianglesign = function(x1, y1, x2, y2, x3, y3)
	return (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3)
end
_module_0["trianglesign"] = trianglesign
local inrect
inrect = function(x, y, x1, y1, x2, y2)
	return isinrange(x, x1, x2) and isinrange(y, y1, y2)
end
_module_0["inrect"] = inrect
local incircle
incircle = function(x, y, cx, cy, r)
	return pow(x - cx, 2) + pow(y - cy, 2) <= pow(r, 2)
end
_module_0["incircle"] = incircle
local ontangent
ontangent = function(x, y, x1, y1, x2, y2)
	return trianglesign(x, y, x1, y1, x2, y2) == 0
end
_module_0["ontangent"] = ontangent
local intriangle
intriangle = function(x, y, x1, y1, x2, y2, x3, y3)
	return trianglesign(x, y, x1, y1, x2, y2) * trianglesign(x, y, x2, y2, x3, y3) > 0
end
_module_0["intriangle"] = intriangle
local inpoly
inpoly = function(x, y, poly)
	local inside, length = false, #poly
	local j = length
	for i = 1, length do
		local px, py, lpx, lpy = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
		if (py < y and lpy >= y or lpy < y and py >= y) and (px + (y - py) / (lpy - py) * (lpx - px) < x) then
			inside = not inside
		end
		j = i
	end
	return inside
end
_module_0["inpoly"] = inpoly
return _module_0

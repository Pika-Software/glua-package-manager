local _module_0 = { }
--[[
    MIT License

    Copyright (c) 2024 Pika Software

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
--]]
local type, tostring, tonumber, rawget, rawset, getmetatable, pairs = _G.type, _G.tostring, _G.tonumber, _G.rawget, _G.rawset, _G.getmetatable, _G.pairs
local byte, char, sub, gsub, lower, format = string.byte, string.char, string.sub, string.gsub, string.lower, string.format
local rshift, lshift, band, bor
do
	local _obj_0 = (bit or bit32)
	rshift, lshift, band, bor = _obj_0.rshift, _obj_0.lshift, _obj_0.band, _obj_0.bor
end
local concat, remove = table.concat, table.remove
local floor = math.floor
-- a quirky way to check if number have metatable
-- if it has, then we can use getmetatable and have even faster isnumber function
local isstring
do
	local stringMeta = getmetatable("")
	if stringMeta then
		isstring = function(v)
			return getmetatable(v) == stringMeta
		end
	end
end
local isnumber
do
	local numberMeta = getmetatable(0)
	if numberMeta then
		isnumber = function(v)
			return getmetatable(v) == numberMeta
		end
	end
end
-- Garry's Mod have is<type> functions, prefer them because they are faster than type
isstring = isstring or function(v)
	return type(v) == "string"
end
local istable = istable or function(v)
	return type(v) == "table"
end
isnumber = isnumber or function(v)
	return type(v) == "number"
end
local compileCharacterTable
compileCharacterTable = function(chars)
	local result = { }
	for _index_0 = 1, #chars do
		local v = chars[_index_0]
		if istable(v) then
			for i = byte(v[1]), byte(v[2]) do
				result[i] = true
			end
		else
			result[byte(v)] = true
		end
	end
	return result
end
-- Use result from `compileCharacterTable` in `containsCharacter` as chars
local containsCharacter
containsCharacter = function(str, chars, startPos, endPos)
	if startPos == nil then
		startPos = 1
	end
	if endPos == nil then
		endPos = #str
	end
	for i = startPos, endPos do
		if chars[byte(str, i)] then
			return true
		end
	end
	return false
end
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
local FORBIDDEN_HOST_CODE_POINTS = compileCharacterTable({
	"\0",
	"\t",
	"\n",
	"\r",
	" ",
	"#",
	"/",
	":",
	"<",
	">",
	"?",
	"@",
	"[",
	"\\",
	"]",
	"^",
	"|"
})
local FORBIDDEN_DOMAIN_CODE_POINTS = compileCharacterTable({
	"\0",
	"\t",
	"\n",
	"\r",
	" ",
	"#",
	"/",
	":",
	"<",
	">",
	"?",
	"@",
	"[",
	"\\",
	"]",
	"^",
	"|",
	{
		"\0",
		"\x1F"
	},
	"%",
	"\x7F"
})
local FILE_OTHERWISE_CODE_POINTS = compileCharacterTable({
	"/",
	"\\",
	"?",
	"#"
})
local DECODE_LOOKUP_TABLE = { }
for i = 0x00, 0xFF do
	local hex = bit.tohex(i, 2)
	DECODE_LOOKUP_TABLE[hex] = char(i)
	DECODE_LOOKUP_TABLE[hex:upper()] = char(i)
end
local URI_DECODE_SET
do
	local _tab_0 = { }
	local _idx_0 = 1
	for _key_0, _value_0 in pairs(DECODE_LOOKUP_TABLE) do
		if _idx_0 == _key_0 then
			_tab_0[#_tab_0 + 1] = _value_0
			_idx_0 = _idx_0 + 1
		else
			_tab_0[_key_0] = _value_0
		end
	end
	URI_DECODE_SET = _tab_0
end
local _list_0 = {
	0x2D,
	0x2E,
	0x21,
	0x7E,
	0x2A,
	0x27,
	0x28,
	0x29
}
for _index_0 = 1, #_list_0 do
	local i = _list_0[_index_0]
	local hex = bit.tohex(i, 2)
	URI_DECODE_SET[hex] = nil
	URI_DECODE_SET[hex:upper()] = nil
end
local percentDecode
percentDecode = function(s, decodeSet)
	s = gsub(s, "%%(%x%x)", decodeSet)
	return s
end
local compilePercentEncodeSet
compilePercentEncodeSet = function(encodeSet, ...)
	-- Lookup table for decoding percent-encoded characters and encoding special characters
	-- Using HEX_TABLE will result in a double speedup compared to using functions
	do
		local _tab_0 = { }
		local _idx_0 = 1
		for _key_0, _value_0 in pairs(encodeSet) do
			if _idx_0 == _key_0 then
				_tab_0[#_tab_0 + 1] = _value_0
				_idx_0 = _idx_0 + 1
			else
				_tab_0[_key_0] = _value_0
			end
		end
		encodeSet = _tab_0
	end
	local _list_1 = {
		...
	}
	for _index_0 = 1, #_list_1 do
		local ch = _list_1[_index_0]
		if isstring(ch) then
			ch = byte(ch)
		end
		if isnumber(ch) then
			encodeSet[char(ch)] = "%" .. bit.tohex(ch, 2):upper()
		elseif istable(ch) then
			local charStart = isstring(ch[1]) and byte(ch[1]) or ch[1]
			local charEnd = isstring(ch[2]) and byte(ch[2]) or ch[2]
			for i = charStart, charEnd do
				encodeSet[char(i)] = "%" .. bit.tohex(i, 2):upper()
			end
		end
	end
	return encodeSet
end
local percentEncode
percentEncode = function(s, encodeSet, spaceAsPlus)
	local old = nil
	if spaceAsPlus == true then
		old = encodeSet[" "]
		encodeSet[" "] = "+"
	end
	s = gsub(s, "%W", encodeSet)
	if old then
		encodeSet[" "] = old
	end
	return s
end
local C0_ENCODE_SET = compilePercentEncodeSet({ }, {
	0x00,
	0x1F
}, {
	0x7F,
	0xFF
})
local FRAGMENT_ENCODE_SET = compilePercentEncodeSet(C0_ENCODE_SET, " ", "\"", "<", ">", "`")
local QUERY_ENCODE_SET = compilePercentEncodeSet(C0_ENCODE_SET, " ", "\"", "#", "<", ">")
local SPECIAL_QUERY_ENCODE_SET = compilePercentEncodeSet(QUERY_ENCODE_SET, "'")
local PATH_ENCODE_SET = compilePercentEncodeSet(QUERY_ENCODE_SET, "?", "`", "{", "}")
local USERINFO_ENCODE_SET = compilePercentEncodeSet(PATH_ENCODE_SET, "/", ":", ";", "=", "@", {
	0x5B,
	0x5E
}, "|")
local COMPONENT_ENCODE_SET = compilePercentEncodeSet(USERINFO_ENCODE_SET, {
	0x24,
	0x26
}, "+", ",")
local URLENCODED_ENCODE_SET = compilePercentEncodeSet(COMPONENT_ENCODE_SET, "!", {
	0x27,
	0x29
}, "~")
local URI_ENCODE_SET = compilePercentEncodeSet(C0_ENCODE_SET, 0x20, 0x22, 0x25, 0x3C, 0x3E, {
	0x42,
	0x59
}, {
	0x5B,
	0x5E
}, 0x60, {
	0x62,
	0x79
}, {
	0x7B,
	0x7D
})
local encodeURI
encodeURI = function(s)
	return percentEncode(s, URI_ENCODE_SET)
end
_module_0["encodeURI"] = encodeURI
local encodeURIComponent
encodeURIComponent = function(s)
	return percentEncode(s, COMPONENT_ENCODE_SET, true)
end
_module_0["encodeURIComponent"] = encodeURIComponent
local decodeURIComponent
decodeURIComponent = function(s)
	return percentDecode(s, DECODE_LOOKUP_TABLE)
end
_module_0["decodeURIComponent"] = decodeURIComponent
local decodeURI
decodeURI = function(s)
	return percentDecode(s, URI_DECODE_SET)
end
_module_0["decodeURI"] = decodeURI
local isLower
isLower = function(ch)
	return ch >= 0x61 and ch <= 0x7A
end
local isUpper
isUpper = function(ch)
	return ch >= 0x41 and ch <= 0x5A
end
local isAlpha
isAlpha = function(ch)
	return isLower(ch) or isUpper(ch)
end
local isDigit
isDigit = function(ch)
	return ch >= 0x30 and ch <= 0x39
end
local isHexDigit
isHexDigit = function(ch)
	return isDigit(ch) or ch >= 0x41 and ch <= 0x46 or ch >= 0x61 and ch <= 0x66
end
local isSingleDot
isSingleDot = function(str)
	local _exp_0 = #str
	if 1 == _exp_0 then
		return str == "."
	elseif 3 == _exp_0 then
		return lower(str) == "%2e"
	else
		return false
	end
end
local isDoubleDot
isDoubleDot = function(str)
	local _exp_0 = #str
	if 2 == _exp_0 then
		return str == ".."
	elseif 4 == _exp_0 then
		str = lower(str)
		return str == "%2e." or str == ".%2e"
	elseif 6 == _exp_0 then
		return lower(str) == "%2e%2e"
	else
		return false
	end
end
local isWindowsDriveLetterCodePoints
isWindowsDriveLetterCodePoints = function(ch1, ch2, normalized)
	return isAlpha(ch1) and (ch2 == 0x3A or (normalized == false and ch2 == 0x7C))
end
local isWindowsDriveLetter
isWindowsDriveLetter = function(str, normalized)
	return #str == 2 and isWindowsDriveLetterCodePoints(byte(str, 1), byte(str, 2), normalized)
end
local startsWithWindowsDriveLetter
startsWithWindowsDriveLetter = function(str, startPos, endPos)
	local len = endPos - startPos + 1
	return len >= 2 and isWindowsDriveLetterCodePoints(byte(str, startPos), byte(str, startPos + 1), false) and (len == 2 or FILE_OTHERWISE_CODE_POINTS[byte(str, startPos + 2)])
end
-- Converts character to digit,
-- if given non valid character it will return invalid number
local charToDec
charToDec = function(ch)
	return ch - 0x30
end
local hexToDec
hexToDec = function(ch)
	if ch >= 0x61 then
		return ch - 0x61 + 10
	elseif ch >= 0x41 then
		return ch - 0x41 + 10
	else
		return charToDec(ch)
	end
end
-- Finds nearest non whitespace character from startPos to endPos
-- And returns the position of that character
local trimInput
trimInput = function(str, startPos, endPos)
	for i = startPos, endPos, (startPos < endPos and 1 or -1) do
		local ch = byte(str, i)
		if not ch or ch > 0x20 then
			return i
		end
	end
	return endPos - 1
end
-- UTF-8 decoder from https://bjoern.hoehrmann.de/utf-8/decoder/dfa/
local UTF8_DECODE_LOOKUP = { }
do
	local UTF8_DECODE_LOOKUP_RULES = {
		{
			0,
			0x00,
			0x7f
		},
		{
			1,
			0x80,
			0x8f
		},
		{
			9,
			0x90,
			0x9f
		},
		{
			7,
			0xa0,
			0xbf
		},
		{
			8,
			0xc0,
			0xc1
		},
		{
			2,
			0xc2,
			0xdf
		},
		{
			0xa,
			0xe0
		},
		{
			0x3,
			0xe1,
			0xef
		},
		{
			0xb,
			0xf0
		},
		{
			0x6,
			0xf1,
			0xf3
		},
		{
			0x5,
			0xf4
		},
		{
			0x8,
			0xf5,
			0xff
		},
		{
			0x0,
			0x100
		},
		{
			0x1,
			0x101
		},
		{
			0x2,
			0x102
		},
		{
			0x3,
			0x103
		},
		{
			0x5,
			0x104
		},
		{
			0x8,
			0x105
		},
		{
			0x7,
			0x106
		},
		{
			0x1,
			0x107,
			0x10f
		},
		{
			0x4,
			0x10a
		},
		{
			0x6,
			0x10b
		},
		{
			1,
			0x110,
			0x12f
		},
		{
			0,
			0x121
		},
		{
			0,
			0x127
		},
		{
			0,
			0x129
		},
		{
			1,
			0x130,
			0x14f
		},
		{
			2,
			0x131
		},
		{
			2,
			0x137
		},
		{
			2,
			0x139
		},
		{
			2,
			0x147
		},
		{
			1,
			0x150,
			0x16f
		},
		{
			2,
			0x151
		},
		{
			2,
			0x159
		},
		{
			3,
			0x167
		},
		{
			3,
			0x169
		},
		{
			1,
			0x170,
			0x18f
		},
		{
			3,
			0x171
		},
		{
			3,
			0x177
		},
		{
			3,
			0x179
		},
		{
			3,
			0x181
		}
	}
	for _index_0 = 1, #UTF8_DECODE_LOOKUP_RULES do
		local rule = UTF8_DECODE_LOOKUP_RULES[_index_0]
		if rule[3] then
			for i = rule[2], rule[3] do
				UTF8_DECODE_LOOKUP[i] = rule[1]
			end
		else
			UTF8_DECODE_LOOKUP[rule[2]] = rule[1]
		end
	end
end
local utf8Decode
utf8Decode = function(str, startPos, endPos)
	-- TODO add support for fullwidth utf8/utf16
	local output = { }
	local count = 0
	local state = 0
	local codep = 0
	for i = startPos, endPos do
		local b = byte(str, i)
		local t = UTF8_DECODE_LOOKUP[b]
		codep = (state ~= 0) and bor(band(b, 0x3f), lshift(codep, 6)) or band(rshift(0xff, t), b)
		state = UTF8_DECODE_LOOKUP[256 + state * 16 + t]
		if state == 0 then
			count = count + 1
			output[count] = codep
		end
	end
	if state ~= 0 then
		error("Invalid URL: UTF-8 decoding error")
	end
	return output
end
-- RFC 3492 Punycode encode
local punycodeEncode
punycodeEncode = function(str, startPos, endPos)
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
	local input = utf8Decode(str, startPos, endPos)
	local inputLen = #input
	local output = { }
	local delta = 0
	local out = 0
	local bias = initialBias
	-- Handle the basic code points
	for _index_0 = 1, #input do
		local ch = input[_index_0]
		if ch < 0x80 then
			out = out + 1
			output[out] = char(ch)
		end
	end
	-- h is the number of code points that have been handled, b is the number of basic code points
	-- that have been handled, and out is the number of characters that have been output.
	local h = out
	local b = out
	if b > 0 then
		out = out + 1
		output[out] = char(delimiter)
	end
	-- Main encoding loop
	while h < inputLen do
		-- All non-basic code points < n have been handled already. Find the next larger one
		local m = 0x7FFFFFFF
		for _index_0 = 1, #input do
			local ch = input[_index_0]
			if ch >= n and ch < m then
				m = ch
			end
		end
		-- Increase delta enough to advance the decoder's <n,i> state to <m,0>, but guard against overflow
		if m - n > (0x7FFFFFFF - delta) / (h + 1) then
			error("Invalid URL: Punycode overflow")
		end
		delta = delta + ((m - n) * (h + 1))
		n = m
		for _index_0 = 1, #input do
			local ch = input[_index_0]
			-- Punycode does not need to check whether input[j] is basic:
			if ch < n then
				delta = delta + 1
				if delta + 1 > 0x7FFFFFFF then
					error("Invalid URL: Punycode overflow")
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
					output[out] = char(d + 22 + (d < 26 and 75 or 0))
					q = floor((q - t) / (base - t))
					k = k + base
				end
				out = out + 1
				output[out] = char(q + 22 + (q < 26 and 75 or 0))
				k = 0
				delta = h == b and floor(delta / damp) or rshift(delta, 1)
				delta = delta + floor(delta / (h + 1))
				while delta > ((base - tMin) * tMax) / 2 do
					delta = floor(delta / (base - tMin))
					k = k + base
				end
				bias = floor(k + (base - tMin + 1) * delta / (delta + skew))
				delta = 0
				h = h + 1
			end
		end
		delta = delta + 1
		n = n + 1
	end
	return concat(output, "", 1, out)
end
local parseIPv4InIPv6
parseIPv4InIPv6 = function(str, pointer, endPos, address, pieceIndex)
	local numbersSeen = 0
	while pointer <= endPos do
		local ipv4Piece = nil
		local ch = byte(str, pointer)
		if numbersSeen > 0 then
			if not (ch == 0x2E and numbersSeen < 4) then
				error("Invalid URL: IPv4 in IPv6 invalid code point")
			end
			pointer = pointer + 1
			ch = pointer <= endPos and byte(str, pointer)
		end
		while ch and isDigit(ch) do
			local num = charToDec(ch)
			if not ipv4Piece then
				ipv4Piece = num
			elseif ipv4Piece == 0 then
				error("Invalid URL: IPv4 in IPv6 invalid code point")
			else
				ipv4Piece = ipv4Piece * 10 + num
			end
			if ipv4Piece > 255 then
				error("Invalid URL: IPv4 in IPv6 out of range part")
			end
			pointer = pointer + 1
			ch = pointer <= endPos and byte(str, pointer)
		end
		if not ipv4Piece then
			error("Invalid URL: IPv4 in IPv6 invalid code point")
		end
		address[pieceIndex] = address[pieceIndex] * 0x100 + ipv4Piece
		numbersSeen = numbersSeen + 1
		if numbersSeen == 2 or numbersSeen == 4 then
			pieceIndex = pieceIndex + 1
		end
	end
	if numbersSeen ~= 4 then
		error("Invalid URL: IPv4 in IPv6 too few parts")
	end
	return pieceIndex
end
local parseIPv6
parseIPv6 = function(str, startPos, endPos)
	local address = {
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0
	}
	local pointer = startPos
	local pieceIndex = 1
	local compress = nil
	if byte(str, startPos) == 0x3A then
		if startPos == endPos or byte(str, startPos + 1) ~= 0x3A then
			error("Invalid URL: IPv6 invalid compression")
		end
		pointer = pointer + 2
		pieceIndex = 2
		compress = 2
	end
	while pointer <= endPos do
		if pieceIndex == 9 then
			error("Invalid URL: IPv6 too many pieces")
		end
		local ch = byte(str, pointer)
		if ch == 0x3A then
			if compress then
				error("Invalid URL: IPv6 multiple compression")
			end
			pointer = pointer + 1
			pieceIndex = pieceIndex + 1
			compress = pieceIndex
			goto _continue_0
		end
		local value = 0
		local length = 0
		while length < 4 and ch and isHexDigit(ch) do
			value = value * 0x10 + hexToDec(ch)
			pointer = pointer + 1
			length = length + 1
			ch = pointer <= endPos and byte(str, pointer)
		end
		if ch == 0x2E then
			if length == 0 then
				error("Invalud URL: IPv4 in IPv6 invalid code point")
			end
			pointer = pointer - length
			if pieceIndex > 7 then
				error("Invalid URL: IPv4 in IPv6 too many pieces")
			end
			pieceIndex = parseIPv4InIPv6(str, pointer, endPos, address, pieceIndex)
			break
		elseif ch == 0x3A then
			pointer = pointer + 1
			if pointer > endPos then
				error("Invalid URL: IPv6 invalid code point")
			end
		elseif pointer <= endPos then
			error("Invalid URL: IPv6 invalid code point")
		end
		address[pieceIndex] = value
		pieceIndex = pieceIndex + 1
		::_continue_0::
	end
	if compress then
		local swaps = pieceIndex - compress
		pieceIndex = 8
		while pieceIndex ~= 1 and swaps > 0 do
			local value = address[pieceIndex]
			address[pieceIndex] = address[compress + swaps - 1]
			address[compress + swaps - 1] = value
			swaps = swaps - 1
			pieceIndex = pieceIndex - 1
		end
	elseif pieceIndex ~= 9 then
		error("Invalid URL: IPv6 too few pieces")
	end
	return address
end
local parseIPv4Number
parseIPv4Number = function(str)
	if str == "" then
		return
	end
	local radix = 10
	local ch1 = byte(str, 1)
	local ch2 = byte(str, 2)
	if ch1 == 0x30 and (ch2 == 0x78 or ch2 == 0x58) then
		radix = 16
		if #str == 2 then
			str = "0"
		end
	elseif ch1 == 0x30 and ch2 then
		radix = 8
	end
	return tonumber(str, radix)
end
local endsInANumberChecker
endsInANumberChecker = function(str, startPos, endPos)
	-- find a starting point for number
	local numStart = startPos
	local numEnd = endPos
	for i = numEnd, numStart, -1 do
		if byte(str, i) == 0x2E then
			if i == endPos then
				numEnd = i - 1
			else
				numStart = i + 1
				break
			end
		end
	end
	-- sanity check, do not invoke parser if we have ONLY digits
	for i = numStart, numEnd do
		if not isDigit(byte(str, i)) then
			-- welp, let us try at least parse it, what if it is a hex number
			return parseIPv4Number(sub(str, numStart, numEnd))
		end
	end
	return numStart <= numEnd
end
local parseIPv4
parseIPv4 = function(str, startPos, endPos)
	local numbers = { }
	local pointer = startPos
	while true do
		local ch = pointer <= endPos and byte(str, pointer)
		if not ch or ch == 0x2E then
			local num = parseIPv4Number(sub(str, startPos, pointer - 1))
			if not num then
				if pointer > endPos and #numbers > 0 then
					break
				end
				error("Invalid URL: IPv4 non numeric part")
			end
			startPos = pointer + 1
			numbers[#numbers + 1] = num
			if not ch then
				break
			end
		end
		pointer = pointer + 1
	end
	if #numbers > 4 then
		error("Invalid URL: IPv4 too many parts")
	end
	for i = 1, #numbers - 1 do
		if numbers[i] > 255 then
			error("Invalid URL: IPv4 out of range part")
		end
	end
	if numbers[#numbers] >= 256 ^ (5 - #numbers) then
		error("Invalid URL: IPv4 out of range part")
	end
	local ipv4 = numbers[#numbers]
	local counter = 0
	for i = 1, #numbers - 1 do
		ipv4 = ipv4 + (numbers[i] * 256 ^ (3 - counter))
		counter = counter + 1
	end
	return ipv4
end
local domainToASCII
domainToASCII = function(domain)
	for i = 1, #domain do
		if byte(domain, i) > 0x7F then
			-- Remove special symbols that are ignored
			-- I probably really should implement some proper punycode
			domain = gsub(domain, "\xC2\xAD", "")
			domain = gsub(domain, "\xE3\x80\x82", ".")
			-- remove space characters
			domain = gsub(domain, "\xE2\x80\x8B", "")
			domain = gsub(domain, "\xE2\x81\xA0", "")
			domain = gsub(domain, "\xEF\xBB\xBF", "")
			break
		end
	end
	local containsNonASCII = false
	local doLowerCase = false
	local punycodePrefix = 0
	local partStart = 1
	local pointer = 1
	local parts = { }
	while true do
		local ch = byte(domain, pointer)
		if not ch or ch == 0x2E then
			-- decode an find errors
			if punycodePrefix == 4 and containsNonASCII then
				error("Invalid URL: Domain invalid code point")
			end
			local domainPart = containsNonASCII and "xn--" .. punycodeEncode(domain, partStart, pointer - 1) or sub(domain, partStart, pointer - 1)
			-- btw, punycode decode lowercases the domain, so we need to lowercase it
			-- in ideal sutiation I should have written punycodeDecode, but I am not in the mood to write it
			if doLowerCase then
				domainPart = lower(domainPart)
			end
			parts[#parts + 1] = domainPart
			partStart = pointer + 1
			containsNonASCII = false
			doLowerCase = false
			punycodePrefix = 0
			if not ch then
				break
			end
		elseif ch > 0x7F then
			containsNonASCII = true
		elseif PUNYCODE_PREFIX[pointer - partStart + 1] == ch then
			punycodePrefix = punycodePrefix + 1
		elseif isUpper(ch) then
			doLowerCase = true
		end
		pointer = pointer + 1
	end
	return concat(parts, ".")
end
local parseHostString
parseHostString = function(str, startPos, endPos, isSpecial)
	if byte(str, startPos) == 0x5B then
		if byte(str, endPos) ~= 0x5D then
			error("Invalid URL: IPv6 unclosed")
		end
		return parseIPv6(str, startPos + 1, endPos - 1)
	elseif not isSpecial then
		-- opaque host parsing
		if containsCharacter(str, FORBIDDEN_HOST_CODE_POINTS, startPos, endPos) then
			error("Invalid URL: Host invalid code point")
		end
		return percentEncode(sub(str, startPos, endPos), C0_ENCODE_SET)
	else
		local domain = percentDecode(sub(str, startPos, endPos), DECODE_LOOKUP_TABLE)
		local asciiDomain = domainToASCII(domain)
		if containsCharacter(asciiDomain, FORBIDDEN_DOMAIN_CODE_POINTS) then
			error("Invalid URL: Domain invalid code point")
		end
		if endsInANumberChecker(asciiDomain, 1, #asciiDomain) then
			return parseIPv4(asciiDomain, 1, #asciiDomain)
		end
		return asciiDomain
	end
end
-- Predefine locals so we can make functions in the order I want (as if you were reading specs)
local parseScheme, parseNoScheme, parseSpecialRelativeOrAuthority, parsePathOrAuthority
local parseRelative, parseRelativeSlash, parseSpecialAuthorityIgnoreSlashes, parseAuthority
local parseHost, parsePort, parseFile, parseFileSlash, parseFileHost, parsePathStart, parsePath, parseOpaquePath
local parseQuery, parseFragment
parseScheme = function(self, str, startPos, endPos, base, stateOverride)
	-- scheme start state
	if startPos <= endPos and isAlpha(byte(str, startPos)) then
		-- scheme state
		local doLowerCase = false
		local scheme = nil
		for i = startPos, endPos do
			local ch = byte(str, i)
			if ch == 0x3A then
				scheme = sub(str, startPos, i - 1)
				if doLowerCase then
					scheme = lower(scheme)
				end
				local isSpecial = SPECIAL_SCHEMAS[scheme]
				if stateOverride then
					local isUrlSpecial = self.scheme and SPECIAL_SCHEMAS[self.scheme]
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
					parseFile(self, str, i + 1, endPos, base)
				elseif isSpecial and base and base.scheme == scheme then
					-- special relative or authority state
					parseSpecialRelativeOrAuthority(self, str, i + 1, endPos, base, isSpecial)
				elseif isSpecial then
					-- special authority slashes state
					parseSpecialAuthorityIgnoreSlashes(self, str, i + 1, endPos, base, isSpecial)
				elseif byte(str, i + 1) == 0x2F then
					-- path or authority state
					parsePathOrAuthority(self, str, i + 2, endPos, base)
				else
					-- opaque path state
					parseOpaquePath(self, str, i + 1, endPos)
				end
				return
			elseif isUpper(ch) then
				doLowerCase = true
			elseif not isLower(ch) and not isDigit(ch) and ch ~= 0x2B and ch ~= 0x2D and ch ~= 0x2E then
				-- scheme have an invalid character, so it's not a scheme
				break
			end
		end
	end
	if not stateOverride then
		-- no scheme state
		return parseNoScheme(self, str, startPos, endPos, base)
	end
end
parseNoScheme = function(self, str, startPos, endPos, base)
	local startsWithFragment = byte(str, startPos) == 0x23
	local baseHasOpaquePath = base and isstring(base.path)
	if not base or (baseHasOpaquePath and not startsWithFragment) then
		error("Invalid URL: Missing scheme")
	end
	if baseHasOpaquePath and startsWithFragment then
		self.scheme = base.scheme
		self.path = base.path
		self.query = base.query
		return parseFragment(self, str, startPos + 1, endPos)
	elseif base.scheme ~= "file" then
		return parseRelative(self, str, startPos, endPos, base, SPECIAL_SCHEMAS[base.scheme])
	else
		self.scheme = "file"
		return parseFile(self, str, startPos, endPos, base)
	end
end
parseSpecialRelativeOrAuthority = function(self, str, startPos, endPos, base, isSpecial)
	if byte(str, startPos) == 0x2F and byte(str, startPos + 1) == 0x2F then
		-- special authority slashes state
		return parseSpecialAuthorityIgnoreSlashes(self, str, startPos + 2, endPos, base, isSpecial)
	else
		-- relative state
		self.scheme = base.scheme
		return parseRelative(self, str, startPos, endPos, base, isSpecial)
	end
end
parsePathOrAuthority = function(self, str, startPos, endPos, base)
	if byte(str, startPos) == 0x2F then
		return parseAuthority(self, str, startPos + 1, endPos)
	else
		return parsePath(self, str, startPos, endPos)
	end
end
parseRelative = function(self, str, startPos, endPos, base, isSpecial)
	self.scheme = base.scheme
	local ch = startPos <= endPos and byte(str, startPos)
	if ch == 0x2F or (isSpecial and ch == 0x5C) then
		-- relative slash state
		return parseRelativeSlash(self, str, startPos + 1, endPos, base, isSpecial)
	else
		self.username = base.username
		self.password = base.password
		self.hostname = base.hostname
		self.port = base.port
		local path
		do
			local _tab_0 = { }
			local _obj_0 = (base.path or { })
			local _idx_0 = 1
			for _key_0, _value_0 in pairs(_obj_0) do
				if _idx_0 == _key_0 then
					_tab_0[#_tab_0 + 1] = _value_0
					_idx_0 = _idx_0 + 1
				else
					_tab_0[_key_0] = _value_0
				end
			end
			path = _tab_0
		end
		self.path = path
		if ch == 0x3F then
			return parseQuery(self, str, startPos + 1, endPos)
		elseif ch == 0x23 then
			self.query = base.query
			return parseFragment(self, str, startPos + 1, endPos)
		elseif ch then
			local pathLen = #path
			if pathLen ~= 1 or not isWindowsDriveLetter(path[1]) then
				path[pathLen] = nil
			end
			return parsePath(self, str, startPos, endPos, isSpecial, path)
		end
	end
end
parseRelativeSlash = function(self, str, startPos, endPos, base, isSpecial)
	local ch = byte(str, startPos)
	if isSpecial and (ch == 0x2F or ch == 0x5C) then
		-- special authority ignore slashes state
		return parseSpecialAuthorityIgnoreSlashes(self, str, startPos + 1, endPos, base, isSpecial)
	elseif ch == 0x2F then
		-- authority state
		return parseAuthority(self, str, startPos + 1, endPos, isSpecial)
	else
		self.username = base.username
		self.password = base.password
		self.hostname = base.hostname
		self.port = base.port
		return parsePath(self, str, startPos, endPos, isSpecial)
	end
end
parseSpecialAuthorityIgnoreSlashes = function(self, str, startPos, endPos, base, isSpecial)
	for i = startPos, endPos do
		local ch = byte(str, i)
		if ch ~= 0x2F and ch ~= 0x5C then
			parseAuthority(self, str, i, endPos, isSpecial)
			break
		end
	end
end
parseAuthority = function(self, str, startPos, endPos, isSpecial)
	-- authority state
	local atSignSeen = false
	local passwordTokenSeen = false
	local pathEndPos = endPos
	for i = startPos, endPos do
		local ch = byte(str, i)
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
		error("Invalid URL: Missing host")
	end
	if atSignSeen then
		if passwordTokenSeen then
			self.username = percentEncode(sub(str, startPos, passwordTokenSeen - 1), USERINFO_ENCODE_SET)
			self.password = percentEncode(sub(str, passwordTokenSeen + 1, atSignSeen - 1), USERINFO_ENCODE_SET)
		else
			self.username = percentEncode(sub(str, startPos, atSignSeen - 1), USERINFO_ENCODE_SET)
		end
	end
	parseHost(self, str, atSignSeen and atSignSeen + 1 or startPos, endPos, isSpecial)
	return parsePathStart(self, str, endPos + 1, pathEndPos, isSpecial)
end
parseHost = function(self, str, startPos, endPos, isSpecial, stateOverride)
	if stateOverride and isSpecial == true then
		return parseFileHost(self, str, startPos, endPos, stateOverride)
	end
	local insideBrackets = false
	for i = startPos, endPos do
		local ch = byte(str, i)
		if ch == 0x3A and not insideBrackets then
			if i == startPos then
				error("Invalid URL: Missing host")
			end
			if stateOverride == "hostname" then
				return
			end
			parsePort(self, str, i + 1, endPos, isSpecial, stateOverride)
			endPos = i - 1
			break
		elseif ch == 0x5B then
			insideBrackets = true
		elseif ch == 0x5D then
			insideBrackets = false
		end
	end
	if isSpecial and startPos > endPos then
		error("Invalid URL: Missing host")
	elseif stateOverride and startPos == endPos and (self.username or self.password or self.port) then
		return
	end
	self.hostname = parseHostString(str, startPos, endPos, isSpecial)
end
parsePort = function(self, str, startPos, endPos, defaultPort, stateOverride)
	if startPos > endPos then
		return
	end
	local port = tonumber(sub(str, startPos, endPos))
	if not port or (port > 2 ^ 16 - 1) or port < 0 then
		if stateOverride then
			return
		end
		error("Invalid URL: Invalid port")
	end
	if port ~= defaultPort then
		self.port = port
	end
end
parseFile = function(self, str, startPos, endPos, base)
	self.scheme = "file"
	self.hostname = ""
	local ch = startPos <= endPos and byte(str, startPos)
	if ch == 0x2F or ch == 0x5C then
		return parseFileSlash(self, str, startPos + 1, endPos, base)
	elseif base and base.scheme == "file" then
		self.hostname = base.hostname
		local path
		do
			local _tab_0 = { }
			local _obj_0 = (base.path or { })
			local _idx_0 = 1
			for _key_0, _value_0 in pairs(_obj_0) do
				if _idx_0 == _key_0 then
					_tab_0[#_tab_0 + 1] = _value_0
					_idx_0 = _idx_0 + 1
				else
					_tab_0[_key_0] = _value_0
				end
			end
			path = _tab_0
		end
		self.path = path
		if ch == 0x3F then
			return parseQuery(self, str, startPos + 1, endPos)
		elseif ch == 0x23 then
			self.query = base.query
			return parseFragment(self, str, startPos + 1, endPos)
		elseif ch then
			local pathLen = #path
			if not startsWithWindowsDriveLetter(str, startPos, endPos) then
				if pathLen ~= 1 or not isWindowsDriveLetter(path[1]) then
					path[pathLen] = nil
				end
			else
				path = nil
			end
			return parsePath(self, str, startPos, endPos, true, path)
		end
	else
		return parsePath(self, str, startPos, endPos, true)
	end
end
parseFileSlash = function(self, str, startPos, endPos, base)
	local ch = byte(str, startPos)
	if ch == 0x2F or ch == 0x5C then
		return parseFileHost(self, str, startPos + 1, endPos)
	else
		local path = { }
		if base and base.scheme == "file" then
			self.hostname = base.hostname
			if not startsWithWindowsDriveLetter(str, startPos, endPos) and isWindowsDriveLetter(base.path[1], false) then
				path[1] = base.path[1]
			end
		end
		return parsePath(self, str, startPos, endPos, true, path)
	end
end
parseFileHost = function(self, str, startPos, endPos, stateOverride)
	local i = startPos
	while true do
		local ch = i <= endPos and byte(str, i)
		if ch == 0x2F or ch == 0x5C or ch == 0x3F or ch == 0x23 or not ch then
			local hostLen = i - startPos
			if not stateOverride and hostLen == 2 and isWindowsDriveLetterCodePoints(byte(str, startPos), byte(str, startPos + 1), false) then
				parsePath(self, str, startPos, endPos, true)
			elseif hostLen == 0 then
				self.hostname = ""
				if stateOverride then
					return
				end
				parsePathStart(self, str, i, endPos, true)
			else
				local hostname = parseHostString(str, startPos, i - 1, true)
				if hostname == "localhost" then
					hostname = ""
				end
				self.hostname = hostname
				if stateOverride then
					return
				end
				parsePathStart(self, str, i, endPos, true)
			end
			break
		end
		i = i + 1
	end
end
parsePathStart = function(self, str, startPos, endPos, isSpecial, stateOverride)
	local ch = startPos <= endPos and byte(str, startPos)
	if isSpecial then
		if ch == 0x2F or ch == 0x5C then
			startPos = startPos + 1
		end
		return parsePath(self, str, startPos, endPos, isSpecial, nil, stateOverride)
	elseif not stateOverride and ch == 0x3F then
		return parseQuery(self, str, startPos + 1, endPos)
	elseif not stateOverride and ch == 0x23 then
		return parseFragment(self, str, startPos + 1, endPos)
	elseif ch then
		if ch == 0x2F then
			startPos = startPos + 1
		end
		return parsePath(self, str, startPos, endPos, isSpecial, nil, stateOverride)
	elseif stateOverride and not self.hostname then
		local _obj_0 = self.path
		_obj_0[#_obj_0 + 1] = ""
	end
end
parsePath = function(self, str, startPos, endPos, isSpecial, segments, stateOverride)
	if segments == nil then
		segments = { }
	end
	local segmentsCount = #segments
	local hasWindowsLetter = segmentsCount ~= 0 and isWindowsDriveLetter(segments[1], false)
	local segmentStart = startPos
	local i = startPos
	while true do
		local ch = i <= endPos and byte(str, i)
		if ch == 0x2F or (isSpecial and ch == 0x5C) or (not stateOverride and (ch == 0x3F or ch == 0x23)) or not ch then
			local segment = percentEncode(sub(str, segmentStart, i - 1), PATH_ENCODE_SET)
			segmentStart = i + 1
			if isDoubleDot(segment) then
				if segmentsCount ~= 1 or not hasWindowsLetter then
					segments[segmentsCount] = nil
					segmentsCount = segmentsCount - 1
					if segmentsCount == -1 then
						segmentsCount = 0
					end
				end
				if ch ~= 0x2F and (isSpecial and ch ~= 0x5C) then
					segmentsCount = segmentsCount + 1
					segments[segmentsCount] = ""
				end
			elseif not isSingleDot(segment) then
				if isSpecial == true and segmentsCount == 0 and isWindowsDriveLetter(segment, false) then
					segment = gsub(segment, "|", ":")
					hasWindowsLetter = true
				end
				segmentsCount = segmentsCount + 1
				segments[segmentsCount] = segment
			elseif ch ~= 0x2F and (isSpecial and ch ~= 0x5C) then
				segmentsCount = segmentsCount + 1
				segments[segmentsCount] = ""
			end
			if ch == 0x3F then
				parseQuery(self, str, i + 1, endPos)
				break
			elseif ch == 0x23 then
				parseFragment(self, str, i + 1, endPos)
				break
			elseif not ch then
				break
			end
		end
		i = i + 1
	end
	self.path = segments
end
parseOpaquePath = function(self, str, startPos, endPos)
	for i = startPos, endPos do
		local ch = byte(str, i)
		if ch == 0x3F then
			parseQuery(self, str, i + 1, endPos)
			endPos = i - 1
			break
		elseif ch == 0x23 then
			parseFragment(self, str, i + 1, endPos)
			endPos = i - 1
			break
		end
	end
	self.path = percentEncode(sub(str, startPos, endPos), C0_ENCODE_SET)
end
parseQuery = function(self, str, startPos, endPos, isSpecial, stateOverride)
	for i = startPos, endPos do
		if not stateOverride and byte(str, i) == 0x23 then
			parseFragment(self, str, i + 1, endPos)
			endPos = i - 1
			break
		end
	end
	local encodeSet = isSpecial and SPECIAL_QUERY_ENCODE_SET or QUERY_ENCODE_SET
	self.query = percentEncode(sub(str, startPos, endPos), encodeSet)
end
-- This methods parses given query string to a list of name-value tuple
local parseQueryString
parseQueryString = function(str, output)
	if output == nil then
		output = { }
	end
	local pointer = 1
	local startPos = 1
	local name = nil
	local value = nil
	local containsPlus = false
	local count = 0
	while true do
		local ch = byte(str, pointer)
		if ch == 0x26 or not ch then
			value = sub(str, startPos, pointer - 1)
			if containsPlus then
				value = gsub(name, "%+", " ")
				containsPlus = false
			end
			if not name then
				name = value
				value = nil
			end
			if name ~= "" or value then
				name = percentDecode(name, DECODE_LOOKUP_TABLE)
				value = value and percentDecode(value, DECODE_LOOKUP_TABLE) or nil
				count = count + 1
				output[count] = {
					name,
					value
				}
			end
			name = nil
			value = nil
			startPos = pointer + 1
			if not ch then
				break
			end
		elseif ch == 0x3D then
			name = sub(str, startPos, pointer - 1)
			startPos = pointer + 1
			if containsPlus then
				name = gsub(name, "%+", " ")
				containsPlus = false
			end
		elseif ch == 0x2B then
			containsPlus = true
		end
		pointer = pointer + 1
	end
	return output
end
parseFragment = function(self, str, startPos, endPos)
	self.fragment = percentEncode(sub(str, startPos, endPos), FRAGMENT_ENCODE_SET)
end
local parse
parse = function(self, str, base)
	if not isstring(str) then
		error("Invalid URL: URL must be a string")
	end
	if isstring(base) then
		-- yeah, we dont even need to full URL object for this
		local url = { }
		parse(url, base)
		base = url
	end
	str = gsub(str, "[\t\n\r]", "")
	local startPos = 1
	local endPos = #str
	-- Trim leading and trailing whitespaces
	startPos = trimInput(str, startPos, endPos)
	endPos = trimInput(str, endPos, startPos)
	parseScheme(self, str, startPos, endPos, base)
	return self
end
_module_0["parse"] = parse
local serializeIPv6
serializeIPv6 = function(address)
	local output = { }
	local len = 0
	local compress = 0
	local compressLen = 0
	local zeroStart = 0
	-- Find first longest sequence of zeros
	for i = 1, 8 do
		if address[i] == 0 then
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
			if address[i] == 0 then
				goto _continue_0
			end
			ignore0 = false
		end
		if compress == i then
			len = len + 1
			output[len] = i == 1 and "::" or ":"
			ignore0 = true
			goto _continue_0
		end
		len = len + 1
		output[len] = format("%x", address[i])
		-- why format? because it returns hex without zeros (aka smallest hex value)
		if i ~= 8 then
			len = len + 1
			output[len] = ":"
		end
		::_continue_0::
	end
	return concat(output, "", 1, len)
end
local serializeHost
serializeHost = function(host)
	if istable(host) then
		return "[" .. serializeIPv6(host) .. "]"
	elseif isnumber(host) then
		local address = { }
		for i = 1, 4 do
			address[5 - i] = format("%u", host % 256)
			host = floor(host / 256)
		end
		return concat(address, ".")
	end
	return host
end
local serializeQuery
serializeQuery = function(query)
	if not istable(query) then
		return query
	end
	local output, length = { }, 0
	for _index_0 = 1, #query do
		local t = query[_index_0]
		if length > 0 then
			length = length + 1
			output[length] = "&"
		end
		length = length + 1
		output[length] = t[1] and percentEncode(t[1], URLENCODED_ENCODE_SET, true) or ""
		local value = t[2] and percentEncode(t[2], URLENCODED_ENCODE_SET, true) or ""
		if value ~= "" then
			length = length + 1
			output[length] = "="
			length = length + 1
			output[length] = value
		end
	end
	if length ~= 0 then
		return concat(output, "", 1, length)
	end
end
local serialize
serialize = function(self, excludeFragment)
	local scheme = self.scheme
	local hostname = self.hostname
	local path = self.path
	local query = self.query
	local fragment = self.fragment
	local isOpaque = isstring(path)
	local output, length = { }, 0
	if scheme then
		length = length + 1
		output[length] = scheme
		length = length + 1
		output[length] = ":"
	end
	if hostname then
		length = length + 1
		output[length] = "//"
		local username = self.username
		local password = self.password
		if username or password then
			length = length + 1
			output[length] = username
			if password and password ~= "" then
				length = length + 1
				output[length] = ":"
				length = length + 1
				output[length] = password
			end
			length = length + 1
			output[length] = "@"
		end
		length = length + 1
		output[length] = serializeHost(hostname)
		local port = self.port
		if port then
			length = length + 1
			output[length] = ":"
			length = length + 1
			output[length] = tostring(port)
		end
	elseif path and not isOpaque and #path > 1 and path[1] == "" then
		length = length + 1
		output[length] = "./"
	end
	if path then
		length = length + 1
		output[length] = isOpaque and path or "/" .. concat(path, "/")
	end
	if query and #query ~= 0 then
		length = length + 1
		output[length] = "?"
		length = length + 1
		output[length] = tostring(query) or ""
	end
	if fragment and excludeFragment ~= true then
		length = length + 1
		output[length] = "#"
		length = length + 1
		output[length] = fragment
	end
	return concat(output, "", 1, length)
end
_module_0["serialize"] = serialize
local getOrigin
getOrigin = function(self)
	local _exp_0 = self.scheme
	if "ftp" == _exp_0 or "http" == _exp_0 or "https" == _exp_0 or "ws" == _exp_0 or "wss" == _exp_0 then
		return self.scheme, self.hostname, self.port
	elseif "blob" == _exp_0 then
		local pathURL = self.path
		if not isstring(pathURL) then
			return
		end
		local ok, url = pcall(parse, { }, pathURL)
		if ok then
			return getOrigin(url)
		end
	end
end
local serializeOrigin
serializeOrigin = function(self)
	local scheme, hostname, port = getOrigin(self)
	if scheme then
		local output = scheme .. "://" .. serializeHost(hostname)
		if port then
			output = output .. ":" .. port
		end
		return output
	end
end
local URLSearchParams
do
	local _class_0
	local update
	local _base_0 = {
		__tostring = function(self)
			return serializeQuery(self)
		end,
		append = function(list, name, value)
			list[#list + 1] = {
				name,
				value
			}
			return update(list)
		end,
		delete = function(list, name, value)
			for i = #list, 1, -1 do
				local t = list[i]
				if t[1] == name and (not value or t[2] == value) then
					remove(list, i)
				end
			end
			return update(list)
		end,
		get = function(list, name)
			for _index_0 = 1, #list do
				local t = list[_index_0]
				if t[1] == name then
					return t[2]
				end
			end
		end,
		getAll = function(list, name)
			local values = { }
			for _index_0 = 1, #list do
				local t = list[_index_0]
				if t[1] == name then
					values[#values + 1] = t[2]
				end
			end
			return values
		end,
		has = function(list, name, value)
			for _index_0 = 1, #list do
				local t = list[_index_0]
				if t[1] == name and (not value or t[2] == value) then
					return true
				end
			end
			return false
		end,
		set = function(list, name, value)
			for i = 1, #list do
				local t = list[i]
				if t[1] == name then
					-- replace first value
					t[2] = value
					-- remove all other values
					for j = #list, i + 1, -1 do
						if list[j][1] == name then
							remove(list, j)
						end
					end
					update(list)
					return
				end
			end
			-- if name is not found, append new value
			list[#list + 1] = {
				name,
				value
			}
			return update(list)
		end,
		sort = function(list)
			for i = 1, #list - 1 do
				local jMin = i
				for j = i + 1, #list do
					if list[j][1] < list[jMin][1] then
						jMin = j
					end
				end
				if jMin ~= i then
					local old = list[i]
					list[i] = list[jMin]
					list[jMin] = old
				end
			end
			return update(list)
		end,
		iterator = function(list)
			local i = 0
			return function()
				i = i + 1
				local t = list[i]
				if t then
					return t[1], t[2]
				end
			end
		end,
		keys = function(list)
			local i = 0
			return function()
				i = i + 1
				local t = list[i]
				if t then
					return t[1]
				end
			end
		end,
		values = function(list)
			local i = 0
			return function()
				i = i + 1
				local t = list[i]
				if t then
					return t[2]
				end
			end
		end
	}
	if _base_0.__index == nil then
		_base_0.__index = _base_0
	end
	_class_0 = setmetatable({
		__init = function(self, query, url)
			self.url = url
			if isstring(query) then
				if byte(query, 1) == 0x3F then
					query = sub(query, 2)
				end
				parseQueryString(query, self)
			elseif istable(query) then
				for i = 1, #query do
					self[i] = query[i]
				end
			end
			if self.url then
				-- yeah, URLState.query may be a string or URLSearchParams
				-- when we access URL.searchParams, it will look for URLState.query
				self.url.state.query = self
			end
		end,
		__base = _base_0,
		__name = "URLSearchParams"
	}, {
		__index = _base_0,
		__call = function(cls, ...)
			local _self_0 = setmetatable({ }, _base_0)
			cls.__init(_self_0, ...)
			return _self_0
		end
	})
	_base_0.__class = _class_0
	local self = _class_0;
	update = function(self)
		if self.url then
			self.url.query = self
		end
	end
	URLSearchParams = _class_0
end
_module_0["URLSearchParams"] = URLSearchParams
local IsURLSearchParams
IsURLSearchParams = function(any)
	local metatable = getmetatable(any)
	return metatable and metatable.__class == URLSearchParams
end
_module_0["IsURLSearchParams"] = IsURLSearchParams
local URL
do
	local _class_0
	local STATE_FIELDS, resetCache, cacheValue
	local _base_0 = {
		__tostring = function(self)
			return self.href
		end,
		__index = function(self, key)
			local state = rawget(self, "state")
			-- State fields
			if STATE_FIELDS[key] then
				if "hostname" == key then
					return rawget(self, "_hostname") or cacheValue(self, "_hostname", serializeHost(state.hostname))
				elseif "query" == key then
					return rawget(self, "_query") or cacheValue(self, "_query", IsURLSearchParams(state.query) and tostring(state.query) or state.query)
				else
					return state[key]
				end
			end
			-- Special fields
			if "href" == key then
				return rawget(self, "_href") or cacheValue(self, "_href", serialize(state))
			elseif "origin" == key then
				return rawget(self, "_origin") or cacheValue(self, "_origin", serializeOrigin(state))
			elseif "protocol" == key then
				return state.scheme and state.scheme .. ":" or nil
			elseif "host" == key then
				do
					local cached = rawget(self, "_host")
					if cached then
						return cached
					end
				end
				if not state.hostname then
					return ""
				end
				return cacheValue(self, "_host", state.port and self.hostname .. ":" .. state.port or self.hostname)
			elseif "pathname" == key then
				do
					local cached = rawget(self, "_pathname")
					if cached then
						return cached
					end
				end
				if not istable(state.path) then
					return state.path
				end
				return cacheValue(self, "_pathname", "/" .. concat(state.path, "/"))
			elseif "search" == key then
				local query = self.query
				if not query or query == "" then
					return ""
				end
				return "?" .. query
			elseif "searchParams" == key then
				if IsURLSearchParams(state.query) then
					return state.query
				end
				return URLSearchParams(state.query, self)
			elseif "hash" == key then
				if not state.fragment or state.fragment == "" then
					return ""
				end
				return "#" .. state.fragment
			end
		end,
		__newindex = function(self, key, value)
			local state = rawget(self, "state")
			-- State fields
			if STATE_FIELDS[key] then
				resetCache(self)
				if "username" == key then
					if not state.hostname or state.hostname == "" or state.scheme == "file" then
						return
					end
					state.username = value
				elseif "password" == key then
					if not state.hostname or state.hostname == "" or state.scheme == "file" then
						return
					end
					state.password = value
				elseif "hostname" == key then
					if isstring(state.path) then
						return
					end
					parseHost(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], "hostname")
				elseif "port" == key then
					if not state.hostname or state.hostname == "" or state.scheme == "file" then
						return
					end
					if not value or value == "" then
						state.port = nil
						return
					else
						value = tostring(value)
						parsePort(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], true)
					end
				else
					state[key] = value
				end
				return
			end
			-- Special fields
			if "href" == key then
				resetCache(self)
				state = { }
				parse(state, value)
				return rawset(self, "state", state)
			elseif "origin" == key then
				return
			elseif "protocol" == key then
				resetCache(self)
				return parseScheme(state, value, 1, #value, nil, true)
			elseif "host" == key then
				if isstring(state.path) then
					return
				end
				resetCache(self)
				return parseHost(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], "host")
			elseif "pathname" == key then
				if isstring(state.path) then
					return
				end
				resetCache(self)
				state.path = { }
				return parsePathStart(state, value, 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], true)
			elseif "search" == key then
				resetCache(self)
				local leadingSymbol = byte(value, 1) == 0x3F
				return parseQuery(state, value, leadingSymbol and 2 or 1, #value, state.scheme and SPECIAL_SCHEMAS[state.scheme], true)
			elseif "searchParams" == key then
				return
			elseif "hash" == key then
				if not value or value == "" then
					state.fragment = nil
					return
				end
				resetCache(self)
				local leadingSymbol = byte(value, 1) == 0x23
				return parseFragment(state, value, leadingSymbol and 2 or 1, #value)
			else
				return rawset(self, key, value)
			end
		end
	}
	if _base_0.__index == nil then
		_base_0.__index = _base_0
	end
	_class_0 = setmetatable({
		__init = function(self, str, base)
			local state = { }
			self.state = state
			return parse(state, str, base)
		end,
		__base = _base_0,
		__name = "URL"
	}, {
		__index = _base_0,
		__call = function(cls, ...)
			local _self_0 = setmetatable({ }, _base_0)
			cls.__init(_self_0, ...)
			return _self_0
		end
	})
	_base_0.__class = _class_0
	local self = _class_0;
	self.parse = function(str, base)
		return URL(str, base)
	end
	self.canParse = function(str, base)
		return pcall(parse, { }, str, base)
	end
	STATE_FIELDS = {
		["scheme"] = true,
		["username"] = true,
		["password"] = true,
		["hostname"] = true,
		["port"] = true,
		["path"] = true,
		["query"] = true,
		["fragment"] = true
	}
	resetCache = function(self)
		rawset(self, "_href", nil)
		rawset(self, "_origin", nil)
		rawset(self, "_host", nil)
		rawset(self, "_hostname", nil)
		rawset(self, "_pathname", nil)
		return rawset(self, "_query", nil)
	end
	cacheValue = function(self, key, value)
		rawset(self, key, value)
		return value
	end
	URL = _class_0
end
_module_0["URL"] = URL
local IsURL
IsURL = function(any)
	local metatable = getmetatable(any)
	return metatable and metatable.__class == URL
end
_module_0["IsURL"] = IsURL
return _module_0

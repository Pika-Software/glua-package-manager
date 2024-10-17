local _G = _G
local environment
do
	local _obj_0 = _G.gpm
	environment = _obj_0.environment
end
local char, byte, sub, gsub, gmatch, len
do
	local _obj_0 = _G.string
	char, byte, sub, gsub, gmatch, len = _obj_0.char, _obj_0.byte, _obj_0.sub, _obj_0.gsub, _obj_0.gmatch, _obj_0.len
end
local band, bor, lshift, rshift
do
	local _obj_0 = environment.bit
	band, bor, lshift, rshift = _obj_0.band, _obj_0.bor, _obj_0.lshift, _obj_0.rshift
end
local concat, unpack, Flip
do
	local _obj_0 = environment.table
	concat, unpack, Flip = _obj_0.concat, _obj_0.unpack, _obj_0.Flip
end
local min, max
do
	local _obj_0 = _G.math
	min, max = _obj_0.min, _obj_0.max
end
local tonumber = _G.tonumber
local charpattern = "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"
local _module_0 = {
	charpattern = charpattern
}
local utf8byte2char
utf8byte2char = function(byte0)
	-- Single-byte sequence
	if byte0 < 0x80 then
		return char(byte0)
	end
	-- Two-byte sequence
	if byte0 < 0x800 then
		return char(bor(0xC0, band(rshift(byte0, 6), 0x1F)), bor(0x80, band(byte0, 0x3F)))
	end
	-- Three-byte sequence
	if byte0 < 0x10000 then
		return char(bor(0xE0, band(rshift(byte0, 12), 0x0F)), bor(0x80, band(rshift(byte0, 6), 0x3F)), bor(0x80, band(byte0, 0x3F)))
	end
	-- Four-byte sequence
	return char(bor(0xF0, band(rshift(byte0, 18), 0x07)), bor(0x80, band(rshift(byte0, 12), 0x3F)), bor(0x80, band(rshift(byte0, 6), 0x3F)), bor(0x80, band(byte0, 0x3F)))
end
_module_0.byte2char = utf8byte2char
local utf8char
utf8char = function(...)
	local buffer, length = { }, 0
	local _list_0 = {
		...
	}
	for _index_0 = 1, #_list_0 do
		local byte0 = _list_0[_index_0]
		length = length + 1
		buffer[length] = utf8byte2char(byte0)
	end
	return concat(buffer, "", 1, length)
end
_module_0.char = utf8char
local stringPosition
stringPosition = function(number, stringLength)
	if number > 0 then
		return min(number, stringLength)
	end
	if number == 0 then
		return 1
	end
	return max(stringLength + number + 1, 1)
end
local decode
decode = function(str, stringStart, stringLength)
	stringStart = stringPosition(stringStart or 1, stringLength)
	local byte1 = byte(str, stringStart)
	if not byte1 then
		return nil
	end
	-- Single-byte sequence
	if byte1 < 0x80 then
		return stringStart, stringStart, byte1
	end
	-- Validate first byte of multi-byte sequence
	if byte1 > 0xF4 or byte1 < 0xC2 then
		return nil
	end
	-- Get 'supposed' amount of continuation bytes from primary byte
	local contByteCount = byte1 >= 0xF0 and 3 or byte1 >= 0xE0 and 2 or byte1 >= 0xC0 and 1
	local stringEnd = stringStart + contByteCount
	-- The string doesn't have enough data for this many continutation bytes
	if stringLength < stringEnd then
		return nil
	end
	local codePoint = 0
	-- Validate our continuation bytes
	local _list_0 = {
		byte(str, stringStart + 1, stringEnd)
	}
	for _index_0 = 1, #_list_0 do
		local byte0 = _list_0[_index_0]
		-- Invalid continuation byte hit
		if band(byte0, 0xC0) ~= 0x80 then
			return nil
		end
		codePoint = bor(lshift(codePoint, 6), band(byte0, 0x3F))
		byte1 = lshift(byte1, 1)
	end
	return stringStart, stringEnd, bor(codePoint, lshift(band(byte1, 0x7F), contByteCount * 5))
end
_module_0.codes = function(str)
	local index, stringLength = 1, len(str)
	return function()
		if index > stringLength then
			return nil
		end
		local stringStart, stringEnd, codePoint = decode(str, index, stringLength)
		if not stringStart then
			error("invalid UTF-8 code", 2)
		end
		index = stringEnd + 1
		return stringStart, codePoint
	end
end
local utf8codepoint
utf8codepoint = function(str, stringStart, stringEnd)
	local stringLength = len(str)
	stringStart = stringPosition(stringStart or 1, stringLength)
	stringEnd = stringPosition(stringEnd or stringStart, stringLength)
	local buffer, length = { }, 0
	repeat
		local sequenceStart, sequenceEnd, codePoint = decode(str, stringStart, stringLength)
		if not sequenceStart then
			error("invalid UTF-8 code", 2)
		end
		stringStart = sequenceEnd + 1
		length = length + 1
		buffer[length] = codePoint
	until sequenceEnd >= stringEnd
	return unpack(buffer, 1, length)
end
_module_0.codepoint = utf8codepoint
_module_0.byte = utf8codepoint
local utf8len
utf8len = function(str, stringStart, stringEnd)
	local stringLength = len(str)
	stringStart = stringPosition(stringStart or 1, stringLength)
	stringEnd = stringPosition(stringEnd or -1, stringLength)
	local length = 0
	if stringStart == 1 and stringEnd == stringLength then
		for _ in gmatch(str, charpattern) do
			length = length + 1
		end
		return length
	end
	while stringEnd >= stringStart and stringStart <= stringLength do
		local sequenceStart, sequenceEnd = decode(str, stringStart, stringLength)
		if not sequenceStart then
			return false, stringStart
		end
		stringStart = sequenceEnd + 1
		length = length + 1
	end
	return length
end
_module_0.len = utf8len
local utf8offset
utf8offset = function(str, offset, stringStart)
	local stringLength = len(str)
	local position = stringPosition(stringStart or ((offset >= 0) and 1 or stringLength), stringLength)
	-- Back up to the start of this byte sequence
	if offset == 0 then
		while position > 0 and not decode(str, position, stringLength) do
			position = position - 1
		end
		return position
	end
	if not decode(str, position, stringLength) then
		error("initial position is a continuation byte", 2)
	end
	-- Back up to (-offset) byte sequences
	if offset < 0 then
		for i = 1, -offset do
			position = position - 1
			while position > 0 and not decode(str, position, stringLength) do
				position = position - 1
			end
		end
		if position < 1 then
			return nil
		end
		return position
	end
	-- Jump forward (offset) byte sequences
	if offset > 0 then
		for i = 1, offset do
			position = position + 1
			while position <= stringLength and not decode(str, position, stringLength) do
				position = position + 1
			end
		end
		if position > stringLength then
			return nil
		end
		return position
	end
end
_module_0.offset = utf8offset
_module_0.force = function(str)
	local stringLength = len(str)
	if stringLength == 0 then
		return str
	end
	local buffer, length = { }, 0
	local pointer = 1
	repeat
		local seqStartPos, seqEndPos = decode(str, pointer, stringLength)
		if seqStartPos then
			length = length + 1
			buffer[length] = sub(str, seqStartPos, seqEndPos)
			pointer = seqEndPos + 1
		else
			length = length + 1
			buffer[length] = utf8char(0xFFFD)
			pointer = pointer + 1
		end
	until pointer > stringLength
	return concat(buffer, "", 1, length)
end
local stringOffset
stringOffset = function(position, utf8Length)
	if position < 0 then
		position = max(utf8Length + position + 1, 0)
	end
	return position
end
local utf8get
utf8get = function(str, index, utf8Length)
	if utf8Length == nil then
		utf8Length = utf8len(str)
	end
	index = stringOffset(index or 1, utf8Length)
	if index == 0 then
		return ""
	end
	if index > utf8Length then
		return ""
	end
	return utf8char(utf8codepoint(str, utf8offset(str, index - 1)))
end
_module_0.get = utf8get
_module_0.sub = function(str, charStart, charEnd)
	local utf8Length = utf8len(str)
	local buffer, length = { }, 0
	for index = stringOffset(charStart or 1, utf8Length), stringOffset(charEnd or -1, utf8Length) do
		length = length + 1
		buffer[length] = utf8get(str, index, utf8Length)
	end
	return concat(buffer, "", 1, length)
end
do
	-- https://github.com/NebulousCloud/helix/blob/master/gamemode/core/libs/thirdparty/data/sh_utf8_casemap.lua
	local lower2upper = {
		["a"] = "A",
		["b"] = "B",
		["c"] = "C",
		["d"] = "D",
		["e"] = "E",
		["f"] = "F",
		["g"] = "G",
		["h"] = "H",
		["i"] = "I",
		["j"] = "J",
		["k"] = "K",
		["l"] = "L",
		["m"] = "M",
		["n"] = "N",
		["o"] = "O",
		["p"] = "P",
		["q"] = "Q",
		["r"] = "R",
		["s"] = "S",
		["t"] = "T",
		["u"] = "U",
		["v"] = "V",
		["w"] = "W",
		["x"] = "X",
		["y"] = "Y",
		["z"] = "Z",
		["µ"] = "Μ",
		["à"] = "À",
		["á"] = "Á",
		["â"] = "Â",
		["ã"] = "Ã",
		["ä"] = "Ä",
		["å"] = "Å",
		["æ"] = "Æ",
		["ç"] = "Ç",
		["è"] = "È",
		["é"] = "É",
		["ê"] = "Ê",
		["ë"] = "Ë",
		["ì"] = "Ì",
		["í"] = "Í",
		["î"] = "Î",
		["ï"] = "Ï",
		["ð"] = "Ð",
		["ñ"] = "Ñ",
		["ò"] = "Ò",
		["ó"] = "Ó",
		["ô"] = "Ô",
		["õ"] = "Õ",
		["ö"] = "Ö",
		["ø"] = "Ø",
		["ù"] = "Ù",
		["ú"] = "Ú",
		["û"] = "Û",
		["ü"] = "Ü",
		["ý"] = "Ý",
		["þ"] = "Þ",
		["ÿ"] = "Ÿ",
		["ā"] = "Ā",
		["ă"] = "Ă",
		["ą"] = "Ą",
		["ć"] = "Ć",
		["ĉ"] = "Ĉ",
		["ċ"] = "Ċ",
		["č"] = "Č",
		["ď"] = "Ď",
		["đ"] = "Đ",
		["ē"] = "Ē",
		["ĕ"] = "Ĕ",
		["ė"] = "Ė",
		["ę"] = "Ę",
		["ě"] = "Ě",
		["ĝ"] = "Ĝ",
		["ğ"] = "Ğ",
		["ġ"] = "Ġ",
		["ģ"] = "Ģ",
		["ĥ"] = "Ĥ",
		["ħ"] = "Ħ",
		["ĩ"] = "Ĩ",
		["ī"] = "Ī",
		["ĭ"] = "Ĭ",
		["į"] = "Į",
		["ı"] = "I",
		["ĳ"] = "Ĳ",
		["ĵ"] = "Ĵ",
		["ķ"] = "Ķ",
		["ĺ"] = "Ĺ",
		["ļ"] = "Ļ",
		["ľ"] = "Ľ",
		["ŀ"] = "Ŀ",
		["ł"] = "Ł",
		["ń"] = "Ń",
		["ņ"] = "Ņ",
		["ň"] = "Ň",
		["ŋ"] = "Ŋ",
		["ō"] = "Ō",
		["ŏ"] = "Ŏ",
		["ő"] = "Ő",
		["œ"] = "Œ",
		["ŕ"] = "Ŕ",
		["ŗ"] = "Ŗ",
		["ř"] = "Ř",
		["ś"] = "Ś",
		["ŝ"] = "Ŝ",
		["ş"] = "Ş",
		["š"] = "Š",
		["ţ"] = "Ţ",
		["ť"] = "Ť",
		["ŧ"] = "Ŧ",
		["ũ"] = "Ũ",
		["ū"] = "Ū",
		["ŭ"] = "Ŭ",
		["ů"] = "Ů",
		["ű"] = "Ű",
		["ų"] = "Ų",
		["ŵ"] = "Ŵ",
		["ŷ"] = "Ŷ",
		["ź"] = "Ź",
		["ż"] = "Ż",
		["ž"] = "Ž",
		["ſ"] = "S",
		["ƀ"] = "Ƀ",
		["ƃ"] = "Ƃ",
		["ƅ"] = "Ƅ",
		["ƈ"] = "Ƈ",
		["ƌ"] = "Ƌ",
		["ƒ"] = "Ƒ",
		["ƕ"] = "Ƕ",
		["ƙ"] = "Ƙ",
		["ƚ"] = "Ƚ",
		["ƞ"] = "Ƞ",
		["ơ"] = "Ơ",
		["ƣ"] = "Ƣ",
		["ƥ"] = "Ƥ",
		["ƨ"] = "Ƨ",
		["ƭ"] = "Ƭ",
		["ư"] = "Ư",
		["ƴ"] = "Ƴ",
		["ƶ"] = "Ƶ",
		["ƹ"] = "Ƹ",
		["ƽ"] = "Ƽ",
		["ƿ"] = "Ƿ",
		["ǅ"] = "Ǆ",
		["ǆ"] = "Ǆ",
		["ǈ"] = "Ǉ",
		["ǉ"] = "Ǉ",
		["ǋ"] = "Ǌ",
		["ǌ"] = "Ǌ",
		["ǎ"] = "Ǎ",
		["ǐ"] = "Ǐ",
		["ǒ"] = "Ǒ",
		["ǔ"] = "Ǔ",
		["ǖ"] = "Ǖ",
		["ǘ"] = "Ǘ",
		["ǚ"] = "Ǚ",
		["ǜ"] = "Ǜ",
		["ǝ"] = "Ǝ",
		["ǟ"] = "Ǟ",
		["ǡ"] = "Ǡ",
		["ǣ"] = "Ǣ",
		["ǥ"] = "Ǥ",
		["ǧ"] = "Ǧ",
		["ǩ"] = "Ǩ",
		["ǫ"] = "Ǫ",
		["ǭ"] = "Ǭ",
		["ǯ"] = "Ǯ",
		["ǲ"] = "Ǳ",
		["ǳ"] = "Ǳ",
		["ǵ"] = "Ǵ",
		["ǹ"] = "Ǹ",
		["ǻ"] = "Ǻ",
		["ǽ"] = "Ǽ",
		["ǿ"] = "Ǿ",
		["ȁ"] = "Ȁ",
		["ȃ"] = "Ȃ",
		["ȅ"] = "Ȅ",
		["ȇ"] = "Ȇ",
		["ȉ"] = "Ȉ",
		["ȋ"] = "Ȋ",
		["ȍ"] = "Ȍ",
		["ȏ"] = "Ȏ",
		["ȑ"] = "Ȑ",
		["ȓ"] = "Ȓ",
		["ȕ"] = "Ȕ",
		["ȗ"] = "Ȗ",
		["ș"] = "Ș",
		["ț"] = "Ț",
		["ȝ"] = "Ȝ",
		["ȟ"] = "Ȟ",
		["ȣ"] = "Ȣ",
		["ȥ"] = "Ȥ",
		["ȧ"] = "Ȧ",
		["ȩ"] = "Ȩ",
		["ȫ"] = "Ȫ",
		["ȭ"] = "Ȭ",
		["ȯ"] = "Ȯ",
		["ȱ"] = "Ȱ",
		["ȳ"] = "Ȳ",
		["ȼ"] = "Ȼ",
		["ɂ"] = "Ɂ",
		["ɇ"] = "Ɇ",
		["ɉ"] = "Ɉ",
		["ɋ"] = "Ɋ",
		["ɍ"] = "Ɍ",
		["ɏ"] = "Ɏ",
		["ɓ"] = "Ɓ",
		["ɔ"] = "Ɔ",
		["ɖ"] = "Ɖ",
		["ɗ"] = "Ɗ",
		["ə"] = "Ə",
		["ɛ"] = "Ɛ",
		["ɠ"] = "Ɠ",
		["ɣ"] = "Ɣ",
		["ɨ"] = "Ɨ",
		["ɩ"] = "Ɩ",
		["ɫ"] = "Ɫ",
		["ɯ"] = "Ɯ",
		["ɲ"] = "Ɲ",
		["ɵ"] = "Ɵ",
		["ɽ"] = "Ɽ",
		["ʀ"] = "Ʀ",
		["ʃ"] = "Ʃ",
		["ʈ"] = "Ʈ",
		["ʉ"] = "Ʉ",
		["ʊ"] = "Ʊ",
		["ʋ"] = "Ʋ",
		["ʌ"] = "Ʌ",
		["ʒ"] = "Ʒ",
		["ͅ"] = "Ι",
		["ͻ"] = "Ͻ",
		["ͼ"] = "Ͼ",
		["ͽ"] = "Ͽ",
		["ά"] = "Ά",
		["έ"] = "Έ",
		["ή"] = "Ή",
		["ί"] = "Ί",
		["α"] = "Α",
		["β"] = "Β",
		["γ"] = "Γ",
		["δ"] = "Δ",
		["ε"] = "Ε",
		["ζ"] = "Ζ",
		["η"] = "Η",
		["θ"] = "Θ",
		["ι"] = "Ι",
		["κ"] = "Κ",
		["λ"] = "Λ",
		["μ"] = "Μ",
		["ν"] = "Ν",
		["ξ"] = "Ξ",
		["ο"] = "Ο",
		["π"] = "Π",
		["ρ"] = "Ρ",
		["ς"] = "Σ",
		["σ"] = "Σ",
		["τ"] = "Τ",
		["υ"] = "Υ",
		["φ"] = "Φ",
		["χ"] = "Χ",
		["ψ"] = "Ψ",
		["ω"] = "Ω",
		["ϊ"] = "Ϊ",
		["ϋ"] = "Ϋ",
		["ό"] = "Ό",
		["ύ"] = "Ύ",
		["ώ"] = "Ώ",
		["ϐ"] = "Β",
		["ϑ"] = "Θ",
		["ϕ"] = "Φ",
		["ϖ"] = "Π",
		["ϙ"] = "Ϙ",
		["ϛ"] = "Ϛ",
		["ϝ"] = "Ϝ",
		["ϟ"] = "Ϟ",
		["ϡ"] = "Ϡ",
		["ϣ"] = "Ϣ",
		["ϥ"] = "Ϥ",
		["ϧ"] = "Ϧ",
		["ϩ"] = "Ϩ",
		["ϫ"] = "Ϫ",
		["ϭ"] = "Ϭ",
		["ϯ"] = "Ϯ",
		["ϰ"] = "Κ",
		["ϱ"] = "Ρ",
		["ϲ"] = "Ϲ",
		["ϵ"] = "Ε",
		["ϸ"] = "Ϸ",
		["ϻ"] = "Ϻ",
		["а"] = "А",
		["б"] = "Б",
		["в"] = "В",
		["г"] = "Г",
		["д"] = "Д",
		["е"] = "Е",
		["ж"] = "Ж",
		["з"] = "З",
		["и"] = "И",
		["й"] = "Й",
		["к"] = "К",
		["л"] = "Л",
		["м"] = "М",
		["н"] = "Н",
		["о"] = "О",
		["п"] = "П",
		["р"] = "Р",
		["с"] = "С",
		["т"] = "Т",
		["у"] = "У",
		["ф"] = "Ф",
		["х"] = "Х",
		["ц"] = "Ц",
		["ч"] = "Ч",
		["ш"] = "Ш",
		["щ"] = "Щ",
		["ъ"] = "Ъ",
		["ы"] = "Ы",
		["ь"] = "Ь",
		["э"] = "Э",
		["ю"] = "Ю",
		["я"] = "Я",
		["ѐ"] = "Ѐ",
		["ё"] = "Ё",
		["ђ"] = "Ђ",
		["ѓ"] = "Ѓ",
		["є"] = "Є",
		["ѕ"] = "Ѕ",
		["і"] = "І",
		["ї"] = "Ї",
		["ј"] = "Ј",
		["љ"] = "Љ",
		["њ"] = "Њ",
		["ћ"] = "Ћ",
		["ќ"] = "Ќ",
		["ѝ"] = "Ѝ",
		["ў"] = "Ў",
		["џ"] = "Џ",
		["ѡ"] = "Ѡ",
		["ѣ"] = "Ѣ",
		["ѥ"] = "Ѥ",
		["ѧ"] = "Ѧ",
		["ѩ"] = "Ѩ",
		["ѫ"] = "Ѫ",
		["ѭ"] = "Ѭ",
		["ѯ"] = "Ѯ",
		["ѱ"] = "Ѱ",
		["ѳ"] = "Ѳ",
		["ѵ"] = "Ѵ",
		["ѷ"] = "Ѷ",
		["ѹ"] = "Ѹ",
		["ѻ"] = "Ѻ",
		["ѽ"] = "Ѽ",
		["ѿ"] = "Ѿ",
		["ҁ"] = "Ҁ",
		["ҋ"] = "Ҋ",
		["ҍ"] = "Ҍ",
		["ҏ"] = "Ҏ",
		["ґ"] = "Ґ",
		["ғ"] = "Ғ",
		["ҕ"] = "Ҕ",
		["җ"] = "Җ",
		["ҙ"] = "Ҙ",
		["қ"] = "Қ",
		["ҝ"] = "Ҝ",
		["ҟ"] = "Ҟ",
		["ҡ"] = "Ҡ",
		["ң"] = "Ң",
		["ҥ"] = "Ҥ",
		["ҧ"] = "Ҧ",
		["ҩ"] = "Ҩ",
		["ҫ"] = "Ҫ",
		["ҭ"] = "Ҭ",
		["ү"] = "Ү",
		["ұ"] = "Ұ",
		["ҳ"] = "Ҳ",
		["ҵ"] = "Ҵ",
		["ҷ"] = "Ҷ",
		["ҹ"] = "Ҹ",
		["һ"] = "Һ",
		["ҽ"] = "Ҽ",
		["ҿ"] = "Ҿ",
		["ӂ"] = "Ӂ",
		["ӄ"] = "Ӄ",
		["ӆ"] = "Ӆ",
		["ӈ"] = "Ӈ",
		["ӊ"] = "Ӊ",
		["ӌ"] = "Ӌ",
		["ӎ"] = "Ӎ",
		["ӏ"] = "Ӏ",
		["ӑ"] = "Ӑ",
		["ӓ"] = "Ӓ",
		["ӕ"] = "Ӕ",
		["ӗ"] = "Ӗ",
		["ә"] = "Ә",
		["ӛ"] = "Ӛ",
		["ӝ"] = "Ӝ",
		["ӟ"] = "Ӟ",
		["ӡ"] = "Ӡ",
		["ӣ"] = "Ӣ",
		["ӥ"] = "Ӥ",
		["ӧ"] = "Ӧ",
		["ө"] = "Ө",
		["ӫ"] = "Ӫ",
		["ӭ"] = "Ӭ",
		["ӯ"] = "Ӯ",
		["ӱ"] = "Ӱ",
		["ӳ"] = "Ӳ",
		["ӵ"] = "Ӵ",
		["ӷ"] = "Ӷ",
		["ӹ"] = "Ӹ",
		["ӻ"] = "Ӻ",
		["ӽ"] = "Ӽ",
		["ӿ"] = "Ӿ",
		["ԁ"] = "Ԁ",
		["ԃ"] = "Ԃ",
		["ԅ"] = "Ԅ",
		["ԇ"] = "Ԇ",
		["ԉ"] = "Ԉ",
		["ԋ"] = "Ԋ",
		["ԍ"] = "Ԍ",
		["ԏ"] = "Ԏ",
		["ԑ"] = "Ԑ",
		["ԓ"] = "Ԓ",
		["ա"] = "Ա",
		["բ"] = "Բ",
		["գ"] = "Գ",
		["դ"] = "Դ",
		["ե"] = "Ե",
		["զ"] = "Զ",
		["է"] = "Է",
		["ը"] = "Ը",
		["թ"] = "Թ",
		["ժ"] = "Ժ",
		["ի"] = "Ի",
		["լ"] = "Լ",
		["խ"] = "Խ",
		["ծ"] = "Ծ",
		["կ"] = "Կ",
		["հ"] = "Հ",
		["ձ"] = "Ձ",
		["ղ"] = "Ղ",
		["ճ"] = "Ճ",
		["մ"] = "Մ",
		["յ"] = "Յ",
		["ն"] = "Ն",
		["շ"] = "Շ",
		["ո"] = "Ո",
		["չ"] = "Չ",
		["պ"] = "Պ",
		["ջ"] = "Ջ",
		["ռ"] = "Ռ",
		["ս"] = "Ս",
		["վ"] = "Վ",
		["տ"] = "Տ",
		["ր"] = "Ր",
		["ց"] = "Ց",
		["ւ"] = "Ւ",
		["փ"] = "Փ",
		["ք"] = "Ք",
		["օ"] = "Օ",
		["ֆ"] = "Ֆ",
		["ᵽ"] = "Ᵽ",
		["ḁ"] = "Ḁ",
		["ḃ"] = "Ḃ",
		["ḅ"] = "Ḅ",
		["ḇ"] = "Ḇ",
		["ḉ"] = "Ḉ",
		["ḋ"] = "Ḋ",
		["ḍ"] = "Ḍ",
		["ḏ"] = "Ḏ",
		["ḑ"] = "Ḑ",
		["ḓ"] = "Ḓ",
		["ḕ"] = "Ḕ",
		["ḗ"] = "Ḗ",
		["ḙ"] = "Ḙ",
		["ḛ"] = "Ḛ",
		["ḝ"] = "Ḝ",
		["ḟ"] = "Ḟ",
		["ḡ"] = "Ḡ",
		["ḣ"] = "Ḣ",
		["ḥ"] = "Ḥ",
		["ḧ"] = "Ḧ",
		["ḩ"] = "Ḩ",
		["ḫ"] = "Ḫ",
		["ḭ"] = "Ḭ",
		["ḯ"] = "Ḯ",
		["ḱ"] = "Ḱ",
		["ḳ"] = "Ḳ",
		["ḵ"] = "Ḵ",
		["ḷ"] = "Ḷ",
		["ḹ"] = "Ḹ",
		["ḻ"] = "Ḻ",
		["ḽ"] = "Ḽ",
		["ḿ"] = "Ḿ",
		["ṁ"] = "Ṁ",
		["ṃ"] = "Ṃ",
		["ṅ"] = "Ṅ",
		["ṇ"] = "Ṇ",
		["ṉ"] = "Ṉ",
		["ṋ"] = "Ṋ",
		["ṍ"] = "Ṍ",
		["ṏ"] = "Ṏ",
		["ṑ"] = "Ṑ",
		["ṓ"] = "Ṓ",
		["ṕ"] = "Ṕ",
		["ṗ"] = "Ṗ",
		["ṙ"] = "Ṙ",
		["ṛ"] = "Ṛ",
		["ṝ"] = "Ṝ",
		["ṟ"] = "Ṟ",
		["ṡ"] = "Ṡ",
		["ṣ"] = "Ṣ",
		["ṥ"] = "Ṥ",
		["ṧ"] = "Ṧ",
		["ṩ"] = "Ṩ",
		["ṫ"] = "Ṫ",
		["ṭ"] = "Ṭ",
		["ṯ"] = "Ṯ",
		["ṱ"] = "Ṱ",
		["ṳ"] = "Ṳ",
		["ṵ"] = "Ṵ",
		["ṷ"] = "Ṷ",
		["ṹ"] = "Ṹ",
		["ṻ"] = "Ṻ",
		["ṽ"] = "Ṽ",
		["ṿ"] = "Ṿ",
		["ẁ"] = "Ẁ",
		["ẃ"] = "Ẃ",
		["ẅ"] = "Ẅ",
		["ẇ"] = "Ẇ",
		["ẉ"] = "Ẉ",
		["ẋ"] = "Ẋ",
		["ẍ"] = "Ẍ",
		["ẏ"] = "Ẏ",
		["ẑ"] = "Ẑ",
		["ẓ"] = "Ẓ",
		["ẕ"] = "Ẕ",
		["ẛ"] = "Ṡ",
		["ạ"] = "Ạ",
		["ả"] = "Ả",
		["ấ"] = "Ấ",
		["ầ"] = "Ầ",
		["ẩ"] = "Ẩ",
		["ẫ"] = "Ẫ",
		["ậ"] = "Ậ",
		["ắ"] = "Ắ",
		["ằ"] = "Ằ",
		["ẳ"] = "Ẳ",
		["ẵ"] = "Ẵ",
		["ặ"] = "Ặ",
		["ẹ"] = "Ẹ",
		["ẻ"] = "Ẻ",
		["ẽ"] = "Ẽ",
		["ế"] = "Ế",
		["ề"] = "Ề",
		["ể"] = "Ể",
		["ễ"] = "Ễ",
		["ệ"] = "Ệ",
		["ỉ"] = "Ỉ",
		["ị"] = "Ị",
		["ọ"] = "Ọ",
		["ỏ"] = "Ỏ",
		["ố"] = "Ố",
		["ồ"] = "Ồ",
		["ổ"] = "Ổ",
		["ỗ"] = "Ỗ",
		["ộ"] = "Ộ",
		["ớ"] = "Ớ",
		["ờ"] = "Ờ",
		["ở"] = "Ở",
		["ỡ"] = "Ỡ",
		["ợ"] = "Ợ",
		["ụ"] = "Ụ",
		["ủ"] = "Ủ",
		["ứ"] = "Ứ",
		["ừ"] = "Ừ",
		["ử"] = "Ử",
		["ữ"] = "Ữ",
		["ự"] = "Ự",
		["ỳ"] = "Ỳ",
		["ỵ"] = "Ỵ",
		["ỷ"] = "Ỷ",
		["ỹ"] = "Ỹ",
		["ἀ"] = "Ἀ",
		["ἁ"] = "Ἁ",
		["ἂ"] = "Ἂ",
		["ἃ"] = "Ἃ",
		["ἄ"] = "Ἄ",
		["ἅ"] = "Ἅ",
		["ἆ"] = "Ἆ",
		["ἇ"] = "Ἇ",
		["ἐ"] = "Ἐ",
		["ἑ"] = "Ἑ",
		["ἒ"] = "Ἒ",
		["ἓ"] = "Ἓ",
		["ἔ"] = "Ἔ",
		["ἕ"] = "Ἕ",
		["ἠ"] = "Ἠ",
		["ἡ"] = "Ἡ",
		["ἢ"] = "Ἢ",
		["ἣ"] = "Ἣ",
		["ἤ"] = "Ἤ",
		["ἥ"] = "Ἥ",
		["ἦ"] = "Ἦ",
		["ἧ"] = "Ἧ",
		["ἰ"] = "Ἰ",
		["ἱ"] = "Ἱ",
		["ἲ"] = "Ἲ",
		["ἳ"] = "Ἳ",
		["ἴ"] = "Ἴ",
		["ἵ"] = "Ἵ",
		["ἶ"] = "Ἶ",
		["ἷ"] = "Ἷ",
		["ὀ"] = "Ὀ",
		["ὁ"] = "Ὁ",
		["ὂ"] = "Ὂ",
		["ὃ"] = "Ὃ",
		["ὄ"] = "Ὄ",
		["ὅ"] = "Ὅ",
		["ὑ"] = "Ὑ",
		["ὓ"] = "Ὓ",
		["ὕ"] = "Ὕ",
		["ὗ"] = "Ὗ",
		["ὠ"] = "Ὠ",
		["ὡ"] = "Ὡ",
		["ὢ"] = "Ὢ",
		["ὣ"] = "Ὣ",
		["ὤ"] = "Ὤ",
		["ὥ"] = "Ὥ",
		["ὦ"] = "Ὦ",
		["ὧ"] = "Ὧ",
		["ὰ"] = "Ὰ",
		["ά"] = "Ά",
		["ὲ"] = "Ὲ",
		["έ"] = "Έ",
		["ὴ"] = "Ὴ",
		["ή"] = "Ή",
		["ὶ"] = "Ὶ",
		["ί"] = "Ί",
		["ὸ"] = "Ὸ",
		["ό"] = "Ό",
		["ὺ"] = "Ὺ",
		["ύ"] = "Ύ",
		["ὼ"] = "Ὼ",
		["ώ"] = "Ώ",
		["ᾀ"] = "ᾈ",
		["ᾁ"] = "ᾉ",
		["ᾂ"] = "ᾊ",
		["ᾃ"] = "ᾋ",
		["ᾄ"] = "ᾌ",
		["ᾅ"] = "ᾍ",
		["ᾆ"] = "ᾎ",
		["ᾇ"] = "ᾏ",
		["ᾐ"] = "ᾘ",
		["ᾑ"] = "ᾙ",
		["ᾒ"] = "ᾚ",
		["ᾓ"] = "ᾛ",
		["ᾔ"] = "ᾜ",
		["ᾕ"] = "ᾝ",
		["ᾖ"] = "ᾞ",
		["ᾗ"] = "ᾟ",
		["ᾠ"] = "ᾨ",
		["ᾡ"] = "ᾩ",
		["ᾢ"] = "ᾪ",
		["ᾣ"] = "ᾫ",
		["ᾤ"] = "ᾬ",
		["ᾥ"] = "ᾭ",
		["ᾦ"] = "ᾮ",
		["ᾧ"] = "ᾯ",
		["ᾰ"] = "Ᾰ",
		["ᾱ"] = "Ᾱ",
		["ᾳ"] = "ᾼ",
		["ι"] = "Ι",
		["ῃ"] = "ῌ",
		["ῐ"] = "Ῐ",
		["ῑ"] = "Ῑ",
		["ῠ"] = "Ῠ",
		["ῡ"] = "Ῡ",
		["ῥ"] = "Ῥ",
		["ῳ"] = "ῼ",
		["ⅎ"] = "Ⅎ",
		["ⅰ"] = "Ⅰ",
		["ⅱ"] = "Ⅱ",
		["ⅲ"] = "Ⅲ",
		["ⅳ"] = "Ⅳ",
		["ⅴ"] = "Ⅴ",
		["ⅵ"] = "Ⅵ",
		["ⅶ"] = "Ⅶ",
		["ⅷ"] = "Ⅷ",
		["ⅸ"] = "Ⅸ",
		["ⅹ"] = "Ⅹ",
		["ⅺ"] = "Ⅺ",
		["ⅻ"] = "Ⅻ",
		["ⅼ"] = "Ⅼ",
		["ⅽ"] = "Ⅽ",
		["ⅾ"] = "Ⅾ",
		["ⅿ"] = "Ⅿ",
		["ↄ"] = "Ↄ",
		["ⓐ"] = "Ⓐ",
		["ⓑ"] = "Ⓑ",
		["ⓒ"] = "Ⓒ",
		["ⓓ"] = "Ⓓ",
		["ⓔ"] = "Ⓔ",
		["ⓕ"] = "Ⓕ",
		["ⓖ"] = "Ⓖ",
		["ⓗ"] = "Ⓗ",
		["ⓘ"] = "Ⓘ",
		["ⓙ"] = "Ⓙ",
		["ⓚ"] = "Ⓚ",
		["ⓛ"] = "Ⓛ",
		["ⓜ"] = "Ⓜ",
		["ⓝ"] = "Ⓝ",
		["ⓞ"] = "Ⓞ",
		["ⓟ"] = "Ⓟ",
		["ⓠ"] = "Ⓠ",
		["ⓡ"] = "Ⓡ",
		["ⓢ"] = "Ⓢ",
		["ⓣ"] = "Ⓣ",
		["ⓤ"] = "Ⓤ",
		["ⓥ"] = "Ⓥ",
		["ⓦ"] = "Ⓦ",
		["ⓧ"] = "Ⓧ",
		["ⓨ"] = "Ⓨ",
		["ⓩ"] = "Ⓩ",
		["ⰰ"] = "Ⰰ",
		["ⰱ"] = "Ⰱ",
		["ⰲ"] = "Ⰲ",
		["ⰳ"] = "Ⰳ",
		["ⰴ"] = "Ⰴ",
		["ⰵ"] = "Ⰵ",
		["ⰶ"] = "Ⰶ",
		["ⰷ"] = "Ⰷ",
		["ⰸ"] = "Ⰸ",
		["ⰹ"] = "Ⰹ",
		["ⰺ"] = "Ⰺ",
		["ⰻ"] = "Ⰻ",
		["ⰼ"] = "Ⰼ",
		["ⰽ"] = "Ⰽ",
		["ⰾ"] = "Ⰾ",
		["ⰿ"] = "Ⰿ",
		["ⱀ"] = "Ⱀ",
		["ⱁ"] = "Ⱁ",
		["ⱂ"] = "Ⱂ",
		["ⱃ"] = "Ⱃ",
		["ⱄ"] = "Ⱄ",
		["ⱅ"] = "Ⱅ",
		["ⱆ"] = "Ⱆ",
		["ⱇ"] = "Ⱇ",
		["ⱈ"] = "Ⱈ",
		["ⱉ"] = "Ⱉ",
		["ⱊ"] = "Ⱊ",
		["ⱋ"] = "Ⱋ",
		["ⱌ"] = "Ⱌ",
		["ⱍ"] = "Ⱍ",
		["ⱎ"] = "Ⱎ",
		["ⱏ"] = "Ⱏ",
		["ⱐ"] = "Ⱐ",
		["ⱑ"] = "Ⱑ",
		["ⱒ"] = "Ⱒ",
		["ⱓ"] = "Ⱓ",
		["ⱔ"] = "Ⱔ",
		["ⱕ"] = "Ⱕ",
		["ⱖ"] = "Ⱖ",
		["ⱗ"] = "Ⱗ",
		["ⱘ"] = "Ⱘ",
		["ⱙ"] = "Ⱙ",
		["ⱚ"] = "Ⱚ",
		["ⱛ"] = "Ⱛ",
		["ⱜ"] = "Ⱜ",
		["ⱝ"] = "Ⱝ",
		["ⱞ"] = "Ⱞ",
		["ⱡ"] = "Ⱡ",
		["ⱥ"] = "Ⱥ",
		["ⱦ"] = "Ⱦ",
		["ⱨ"] = "Ⱨ",
		["ⱪ"] = "Ⱪ",
		["ⱬ"] = "Ⱬ",
		["ⱶ"] = "Ⱶ",
		["ⲁ"] = "Ⲁ",
		["ⲃ"] = "Ⲃ",
		["ⲅ"] = "Ⲅ",
		["ⲇ"] = "Ⲇ",
		["ⲉ"] = "Ⲉ",
		["ⲋ"] = "Ⲋ",
		["ⲍ"] = "Ⲍ",
		["ⲏ"] = "Ⲏ",
		["ⲑ"] = "Ⲑ",
		["ⲓ"] = "Ⲓ",
		["ⲕ"] = "Ⲕ",
		["ⲗ"] = "Ⲗ",
		["ⲙ"] = "Ⲙ",
		["ⲛ"] = "Ⲛ",
		["ⲝ"] = "Ⲝ",
		["ⲟ"] = "Ⲟ",
		["ⲡ"] = "Ⲡ",
		["ⲣ"] = "Ⲣ",
		["ⲥ"] = "Ⲥ",
		["ⲧ"] = "Ⲧ",
		["ⲩ"] = "Ⲩ",
		["ⲫ"] = "Ⲫ",
		["ⲭ"] = "Ⲭ",
		["ⲯ"] = "Ⲯ",
		["ⲱ"] = "Ⲱ",
		["ⲳ"] = "Ⲳ",
		["ⲵ"] = "Ⲵ",
		["ⲷ"] = "Ⲷ",
		["ⲹ"] = "Ⲹ",
		["ⲻ"] = "Ⲻ",
		["ⲽ"] = "Ⲽ",
		["ⲿ"] = "Ⲿ",
		["ⳁ"] = "Ⳁ",
		["ⳃ"] = "Ⳃ",
		["ⳅ"] = "Ⳅ",
		["ⳇ"] = "Ⳇ",
		["ⳉ"] = "Ⳉ",
		["ⳋ"] = "Ⳋ",
		["ⳍ"] = "Ⳍ",
		["ⳏ"] = "Ⳏ",
		["ⳑ"] = "Ⳑ",
		["ⳓ"] = "Ⳓ",
		["ⳕ"] = "Ⳕ",
		["ⳗ"] = "Ⳗ",
		["ⳙ"] = "Ⳙ",
		["ⳛ"] = "Ⳛ",
		["ⳝ"] = "Ⳝ",
		["ⳟ"] = "Ⳟ",
		["ⳡ"] = "Ⳡ",
		["ⳣ"] = "Ⳣ",
		["ⴀ"] = "Ⴀ",
		["ⴁ"] = "Ⴁ",
		["ⴂ"] = "Ⴂ",
		["ⴃ"] = "Ⴃ",
		["ⴄ"] = "Ⴄ",
		["ⴅ"] = "Ⴅ",
		["ⴆ"] = "Ⴆ",
		["ⴇ"] = "Ⴇ",
		["ⴈ"] = "Ⴈ",
		["ⴉ"] = "Ⴉ",
		["ⴊ"] = "Ⴊ",
		["ⴋ"] = "Ⴋ",
		["ⴌ"] = "Ⴌ",
		["ⴍ"] = "Ⴍ",
		["ⴎ"] = "Ⴎ",
		["ⴏ"] = "Ⴏ",
		["ⴐ"] = "Ⴐ",
		["ⴑ"] = "Ⴑ",
		["ⴒ"] = "Ⴒ",
		["ⴓ"] = "Ⴓ",
		["ⴔ"] = "Ⴔ",
		["ⴕ"] = "Ⴕ",
		["ⴖ"] = "Ⴖ",
		["ⴗ"] = "Ⴗ",
		["ⴘ"] = "Ⴘ",
		["ⴙ"] = "Ⴙ",
		["ⴚ"] = "Ⴚ",
		["ⴛ"] = "Ⴛ",
		["ⴜ"] = "Ⴜ",
		["ⴝ"] = "Ⴝ",
		["ⴞ"] = "Ⴞ",
		["ⴟ"] = "Ⴟ",
		["ⴠ"] = "Ⴠ",
		["ⴡ"] = "Ⴡ",
		["ⴢ"] = "Ⴢ",
		["ⴣ"] = "Ⴣ",
		["ⴤ"] = "Ⴤ",
		["ⴥ"] = "Ⴥ",
		["ａ"] = "Ａ",
		["ｂ"] = "Ｂ",
		["ｃ"] = "Ｃ",
		["ｄ"] = "Ｄ",
		["ｅ"] = "Ｅ",
		["ｆ"] = "Ｆ",
		["ｇ"] = "Ｇ",
		["ｈ"] = "Ｈ",
		["ｉ"] = "Ｉ",
		["ｊ"] = "Ｊ",
		["ｋ"] = "Ｋ",
		["ｌ"] = "Ｌ",
		["ｍ"] = "Ｍ",
		["ｎ"] = "Ｎ",
		["ｏ"] = "Ｏ",
		["ｐ"] = "Ｐ",
		["ｑ"] = "Ｑ",
		["ｒ"] = "Ｒ",
		["ｓ"] = "Ｓ",
		["ｔ"] = "Ｔ",
		["ｕ"] = "Ｕ",
		["ｖ"] = "Ｖ",
		["ｗ"] = "Ｗ",
		["ｘ"] = "Ｘ",
		["ｙ"] = "Ｙ",
		["ｚ"] = "Ｚ",
		["𐐨"] = "𐐀",
		["𐐩"] = "𐐁",
		["𐐪"] = "𐐂",
		["𐐫"] = "𐐃",
		["𐐬"] = "𐐄",
		["𐐭"] = "𐐅",
		["𐐮"] = "𐐆",
		["𐐯"] = "𐐇",
		["𐐰"] = "𐐈",
		["𐐱"] = "𐐉",
		["𐐲"] = "𐐊",
		["𐐳"] = "𐐋",
		["𐐴"] = "𐐌",
		["𐐵"] = "𐐍",
		["𐐶"] = "𐐎",
		["𐐷"] = "𐐏",
		["𐐸"] = "𐐐",
		["𐐹"] = "𐐑",
		["𐐺"] = "𐐒",
		["𐐻"] = "𐐓",
		["𐐼"] = "𐐔",
		["𐐽"] = "𐐕",
		["𐐾"] = "𐐖",
		["𐐿"] = "𐐗",
		["𐑀"] = "𐐘",
		["𐑁"] = "𐐙",
		["𐑂"] = "𐐚",
		["𐑃"] = "𐐛",
		["𐑄"] = "𐐜",
		["𐑅"] = "𐐝",
		["𐑆"] = "𐐞",
		["𐑇"] = "𐐟",
		["𐑈"] = "𐐠",
		["𐑉"] = "𐐡",
		["𐑊"] = "𐐢",
		["𐑋"] = "𐐣",
		["𐑌"] = "𐐤",
		["𐑍"] = "𐐥",
		["𐑎"] = "𐐦",
		["𐑏"] = "𐐧"
	}
	local upper2lower = Flip(lower2upper, true)
	local metatable = {
		__index = function(tbl, key)
			return key
		end
	}
	setmetatable(lower2upper, metatable)
	setmetatable(upper2lower, metatable)
	_module_0.lower = function(str)
		local utf8Length = utf8len(str)
		local buffer, length = { }, 0
		for index = 1, utf8Length do
			length = length + 1
			buffer[length] = upper2lower[utf8get(str, index, utf8Length)]
		end
		return concat(buffer, "", 1, length)
	end
	_module_0.upper = function(str)
		local utf8Length = utf8len(str)
		local buffer, length = { }, 0
		for index = 1, utf8Length do
			length = length + 1
			buffer[length] = lower2upper[utf8get(str, index, utf8Length)]
		end
		return concat(buffer, "", 1, length)
	end
end
local utf8hex2char
utf8hex2char = function(str)
	return utf8byte2char(tonumber(str, 16))
end
_module_0.hex2char = utf8hex2char
do
	local escapeChars = {
		["\\n"] = "\n",
		["\\t"] = "\t",
		["\\0"] = "\0"
	}
	local escapeToChar
	escapeToChar = function(str)
		return escapeChars[str] or sub(str, 2, 2)
	end
	_module_0.unicode = function(str, isSequence)
		if isSequence == nil then
			isSequence = false
		end
		return gsub(gsub(str, isSequence and "\\[uU]([0-9a-fA-F]+)" or "[uU]%+([0-9a-fA-F]+)", utf8hex2char), "\\.", escapeToChar), nil
	end
end
_module_0.reverse = function(str)
	local utf8Length = utf8len(str)
	local position = utf8Length
	local buffer, length = { }, 0
	while position > 0 do
		length = length + 1
		buffer[length] = utf8get(str, position, utf8Length)
		position = position - 1
	end
	return concat(buffer, "", 1, length)
end
return _module_0

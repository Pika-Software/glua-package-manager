local _G = _G
local gpm, pairs, error, rawget, getfenv, getmetatable, setmetatable, istable, tostring, tonumber, CLIENT, SERVER, MENU_DLL = _G.gpm, _G.pairs, _G.error, _G.rawget, _G.getfenv, _G.getmetatable, _G.setmetatable, _G.istable, _G.tostring, _G.tonumber, _G.CLIENT, _G.SERVER, _G.MENU_DLL
local environment = gpm.environment
local string, table, util = environment.string, environment.table, environment.util
local byte, sub, gsub, format, len, find, match = string.byte, string.sub, string.gsub, string.format, string.len, string.find, string.match
local concat, remove = table.concat, table.remove
local min, max
do
	local _obj_0 = _G.math
	min, max = _obj_0.min, _obj_0.max
end
local getinfo
do
	local _obj_0 = _G.debug
	getinfo = _obj_0.getinfo
end
-- constants
environment.FCVAR_HIDDEN = 16
environment.TYPE_COLOR = 255
local isbool, isnumber, isstring, isfunction = _G.isbool, _G.isnumber, _G.isstring, _G.isfunction
do
	local running
	do
		local _obj_0 = _G.coroutine
		running = _obj_0.running
	end
	do
		local _tmp_0
		_tmp_0 = function(message, level)
			if running() then
				return error(message, level)
			end
			return error(tostring(message), level)
		end
		environment.throw = _tmp_0
		environment.error = _tmp_0
	end
end
-- table
if not table.unpack then
	table.unpack = _G.unpack
end
local bit = environment.bit
do
	local lshift, rshift
	do
		local _obj_0 = _G.bit
		lshift, rshift = _obj_0.lshift, _obj_0.rshift
	end
	bit.lshift = function(number, shift)
		return shift > 31 and 0x0 or lshift(number, shift)
	end
	bit.rshift = function(number, shift)
		return shift > 31 and 0x0 or rshift(number, shift)
	end
end
local rshift, band = bit.rshift, bit.band
do
	local select = _G.select
	if not table.pack then
		table.pack = function(...)
			return {
				n = select("#", ...),
				...
			}
		end
	end
	if not table.create then
		table.create = function(length, ...)
			if not length then
				return {
					...
				}, select("#", ...)
			end
			if length == 0 then
				return { }, 0
			end
			local count = select("#", ...)
			if count == 0 then
				return { }, 0
			end
			local result = { }
			if count == 1 then
				if length > 0 then
					for index = 1, length, 1 do
						result[index] = ...
					end
				else
					for index = -1, length, -1 do
						result[index] = ...
					end
				end
				return result, length
			end
			local args = {
				...
			}
			if length > 0 then
				for index = 1, length, 1 do
					result[index] = args[index]
				end
			else
				count = -length
				for index = count, 1, -1 do
					result[count - index + 1] = args[index]
				end
			end
			return result, length
		end
	end
end
table.move = function(source, first, last, offset, destination)
	if destination == nil then
		destination = source
	end
	for i = 0, last - first do
		destination[offset + i] = source[first + i]
	end
	return destination
end
table.Insert = function(source, first, last, offset, destination)
	if destination == nil then
		destination = source
	end
	while offset < 0 do
		offset = offset + (#destination + 2)
	end
	local steps = last - first
	for i = #destination, offset, -1 do
		destination[steps + i + 1] = destination[i]
	end
	for i = 0, steps do
		destination[offset + i] = source[first + i]
	end
	return destination
end
do
	local copy
	copy = function(source, isSequential, deepCopy, copyKeys, copies)
		if copyKeys == nil then
			copyKeys = false
		end
		if copies == nil then
			copies = { }
		end
		local result = copies[source]
		if not result then
			result = { }
			if deepCopy then
				setmetatable(result, getmetatable(source))
			end
			copies[source] = result
		end
		if isSequential then
			if deepCopy then
				for index = 1, #source do
					local value = source[index]
					if istable(value) then
						value = copy(value, true, true, copyKeys, copies)
					end
					result[index] = value
				end
			else
				for index = 1, #source do
					result[index] = source[index]
				end
			end
		elseif deepCopy then
			for key, value in pairs(source) do
				if istable(value) then
					value = copy(value, false, true, copyKeys, copies)
				end
				if copyKeys and istable(key) then
					result[copy(value, false, true, true, copies)] = value
				else
					result[key] = value
				end
			end
		else
			for key, value in pairs(source) do
				result[key] = value
			end
		end
		return result
	end
	table.copy = copy
end
if not table.insert then
	table.insert = function(tbl, index, value)
		local length = #tbl
		if value == nil then
			length = length + 1
			index, value = length, index
		end
		for j = length, index, -1 do
			tbl[j + 1] = tbl[j]
		end
		tbl[index] = value
		return index
	end
end
table.Add = function(destination, source, isSequential)
	local length = #destination
	if isSequential then
		for index = 1, #source do
			destination[length + index] = source[index]
		end
	else
		for _, value in pairs(source) do
			length = length + 1
			destination[length] = value
		end
	end
	return destination
end
table.RemoveByValue = function(tbl, any, isSequential)
	if isSequential then
		for index = 1, #tbl do
			if tbl[index] == any then
				remove(tbl, index)
				return index
			end
		end
	else
		for key, value in pairs(tbl) do
			if value == any then
				tbl[key] = nil
				return key
			end
		end
	end
	return nil
end
table.RemoveSameValues = function(tbl, any, isSequential)
	if isSequential then
		::removed::
		for index = 1, #tbl do
			if tbl[index] == any then
				remove(tbl, index)
				goto removed
			end
		end
	else
		for key, value in pairs(tbl) do
			if value == any then
				tbl[key] = nil
			end
		end
	end
	return nil
end
table.Flip = function(tbl, noCopy)
	if noCopy then
		local keys, length = { }, 0
		for key in pairs(tbl) do
			length = length + 1
			keys[length] = key
		end
		for i = 1, length do
			local key = keys[i]
			local value = tbl[key]
			tbl[key] = nil
			tbl[value] = key
		end
		return tbl
	end
	local result = { }
	for key, value in pairs(tbl) do
		result[value] = key
	end
	return result
end
table.HasValue = function(tbl, any, isSequential)
	if isSequential then
		for index = 1, #tbl do
			if tbl[index] == any then
				return true
			end
		end
	else
		for _, value in pairs(tbl) do
			if value == any then
				return true
			end
		end
	end
	return false
end
table.GetValues = function(tbl)
	local result, length = { }, 0
	for _, value in pairs(tbl) do
		length = length + 1
		result[length] = value
	end
	return result, length
end
table.GetValue = function(tbl, str)
	local pointer = 1
	for _ = 1, len(str) do
		local startPos = find(str, ".", pointer, true)
		if not startPos then
			break
		end
		tbl = tbl[sub(str, pointer, startPos - 1)]
		if tbl == nil then
			return
		end
		pointer = startPos + 1
	end
	return tbl[sub(str, pointer)]
end
table.SetValue = function(tbl, str, value)
	local pointer = 1
	for _ = 1, len(str) do
		local startPos = find(str, ".", pointer, true)
		if not startPos then
			break
		end
		local key = sub(str, pointer, startPos - 1)
		pointer = startPos + 1
		if not istable(tbl[key]) then
			tbl[key] = { }
		end
		tbl = tbl[key]
	end
	tbl[sub(str, pointer)] = value
end
table.Slice = function(tbl, startPos, endPos, step)
	local result, length = { }, 0
	for index = startPos or 1, endPos or #tbl, step or 1 do
		length = length + 1
		result[length] = tbl[index]
	end
	return result
end
do
	local equal
	equal = function(a, b)
		if a == b then
			return true
		end
		for key, value in pairs(a) do
			local alt = rawget(b, key)
			if alt == nil then
				return false
			end
			if not (getmetatable(value) or getmetatable(alt)) and istable(value) and istable(alt) then
				return equal(value, alt)
			end
			if value ~= alt then
				return false
			end
		end
		for key, value in pairs(b) do
			local alt = rawget(a, key)
			if alt == nil then
				return false
			end
			if not (getmetatable(value) or getmetatable(alt)) and istable(value) and istable(alt) then
				return equal(value, alt)
			end
			if value ~= alt then
				return false
			end
		end
		return true
	end
	table.Equal = equal
end
do
	local diffKeys
	diffKeys = function(a, b, result, length)
		if result == nil then
			result = { }
		end
		if length == nil then
			length = 0
		end
		if a == b then
			return { }, 0
		end
		for key, value in pairs(a) do
			local alt = rawget(b, key)
			if alt == nil then
				length = length + 1
				result[length] = key
			end
			if not (getmetatable(value) or getmetatable(alt)) and istable(value) and istable(alt) then
				result, length = diffKeys(value, alt, result, length)
			end
			if value ~= alt then
				length = length + 1
				result[length] = key
			end
		end
		for key, value in pairs(b) do
			local alt = rawget(a, key)
			if alt == nil then
				length = length + 1
				result[length] = key
			end
			if not (getmetatable(value) or getmetatable(alt)) and istable(value) and istable(alt) then
				result, length = diffKeys(value, alt, result, length)
			end
			if value ~= alt then
				length = length + 1
				result[length] = key
			end
		end
		return result, length
	end
	table.DiffKeys = diffKeys
end
do
	local diff
	diff = function(a, b)
		local result = { }
		for key, value in pairs(a) do
			local alt = rawget(b, key)
			if alt == nil then
				result[key] = {
					value,
					alt
				}
			end
			if not (getmetatable(value) or getmetatable(alt)) and istable(value) and istable(alt) then
				result[key] = diff(value, alt)
			end
			if value ~= alt then
				result[key] = {
					value,
					alt
				}
			end
		end
		for key, value in pairs(b) do
			if not result[key] then
				local alt = rawget(a, key)
				if alt == nil then
					result[key] = {
						value,
						alt
					}
				end
				if not (getmetatable(value) or getmetatable(alt)) and istable(value) and istable(alt) then
					result[key] = diff(value, alt)
				end
				if value ~= alt then
					result[key] = {
						value,
						alt
					}
				end
			end
		end
		return result
	end
	table.Diff = diff
end
table.IsSequential = function(tbl)
	local index = 1
	for _ in pairs(tbl) do
		if tbl[index] == nil then
			return false
		end
		index = index + 1
	end
	return true
end
do
	local next = _G.next
	table.IsEmpty = function(tbl)
		return next(tbl) == nil
	end
	table.Empty = function(tbl)
		for key in pairs(tbl) do
			tbl[key] = nil
		end
		return tbl
	end
end
table.GetKeys = function(tbl)
	local result, length = { }, 0
	for key in pairs(tbl) do
		length = length + 1
		result[length] = key
	end
	return result, length
end
table.Count = function(tbl)
	local length = 0
	for _ in pairs(tbl) do
		length = length + 1
	end
	return length
end
do
	local random
	do
		local _obj_0 = _G.math
		random = _obj_0.random
	end
	local index, length = 1, 0
	table.Shuffle = function(tbl)
		length = #tbl
		for i = length, 1, -1 do
			index = random(1, length)
			tbl[i], tbl[index] = tbl[index], tbl[i]
		end
		return tbl
	end
	do
		local keys = setmetatable({ }, {
			__mode = "v"
		})
		table.Random = function(tbl, isSequential)
			if isSequential then
				length = #tbl
				if length == 0 then
					return nil, nil
				end
				if length == 1 then
					index = 1
				else
					index = random(1, length)
				end
			else
				length = 0
				for key in pairs(tbl) do
					length = length + 1
					keys[length] = key
				end
				if length == 0 then
					return nil, nil
				end
				if length == 1 then
					index = keys[1]
				else
					index = keys[random(1, length)]
				end
			end
			return tbl[index], index
		end
	end
end
do
	local lower
	do
		local _obj_0 = _G.string
		lower = _obj_0.lower
	end
	local lowerKeyNames
	lowerKeyNames = function(tbl)
		for key, value in pairs(tbl) do
			if istable(value) then
				value = lowerKeyNames(value)
			end
			if isstring(key) then
				tbl[key] = nil
				tbl[lower(key)] = value
			elseif istable(key) then
				tbl[key] = nil
				tbl[lowerKeyNames(key)] = value
			end
		end
		return tbl
	end
	table.LowerKeyNames = lowerKeyNames
end
-- string
string.slice = sub
string.gmatch = string.gmatch or string.gfind
string.cut = function(str, index)
	return sub(str, 1, index - 1), sub(str, index, len(str))
end
string.insert = function(str, index, value)
	if value == nil then
		return str .. index
	end
	return sub(str, 1, index - 1) .. value .. sub(str, index, len(str))
end
string.StartsWith = function(str, startStr)
	return str == startStr or sub(str, 1, len(startStr)) == startStr
end
string.EndsWith = function(str, endStr)
	if endStr == "" or str == endStr then
		return true
	end
	local length = len(str)
	return sub(str, length - len(endStr) + 1, length) == endStr
end
string.concat = function(...)
	local args = {
		...
	}
	local length = #args
	if length == 0 then
		return ""
	end
	return concat(args, "", 1, length)
end
string.IndexOf = function(str, searchable, position, withPattern)
	if not searchable then
		return 0
	end
	if searchable == "" then
		return 1
	end
	position = max(position or 1, 1)
	if position > len(str) then
		return -1
	end
	return find(str, searchable, position, withPattern ~= true) or -1, nil
end
do
	local split
	split = function(str, pattern, withPattern)
		if not pattern then
			return {
				str
			}
		end
		if pattern == "" then
			local result = { }
			for index = 1, len(str) do
				result[index] = sub(str, index, index)
			end
			return result
		end
		withPattern = withPattern ~= true
		local result, rlength = { }, 0
		local pointer = 1
		while true do
			local startPos, endPos = find(str, pattern, pointer, withPattern)
			if not startPos then
				break
			end
			rlength = rlength + 1
			result[rlength] = sub(str, pointer, startPos - 1)
			pointer = endPos + 1
		end
		rlength = rlength + 1
		result[rlength] = sub(str, pointer)
		return result, rlength
	end
	string.Split = split
	string.Explode = function(pattern, str, withPattern)
		return split(str, pattern, withPattern)
	end
end
string.Count = function(str, pattern, withPattern)
	if not pattern then
		return 0
	end
	if pattern == "" then
		return len(str)
	end
	withPattern = withPattern ~= true
	local pointer = 1
	local count = 0
	while true do
		local startPos, endPos = find(str, pattern, pointer, withPattern)
		if not startPos then
			break
		end
		count = count + 1
		pointer = endPos + 1
	end
	return count
end
string.ByteSplit = function(str, byte0)
	if not byte0 then
		return {
			str
		}
	end
	local result, length = { }, 0
	local startPos, endPos = 1, 1
	local nextByte = byte(str, endPos)
	while nextByte do
		if nextByte == byte0 then
			length = length + 1
			result[length] = sub(str, startPos, endPos - 1)
			startPos = endPos + 1
		end
		endPos = endPos + 1
		nextByte = byte(str, endPos)
	end
	length = length + 1
	result[length] = sub(str, startPos, endPos - 1)
	return result, length
end
string.ByteCount = function(str, byte0)
	if not byte0 then
		return 0
	end
	local count = 0
	local pointer = 1
	local nextByte = byte(str, pointer)
	while nextByte do
		if nextByte == byte0 then
			count = count + 1
		end
		pointer = pointer + 1
		nextByte = byte(str, pointer)
	end
	return count
end
string.TrimByte = function(str, byte0, dir)
	if dir == nil then
		dir = 0
	end
	local startPos, endPos = 1, len(str)
	if dir ~= -1 then
		while byte(str, startPos) == byte0 do
			startPos = startPos + 1
			if startPos == endPos then
				return "", 0
			end
		end
	end
	if dir ~= 1 then
		while byte(str, endPos) == byte0 do
			endPos = endPos - 1
			if endPos == 0 then
				return "", 0
			end
		end
	end
	return sub(str, startPos, endPos), endPos - startPos + 1
end
string.TrimBytes = function(str, bytes, dir)
	if dir == nil then
		dir = 0
	end
	local startPos, endPos = 1, len(str)
	for key, value in pairs(bytes) do
		if isnumber(value) then
			bytes[value] = true
			bytes[key] = nil
		elseif isbool(value) then
			if not isnumber(key) then
				error("invalid bytes", 2)
			end
		else
			error("invalid bytes", 2)
		end
	end
	if dir ~= -1 then
		while bytes[byte(str, startPos)] do
			startPos = startPos + 1
			if startPos == endPos then
				return "", 0
			end
		end
	end
	if dir ~= 1 then
		while bytes[byte(str, endPos)] do
			endPos = endPos - 1
			if endPos == 0 then
				return "", 0
			end
		end
	end
	return sub(str, startPos, endPos), endPos - startPos + 1
end
do
	local chars = {
		[0x28] = "%(",
		[0x29] = "%)",
		[0x5B] = "%[",
		[0x5D] = "%]",
		[0x2E] = "%.",
		[0x25] = "%%",
		[0x2B] = "%+",
		[0x2D] = "%-",
		[0x2A] = "%*",
		[0x3F] = "%?",
		[0x5E] = "%^",
		[0x24] = "%$"
	}
	local patternSafe
	patternSafe = function(str)
		local result, size = { }, 0
		local startPos = 1
		local length = len(str)
		for index = 1, length do
			local byte0 = byte(str, index)
			if byte0 == 0x00 then
				size = size + 1
				result[size] = sub(str, startPos, index - 1) .. "%z"
				startPos = index + 1
			else
				local sybol = chars[byte0]
				if sybol then
					size = size + 1
					if startPos ~= index then
						result[size] = sub(str, startPos, index - 1) .. sybol
					else
						result[size] = sybol
					end
					startPos = index + 1
				end
			end
		end
		size = size + 1
		result[size] = sub(str, startPos, length)
		if size == 0 then
			return str
		end
		if size == 1 then
			return result[1]
		end
		return concat(result, "", 1, size)
	end
	string.PatternSafe = patternSafe
	local trim
	trim = function(str, pattern, dir)
		if dir == nil then
			dir = 0
		end
		if pattern then
			if pattern == "" then
				pattern = "%s"
			else
				local length = len(pattern)
				if length == 1 then
					pattern = chars[byte(pattern, 1)] or pattern
				elseif length ~= 2 or byte(pattern, 1) ~= 0x25 then
					pattern = "[" .. pattern .. "]"
				end
			end
		else
			pattern = "%s"
		end
		-- left
		if dir == 1 then
			return match(str, "^(.-)" .. pattern .. "*$") or str
		end
		-- right
		if dir == -1 then
			return match(str, "^" .. pattern .. "*(.+)$") or str
		end
		return match(str, "^" .. pattern .. "*(.-)" .. pattern .. "*$") or str
	end
	string.Trim = trim
	string.TrimLeft = function(str, pattern)
		return trim(str, pattern, 1)
	end
	string.TrimRight = function(str, pattern)
		return trim(str, pattern, -1)
	end
	string.IsURL = function(str)
		return match(str, "^%l[%l+-.]+%:[^%z\x01-\x20\x7F-\xFF\"<>^`:{-}]*$") ~= nil
	end
	string.IsSteamID = function(str)
		return match(str, "^STEAM_[0-5]:[01]:%d+$") ~= nil
	end
end
do
	local isNumber
	do
		local ascii_numbers = {
			[0x30] = true,
			[0x31] = true,
			[0x32] = true,
			[0x33] = true,
			[0x34] = true,
			[0x35] = true,
			[0x36] = true,
			[0x37] = true,
			[0x38] = true,
			[0x39] = true
		}
		isNumber = function(str, start, finish)
			for index = start or 1, finish or len(str) do
				if ascii_numbers[byte(str, index, index)] == nil then
					return false
				end
			end
			return true
		end
		string.IsNumber = isNumber
	end
	string.IsSteamID64 = function(str)
		if len(str) == 17 and sub(str, 1, 3) == "765" then
			return isNumber(str, 4, 17)
		end
		return false
	end
end
string.Extract = function(str, pattern, default)
	local startPos, endPos, matched = find(str, pattern, 1, false)
	if startPos then
		return sub(str, 1, startPos - 1) .. sub(str, endPos + 1), matched or default
	end
	return str, default
end
string.ToBytes = function(str)
	local length = len(str)
	return {
		byte(str, 1, length)
	}, length
end
string.Left = function(str, num)
	return sub(str, 1, num)
end
string.Right = function(str, num)
	return sub(str, -num)
end
do
	local replace
	replace = function(str, searchable, replaceable, withPattern)
		if withPattern then
			return gsub(str, searchable, replaceable)
		end
		local startPos, endPos = find(str, searchable, 1, true)
		while startPos do
			str = sub(str, 1, startPos - 1) .. replaceable .. sub(str, endPos + 1)
			startPos, endPos = find(str, searchable, endPos + 1, true)
		end
		return str
	end
	string.Replace = replace
	string.SQLSafe = function(str, noQuotes)
		str = replace(tostring(str), "'", "''", false)
		local null_chr = find(str, "\0")
		if null_chr then
			str = sub(str, 1, null_chr - 1)
		end
		if noQuotes then
			return str
		end
		return "'" .. str .. "'"
	end
end
string.IsBytecode = function(str)
	return byte(str, 1) == 0x1B
end
local argument, findMetaTable, registerMetaTable, CLIENT_SERVER
do
	local FindMetaTable, RegisterMetaTable, TypeID, rawset, type = _G.FindMetaTable, _G.RegisterMetaTable, _G.TypeID, _G.rawset, _G.type
	local Count = table.Count
	-- client/server
	CLIENT_SERVER = CLIENT or SERVER
	environment.CLIENT_SERVER = CLIENT_SERVER
	-- client/menu
	local CLIENT_MENU = CLIENT and MENU_DLL
	environment.CLIENT_MENU = CLIENT_MENU
	local static = {
		["unknown"] = -1,
		["nil"] = 0,
		["boolean"] = 1,
		["light userdata"] = 2,
		["number"] = 3,
		["string"] = 4,
		["table"] = 5,
		["function"] = 6,
		["userdata"] = 7,
		["thread"] = 8,
		["Entity"] = CLIENT_SERVER and 9 or nil,
		["Player"] = CLIENT_SERVER and 9 or nil,
		["Weapon"] = CLIENT_SERVER and 9 or nil,
		["NPC"] = CLIENT_SERVER and 9 or nil,
		["Vehicle"] = CLIENT_SERVER and 9 or nil,
		["CSEnt"] = CLIENT and 9 or nil,
		["NextBot"] = CLIENT_SERVER and 9 or nil,
		["Vector"] = 10,
		["Angle"] = 11,
		["PhysObj"] = CLIENT_SERVER and 12 or nil,
		["ISave"] = CLIENT_SERVER and 13 or nil,
		["IRestore"] = CLIENT_SERVER and 14 or nil,
		["CTakeDamageInfo"] = CLIENT_SERVER and 15 or nil,
		["CEffectData"] = CLIENT_SERVER and 16 or nil,
		["CMoveData"] = CLIENT_SERVER and 17 or nil,
		["CRecipientFilter"] = SERVER and 18 or nil,
		["CUserCmd"] = CLIENT_SERVER and 19 or nil,
		["IMaterial"] = 21,
		["Panel"] = CLIENT_MENU and 22 or nil,
		["CLuaParticle"] = CLIENT and 23 or nil,
		["CLuaEmitter"] = CLIENT and 24 or nil,
		["ITexture"] = 25,
		["bf_read"] = CLIENT_SERVER and 26 or nil,
		["ConVar"] = 27,
		["IMesh"] = CLIENT_MENU and 28 or nil,
		["VMatrix"] = 29,
		["CSoundPatch"] = CLIENT_SERVER and 30 or nil,
		["pixelvis_handle_t"] = CLIENT and 31 or nil,
		["dlight_t"] = CLIENT and 32 or nil,
		["IVideoWriter"] = CLIENT_MENU and 33 or nil,
		["File"] = 34,
		["CLuaLocomotion"] = SERVER and 35 or nil,
		["PathFollower"] = SERVER and 36 or nil,
		["CNavArea"] = SERVER and 37 or nil,
		["IGModAudioChannel"] = CLIENT and 38 or nil,
		["CNavLadder"] = SERVER and 39 or nil,
		["CNewParticleEffect"] = CLIENT and 40 or nil,
		["ProjectedTexture"] = CLIENT and 41 or nil,
		["PhysCollide"] = CLIENT_SERVER and 42 or nil,
		["SurfaceInfo"] = CLIENT_SERVER and 43 or nil,
		["Color"] = 255
	}
	local metatables = { }
	environment.inext = _G.ipairs(metatables)
	findMetaTable = function(name)
		argument(name, 1, "string")
		local metatable = metatables[name]
		if metatable then
			return metatable
		end
		metatable = FindMetaTable(name)
		if not istable(metatable) then
			return nil
		end
		local id = static[name] or rawget(metatable, "MetaID") or rawget(metatable, "__metatable_id") or (256 + Count(metatables))
		if not isnumber(id) or id < 0 then
			return nil
		end
		rawset(metatable, "__metatable_name", name)
		rawset(metatable, "__metatable_id", id)
		rawset(metatable, "MetaName", name)
		rawset(metatable, "MetaID", id)
		metatables[name] = metatable
		return metatable
	end
	util.FindMetaTable = findMetaTable
	registerMetaTable = function(name, new)
		argument(name, 1, "string")
		argument(new, 2, "table")
		local old = findMetaTable(name)
		if not old then
			if RegisterMetaTable then
				RegisterMetaTable(name, new)
			end
			local id = static[name] or rawget(new, "MetaID") or rawget(new, "__metatable_id") or (256 + Count(metatables))
			if not isnumber(id) or id < 0 then
				return nil
			end
			rawset(new, "__metatable_name", name)
			rawset(new, "__metatable_id", id)
			rawset(new, "MetaName", name)
			rawset(new, "MetaID", id)
			metatables[name] = new
			return new
		end
		if new ~= old then
			local id = static[name] or rawget(old, "MetaID") or rawget(old, "__metatable_id") or (256 + Count(metatables))
			if not isnumber(id) or id < 0 then
				return nil
			end
			for key in pairs(old) do
				old[key] = nil
			end
			setmetatable(old, {
				__index = new,
				__newindex = new
			})
			rawset(old, "__metatable_name", name)
			rawset(old, "__metatable_id", id)
			rawset(old, "MetaName", name)
			rawset(old, "MetaID", id)
		end
		return old
	end
	util.RegisterMetaTable = registerMetaTable
	local type_fn
	type_fn = function(any)
		local name
		local metatable = getmetatable(any)
		if metatable then
			local cls = rawget(metatable, "__class")
			if cls then
				name = rawget(cls, "__name")
			else
				name = rawget(metatable, "__metatable_name") or rawget(metatable, "MetaName")
			end
		end
		if name then
			return name
		end
		return type(any)
	end
	environment.type = type_fn
	-- js like type
	environment.typeof = function(any, ...)
		return type_fn(any), ...
	end
	if isfunction(TypeID) then
		environment.TypeID = function(any)
			local metatable = getmetatable(any)
			if metatable then
				local id = rawget(metatable, "__metatable_id")
				if id then
					return id
				end
			end
			return TypeID(any)
		end
	else
		environment.TypeID = function(any)
			local metatable = getmetatable(any)
			if metatable then
				local id = rawget(metatable, "__metatable_id")
				if id then
					return id
				end
			end
			-- TYPE_TABLE
			return 5
		end
	end
	do
		local _tmp_0
		_tmp_0 = function(any, a, b, ...)
			if isstring(a) then
				if isstring(b) then
					a = {
						a,
						b,
						...
					}
				else
					return type_fn(any) == a
				end
			end
			local name = type_fn(any)
			for _index_0 = 1, #a do
				local str = a[_index_0]
				if name == str then
					return true
				end
			end
			return false
		end
		environment.isinstance = _tmp_0
		environment.instanceof = _tmp_0
	end
	argument = function(value, num, ...)
		local typeName = type_fn(value)
		local args = {
			...
		}
		local length = #args
		local expected
		for index = 1, length do
			local searchable = args[index]
			if typeName == searchable or searchable == "any" then
				return value
			elseif isfunction(searchable) then
				expected = searchable(value, typeName, num)
				if not isstring(expected) then
					return value
				end
			end
		end
		if not expected then
			if length == 0 then
				expected = "none"
			elseif length == 1 then
				expected = args[1]
			else
				expected = concat(args, "/")
			end
		end
		error("bad argument #" .. num .. " to \'" .. (getinfo(2, "n").name or "unknown") .. "\' ('" .. expected .. "' expected, got '" .. typeName .. "')", 3)
		return nil
	end
	environment.argument = argument
end
local newClass
do
	local class__call
	class__call = function(cls, ...)
		local init = rawget(cls, "__init")
		if not init then
			local parent = rawget(cls, "__parent")
			if parent then
				init = rawget(parent, "__init")
			end
		end
		local base = rawget(cls, "__base")
		if not base then
			error("class '" .. tostring(cls) .. "' has been corrupted", 2)
		end
		local obj = setmetatable({ }, base)
		if init then
			local override, new = init(obj, ...)
			if override then
				return new
			end
		end
		return obj
	end
	local extends__index
	extends__index = function(cls, key)
		local base = rawget(cls, "__base")
		if not base then
			return nil
		end
		local value = rawget(base, key)
		if value == nil then
			local parent = rawget(cls, "__parent")
			if parent then
				value = parent[key]
			end
		end
		return value
	end
	local tostring_object
	tostring_object = function(obj)
		return format("@object '%s': %p", obj.__class.__name, obj)
	end
	local tostring_class
	tostring_class = function(cls)
		return format("@class '%s': %p", cls.__name, cls)
	end
	local classExtends
	classExtends = function(cls, parent)
		argument(cls, 1, "class")
		argument(parent, 2, "class")
		local base = rawget(cls, "__base")
		if not base then
			error("class '" .. tostring(cls) .. "' has been corrupted", 2)
		end
		local metatable = getmetatable(cls)
		if not metatable then
			error("metatable of class '" .. tostring(cls) .. "' has been corrupted", 2)
		end
		local base_parent = rawget(parent, "__base")
		if not base_parent then
			error("invalid parent", 2)
		end
		if metatable.__index ~= base then
			error("class '" .. tostring(cls) .. "' has already been extended", 2)
		end
		if rawget(base, "__tostring") == tostring_object then
			rawset(base, "__tostring", nil)
		end
		metatable.__index = extends__index
		setmetatable(base, {
			__index = base_parent
		})
		for key, value in pairs(base_parent) do
			if sub(key, 1, 2) == "__" and rawget(base, key) == nil and not (key == "__index" and value == base_parent) then
				rawset(base, key, value)
			end
		end
		local inherited = rawget(parent, "__inherited")
		if inherited then
			inherited(parent, cls)
		end
		rawset(cls, "__parent", parent)
		rawset(base, "__class", cls)
		return cls
	end
	environment.extends = classExtends
	newClass = function(name, base, static, parent)
		argument(name, 1, "string")
		if base then
			argument(base, 2, "table")
			rawset(base, "__index", rawget(base, "__index") or base)
			rawset(base, "__tostring", rawget(base, "__tostring") or tostring_object)
		else
			base = {
				__tostring = tostring_object
			}
			base.__index = base
		end
		if static then
			argument(static, 3, "table")
			rawset(static, "__init", rawget(base, "new"))
			rawset(static, "__name", name)
			rawset(static, "__base", base)
		else
			static = {
				__init = rawget(base, "new"),
				__name = name,
				__base = base
			}
		end
		rawset(base, "new", nil)
		setmetatable(static, {
			__tostring = tostring_class,
			__metatable_name = "class",
			__call = class__call,
			__metatable_id = 5,
			__index = base
		})
		if parent ~= nil then
			classExtends(static, parent)
		else
			rawset(base, "__class", static)
		end
		return static
	end
	environment.class = newClass
	environment.extend = function(parent, name, base, static)
		return newClass(name, base, static, parent)
	end
end
do
	local gmatch, ByteSplit, TrimBytes = string.gmatch, string.ByteSplit, string.TrimBytes
	do
		local isDomain
		isDomain = function(str)
			if str == "" then
				return false, "empty string"
			end
			local length = len(str)
			if length > 253 then
				return false, "domain is too long"
			end
			if byte(str, 1) == 0x2E then
				return false, "first character in domain cannot be a dot"
			end
			if byte(str, length) == 0x2E then
				return false, "last character in domain cannot be a dot"
			end
			if not match(str, "^[%l][%l%d.]*%.[%l]+$") then
				return false, "invalid domain"
			end
			local _list_0 = ByteSplit(str, 0x2E)
			for _index_0 = 1, #_list_0 do
				local label = _list_0[_index_0]
				if label == "" then
					return false, "empty label in domain"
				end
				if len(label) > 63 then
					return false, "label '" .. label .. "' in domain is too long"
				end
			end
			return true
		end
		string.IsDomain = isDomain
		string.IsEmail = function(str)
			if str == "" then
				return false, "empty string"
			end
			local lastAt = find(str, "[^%@]+$")
			if not lastAt then
				return false, "@ symbol is missing"
			end
			if lastAt >= 65 then
				return nil, "username is too long"
			end
			local username = sub(str, 1, lastAt - 2)
			if username == nil or username == "" then
				return false, "username is missing"
			end
			if find(username, "[%c]") then
				return false, "invalid characters in username"
			end
			if find(username, "%p%p") then
				return false, "too many periods in username"
			end
			if byte(username, 1) == 0x22 and byte(username, len(username)) ~= 0x22 then
				return nil, "invalid usage of quotes"
			end
			return isDomain(sub(str, lastAt, len(str)))
		end
	end
	local SPACE_BYTES = {
		0x20,
		0x09,
		0x0D,
		0x0A
	}
	environment.SPACE_BYTES = SPACE_BYTES
	local default_types = {
		["nil"] = true,
		["boolean"] = true,
		["number"] = true,
		["string"] = true,
		["table"] = true,
		["function"] = true,
		["thread"] = true,
		["userdata"] = true
	}
	local __tostring
	__tostring = function(self)
		return format("@type '%s': %p", getmetatable(self).__metatable_name, self)
	end
	environment.Type = newClass("Type", {
		new = function(self, name, scheme, classes)
			argument(name, 1, "string")
			argument(scheme, 2, "string")
			if classes ~= nil then
				argument(classes, 3, "table")
				for className, cls in pairs(classes) do
					if not isstring(className) then
						error("external type name must be a string")
					end
					if not istable(cls) then
						error("external type must be a class")
					end
					if rawget(cls, "__name") ~= className then
						error("external type name mismatch '" .. (rawget(cls, "__name") or "nil") .. " ~= " .. className .. "'")
					end
				end
				classes[name] = self
			else
				classes = {
					[name] = self
				}
			end
			self.external = classes
			self.name = name
			local required, length = { }, 0
			local fields = { }
			for str in gmatch(scheme, "(.-)\n") do
				local line = TrimBytes(str, SPACE_BYTES, 0)
				if byte(line, 1) == 0x23 then
					goto _continue_0
				end
				local commentPos = find(line, "#", 1, true)
				if commentPos then
					line = sub(line, 1, commentPos - 1)
				end
				local parts, count = ByteSplit(line, 0x3A)
				if count > 2 then
					error("invalid type definition, expected 'name: type'")
				end
				local typeName, typeLength = TrimBytes(parts[2], SPACE_BYTES, 1)
				local fieldName = TrimBytes(parts[1], SPACE_BYTES, -1)
				if byte(typeName, typeLength) == 0x3F then
					typeLength = typeLength - 1
					typeName = sub(typeName, 1, typeLength)
				else
					length = length + 1
					required[length] = fieldName
				end
				local isArray = false
				if byte(typeName, typeLength - 1) == 0x5B and byte(typeName, typeLength) == 0x5D then
					isArray = true
					typeLength = typeLength - 2
					typeName = sub(typeName, 1, -3)
				end
				if not (default_types[typeName] or (classes and classes[typeName])) then
					error("unknown type '" .. typeName .. "'")
				end
				fields[fieldName] = {
					typeName,
					isArray
				}
				::_continue_0::
			end
			self.metatable = {
				__metatable_name = name,
				__metatable_id = 5,
				__tostring = __tostring
			}
			self.required = required
			self.fields = fields
			return nil
		end,
		__call = function(self, tbl)
			local required, fields = self.required, self.fields
			for _index_0 = 1, #required do
				local key = required[_index_0]
				if not tbl[key] then
					local data = fields[key]
					if data[2] then
						error("expected field '" .. key .. ":" .. data[1] .. "[]', got '" .. key .. ":nil'", 2)
					else
						error("expected field '" .. key .. ":" .. data[1] .. "', got '" .. key .. ":nil'", 2)
					end
				end
			end
			for key, value in pairs(tbl) do
				local data = fields[key]
				if not data then
					error("unknown field '" .. key .. ":" .. type(value) .. "'", 2)
				end
				local typeName = data[1]
				if data[2] then
					if not istable(value) then
						error("expected field '" .. key .. ":" .. typeName .. "[]', got '" .. key .. ":" .. type(value) .. "'", 2)
					end
					for index = 1, #value do
						if type(value[index]) ~= typeName then
							error("expected field '" .. key .. ":" .. typeName .. "[" .. index .. "]', got '" .. key .. ":" .. type(value[index]) .. "[" .. index .. "]'", 2)
						end
					end
				elseif type(value) ~= typeName then
					error("expected field '" .. key .. ":" .. typeName .. "', got '" .. key .. ":" .. type(value) .. "'", 2)
				end
			end
			return setmetatable(tbl, self.metatable)
		end
	})
end
do
	local debug = _G.debug
	do
		local name, func = debug.getupvalue(_G.Material, 1)
		if name == "C_Material" then
			environment.CMaterial = func
		end
	end
	do
		local getmetatabled = debug.getmetatable or getmetatable
		local setmetatabled = debug.setmetatable or setmetatable
		-- null
		do
			local null = _G.newproxy(true)
			environment.null = null
			local metatable = getmetatabled(null)
			metatable.__metatable_name = "null"
			metatable.__metatable_id = 0
			metatable.MetaName = "null"
			metatable.MetaID = 0
			metatable.__tostring = function()
				return "null"
			end
			registerMetaTable("null", metatable)
		end
		-- nil
		local object = nil
		do
			local metatable = getmetatabled(object)
			if metatable == nil then
				metatable = { }
				setmetatabled(object, metatable)
			end
			registerMetaTable("nil", metatable)
		end
		-- boolean
		object = false
		do
			local metatable = getmetatabled(object)
			if metatable == nil then
				metatable = { }
				setmetatabled(object, metatable)
			end
			registerMetaTable("boolean", metatable)
			isbool = function(any)
				return getmetatable(any) == metatable
			end
		end
		environment.isbool = isbool
		-- number
		object = 0
		do
			local metatable = getmetatabled(object)
			if metatable == nil then
				metatable = { }
				setmetatabled(object, metatable)
			end
			registerMetaTable("number", metatable)
			isnumber = function(any)
				return getmetatable(any) == metatable
			end
		end
		environment.isnumber = isnumber
		-- string
		object = ""
		do
			local metatable = getmetatabled(object)
			if metatable == nil then
				metatable = { }
				setmetatabled(object, metatable)
			end
			registerMetaTable("string", metatable)
			isstring = function(any)
				return getmetatable(any) == metatable
			end
		end
		environment.isstring = isstring
		-- function
		object = function() end
		do
			local metatable = getmetatabled(object)
			if metatable == nil then
				metatable = { }
				setmetatabled(object, metatable)
			end
			registerMetaTable("function", metatable)
			isfunction = function(any)
				return getmetatable(any) == metatable
			end
			environment.iscallable = function(obj)
				local tbl = getmetatable(obj)
				if tbl and (tbl == metatable or tbl.__call) then
					return true
				end
				return false
			end
		end
		environment.isfunction = isfunction
		-- Make jit happy <3
		environment.debug.fempty = object
		-- thread
		object = _G.coroutine.create(object)
		do
			local metatable = getmetatabled(object)
			if metatable == nil then
				metatable = { }
				setmetatabled(object, metatable)
			end
			registerMetaTable("thread", metatable)
			environment.isthread = function(any)
				return getmetatable(any) == metatable
			end
		end
	end
	-- Vector
	do
		local metatable = findMetaTable("Vector")
		environment.isvector = function(any)
			return getmetatable(any) == metatable
		end
	end
	-- Angle
	do
		local metatable = findMetaTable("Angle")
		environment.isangle = function(any)
			return getmetatable(any) == metatable
		end
	end
	-- VMatrix
	do
		local metatable = findMetaTable("VMatrix")
		environment.ismatrix = function(any)
			return getmetatable(any) == metatable
		end
	end
	-- ConVar
	do
		local metatable = findMetaTable("ConVar")
		environment.isconvar = function(any)
			return getmetatable(any) == metatable
		end
	end
	-- IMesh
	if CLIENT or MENU_DLL then
		local metatable = findMetaTable("IMesh")
		if metatable == nil then
			environment.ismesh = function(any)
				return getmetatable(any) == metatable
			end
		else
			environment.ismesh = function(any)
				return false
			end
		end
	end
	-- Dynamic Light
	if CLIENT then
		local metatable = findMetaTable("dlight_t")
		environment.isdynamiclight = function(any)
			return getmetatable(any) == metatable
		end
	end
	local ENTITY = findMetaTable("Entity")
	-- entity
	environment.isentity = function(any)
		local metatable = getmetatable(any)
		return metatable and metatable.__metatable_id == 9
	end
	-- player
	do
		local metatable = findMetaTable("Player")
		local is
		is = function(any)
			return getmetatable(any) == metatable
		end
		ENTITY.IsPlayer = is
		environment.IsPlayer = is
	end
	-- weapon
	do
		local metatable = findMetaTable("Weapon")
		local is
		is = function(any)
			return getmetatable(any) == metatable
		end
		ENTITY.IsWeapon = is
		environment.IsWeapon = is
	end
	-- npc
	do
		local metatable = findMetaTable("NPC")
		local is
		is = function(any)
			return getmetatable(any) == metatable
		end
		ENTITY.IsNPC = is
		environment.IsNPC = is
	end
	-- NextBot
	do
		local metatable = findMetaTable("NextBot")
		local is
		is = function(any)
			return getmetatable(any) == metatable
		end
		ENTITY.IsNextBot = is
		environment.IsNextBot = is
	end
	-- Vehicle
	do
		local metatable = findMetaTable("Vehicle")
		local is
		is = function(any)
			return getmetatable(any) == metatable
		end
		ENTITY.IsVehicle = is
		environment.IsVehicle = is
	end
	-- CSEnt
	if CLIENT then
		do
			local metatable = findMetaTable("CSEnt")
			local is
			is = function(any)
				return getmetatable(any) == metatable
			end
			ENTITY.IsClientEntity = is
			environment.IsClientEntity = is
		end
		local LocalPlayer, NULL = _G.LocalPlayer, _G.NULL
		local IsValid = ENTITY.IsValid
		local player
		environment.LocalPlayer = function()
			if player == nil then
				local entity = LocalPlayer()
				if IsValid(entity) then
					player = entity
					return entity
				end
				return NULL
			end
			return player
		end
	end
	-- Panel
	if CLIENT or MENU_DLL then
		local metatable = findMetaTable("Panel")
		environment.ispanel = function(any)
			return getmetatable(any) == metatable
		end
	end
end
-- my cool math '^'
local math = setmetatable(_G.include("gpm/libs/math.lua"), table.SandboxMetatable(_G.math))
local debug = environment.debug
local clamp, lerp = math.clamp, math.lerp
environment.math = math
do
	local CMaterial = environment.CMaterial
	local decimal2binary = math.decimal2binary
	environment.MPAR_VERTEXLITGENERIC = 0x80
	environment.MPAR_NOCULL = 0x40
	environment.MPAR_ALPHATEST = 0x20
	environment.MPAR_MIPS = 0x10
	environment.MPAR_NOCLAMP = 0x8
	environment.MPAR_SMOOTH = 0x4
	environment.MPAR_IGNOREZ = 0x2
	environment.Material = function(name, parameters, flags)
		if parameters then
			argument(name, 1, "number", "string")
			if isstring(parameters) then
				if parameters == "" then
					return CMaterial(name)
				end
				return CMaterial(name, (find(parameters, "vertexlitgeneric", 1, true) and "1" or "0") .. (find(parameters, "nocull", 1, true) and "1" or "0") .. (find(parameters, "alphatest", 1, true) and "1" or "0") .. (find(parameters, "mips", 1, true) and "1" or "0") .. (find(parameters, "noclamp", 1, true) and "1" or "0") .. (find(parameters, "smooth", 1, true) and "1" or "0") .. (find(parameters, "ignorez", 1, true) and "1" or "0"))
			end
			if parameters > 0 then
				return CMaterial(name, decimal2binary(parameters, true))
			end
		end
		return CMaterial(name)
	end
end
math.type = function(number)
	if isnumber(number) then
		return (number % 1) == 0 and "integer" or "float"
	end
	return nil
end
debug.fcall = function(func, ...)
	return func(...)
end
debug.getstack = function(startPos)
	local stack, length = { }, 0
	for level = 1 + (startPos or 1), 16 do
		local info = getinfo(level, "Snluf")
		if not info then
			break
		end
		length = length + 1
		stack[length] = info
	end
	return stack, length
end
debug.getfmain = function()
	for level = 2, 16 do
		local info = getinfo(level, "fS")
		if not info then
			break
		end
		if info.what == "main" then
			return info.func
		end
	end
end
do
	local lff
	lff = function(a, b)
		return b
	end
	debug.getfpath = function(location)
		local info = getinfo(location, "S")
		if info.what == "main" then
			return gsub(gsub(sub(info.source, 2), "^(.-)(lua/.*)$", lff), "^(.-)([%w_]+/gamemode/.*)$", lff)
		end
		return ""
	end
end
do
	local char = string.char
	local abs = math.abs
	-- color correction credits goes to 0x00000ED (https://github.com/0x00000ED)
	local colorCorrection = {
		[0] = 0,
		5,
		8,
		10,
		12,
		13,
		14,
		15,
		16,
		17,
		18,
		19,
		20,
		21,
		22,
		22,
		23,
		24,
		25,
		26,
		27,
		28,
		28,
		29,
		30,
		31,
		32,
		33,
		34,
		35,
		35,
		36,
		37,
		38,
		39,
		40,
		41,
		42,
		42,
		43,
		44,
		45,
		46,
		47,
		48,
		49,
		50,
		51,
		51,
		52,
		53,
		54,
		55,
		56,
		57,
		58,
		59,
		60,
		60,
		61,
		62,
		63,
		64,
		65,
		66,
		67,
		68,
		69,
		70,
		71,
		72,
		73,
		73,
		74,
		75,
		76,
		77,
		78,
		79,
		80,
		81,
		82,
		83,
		84,
		85,
		86,
		87,
		88,
		88,
		89,
		90,
		91,
		92,
		93,
		94,
		95,
		96,
		97,
		98,
		99,
		100,
		101,
		102,
		103,
		104,
		105,
		106,
		107,
		108,
		109,
		109,
		111,
		111,
		113,
		113,
		114,
		115,
		116,
		117,
		118,
		119,
		120,
		121,
		122,
		123,
		124,
		125,
		126,
		127,
		128,
		129,
		130,
		131,
		132,
		133,
		134,
		135,
		136,
		137,
		138,
		139,
		140,
		141,
		142,
		143,
		144,
		145,
		146,
		147,
		148,
		149,
		150,
		151,
		152,
		153,
		154,
		155,
		156,
		157,
		157,
		158,
		159,
		160,
		162,
		163,
		164,
		165,
		165,
		167,
		168,
		168,
		170,
		170,
		172,
		172,
		174,
		174,
		176,
		177,
		177,
		178,
		180,
		181,
		182,
		183,
		184,
		185,
		186,
		187,
		188,
		189,
		190,
		191,
		192,
		193,
		194,
		195,
		196,
		197,
		198,
		199,
		200,
		201,
		202,
		203,
		204,
		205,
		206,
		207,
		208,
		209,
		210,
		211,
		212,
		213,
		214,
		215,
		216,
		217,
		218,
		219,
		220,
		221,
		222,
		223,
		224,
		225,
		226,
		227,
		228,
		229,
		230,
		231,
		232,
		233,
		234,
		236,
		237,
		237,
		238,
		239,
		241,
		242,
		243,
		244,
		245,
		246,
		247,
		248,
		249,
		250,
		251,
		252,
		253,
		254,
		255
	}
	local vconst = 1 / 255
	local colorClass
	local internal = setmetatable({
		__tostring = function(self)
			return format("%d %d %d %d", self.r, self.g, self.b, self.a)
		end,
		__eq = function(self, other)
			return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a
		end,
		__unm = function(self)
			return self:Copy():Invert()
		end,
		__add = function(self, color)
			return colorClass(self.r + color.r, self.g + color.g, self.b + color.b, self.a + color.a)
		end,
		__sub = function(self, color)
			return colorClass(self.r - color.r, self.g - color.g, self.b - color.b, self.a - color.a)
		end,
		__mul = function(self, other)
			if isnumber(other) then
				return colorClass(self.r * other, self.g * other, self.b * other, self.a * other)
			end
			return colorClass(self.r * other.r, self.g * other.g, self.b * other.b, self.a * other.a)
		end,
		__div = function(self, other)
			if isnumber(other) then
				return colorClass(self.r / other, self.g / other, self.b / other, self.a / other)
			end
			return colorClass(self.r / other.r, self.g / other.g, self.b / other.b, self.a / other.a)
		end,
		__lt = function(self, other)
			return (self.r + self.g + self.b + self.a) < (other.r + other.g + other.b + other.a)
		end,
		__le = function(self, other)
			return (self.r + self.g + self.b + self.a) <= (other.r + other.g + other.b + other.a)
		end,
		__concat = function(self, value)
			return self:ToHex() .. tostring(value)
		end,
		new = function(self, r, g, b, a)
			if istable(r) then
				a = a or r[4] or r.a
				b = b or r[3] or r.b
				g = g or r[2] or r.g
				r = r[1] or r.r
			end
			r = r or 0
			g = g or 0
			b = b or 0
			a = a or 255
			self.r = clamp(r, 0, 255)
			self.g = clamp(g, 0, 255)
			self.b = clamp(b, 0, 255)
			self.a = clamp(a, 0, 255)
		end,
		DoCorrection = function(self)
			self.r = colorCorrection[self.r]
			self.g = colorCorrection[self.g]
			self.b = colorCorrection[self.b]
			return self
		end,
		Copy = function(self)
			return colorClass(self.r, self.g, self.b, self.a)
		end,
		ToTable = function(self)
			return {
				self.r,
				self.g,
				self.b,
				self.a
			}
		end,
		ToHex = function(self)
			return format("#%02x%02x%02x", self.r, self.g, self.b)
		end,
		ToBinary = function(self)
			return char(self.r, self.g, self.b, self.a)
		end,
		ToVector = function(self)
			return Vector(self.r * vconst, self.g * vconst, self.b * vconst)
		end,
		ToHSL = _G.ColorToHSL,
		ToHSV = _G.ColorToHSV,
		ToHWB = function(self)
			local hue, saturation, brightness = self:ToHSV()
			return hue, (100 - saturation) * brightness, 100 - brightness
		end,
		ToCMYK = function(self)
			local m = max(self.r, self.g, self.b)
			return (m - self.r) / m * 100, (m - self.g) / m * 100, (m - self.b) / m * 100, min(self.r, self.g, self.b) / 2.55
		end,
		Lerp = function(self, color, frac)
			frac = clamp(frac, 0, 1)
			return colorClass(lerp(frac, self.r, color.r), lerp(frac, self.g, color.g), lerp(frac, self.b, color.b), lerp(frac, self.a, color.a))
		end,
		LerpTo = function(self, color, frac)
			frac = clamp(frac, 0, 1)
			self.r = lerp(frac, self.r, color.r)
			self.g = lerp(frac, self.g, color.g)
			self.b = lerp(frac, self.b, color.b)
			self.a = lerp(frac, self.a, color.a)
			return self
		end,
		Invert = function(self)
			self.r, self.g, self.b = clamp(abs(255 - self.r), 0, 255), clamp(abs(255 - self.g), 0, 255), clamp(abs(255 - self.b), 0, 255)
			return self
		end
	}, {
		__index = findMetaTable("Color")
	})
	internal.__index = internal
	-- i really hate this
	environment.ColorAlpha = function(color, alpha)
		return colorClass(color.r, color.g, color.b, alpha)
	end
	environment.IsColor = function(any)
		return getmetatable(any) == internal
	end
	environment.iscolor = function(any)
		return getmetatable(any) == internal or (istable(any) and isnumber(any.r) and isnumber(any.g) and isnumber(any.b) and isnumber(any.a))
	end
	colorClass = newClass("Color", internal, {
		FromHex = function(hex)
			if isnumber(hex) then
				return colorClass(rshift(band(hex, 0xFF0000), 16), rshift(band(hex, 0xFF00), 8), band(hex, 0xFF))
			end
			if byte(hex, 1) == 0x23 then
				hex = sub(hex, 2)
			end
			local length = len(hex)
			if length == 3 then
				local r, g, b = byte(hex, 1, 3)
				return colorClass(tonumber(char(r, r), 16), tonumber(char(g, g), 16), tonumber(char(b, b), 16))
			end
			if length == 6 then
				return colorClass(tonumber(sub(hex, 1, 2), 16), tonumber(sub(hex, 3, 4), 16), tonumber(sub(hex, 5, 6), 16))
			end
			return colorClass()
		end,
		FromBinary = function(binary)
			local length = len(binary)
			if length == 1 then
				return colorClass(byte(binary, 1), 0, 0, 255)
			end
			if length == 2 then
				return colorClass(byte(binary, 1), byte(binary, 2), 0, 255)
			end
			if length == 3 then
				return colorClass(byte(binary, 1), byte(binary, 2), byte(binary, 3), 255)
			end
			return colorClass(byte(binary, 1), byte(binary, 2), byte(binary, 3), byte(binary, 4))
		end,
		FromVector = function(vector)
			return colorClass(vector[1] * 255, vector[2] * 255, vector[3] * 255, 255)
		end,
		FromHSL = function(hue, saturation, lightness)
			return colorClass(HSLToColor(hue, saturation, lightness))
		end,
		FromHSV = function(hue, saturation, brightness)
			return colorClass(HSVToColor(hue, saturation, brightness))
		end,
		FromHWB = function(hue, saturation, brightness)
			return colorClass(HSVToColor(hue, 1 - saturation / (1 - brightness), 1 - brightness))
		end,
		FromCMYK = function(cyan, magenta, yellow, black)
			cyan, magenta, yellow, black = cyan * 0.01, magenta * 0.01, yellow * 0.01, black * 0.01
			local mk = 1 - black
			return colorClass((1 - cyan) * mk * 255, (1 - magenta) * mk * 255, (1 - yellow) * mk * 255, 255)
		end,
		FromTable = function(tbl)
			return colorClass(tbl)
		end
	})
	environment.color_white = colorClass(255, 255, 255, 255)
	environment.Color = colorClass
end
-- Stack
do
	util.Stack = newClass("Stack", {
		__tostring = function(self)
			return format("Stack: %p [%d/%d]", self, self.pointer, self.size)
		end,
		new = function(self, size)
			self.size = (isnumber(size) and size > 0) and size or -1
			self.pointer = 0
		end,
		IsEmpty = function(self)
			return self.pointer == 0
		end,
		IsFull = function(self)
			return self.pointer == self.size
		end,
		Peek = function(self)
			return self[self.pointer]
		end,
		Push = function(self, value)
			local pointer = self.pointer
			if pointer ~= self.size then
				pointer = pointer + 1
				self[pointer] = value
				self.pointer = pointer
			end
			return pointer
		end,
		Pop = function(self)
			local pointer = self.pointer
			if pointer == 0 then
				return nil
			end
			self.pointer = pointer - 1
			local value = self[pointer]
			self[pointer] = nil
			return value
		end,
		Empty = function(self)
			for index = 1, self.pointer do
				self[index] = nil
			end
			self.pointer = 0
		end
	})
end
-- Queue
do
	local enqueue
	enqueue = function(self, value)
		if self:IsFull() then
			return nil
		end
		local rear = self.rear + 1
		self.rear = rear
		self[rear] = value
	end
	local dequeue
	dequeue = function(self)
		if self:IsEmpty() then
			return nil
		end
		local front = self.front
		local value = self[front]
		self[front] = nil
		front = front + 1
		self.front = front
		if (front * 2) >= self.rear then
			self:Optimize()
		end
		return value
	end
	util.Queue = newClass("Queue", {
		__tostring = function(self)
			return format("Queue: %p [%d/%d]", self, self.pointer, self.size)
		end,
		new = function(self, size)
			self.size = (isnumber(size) and size > 0) and size or -1
			self.front = 1
			self.rear = 0
		end,
		Length = function(self)
			return (self.rear - self.front) + 1
		end,
		IsEmpty = function(self)
			local rear = self.rear
			return rear == 0 or self.front > rear
		end,
		IsFull = function(self)
			return self:Length() == self.size
		end,
		Push = enqueue,
		Pop = dequeue,
		Enqueue = enqueue,
		Dequeue = dequeue,
		Get = function(self, index)
			return self[self.front + index]
		end,
		Set = function(self, index, value)
			self[self.front + index] = value
		end,
		Optimize = function(self)
			local pointer, buffer = 1, { }
			for index = self.front, self.rear do
				buffer[pointer] = self[index]
				self[index] = nil
				pointer = pointer + 1
			end
			for index = 1, pointer do
				self[index] = buffer[index]
			end
			self.front = 1
			self.rear = pointer - 1
		end,
		Peek = function(self)
			return self[self.front]
		end,
		Empty = function(self)
			for index = self.front, self.rear do
				self[index] = nil
			end
		end,
		Iterator = function(self)
			self:Optimize()
			local front, rear = self.front, self.rear
			front = front - 1
			return function()
				if rear == 0 or front >= rear then
					return nil
				end
				front = front + 1
				return front, self[front]
			end
		end
	})
end
do
	local angle, magnitude, direction, inrect, inpoly, incircle, intriangle, ontangent, dot = math.angle, math.magnitude, math.direction, math.inrect, math.inpoly, math.incircle, math.intriangle, math.ontangent, math.dot
	local metatable
	local new_point
	new_point = function(x, y)
		return setmetatable({
			x,
			y
		}, metatable)
	end
	metatable = {
		new = function(self, x, y)
			argument(x, 1, "number")
			argument(y, 2, "number")
			self[1] = x
			self[2] = y
		end,
		__tostring = function(self)
			return "Point(" .. self[1] .. "; " .. self[2] .. ")"
		end,
		__eq = function(a, b)
			return a[1] == b[1] and a[2] == b[2]
		end,
		__add = function(a, b)
			if isnumber(b) then
				return new_point(a[1] + b, a[2] + b)
			end
			return new_point(a[1] + b[1], a[2] + b[2])
		end,
		__sub = function(a, b)
			if isnumber(b) then
				return new_point(a[1] - b, a[2] - b)
			end
			return new_point(a[1] - b[1], a[2] - b[2])
		end,
		__mul = function(a, b)
			if isnumber(b) then
				return new_point(a[1] * b, a[2] * b)
			end
			return new_point(a[1] * b[1], a[2] * b[2])
		end,
		__div = function(a, b)
			if isnumber(b) then
				return new_point(a[1] / b, a[2] / b)
			end
			return new_point(a[1] / b[1], a[2] / b[2])
		end,
		__unm = function(a)
			return new_point(-a[1], -a[2])
		end,
		copy = function(self)
			return new_point(self[1], self[2])
		end,
		unpack = function(self)
			return self[1], self[2]
		end,
		angle = function(self, p)
			return angle(self[1], self[2], p[1], p[2])
		end,
		distance = function(self, p)
			return magnitude(self[1], self[2], p[1], p[2])
		end,
		normalize = function(self, p)
			self[1], self[2] = direction(self[1], self[2], p[1], p[2])
		end,
		direction = function(self, p)
			return direction(self[1], self[2], p[1], p[2])
		end,
		reflect = function(self, n)
			self[1], self[2] = self[1] - 2 * n[1] * dot(self[1], self[2], n[1], n[2]), self[2] - 2 * n[2] * dot(self[1], self[2], n[1], n[2])
		end,
		scale = function(self, s)
			self[1], self[2] = self[1] * s, self[2] * s
		end,
		dot = function(self, p)
			return self[1] * p[1] + self[2] * p[2]
		end,
		lerp = function(self, b, d)
			self[1], self[2] = lerp(d, self[1], b[1]), lerp(d, self[2], b[2])
		end,
		clamp = function(self, a, b)
			self[1], self[2] = clamp(self[1], a[1], b[1]), clamp(self[2], a[2], b[2])
		end,
		inrect = function(self, c1, c2)
			return inrect(self[1], self[2], c1[1], c1[2], c2[1], c2[2])
		end,
		incircle = function(self, cp, cr)
			return incircle(self[1], self[2], cp[1], cp[2], cr)
		end,
		intriangle = function(self, c1, c2, c3)
			return intriangle(self[1], self[2], c1[1], c1[2], c2[1], c2[2], c3[1], c3[2])
		end,
		ontangent = function(self, c1, c2)
			return ontangent(self[1], self[2], c1[1], c1[2], c2[1], c2[2])
		end,
		inpoly = function(self, poly)
			return inpoly(self[1], self[2], poly)
		end
	}
	math.Point = newClass("Point", metatable)
end
do
	local system, jit, require = _G.system, _G.jit, _G.require
	local Exists
	do
		local _obj_0 = _G.file
		Exists = _obj_0.Exists
	end
	-- ULib support ( I really don't like this )
	if Exists("ulib/shared/hook.lua", "LUA") then
		local ok, f = _G.pcall(_G.CompileFile, "ulib/shared/hook.lua")
		if ok and f then
			_G.pcall(f)
		end
	end
	environment.PRE_HOOK = _G.PRE_HOOK or -2
	environment.PRE_HOOK_RETURN = _G.PRE_HOOK_RETURN or -1
	environment.NORMAL_HOOK = _G.NORMAL_HOOK or 0
	environment.POST_HOOK_RETURN = _G.POST_HOOK_RETURN or 1
	environment.POST_HOOK = _G.POST_HOOK or 2
	local isEdge = jit.versionnum ~= 20004
	local is32 = jit.arch == "x86"
	local head = "lua/bin/gm" .. ((CLIENT and not MENU_DLL) and "cl" or "sv") .. "_"
	local tail = "_" .. ({
		"osx64",
		"osx",
		"linux64",
		"linux",
		"win64",
		"win32"
	})[(system.IsWindows() and 4 or 0) + (system.IsLinux() and 2 or 0) + (is32 and 1 or 0) + 1] .. ".dll"
	local isBinaryModuleInstalled
	isBinaryModuleInstalled = function(name)
		argument(name, 1, "string")
		if name == "" then
			return false, ""
		end
		local filePath = head .. name .. tail
		if Exists(filePath, "MOD") then
			return true, filePath
		end
		if isEdge and is32 and tail == "_linux.dll" then
			filePath = head .. name .. "_linux32.dll"
			if Exists(filePath, "MOD") then
				return true, filePath
			end
		end
		return false, filePath
	end
	util.IsBinaryModuleInstalled = isBinaryModuleInstalled
	environment.load_binary = function(name)
		local installed, filePath = isBinaryModuleInstalled(name)
		if installed then
			require(name)
			return _G[name]
		end
		error("Binary module '" .. filePath .. "' was not found.", 2)
		return nil
	end
	do
		local ceil, log, ln2 = math.ceil, math.log, math.ln2
		util.BitToBytes = function(number)
			return ceil(number / 8)
		end
		util.BytesToBit = function(number)
			return ceil(number) * 8
		end
		util.BitCount = function(value)
			if isnumber(value) then
				return ceil(log(value + 1) / ln2)
			end
			if isstring(value) then
				return len(value) * 8
			end
			if isbool(value) then
				return 1
			end
			return -1
		end
		util.ByteCount = function(value)
			if isnumber(value) then
				return ceil(ceil(log(value + 1) / ln2) / 8)
			end
			if isstring(value) then
				return len(value)
			end
			if isbool(value) then
				return 1
			end
			return -1
		end
	end
end
do
	local os = environment.os
	do
		local time = os.time
		os.dos2unix = function(t, d)
			local data = {
				year = 1980,
				month = 1,
				day = 1,
				hour = 0,
				min = 0,
				sec = 0
			}
			if t then
				data.hour = rshift(band(t, 0xF800), 11)
				data.min = rshift(band(t, 0x07E0), 5)
				data.sec = band(t, 0x001F) * 2
			end
			if d then
				data.year = data.year + rshift(band(d, 0xFE00), 9)
				data.month = rshift(band(d, 0x01E0), 5)
				data.day = band(d, 0x001F)
			end
			return time(data)
		end
	end
	do
		local lshift, bor = bit.lshift, bit.bor
		local fdiv = math.fdiv
		local date = os.date
		os.unix2dos = function(u)
			local data = date("*t", u)
			return bor(lshift(data.hour, 11), lshift(data.min, 5), fdiv(data.sec, 2)), bor(lshift(data.year - 1980, 9), lshift(data.month, 5), data.day)
		end
		table.Reverse = function(tbl, noCopy)
			local length = #tbl
			if noCopy then
				length = length + 1
				for index = 1, fdiv(length, 2), 1 do
					tbl[index], tbl[length - index] = tbl[length - index], tbl[index]
				end
				return tbl
			end
			local result = { }
			for index = length, 1, -1 do
				result[length - index + 1] = tbl[index]
			end
			return result
		end
	end
end
-- Garry's Mod hooks
do
	local hook = _G.hook
	local lib = setmetatable(rawget(environment, "hook") or { }, {
		__index = hook
	})
	environment.hook = lib
	local Add, Remove, GetTable = hook.Add, hook.Remove, hook.GetTable
	local IsEmpty = table.IsEmpty
	if CLIENT_SERVER then
		local inext = environment.inext
		local entities, players
		do
			local GetAll
			do
				local _obj_0 = _G.player
				GetAll = _obj_0.GetAll
			end
			local getAll
			getAll = function()
				if players == nil then
					players = GetAll()
				end
				return players
			end
			environment.player.GetAll = getAll
			local iterator
			iterator = function()
				return inext, getAll(), 0
			end
			environment.player.Iterator = iterator
			if SERVER then
				local isDedicatedServer = _G.game.IsDedicated()
				local NULL = _G.NULL
				environment.game.IsDedicated = function()
					return isDedicatedServer
				end
				if isDedicatedServer then
					environment.LocalPlayer = function()
						return NULL
					end
				else
					local IsListenServerHost
					do
						local _obj_0 = findMetaTable("Player")
						IsListenServerHost = _obj_0.IsListenServerHost
					end
					local player
					environment.LocalPlayer = function()
						if player == nil then
							for _, ply in iterator() do
								if IsListenServerHost(ply) then
									player = ply
									return ply
								end
							end
							return NULL
						end
						return player
					end
				end
			end
		end
		do
			local GetAll
			do
				local _obj_0 = _G.ents
				GetAll = _obj_0.GetAll
			end
			local getAll
			getAll = function()
				if entities == nil then
					entities = GetAll()
				end
				return entities
			end
			environment.ents.GetAll = getAll
			environment.ents.Iterator = function()
				return inext, getAll(), 0
			end
		end
		local IsPlayer = environment.IsPlayer
		local invalidateCache
		invalidateCache = function(entity)
			entities = nil
			if IsPlayer(entity) then
				players = nil
			end
			return nil
		end
		Add("OnEntityCreated", gpm.PREFIX .. "::Iterators", invalidateCache, environment.PRE_HOOK)
		Add("EntityRemoved", gpm.PREFIX .. "::Iterators", invalidateCache, environment.PRE_HOOK)
	end
	-- GM:PlayerInitialized( Player ply )
	if CLIENT_SERVER then
		local Run = hook.Run
		if SERVER then
			local IsForced
			do
				local _obj_0 = findMetaTable("CUserCmd")
				IsForced = _obj_0.IsForced
			end
			Add("SetupMove", gpm.PREFIX .. "::PlayerInitialized", function(ply, _, cmd)
				if ply.__initialized or not (IsForced(cmd) or ply:IsBot()) then
					return nil
				end
				ply.__initialized = true
				Run("PlayerInitialized", ply)
				return nil
			end, environment.PRE_HOOK)
		end
		if CLIENT then
			Add("RenderScene", gpm.PREFIX .. "::PlayerInitialized", function()
				Remove("RenderScene", gpm.PREFIX .. "::PlayerInitialized")
				local ply = environment.LocalPlayer()
				if not ply:IsValid() or ply.__initialized then
					return nil
				end
				ply.__initialized = true
				Run("PlayerInitialized", ply)
				return nil
			end, environment.PRE_HOOK)
		end
	end
	local hooksMeta = {
		__index = function(tbl, key)
			local new = { }
			rawset(tbl, key, new)
			return new
		end
	}
	lib.Add = function(eventName, identifier, func, priority)
		argument(eventName, 1, "string")
		argument(identifier, 2, "string")
		argument(func, 3, "function")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local hooks = pkg.__hooks
				if not hooks then
					hooks = { }
					setmetatable(hooks, hooksMeta)
					pkg.__hooks = hooks
				end
				hooks[eventName][identifier] = func
				return Add(eventName, pkg.prefix .. identifier, func, priority)
			end
		end
		return Add(eventName, identifier, func, priority)
	end
	lib.Remove = function(eventName, identifier)
		argument(eventName, 1, "string")
		argument(identifier, 2, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local hooks = pkg.__hooks
				if not hooks then
					hooks = { }
					setmetatable(hooks, hooksMeta)
					pkg.__hooks = hooks
				end
				local event = hooks[eventName]
				event[identifier] = nil
				if IsEmpty(event) then
					hooks[eventName] = nil
				end
				return Remove(eventName, pkg.prefix .. identifier)
			end
		end
		return Remove(eventName, identifier)
	end
	lib.GetTable = function()
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local hooks = pkg.__hooks
				if not hooks then
					hooks = { }
					setmetatable(hooks, hooksMeta)
					pkg.__hooks = hooks
				end
				return hooks
			end
		end
		return GetTable()
	end
end
-- Garry's Mod timers
do
	local timer = _G.timer
	local Adjust, Create, Exists, Pause, Remove, RepsLeft, Start, Stop, Simple, TimeLeft, Toggle, UnPause = timer.Adjust, timer.Create, timer.Exists, timer.Pause, timer.Remove, timer.RepsLeft, timer.Start, timer.Stop, timer.Simple, timer.TimeLeft, timer.Toggle, timer.UnPause
	local lib = setmetatable(rawget(environment, "timer") or { }, {
		__index = timer
	})
	environment.timer = lib
	local unpack = table.unpack
	lib.Adjust = function(identifier, delay, repetitions, func)
		argument(identifier, 1, "string")
		argument(delay, 2, "number")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local timers = pkg.__timers
				if not timers then
					timers = { }
					pkg.__timers = timers
				end
				local data = timers[identifier]
				if not data then
					return nil
				end
				delay = delay or data.delay
				data.delay = delay
				repetitions = repetitions or data.repetitions
				data.repetitions = repetitions
				func = func or data.func
				data.func = func
				return Adjust(pkg.prefix .. identifier, delay, repetitions, func)
			end
		end
		return Adjust(identifier, delay, repetitions, func)
	end
	lib.Create = function(identifier, delay, repetitions, func)
		argument(identifier, 1, "string")
		argument(delay, 2, "number")
		argument(repetitions, 3, "number")
		argument(func, 4, "function")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local timers = pkg.__timers
				if not timers then
					timers = { }
					pkg.__timers = timers
				end
				local data = timers[identifier]
				if data then
					data.delay = delay
					data.repetitions = repetitions
					data.func = func
				else
					timers[identifier] = {
						delay = delay,
						repetitions = repetitions,
						func = func
					}
				end
				return Create(pkg.prefix .. identifier, delay, repetitions, func)
			end
		end
		return Create(identifier, delay, repetitions, func)
	end
	lib.Exists = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return Exists(pkg.prefix .. identifier)
			end
		end
		return Exists(identifier)
	end
	lib.Pause = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return Pause(pkg.prefix .. identifier)
			end
		end
		return Pause(identifier)
	end
	lib.Remove = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local timers = pkg.__timers
				if not timers then
					timers = { }
					pkg.__timers = timers
				end
				timers[identifier] = nil
				return Remove(pkg.prefix .. identifier)
			end
		end
		return Remove(identifier)
	end
	lib.RepsLeft = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return RepsLeft(pkg.prefix .. identifier)
			end
		end
		return RepsLeft(identifier)
	end
	lib.Start = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return Start(pkg.prefix .. identifier)
			end
		end
		return Start(identifier)
	end
	lib.Stop = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return Stop(pkg.prefix .. identifier)
			end
		end
		return Stop(identifier)
	end
	lib.TimeLeft = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return TimeLeft(pkg.prefix .. identifier)
			end
		end
		return TimeLeft(identifier)
	end
	lib.Toggle = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return Toggle(pkg.prefix .. identifier)
			end
		end
		return Toggle(identifier)
	end
	lib.UnPause = function(identifier)
		argument(identifier, 1, "string")
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				return UnPause(pkg.prefix .. identifier)
			end
		end
		return UnPause(identifier)
	end
	lib.GetTable = function()
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local timers = pkg.__timers
				if not timers then
					timers = { }
					pkg.__timers = timers
				end
				return timers
			end
		end
		return nil
	end
	lib.Tick = function(func, ...)
		local args = {
			...
		}
		Simple(0, function()
			func(unpack(args))
			return nil
		end)
		return nil
	end
end
do
	local getConVar
	do
		local GetConVar_Internal = _G.GetConVar_Internal
		local cache = { }
		getConVar = function(name)
			local convar = cache[name]
			if convar then
				return convar
			end
			convar = GetConVar_Internal(name)
			if convar == nil then
				return nil
			end
			cache[name] = convar
			return convar
		end
		environment.GetConVar = getConVar
	end
	local developer = getConVar("developer")
	if not MENU_DLL and environment.game.IsDedicated() then
		local isInDebug = developer and developer:GetInt() > 1 or false
		_G.cvars.AddChangeCallback("developer", function(_, __, str)
			isInDebug = (tonumber(str, 10) or 0) > 1
		end, gpm.PREFIX .. "::Debug")
		gpm.IsInDebug = function()
			return isInDebug
		end
	else
		local GetInt
		do
			local _obj_0 = getmetatable(developer)
			GetInt = _obj_0.GetInt
		end
		gpm.IsInDebug = function()
			return GetInt(developer) > 0
		end
	end
end

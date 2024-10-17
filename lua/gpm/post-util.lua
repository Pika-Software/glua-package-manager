local _G = _G
local gpm, SERVER = _G.gpm, _G.SERVER
local environment, Logger = gpm.environment, gpm.Logger
local istable, pcall, require, tonumber, tostring = _G.istable, _G.pcall, _G.require, _G.tonumber, _G.tostring
local bit, math, string, table, os, util, argument, isstring, isnumber, isfunction, throw, type = environment.bit, environment.math, environment.string, environment.table, environment.os, environment.util, environment.argument, environment.isstring, environment.isnumber, environment.isfunction, environment.throw, environment.type
local char, byte, sub, gsub, len, find, format, match = string.char, string.byte, string.sub, string.gsub, string.len, string.find, string.format, string.match
local CRC, IsBinaryModuleInstalled = util.CRC, util.IsBinaryModuleInstalled
local concat, unpack = table.concat, table.unpack
local newClass = environment.class
local clamp = math.clamp
local time = os.time
do
	local CodeCompileError = environment.CodeCompileError
	local installed, filePath = IsBinaryModuleInstalled("moonloader")
	if installed then
		local ok, msg = pcall(require, "moonloader")
		if ok and istable(_G.moonloader) then
			Logger:Info("gm_moonloader v%s loaded.", _G.moonloader._VERSION)
			installed = true
		else
			Logger:Error("gm_moonloader startup error: %s", msg or "unknown error")
			installed = false
		end
	end
	local yueFail
	yueFail = function()
		return throw(CodeCompileError("Attempt to compile Yuescript failed, install gm_moonloader and try again, https://github.com/Pika-Software/gm_moonloader."))
	end
	if installed then
		local moonloader = _G.moonloader
		environment.moon = moonloader
		-- Yuescript
		local yue = moonloader.yue
		if istable(yue) then
			environment.yue = yue
		else
			environment.yue = {
				ToLua = yueFail
			}
			Logger:Warn("Yuescript support is missing, yuescript code compilation is unavailable.")
		end
	else
		local moonFail
		moonFail = function()
			return throw(CodeCompileError("Attempt to compile MoonScript failed, install gm_moonloader and try again, https://github.com/Pika-Software/gm_moonloader."))
		end
		environment.moon = {
			PreCacheFile = moonFail,
			PreCacheDir = moonFail,
			ToLua = moonFail
		}
		environment.yue = {
			ToLua = yueFail
		}
		Logger:Warn("Binary module '" .. filePath .. "' is missing, support for moon and yue scripts is unavailable.")
	end
end
-- https://github.com/WilliamVenner/gmsv_workshop
if SERVER and not (istable(steamworks) and isfunction(steamworks.DownloadUGC)) then
	local installed, filePath = IsBinaryModuleInstalled("workshop")
	if installed then
		if not pcall(require, "workshop") then
			Logger:Error("Binary module '" .. filePath .. "' was corrupted!")
		end
	else
		Logger:Warn("Binary module '" .. filePath .. "' is missing, Steam workshop downloads is unavailable.")
	end
end
do
	local byteCodeSupported
	if SERVER then
		-- https://github.com/willox/gmbc
		local filePath
		byteCodeSupported, filePath = IsBinaryModuleInstalled("gmbc")
		if byteCodeSupported then
			byteCodeSupported = pcall(require, "gmbc")
		else
			Logger:Warn("Binary module '" .. filePath .. "' is missing, bytecode compilation is unavailable.")
		end
	else
		byteCodeSupported = false
	end
	local CompileString, gmbc_load_bytecode, setfenv = _G.CompileString, _G.gmbc_load_bytecode, _G.setfenv
	local yue, moon = environment.yue, environment.moon
	local IsBytecode = string.IsBytecode
	environment.loadstring = function(code, identifier, handleError, ignoreBytecode)
		if handleError == nil then
			handleError = true
		end
		if not ignoreBytecode and IsBytecode(code) then
			if byteCodeSupported then
				return gmbc_load_bytecode(code)
			end
			local msg = "Bytecode compilation is not supported. Please install gmbc (https://github.com/willox/gmbc)"
			if handleError then
				throw(msg, 2)
				return nil
			end
			return msg
		end
		return CompileString(code, identifier, handleError)
	end
	local load
	load = function(chunk, chunkName, mode, env, config, handleError)
		if mode == nil then
			mode = "bt"
		end
		if env == nil then
			env = getfenv(2)
		end
		if handleError == nil then
			handleError = true
		end
		argument(chunkName, 2, "string")
		do
			local _exp_0 = type(chunk)
			if "string" == _exp_0 then
				local modes = { }
				local _list_0 = {
					byte(mode, 1, len(mode))
				}
				for _index_0 = 1, #_list_0 do
					local byte0 = _list_0[_index_0]
					modes[byte0] = true
				end
				local func
				if modes[0x62] and IsBytecode(chunk) then
					if byteCodeSupported then
						func = gmbc_load_bytecode(chunk)
					end
					local msg = "Bytecode compilation is not supported."
					if handleError then
						throw(msg, 2)
						return nil
					end
					return msg
				end
				if modes[0x79] then
					if config then
						argument(config, 5, "table")
						chunk = yue.ToLua(chunk, config)
					else
						chunk = yue.ToLua(chunk)
					end
				elseif modes[0x6D] then
					chunk = moon.ToLua(chunk)
				end
				if modes[0x74] then
					func = CompileString(chunk, chunkName, handleError)
				end
				if func then
					if isfunction(func) and env then
						setfenv(func, env)
					end
					return func
				end
				local msg = "wrong load mode"
				if handleError then
					throw(msg, 2)
					return nil
				end
				return msg
			elseif "function" == _exp_0 then
				local result, length = { }, 0
				local str = chunk()
				while str do
					length = length + 1
					result[length] = str
					str = chunk()
				end
				if length == 0 then
					return function() end
				end
				return load(concat(result, "", 1, length), chunkName, mode, env, config, handleError)
			end
		end
		throw("Invalid argument #1 to 'load' (string/function expected)", 2)
		return nil
	end
	environment.load = load
end
do
	local BInt, struct = environment.BInt, environment.struct
	local FromBytes, ToBytes, ToNumber, CastSigned = BInt.FromBytes, BInt.ToBytes, BInt.ToNumber, BInt.CastSigned
	local io = struct.io
	local setEndianness
	do
		local Little, Set
		do
			local _obj_0 = io.endianness
			Little, Set = _obj_0.Little, _obj_0.Set
		end
		local Read
		do
			local _obj_0 = io.i
			Read = _obj_0.Read
		end
		util.LZMA_PROPS_SIZE = 5
		util.CompressedSize = function(binary)
			if binary == "" then
				return 0
			end
			Little()
			return Read(nil, sub(binary, 6, 14), 8)
		end
		setEndianness = function(isBigEndian)
			if isBigEndian then
				Set("big")
				return true
			end
			Set("little")
			return false
		end
	end
	local readUInt, writeUInt
	do
		local uint = io.I
		readUInt, writeUInt = uint.Read, uint.Write
	end
	local SteamID
	do
		local IsSteamID, IsSteamID64 = string.IsSteamID, string.IsSteamID64
		local fdiv = math.fdiv
		local universes = {
			[0] = {
				"450",
				3603922337792,
				3
			},
			[1] = {
				"765",
				61197960265728,
				3
			},
			[2] = {
				"1486",
				18791998193664,
				4
			},
			[3] = {
				"2206",
				76386036121600,
				4
			},
			[4] = {
				"2927",
				33980074049536,
				4
			},
			[5] = {
				"3647",
				91574111977472,
				4
			}
		}
		util.SteamIDTo64 = function(str, fullUniverse)
			local x, y, z = match(str, "^STEAM_([0-5]):([01]):(%d+)$")
			local universe = tonumber(x, 10)
			if not fullUniverse and universe == 0 then
				universe = 1
			end
			local data = universes[universe]
			return data[1] .. ((tonumber(z, 10) * 2) + data[2]) + (y == "1" and 1 or 0)
		end
		util.SteamIDFrom64 = function(str, skipUniverse)
			local account_id, universe
			if skipUniverse == false then
				for i = 0, 5 do
					local data = universes[i]
					if data[1] == sub(str, 1, data[3]) then
						account_id = tonumber(sub(str, data[3] + 1), 10) - data[2]
						universe = i
						break
					end
				end
				if not universe then
					universe = 1
				end
			else
				universe = 0
				account_id = tonumber(sub(str, 4), 10) - 61197960265728
			end
			return "STEAM_" .. (universe or 0) .. ":" .. (account_id % 2 == 0 and "0" or "1") .. ":" .. fdiv(account_id, 2)
		end
		local metatable = {
			new = function(self, str, fullUniverse)
				argument(str, 1, "string")
				if IsSteamID64(str) then
					local account_id, universe
					if fullUniverse then
						for i = 0, 5 do
							local data = universes[i]
							if data[1] == sub(str, 1, data[3]) then
								account_id = tonumber(sub(str, data[3] + 1), 10) - data[2]
								universe = i
								break
							end
						end
						if not universe then
							universe = 1
						end
					else
						universe = 1
						account_id = tonumber(sub(str, 4), 10) - 61197960265728
					end
					self.universe, self.id, self.account_number, self.account_id = universe, account_id % 2 ~= 0, fdiv(account_id, 2), account_id
					return nil
				end
				if IsSteamID(str) then
					local x, y, z = match(str, "^STEAM_([0-5]):([01]):(%d+)$")
					local universe, id, account_number = tonumber(x, 10), y == "1", tonumber(z, 10)
					if not fullUniverse and universe == 0 then
						universe = 1
					end
					self.universe, self.id, self.account_number, self.account_id = universe, id, account_number, (account_number * 2) + (id and 1 or 0)
					return nil
				end
				throw("Invalid SteamID", 3)
				return nil
			end,
			ToXYZ = function(self)
				return self.universe, self.id, self.account_number
			end,
			ToIntegers = function(self)
				return self.universe, self.id and 1 or 0, self.account_number
			end,
			ToSteamID = function(self)
				return "STEAM_" .. self.universe .. ":" .. (self.id and "1" or "0") .. ":" .. self.account_number
			end,
			ToSteamID64 = function(self)
				local data = universes[self.universe]
				return data[1] .. (self.account_id + data[2])
			end,
			GetProfileURL = function(self)
				return "https://steamcommunity.com/profiles/" .. self:ToSteamID64()
			end,
			ToAccountID = function(self)
				return self.account_id
			end,
			ToHex = function(self)
				return format("0x%x", self.account_id)
			end,
			ToSteamID3 = function(self)
				return "[U:" .. self.universe .. ":" .. self.account_id .. "]"
			end,
			ToBinary = function(self, isBigEndian, withUniverse)
				setEndianness(isBigEndian)
				if withUniverse then
					return char(self.universe) .. writeUInt(nil, self.account_id, 4)
				end
				return writeUInt(nil, self.account_id, 4)
			end,
			GetUniverse = function(self)
				return self.universe
			end,
			SetUniverse = function(self, universe)
				argument(universe, 1, "number")
				if universe < 0 or universe > 5 then
					throw("Invalid SteamID universe", 2)
				end
				self.universe = universe
				return self
			end
		}
		metatable.__tostring = metatable.ToSteamID
		metatable.__eq = function(self, other)
			return getmetatable(other) == metatable and self.universe == other.universe and self.id == other.id and self.account_number == other.account_number
		end
		SteamID = newClass("SteamID", metatable, {
			IsValid = function(steamid)
				argument(steamid, 1, "string")
				return IsSteamID(steamid)
			end,
			FromSteamID = function(steamid)
				argument(steamid, 1, "string")
				if not IsSteamID(steamid) then
					throw("Invalid SteamID", 2)
				end
				local x, y, z = match(steamid, "^STEAM_([0-5]):([01]):(%d+)$")
				local id, account_number = y == "1", tonumber(z, 10)
				return setmetatable({
					universe = tonumber(x, 10),
					id = id,
					account_number = account_number,
					account_id = (account_number * 2) + (id and 1 or 0)
				}, metatable)
			end,
			FromSteamID64 = function(steamid64, fullUniverse)
				steamid64 = tostring(steamid64)
				local account_id, universe
				if fullUniverse then
					for i = 0, 5 do
						local data = universes[i]
						if data[1] == sub(steamid64, 1, data[3]) then
							account_id = tonumber(sub(steamid64, data[3] + 1), 10) - data[2]
							universe = i
							break
						end
					end
					if not universe then
						universe = 1
					end
				else
					universe = 1
					account_id = tonumber(sub(steamid64, 4), 10) - 61197960265728
				end
				return setmetatable({
					universe = universe,
					id = account_id % 2 ~= 0,
					account_number = fdiv(account_id, 2),
					account_id = account_id
				}, metatable)
			end,
			FromSteamID3 = function(sid3)
				local x, z = match(sid3, "^%[?U:(%d):(%d+)%]?$")
				local account_number = tonumber(z, 10) or -1
				if account_number < 0 then
					throw("Invalid SteamID3", 2)
				end
				local id
				account_number, id = fdiv(account_number, 2), z % 2 ~= 0
				return setmetatable({
					universe = tonumber(x, 10),
					id = id,
					account_number = account_number,
					account_id = (account_number * 2) + (id and 1 or 0)
				}, metatable)
			end,
			FromBinary = function(binary, isBigEndian, withUniverse)
				setEndianness(isBigEndian)
				local account_id = readUInt(nil, withUniverse and sub(binary, 2) or binary, 4) or -1
				if account_id < 0 then
					throw("Invalid binary SteamID", 2)
				end
				return setmetatable({
					universe = withUniverse and clamp(byte(binary, 1), 0, 5) or 1,
					id = account_id % 2 ~= 0,
					account_number = fdiv(account_id, 2),
					account_id = account_id
				}, metatable)
			end,
			FromHex = function(hex)
				if not isnumber(hex) then
					hex = tonumber(hex, 16)
				end
				argument(hex, 1, "number")
				if hex < 0 then
					throw("Invalid hex", 2)
				end
				return setmetatable({
					universe = 1,
					id = hex % 2 ~= 0,
					account_number = fdiv(hex, 2),
					account_id = hex
				}, metatable)
			end,
			FromAccountID = function(account_id)
				argument(account_id, 1, "number")
				return setmetatable({
					universe = 1,
					id = account_id % 2 ~= 0,
					account_number = fdiv(account_id, 2),
					account_id = account_id
				}, metatable)
			end
		})
		environment.SteamID = SteamID
	end
	-- lua 5.3 string features
	do
		local Read, Write = struct.Read, struct.Write
		string.pack = function(fmt, ...)
			return Write(fmt, {
				...
			})
		end
		string.unpack = function(fmt, binary, offset)
			if offset then
				return unpack(Read(fmt, sub(binary, offset, len(binary))))
			end
			return unpack(Read(fmt, binary))
		end
		string.packsize = struct.SizeOf
	end
	-- Byte Stream
	local deflate, Color = environment.deflate, environment.Color
	local unix2dos, dos2unix = os.unix2dos, os.dos2unix
	local Date = util.Date
	local readInt, writeInt
	do
		local int = io.i
		readInt, writeInt = int.Read, int.Write
	end
	local readFloat, writeFloat
	do
		local float = io.f
		readFloat, writeFloat = float.Read, float.Write
	end
	local readDouble, writeDouble
	do
		local double = io.d
		readDouble, writeDouble = double.Read, double.Write
	end
	local noCompression
	noCompression = function(content)
		return content
	end
	local compressionMethods = {
		[0] = {
			[1] = noCompression,
			[2] = noCompression
		},
		[8] = {
			[1] = deflate.CompressDeflate,
			[2] = deflate.DecompressDeflate
		}
	}
	local seek
	seek = function(self, position)
		self:Flush()
		if position then
			argument(position, 2, "number")
			position = clamp(position, 0, self.size)
		else
			position = 0
		end
		self.pointer = position
		return position
	end
	util.ByteStream = newClass("ByteStream", {
		__tostring = function(self)
			return format("ByteStream: %p [%d/%d]", self, self.pointer, self.size)
		end,
		IsValid = function(self)
			return self.data ~= nil
		end,
		EndOfFile = function(self)
			return self.pointer >= self.size
		end,
		Size = function(self)
			return self.size
		end,
		Tell = function(self)
			return self.pointer
		end,
		Close = function(self)
			self:Flush()
			self.pointer = 0
		end,
		Seek = seek,
		SeekTo = seek,
		SeekToBegin = function(self)
			return self:Seek(0)
		end,
		SeekToEnd = function(self)
			return self:Seek(self.size - self.pointer)
		end,
		SkipEmpty = function(self)
			while not self:EndOfFile() do
				if self:ReadByte() ~= 0 then
					self:Skip(-1)
					break
				end
			end
		end,
		Skip = function(self, length)
			if length then
				argument(length, 2, "number")
			else
				length = 1
			end
			return self:Seek(self.pointer + length)
		end,
		Read = function(self, length)
			local pointer, size = self.pointer, self.size
			if length == "*a" or length == nil then
				length = size
			end
			argument(length, 2, "number")
			if length > 0 then
				if pointer >= size then
					return nil, "eof"
				end
				return sub(self.data, pointer + 1, self:Skip(length))
			end
			if length < 0 then
				if pointer <= 0 then
					return nil, "sof"
				end
				return sub(self.data, self:Skip(length), pointer + 1)
			end
			return nil, "no data"
		end,
		ReadAll = function(self)
			self:SeekToBegin()
			return self:Read(self.size)
		end,
		ReadString = function(self)
			local pointer, size = self.pointer, self.size
			if pointer >= size then
				return nil, "eof"
			end
			local length, data = 0, self.data
			for index = pointer, size do
				if byte(data, index + 1) == 0 then
					break
				end
				length = length + 1
			end
			if length == 0 then
				self:Skip(1)
				return nil
			end
			local str = self:Read(length)
			self:Skip(1)
			return str
		end,
		WriteString = function(self, str)
			argument(str, 1, "string")
			return self:Write(str .. "\0")
		end,
		ReadLine = function(self)
			local pointer, size = self.pointer, self.size
			if pointer >= size then
				return nil, "eof"
			end
			local length, data = 0, self.data
			for index = pointer, size do
				if byte(data, index + 1) == 0xA then
					break
				end
				length = length + 1
			end
			if length == 0 then
				self:Skip(1)
				return nil
			end
			return self:Read(length)
		end,
		WriteLine = function(self, str)
			argument(str, 1, "string")
			return self:Write(str .. "\n")
		end,
		ReadByte = function(self)
			if self:EndOfFile() then
				return nil, "eof"
			end
			return byte(self.data, self:Skip(1))
		end,
		WriteByte = function(self, number)
			return self:Write(char(number))
		end,
		ReadSignedByte = function(self)
			return self:ReadByte() - 0x80
		end,
		WriteSignedByte = function(self, number)
			return self:WriteByte(number + 0x80)
		end,
		ReadBool = function(self)
			do
				local _exp_0 = self:ReadByte()
				if 0 == _exp_0 then
					return false
				elseif 1 == _exp_0 then
					return true
				end
			end
			return nil, "eof"
		end,
		WriteBool = function(self, bool)
			return self:WriteByte(bool and 1 or 0)
		end,
		ReadUInt = function(self, bytes, isBigEndian)
			argument(bytes, 2, "number")
			setEndianness(isBigEndian)
			return readUInt(nil, self:Read(bytes), bytes)
		end,
		WriteUInt = function(self, number, bytes, isBigEndian)
			argument(number, 1, "number")
			argument(bytes, 2, "number")
			setEndianness(isBigEndian)
			return self:Write(writeUInt(nil, number, bytes))
		end,
		ReadUShort = function(self, isBigEndian)
			return self:ReadUInt(2, isBigEndian)
		end,
		WriteUShort = function(self, number, isBigEndian)
			return self:WriteUInt(number, 2, isBigEndian)
		end,
		ReadULong = function(self, isBigEndian)
			return self:ReadUInt(4, isBigEndian)
		end,
		WriteULong = function(self, number, isBigEndian)
			return self:WriteUInt(number, 4, isBigEndian)
		end,
		ReadUInt64 = function(self, isBigEndian)
			local binary = self:Read(8)
			if not binary then
				return nil, "eof"
			end
			if setEndianness(isBigEndian) then
				if byte(binary, 1) == 0 and byte(binary, 2) == 0 then
					return readUInt(nil, sub(binary, 3), 6)
				end
				return FromBytes(binary, false)
			end
			if byte(binary, 7) == 0 and byte(binary, 8) == 0 then
				return readUInt(nil, binary, 6)
			end
			return FromBytes(binary, true)
		end,
		WriteUInt64 = function(self, number, isBigEndian)
			local isBint
			if isnumber(number) then
				isBint = false
			else
				number = BInt(number)
				isBint = true
			end
			if isBint or number > 0xFFFFFFFFFFFF then
				if setEndianness(isBigEndian) then
					return self:Write(ToBytes(number, 8, false))
				end
				return self:Write(ToBytes(number, 8, true))
			end
			if setEndianness(isBigEndian) then
				self:Write("\0\0")
				if isBint then
					return self:Write(writeUInt(nil, ToNumber(number), 6))
				end
				return self:Write(writeUInt(nil, number, 6))
			end
			if isBint then
				self:Write(writeUInt(nil, ToNumber(number), 6))
			else
				self:Write(writeUInt(nil, number, 6))
			end
			return self:Write("\0\0")
		end,
		ReadInt = function(self, bytes, isBigEndian)
			argument(bytes, 2, "number")
			setEndianness(isBigEndian)
			return readInt(nil, self:Read(bytes), bytes)
		end,
		WriteInt = function(self, number, bytes, isBigEndian)
			argument(number, 1, "number")
			argument(bytes, 2, "number")
			setEndianness(isBigEndian)
			return self:Write(writeInt(nil, number, bytes))
		end,
		ReadShort = function(self, isBigEndian)
			return self:ReadInt(2, isBigEndian)
		end,
		WriteShort = function(self, number, isBigEndian)
			return self:WriteInt(number, 2, isBigEndian)
		end,
		ReadLong = function(self, isBigEndian)
			return self:ReadInt(4, isBigEndian)
		end,
		WriteLong = function(self, number, isBigEndian)
			return self:WriteInt(number, 4, isBigEndian)
		end,
		ReadInt64 = function(self, isBigEndian)
			local binary = self:Read(8)
			if not binary then
				return nil, "eof"
			end
			if setEndianness(isBigEndian) then
				if byte(binary, 1) == 0 and byte(binary, 2) == 0 then
					return readInt(nil, sub(binary, 3), 6)
				end
				return CastSigned(FromBytes(binary, false), 8)
			end
			if byte(binary, 7) == 0 and byte(binary, 8) == 0 then
				return readInt(nil, binary, 6)
			end
			return CastSigned(FromBytes(binary, true), 8)
		end,
		WriteInt64 = function(self, number, isBigEndian)
			local isBint
			if isnumber(number) then
				isBint = false
			else
				number = BInt(number)
				isBint = true
			end
			if isBint or number > 0xFFFFFFFFFFFF then
				if setEndianness(isBigEndian) then
					return self:Write(ToBytes(number, 8, false))
				end
				return self:Write(ToBytes(number, 8, true))
			end
			if setEndianness(isBigEndian) then
				self:Write("\0\0")
				if isBint then
					return self:Write(writeInt(nil, ToNumber(number), 6))
				end
				return self:Write(writeInt(nil, number, 6))
			end
			if isBint then
				self:Write(writeInt(nil, ToNumber(number), 6))
			else
				self:Write(writeInt(nil, number, 6))
			end
			return self:Write("\0\0")
		end,
		ReadFloat = function(self, isBigEndian)
			setEndianness(isBigEndian)
			return readFloat(nil, self:Read(4), 4)
		end,
		WriteFloat = function(self, number, isBigEndian)
			argument(number, 2, "number")
			setEndianness(isBigEndian)
			return self:Write(writeFloat(nil, number, 4))
		end,
		ReadDouble = function(self, isBigEndian)
			setEndianness(isBigEndian)
			return readDouble(nil, self:Read(8), 8)
		end,
		WriteDouble = function(self, number, isBigEndian)
			argument(number, 2, "number")
			setEndianness(isBigEndian)
			return self:Write(writeDouble(nil, number, 8))
		end,
		ReadTime = function(self)
			return dos2unix(self:ReadUShort(), self:ReadUShort())
		end,
		WriteTime = function(self, u)
			local t, d = unix2dos(u)
			self:WriteUShort(t)
			return self:WriteUShort(d)
		end,
		ReadZipFile = function(self, doCRC)
			if self:Read(4) ~= "PK\x03\x04" then
				return
			end
			local data = { }
			self:Skip(4)
			local compressionMethod = self:ReadUShort()
			data.compression = compressionMethod
			data.time = self:ReadTime()
			local crc = self:ReadULong()
			data.crc = crc
			local compressedSize = self:ReadULong()
			data.size = self:ReadULong()
			local pathLength = self:ReadUShort()
			local extraLength = self:ReadUShort()
			data.path = self:Read(pathLength)
			self:Skip(extraLength)
			local method = compressionMethods[compressionMethod]
			if not method then
				return data, "compression method not supported"
			end
			local content = method[2](self:Read(compressedSize))
			data.content = content
			if doCRC and content and crc ~= CRC(content) then
				return data, "crc-32 mismatch"
			end
			return data
		end,
		WriteZipFile = function(self, fileName, content, compressionMethod, unixTime)
			if compressionMethod == nil then
				compressionMethod = 0
			end
			if unixTime == nil then
				unixTime = time()
			end
			argument(fileName, 1, "string")
			argument(content, 2, "string")
			argument(compressionMethod, 3, "number")
			argument(unixTime, 4, "number")
			-- signature
			self:Write("PK\x03\x04")
			-- Version needed to extract (minimum)
			self:WriteUShort(0)
			-- General purpose bit flag
			self:WriteUShort(0)
			local method = compressionMethods[compressionMethod]
			if not method then
				throw("Unsupported compression method: " .. compressionMethod)
				return nil
			end
			-- Compression method
			self:WriteUShort(compressionMethod)
			-- Modification time
			self:WriteTime(unixTime)
			-- CRC-32
			self:WriteULong(tonumber(CRC(content), 10))
			local fileSize = len(content)
			content = method[1](content)
			-- Compressed size
			self:WriteULong(len(content))
			-- Uncompressed size
			self:WriteULong(fileSize)
			-- File name length
			self:WriteUShort(len(fileName))
			-- Extra field length
			self:WriteUShort(0)
			self:Write(fileName)
			return self:Write(content)
		end,
		ReadColor = function(self)
			return Color(byte(self:Read(4)))
		end,
		WriteColor = function(self, color)
			return self:Write(char(color.r, color.g, color.b, color.a))
		end,
		ReadDate = function(self)
			return Date.FromBinary(self:Read(12))
		end,
		WriteDate = function(self, date)
			if isstring(date) then
				date = Date(date)
			end
			argument(date, 1, "Date")
			return self:Write(date:ToBinary())
		end,
		ReadSteamID = function(self, isBigEndian, withUniverse)
			return SteamID.FromBinary(self:Read(withUniverse and 5 or 4), setEndianness(isBigEndian), withUniverse)
		end,
		WriteSteamID = function(self, steamid, withUniverse)
			if isstring(steamid) then
				steamid = SteamID(steamid)
			end
			argument(steamid, 1, "SteamID")
			return self:Write(steamid:ToBinary(withUniverse))
		end
	}, {
		CompressionMethods = compressionMethods
	}, struct.Cursor)
	do
		local ceil, max, pow2, floor, isuint = math.ceil, math.max, math.pow2, math.floor, math.isuint
		local Insert, Reverse = table.Insert, table.Reverse
		local string_ToBytes = string.ToBytes
		local band = bit.band
		local metatable = {
			__tostring = function(self)
				return format("BitStream: %p [%d/%d]", self, self.pointer, self.size)
			end,
			new = function(self, binary)
				self.buffer_size = 0
				self.pointer = 0
				self.buffer = { }
				if binary then
					argument(binary, 1, "string")
					local bits, size = { }, 0
					local _list_0 = {
						byte(binary, 1, len(binary))
					}
					for _index_0 = 1, #_list_0 do
						local uint = _list_0[_index_0]
						for i = 0, 7, 1 do
							size = size + 1
							bits[size] = band(uint, pow2[i]) ~= 0
						end
					end
					self.bits, self.size = bits, size
					return nil
				end
				self.bits, self.size = { }, 0
				return nil
			end,
			Flush = function(self)
				local buffer_size = self.buffer_size
				if buffer_size == 0 then
					return self.bits
				end
				local bits, pointer, size = self.bits, self.pointer, self.size
				if pointer > size then
					for index = size, pointer do
						bits[index] = false
					end
					size = pointer
				end
				Insert(self.buffer, pointer, buffer_size, pointer, bits)
				self.pointer = pointer + buffer_size
				self.size = size + buffer_size
				self.buffer_size = 0
				self.buffer = { }
				return bits
			end,
			Size = function(self, inBytes)
				if inBytes then
					return ceil(self.size * 0.125)
				end
				return self.size
			end,
			SkipZeros = function(self)
				local pointer = self.pointer + 1
				local bits, size = self.bits, self.size
				while pointer <= size do
					pointer = pointer + 1
					if bits[pointer] then
						pointer = pointer - 1
						break
					end
				end
				return self:Seek(pointer)
			end,
			ReadBits = function(self, length)
				self:Flush()
				local pointer, size = self.pointer, self.size
				if length == "*a" or length == nil then
					length = size
				end
				argument(length, 2, "number")
				if length > 0 then
					if pointer >= size then
						return nil, "eof"
					end
					return unpack(self.bits, pointer + 1, pointer + length)
				end
				if length < 0 then
					if pointer <= 0 then
						return nil, "sof"
					end
					local start, finish = pointer + 1, pointer + length
					return unpack(Reverse({
						unpack(self.bits, start, finish)
					}, false), start, finish)
				end
				return nil
			end,
			WriteBits = function(self, ...)
				local buffer, buffer_size = self.buffer, self.buffer_size
				local _list_0 = {
					...
				}
				for _index_0 = 1, #_list_0 do
					local value = _list_0[_index_0]
					buffer_size = buffer_size + 1
					buffer[buffer_size] = value == true
				end
				self.buffer_size = buffer_size
				return nil
			end,
			ReadBit = function(self)
				if self:EndOfFile() then
					return nil, "eof"
				end
				return self.bits[self:Skip(1)] == true
			end,
			WriteBit = function(self, bool)
				local buffer_size = self.buffer_size + 1
				self.buffer[buffer_size] = bool == true
				self.buffer_size = buffer_size
				return nil
			end,
			ReadByte = function(self)
				local pointer = self.pointer
				if pointer >= self.size then
					return nil, "eof"
				end
				self.pointer = pointer + 8
				local bits = self.bits
				return (bits[pointer + 1] and 1 or 0) + (bits[pointer + 2] and 2 or 0) + (bits[pointer + 3] and 4 or 0) + (bits[pointer + 4] and 8 or 0) + (bits[pointer + 5] and 16 or 0) + (bits[pointer + 6] and 32 or 0) + (bits[pointer + 7] and 64 or 0) + (bits[pointer + 8] and 128 or 0)
			end,
			WriteByte = function(self, uint)
				argument(uint, 1, "number")
				if uint < 0 or uint > 255 then
					throw("Invalid byte value", 2)
				end
				local buffer, buffer_size = self.buffer, self.buffer_size
				for i = 0, 7 do
					buffer_size = buffer_size + 1
					buffer[buffer_size] = band(uint, pow2[i]) ~= 0
				end
				self.buffer_size = buffer_size
				return self
			end,
			WriteNull = function(self)
				local buffer, buffer_size = self.buffer, self.buffer_size
				for i = 1, 8 do
					buffer_size = buffer_size + 1
					buffer[buffer_size] = false
				end
				self.buffer_size = buffer_size
				return self
			end,
			Read = function(self, length)
				self:Flush()
				local pointer, size = self.pointer, self.size
				local isNegative
				if length == nil then
					length = ceil((size - pointer) / 8)
					isNegative = false
				elseif length == 0 then
					return nil, "no data"
				else
					isNegative = length < 0
					if isNegative then
						if pointer <= 0 then
							return nil, "sof"
						end
						length = max(-length, ceil(pointer / 8))
					elseif pointer >= size then
						return nil, "eof"
					else
						length = max(length, ceil((size - pointer) / 8))
					end
				end
				local bytes = { }
				local bits = self.bits
				if isNegative then
					self:Skip(-length * 8)
					return self:Read(length)
				end
				for i = 1, length, 1 do
					pointer = pointer + 1
					local uint = 0
					for j = 0, 7, 1 do
						if bits[pointer + j] == true then
							uint = uint + pow2[j]
						end
					end
					pointer = pointer + 7
					bytes[i] = char(uint)
				end
				self.pointer = pointer
				return concat(bytes, "", 1, length)
			end,
			Write = function(self, str)
				argument(str, 1, "string")
				local buffer, buffer_size = self.buffer, self.buffer_size
				local _list_0 = {
					byte(str, 1, len(str))
				}
				for _index_0 = 1, #_list_0 do
					local uint = _list_0[_index_0]
					for j = 0, 7, 1 do
						buffer_size = buffer_size + 1
						buffer[buffer_size] = band(uint, pow2[j]) ~= 0
					end
				end
				self.buffer_size = buffer_size
				return self
			end,
			ReadString = function(self)
				local pointer = self.pointer
				if pointer >= self.size then
					return nil, "eof"
				end
				local parts, length = { }, 0
				local uint = self:ReadByte()
				while uint ~= 0 do
					length = length + 1
					parts[length] = char(uint)
					uint = self:ReadByte()
				end
				if length == 0 then
					return nil, "no data"
				end
				return concat(parts, "", 1, length)
			end,
			WriteString = function(self, str)
				argument(str, 1, "string")
				self:Write(str .. "\0")
				return self
			end,
			ReadLine = function(self)
				local pointer, size = self.pointer, self.size
				if pointer >= size then
					return nil, "eof"
				end
				local length = 0
				for index = pointer, size do
					local uint = self:ReadByte()
					if not uint then
						return nil, "eof"
					end
					if uint == 0xA or uint == 0 then
						break
					end
					length = length + 1
				end
				if length == 0 then
					return nil
				end
				self:Seek(pointer)
				return self:Read(length)
			end,
			ReadBinaryString = function(self)
				local pointer, size, bits = self.pointer, self.size, self.bits
				local chars, count = { }, 0
				for index = pointer + 1, size, 1 do
					count = count + 1
					chars[count] = bits[index] and "1" or "0"
				end
				self.pointer = size
				return concat(chars, "", 1, count)
			end,
			WriteBinaryString = function(self, str)
				argument(str, 1, "string")
				local buffer, buffer_size = self.buffer, self.buffer_size
				local bytes, length = string_ToBytes(str)
				for i = 1, length do
					buffer_size = buffer_size + 1
					buffer[buffer_size] = bytes[i] == 0x31
				end
				self.buffer_size = buffer_size
				return self
			end,
			ReadUInt = function(self, bitCount)
				if bitCount == 0 then
					return 0
				elseif bitCount < 0 then
					throw("uint cannot be negative", 2)
				end
				if not isuint(bitCount) then
					bitCount = ceil(bitCount)
				end
				self:Flush()
				local pointer = self.pointer
				local endPos = pointer + bitCount
				if endPos > self.size then
					return nil, "eof"
				end
				self.position = pointer
				local bits = self.bits
				local uint = 0
				for i = pointer + 1, endPos, 1 do
					if bits[i] == true then
						uint = uint + pow2[bitCount - i]
					end
				end
				return uint
			end,
			WriteUInt = function(self, uint, bitCount, isBigEndian)
				argument(uint, 1, "number")
				argument(bitCount, 2, "number")
				bitCount = max(isuint(bitCount) and bitCount or ceil(bitCount), 0)
				if bitCount == 0 then
					return self
				end
				if uint > (pow2[bitCount] - 1) then
					throw(format("UInt '%i' cannot fit in %i bits (max: %i)", uint, bitCount, pow2[bitCount] - 1), 2)
				end
				local buffer, buffer_size = self.buffer, self.buffer_size
				for i = bitCount - 1, 0, -1 do
					if uint == 0 then
						for j = buffer_size + (i + 1), buffer_size + 1, -1 do
							buffer[j] = false
						end
						break
					else
						buffer[buffer_size + (i + 1)] = uint % 2 == 1
						uint = floor(uint * 0.5)
					end
				end
				self.buffer_size = buffer_size + bitCount
				return self
			end,
			ReadUShort = function(self, isBigEndian)
				setEndianness(isBigEndian)
				return readUInt(nil, self:Read(2), 2)
			end,
			WriteUShort = function(self, number, isBigEndian)
				argument(number, 1, "number")
				setEndianness(isBigEndian)
				return self:Write(writeUInt(nil, number, 2))
			end,
			ReadULong = function(self, isBigEndian)
				setEndianness(isBigEndian)
				return readUInt(nil, self:Read(4), 4)
			end,
			WriteULong = function(self, number, isBigEndian)
				argument(number, 1, "number")
				setEndianness(isBigEndian)
				return self:Write(writeUInt(nil, number, 4))
			end,
			ReadInt = function(self, bitCount)
				return self:ReadUInt(bitCount) - pow2[bitCount - 1]
			end,
			WriteInt = function(self, int, bitCount)
				return self:WriteUInt(int + pow2[bitCount - 1], bitCount)
			end,
			ReadShort = function(self, isBigEndian)
				setEndianness(isBigEndian)
				return readInt(nil, self:Read(2), 2)
			end,
			WriteShort = function(self, number, isBigEndian)
				argument(number, 1, "number")
				setEndianness(isBigEndian)
				return self:Write(writeInt(nil, number, 2))
			end,
			ReadLong = function(self, isBigEndian)
				setEndianness(isBigEndian)
				return readInt(nil, self:Read(4), 4)
			end,
			WriteLong = function(self, number, isBigEndian)
				argument(number, 1, "number")
				setEndianness(isBigEndian)
				return self:Write(writeInt(nil, number, 4))
			end,
			ReadUInt64 = function(self, isBigEndian)
				local binary = self:Read(8)
				if not binary then
					return nil, "eof"
				end
				if setEndianness(isBigEndian) then
					if byte(binary, 1) == 0 and byte(binary, 2) == 0 then
						return readUInt(nil, sub(binary, 3), 6)
					end
					return FromBytes(binary, false)
				end
				if byte(binary, 7) == 0 and byte(binary, 8) == 0 then
					return readUInt(nil, binary, 6)
				end
				return FromBytes(binary, true)
			end,
			WriteUInt64 = function(self, number, isBigEndian)
				local isBint
				if isnumber(number) then
					isBint = false
				else
					number = BInt(number)
					isBint = true
				end
				if isBint or number > 0xFFFFFFFFFFFF then
					if setEndianness(isBigEndian) then
						return self:Write(string_ToBytes(number, 8, false))
					end
					return self:Write(string_ToBytes(number, 8, true))
				end
				if setEndianness(isBigEndian) then
					self:WriteNull()
					self:WriteNull()
					if isBint then
						return self:Write(writeUInt(nil, ToNumber(number), 6))
					end
					return self:Write(writeUInt(nil, number, 6))
				end
				if isBint then
					self:Write(writeUInt(nil, ToNumber(number), 6))
				else
					self:Write(writeUInt(nil, number, 6))
				end
				self:WriteNull()
				return self:WriteNull()
			end,
			ReadInt64 = function(self, isBigEndian)
				local binary = self:Read(8)
				if not binary then
					return nil, "eof"
				end
				if setEndianness(isBigEndian) then
					if byte(binary, 1) == 0 and byte(binary, 2) == 0 then
						return readInt(nil, sub(binary, 3), 6)
					end
					return CastSigned(FromBytes(binary, false), 8)
				end
				if byte(binary, 7) == 0 and byte(binary, 8) == 0 then
					return readInt(nil, binary, 6)
				end
				return CastSigned(FromBytes(binary, true), 8)
			end,
			WriteInt64 = function(self, number, isBigEndian)
				local isBint
				if isnumber(number) then
					isBint = false
				else
					number = BInt(number)
					isBint = true
				end
				if isBint or number > 0xFFFFFFFFFFFF then
					if setEndianness(isBigEndian) then
						return self:Write(string_ToBytes(number, 8, false))
					end
					return self:Write(string_ToBytes(number, 8, true))
				end
				if setEndianness(isBigEndian) then
					self:WriteNull()
					self:WriteNull()
					if isBint then
						return self:Write(writeInt(nil, ToNumber(number), 6))
					end
					return self:Write(writeInt(nil, number, 6))
				end
				if isBint then
					self:Write(writeInt(nil, ToNumber(number), 6))
				else
					self:Write(writeInt(nil, number, 6))
				end
				self:WriteNull()
				return self:WriteNull()
			end,
			ReadColor = function(self)
				return Color(self:ReadByte(), self:ReadByte(), self:ReadByte(), self:ReadByte())
			end,
			WriteColor = function(self, color)
				self:WriteByte(color.r)
				self:WriteByte(color.g)
				self:WriteByte(color.b)
				return self:WriteByte(color.a)
			end
		}
		-- Yep, in bitstream bool is a bit
		metatable.ReadBool = metatable.ReadBit
		metatable.WriteBool = metatable.WriteBit
		local inf, nan, isnegative, ldexp, frexp = math.inf, math.nan, math.isnegative, math.ldexp, math.frexp
		local implode, explode = struct.implode, struct.explode
		-- Float
		do
			-- constants
			local c0 = pow2[7]
			local c1 = pow2[8] - 1
			local c2 = pow2[23]
			local c3 = 1 - 23 - c0
			local c4 = pow2[22]
			local bias = c0 - 1
			local c5 = bias + 1
			local c6 = pow2[24]
			metatable.ReadFloat = function(self)
				self:Flush()
				local pointer = self.pointer
				local endPos = pointer + 32
				if endPos > self.size then
					return nil, "eof"
				end
				local bits = self.bits
				local fraction = implode(bits, 23, pointer)
				local exponent = implode(bits, 8, pointer + 23)
				local sign = bits[endPos] and -1 or 1
				if exponent == c1 then
					if fraction == 0 or sign == -1 then
						return sign * inf
					end
					return nan
				end
				if exponent ~= 0 then
					fraction = fraction + c2
				else
					exponent = 1
				end
				return sign * ldexp(fraction, exponent + c3)
			end
			metatable.WriteFloat = function(self, float)
				argument(float, 1, "number")
				local sign
				if isnegative(float) then
					sign = true
					float = -float
				else
					sign = false
				end
				local exponent, fraction
				if float == inf then
					exponent = c5
					fraction = 0
				elseif float ~= float then
					exponent = c5
					fraction = c4
				elseif float == 0 then
					exponent = -bias
					fraction = 0
				else
					fraction, exponent = frexp(float)
					local ebs = exponent + bias
					if ebs <= 1 then
						fraction = fraction * pow2[22 + ebs]
						exponent = -bias
					else
						fraction = fraction - 0.5
						exponent = exponent - 1
						fraction = fraction * c6
					end
				end
				local bits = explode(fraction)
				local exponentBits = explode(exponent + bias)
				for index = 1, 8 do
					bits[23 + index] = exponentBits[index]
				end
				bits[32] = sign
				local buffer, buffer_size = self.buffer, self.buffer_size
				for index = 1, 32 do
					buffer_size = buffer_size + 1
					buffer[buffer_size] = bits[index] == true
				end
				self.buffer_size = buffer_size
				return self
			end
		end
		-- Double
		do
			-- constants
			local c0 = pow2[11] - 1
			local c1 = pow2[52]
			local c2 = pow2[10]
			local c3 = 1 - 52 - c2
			local c4 = pow2[51]
			local bias = c2 - 1
			local c5 = bias + 1
			local c6 = pow2[53]
			metatable.ReadDouble = function(self)
				self:Flush()
				local pointer = self.pointer
				local endPos = pointer + 64
				if endPos > self.size then
					return nil, "eof"
				end
				local bits = self.bits
				local fraction = implode(bits, 52, pointer)
				local exponent = implode(bits, 11, pointer + 52)
				local sign = bits[endPos] and -1 or 1
				if exponent == c0 then
					if fraction == 0 or sign == -1 then
						return sign * inf
					end
					return nan
				end
				if exponent ~= 0 then
					fraction = fraction + c1
				else
					exponent = 1
				end
				return sign * ldexp(fraction, exponent + c3)
			end
			metatable.WriteDouble = function(self, double)
				argument(double, 2, "number")
				local sign
				if isnegative(double) then
					sign = true
					double = -double
				else
					sign = false
				end
				local exponent, fraction
				if double == inf then
					exponent = c5
					fraction = 0
				elseif double ~= double then
					exponent = c5
					fraction = c4
				elseif double == 0 then
					exponent = -bias
					fraction = 0
				else
					fraction, exponent = frexp(double)
					local ebs = exponent + bias
					if ebs <= 1 then
						fraction = fraction * pow2[51 + ebs]
						exponent = -bias
					else
						fraction = fraction - 0.5
						exponent = exponent - 1
						fraction = fraction * c6
					end
				end
				local bits = explode(fraction)
				local exponentBits = explode(exponent + bias)
				for index = 1, 11 do
					bits[52 + index] = exponentBits[index]
				end
				bits[64] = sign
				local buffer, buffer_size = self.buffer, self.buffer_size
				for index = 1, 64 do
					buffer_size = buffer_size + 1
					buffer[buffer_size] = bits[index] == true
				end
				self.buffer_size = buffer_size
				return self
			end
		end
		util.BitStream = environment.extend(util.ByteStream, "BitStream", metatable)
	end
end
-- Version
do
	local ByteSplit, lower = string.ByteSplit, string.lower
	do
		local URL, isurl = environment.URL, environment.isurl
		local Flip = table.Flip
		string.PathFromURL = function(url)
			if not isurl(url) then
				url = URL(url)
			end
			if not url.hostname or url.hostname == "" then
				return url.scheme .. "/" .. lower(url.pathname)
			end
			return url.scheme .. "/" .. concat(Flip(ByteSplit(lower(url.hostname), 0x2E)), "/") .. lower(url.pathname)
		end
	end
	local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift
	local isuint, max = math.isuint, math.max
	local ByteCount = string.ByteCount
	local sort = table.sort
	local compare
	compare = function(a, b)
		return a == b and 0 or a < b and -1 or 1
	end
	local compareIDs
	compareIDs = function(value, value2)
		if value == value2 then
			return 0
		end
		if not value then
			return -1
		end
		if not value2 then
			return 1
		end
		local number, number2 = tonumber(value, 10), tonumber(value2, 10)
		if number and number2 then
			return compare(number, number2)
		end
		if number then
			return -1
		end
		if number2 then
			return 1
		end
		return compare(value, value2)
	end
	local smallerPreRelease
	smallerPreRelease = function(first, second)
		if not first or first == second then
			return false
		end
		if not second then
			return true
		end
		local fisrt, fcount = ByteSplit(first, 0x2E)
		local scount
		second, scount = ByteSplit(second, 0x2E)
		local comparison
		for index = 1, fcount do
			comparison = compareIDs(fisrt[index], second[index])
			if comparison ~= 0 then
				return comparison == -1
			end
		end
		return fcount < scount
	end
	local parsePreRelease
	parsePreRelease = function(str)
		if str == "" then
			return nil
		end
		local preRelease = match(str, "^-(%w[%.%w-]*)$")
		if not preRelease or match(preRelease, "%.%.") then
			throw("the pre-release '" .. str .. "' is not valid")
			return nil
		end
		return preRelease
	end
	local parseBuild
	parseBuild = function(str)
		if str == "" then
			return nil
		end
		local build = match(str, "^%+(%w[%.%w-]*)$")
		if not build or match(build, "%.%.") then
			throw("the build '" .. str .. "' is not valid")
			return nil
		end
		return build
	end
	local parsePreReleaseAndBuild
	parsePreReleaseAndBuild = function(self, str)
		if not str or str == "" then
			return nil
		end
		local preRelease, build = match(str, "^(%-[^+]+)(%+.+)$")
		if not (preRelease and build) then
			local _exp_0 = byte(str, 1)
			if 0x2d == _exp_0 then
				preRelease = parsePreRelease(str)
			elseif 0x2b == _exp_0 then
				build = parseBuild(str)
			else
				throw("the parameter '" .. str .. "' must begin with + or - to denote a pre-release or a build", 3)
				return nil
			end
		end
		return preRelease, build
	end
	-- Semver lua parser. Based on https://github.com/kikito/semver.lua
	-- https://github.com/Pika-Software/gpm_legacy/blob/main/lua/gpm/sh_semver.lua
	local numbersToString
	numbersToString = function(major, minor, patch, preRelease, build)
		if preRelease and build then
			return major .. "." .. minor .. "." .. patch .. "-" .. preRelease .. "+" .. build
		end
		if preRelease then
			return major .. "." .. minor .. "." .. patch .. "-" .. preRelease
		end
		if build then
			return major .. "." .. minor .. "." .. patch .. "+" .. build
		end
		return major .. "." .. minor .. "." .. patch
	end
	local parse
	parse = function(major, minor, patch, preRelease, build)
		if not major then
			throw("at least one parameter is needed", 2)
			return nil
		end
		if isnumber(major) then
			if not isuint(major) then
				throw("major version must be unsigned integer", 2)
			end
			if minor then
				if not isnumber(minor) then
					throw("minor version must be a number", 2)
				end
				if not isuint(minor) then
					throw("minor version must be unsigned integer", 2)
				end
			else
				minor = 0
			end
			if patch then
				if not isnumber(patch) then
					throw("patch version must be a number", 2)
				end
				if not isuint(patch) then
					throw("patch version must be unsigned integer", 2)
				end
			else
				patch = 0
			end
			if isstring(build) then
				if isstring(preRelease) then
					preRelease = parsePreRelease(preRelease)
				end
				build = parseBuild(build)
			elseif isnumber(preRelease) then
				preRelease, build = parsePreReleaseAndBuild(preRelease)
			end
		else
			local extra
			major, minor, patch, extra = match(tostring(major), "^(%d+)%.?(%d*)%.?(%d*)(.-)$")
			if not major then
				throw("the major version is missing", 2)
				return nil
			end
			major = tonumber(major, 10)
			if minor == "" then
				minor = "0"
			end
			minor = tonumber(minor, 10)
			if patch == "" then
				patch = "0"
			end
			patch = tonumber(patch, 10)
			preRelease, build = parsePreReleaseAndBuild(extra)
		end
		if major > 0x3ff or minor > 0x7ff or patch > 0x7ff then
			throw("version is too large (max 1023.2047.2047)", 2)
		elseif major < 0 or minor < 0 or patch < 0 then
			throw("version is too small (min 0.0.0)", 2)
		end
		return major, minor, patch, preRelease, build
	end
	local versions = { }
	local sort_fn
	sort_fn = function(a, b)
		return a > b
	end
	local versionClass
	versionClass = newClass("Version", {
		__tostring = function(self)
			return self.__string
		end,
		new = function(self, major, minor, patch, preRelease, build)
			major, minor, patch, preRelease, build = parse(major, minor, patch, preRelease, build)
			local str = numbersToString(major, minor, patch, preRelease, build)
			local version = versions[str]
			if version and version.major == major and version.minor == minor and version.patch == patch and version.prerelease == preRelease and version.build == build then
				return true, version
			end
			self.major, self.minor, self.patch, self.prerelease, self.build = major, minor, patch, preRelease, build
			versions[str] = self
			self.__string = str
			return false, nil
		end,
		__eq = function(self, other)
			return self.__string == other.__string
		end,
		__lt = function(self, other)
			if self.major ~= other.major then
				return self.major < other.major
			end
			if self.minor ~= other.minor then
				return self.minor < other.minor
			end
			if self.patch ~= other.patch then
				return self.patch < other.patch
			end
			return smallerPreRelease(self.prerelease, other.prerelease)
		end,
		__pow = function(self, other)
			if self.major == 0 then
				return self == other
			end
			return self.major == other.major and self.minor <= other.minor
		end,
		__mod = function(self, str)
			-- version range := comparator sets
			if find(str, "||", 1, true) then
				local pos, part
				local start = 1
				while true do
					pos = find(str, "||", start, true)
					part = sub(str, start, pos and (pos - 1))
					if self % part then
						return true
					end
					if not pos then
						return false
					end
					start = pos + 2
				end
			end
			-- comparator set := comparators
			str = gsub(gsub(gsub(str, "%s+", " "), "^%s+", ""), "%s+$", "")
			if find(str, " ", 1, true) then
				local pos, part
				local start = 1
				while true do
					pos = find(str, " ", start, true)
					part = sub(str, start, pos and (pos - 1))
					-- Hyphen Ranges: X.Y.Z - A.B.C
					-- https://docs.npmjs.com/cli/v6/using-npm/semver#hyphen-ranges-xyz---abc
					if pos and sub(str, pos, pos + 2) == " - " then
						if not (self % (">=" .. part)) then
							return false
						end
						start = pos + 3
						pos = find(str, " ", start, true)
						part = sub(str, start, pos and (pos - 1))
						if not (self % ("<=" .. part)) then
							return false
						end
					elseif not (self % part) then
						return false
					end
					if not pos then
						return true
					end
					start = pos + 1
				end
				return true
			end
			-- comparators := operator + version
			str = gsub(gsub(str, "^=", ""), "^v", "")
			-- X-Ranges *
			-- Any of X, x, or * may be used to 'stand in' for one of the numeric values in the [major, minor, patch] tuple.
			-- https://docs.npmjs.com/cli/v6/using-npm/semver#x-ranges-12x-1x-12-
			if str == "" or str == "*" then
				return self % ">=0.0.0"
			end
			local pos = find(str, "%d")
			if not pos then
				throw("Version range must starts with number: " .. str, 2)
				return nil
			end
			-- X-Ranges 1.2.x 1.X 1.2.*
			-- Any of X, x, or * may be used to 'stand in' for one of the numeric values in the [major, minor, patch] tuple.
			-- https://docs.npmjs.com/cli/v6/using-npm/semver#x-ranges-12x-1x-12-
			local operator
			if pos == 1 then
				operator = "="
			else
				operator = sub(str, 1, pos - 1)
			end
			local version = gsub(sub(str, pos), "%.[xX*]", "")
			local xrange = max(2 - ByteCount(version, 0x2e), 0)
			for i = 1, xrange do
				version = version .. ".0"
			end
			local sv = versionClass(version)
			if operator == "<" then
				return self < sv
			end
			-- primitive operators
			-- https://docs.npmjs.com/cli/v6/using-npm/semver#ranges
			if operator == "<=" then
				if xrange > 0 then
					if xrange == 1 then
						sv = sv:nextMinor()
					elseif xrange == 2 then
						sv = sv:nextMajor()
					end
					return self < sv
				end
				return self <= sv
			end
			if operator == ">" then
				if xrange > 0 then
					if xrange == 1 then
						sv = sv:nextMinor()
					elseif xrange == 2 then
						sv = sv:nextMajor()
					end
					return self >= sv
				end
				return self > sv
			end
			if operator == ">=" then
				return self >= sv
			end
			if operator == "=" then
				if xrange > 0 then
					if self < sv then
						return false
					end
					if xrange == 1 then
						sv = sv:nextMinor()
					elseif xrange == 2 then
						sv = sv:nextMajor()
					end
					return self < sv
				end
				return self == sv
			end
			-- Caret Ranges ^1.2.3 ^0.2.5 ^0.0.4
			-- Allows changes that do not modify the left-most non-zero digit in the [major, minor, patch] tuple.
			-- In other words, this allows patch and minor updates for versions 1.0.0 and above, patch updates for
			-- versions 0.X >=0.1.0, and no updates for versions 0.0.X.
			-- https://docs.npmjs.com/cli/v6/using-npm/semver#caret-ranges-123-025-004
			if operator == "^" then
				if sv.major == 0 and xrange < 2 then
					if sv.minor == 0 and xrange < 1 then
						return self.major == 0 and self.minor == 0 and self >= sv and self < sv:nextPatch()
					end
					return self.major == 0 and self >= sv and self < sv:nextMinor()
				end
				return self.major == sv.major and self >= sv and self < sv:nextMajor()
			end
			-- Tilde Ranges ~1.2.3 ~1.2 ~1
			-- Allows patch-level changes if a minor version is specified on the comparator. Allows minor-level changes if not.
			-- https://docs.npmjs.com/cli/v6/using-npm/semver#tilde-ranges-123-12-1
			if operator == "~" then
				if self < sv then
					return false
				end
				if xrange == 2 then
					return self < sv:nextMajor()
				end
				return self < sv:nextMinor()
			end
			throw("Invaild operator: '" .. operator .. "'", 2)
			return nil
		end,
		nextMajor = function(self)
			return versionClass(self.major + 1, 0, 0)
		end,
		nextMinor = function(self)
			return versionClass(self.major, self.minor + 1, 0)
		end,
		nextPatch = function(self)
			return versionClass(self.major, self.minor, self.patch + 1)
		end,
		toNumber = function(self)
			local major = tonumber(self.major, 10)
			if major > 0x3ff then
				throw("major version is too large (max 1023)", 2)
				return nil
			end
			local minor = tonumber(self.minor, 10)
			if minor > 0x7ff then
				throw("minor version is too large (max 2047)", 2)
				return nil
			end
			local patch = tonumber(self.patch, 10)
			if patch > 0x7ff then
				throw("patch version is too large (max 2047)", 2)
				return nil
			end
			return bor(lshift(patch, 21), lshift(minor, 10), major)
		end
	}, {
		parse = parse,
		tostring = function(...)
			return numbersToString(parse(...))
		end,
		fromNumber = function(uint)
			return versionClass(band(uint, 0x3ff), band(rshift(uint, 10), 0x7ff), band(rshift(uint, 21), 0x7ff))
		end,
		select = function(target, tbl)
			sort(tbl, sort_fn)
			for index = 1, #tbl do
				local version = versionClass(tbl[index])
				if version % target then
					return version, index
				end
			end
			return nil, -1
		end
	})
	util.Version = versionClass
end
if _G.sql then
	local SQLError = environment.SQLError
	local SQLSafe = string.SQLSafe
	local sql, pairs = _G.sql, _G.pairs
	local Query = sql.Query
	local lib = environment.sql
	do
		local _tmp_0
		_tmp_0 = function()
			return sql.m_strError
		end
		lib.lastError = _tmp_0
		lib.LastError = _tmp_0
	end
	local escape
	escape = function(str)
		return str == nil and "null" or SQLSafe(str)
	end
	lib.escape = escape
	lib.Escape = escape
	local rawQuery
	rawQuery = function(str)
		Logger:Debug("Executing SQL query: " .. str)
		local result = Query(str)
		if result == false then
			throw(SQLError(sql.m_strError, nil, nil, 4))
		end
		return result
	end
	lib.rawQuery = rawQuery
	lib.RawQuery = rawQuery
	local tableExists
	tableExists = function(name)
		return rawQuery("select name from sqlite_master where name=" .. escape(name) .. " and type='table'") and true or false
	end
	lib.tableExists = tableExists
	lib.TableExists = tableExists
	do
		local _tmp_0
		_tmp_0 = function(name)
			return rawQuery("select name from sqlite_master where name=" .. escape(name) .. " and type='index'") and true or false
		end
		lib.IndexExists = _tmp_0
		lib.IndexExists = _tmp_0
	end
	local begin
	begin = function()
		rawQuery("begin")
		return nil
	end
	lib.begin = begin
	lib.Begin = begin
	local commit
	commit = function()
		rawQuery("commit")
		return nil
	end
	lib.commit = commit
	lib.Commit = commit
	local rollback
	rollback = function()
		rawQuery("rollback")
		return nil
	end
	lib.rollback = rollback
	lib.Rollback = rollback
	local query
	query = function(str, ...)
		local args, index = {
			...
		}, 0
		str = gsub(str, "?", function()
			index = index + 1
			return escape(args[index])
		end)
		local result = rawQuery(str)
		-- convert NULL values into nil
		if result then
			for _index_0 = 1, #result do
				local tbl = result[_index_0]
				for key, value in pairs(tbl) do
					if value == "NULL" then
						tbl[key] = nil
					end
				end
			end
		end
		return result
	end
	lib.query = query
	lib.Query = query
	local queryRow
	queryRow = function(str, row, ...)
		if row == nil then
			row = 1
		end
		local result = query(str, ...)
		if result then
			return result[row]
		end
		return nil
	end
	lib.queryRow = queryRow
	lib.QueryRow = queryRow
	local queryOne
	queryOne = function(str, ...)
		return queryRow(str, 1, ...)
	end
	lib.queryOne = queryOne
	lib.QueryOne = queryOne
	do
		local _tmp_0
		_tmp_0 = function(str, ...)
			local result = queryOne(str, ...)
			if result then
				return next(result)
			end
			return nil
		end
		lib.queryValue = _tmp_0
		lib.QueryValue = _tmp_0
	end
	do
		local _tmp_0
		_tmp_0 = function(func)
			begin()
			local ok, result = pcall(func)
			if ok then
				commit()
				return result
			end
			rollback()
			throw(result)
			return nil
		end
		lib.transaction = _tmp_0
		lib.Transaction = _tmp_0
	end
end

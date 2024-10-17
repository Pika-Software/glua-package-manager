local _G = _G
local gmod_net = _G.net
if not gmod_net then
	return nil
end
local NULL, pairs, getfenv, setmetatable, xpcall = _G.NULL, _G.pairs, _G.getfenv, _G.setmetatable, _G.xpcall
local environment
do
	local _obj_0 = _G.gpm
	environment = _obj_0.environment
end
local string, net, util, isnumber, isstring, Entity, TypeID, ErrorNoHaltWithStack, argument, throw, SERVER = environment.string, environment.net, environment.util, environment.isnumber, environment.isstring, environment.Entity, environment.TypeID, environment.ErrorNoHaltWithStack, environment.argument, environment.throw, environment.SERVER
local ReadUInt, WriteUInt, ReadData, WriteData, Start = gmod_net.ReadUInt, gmod_net.WriteUInt, gmod_net.ReadData, gmod_net.WriteData, gmod_net.Start
local byte, char, lower = string.byte, string.char, string.lower
local ENTITY = FindMetaTable("Entity")
local EntIndex, IsValid = ENTITY.EntIndex, ENTITY.IsValid
local types = rawget(net, "Types")
if not istable(types) then
	types = { }
	net.Types = types
end
-- C
types[environment.TYPE_STRING] = {
	net.ReadString,
	net.WriteString
}
types[environment.TYPE_NUMBER] = {
	net.ReadDouble,
	net.WriteDouble
}
types[environment.TYPE_MATRIX] = {
	net.ReadMatrix,
	net.WriteMatrix
}
types[environment.TYPE_VECTOR] = {
	net.ReadVector,
	net.WriteVector
}
types[environment.TYPE_ANGLE] = {
	net.ReadAngle,
	net.WriteAngle
}
net.WriteType = function(value, index)
	if not isnumber(index) then
		index = TypeID(value)
		if index < 0 then
			throw("invalid type '" .. index .. "'", 2)
			return nil
		end
	end
	local data = types[index]
	if data then
		local func = data[2]
		if func then
			WriteUInt(index, 16)
			return func(value)
		end
	end
	throw("missing type '" .. index .. "' writer", 2)
	return nil
end
do
	local TYPE_NIL = _G.TYPE_NIL
	net.ReadType = function(index)
		if index == nil then
			index = ReadUInt(16)
		end
		if index == TYPE_NIL then
			return nil
		end
		local data = types[index]
		if data then
			local func = data[1]
			if func then
				return func()
			end
		end
		throw("missing type '" .. index .. "' reader", 2)
		return nil
	end
end
if SERVER then
	local NetworkStringToID, AddNetworkString = util.NetworkStringToID, util.AddNetworkString
	local rawset = _G.rawset
	local networkStrings = rawget(net, "NetworkStrings")
	if not istable(networkStrings) then
		networkStrings = setmetatable({ }, {
			__newindex = environment.debug.fempty,
			__index = function(tbl, key)
				local value = NetworkStringToID(key)
				rawset(tbl, key, value)
				return value
			end
		})
		rawset(net, "NetworkStrings", networkStrings)
	end
	net.Register = function(networkString)
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				networkString = pkg.prefix .. networkString
			end
		end
		networkString = lower(networkString)
		local value = networkStrings[networkString]
		if not value or value == 0 then
			value = AddNetworkString(networkString)
			rawset(networkStrings, networkString, value)
		end
		return value
	end
	net.Exists = function(networkString)
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				networkString = pkg.prefix .. networkString
			end
		end
		return networkStrings[lower(networkString)] > 0
	end
end
net.Start = function(networkString)
	local fenv = getfenv(2)
	if fenv then
		local pkg = fenv.__package
		if pkg then
			networkString = pkg.prefix .. networkString
		end
	end
	Start(lower(networkString))
	return nil
end
-- Network string callback registration
do
	local remove
	do
		local _obj_0 = environment.table
		remove = _obj_0.remove
	end
	local external = rawget(net, "Receivers")
	if not istable(external) then
		external = { }
		net.Receivers = external
	end
	local length = 0
	net.Receive = function(networkString, func, identifier)
		networkString = lower(networkString)
		if not isstring(identifier) then
			identifier = "unknown"
		end
		local networks = external
		local fenv = getfenv(2)
		if fenv then
			local pkg = fenv.__package
			if pkg then
				local prefix = pkg.prefix
				identifier = prefix .. identifier
				networkString = prefix .. networkString
				networks = pkg.__networks
				if not networks then
					networks = { }
					pkg.__networks = networks
				end
			end
		end
		local functions = networks[networkString]
		if not functions then
			functions = { }
			external[networkString] = functions
		end
		length = #functions
		for index = 1, length do
			if functions[index][1] == identifier then
				remove(functions, index)
				length = length - 1
				break
			end
		end
		functions[length + 1] = {
			[1] = identifier,
			[2] = func
		}
	end
	-- Network string callback performing
	local NetworkIDToString = util.NetworkIDToString
	local ReadHeader = net.ReadHeader
	local Run
	do
		local _obj_0 = _G.hook
		Run = _obj_0.Run
	end
	local gmod_receivers = gmod_net.Receivers
	gmod_net.Incoming = function(length, client)
		if length == nil then
			length = 16
		end
		if client == nil then
			client = NULL
		end
		local networkString = NetworkIDToString(ReadHeader())
		if networkString == nil then
			return nil
		end
		networkString = lower(networkString)
		length = length - 16
		if Run("IncomingNetworkMessage", networkString, length, client) == false then
			return nil
		end
		local func = gmod_receivers[networkString]
		if func then
			xpcall(func, ErrorNoHaltWithStack, length, client)
		end
		local functions = external[networkString]
		if functions then
			for _index_0 = 1, #functions do
				local data = functions[_index_0]
				xpcall(data[2], ErrorNoHaltWithStack, length, client)
			end
		end
		return nil
	end
end
-- Boolean
do
	local ReadBit, WriteBit = gmod_net.ReadBit, gmod_net.WriteBit
	local read
	read = function()
		return ReadBit() == 1
	end
	-- bool must be an alias of bit ( because yeah... )
	net.ReadBool, net.WriteBool = read, WriteBit
	net.ReadBit = read
	types[environment.TYPE_BOOL] = {
		read,
		WriteBit
	}
end
-- Entity
do
	local write
	write = function(entity)
		if entity and IsValid(entity) then
			WriteUInt(EntIndex(entity), 16)
			return entity
		end
		WriteUInt(0, 16)
		return entity
	end
	local read
	read = function()
		local index = ReadUInt(16)
		if index == nil or index == 0 then
			return NULL
		end
		return Entity(index)
	end
	net.ReadEntity, net.WriteEntity = read, write
	types[environment.TYPE_ENTITY] = {
		read,
		write
	}
end
-- Player
do
	local maxplayers_bits = util.BitCount(_G.game.MaxPlayers())
	net.ReadPlayer = function()
		local index = ReadUInt(maxplayers_bits)
		if index == nil or index == 0 then
			return NULL
		end
		return Entity(index)
	end
	net.WritePlayer = function(ply)
		if ply and IsValid(ply) and ply:IsPlayer() then
			WriteUInt(EntIndex(ply), maxplayers_bits)
			return ply
		end
		WriteUInt(0, maxplayers_bits)
		return ply
	end
end
-- Color
do
	local metatable = FindMetaTable("Color")
	local read
	read = function(readAlpha)
		if readAlpha == false then
			local r, g, b = byte(ReadData(3), 1, 3)
			return setmetatable({
				r = r,
				g = g,
				b = b,
				a = 255
			}, metatable)
		end
		local r, g, b, a = byte(ReadData(4), 1, 4)
		return setmetatable({
			r = r,
			g = g,
			b = b,
			a = a
		}, metatable)
	end
	local write
	write = function(color, writeAlpha)
		if writeAlpha == false then
			WriteData(char(color.r or 255, color.g or 255, color.b or 255))
			return color
		end
		WriteData(char(color.r or 255, color.g or 255, color.b or 255, color.a or 255))
		return color
	end
	net.ReadColor, net.WriteColor = read, write
	types[environment.TYPE_COLOR] = {
		read,
		write
	}
end
do
	local BytesLeft = gmod_net.BytesLeft
	local readAll
	readAll = function()
		return ReadData(BytesLeft(), nil)
	end
	net.ReadAll = readAll
end
-- Table
do
	local ReadType, WriteType = net.ReadType, net.WriteType
	local read
	read = function(isSequential)
		local result = { }
		if isSequential then
			for index = 1, ReadUInt(32) do
				result[index] = ReadType()
			end
			return result
		end
		::read::
		local key = ReadType()
		if key == nil then
			return result
		end
		result[key] = ReadType()
		goto read
		return result
	end
	local length = 0
	local write
	write = function(tbl, isSequential)
		if isSequential then
			length = #tbl
			WriteUInt(length, 32)
			for index = 1, length do
				WriteType(tbl[index])
			end
			return tbl, length
		end
		length = 0
		for key, value in pairs(tbl) do
			WriteType(key)
			WriteType(value)
			length = length + 1
		end
		WriteUInt(0, 16)
		return tbl, length
	end
	net.ReadTable, net.WriteTable = read, write
	types[environment.TYPE_TABLE] = {
		read,
		write
	}
end
-- SteamID
do
	local SteamID = util.SteamID
	net.ReadSteamID = function(withUniverse)
		return SteamID.FromBinary(ReadData(withUniverse and 5 or 4), false, withUniverse)
	end
	net.WriteSteamID = function(steamID, withUniverse)
		if isstring(steamID) then
			steamID = SteamID(steamID)
		end
		argument(steamID, 1, "SteamID")
		return WriteData(steamID:ToBinary(withUniverse))
	end
end
-- Date
do
	local Date = util.Date
	net.ReadDate = function()
		return Date.FromBinary(ReadData(12))
	end
	net.WriteDate = function(date)
		if isstring(date) then
			date = Date(date)
		end
		argument(date, 1, "Date")
		return WriteData(date:ToBinary())
	end
end
-- Time
do
	local dos2unix, unix2dos
	do
		local _obj_0 = environment.os
		dos2unix, unix2dos = _obj_0.dos2unix, _obj_0.unix2dos
	end
	net.ReadTime = function()
		return dos2unix(ReadUInt(16), ReadUInt(16))
	end
	net.WriteTime = function(u)
		local t, d = unix2dos(u)
		WriteUInt(t, 16)
		return WriteUInt(d, 16)
	end
end
net.ReadByte = function()
	return ReadUInt(8)
end
net.WriteByte = function(number)
	WriteUInt(number, 8)
	return nil
end
net.ReadUShort = function()
	return ReadUInt(16)
end
net.WriteUShort = function(number)
	WriteUInt(number, 16)
	return nil
end
net.ReadULong = function()
	return ReadUInt(32)
end
net.WriteULong = function(number)
	WriteUInt(number, 32)
	return nil
end
do
	local ReadInt, WriteInt = gmod_net.ReadInt, gmod_net.WriteInt
	net.ReadSignedByte = function()
		return ReadInt(8)
	end
	net.WriteSignedByte = function(number)
		WriteInt(number, 8)
		return nil
	end
	net.ReadShort = function()
		return ReadInt(16)
	end
	net.WriteShort = function(number)
		WriteInt(number, 16)
		return nil
	end
	net.ReadLong = function()
		return ReadInt(32)
	end
	net.WriteLong = function(number)
		WriteInt(number, 32)
		return nil
	end
end

local _G = _G
local error = _G.error
local environment
do
	local _obj_0 = _G.gpm
	environment = _obj_0.environment
end
local string, math, table, tonumber, assert, argument, isstring, isnumber, type = environment.string, environment.math, environment.table, environment.tonumber, environment.assert, environment.argument, environment.isstring, environment.isnumber, environment.type
local char, byte, len, sub, format, match, find, rep = string.char, string.byte, string.len, string.sub, string.format, string.match, string.find, string.rep
local trunc, floor, min, max, pow2, mod2 = math.trunc, math.floor, math.min, math.max, math.pow2, math.mod2
local concat, unpack = table.concat, table.unpack
local classExtend = environment.extend
local registry = { }
local _module_0 = {
	registry = registry
}
-- https://github.com/ToxicFrog/vstruct/blob/master/cursor.lua
do
	local base = {
		__tostring = function(self)
			return format("Cursor: %p [%d/%d]", self, self.pointer, self.size)
		end,
		new = function(self, data)
			if data == nil then
				data = ""
			end
			self.data = data
			assert(isstring(data), "data must be a string")
			self.size = len(data)
			self.buffer_size = 0
			self.pointer = 0
			self.buffer = { }
			return nil
		end,
		Flush = function(self)
			local buffer_size = self.buffer_size
			if buffer_size == 0 then
				return self.data
			end
			local data, pointer, size = self.data, self.pointer, self.size
			if pointer > size then
				data = data .. rep("\0", pointer - size)
				size = len(data)
			end
			local content = concat(self.buffer, "", 1, buffer_size)
			self.buffer_size = 0
			self.buffer = { }
			buffer_size = len(content)
			data = sub(data, 1, pointer) .. content .. sub(data, pointer + buffer_size + 1, size)
			self.data, self.size = data, len(data)
			self.pointer = pointer + buffer_size
			return data
		end,
		Seek = function(self, whence, offset)
			if whence == nil then
				whence = "cur"
			end
			if offset == nil then
				offset = 0
			end
			self:Flush()
			local pointer, size = self.pointer, self.size
			if "cur" == whence then
				pointer = pointer + offset
			elseif "end" == whence then
				pointer = size + offset
			elseif "set" == whence then
				pointer = offset
			else
				error("bad argument #1 to 'Seek' (invalid option)", 2)
				return nil
			end
			pointer = min(max(pointer, 0), size)
			self.pointer = pointer
			return pointer
		end,
		Write = function(self, str)
			local buffer_size = self.buffer_size + 1
			self.buffer[buffer_size] = str
			self.buffer_size = buffer_size
			return nil
		end,
		Read = function(self, length)
			if length == nil then
				length = 1
			end
			self:Flush()
			local pointer, size = self.pointer, self.size
			if pointer > size then
				return nil, "eof"
			end
			if length == "*a" then
				length = size
			end
			self.pointer = min(pointer + length, size)
			return sub(self.data, pointer + 1, pointer + length)
		end
	}
	_module_0.Cursor = environment.class("Cursor", base)
	_module_0.IsCursor = function(any)
		return getmetatable(any) == base
	end
end
-- https://github.com/ToxicFrog/vstruct/blob/master/init.lua
local explode
explode = function(number, size)
	if size == nil then
		size = 0
	end
	local mask, length = { }, 0
	while number ~= 0 or length < size do
		length = length + 1
		mask[length] = mod2[number] ~= 0
		number = trunc(number / 2)
	end
	return mask
end
_module_0.explode = explode
local implode
implode = function(mask, size, offset)
	size = size or #mask
	local byte0 = 0
	if offset then
		for index = size, 1, -1 do
			byte0 = byte0 * 2 + (mask[index + offset] and 1 or 0)
		end
		return byte0
	end
	for index = size, 1, -1 do
		byte0 = byte0 * 2 + (mask[index] and 1 or 0)
	end
	return byte0
end
_module_0.implode = implode
-- https://github.com/ToxicFrog/vstruct/blob/master/io.lua
local io = { }
_module_0.io = io
local endianness
do
	local isint, isuint = math.isint, math.isuint
	local registerIO, defaultTypeSize, defaultSize
	do
		defaultTypeSize = function(number)
			assert(number, "format requires a size")
			return tonumber(number, 10)
		end
		defaultSize = function(str)
			assert(str, "format requires a size")
			return nil
		end
		local defaultValidate
		defaultValidate = function()
			return true
		end
		local _base_0 = {
			__index = {
				Size = defaultSize,
				Validate = defaultValidate,
				HasValue = function()
					return false
				end
			}
		}
		local _base_1 = {
			__index = {
				Size = defaultTypeSize,
				Validate = defaultValidate,
				HasValue = function()
					return true
				end
			}
		}
		registerIO = function(name, tbl, isType)
			io[name] = setmetatable(tbl, isType and _base_1 or _base_0)
		end
		_module_0.RegisterIO = registerIO
	end
	local setAlias
	setAlias = function(name, symbol)
		io[symbol] = io[name]
	end
	_module_0.SetIOAlias = setAlias
	do
		local read
		read = function(fileDescriptor, _, offset)
			assert(fileDescriptor:Seek("cur", offset))
			return nil
		end
		registerIO("+", {
			Read = read,
			Write = read
		})
	end
	do
		local read
		read = function(fileDescriptor, _, offset)
			assert(fileDescriptor:Seek("cur", -offset))
			return nil
		end
		registerIO("-", {
			Read = read,
			Write = read
		})
	end
	do
		local read
		read = function(fileDescriptor, _, offset)
			assert(fileDescriptor:Seek("set", offset))
			return nil
		end
		registerIO("@", {
			Read = read,
			Write = read
		})
	end
	do
		local value
		local big
		big = function()
			value = "big"
			endianness.value = value
			return value
		end
		local little
		little = function()
			value = "little"
			endianness.value = value
			return value
		end
		local isBig = byte(string.dump(environment.debug.fempty), 7) == 0x00
		local host
		host = function()
			if isBig then
				return big()
			end
			return little()
		end
		endianness = {
			value = nil,
			Big = big,
			Little = little,
			Size = defaultTypeSize,
			Host = host,
			Get = function()
				return value
			end,
			Set = function(str)
				if "big" == str then
					return big()
				elseif "little" == str then
					return little()
				else
					return host()
				end
			end
		}
		registerIO("endianness", endianness)
	end
	-- https://github.com/ToxicFrog/vstruct/blob/master/io.lua
	do
		-- big-endian
		do
			local Big = endianness.Big
			local read
			read = function()
				Big()
				return nil
			end
			registerIO(">", {
				Size = function(number)
					assert(number == nil, "'>' is an endianness control, and does not have size")
					return 0
				end,
				Read = read,
				Write = read
			})
		end
		-- little-endian
		do
			local Little = endianness.Little
			local read
			read = function()
				Little()
				return nil
			end
			registerIO("<", {
				Size = function(number)
					assert(number == nil, "'<' is an endianness control, and does not have size")
					return 0
				end,
				Read = read,
				Write = read
			})
		end
		-- host
		do
			local Host = endianness.Host
			local read
			read = function()
				Host()
				return nil
			end
			registerIO("=", {
				Size = function(number)
					assert(number == nil, "'=' is an endianness control, and does not have size")
					return 0
				end,
				Read = read,
				Write = read
			})
		end
	end
	-- https://github.com/ToxicFrog/vstruct/blob/master/io/a.lua
	-- align-to
	do
		local read
		read = function(fileDescriptor, _, align)
			local mod = fileDescriptor.pointer % align
			if mod ~= 0 then
				fileDescriptor:Seek("cur", align - mod)
			end
			return nil
		end
		registerIO("a", {
			Read = read,
			Write = read
		})
	end
	local readUInt, writeUInt, readUIntBits, writeUIntBits
	do
		-- https://github.com/ToxicFrog/vstruct/blob/master/io/u.lua
		-- unsigned ints
		readUInt = function(_, binary, bytes)
			if bytes == nil then
				bytes = 4
			end
			local number = 0
			if endianness.value == "big" then
				for index = 1, bytes, 1 do
					number = number * 0x100 + byte(binary, index, index)
				end
				return number
			end
			for index = bytes, 1, -1 do
				number = number * 0x100 + byte(binary, index, index)
			end
			return number
		end
		writeUInt = function(_, number, bytes)
			if bytes == nil then
				bytes = 4
			end
			assert(number >= 0 and number < pow2[bytes * 8], "unsigned integer overflow")
			number = trunc(number)
			local buffer = { }
			if endianness.value == "big" then
				for index = bytes, 1, -1 do
					buffer[index] = char(number % 0x100)
					number = trunc(number * 0.00390625)
				end
				return concat(buffer, "", 1, bytes)
			end
			for index = 1, bytes, 1 do
				buffer[index] = char(number % 0x100)
				number = trunc(number * 0.00390625)
			end
			return concat(buffer, "", 1, bytes)
		end
		readUIntBits = function(readBit, count)
			local bits = 0
			for _ = 1, (count or 4) do
				bits = bits * 2 + readBit()
			end
			return bits
		end
		writeUIntBits = function(writeBit, data, count)
			for index = (count or 4) - 1, 0, -1 do
				writeBit(mod2[floor(data / pow2[index])])
			end
		end
		local size
		size = function(number)
			if number == nil then
				number = 4
			end
			assert(isnumber(number), "unsigned integer size must be a number")
			return number
		end
		registerIO("I", {
			Size = size,
			Read = readUInt,
			ReadBits = readUIntBits,
			Write = writeUInt,
			WriteBits = writeUIntBits
		}, true)
		setAlias("I", "u")
		registerIO("H", {
			Size = function()
				return 2
			end,
			Read = function(_, binary)
				return readUInt(nil, binary, 2)
			end,
			Write = function(_, number)
				return writeUInt(nil, number, 2)
			end,
			ReadBits = function(readBit)
				return readUIntBits(readBit, 2)
			end,
			WriteBits = function(writeBit, number)
				return writeUIntBits(writeBit, number, 2)
			end
		}, true)
		local readInt
		readInt = function(_, binary, bytes)
			if bytes == nil then
				bytes = 4
			end
			local number = readUInt(nil, binary, bytes)
			if number < pow2[bytes * 8 - 1] then
				return number
			end
			return number - pow2[bytes * 8]
		end
		local writeInt
		writeInt = function(_, number, bytes)
			if bytes == nil then
				bytes = 4
			end
			local limit = pow2[bytes * 8 - 1]
			assert(number >= -limit and number < limit, "signed integer overflow")
			number = trunc(number)
			if number < 0 then
				number = number + pow2[bytes * 8]
			end
			return writeUInt(nil, number, bytes)
		end
		local readIntBits
		readIntBits = function(readBit, count)
			if count == nil then
				count = 4
			end
			local number = readUIntBits(readBit, count)
			if number < pow2[count - 1] then
				return number
			end
			return number - pow2[count]
		end
		local writeIntBits
		writeIntBits = function(writeBit, number, count)
			if count == nil then
				count = 4
			end
			if number < 0 then
				number = number + pow2[count]
			end
			return writeUIntBits(writeBit, number, count)
		end
		-- https://github.com/ToxicFrog/vstruct/blob/master/io/i.lua
		-- signed integers
		registerIO("i", {
			Size = size,
			Read = readInt,
			ReadBits = readIntBits,
			Write = writeInt,
			WriteBits = writeIntBits
		}, true)
		registerIO("h", {
			Size = function()
				return 2
			end,
			Read = function(_, binary)
				return readInt(nil, binary, 2)
			end,
			Write = function(_, number)
				return writeInt(nil, number, 2)
			end,
			ReadBits = function(readBit)
				return readIntBits(readBit, 2)
			end,
			WriteBits = function(writeBit, data)
				return writeIntBits(writeBit, data, 2)
			end
		}, true)
		registerIO("T", {
			Size = function()
				return 4
			end,
			Read = function(_, binary)
				return readUInt(nil, binary, 4)
			end,
			Write = function(_, number)
				return writeUInt(nil, number, 4)
			end,
			ReadBits = function(readBit)
				return readUIntBits(readBit, 4)
			end,
			WriteBits = function(writeBit, data)
				return writeUIntBits(writeBit, data, 4)
			end
		}, true)
		registerIO("l", {
			Size = function()
				return 8
			end,
			Read = function(_, binary)
				return readInt(nil, binary, 8)
			end,
			Write = function(_, number)
				return writeInt(nil, number, 8)
			end,
			ReadBits = function(readBit)
				return readIntBits(readBit, 8)
			end,
			WriteBits = function(writeBit, data)
				return writeIntBits(writeBit, data, 8)
			end
		}, true)
		setAlias("l", "j")
		registerIO("L", {
			Size = function()
				return 8
			end,
			Read = function(_, binary)
				return readUInt(nil, binary, 8)
			end,
			Write = function(_, number)
				return writeUInt(nil, number, 8)
			end,
			ReadBits = function(readBit)
				return readUIntBits(readBit, 8)
			end,
			WriteBits = function(writeBit, data)
				return writeUIntBits(writeBit, data, 8)
			end
		}, true)
		setAlias("L", "J")
		-- https://github.com/ToxicFrog/vstruct/blob/master/io/p.lua
		-- signed fixed point
		-- format is pTOTAL_SIZE,FRACTIONAL_SIZE
		-- Fractional size is in bits, total size in bytes.
		registerIO("p", {
			Size = function(count, fraction)
				assert(count, "format requires a bit count")
				assert(fraction, "format requires a fractional-part size")
				if tonumber(count, 10) and tonumber(fraction, 10) then
					-- Check only possible if both values were specified at compile time
					assert(count * 8 >= fraction, "fixed point number has more fractional bits than total bits")
				end
				return count
			end,
			Read = function(_, binary, count, fraction)
				return readInt(nil, binary, count) / pow2[fraction]
			end,
			Write = function(_, number, count, fraction)
				return writeInt(nil, number * pow2[fraction], count)
			end
		}, true)
		-- https://github.com/ToxicFrog/vstruct/blob/master/io/pu.lua
		-- signed fixed point
		-- format is pTOTAL_SIZE,FRACTIONAL_SIZE
		-- Fractional size is in bits, total size in bytes.
		registerIO("pu", {
			Size = function(count, fraction)
				assert(count, "format requires a bit count")
				assert(fraction, "format requires a fractional-part size")
				if tonumber(count, 10) and tonumber(fraction, 10) then
					-- Check only possible if both values were specified at compile time
					assert(count * 8 >= fraction, "fixed point number has more fractional bits than total bits")
				end
				return count
			end,
			Read = function(_, binary, count, fraction)
				return readUInt(nil, binary, count) / pow2[fraction]
			end,
			Write = function(_, number, count, fraction)
				return writeUInt(nil, number * pow2[fraction], count)
			end
		}, true)
	end
	-- signed byte
	registerIO("b", {
		Size = function()
			return 1
		end,
		Read = function(_, str)
			return byte(str, 1, 1) - 0x80
		end,
		Write = function(_, number)
			assert(isint(number), "signed byte must be an integer")
			assert(number > -129 and number < 128, "signed byte overflow")
			return char(number + 0x80)
		end,
		ReadBits = function(readBit, size)
			return readUIntBits(readBit, size) - (pow2[size] * 0.5)
		end,
		WriteBits = function(writeBit, data, size)
			return writeUIntBits(writeBit, data + (pow2[size] * 0.5), size)
		end
	}, true)
	-- unsigned byte
	registerIO("B", {
		Size = function()
			return 1
		end,
		Read = function(_, str)
			return byte(str, 1, 1)
		end,
		Write = function(_, number)
			assert(isuint(number), "unsigned byte must be an unsigned integer")
			assert(number > 0 and number < 256, "unsigned byte overflow")
			return char(number)
		end,
		ReadBits = readUIntBits,
		WriteBits = writeUIntBits
	}, true)
	-- https://github.com/ToxicFrog/vstruct/blob/master/io/b.lua
	-- boolean
	registerIO("o", {
		Read = function(_, buffer)
			return match(buffer, "%Z") and true or false
		end,
		ReadBits = function(readBit, size)
			local number = 0
			for _ = 1, size do
				number = number + readBit()
			end
			return number > 0
		end,
		Write = function(_, data, size)
			return writeUInt(nil, data and 1 or 0, size)
		end,
		WriteBits = function(writeBit, data, size)
			for _ = 1, size do
				writeBit(data and 1 or 0)
			end
		end
	}, true)
	-- https://github.com/ToxicFrog/vstruct/blob/master/io/s.lua
	-- fixed length strings
	local writeString
	writeString = function(_, data, size)
		local length = len(data)
		size = size or length
		if size > length then
			data = data .. rep("\0", size - length)
		end
		return sub(data, 1, size)
	end
	local readString
	do
		readString = function(fileDescriptor, binary, size)
			if binary then
				assert(len(binary) == size, "length of buffer does not match length of string format")
				return binary
			end
			return fileDescriptor:Read(size or "*a")
		end
		registerIO("c", {
			Size = defaultSize,
			Read = readString,
			Write = writeString
		}, true)
		-- https://github.com/ToxicFrog/vstruct/blob/master/io/x.lua
		-- skip/pad
		do
			registerIO("x", {
				Read = function(fileDescriptor, binary, size)
					readString(fileDescriptor, binary, size)
					return nil
				end,
				ReadBits = function(readBit, size)
					for _ = 1, size do
						readBit()
					end
				end,
				Write = function(fileDescriptor, data, size, value)
					return rep(char(value or 0), size)
				end,
				WriteBits = function(writeBit, _, size, value)
					if value == nil then
						value = 0
					end
					assert(value == 0 or value == 1, "value must be 0 or 1")
					for _ = 1, size do
						writeBit(value)
					end
				end
			})
		end
	end
	-- https://github.com/ToxicFrog/vstruct/blob/master/io/c.lua
	-- counted strings
	registerIO("s", {
		Size = function(size)
			if size then
				assert(isnumber(size), "size must be a number")
				assert(size ~= 0, "size must be greater than 0")
			end
			return nil
		end,
		Read = function(fileDescriptor, _, size)
			if size == nil then
				size = 1
			end
			-- assert( size, "size is required for counted strings" )
			local length = readUInt(nil, fileDescriptor:Read(size), size)
			if length == 0 then
				return ""
			end
			return fileDescriptor:Read(length)
		end,
		Write = function(_, data, size)
			return writeUInt(nil, len(data), size or 1) .. writeString(nil, data)
		end
	}, true)
	registerIO("z", {
		Size = function(size)
			return tonumber(size, 10)
		end,
		Read = function(fileDescriptor, str, size, csize)
			if csize == nil then
				csize = 1
			end
			local null = rep("\0", csize)
			-- read exactly that many characters, then strip the null termination
			if size then
				str = readString(fileDescriptor, str, size)
				local length = 0
				repeat
					length = find(str, null, length + 1, true)
				until length == nil or ((length - 1) % csize) == 0
				return sub(str, 1, (length or 0) - 1)
			end
			-- this is where it gets ugly: the size wasn't specified, so we need to
			-- read (csize) bytes at a time looking for the null terminator
			local chars, length = { }, 0
			local c = fileDescriptor:Read(csize)
			while c and c ~= null do
				length = length + 1
				chars[length] = c
				c = fileDescriptor:Read(csize)
			end
			return concat(chars, "", 1, length)
		end,
		White = function(_, str, size, csize)
			if csize == nil then
				csize = 1
			end
			size = size or len(str) + csize
			assert((size % csize) == 0, "string length is not a multiple of character size")
			-- truncate to field size
			if len(str) >= size then
				str = sub(str, 1, size - csize)
			end
			return writeString(nil, str .. rep("\0", csize), size)
		end
	}, true)
	-- https://github.com/ToxicFrog/vstruct/blob/master/io/m.lua
	-- bitmasks
	local readBitmask
	readBitmask = function(_, binary, size)
		size = size or len(binary)
		local mask, length = { }, 0
		if endianness.value == "big" then
			for index = size, 1, -1 do
				local byte0 = byte(binary, index, index)
				for num = 1, 8 do
					length = length + 1
					mask[length] = mod2[byte0] == 1
					byte0 = floor(byte0 / 2)
				end
			end
			return mask
		end
		for index = 1, size, 1 do
			local byte0 = byte(binary, index, index)
			for num = 1, 8 do
				length = length + 1
				mask[length] = mod2[byte0] == 1
				byte0 = floor(byte0 / 2)
			end
		end
		return mask
	end
	local writeBitmask
	writeBitmask = function(_, bits, size)
		local buffer, length = { }, 0
		if endianness.value == "big" then
			for index = size * 8, 1, -8 do
				length = length + 1
				buffer[length] = implode(bits, 8, index - 1)
			end
			return writeString(nil, char(unpack(buffer, 1, length)), size)
		end
		for index = 1, size * 8, 8 do
			length = length + 1
			buffer[length] = implode(bits, 8, index - 1)
		end
		return writeString(nil, char(unpack(buffer, 1, length)), size)
	end
	registerIO("m", {
		Read = readBitmask,
		ReadBits = function(readBit, size)
			local mask = { }
			for index = 1, size do
				mask[index] = readBit() == 1
			end
			return mask
		end,
		Write = writeBitmask,
		WriteBits = function(writeBit, data, size)
			for index = 1, size do
				writeBit(data[index] and 1 or 0)
			end
		end
	}, true)
	-- https://github.com/ToxicFrog/vstruct/blob/master/io/f.lua
	-- IEEE floating point floats, doubles and quads
	do
		local inf, nan, isnegative, frexp, ldexp = math.inf, math.nan, math.isnegative, math.frexp, math.ldexp
		-- float
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
			registerIO("f", {
				Size = function()
					return 4
				end,
				Read = function(_, binary)
					local bits = readBitmask(nil, binary, 4)
					local fraction = implode(bits, 23)
					local exponent = implode(bits, 8, 23)
					local sign = bits[32] and -1 or 1
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
				end,
				Write = function(_, float)
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
					return writeBitmask(nil, bits, 4)
				end
			}, true)
		end
		-- double
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
			registerIO("d", {
				Size = function()
					return 8
				end,
				Read = function(_, binary)
					local bits = readBitmask(nil, binary, 8)
					local fraction = implode(bits, 52)
					local exponent = implode(bits, 11, 52)
					local sign = bits[64] and -1 or 1
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
				end,
				Write = function(_, double)
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
					return writeBitmask(nil, bits, 8)
				end
			}, true)
			setAlias("d", "n")
		end
		-- quad
		do
			-- constants
			local c0 = pow2[14]
			local c1 = pow2[15] - 1
			local c2 = pow2[111]
			local c3 = pow2[112]
			local c4 = 1 - 112 - c0
			local bias = c0 - 1
			local c5 = bias + 1
			local c6 = pow2[113]
			registerIO("q", {
				Size = function()
					return 16
				end,
				Read = function(_, binary)
					local bits = readBitmask(nil, binary, 16)
					local fraction = implode(bits, 112)
					local exponent = implode(bits, 15, 112)
					local sign = bits[128] and -1 or 1
					if exponent == c1 then
						if fraction == 0 or sign == -1 then
							return sign * inf
						end
						return nan
					end
					if exponent ~= 0 then
						fraction = fraction + c3
					else
						exponent = 1
					end
					return sign * ldexp(fraction, exponent + c4)
				end,
				Write = function(_, quad)
					local sign
					if isnegative(quad) then
						sign = true
						quad = -quad
					else
						sign = false
					end
					local exponent, fraction
					if quad == inf then
						exponent = c5
						fraction = 0
					elseif quad ~= quad then
						exponent = c5
						fraction = c2
					elseif quad == 0 then
						exponent = -bias
						fraction = 0
					else
						fraction, exponent = frexp(quad)
						local ebs = exponent + bias
						if ebs <= 1 then
							fraction = fraction * pow2[111 + ebs]
							exponent = -bias
						else
							fraction = fraction - 0.5
							exponent = exponent - 1
							fraction = fraction * c6
						end
					end
					local bits = explode(fraction)
					local exponentBits = explode(exponent + bias)
					for index = 1, 15 do
						bits[112 + index] = exponentBits[index]
					end
					bits[128] = sign
					return writeBitmask(nil, bits, 16)
				end
			}, true)
		end
	end
end
-- https://github.com/ToxicFrog/vstruct/blob/master/lexer.lua
do
	local lexis, length = { }, 0
	local addLexer
	addLexer = function(name, pattern)
		length = length + 1
		lexis[length] = {
			name = name,
			pattern = "^" .. pattern
		}
	end
	_module_0.AddLexer = addLexer
	addLexer(false, "%s+")
	addLexer(false, "%-%-[^\n]*")
	addLexer("key", "([%a_][%w_.]*):")
	addLexer("io", "([-+@<>=])")
	addLexer("io", "([%a_]+)")
	addLexer("number", "([%d.,]+)")
	addLexer("number", "(#[%a_][%w_.]*)")
	addLexer("splice", "&(%S+)")
	addLexer("{", "%{")
	addLexer("}", "%}")
	addLexer("(", "%(")
	addLexer(")", "%)")
	addLexer("*", "%*")
	addLexer("[", "%[")
	addLexer("]", "%]")
	addLexer("|", "%|")
	_module_0.lexer = function(source)
		local index, hadWhitespace = 1, false
		local where
		where = function()
			return format("character %d ('%s')", index, sub(source, 1, 4))
		end
		local find_match
		find_match = function()
			for j = 1, length do
				local data = lexis[j]
				if match(source, data.pattern) then
					local _, endPos, text = find(source, data.pattern)
					return data, endPos, text
				end
			end
			error(format("Lexical error in format string at %s.", where()))
			return nil
		end
		local eat_whitespace
		eat_whitespace = function()
			local aux
			aux = function()
				if #source == 0 then
					return nil
				end
				local matched, size = find_match()
				if matched.name then
					return nil
				end
				source = sub(source, size + 1, len(source))
				hadWhitespace = true
				index = index + size
				return aux()
			end
			hadWhitespace = false
			return aux()
		end
		local whitespace
		whitespace = function()
			return hadWhitespace
		end
		local next
		next = function()
			eat_whitespace()
			if #source == 0 then
				return {
					text = nil,
					type = "EOF"
				}
			end
			local data, size, text = find_match()
			source = sub(source, size + 1, len(source))
			index = index + size
			return {
				text = text,
				type = data.name
			}
		end
		local peek
		peek = function()
			eat_whitespace()
			if #source == 0 then
				return {
					text = nil,
					type = "EOF"
				}
			end
			local data, _, text = find_match()
			return {
				text = text,
				type = data.name
			}
		end
		return {
			next = next,
			peek = peek,
			where = where,
			whitespace = whitespace,
			tokens = function()
				return next
			end
		}
	end
end
-- https://github.com/ToxicFrog/vstruct/blob/master/ast.lua
local ast = { }
_module_0.ast = ast
do
	local gmatch = string.gmatch
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/Node.lua
	local nodeClass = environment.class("Node", {
		new = function(self)
			self.size = 0
		end,
		Append = function(self, node)
			self[#self + 1] = node
			self.size = self.size + (node.size or 0)
		end,
		Read = function(self, fileDescriptor, data)
			for _index_0 = 1, #self do
				local child = self[_index_0]
				child:Read(fileDescriptor, data)
			end
		end,
		ReadBits = function(self, bits, data)
			for _index_0 = 1, #self do
				local child = self[_index_0]
				child:ReadBits(bits, data)
			end
		end,
		Write = function(self, fileDescriptor, context)
			for _index_0 = 1, #self do
				local child = self[_index_0]
				child:Write(fileDescriptor, context)
			end
		end,
		WriteBits = function(self, bits, context)
			for _index_0 = 1, #self do
				local child = self[_index_0]
				child:WriteBits(bits, context)
			end
		end
	})
	ast.Node = nodeClass
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/List.lua
	local listClass = classExtend(nodeClass, "List")
	ast.List = listClass
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/Table.lua
	local tableClass
	do
		local Read, ReadBits = nodeClass.Read, nodeClass.ReadBits
		tableClass = classExtend(nodeClass, "Table", {
			Read = function(self, fileDescriptor)
				local tbl = { }
				Read(self, fileDescriptor, tbl)
				return tbl
			end,
			ReadBits = function(self, bits)
				local tbl = { }
				ReadBits(self, bits, tbl)
				return tbl
			end
		})
		ast.Table = tableClass
	end
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/Number.lua
	-- A node that holds either a number, or a reference to an already-read, named field which contains a number.
	local numberClass
	do
		numberClass = classExtend(nodeClass, "Number", {
			new = function(self, text)
				if match(text, "^#") then
					self.key = sub(text, 2, len(text))
				else
					self.value = assert(tonumber(text, 10), "numeric constant '" .. text .. "' is not a number")
				end
			end,
			Get = function(self, data)
				local value = self.value
				if value then
					return value
				end
				if data then
					local key = self.key
					for name in gmatch(key, "([^%.]+)%.") do
						if data[name] == nil then
							break
						end
						data = data[name]
					end
					value = data[match(key, "[^%.]+$")]
					assert(value ~= nil, "backreferenced field '" .. key .. "' has not been read yet")
					assert(isnumber(value), "backreferenced field '" .. key .. "' is not a numeric type")
					return value
				end
				return true
			end
		})
	end
	ast.Number = numberClass
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/Root.lua
	local rootClass
	do
		local Host = endianness.Host
		rootClass = classExtend(nodeClass, "Root", {
			new = function(self, children)
				self[1] = children
				self.size = children.size
			end,
			Read = function(self, fileDescriptor, data)
				Host()
				self[1]:Read(fileDescriptor, data)
				return data
			end,
			Write = function(self, fileDescriptor, data)
				Host()
				self[1]:Write(fileDescriptor, {
					data = data,
					n = 1
				})
				return nil
			end
		})
	end
	ast.Root = rootClass
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/Repeat.lua
	local repeatClass = classExtend(nodeClass, "Repeat", {
		new = function(self, count, child)
			self.count = count
			self.child = child
			if count.value and child.size then
				self.size = count:Get(nil) * child.size
			else
				-- Child has runtime-deferred size, or count is a backreference
				self.size = nil
			end
		end,
		Read = function(self, fileDescriptor, data)
			local child = self.child
			for _ = 1, self.count:Get(data) do
				child:Read(fileDescriptor, data)
			end
		end,
		ReadBits = function(self, bits, data)
			local child = self.child
			for _ = 1, self.count:Get(data) do
				child:ReadBits(bits, data)
			end
		end,
		Write = function(self, fileDescriptor, data)
			local child = self.child
			for _ = 1, self.count:Get(data.data) do
				child:Write(fileDescriptor, data)
			end
		end,
		WriteBits = function(self, bits, data)
			local child = self.child
			for _ = 1, self.count:Get(data.data) do
				child:WriteBits(bits, data)
			end
		end
	})
	ast.Repeat = repeatClass
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/Name.lua
	local nameClass
	do
		local tostring = environment.tostring
		local put
		put = function(data, key, value)
			if key then
				for name in gmatch(key, "([^%.]+)%.") do
					data = data[name]
					if data == nil then
						data = { }
					end
				end
				data[match(key, "[^%.]+$")] = value
				return nil
			end
			data[#data + 1] = value
		end
		-- Return a new subcontext containing only the data referenced by the key.
		-- `parent` points to the parent context, so that backreferences can be resolved.
		local get
		get = function(context, key)
			local value
			if key then
				local data = context.data
				for name in gmatch(key, "([^%.]+)%.") do
					if data[name] == nil then
						break
					end
					data = data[name]
				end
				value = data[match(key, "[^%.]+$")]
			else
				local n = context.n
				value = context.data[n]
				context.n = n + 1
			end
			assert(value ~= nil, "bad input while writing: no value for key " .. tostring(key or context.n - 1))
			return {
				parent = context,
				data = value,
				n = 1
			}
		end
		nameClass = classExtend(nodeClass, "Name", {
			new = function(self, key, child)
				self.key = key
				self.child = child
				self.size = child.size
			end,
			Read = function(self, fileDescriptor, data)
				return put(data, self.key, self.child:Read(fileDescriptor, data))
			end,
			ReadBits = function(self, bits, data)
				return put(data, self.key, self.child:ReadBits(bits, data))
			end,
			Write = function(self, fileDescriptor, context)
				self.child:Write(fileDescriptor, get(context, self.key))
				return nil
			end,
			WriteBits = function(self, bits, context)
				self.child:WriteBits(bits, get(context, self.key))
				return nil
			end
		})
	end
	ast.Name = nameClass
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/Bitpack.lua
	local bitpackClass
	do
		-- return an iterator over the individual bits in buffer
		local biterator
		biterator = function(binary)
			local data = {
				byte(binary, 1, len(binary))
			}
			local isBig = endianness.value == "big"
			local index = isBig and 1 or #data
			local delta = isBig and 1 or -1
			local bit0 = 7
			return function()
				local value = mod2[floor(data[index] / pow2[bit0])]
				bit0 = (bit0 - 1) % 8
				-- we just wrapped around
				if bit0 == 7 then
					index = index + delta
				end
				return value
			end
		end
		local bitpacker
		bitpacker = function(buffer, size)
			for index = 1, size do
				buffer[index] = 0
			end
			local isBig = endianness.value == "big"
			local index = isBig and 1 or size
			local delta = isBig and 1 or -1
			local bit0 = 7
			return function(byte1)
				buffer[index] = buffer[index] + (byte1 * pow2[bit0])
				bit0 = (bit0 - 1) % 8
				-- we just wrapped around
				if bit0 == 7 then
					index = index + delta
				end
			end
		end
		bitpackClass = classExtend(nodeClass, "Bitpack", {
			new = function(self, size)
				self.size = 0
				self.total_size = size
			end,
			Finalize = function(self)
				-- children are getting added with size in bits, not bytes
				local size = self.size
				size = size / 8
				assert(size, "bitpacks cannot contain variable-width fields")
				assert(size == self.total_size, "bitpack contents do not match bitpack size: " .. size .. " ~= " .. self.total_size)
				self.size = size
			end,
			Read = function(self, fileDescriptor, data)
				self:ReadBits(biterator(fileDescriptor:Read(self.size)), data)
				return nil
			end,
			Write = function(self, fileDescriptor, context)
				local buffer = { }
				self:WriteBits(bitpacker(buffer, self.size), context)
				return fileDescriptor:Write(char(unpack(buffer)))
			end
		})
	end
	ast.Bitpack = bitpackClass
	-- https://github.com/ToxicFrog/vstruct/blob/master/ast/IO.lua
	local ioClass = classExtend(nodeClass, "IO", {
		new = function(self, name, args)
			self.name = name
			local argv, n = {
				has_backrefs = false
			}, 0
			if args then
				for arg in gmatch(args .. ",", "([^,]*),") do
					n = n + 1
					if arg == "" then
						argv[n] = nil
					else
						local number = tonumber(arg, 10)
						if number then
							argv[n] = number
						elseif match(arg, "^#[%a_][%w_.]*$") then
							argv.has_backrefs = true
							argv[n] = numberClass(arg)
						else
							argv[n] = arg
						end
					end
				end
			end
			self.size = io[name].Size(argv[1])
			self.hasvalue = io[name].HasValue()
			self.argv = argv
			argv.n = n
		end,
		Read = function(self, fileDescriptor, data)
			local buffer
			local size = self.size
			if size and size > 0 then
				buffer = fileDescriptor:Read(size)
				assert(buffer and #buffer == size, "attempt to read past end of buffer in format " .. self.name)
			end
			return io[self.name].Read(fileDescriptor, buffer, self:GetArgv(data))
		end,
		ReadBits = function(self, bits, data)
			return io[self.name].ReadBits(bits, self:GetArgv(data))
		end,
		Write = function(self, fileDescriptor, context)
			local buffer = io[self.name].Write(fileDescriptor, context.data, self:GetArgvContext(context))
			if buffer then
				fileDescriptor:Write(buffer)
			end
			return nil
		end,
		WriteBits = function(self, fileDescriptor, bits, context)
			local buffer = io[self.name].WriteBits(bits, context.data, self:GetArgvContext(context))
			if buffer then
				fileDescriptor:Write(buffer)
			end
			return nil
		end,
		GetArgv = function(self, data)
			local argv = self.argv
			local n = argv.n
			-- If backreferences were involved, we have to try to resolve them.
			if argv.has_backrefs then
				local buffer = { }
				for index = 1, n do
					if argv[index] then
						buffer[index] = argv[index]:Get(data)
					end
				end
				return unpack(buffer, 1, n)
			end
			-- Usually the contents were determined at compile-time and we can just unpack it as is.
			return unpack(argv, 1, n)
		end,
		GetArgvContext = function(self, context)
			return self:GetArgv((context.parent or context).data)
		end
	})
	ast.IO = ioClass
	local iterator
	do
		-- used by the rest of the parser to report syntax errors
		local ast_error
		ast_error = function(lex, expected)
			error("parsing format string at " .. lex.where() .. ": expected " .. expected .. ", got " .. lex.peek().type)
			return nil
		end
		ast.error = ast_error
		local ast_require
		ast_require = function(lex, typeName)
			local tbl = lex.next()
			if tbl.type ~= typeName then
				ast_error(lex, typeName)
			end
			return tbl
		end
		ast.require = ast_require
		local ast_next
		local ast_next_until
		ast_next_until = function(lex, typeName)
			return function()
				local tokType = lex.peek().type
				if tokType == "EOF" then
					ast_error(lex, typeName)
					return nil
				end
				if tokType == typeName then
					return nil
				end
				return ast_next(lex)
			end
		end
		ast.next_until = ast_next_until
		local ast_repetition
		ast_repetition = function(lex)
			local count = numberClass(lex.next().text)
			ast_require(lex, "*")
			return repeatClass(count, ast_next(lex))
		end
		ast.repetition = ast_repetition
		local ast_group
		ast_group = function(lex)
			ast_require(lex, "(")
			local group = listClass()
			group.tag = "group"
			for value in ast_next_until(lex, ")") do
				group:Append(value)
			end
			ast_require(lex, ")")
			return group
		end
		ast.group = ast_group
		local ast_table, ast_io, ast_key
		do
			local ast_raw_table
			ast_raw_table = function(lex)
				ast_require(lex, "{")
				local group = tableClass()
				for value in ast_next_until(lex, "}") do
					group:Append(value)
				end
				ast_require(lex, "}")
				return group
			end
			ast.raw_table = ast_raw_table
			ast_table = function(lex)
				return nameClass(nil, ast_raw_table(lex))
			end
			ast.table = ast_table
			local ast_raw_io
			ast_raw_io = function(lex)
				local name = lex.next().text
				local value = lex.peek()
				if value and value.type == "number" and not lex.whitespace() then
					return ioClass(name, lex.next().text)
				end
				return ioClass(name, nil)
			end
			ast.raw_io = ast_raw_io
			ast_io = function(lex)
				local value = ast_raw_io(lex)
				if value.hasvalue then
					return nameClass(nil, value)
				end
				return value
			end
			ast.io = ast_io
			ast_key = function(lex)
				local name = lex.next().text
				do
					local _exp_0 = lex.peek().type
					if "io" == _exp_0 then
						local value = ast_raw_io(lex)
						if value.hasvalue then
							return nameClass(name, value)
						end
						ast_error(lex, "value (io specifier or table) - format '" .. name .. "' has no value")
						return nil
					elseif "{" == _exp_0 then
						return nameClass(name, ast_raw_table(lex))
					end
				end
				ast_error(lex, "value (io specifier or table)")
				return nil
			end
			ast.key = ast_key
		end
		local ast_bitpack
		ast_bitpack = function(lex)
			ast_require(lex, "[")
			local bitpack = bitpackClass(tonumber(ast_require(lex, "number").text, 10))
			ast_require(lex, "|")
			for value in ast_next_until(lex, "]") do
				bitpack:Append(value)
			end
			ast_require(lex, "]")
			bitpack:Finalize()
			return bitpack
		end
		ast.bitpack = ast_bitpack
		local ast_control
		ast_control = function(lex)
			local name = lex.next().text
			ast_require(lex, ":")
			return nameClass(name, ast_next(lex))
		end
		ast.control = ast_control
		local ast_splice
		ast_splice = function(lex)
			local name = lex.next().text
			local root = registry[name]
			if root then
				return root[1]
			end
			error("attempt to splice in format '" .. name .. "', which is not registered")
			return nil
		end
		ast.splice = ast_splice
		ast_next = function(lex)
			local tok = lex.peek()
			local typeName = tok.type
			if typeName == "EOF" then
				return nil
			end
			if typeName == "(" then
				return ast_group(lex)
			end
			if typeName == "{" then
				return ast_table(lex)
			end
			if typeName == "[" then
				return ast_bitpack(lex)
			end
			if typeName == "io" then
				return ast_io(lex)
			end
			if typeName == "key" then
				return ast_key(lex)
			end
			if typeName == "number" then
				return ast_repetition(lex)
			end
			if typeName == "control" then
				return ast_control(lex)
			end
			if typeName == "splice" then
				return ast_splice(lex)
			end
			ast_error(lex, "'(', '{', '[', name, number, control, or io specifier")
			return nil
		end
		ast.next = ast_next
		iterator = function(lex)
			return function()
				return ast_next(lex)
			end
		end
		ast.iterator = iterator
	end
	do
		local lexer = _module_0.lexer
		ast.parse = function(source)
			local root = listClass()
			for node in iterator(lexer(source)) do
				root:Append(node)
			end
			return rootClass(root)
		end
	end
end
-- https://github.com/ToxicFrog/vstruct/blob/master/api.lua
local api = { }
_module_0.api = api
do
	local wrapFileDescriptor
	do
		local Cursor = _module_0.Cursor
		wrapFileDescriptor = function(fileDescriptor)
			if isstring(fileDescriptor) then
				return Cursor(fileDescriptor)
			end
			local name = type(fileDescriptor)
			if name == "File" or name == "File: Legacy" then
				return Cursor(fileDescriptor:Read(), fileDescriptor:Close())
			end
			return fileDescriptor
		end
		api.WarpFileDescriptor = wrapFileDescriptor
	end
	local IsCursor = _module_0.IsCursor
	local istable = _G.istable
	local unwrapFileDescriptor
	unwrapFileDescriptor = function(fileDescriptor)
		if IsCursor(fileDescriptor) then
			return fileDescriptor:Flush()
		end
		return fileDescriptor
	end
	api.UnwrapFileDescriptor = unwrapFileDescriptor
	api.Read = function(obj, fileDescriptor, data)
		fileDescriptor = wrapFileDescriptor(fileDescriptor or "")
		if not IsCursor(fileDescriptor) then
			error("bad argument #2 to 'Read' (file or string expected, got " .. type(fileDescriptor) .. ")", 3)
		end
		if data ~= nil then
			argument(data, 3, "table")
		end
		return obj.ast:Read(fileDescriptor, data or { })
	end
	api.Write = function(obj, fileDescriptor, data)
		if fileDescriptor and not data then
			data, fileDescriptor = fileDescriptor, nil
		end
		fileDescriptor = wrapFileDescriptor(fileDescriptor or "")
		if not IsCursor(fileDescriptor) then
			error("bad argument #2 to 'Write' (file or string expected, got " .. type(fileDescriptor) .. ")", 3)
		end
		if not istable(data) then
			error("bad argument #3 to 'Write' (table expected, got " .. type(data) .. ")", 3)
		end
		obj.ast:Write(fileDescriptor, data)
		return unwrapFileDescriptor(fileDescriptor)
	end
	api.Records = function(rast, fileDescriptor, unpacked)
		fileDescriptor = wrapFileDescriptor(fileDescriptor or "")
		if not IsCursor(fileDescriptor) then
			error("bad argument #2 to 'Records' (file or string expected, got " .. type(fileDescriptor) .. ")", 3)
		end
		if unpacked ~= nil then
			argument(unpacked, 3, "boolean")
		end
		return function()
			if fileDescriptor:Read(0) then
				if unpacked then
					return unpack(rast:Read(fileDescriptor))
				end
				return rast:Read(fileDescriptor)
			end
		end
	end
	api.SizeOf = function(obj)
		return obj.ast.size
	end
	do
		local parse = ast.parse
		local cache = { }
		api.Compile = function(name, fmt)
			local obj, root
			obj = cache[fmt]
			if obj then
				root = obj.ast
			else
				root = parse(fmt)
				obj = {
					ast = root,
					source = fmt,
					Read = api.Read,
					Write = api.Write,
					Records = api.Records,
					SizeOf = api.SizeOf
				}
				cache[fmt] = obj
			end
			if name then
				registry[name] = root
			end
			return obj
		end
	end
end
-- https://github.com/ToxicFrog/vstruct/blob/master/init.lua
local read, write, sizeOf
do
	local records
	do
		local Compile, WarpFileDescriptor = api.Compile, api.WarpFileDescriptor
		read = function(fmt, ...)
			argument(fmt, 1, "string")
			return Compile(nil, fmt):Read(...)
		end
		_module_0.Read = read
		write = function(fmt, ...)
			argument(fmt, 1, "string")
			return Compile(nil, fmt):Write(...)
		end
		_module_0.Write = write
		sizeOf = function(fmt)
			argument(fmt, 1, "string")
			return Compile(nil, fmt).ast.size
		end
		_module_0.SizeOf = sizeOf
		_module_0.ReadVals = function(...)
			return unpack(read(...))
		end
		_module_0.Compile = function(name, fmt)
			argument(name, 1, "string")
			if fmt then
				argument(fmt, 2, "string")
				return Compile(name, fmt)
			end
			return Compile(nil, name)
		end
		records = function(fmt, fileDescriptor, unpacked)
			argument(fmt, 1, "string")
			if unpacked ~= nil then
				argument(unpacked, 3, "boolean")
			end
			return Compile(nil, fmt):Records(WarpFileDescriptor(fileDescriptor), unpacked)
		end
		_module_0.Records = records
	end
	_module_0.Array = function(fmt, fileDescriptor, length)
		if length == nil then
			length = 1
		end
		local array = { }
		for record in records(fmt, fileDescriptor) do
			array[length] = record
			length = length + 1
		end
		return array
	end
end
return _module_0

local _G = _G
local environment
do
	local _obj_0 = _G.gpm
	environment = _obj_0.environment
end
local string, file, table, await, async, AddonError, argument, error = environment.string, environment.file, environment.table, environment.await, environment.async, environment.AddonError, environment.argument, environment.error
file.CreateDir("/data/gpm/mount", true)
file.Delete("/data/gpm/mount/*")
local _module_0 = { }
do
	local Find, GetFolderContents = file.Find, file.GetFolderContents
	local GetAddons
	do
		local _obj_0 = _G.engine
		GetAddons = _obj_0.GetAddons
	end
	_module_0.GetAll = GetAddons
	local get
	get = function(wsid)
		local _list_0 = GetAddons()
		for _index_0 = 1, #_list_0 do
			local data = _list_0[_index_0]
			if data.wsid == wsid then
				return data
			end
		end
	end
	_module_0.Get = get
	_module_0.FileFind = function(filePath, wsid)
		local data = get(wsid)
		if data then
			return Find(filePath, data.title, true)
		end
	end
	_module_0.GetFiles = function(wsid, filePath)
		local data = get(wsid)
		if data then
			return GetFolderContents(filePath or "", data.title, true)
		end
	end
end
do
	local HasValue = table.HasValue
	-- Addon types
	local types = {
		"gamemode",
		"map",
		"weapon",
		"vehicle",
		"npc",
		"entity",
		"tool",
		"effects",
		"model",
		"servercontent"
	}
	_module_0.Types = types
	_module_0.TypeExists = function(str)
		return HasValue(types, str, true)
	end
	-- Addon tags
	local tags = {
		"fun",
		"roleplay",
		"scenic",
		"movie",
		"realism",
		"cartoon",
		"water",
		"comic",
		"build"
	}
	_module_0.Tags = tags
	_module_0.TagExists = function(str)
		return HasValue(tags, str, true)
	end
end
local isFilePathAllowed
do
	local find, gsub = string.find, string.gsub
	-- https://github.com/Facepunch/gmad/blob/master/include/AddonWhiteList.h
	local wildcard = {
		"lua/*.lua",
		"scenes/*.vcd",
		"particles/*.pcf",
		"resource/fonts/*.ttf",
		"scripts/vehicles/*.txt",
		"resource/localization/*/*.properties",
		"maps/*.bsp",
		"maps/*.lmp",
		"maps/*.nav",
		"maps/*.ain",
		"maps/thumb/*.png",
		"sound/*.wav",
		"sound/*.mp3",
		"sound/*.ogg",
		"materials/*.vmt",
		"materials/*.vtf",
		"materials/*.png",
		"materials/*.jpg",
		"materials/*.jpeg",
		"materials/colorcorrection/*.raw",
		"models/*.mdl",
		"models/*.vtx",
		"models/*.phy",
		"models/*.ani",
		"models/*.vvd",
		"gamemodes/*/*.txt",
		"gamemodes/*/*.fgd",
		"gamemodes/*/logo.png",
		"gamemodes/*/icon24.png",
		"gamemodes/*/gamemode/*.lua",
		"gamemodes/*/entities/effects/*.lua",
		"gamemodes/*/entities/weapons/*.lua",
		"gamemodes/*/entities/entities/*.lua",
		"gamemodes/*/backgrounds/*.png",
		"gamemodes/*/backgrounds/*.jpg",
		"gamemodes/*/backgrounds/*.jpeg",
		"gamemodes/*/content/models/*.mdl",
		"gamemodes/*/content/models/*.vtx",
		"gamemodes/*/content/models/*.phy",
		"gamemodes/*/content/models/*.ani",
		"gamemodes/*/content/models/*.vvd",
		"gamemodes/*/content/materials/*.vmt",
		"gamemodes/*/content/materials/*.vtf",
		"gamemodes/*/content/materials/*.png",
		"gamemodes/*/content/materials/*.jpg",
		"gamemodes/*/content/materials/*.jpeg",
		"gamemodes/*/content/materials/colorcorrection/*.raw",
		"gamemodes/*/content/scenes/*.vcd",
		"gamemodes/*/content/particles/*.pcf",
		"gamemodes/*/content/resource/fonts/*.ttf",
		"gamemodes/*/content/scripts/vehicles/*.txt",
		"gamemodes/*/content/resource/localization/*/*.properties",
		"gamemodes/*/content/maps/*.bsp",
		"gamemodes/*/content/maps/*.nav",
		"gamemodes/*/content/maps/*.ain",
		"gamemodes/*/content/maps/thumb/*.png",
		"gamemodes/*/content/sound/*.wav",
		"gamemodes/*/content/sound/*.mp3",
		"gamemodes/*/content/sound/*.ogg",
		"data_static/*.txt",
		"data_static/*.dat",
		"data_static/*.json",
		"data_static/*.xml",
		"data_static/*.csv",
		"data_static/*.dem",
		"data_static/*.vcd",
		"data_static/*.vtf",
		"data_static/*.vmt",
		"data_static/*.png",
		"data_static/*.jpg",
		"data_static/*.jpeg",
		"data_static/*.mp3",
		"data_static/*.wav",
		"data_static/*.ogg"
	}
	-- Converting wildcard to lua patterns
	for index = 1, #wildcard do
		wildcard[index] = "^" .. gsub(gsub(wildcard[index], "%.", "%."), "%*", ".+") .. "$"
	end
	isFilePathAllowed = function(filePath)
		for _index_0 = 1, #wildcard do
			local pattern = wildcard[_index_0]
			if find(filePath, pattern) then
				return true
			end
		end
		return false
	end
	_module_0.IsFilePathAllowed = isFilePathAllowed
end
local tostring, tonumber, isstring, isnumber = environment.tostring, environment.tonumber, environment.isstring, environment.isnumber
local AsyncRead, AsyncWrite, MountGMA, Open = file.AsyncRead, file.AsyncWrite, file.MountGMA, file.Open
local ByteStream, CRC, MD5
do
	local _obj_0 = environment.util
	ByteStream, CRC, MD5 = _obj_0.ByteStream, _obj_0.CRC, _obj_0.MD5
end
local byte, sub, lower, format, len = string.byte, string.sub, string.lower, string.format, string.len
local isuint
do
	local _obj_0 = environment.math
	isuint = _obj_0.isuint
end
local equal
do
	local _obj_0 = environment.path
	equal = _obj_0.equal
end
local time
do
	local _obj_0 = environment.os
	time = _obj_0.time
end
local Empty, remove = table.Empty, table.remove
local sidePrefix = _G.SERVER and "s" or _G.CLIENT and "c" or _G.MENU_DLL and "m" or "u"
_module_0.GMA = environment.class("GMA", {
	Identity = "GMAD",
	FormatVersion = 3,
	__tostring = function(self)
		return format("Garry's Mod Addon: %p [%s]", self, self.title)
	end,
	new = function(self, binary, doCRC)
		self.title = "unknown"
		self.author = "unknown"
		self.description = "unknown"
		self.version = 1
		self.required_content = { }
		self.steam_id = ""
		self.real_crc = 0
		self.files = { }
		self.stored_crc = 0
		if binary then
			self:Parse(ByteStream(binary), doCRC)
		end
		return nil
	end,
	GetTitle = function(self)
		return self.title
	end,
	SetTitle = function(self, str)
		argument(str, 1, "string")
		self.title = str
	end,
	GetAuthor = function(self)
		return self.author
	end,
	SetAuthor = function(self, str)
		argument(str, 1, "string")
		self.author = str
	end,
	GetDescription = function(self)
		return self.description
	end,
	SetDescription = function(self, str)
		argument(str, 1, "string")
		self.description = str
	end,
	GetAddonVersion = function(self)
		return self.version
	end,
	SetAddonVersion = function(self, int32)
		argument(int32, 1, "number")
		self.version = int32
	end,
	GetTimestamp = function(self)
		local timestamp = self.timestamp
		if not isnumber(timestamp) then
			timestamp = time()
			self.timestamp = timestamp
		end
		return timestamp
	end,
	SetTimestamp = function(self, uint64)
		argument(uint64, 1, "number")
		if not isuint(uint64) then
			error("invalid timestamp must be an unsigned integer", 2)
		end
		if uint64 > 0xFFFFFFFFFFFFFFFF then
			error("invalid timestamp must be less than 2^64", 2)
		end
		self.timestamp = uint64
	end,
	GetSteamID = function(self)
		return self.steam_id
	end,
	SetSteamID = function(self, str)
		argument(str, 1, "string")
		self.steam_id = str
	end,
	Parse = function(self, handler, doCRC)
		handler:Seek(0)
		if handler:Read(4) ~= self.Identity then
			error(AddonError("File is not a gma"))
		end
		local version = handler:ReadByte()
		if version > self.FormatVersion then
			error(AddonError("gma version is unsupported"))
		end
		local steam_id = handler:ReadUInt64()
		if steam_id then
			if isstring(steam_id) then
				self.steam_id = steam_id
			else
				self.steam_id = tostring(steam_id)
			end
		else
			self.steam_id = ""
		end
		self.timestamp = handler:ReadUInt64()
		if version > 1 and handler:ReadByte() ~= 0 then
			local required_content = self.required_content
			handler:Skip(-1)
			while not handler:EndOfFile() do
				local value = handler:ReadString()
				if value then
					required_content[value] = true
				else
					break
				end
			end
		end
		self.title = handler:ReadString()
		self.description = handler:ReadString()
		self.author = handler:ReadString()
		self.version = handler:ReadLong()
		local position = 0
		local files = self.files
		while not handler:EndOfFile() do
			local index = handler:ReadULong()
			if index == 0 then
				break
			end
			local data = {
				path = handler:ReadString(),
				position = position
			}
			local fileSize = handler:ReadUInt64()
			data.size = fileSize
			position = position + fileSize
			data.stored_crc = handler:ReadULong()
			files[index] = data
		end
		files.pointer = handler:Tell()
		if doCRC ~= true then
			local contentSize = handler:Size() - 4
			handler:Seek(contentSize)
			self.stored_crc = handler:ReadULong() or 0
			handler:Seek(0)
			self.real_crc = tonumber(CRC(handler:Read(contentSize)), 10)
		end
	end,
	VerifyCRC = function(self)
		return self.stored_crc == self.real_crc
	end,
	VerifyFilesCRC = function(self)
		local _list_0 = self.files
		for _index_0 = 1, #_list_0 do
			local data = _list_0[_index_0]
			local stored_crc = data.stored_crc
			if not stored_crc then
				return false, data
			end
			local real_crc = data.real_crc
			if not real_crc then
				local content = data.content
				if content then
					real_crc = tonumber(CRC(content), 10)
					data.real_crc = real_crc
				end
			end
			if stored_crc ~= real_crc then
				return false, data
			end
		end
		return true
	end,
	VerifyFiles = function(self)
		local files = self.files
		if #files == 0 then
			return false, nil
		end
		for _index_0 = 1, #files do
			local data = files[_index_0]
			if not isFilePathAllowed(data.path) then
				return false, data
			end
		end
		return true
	end,
	ReadFile = function(self, handler, index)
		if not handler then
			error(AddonError("file read handler is missing, reading is not possible"))
		end
		local files = self.files
		local data = files[index]
		if not data then
			error(AddonError("requested file does not exist"))
		end
		handler:Seek(files.pointer + data.position)
		data.content = handler:Read(data.size)
		return data
	end,
	ReadAllFiles = function(self, handler, doCRC)
		if not handler then
			error(AddonError("file read handler is missing, reading is not possible"))
		end
		local files = self.files
		local pointer = files.pointer
		if not pointer then
			error(AddonError("file pointer is missing, reading is not possible"))
		end
		doCRC = doCRC ~= true
		for _index_0 = 1, #files do
			local data = files[_index_0]
			handler:Seek(pointer + data.position)
			local content = handler:Read(data.size)
			data.content = content
			if doCRC then
				data.real_crc = tonumber(CRC(content), 10)
			end
		end
		return files
	end,
	GetFiles = function(self)
		return self.files
	end,
	GetFile = function(self, index)
		return self.files[index]
	end,
	SetFile = function(self, filePath, content, doCRC)
		argument(filePath, 1, "string")
		argument(content, 2, "string")
		if byte(filePath, 1) == 0x2F then
			filePath = sub(filePath, 2)
		end
		filePath = lower(filePath)
		doCRC = doCRC ~= false
		local files = self.files
		local length = #files
		::removed::
		for index = 1, length do
			if equal(files[index].path, filePath) then
				remove(files, index)
				length = length - 1
				goto removed
			end
		end
		local data = {
			size = len(content),
			path = filePath,
			content = content
		}
		if doCRC then
			do
				local _tmp_0 = tonumber(CRC(content), 10)
				data.stored_crc = _tmp_0
				data.real_crc = _tmp_0
			end
		end
		length = length + 1
		files[length] = data
	end,
	ClearFiles = function(self)
		return Empty(self.files)
	end,
	AddRequiredContent = function(self, value)
		argument(value, 1, "string")
		self.required_content[value] = true
	end,
	RemoveRequiredContent = function(self, value)
		argument(value, 1, "string")
		self.required_content[value] = nil
	end,
	ClearRequiredContent = function(self)
		return Empty(self.required_content)
	end,
	Read = function(self, filePath, readAllFiles, doCRC)
		Empty(self.required_content)
		Empty(self.files)
		local handler = Open(filePath, "rb")
		if not handler then
			error(AddonError("file cannot be opened"))
		end
		self:Parse(handler, doCRC)
		if readAllFiles then
			self:ReadAllFiles(handler, doCRC)
		end
		handler:Close()
		return self
	end,
	AsyncRead = async(function(self, filePath, readAllFiles, doCRC, validateHash)
		Empty(self.required_content)
		Empty(self.files)
		local handler = ByteStream(await(AsyncRead(filePath, "rb", nil, validateHash)))
		self:Parse(handler, doCRC)
		if readAllFiles then
			self:ReadAllFiles(handler, doCRC)
		end
		handler:Close()
		return self
	end),
	GetBinary = function(self, doCRC)
		local ok, result = self:VerifyFiles()
		if not ok then
			if result then
				error(AddonError("file is not allowed by whitelist (" .. result.path .. ")"))
			else
				error(AddonError("gma is empty"))
			end
		end
		doCRC = doCRC ~= false
		local handler = ByteStream()
		handler:Write(self.Identity)
		handler:WriteByte(self.FormatVersion)
		local steam_id = self.steam_id
		if not steam_id or steam_id == "" then
			handler:Write("\0\0\0\0\0\0\0\0")
		else
			handler:WriteUInt64(steam_id)
		end
		handler:WriteUInt64(self:GetTimestamp())
		for value in pairs(self.required_content) do
			handler:WriteString(value)
		end
		handler:WriteByte(0)
		handler:WriteString(self.title)
		handler:WriteString(self.description)
		handler:WriteString(self.author)
		handler:WriteLong(self.version)
		local files = self.files
		for index = 1, #files do
			handler:WriteULong(index)
			local data = files[index]
			handler:WriteString(lower(data.path))
			handler:WriteUInt64(data.size)
			if doCRC then
				handler:WriteULong(tonumber(CRC(data.content), 10))
			else
				handler:WriteULong(0)
			end
		end
		handler:WriteULong(0)
		for _index_0 = 1, #files do
			local data = files[_index_0]
			local content = data.content
			if isstring(content) then
				handler:Write(content)
			else
				error(AddonError("file content must be a string (" .. data.path .. ")"))
			end
		end
		if doCRC then
			local crc = tonumber(CRC(handler:ReadAll()), 10)
			self.stored_crc = crc
			self.real_crc = crc
		else
			handler:WriteULong(0)
		end
		return handler:ReadAll()
	end,
	Write = function(self, filePath, doCRC)
		argument(filePath, 1, "string")
		local handler = Open(filePath, "wb")
		if not handler then
			error(AddonError("file '" .. filePath .. "' cannot be opened"))
		end
		handler:Write(self:GetBinary(doCRC))
		handler:Close()
		return self
	end,
	AsyncWrite = async(function(self, filePath, doCRC, saveHash)
		argument(filePath, 1, "string")
		await(AsyncWrite(filePath, self:GetBinary(doCRC), nil, nil, saveHash))
		return self
	end),
	Mount = function(self, doCRC)
		local filePath = "/data/gpm/mount/" .. MD5(self.title .. time() .. sidePrefix) .. ".gma"
		self:Write(filePath, doCRC)
		local ok, result = MountGMA(filePath)
		if not ok then
			error(AddonError(result))
		end
		return result
	end,
	AsyncMount = async(function(self, doCRC, saveHash)
		local filePath = "/data/gpm/mount/" .. MD5(self.title .. time() .. sidePrefix) .. ".gma"
		await(self:AsyncWrite(filePath, doCRC, saveHash))
		local ok, result = MountGMA(filePath)
		if not ok then
			error(AddonError(result))
		end
		return result
	end)
})
return _module_0

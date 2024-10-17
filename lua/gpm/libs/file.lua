local _G = _G
local environment, Logger, sql
do
	local _obj_0 = _G.gpm
	environment, Logger, sql = _obj_0.environment, _obj_0.Logger, _obj_0.sql
end
local file, istable, CLIENT, SERVER, MENU_DLL, pcall = _G.file, _G.istable, _G.CLIENT, _G.SERVER, _G.MENU_DLL, _G.pcall
local async, await, debug, util, path, string, Future, CodeCompileError, FileSystemError, error, argument, tostring = environment.async, environment.await, environment.debug, environment.util, environment.path, environment.string, environment.Future, environment.CodeCompileError, environment.FileSystemError, environment.error, environment.argument, environment.tostring
local ByteStream, IsBinaryModuleInstalled, SHA256 = util.ByteStream, util.IsBinaryModuleInstalled, util.SHA256
local byte, sub, len, match, ByteSplit = string.byte, string.sub, string.len, string.match, string.ByteSplit
local resolve, getDirectory, getFile, getCurrentDirectory = path.resolve, path.getDirectory, path.getFile, path.getCurrentDirectory
local concat, Add
do
	local _obj_0 = environment.table
	concat, Add = _obj_0.concat, _obj_0.Add
end
local Find, Exists, IsDir = file.Find, file.Exists, file.IsDir
local get, save
do
	local _obj_0 = sql.files
	get, save = _obj_0.get, _obj_0.save
end
local fempty = debug.fempty
-- Entropia File System Watcher: https://github.com/Pika-Software/gm_efsw
if SERVER and not _G.efsw and IsBinaryModuleInstalled("efsw") and pcall(require, "efsw") then
	Logger:Info("gm_efsw is initialized, package auto-reloading are available.")
end
local lib = environment.file
local luaPath
if SERVER then
	luaPath = "lsv"
elseif CLIENT then
	luaPath = "lcl"
elseif MENU_DLL then
	luaPath = "LuaMenu"
else
	luaPath = "LUA"
end
lib.LuaPath = luaPath
local luaGamePaths = {
	["LuaMenu"] = true,
	["lsv"] = true,
	["LUA"] = true,
	["lcl"] = true
}
lib.LuaGamePaths = luaGamePaths
local luaExtensions = {
	lua = true,
	yue = true,
	moon = true
}
lib.LuaExtensions = luaExtensions
local writeAllowedGamePaths = {
	["DATA"] = true
}
lib.WriteAllowedGamePaths = writeAllowedGamePaths
local assertWriteAllowed
assertWriteAllowed = function(filePath, gamePath)
	if writeAllowedGamePaths[gamePath] or MENU_DLL then
		return nil
	end
	error(FileSystemError("File '" .. tostring(filePath) .. "' is not allowed to be written to '" .. tostring(gamePath) .. "'.", 3))
	return nil
end
local normalizeGamePath, absoluteGamePath
do
	local isurl = environment.isurl
	local dir2path = {
		lua = luaPath,
		data = "DATA",
		download = "DOWNLOAD"
	}
	normalizeGamePath = function(absolutePath, gamePath)
		if not gamePath and isurl(absolutePath) then
			if absolutePath.scheme ~= "file" then
				error(FileSystemError("Cannot resolve URL '" .. tostring(absolutePath) .. "' because it is not a file URL."))
			end
			absolutePath = absolutePath.pathname
		end
		local firstByte = byte(absolutePath)
		if firstByte == 0x2F then
			absolutePath = sub(absolutePath, 2)
			if gamePath then
				return absolutePath, gamePath
			end
		elseif firstByte == 0x2E then
			local secondByte = byte(absolutePath, 2)
			if secondByte == 0x2F or (secondByte == 0x2E and byte(absolutePath, 3) == 0x2F) then
				local currentDir = sub(getCurrentDirectory(), 5)
				if currentDir == "" then
					error(FileSystemError("Cannot resolve relative path '" .. tostring(absolutePath) .. "' because main file is unknown."))
				end
				absolutePath = sub(resolve(currentDir .. absolutePath), 2)
				gamePath = luaPath
			end
		end
		if not gamePath then
			for index = 1, len(absolutePath) do
				if byte(absolutePath, index) == 0x2F then
					local rootDir = sub(absolutePath, 1, index - 1)
					gamePath = dir2path[rootDir]
					if gamePath then
						absolutePath = sub(absolutePath, index + 1)
					end
					break
				end
			end
		end
		return absolutePath, gamePath or "GAME"
	end
	lib.NormalizeGamePath = normalizeGamePath
	local path2dir = {
		DOWNLOAD = "/download",
		LuaMenu = "/lua",
		DATA = "/data",
		LUA = "/lua",
		lsv = "/lua",
		lcl = "/lua"
	}
	absoluteGamePath = function(filePath, gamePath, withoutSlash)
		if gamePath then
			filePath = (path2dir[gamePath] or "") .. "/" .. filePath
		end
		if withoutSlash and byte(filePath, 1) == 0x2F then
			filePath = sub(filePath, 2)
		end
		return filePath
	end
	lib.AbsoluteGamePath = absoluteGamePath
end
do
	local Time = file.Time
	lib.Time = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		return Time(filePath, gamePath)
	end
end
lib.Find = function(filePath, gamePath, skipNormalize)
	if not skipNormalize then
		filePath, gamePath = normalizeGamePath(filePath, gamePath)
	end
	local files, dirs = Find(filePath, gamePath)
	if CLIENT and luaGamePaths[gamePath] then
		local files2, dirs2 = Find("lua/" .. filePath, "WORKSHOP")
		return Add(files, files2, true), Add(dirs, dirs2, true)
	end
	return files, dirs
end
do
	local replaceDir, replaceFile = path.replaceDir, path.replaceFile
	local Rename = file.Rename
	lib.Move = function(pathFrom, pathTo, gamePathFrom, gamePathTo, skipNormalize)
		if not skipNormalize then
			pathFrom, gamePathFrom = normalizeGamePath(pathFrom, gamePathFrom)
		end
		assertWriteAllowed(pathFrom, gamePathFrom)
		if not skipNormalize then
			pathTo, gamePathTo = normalizeGamePath(pathTo, gamePathTo)
		end
		assertWriteAllowed(pathTo, gamePathTo)
		return Rename(pathFrom, replaceDir(pathFrom, pathTo), gamePathFrom, gamePathTo)
	end
	lib.Rename = function(filePath, newName, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		assertWriteAllowed(filePath, gamePath)
		return Rename(filePath, replaceFile(filePath, newName), gamePath)
	end
end
local isFileMounted, isDirMounted
do
	local allowedGamePaths = {
		["LUA"] = true,
		["lsv"] = true,
		["lcl"] = true,
		["GAME"] = true,
		["WORKSHOP"] = true,
		["THIRDPARTY"] = true
	}
	local mountedFiles = rawget(environment.file, "MountedFiles") or { }
	lib.MountedFiles = mountedFiles
	isFileMounted = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		if not allowedGamePaths[gamePath] then
			return false
		end
		if luaGamePaths[gamePath] then
			filePath = "lua/" .. filePath
		end
		return mountedFiles[filePath]
	end
	lib.IsFileMounted = isFileMounted
	local mountedFolders = rawget(environment.file, "MountedFolders") or { }
	lib.MountedFolders = mountedFolders
	isDirMounted = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		if not allowedGamePaths[gamePath] then
			return false
		end
		if luaGamePaths[gamePath] then
			filePath = "lua/" .. filePath
		end
		return mountedFolders[filePath]
	end
	lib.IsDirMounted = isDirMounted
	do
		local MountGMA
		do
			local _obj_0 = environment.game
			MountGMA = _obj_0.MountGMA
		end
		lib.MountGMA = function(relativePath)
			local success, files = MountGMA(sub(resolve(relativePath), 2))
			if success then
				local fileCount = #files
				for index = 1, fileCount do
					local filePath = files[index]
					-- mounted files
					mountedFiles[filePath] = true
					-- mounted dirs
					local segments, segmentCount = ByteSplit(getDirectory(filePath, false), 0x2F)
					segmentCount = segmentCount - 1
					while segmentCount ~= 0 do
						mountedFolders[concat(segments, "/", 1, segmentCount)] = true
						segmentCount = segmentCount - 1
					end
				end
				Logger:Debug("GMA file '%s' was mounted to GAME with %d files.", relativePath, fileCount)
			end
			return success, files
		end
	end
end
local isDir, isFile, createDir
do
	local Delete = file.Delete
	lib.Exists = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		return (isFileMounted(filePath, gamePath, true) or isDirMounted(filePath, gamePath, true)) or Exists(filePath, gamePath) or (CLIENT and luaGamePaths[gamePath] and Exists("lua/" .. filePath, "WORKSHOP"))
	end
	isDir = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		return isDirMounted(filePath, gamePath, true) or IsDir(filePath, gamePath) or (CLIENT and luaGamePaths[gamePath] and IsDir("lua/" .. filePath, "WORKSHOP"))
	end
	lib.IsDir = isDir
	isFile = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		if isFileMounted(filePath, gamePath, true) then
			return true
		end
		if isDirMounted(filePath, gamePath, true) then
			return false
		end
		if Exists(filePath, gamePath) then
			if IsDir(filePath, gamePath) then
				return false
			end
			return true
		end
		if CLIENT and luaGamePaths[gamePath] and Exists("lua/" .. filePath, "WORKSHOP") then
			if IsDir("lua/" .. filePath, "WORKSHOP") then
				return false
			end
			return true
		end
		return false
	end
	lib.IsFile = isFile
	do
		local delete
		delete = function(filePath, gamePath)
			local basePath = getDirectory(filePath, true)
			local files, dirs = Find(filePath, gamePath)
			local searchable = getFile(filePath)
			local successful = true
			for _index_0 = 1, #files do
				local fileName = files[_index_0]
				if not Delete(basePath .. fileName, gamePath) then
					successful = false
				end
			end
			for _index_0 = 1, #dirs do
				local directoryName = dirs[_index_0]
				local directoryPath = basePath .. directoryName
				if directoryPath == filePath then
					if not delete(directoryPath .. "/*", gamePath) then
						successful = false
					end
				elseif not delete(directoryPath .. "/" .. searchable, gamePath) then
					successful = false
				end
				if not Delete(directoryPath, gamePath) then
					successful = false
				end
			end
			return successful
		end
		lib.Delete = function(filePath, gamePath, skipNormalize)
			if not skipNormalize then
				filePath, gamePath = normalizeGamePath(filePath, gamePath)
			end
			assertWriteAllowed(filePath, gamePath)
			return delete(filePath, gamePath)
		end
	end
	do
		local CreateDir = file.CreateDir
		createDir = function(directoryPath, force, gamePath, skipNormalize)
			if not skipNormalize then
				directoryPath, gamePath = normalizeGamePath(directoryPath, gamePath)
			end
			assertWriteAllowed(directoryPath, gamePath)
			if force then
				local currentPath
				local _list_0 = ByteSplit(directoryPath, 0x2F)
				for _index_0 = 1, #_list_0 do
					local directoryName = _list_0[_index_0]
					if directoryName then
						if currentPath then
							currentPath = currentPath .. ("/" .. directoryName)
						else
							currentPath = directoryName
						end
						if isDir(currentPath, gamePath, true) then
							goto _continue_0
						end
						Delete(currentPath, gamePath)
						CreateDir(currentPath, gamePath)
					end
					::_continue_0::
				end
				return currentPath
			end
			CreateDir(directoryPath, gamePath)
			return directoryPath
		end
		lib.CreateDir = createDir
	end
	do
		local Size = file.Size
		local size
		size = function(filePath, gamePath)
			if isDir(filePath, gamePath) then
				local bytes = 0
				local files, dirs = Find(filePath .. "/*", gamePath)
				for _index_0 = 1, #files do
					local fileName = files[_index_0]
					bytes = bytes + Size(filePath .. "/" .. fileName, gamePath)
				end
				for _index_0 = 1, #dirs do
					local directoryName = dirs[_index_0]
					bytes = bytes + size(filePath .. "/" .. directoryName, gamePath)
				end
				return bytes
			end
			return Size(filePath, gamePath)
		end
		lib.Size = function(filePath, gamePath, skipNormalize)
			if not skipNormalize then
				filePath, gamePath = normalizeGamePath(filePath, gamePath)
			end
			return size(filePath, gamePath)
		end
	end
end
do
	local getFolderContents
	getFolderContents = function(directoryPath, gamePath, result, length)
		local files, dirs = Find(directoryPath .. "*", gamePath)
		if not files then
			return result, length
		end
		for _index_0 = 1, #files do
			local fileName = files[_index_0]
			length = length + 1
			result[length] = directoryPath .. fileName
		end
		for _index_0 = 1, #dirs do
			local directoryName = dirs[_index_0]
			result, length = getFolderContents(directoryPath .. directoryName .. "/", gamePath, result, length)
		end
		return result, length
	end
	lib.GetFolderContents = function(directoryPath, gamePath, skipNormalize)
		if not skipNormalize then
			directoryPath, gamePath = normalizeGamePath(directoryPath, gamePath)
		end
		local result, length = { }, 0
		if directoryPath == "" or isDir(directoryPath, gamePath, true) then
			if directoryPath ~= "" then
				directoryPath = directoryPath .. "/"
			end
			return getFolderContents(directoryPath, gamePath, result, length)
		end
		return result, length
	end
end
local append, read, write
do
	local legacy = util.FindMetaTable("File")
	local base = { }
	do
		local getmetatable = _G.getmetatable
		environment.isfile = function(any)
			local metatable = getmetatable(any)
			return metatable == base or metatable == legacy
		end
	end
	local fileClass
	do
		local setmetatable = debug.setmetatable
		local newClass = environment.class
		local Open = file.Open
		local writeModes = {
			["a"] = true,
			["w"] = true,
			["ab"] = true,
			["wb"] = true
		}
		legacy.new = function(self, filePath, fileMode, gamePath, skipNormalize)
			if not skipNormalize then
				filePath, gamePath = normalizeGamePath(filePath, gamePath)
			end
			if writeModes[fileMode] then
				local directoryPath = getDirectory(filePath, true)
				if directoryPath ~= "" and directoryPath ~= "/" then
					createDir(directoryPath, true, gamePath, true)
				end
			end
			local cls = Open(filePath, fileMode, gamePath)
			if cls then
				setmetatable(cls, self.__class.__base)
				return true, cls
			end
			return true, nil
		end
		local fileLegacyClass = newClass("File: Legacy", legacy)
		util.FileLegacy = fileLegacyClass
		fileClass = newClass("File", base, nil, fileLegacyClass)
		util.File = fileClass
		lib.Open = function(filePath, fileMode, gamePath, skipNormalize)
			return fileClass(filePath, fileMode, gamePath, skipNormalize)
		end
	end
	local Close, Read, Write, EndOfFile = legacy.Close, legacy.Read, legacy.Write, legacy.EndOfFile
	do
		local ReadULong, WriteULong, ReadByte, Seek, Size, Skip, Tell = legacy.ReadULong, legacy.WriteULong, legacy.ReadByte, legacy.Seek, legacy.Size, legacy.Skip, legacy.Tell
		base.IsValid = function(fileHandle)
			return tostring(fileHandle) ~= "File [NULL]"
		end
		base.SeekToBegin = function(fileHandle)
			return Seek(fileHandle, 0)
		end
		base.SeekToEnd = function(fileHandle)
			return Seek(fileHandle, Size(fileHandle))
		end
		base.SkipEmpty = function(fileHandle)
			while not EndOfFile(fileHandle) do
				if ReadByte(fileHandle) ~= 0 then
					Skip(fileHandle, -1)
					break
				end
			end
		end
		-- String
		base.ReadString = function(fileHandle)
			local startPos, length = Tell(fileHandle), 0
			while not EndOfFile(fileHandle) and ReadByte(fileHandle) ~= 0 do
				length = length + 1
			end
			Seek(fileHandle, startPos)
			local data = Read(fileHandle, length)
			Skip(fileHandle, 1)
			return data
		end
		base.WriteString = ByteStream.WriteString
		-- Line
		base.WriteLine = ByteStream.WriteLine
		if not base.ReadUInt64 then
			base.ReadUInt64 = function(fileHandle)
				local number = ReadULong(fileHandle)
				Skip(fileHandle, 4)
				return number
			end
		end
		if not base.WriteUInt64 then
			base.WriteUInt64 = function(fileHandle, number)
				WriteULong(fileHandle, number)
				WriteULong(fileHandle, 0)
				return
			end
		end
		base.ReadAll = function(fileHandle)
			Seek(fileHandle, 0)
			return Read(fileHandle, Size(fileHandle))
		end
		-- UnixTime
		base.ReadTime = ByteStream.ReadTime
		base.WriteTime = ByteStream.WriteTime
		-- ZipFile
		base.ReadZipFile = ByteStream.ReadZipFile
		base.WriteZipFile = ByteStream.WriteZipFile
		-- Color
		base.ReadColor = ByteStream.ReadColor
		base.WriteColor = ByteStream.WriteColor
		-- Date
		base.ReadDate = ByteStream.ReadDate
		base.WriteDate = ByteStream.WriteDate
	end
	append = function(filePath, content, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		assertWriteAllowed(filePath, gamePath)
		local fileHandle = fileClass(filePath, "ab", gamePath, true)
		if fileHandle then
			Write(fileHandle, content)
			Close(fileHandle)
			return true
		end
		return false
	end
	lib.Append = append
	read = function(filePath, gamePath, length, skipNormalize, verifyHash)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		if CLIENT and luaGamePaths[gamePath] and not (Exists(filePath, gamePath) and not IsDir(filePath, gamePath)) then
			filePath, gamePath = "lua/" .. filePath, "WORKSHOP"
		end
		local fileHandle = fileClass(filePath, "rb", gamePath, true)
		if fileHandle then
			local content = Read(fileHandle, length)
			Close(fileHandle)
			if verifyHash then
				local cache = get(absoluteGamePath(filePath, gamePath, false))
				if not (cache and (not cache.hash or cache.hash == SHA256(content)) and cache.size == len(content)) then
					return nil
				end
			end
			return content
		end
	end
	lib.Read = read
	write = function(filePath, content, gamePath, skipNormalize, saveHash)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		assertWriteAllowed(filePath, gamePath)
		local fileHandle = fileClass(filePath, "wb", gamePath, true)
		if fileHandle then
			Write(fileHandle, content)
			Close(fileHandle)
			if saveHash then
				save(absoluteGamePath(filePath, gamePath, false), len(content), nil, SHA256(content))
			end
			return true
		end
		return false
	end
	lib.Write = write
	do
		local ReadLine = legacy.ReadLine
		local gsub = string.gsub
		local readLines
		readLines = function(filePath, gamePath, skipNormalize)
			local fileHandle = fileClass(filePath, "rb", gamePath, skipNormalize)
			if fileHandle then
				local lines, length = { }, 0
				while not EndOfFile(fileHandle) do
					length = length + 1
					lines[length] = ReadLine(fileHandle)
				end
				Close(fileHandle)
				local pointer = 0
				return function()
					pointer = pointer + 1
					return lines[pointer], pointer
				end
			end
			return fempty
		end
		lib.Lines = readLines
		local getinfo = debug.getinfo
		debug.getfcode = function(location)
			local info = getinfo(location)
			local linedefined = info.linedefined
			if linedefined < 0 then
				return info.source
			end
			local lastlinedefined = info.lastlinedefined
			local lines, length = { }, 0
			for str, line in readLines(gsub(info.source, "^@", "/"), nil) do
				if line >= linedefined then
					length = length + 1
					lines[length] = str
				end
				if line >= lastlinedefined then
					break
				end
			end
			if length == 0 then
				return ""
			end
			local spaces = match(lines[1], "^%s+")
			if spaces then
				local spLength = len(spaces)
				local spLength1 = spLength + 1
				for index = 1, length do
					local str = lines[index]
					if sub(str, 1, spLength) == spaces then
						lines[index] = sub(str, spLength1)
					end
				end
			end
			return concat(lines, "", 1, length)
		end
	end
end
local efsw = _G.efsw
if istable(efsw) then
	local Watch, Unwatch = efsw.Watch, efsw.Unwatch
	local observedFiles = rawget(environment.file, "ObservedFiles") or { }
	lib.ObservedFiles = observedFiles
	local hashIdentifier
	hashIdentifier = function(filePath, gamePath)
		return gamePath .. ":///" .. filePath
	end
	local watch
	watch = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		local identifier = hashIdentifier(filePath, gamePath)
		if observedFiles[identifier] then
			return false
		end
		observedFiles[identifier] = Watch(filePath, gamePath)
		if isDir(filePath, gamePath, true) then
			filePath = filePath .. "/"
			local files, dirs = Find(filePath .. "*", gamePath)
			for _index_0 = 1, #files do
				local fileName = files[_index_0]
				watch(filePath .. fileName, gamePath)
			end
			for _index_0 = 1, #dirs do
				local directoryName = dirs[_index_0]
				watch(filePath .. directoryName, gamePath)
			end
		end
		return true
	end
	lib.Watch = watch
	local unWatch
	unWatch = function(filePath, gamePath, skipNormalize)
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		local identifier = hashIdentifier(filePath, gamePath)
		local watchID = observedFiles[identifier]
		if not watchID then
			return false
		end
		observedFiles[identifier] = nil
		Unwatch(watchID)
		if isDir(filePath, gamePath, true) then
			filePath = filePath .. "/"
			local files, dirs = Find(filePath .. "*", gamePath)
			for _index_0 = 1, #files do
				local fileName = files[_index_0]
				unWatch(filePath .. fileName, gamePath)
			end
			for _index_0 = 1, #dirs do
				local directoryName = dirs[_index_0]
				unWatch(filePath .. directoryName, gamePath)
			end
		end
		return true
	end
	lib.UnWatch = unWatch
else
	lib.Watch = fempty
	lib.Unwatch = fempty
end
local asyncRead
do
	local captureStack, appendStack, popCallStack, pushCallStack = FileSystemError.captureStack, FileSystemError.appendStack, FileSystemError.popCallStack, FileSystemError.pushCallStack
	local functions = {
		{
			"Append",
			false
		},
		{
			"Write",
			false
		},
		{
			"Read",
			false
		}
	}
	do
		local sources = {
			{
				["Name"] = "gm_asyncio",
				["Fetch"] = function()
					return IsBinaryModuleInstalled("asyncio")
				end,
				["Install"] = function()
					require("asyncio")
					local asyncio = _G.asyncio
					return {
						["Append"] = asyncio.AsyncAppend,
						["Read"] = asyncio.AsyncRead,
						["Write"] = asyncio.AsyncWrite
					}
				end
			},
			{
				["Name"] = "async_write",
				["Fetch"] = function()
					return IsBinaryModuleInstalled("async_write")
				end,
				["Install"] = function()
					require("async_write")
					return {
						["Append"] = file.AsyncAppen,
						["Write"] = file.AsyncWrite
					}
				end
			},
			{
				["Name"] = "Garry's Mod Async",
				["Fetch"] = function()
					return not MENU_DLL
				end,
				["Install"] = function()
					return {
						["Read"] = file.AsyncRead
					}
				end
			},
			{
				["Name"] = "Garry's Mod",
				["Install"] = function()
					return {
						["Read"] = function(fileName, gamePath, func)
							local content = read(fileName, gamePath, nil, true, false)
							local state = content == nil and -1 or 0
							func(fileName, gamePath, state, content)
							return state
						end,
						["Append"] = function(fileName, content, gamePath, func)
							local state = append(fileName, content, gamePath, true) and 0 or -1
							func(fileName, "DATA", state)
							return state
						end,
						["Write"] = function(fileName, content, gamePath, func)
							local state = write(fileName, content, gamePath, true) and 0 or -1
							func(fileName, "DATA", state)
							return state
						end
					}
				end
			}
		}
		local functionsNeed = #functions
		for _index_0 = 1, #sources do
			local source = sources[_index_0]
			if not source.Fetch or source.Fetch() then
				local result = source.Install()
				local installed = 0
				for _index_1 = 1, #functions do
					local data = functions[_index_1]
					if data[2] then
						goto _continue_0
					end
					local name = data[1]
					if not result[name] then
						goto _continue_0
					end
					functions[name] = result[name]
					functionsNeed = functionsNeed - 1
					data[2] = true
					installed = installed + 1
					::_continue_0::
				end
				if installed > 0 then
					Logger:Info("'%s' was connected as filesystem API.", source.Name)
				end
				if functionsNeed < 1 then
					break
				end
			end
		end
	end
	local FSASYNC = {
		[-8] = "Filename not part of the specified file system, try a different one.",
		[-7] = "Failure for a reason that might be temporary, you might retry, but not immediately.",
		[-6] = "Read parameters invalid for unbuffered IO.",
		[-5] = "Hard subsystem failure.",
		[-4] = "Read error on file.",
		[-3] = "Out of memory for file read.",
		[-2] = "Caller's provided id is not recognized.",
		[-1] = "Filename could not be opened (bad path, not exist, etc).",
		[0] = "Operation is successful.",
		[1] = "File is properly queued, waiting for service.",
		[2] = "File is being accessed.",
		[3] = "File was aborted by caller.",
		[4] = "File is not yet queued."
	}
	lib.FSASYNC = FSASYNC
	do
		local Append = functions.Append
		lib.AsyncAppend = function(filePath, content, gamePath, skipNormalize)
			if not skipNormalize then
				filePath, gamePath = normalizeGamePath(filePath, gamePath)
			end
			assertWriteAllowed(filePath, gamePath)
			local fut = Future()
			appendStack(captureStack())
			local stack = popCallStack()
			local state = Append(filePath, content, function(iFilePath, iGamePath, iState)
				if iState == 0 then
					fut:setResult(absoluteGamePath(iFilePath, iGamePath, false))
					return nil
				end
				pushCallStack(stack)
				fut:setError(FileSystemError(FSASYNC[iState]))
				popCallStack()
				return nil
			end, gamePath)
			if state ~= 0 then
				fut:setError(FileSystemError(FSASYNC[state]))
			end
			return fut
		end
	end
	do
		local Read = functions.Read
		asyncRead = function(filePath, gamePath, skipNormalize, verifyHash)
			if not skipNormalize then
				filePath, gamePath = normalizeGamePath(filePath, gamePath)
			end
			if CLIENT and luaGamePaths[gamePath] and not (Exists(filePath, gamePath) and not IsDir(filePath, gamePath)) then
				filePath, gamePath = "lua/" .. filePath, "WORKSHOP"
			end
			local fut = Future()
			appendStack(captureStack())
			local stack = popCallStack()
			local state = Read(filePath, gamePath, function(_, __, iState, iContent)
				if iState == 0 then
					if verifyHash then
						local cache = get(absoluteGamePath(filePath, gamePath, false))
						if not (cache and (not cache.hash or cache.hash == SHA256(iContent)) and cache.size == len(iContent)) then
							fut:setError(FileSystemError("File hash mismatch for '" .. absoluteGamePath(filePath, gamePath, false) .. "'"))
							return nil
						end
					end
					fut:setResult(iContent)
					return nil
				end
				pushCallStack(stack)
				fut:setError(FileSystemError(FSASYNC[iState]))
				popCallStack()
				return nil
			end)
			if state ~= 0 then
				fut:setError(FileSystemError(FSASYNC[state]))
			end
			return fut
		end
		lib.AsyncRead = asyncRead
	end
	do
		local Write = functions.Write
		lib.AsyncWrite = function(filePath, content, gamePath, skipNormalize, saveHash)
			if not skipNormalize then
				filePath, gamePath = normalizeGamePath(filePath, gamePath)
			end
			assertWriteAllowed(filePath, gamePath)
			local directoryPath = getDirectory(filePath, true)
			if directoryPath ~= "" and directoryPath ~= "/" then
				createDir(directoryPath, true, gamePath, true)
			end
			local fut = Future()
			appendStack(captureStack())
			local stack = popCallStack()
			local state = Write(filePath, content, gamePath, function(iFilePath, iGamePath, iState)
				if iState == 0 then
					local fullPath = absoluteGamePath(iFilePath, iGamePath, false)
					if saveHash then
						save(fullPath, len(content), nil, SHA256(content))
					end
					fut:setResult(fullPath)
					return nil
				end
				pushCallStack(stack)
				fut:setError(FileSystemError(FSASYNC[iState]))
				popCallStack()
				return nil
			end)
			if state ~= 0 then
				fut:setError(FileSystemError(FSASYNC[state]))
			end
			return fut
		end
	end
end
do
	-- TODO: convert it to async generator (with yield), so it can be used with apairs
	local func = async(function(task)
		local lines, pointer = ByteSplit(await(task), 0xa), 0
		return function()
			pointer = pointer + 1
			return lines[pointer], pointer
		end
	end)
	lib.AsyncLines = function(filePath, gamePath, skipNormalize, verifyHash)
		return func(asyncRead(filePath, gamePath, skipNormalize, verifyHash))
	end
end
do
	local getExtension, stripExtension = path.getExtension, path.stripExtension
	local load = environment.load
	local CompileFile = _G.CompileFile
	local extension2mode = {
		luac = "bt",
		moon = "mt",
		yue = "yt",
		lua = "t",
		lc = "bt"
	}
	local mode2type = {
		mt = "moonscript",
		yt = "yuescript",
		bt = "bytecode",
		t = "lua"
	}
	local asyncCompile = async(function(filePath, gamePath, env, config, verifyHash)
		filePath = stripExtension(filePath) .. "."
		local extensions = { }
		local _list_0 = Find(filePath .. "*", gamePath)
		for _index_0 = 1, #_list_0 do
			local fileName = _list_0[_index_0]
			extensions[getExtension(fileName, false)] = true
		end
		local extension
		if extensions.yue then
			extension = "yue"
		elseif extensions.moon then
			extension = "moon"
		elseif extensions.luac then
			extension = "luac"
		elseif extensions.lc then
			extension = "lc"
		elseif extensions.lua then
			extension = "lua"
		end
		filePath = filePath .. (extension or "lua")
		local chunkName = absoluteGamePath(filePath, gamePath, true)
		local mode = extension2mode[extension]
		if not mode then
			error(CodeCompileError("Could not determine compile mode for '" .. chunkName .. "'"))
		end
		if CLIENT and luaGamePaths[gamePath] and not isFileMounted(filePath, gamePath, true) and getExtension(filePath, false) == "lua" then
			local ok, result = pcall(CompileFile, filePath)
			if not ok then
				error(CodeCompileError("Failed to compile '" .. chunkName .. "', " .. result))
			end
			if not result then
				error(CodeCompileError("Could not compile '" .. chunkName .. "'"))
			end
			if env then
				setfenv(result, env)
			end
			return {
				func = result,
				type = mode2type[mode],
				path = "/" .. chunkName,
				content = ""
			}
		end
		local content = await(asyncRead(filePath, gamePath, true, verifyHash))
		return {
			func = load(content, chunkName, mode, env, config),
			type = mode2type[mode],
			path = "/" .. chunkName,
			content = content
		}
	end)
	lib.AsyncCompile = function(filePath, env, config, gamePath, skipNormalize, verifyHash)
		argument(filePath, 1, "string")
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		return asyncCompile(filePath, gamePath, env, config, verifyHash)
	end
	lib.Compile = function(filePath, env, config, gamePath, skipNormalize, verifyHash)
		argument(filePath, 1, "string")
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		filePath = stripExtension(filePath) .. "."
		local extensions = { }
		local _list_0 = Find(filePath .. "*", gamePath)
		for _index_0 = 1, #_list_0 do
			local fileName = _list_0[_index_0]
			extensions[getExtension(fileName, false)] = true
		end
		local extension
		if extensions.yue then
			extension = "yue"
		elseif extensions.moon then
			extension = "moon"
		elseif extensions.luac then
			extension = "luac"
		elseif extensions.lc then
			extension = "lc"
		elseif extensions.lua then
			extension = "lua"
		end
		filePath = filePath .. (extension or "lua")
		local chunkName = absoluteGamePath(filePath, gamePath, true)
		local mode = extension2mode[extension]
		if not mode then
			error(CodeCompileError("Could not determine compile mode for '" .. chunkName .. "'"))
		end
		if CLIENT and luaGamePaths[gamePath] and not isFileMounted(filePath, gamePath, true) and getExtension(filePath, false) == "lua" then
			local ok, result = pcall(CompileFile, filePath)
			if not ok then
				error(CodeCompileError("Failed to compile '" .. chunkName .. "', " .. result))
			end
			if not result then
				error(CodeCompileError("Could not compile '" .. chunkName .. "'"))
			end
			if env then
				setfenv(result, env)
			end
			return {
				func = result,
				type = mode2type[mode],
				path = "/" .. chunkName,
				content = ""
			}
		end
		local content = read(filePath, gamePath, nil, true, verifyHash)
		return {
			func = load(content, chunkName, mode, env, config),
			type = mode2type[mode],
			path = "/" .. chunkName,
			content = content
		}
	end
	environment.loadfile = function(filePath, mode, env, config, gamePath, skipNormalize, verifyHash)
		argument(filePath, 1, "string")
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		if CLIENT and luaGamePaths[gamePath] and not isFileMounted(filePath, gamePath, true) and getExtension(filePath, false) == "lua" then
			local ok, result = pcall(CompileFile, filePath)
			if not ok then
				error(CodeCompileError("Failed to compile '" .. absoluteGamePath(filePath, gamePath, true) .. "', " .. result))
			end
			if not result then
				error(CodeCompileError("Could not compile '" .. absoluteGamePath(filePath, gamePath, true) .. "'"))
			end
			if env then
				setfenv(result, env)
			end
			return result
		end
		return load(read(filePath, gamePath, nil, true, verifyHash), absoluteGamePath(filePath, gamePath, true), mode, env, config)
	end
end
do
	local addon = include("addon.lua")
	environment.addon = addon
	local GMA, IsFilePathAllowed = addon.GMA, addon.IsFilePathAllowed
	local isstring = environment.isstring
	local equal = path.equal
	local pairs = _G.pairs
	do
		local Read = lib.Read
		lib.Get = function(filePath)
			if istable(filePath) then
				local result = { }
				for index = 1, #filePath do
					local fileName = filePath[index]
					argument(fileName, index, "string")
					result[fileName] = Read(fileName, nil, nil, false)
				end
				return result
			end
			argument(filePath, 1, "string")
			return {
				[filePath] = Read(filePath, nil, nil, false)
			}
		end
	end
	lib.Set = function(filePath, content, uniqueName)
		if istable(filePath) then
			uniqueName = content or uniqueName
			local title, length = { }, 0
			local gma = GMA()
			for fileName, fileContent in pairs(filePath) do
				argument(fileName, 1, "string")
				argument(fileContent, 2, "string")
				if len(fileContent) == 0 then
					error(FileSystemError("File '" .. fileName .. "' cannot be empty.", 2))
				end
				local subPath = fileName
				if byte(subPath, 1) == 0x2f then
					subPath = sub(subPath, 2)
				end
				if not IsFilePathAllowed(subPath) then
					error(FileSystemError("File '" .. subPath .. "' cannot be written.", 2))
				end
				gma:SetFile(subPath, fileContent, false)
				length = length + 1
				title[length] = fileName
			end
			if isstring(uniqueName) then
				gma:SetTitle(uniqueName)
			else
				gma:SetTitle(concat(title, ";", 1, length))
			end
			return gma:Mount(false)
		end
		argument(filePath, 1, "string")
		argument(content, 2, "string")
		if len(content) == 0 then
			error(FileSystemError("File '" .. filePath .. "' cannot be empty.", 2))
		end
		if byte(filePath, 1) == 0x2f then
			filePath = sub(filePath, 2)
		end
		if not IsFilePathAllowed(filePath) then
			error(FileSystemError("File '" .. filePath .. "' cannot be written.", 2))
		end
		local gma = GMA()
		if isstring(uniqueName) then
			gma:SetTitle(uniqueName)
		else
			gma:SetTitle(filePath)
		end
		gma:SetFile(filePath, content, false)
		return gma:Mount(false)
	end
	local iterateZipFiles
	iterateZipFiles = function(fileHandle, doCRC)
		if not fileHandle then
			return fempty
		end
		doCRC = doCRC ~= false
		return function()
			return fileHandle:ReadZipFile(doCRC)
		end
	end
	lib.IterateZipFiles = iterateZipFiles
	lib.MountGMAData = async(function(data, uniqueName, verifyCRC)
		local gma = GMA(data, false)
		if verifyCRC and not gma:VerifyCRC() then
			error(FileSystemError("Invalid CRC checksum for '" .. gma:GetTitle() .. "'"))
		end
		if uniqueName then
			gma:SetTitle(uniqueName)
		end
		return await(gma:AsyncMount(false))
	end)
	local mountZIPData = async(function(binary, uniqueName)
		local gma = GMA()
		gma:SetTitle(uniqueName)
		local isInFolder, last
		local temp = { }
		for data in iterateZipFiles(ByteStream(binary), true) do
			local content = data.content
			if content and content ~= "" then
				local filePath = data.path
				temp[filePath] = content
				if isInFolder ~= false then
					local current = match(filePath, "^(.-)/")
					if last then
						isInFolder = equal(last, current)
					end
					last = current
				end
			end
		end
		local files = temp
		if isInFolder then
			files = { }
			local endPos = #last + 2
			for fileName, content in pairs(temp) do
				files[sub(fileName, endPos)] = content
			end
		end
		for filePath, content in pairs(files) do
			if IsFilePathAllowed(filePath) then
				gma:SetFile(filePath, content)
			end
		end
		return await(gma:AsyncMount(false))
	end)
	lib.MountZIPData = mountZIPData
	local asyncMount = async(function(filePath, gamePath)
		return await(mountZIPData(await(asyncRead(filePath, gamePath, true)), "file:///" .. filePath))
	end)
	lib.MountZIP = function(filePath, gamePath, skipNormalize)
		argument(filePath, 1, "string")
		if not skipNormalize then
			filePath, gamePath = normalizeGamePath(filePath, gamePath)
		end
		return await(asyncMount(filePath, gamePath))
	end
end

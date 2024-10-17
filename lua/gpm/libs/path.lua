local _module_0 = { }
local _G = _G
local environment
do
	local _obj_0 = _G.gpm
	environment = _obj_0.environment
end
-- Based on https://github.com/luvit/luvit/blob/master/deps/path/base.lua
local byte, sub, len, lower, match, gsub, ByteSplit, TrimByte, IsURL
do
	local _obj_0 = environment.string
	byte, sub, len, lower, match, gsub, ByteSplit, TrimByte, IsURL = _obj_0.byte, _obj_0.sub, _obj_0.len, _obj_0.lower, _obj_0.match, _obj_0.gsub, _obj_0.ByteSplit, _obj_0.TrimByte, _obj_0.IsURL
end
local getfmain, getfpath
do
	local _obj_0 = environment.debug
	getfmain, getfpath = _obj_0.getfmain, _obj_0.getfpath
end
local concat, insert, remove = table.concat, table.insert, table.remove
local getfenv, rawget = _G.getfenv, _G.rawget
local URL = environment.URL
local getFile
getFile = function(path)
	for index = len(path), 1, -1 do
		local ch = byte(path, index)
		if ch == 0x2F or ch == 0x5C then
			return sub(path, index + 1)
		end
	end
	return path
end
_module_0["getFile"] = getFile
local getFileName
getFileName = function(path, withExtension)
	if withExtension then
		return getFile(path)
	end
	local dotPosition
	for index = len(path), 1, -1 do
		local ch = byte(path, index)
		if ch == 0x2E then
			if not dotPosition then
				dotPosition = index
			end
		elseif ch == 0x2F or ch == 0x5C then
			if dotPosition then
				return sub(path, index + 1, dotPosition - 1)
			end
			return sub(path, index + 1)
		end
	end
	if dotPosition then
		return sub(path, 1, dotPosition - 1)
	end
	return path
end
_module_0["getFileName"] = getFileName
local getDirectory
getDirectory = function(path, withTrailingSlash)
	if withTrailingSlash == nil then
		withTrailingSlash = true
	end
	for index = len(path), 1, -1 do
		local ch = byte(path, index)
		if ch == 0x2F or ch == 0x5C then
			if withTrailingSlash then
				return sub(path, 1, index)
			end
			return sub(path, 1, index - 1)
		end
	end
	return ""
end
_module_0["getDirectory"] = getDirectory
local getExtension
getExtension = function(path, withDot)
	for index = len(path), 1, -1 do
		local ch = byte(path, index)
		if ch == 0x2F or ch == 0x5C then
			break
		end
		if ch == 0x2E then
			if withDot then
				return sub(path, index)
			end
			return sub(path, index + 1)
		end
	end
	return ""
end
_module_0["getExtension"] = getExtension
local stripFile
stripFile = function(path)
	for index = len(path), 1, -1 do
		local ch = byte(path, index)
		if ch == 0x2F or ch == 0x5C then
			return sub(path, 1, index), sub(path, index + 1)
		end
	end
	return "", path
end
_module_0["stripFile"] = stripFile
local stripDirectory
stripDirectory = function(path)
	for index = len(path), 1, -1 do
		local ch = byte(path, index)
		if ch == 0x2F or ch == 0x5C then
			return sub(path, index + 1), sub(path, 1, index)
		end
	end
	return path, ""
end
_module_0["stripDirectory"] = stripDirectory
local stripExtension
stripExtension = function(path)
	for index = len(path), 1, -1 do
		local ch = byte(path, index)
		if ch == 0x2F or ch == 0x5C then
			return path, ""
		end
		if ch == 0x2E then
			return sub(path, 1, index - 1), sub(path, index + 1)
		end
	end
	return path, ""
end
_module_0["stripExtension"] = stripExtension
local replaceFile
replaceFile = function(path, newFile)
	return stripFile(path) .. newFile
end
_module_0["replaceFile"] = replaceFile
local replaceDir
replaceDir = function(path, newDir)
	if byte(newDir, len(newDir)) ~= 0x2F then
		newDir = newDir .. "/"
	end
	return newDir .. stripDirectory(path)
end
_module_0["replaceDir"] = replaceDir
local replaceExtension
replaceExtension = function(path, newExtension)
	return stripExtension(path) .. "." .. newExtension
end
_module_0["replaceExtension"] = replaceExtension
local fixFileName
fixFileName = function(path)
	local length = len(path)
	if byte(path, length) == 0x2F then
		path = sub(path, 1, length - 1)
	end
	return path
end
_module_0["fixFileName"] = fixFileName
local fixSlashes
fixSlashes = function(path)
	return gsub(path, "[/\\]+", "/"), nil
end
_module_0["fixSlashes"] = fixSlashes
local fix
fix = function(path)
	return fixFileName(fixSlashes(path))
end
_module_0["fix"] = fix
local getCurrentFile
getCurrentFile = function(func)
	if func == nil then
		func = getfmain()
	end
	if func then
		local fenv = getfenv(func)
		if fenv then
			local filePath = rawget(fenv, "__filename")
			if filePath then
				return filePath
			end
		end
		local fpath = getfpath(func)
		if IsURL(fpath) then
			return URL(fpath).pathname
		end
		return "/" .. fpath
	end
end
_module_0["getCurrentFile"] = getCurrentFile
local getCurrentDirectory
getCurrentDirectory = function(func, withTrailingSlash)
	if func == nil then
		func = getfmain()
	end
	if withTrailingSlash == nil then
		withTrailingSlash = true
	end
	if func then
		local fenv = getfenv(func)
		if fenv then
			local dirPath = rawget(fenv, "__dirname")
			if dirPath then
				if withTrailingSlash then
					dirPath = dirPath .. "/"
				end
				return dirPath
			end
		end
		local fpath = getfpath(func)
		if IsURL(fpath) then
			return getDirectory(URL(fpath).pathname, withTrailingSlash)
		end
		return getDirectory("/" .. fpath, withTrailingSlash)
	end
	return "/"
end
_module_0["getCurrentDirectory"] = getCurrentDirectory
local delimiter = ":"
_module_0["delimiter"] = delimiter
local sep = "/"
_module_0["sep"] = sep
local isAbsolute
isAbsolute = function(path)
	return byte(path, 1) == 0x2F
end
_module_0["isAbsolute"] = isAbsolute
local os = jit.os
local isSpecial = os == "Windows" or os == "OSX"
_module_0["isSpecial"] = isSpecial
local equal
equal = function(a, b)
	if isSpecial then
		return a and b and lower(a) == lower(b)
	end
	return a == b
end
_module_0["equal"] = equal
-- Split a filename into [root, dir, basename]
local splitPath
splitPath = function(path)
	local root
	if isAbsolute(path) then
		path = sub(path, 2)
		root = "/"
	else
		root = ""
	end
	local basename, dir = stripDirectory(path)
	return root, dir, basename
end
_module_0["splitPath"] = splitPath
local dirname
dirname = function(path, withTrailingSlash)
	if withTrailingSlash == nil then
		withTrailingSlash = true
	end
	path = getDirectory(path, withTrailingSlash)
	if path == "" then
		if withTrailingSlash then
			return "./"
		end
		return "."
	end
	return path
end
_module_0["dirname"] = dirname
local basename
basename = function(path, stripSuffix)
	path = getFile(path)
	if stripSuffix then
		return stripExtension(path)
	end
	return path, ""
end
_module_0["basename"] = basename
local extname = getExtension
_module_0["extname"] = extname
local normalize
normalize = function(path)
	local isAbs = isAbsolute(path)
	local trailingSlashes = byte(path, len(path)) == 0x2F
	if isAbs then
		path = sub(path, 2)
	end
	local parts, length = ByteSplit(path, 0x2F)
	-- Modifies an array of path parts in place by interpreting "." and ".." segments
	local skip = 0
	for index = length, 1, -1 do
		local part = parts[index]
		if part == "." then
			remove(parts, index)
			length = length - 1
		elseif part == ".." then
			remove(parts, index)
			length = length - 1
			skip = skip + 1
		elseif skip > 0 then
			remove(parts, index)
			length = length - 1
			skip = skip - 1
		end
	end
	if not isAbs then
		while skip > 0 do
			insert(parts, 1, "..")
			length = length + 1
			skip = skip - 1
		end
	end
	path = concat(parts, "/", 1, length)
	if path == "" then
		if isAbs then
			return "/"
		end
		if trailingSlashes then
			return "./"
		end
		return "."
	end
	if trailingSlashes then
		path = path .. "/"
	end
	if isAbs then
		path = "/" .. path
	end
	return fixSlashes(path)
end
_module_0["normalize"] = normalize
local join
join = function(...)
	local parts, length = { }, 0
	-- filter out empty parts
	local _list_0 = {
		...
	}
	for _index_0 = 1, #_list_0 do
		local part = _list_0[_index_0]
		if part and part ~= "" then
			length = length + 1
			parts[length] = part
		end
	end
	for index = 1, length do
		local part = parts[index]
		-- Strip leading slashes on all but first item
		if index > 1 then
			part = TrimByte(part, 0x2F, 1)
		end
		-- Strip trailing slashes on all but last item
		if index < length then
			part = TrimByte(part, 0x2F, -1)
		end
		parts[index] = part
	end
	return normalize(concat(parts, "/", 1, length))
end
_module_0["join"] = join
-- Works backwards, joining the arguments until it resolves to an absolute path.
-- If an absolute path is not resolved, then the current working directory is
-- prepended
local resolve
resolve = function(...)
	local resolvedPath = ""
	local paths = {
		...
	}
	for index = #paths, 1, -1 do
		local path = paths[index]
		if path and path ~= "" then
			resolvedPath = join(normalize(path), resolvedPath)
			if isAbsolute(resolvedPath) then
				return resolvedPath
			end
		end
	end
	return getCurrentDirectory(nil, true) .. resolvedPath
end
_module_0["resolve"] = resolve
-- Returns the relative path from "from" to "to"
-- If no relative path can be solved, then "to" is returned
local relative
relative = function(pathFrom, pathTo)
	pathFrom = resolve(pathFrom)
	pathTo = resolve(pathTo)
	local fromRoot, fromDir, fromBaseName = splitPath(pathFrom)
	local toRoot, toDir, toBaseName = splitPath(pathTo)
	if not equal(fromRoot, toRoot) then
		return pathTo
	end
	local fromParts, fromLength = ByteSplit(fromDir .. fromBaseName, 0x2F)
	local toParts, toLength = ByteSplit(toDir .. toBaseName, 0x2F)
	local commonLength = 0
	for index = 1, fromLength do
		local part = fromParts[index]
		if not equal(part, toParts[index]) then
			break
		end
		commonLength = commonLength + 1
	end
	local parts, length = { }, 0
	for _ = commonLength + 1, fromLength do
		length = length + 1
		parts[length] = ".."
	end
	for index = commonLength + 1, toLength do
		length = length + 1
		parts[length] = toParts[index]
	end
	return concat(parts, "/", 1, length)
end
_module_0["relative"] = relative
--[[
    ┌─────────────────────┬────────────┐
    │          dir        │    base    │
    ├──────┬              ├──────┬─────┤
    │ root │              │ name │ ext │
    "  /    home/user/dir/  file  .txt "
    └──────┴──────────────┴──────┴─────┘
    (All spaces in the "" line should be ignored. They are purely for formatting.)

]]
local parse
parse = function(path)
	local root, dir, base = splitPath(path)
	local name, ext = match(base, "^(.+)%.(.+)$")
	if name then
		ext = ext or ""
	else
		name = base
		ext = ""
	end
	return {
		root = root,
		dir = dir,
		base = base,
		ext = ext,
		name = name
	}
end
_module_0["parse"] = parse
return _module_0

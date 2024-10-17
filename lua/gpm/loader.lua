local _G = _G
local CLIENT, SERVER, gpm, pcall, getfenv = _G.CLIENT, _G.SERVER, _G.gpm, _G.pcall, _G.getfenv
local environment, SendFile = gpm.environment, gpm.SendFile
local async, await, debug, string, path, file, util, pairs, isurl, isstring, argument, URL, ModuleError, error, PackageError, Task = environment.async, environment.await, environment.debug, environment.string, environment.path, environment.file, environment.util, environment.pairs, environment.isurl, environment.isstring, environment.argument, environment.URL, environment.ModuleError, environment.error, environment.PackageError, environment.Task
local NormalizeGamePath, AbsoluteGamePath, Find, LuaPath = file.NormalizeGamePath, file.AbsoluteGamePath, file.Find, file.LuaPath
local getDirectory, getExtension, replaceExtension = path.getDirectory, path.getExtension, path.replaceExtension
local concat, IsEmpty, Merge
do
	local _obj_0 = environment.table
	concat, IsEmpty, Merge = _obj_0.concat, _obj_0.IsEmpty, _obj_0.Merge
end
local newClass = environment.class
local getfpath = debug.getfpath
local Version = util.Version
file.CreateDir("/data/gpm/vfs", true)
_G.hook.Add("ShutDown", gpm.PREFIX .. "::VFS", function()
	file.Delete("/data/gpm/vfs")
	return nil
end)
local addcsluafile
if SERVER then
	local getCurrentFile, getCurrentDirectory, getFile = path.getCurrentFile, path.getCurrentDirectory, path.getFile
	local LuaGamePaths, LuaExtensions = file.LuaGamePaths, file.LuaExtensions
	local addFilePath
	addFilePath = function(filePath, gamePath)
		local basePath = getDirectory(filePath, true)
		local searchable = getFile(filePath)
		local files, dirs = Find(filePath, gamePath, true)
		for index = 1, #files do
			local fileName = files[index]
			if LuaExtensions[getExtension(fileName, false)] then
				SendFile(basePath .. replaceExtension(fileName, "lua"))
			else
				error("Attept to send non-lua file '" .. basePath .. fileName .. "'.", 2)
			end
		end
		for _index_0 = 1, #dirs do
			local directoryName = dirs[_index_0]
			local directoryPath = basePath .. directoryName
			if directoryPath == filePath then
				addFilePath(directoryPath .. "/*", gamePath)
			else
				addFilePath(directoryPath .. "/" .. searchable, gamePath)
			end
		end
		return nil
	end
	addcsluafile = function(filePath, gamePath, skipNormalize)
		if filePath == nil then
			filePath = ""
		end
		if filePath == "" or getFile(filePath) == "." then
			local fenv = getfenv(2)
			local m = fenv and fenv.__module
			if m then
				filePath = m.file
			else
				filePath = getCurrentFile()
			end
		elseif filePath == "./" then
			local fenv = getfenv(2)
			local m = fenv and fenv.__module
			if m then
				filePath = m.directory .. "/*"
			else
				filePath = getCurrentDirectory(nil, true) .. "*"
			end
		end
		if not skipNormalize then
			filePath, gamePath = NormalizeGamePath(filePath, gamePath)
		end
		if not LuaGamePaths[gamePath] then
			error("Sending lua files from '" .. gamePath .. "' game path is not allowed.", 2)
		end
		addFilePath(filePath, gamePath)
		return nil
	end
end
environment.AddCSLuaFile = addcsluafile or debug.fempty
local loader = gpm.loader
if not istable(loader) then
	loader = { }
	gpm.loader = loader
end
-- Modules and Packages are tables with format: [url] = Module/Package
local packages = { }
loader.Packages = packages
local modules = { }
loader.Modules = modules
-- Resolves specifier as it is package specifier
-- See https://nodejs.org/api/esm.html#resolution-algorithm-specification PACKAGE_RESOLVE
local find, match, gsub, format, StartsWith, IsURL, PathFromURL = string.find, string.match, string.gsub, string.format, string.StartsWith, string.IsURL, string.PathFromURL
local AsyncCompile, IsFile = file.AsyncCompile, file.IsFile
local sources = loader.Sources
if not istable(sources) then
	sources = { }
	loader.Sources = sources
end
local getSource
getSource = function(protocol)
	if isstring(protocol) and IsURL(protocol) then
		protocol = URL(protocol).scheme
	elseif isurl(protocol) then
		protocol = protocol.scheme
	end
	return sources[protocol]
end
local moduleClass, packageClass, packageRead
do
	local setmetatable = _G.setmetatable
	do
		moduleClass = newClass("Module", {
			__tostring = function(self)
				return format("Module: %p [%s]", self, self.name)
			end,
			new = function(self, url, env)
				if env == nil then
					env = _G
				end
				self.url = url
				self.env = env
				argument(url, 1, "URL")
				local pathname = url.pathname
				if not pathname then
					return nil
				end
				self.name = "unknown"
				self.file = pathname
				self.directory = getDirectory(pathname, false)
				self.env = setmetatable({
					__module = self,
					__filename = self.file,
					__dirname = self.directory
				}, {
					__index = self.env,
					__newindex = self.env
				})
				modules[url.href] = self
				return nil
			end,
			load = async(function(self)
				if self.func then
					return self.func
				end
				local config = { }
				if self.url.scheme == "file" then
					local filePath, gamePath = NormalizeGamePath(self.url.pathname)
					if not IsFile(filePath, gamePath, true) then
						error(ModuleError("file '" .. tostring(self.url) .. "' does not exist"))
					end
					local compileResult = await(AsyncCompile(filePath, self.env, config, gamePath, true))
					local func = async(compileResult.func)
					self.func = func
					self.name = getfpath(func) or "unknown"
					return func
				end
				error(ModuleError("unsupported scheme '" .. self.url.scheme .. "' ('" .. self.url.href .. "')"))
				return nil
			end),
			run = function(self, ...)
				if not self.func then
					error(ModuleError("module " .. tostring(self.url) .. " was not loaded"))
				end
				return self:func(...)
			end
		}, {
			getAll = function()
				return modules
			end,
			get = function(url)
				return modules[url.href]
			end,
			run = async(function(url, env)
				argument(url, 1, "URL")
				local m = modules[url.href]
				if not m then
					m = moduleClass(url, env)
					await(m:load())
				end
				return await(m:run())
			end)
		})
		loader.Module = moduleClass
	end
	local getFileName = path.getFileName
	local Logger = util.Logger
	local tobool = _G.tobool
	local default = environment.Color(50, 100, 200):DoCorrection()
	local environmentMetatable = {
		__index = environment
	}
	-- TODO: maybe allow urls and strings instead of just local file asyncompile?
	local parse = async(function(filePath, gamePath, config)
		local compileResult = await(AsyncCompile(filePath, { }, config, gamePath, true))
		-- await Module.cache( "file://" .. compileResult.path, compileResult.content )
		local func = compileResult.func
		local info = { }
		setfenv(func, info)
		local success, result = pcall(func)
		if success then
			if istable(result) then
				Merge(info, result)
			end
			if IsEmpty(info) then
				error(PackageError("file '" .. tostring(filePath) .. "' does not contain valid package info (empty or cannot be parsed)"))
				return nil
			end
			if gamePath == LuaPath then
				SendFile(replaceExtension(filePath, "lua"))
			end
			return packageClass(URL(AbsoluteGamePath(filePath, gamePath), "file:///"), info)
		end
		error(PackageError("package info '" .. filePath .. "' execution error: " .. result))
		return nil
	end)
	local emptyTable = { }
	packageRead = async(function(url)
		if isstring(url) then
			url = URL(url)
		end
		if not isurl(url) then
			error(PackageError("invalid url '" .. url.href .. "'"))
		end
		if url.scheme ~= "file" then
			-- error PackageError "unsupported scheme '" .. url.scheme .. "' ('" .. url.href .. "')"
			return nil
		end
		if not istable(url.path) then
			-- error PackageError "invalid path '" .. url.pathname .. "' ('" .. url.href .. "')"
			return nil
		end
		local cached = packages[url.href]
		if cached then
			if not cached:done() or not cached:error() then
				return await(cached)
			end
			-- clear cache if parsing failed
			packages[url.href] = nil
		end
		local filePath, gamePath = NormalizeGamePath(url.pathname)
		local fileDir = getDirectory(filePath, true)
		-- if not package.* file was given in url, try to find it smartly
		if getFileName(filePath, false) ~= "package" then
			local files = Find(fileDir .. "/package.*", gamePath, true)
			if #files == 1 then
				filePath = fileDir .. files[1]
			elseif #files > 1 then
				-- Smartly decide which file to use
				local values = { }
				for _index_0 = 1, #files do
					local fileName = files[_index_0]
					values[getExtension(fileName, false)] = fileName
				end
				filePath = fileDir .. values.yue or values.moon or values.lua or values[1]
			end
		end
		if not IsFile(filePath, gamePath, true) then
			-- error PackageError "file '" .. filePath .. "' does not exist for packageURL '" .. url.href .. "'"
			return nil
		end
		local config = { }
		for key, value in url.searchParams:iterator() do
			config[key] = value
		end
		-- also cache result so next calls will return current package
		local task = Task(parse(filePath, gamePath, config))
		packages[url.href] = task
		return await(task)
	end)
	packageClass = newClass("Package", {
		__tostring = function(self)
			return format("Package: %p [%s@%s]", self, self.name, self.version)
		end,
		new = function(self, url, info)
			self.url = url
			local filePath = url.pathname
			self.file = filePath
			self.directory = getDirectory(filePath, false)
			if not info then
				info = emptyTable
			end
			-- name
			local name = info.name
			if not (isstring(name) and match(name, "^[a-zA-Z_][%w ~<>_&+%-]*")) then
				name = match(filePath, ".*packages/([^/]+)") or getFileName(filePath, false)
				if name == "" then
					error(PackageError("invalid package name: '" .. name .. "'"))
				end
			end
			self.name = name
			-- version
			local version = info.version
			if not isstring(version) then
				version = "0.1.0"
			end
			version = Version(version)
			self.version = version
			-- autorun
			self.autorun = tobool(info.autorun)
			-- send
			if SERVER then
				local send = info.send
				if not istable(send) then
					send = { }
				end
				self.send = send
			end
			-- exports
			local exports = info.exports
			if not (isstring(exports) or istable(exports)) then
				exports = nil
			end
			self.exports = exports
			-- imports
			local imports = info.imports
			if not (isstring(imports) or istable(imports)) then
				imports = nil
			end
			self.imports = imports
			-- dependencies
			local dependencies = info.dependencies
			if not istable(dependencies) then
				dependencies = nil
			end
			self.dependencies = dependencies
			-- description
			local description = info.description
			if not isstring(description) then
				description = "Description not provided"
			end
			self.description = description
			-- license
			local license = info.license
			if not isstring(license) then
				license = "License not provided"
			end
			self.license = license
			-- homepage
			local homepage = info.homepage
			if not isstring(homepage) then
				homepage = "Homepage not provided"
			end
			self.homepage = homepage
			-- logger
			local logger = info.logger
			if not istable(logger) then
				logger = {
					interpolation = true,
					disabled = false,
					color = default
				}
			end
			self.logger = logger
			local prefix = name .. "@" .. version:__tostring()
			local packageLogger
			if logger then
				if logger.disabled then
					packageLogger = nil
				else
					packageLogger = Logger(prefix, logger.color, logger.interpolation)
				end
			else
				packageLogger = Logger(prefix)
			end
			self.prefix = prefix .. "::"
			self.dependencies = { }
			-- package environment
			self.env = setmetatable({
				__package = self,
				Logger = packageLogger
			}, environmentMetatable)
		end
	}, {
		parse = parse,
		read = packageRead
	})
	environment.Package = packageClass
end
-- TODO: after this works as specs intended, optimize it and make better!
local esmClass, esmResolve
do
	local canParse = URL.canParse
	local IsDir = file.IsDir
	local sub = string.sub
	local DEFAULT_CONDITIONS = {
		[SERVER and "server" or CLIENT and "client" or _G.MENU_DLL and "menu" or "default"] = true
	}
	local packageResolve
	-- PACKAGE_TARGET_RESOLVE(packageURL, target, patternMatch, isImports, conditions)
	local packageTargetResolve
	packageTargetResolve = function(self, packageURL, target, patternMatch, isImports)
		if isstring(target) then
			if not StartsWith(target, "./") then
				if isImports == false or StartsWith(target, "/") or StartsWith(target, "../") or canParse(target) then
					error(PackageError("invalid target '" .. tostring(target) .. "' for '" .. tostring(packageURL) .. "'"))
					return nil
				end
				if isstring(patternMatch) then
					return packageResolve(self, gsub(target, "*", patternMatch), packageURL)
				end
				return packageResolve(self, target, packageURL)
			end
			local resolvedTarget = URL(target, packageURL)
			if patternMatch == nil then
				return resolvedTarget
			end
			-- TODO: If patternMatch split on "/" or "\" contains any "", ".", "..", or "node_modules" segments, case insensitive and including percent encoded variants, throw an Invalid Module Specifier error.
			resolvedTarget.pathname = gsub(resolvedTarget.pathname, "*", patternMatch)
			return resolvedTarget
		end
		if istable(target) then
			if #target == 0 then
				local defaultValue
				for p, targetValue in pairs(target) do
					if DEFAULT_CONDITIONS[p] then
						local resolved = packageTargetResolve(self, packageURL, targetValue, patternMatch, isImports)
						if resolved then
							return resolved
						end
					elseif p == "default" then
						defaultValue = targetValue
					end
				end
				-- resolving "default" at the end because tables in lua are unordered
				if defaultValue then
					return packageTargetResolve(self, packageURL, defaultValue, patternMatch, isImports)
				end
				return nil
			end
			-- array
			local success, resolved
			for _index_0 = 1, #target do
				local targetValue = target[_index_0]
				success, resolved = pcall(packageTargetResolve, self, packageURL, targetValue, patternMatch, isImports)
				if success and resolved then
					return resolved
				end
			end
			if not success then
				error(resolved)
				return nil
			end
			return nil
		end
		if target == nil then
			return nil
		end
		error(PackageError("invalid target '" .. tostring(target) .. "' for '" .. tostring(packageURL) .. "'"))
		return nil
	end
	local exportsStartsWithDot
	exportsStartsWithDot = function(self, exports, packageURL)
		if istable(exports) then
			local state
			for key in pairs(exports) do
				local statsWithDot = StartsWith(key, ".")
				if state == nil then
					state = statsWithDot
				elseif state ~= statsWithDot then
					error(PackageError("'" .. tostring(packageURL) .. "' exports are invalid"))
				end
			end
			return state
		end
		-- otherwise exports must be a string
		return StartsWith(exports, ".")
	end
	-- PACKAGE_IMPORTS_EXPORTS_RESOLVE(matchKey, matchObj, packageURL, isImports)
	local packageImportsExportsResolve
	packageImportsExportsResolve = function(self, matchKey, matchObj, packageURL, isImports)
		if matchObj[matchKey] and not find(matchKey, "*", 1, true) then
			local target = matchObj[matchKey]
			return packageTargetResolve(self, packageURL, target, nil, isImports)
		end
		-- TODO: Implement pattern matching
		error(PackageError("pattern matching is not implemented"))
		return nil
	end
	-- PACKAGE_EXPORTS_RESOLVE(packageURL, subpath, exports, conditions)
	local packageExportsResolve
	packageExportsResolve = function(self, packageURL, subpath, exports)
		local startsWithDot = exportsStartsWithDot(self, exports, packageURL)
		if subpath == "." then
			local mainExport
			if isstring(exports) or not startsWithDot then
				mainExport = exports
			elseif istable(exports) and startsWithDot then
				mainExport = exports["."]
			end
			if mainExport then
				local resolved = packageTargetResolve(self, packageURL, mainExport, nil, false)
				if resolved then
					return resolved
				end
			end
		elseif istable(exports) and startsWithDot then
			local resolved = packageImportsExportsResolve(self, subpath, exports, packageURL, false)
			if resolved then
				return resolved
			end
		end
		error(PackageError("no exports found for '" .. tostring(subpath) .. "' in '" .. tostring(packageURL) .. "'"))
		return nil
	end
	local packageDependencyResolve
	packageDependencyResolve = function(self, name, target, subpath)
		if not target then
			error(PackageError("invalid dependency target '" .. tostring(target) .. "' for '" .. tostring(name) .. "'"))
		end
		local packageURL = nil
		if IsURL(target) then
			local source = getSource(target)
			if not source then
				error(PackageError("source for '" .. tostring(target) .. "' not found"))
			end
			packageURL = source:WorkingDirectory(target)
		else
			-- Retrieving all version of the package
			local _, folders = Find("gpm/vfs/packages/" .. name .. "/*", LuaPath, true)
			local version = Version.select(target, folders)
			if not version then
				local versions_str = concat(folders, ", ")
				error(PackageError("could not find installed " .. tostring(name) .. " with version selector " .. tostring(target) .. " (available versions: [" .. tostring(versions_str) .. "])"))
			end
			packageURL = URL("file:///lua/gpm/vfs/packages/" .. name .. "/" .. tostring(version) .. "/")
			if not IsDir(packageURL.pathname) then
				error(PackageError(tostring(packageURL.pathname) .. " should exists but it does not :? (" .. tostring(name) .. " with target " .. tostring(target) .. ")"))
			end
		end
		local pjson = await(packageRead(packageURL))
		self.pjson = pjson
		if pjson and pjson.exports then
			return packageExportsResolve(self, packageURL, subpath, pjson.exports)
		end
		return URL(subpath, packageURL)
	end
	local packageDependenciesResolve
	packageDependenciesResolve = function(self, packageName, packageSubpath)
		-- @pjson must be set by packageSelfResolve
		local pjson = self.pjson
		if not pjson or not istable(pjson.dependencies) then
			return nil
		end
		local target = pjson.dependencies[packageName]
		if isstring(target) then
			return packageDependencyResolve(self, packageName, target, packageSubpath)
		end
		return nil
	end
	-- LOOKUP_PACKAGE_SCOPE(url)
	local lookupPackageScope
	lookupPackageScope = function(self, url)
		if url.scheme ~= "file" then
			error(PackageError("unable to lookup package scope for '" .. tostring(url) .. "' (not a file:/// URL)"))
		end
		local scopeURL
		scopeURL = URL("./package.lua", url)
		while scopeURL.path[1] ~= "package.lua" do
			if scopeURL.path[#scopeURL.path - 1] == "packages" then
				return nil
			end
			if IsFile(scopeURL.pathname) then
				return URL("./", scopeURL)
			end
			scopeURL = URL("../package.lua", scopeURL)
		end
		return nil
	end
	-- PACKAGE_SELF_RESOLVE(packageName, packageSubpath, parentURL)
	local packageSelfResolve
	packageSelfResolve = function(self, packageName, packageSubpath, parentURL)
		local packageURL = lookupPackageScope(self, parentURL)
		if not packageURL then
			return nil
		end
		local pjson = await(packageRead(packageURL))
		self.pjson = pjson
		if not (pjson and pjson.exports) then
			return nil
		end
		if pjson.name == packageName then
			return packageExportsResolve(self, packageURL, packageSubpath, pjson.exports)
		end
		return nil
	end
	-- PACKAGE_RESOLVE(packageSpecifier, parentURL)
	packageResolve = function(self, packageSpecifier, parentURL)
		local packageName
		if packageSpecifier == "" then
			error(PackageError("specifier is an empty string"))
		end
		if StartsWith(packageSpecifier, "@") then
			packageName = match(packageSpecifier, "(.-/.-)/") or packageSpecifier
			if not packageName then
				error(PackageError("invalid specifier '" .. tostring(packageSpecifier) .. "'"))
			end
		else
			packageName = match(packageSpecifier, "(.-)/") or packageSpecifier
		end
		if StartsWith(packageSpecifier, ".") or find(packageSpecifier, "%", 1, true) or find(packageSpecifier, "\\", 1, true) then
			error(PackageError("invalid specifier '" .. tostring(packageSpecifier) .. "'"))
		end
		local packageSubpath = "." .. sub(packageSpecifier, #packageName + 1)
		do
			local selfURL = packageSelfResolve(self, packageName, packageSubpath, parentURL)
			if selfURL then
				return selfURL
			end
		end
		local packageURL
		while not packageURL or packageURL.path[1] ~= "packages" do
			local firstTime = not packageURL
			packageURL = URL("packages/" .. packageName .. "/", parentURL)
			parentURL = URL("..", parentURL)
			if packageURL.scheme == "file" and not IsDir(packageURL.pathname) then
				do
					local result = firstTime and packageDependenciesResolve(self, packageName, packageSubpath)
					if result then
						return result
					end
				end
				goto _continue_0
			end
			local pjson = await(packageRead(packageURL))
			self.pjson = pjson
			if pjson and pjson.exports then
				return packageExportsResolve(self, packageURL, packageSubpath, pjson.exports)
			end
			do
				return URL(packageSubpath, packageURL)
			end
			::_continue_0::
		end
		error(PackageError("package not found: '" .. tostring(packageSpecifier) .. "' from '" .. tostring(self.parentURL) .. "'"))
		return nil
	end
	-- PACKAGE_IMPORTS_RESOLVE(specifier, parentURL, conditions)
	local packageImportsResolve
	packageImportsResolve = function(self, specifier, parentURL)
		if specifier == "#" or StartsWith(specifier, "#/") then
			error(PackageError("invalid import specifier '" .. specifier .. "'"))
		end
		local packageURL = lookupPackageScope(self, parentURL)
		if packageURL then
			local pjson = await(packageRead(packageURL))
			self.pjson = pjson
			if pjson and pjson.imports then
				local resolved = packageImportsExportsResolve(self, specifier, pjson.imports, packageURL, true)
				if resolved then
					return resolved
				end
			end
		end
		error(PackageError("imports are not defined for '" .. specifier .. "' in " .. tostring(packageURL or parentURL)))
		return nil
	end
	esmResolve = function(...)
		return esmClass():resolve(...)
	end
	esmClass = newClass("ESM", {
		resolve = async(function(self, specifier, parentURL)
			self.specifier = specifier
			self.parentURL = parentURL
			-- resolve
			local resolved
			if isurl(specifier) or canParse(specifier) then
				resolved = URL(specifier)
			elseif StartsWith(specifier, "/") or StartsWith(specifier, "./") or StartsWith(specifier, "../") then
				resolved = URL(specifier, parentURL)
			elseif StartsWith(specifier, "#") then
				resolved = packageImportsResolve(self, specifier, parentURL)
			else
				-- specifier is now a bare specifier
				resolved = packageResolve(self, specifier, parentURL)
			end
			return {
				resolved = resolved,
				package = self.pjson
			}
		end)
	}, {
		resolve = esmResolve
	})
	loader.ESM = esmClass
end
local requireClass
do
	local NotImplementedError = environment.NotImplementedError
	local PACKAGE_PATHS = {
		"./?.lua",
		"./?/init.lua"
	}
	local isRequireSyntax
	isRequireSyntax = function(modname)
		return match(modname, "^[%a%d_%-.]+$")
	end
	local resolveFile
	resolveFile = function(self, filePath, base)
		for _index_0 = 1, #PACKAGE_PATHS do
			local pattern = PACKAGE_PATHS[_index_0]
			local url = URL(gsub(pattern, "%?", filePath), base)
			if IsFile(url.pathname) then
				return url
			end
		end
		return nil
	end
	local asyncRequire
	asyncRequire = function(modname, base)
		return await(esmResolve(modname, base))
	end
	requireClass = newClass("Require", {
		resolve = async(function(self, modname, base)
			if not base then
				error(ModuleError("`require` cannot be used outside of modules"))
			end
			if base.scheme ~= "file" then
				error(NotImplementedError("cannot use `require` from `" .. tostring(base) .. "`"))
			end
			local isOpaque = isRequireSyntax(modname)
			local filePath = gsub(modname, "%.", "/")
			do
				local resolved = isOpaque and resolveFile(self, filePath, base)
				if resolved then
					return {
						resolved = resolved
					}
				end
			end
			if StartsWith(filePath, "gpm/") or StartsWith(filePath, "gmod/") then
				local protocol
				protocol, filePath = match(filePath, "^(.-)/(.*)")
				filePath = URL(protocol .. ":///" .. filePath).href
			end
			if filePath == "gpm" or filePath == "gmod" then
				filePath = filePath .. ":///"
			end
			-- success, resolved = try await esmResolve( isOpaque and filePath or modname, base )
			local success, resolved = pcall(asyncRequire, isOpaque and filePath or modname, base)
			if success then
				return resolved
			end
			-- TODO: make better errors
			error(resolved)
			return nil
		end)
	}, {
		resolve = function(...)
			return requireClass():resolve(...)
		end
	})
	loader.Require = requireClass
end
local includeClass
includeClass = newClass("Include", {
	resolve = async(function(self, fileName, base)
		if base and base.scheme == "file" then
			local resolved = URL(fileName, base)
			if resolved.path[1] == "lua" and IsFile(resolved.pathname) then
				return {
					resolved = resolved
				}
			end
		end
		local resolved = URL(fileName, "file:///lua/")
		if resolved.path[1] == "lua" and IsFile(resolved.pathname) then
			return {
				resolved = resolved
			}
		end
		return esmResolve(fileName, base)
	end)
}, {
	resolve = function(...)
		return includeClass():resolve(...)
	end
})
loader.Include = includeClass
local asyncImport, findSource
do
	local SourceError = environment.SourceError
	local Logger, isawaitable = gpm.Logger, gpm.isawaitable
	local join = path.join
	findSource = function(scheme)
		local source = sources[scheme]
		if source then
			return source
		end
		error(SourceError("Source for scheme '" .. tostring(scheme) .. "' not implemented."))
		return
	end
	loader.FindSource = findSource
	local registerSource
	registerSource = function(scheme, source)
		sources[scheme] = source
	end
	loader.RegisterSource = registerSource
	loader.Source = newClass("Source", {
		__tostring = function(self)
			return format("%s %p", self.__class.__name, self)
		end,
		new = function(self, ...)
			local _list_0 = {
				...
			}
			for _index_0 = 1, #_list_0 do
				local protocol = _list_0[_index_0]
				self:register(protocol)
			end
			if not self.FetchInfo then
				Logger:Warn("Source " .. tostring(self) .. " does not implement :FetchInfo method. May cause errors.")
			end
			if not self.Install then
				return Logger:Warn("Source " .. tostring(self) .. " does not implement :Install method. May cause errors.")
			end
		end,
		register = function(self, protocol)
			if isurl(protocol) then
				protocol = protocol.scheme
			end
			local old = sources[protocol]
			if old then
				Logger:Warn("Protocol '" .. tostring(protocol) .. "' has been reregistered by '" .. tostring(self) .. "'. (was " .. tostring(old) .. ")")
			end
			sources[protocol] = self
			return Logger:Debug("  - " .. tostring(self) .. " was registered for " .. tostring(protocol) .. ":")
		end,
		WorkingDirectory = function(self, url)
			return URL(join("file:///lua/gpm/vfs/modules/", PathFromURL(url)) .. "/")
		end
	}, {
		get = getSource
	})
	local parseFileURL
	parseFileURL = function(any)
		if isurl(any) then
			return any
		end
		if isstring(any) and IsURL(any) then
			return URL(any)
		end
	end
	loader.ParseFileURL = parseFileURL
	local getFileURL
	getFileURL = function(any)
		local url = parseFileURL(any)
		if not url then
			error(SourceError("Invalid URL: " .. tostring(any)))
			return nil
		end
		if not url.scheme then
			error(SourceError("Invalid protocol for URL: " .. tostring(any)))
			return nil
		end
		return url
	end
	loader.GetFileURL = getFileURL
	loader.FetchInfo = async(function(url, base, env, parent)
		url = getFileURL(url)
		return await(findSource(url.scheme):FetchInfo(url, base, env, parent))
	end)
	do
		local run = moduleClass.run
		local defaultBase = URL("file:///lua/")
		asyncImport = async(function(specifier, resolver, info, base, env, parent)
			local resolved, package
			do
				local _obj_0 = await(resolver(specifier, base or defaultBase))
				resolved, package = _obj_0.resolved, _obj_0.package
			end
			-- if package was found, then it must overwrite current env
			if package then
				env = package.env or env
				-- if package has dependencies, wait until they are resolved
				local dependencies = package.dependencies
				if dependencies then
					for name, dep in pairs(dependencies) do
						if isawaitable(dep) then
							await(dep)
						end
					end
				end
			end
			return await(run(resolved, env))
		end)
		loader.AsyncImport = asyncImport
	end
	local getImportMeta
	do
		local getfmain = debug.getfmain
		local rawget = _G.rawget
		local getModule
		getModule = function(func)
			if func == nil then
				func = getfmain()
			end
			local fenv = func and getfenv(func)
			if fenv then
				return rawget(fenv, "__module")
			end
		end
		loader.GetModule = getModule
		local getURL
		getURL = function(func)
			if func == nil then
				func = getfmain()
			end
			local fpath = func and getfpath(func)
			if fpath then
				do
					local fenv = getfenv(func)
					if fenv then
						local m = rawget(fenv, "__module")
						if m then
							local url = m.url
							if url then
								return url
							end
						end
					end
				end
				if IsURL(fpath) then
					return URL(fpath)
				end
				return URL("file:///" .. fpath)
			end
		end
		loader.GetURL = getURL
		local getParentURL
		getParentURL = function(m)
			if m == nil then
				m = getModule()
			end
			return m and m.url or nil
		end
		loader.GetParentURL = getParentURL
		local getEnvironment
		getEnvironment = function(m)
			if m == nil then
				m = getModule()
			end
			return m and m.env or nil
		end
		loader.GetEnvironment = getEnvironment
		local getPackage
		getPackage = function(env)
			if env == nil then
				env = getEnvironment()
			end
			return env and env.__package or nil
		end
		loader.GetPackage = getPackage
		getImportMeta = function()
			local base, parent, env
			do
				local fmain = getfmain()
				if fmain then
					do
						local m = getModule(fmain)
						if m then
							base = getParentURL(m)
							env = getEnvironment(m)
							parent = getPackage(env)
						end
					end
					base = base or getURL(fmain)
				end
			end
			return base, env, parent
		end
		loader.GetImportMeta = getImportMeta
	end
	gpm.Import = function(specifier)
		argument(specifier, 1, "string")
		return asyncImport(specifier, esmResolve, nil, getImportMeta())
	end
	-- just for a .lua users
	environment.import = function(specifier)
		argument(specifier, 1, "string")
		return await(asyncImport(specifier, esmResolve, nil, getImportMeta()))
	end
	do
		local resolve = requireClass.resolve
		environment.require = function(modname)
			argument(modname, 1, "string")
			return await(asyncImport(modname, resolve, nil, getImportMeta()))
		end
	end
	do
		local resolve = includeClass.resolve
		do
			local _tmp_0
			_tmp_0 = function(fileName)
				argument(fileName, 1, "string")
				return await(asyncImport(fileName, resolve, nil, getImportMeta()))
			end
			environment.include = _tmp_0
			environment.dofile = _tmp_0
		end
	end
end
-- packages autorun
do
	local display
	do
		local _obj_0 = environment.Error
		display = _obj_0.display
	end
	local Logger, repositories = gpm.Logger, gpm.repositories
	local all, allSettled
	do
		local _obj_0 = gpm.futures
		all, allSettled = _obj_0.all, _obj_0.allSettled
	end
	-- this one has [name@version or url] = Promise
	local dependencies = { }
	loader.Dependencies = dependencies
	-- used for reloading server if not all dependencies were installed
	local lastHumanCount = 0
	local getHumanCount
	getHumanCount = function()
		return #_G.player.GetHumans()
	end
	local installDependency, resolveDependencies
	installDependency = async(function(pkg, name, target, force)
		if not isstring(name) then
			error(PackageError("invalid dependency name '" .. tostring(name) .. "' for '" .. tostring(pkg) .. "'"))
		end
		-- caching installation so duplicate dependencies wont be installed two times
		if force ~= true then
			local ref = tostring(target)
			if not IsURL(ref) then
				ref = name .. "@" .. target
			end
			local task = dependencies[ref]
			if task then
				return task
			end
			task = Task(installDependency(pkg, name, target, true))
			dependencies[ref] = task
			if not pkg.dependencies[name] then
				pkg.dependencies[name] = task
			end
			return task
		end
		if istable(target) then
			-- handle multiple
			return nil
		end
		if not isstring(target) then
			error(PackageError("invalid dependency target '" .. tostring(target) .. "' for '" .. tostring(name) .. "' in '" .. tostring(pkg) .. "'"))
		end
		local workdir
		if not IsURL(target) then
			-- probably version
			local res = await(repositories.FindPackage(name, target))
			if not res then
				error(PackageError("could not find package '" .. tostring(name) .. "' with version '" .. tostring(target) .. "' for '" .. tostring(pkg) .. "'"))
			end
			target = res.url
			workdir = "lua/gpm/vfs/packages/" .. name .. "/" .. tostring(res.version) .. "/"
		end
		local url = URL(target)
		local source = getSource(url)
		if not source then
			error(PackageError("source for '" .. tostring(url) .. "' not found (dependency of '" .. tostring(pkg) .. "')"))
		end
		local info = await(source:FetchInfo(url))
		if source.Install then
			await(source:Install(info, workdir))
			Logger:Info("Installed dependency '%s' [%s] for '%s'", name, target, pkg.name)
		end
		pkg.dependencies[name] = info.package
		-- resolve dependencies of the dependency
		await(resolveDependencies(info.package))
		return nil
	end)
	loader.InstallDependency = installDependency
	resolveDependencies = async(function(pkg)
		if not pkg.dependencies then
			return nil
		end
		local tasks, taskCount = { }, 0
		for name, target in pairs(pkg.dependencies) do
			taskCount = taskCount + 1
			tasks[taskCount] = installDependency(pkg, name, target)
		end
		await(all(tasks))
		-- hacky way to determine if all packages were installed
		for _, task in pairs(dependencies) do
			if not task:done() then
				return nil
			end
		end
		-- alright, it seems that all dependencies were installed
		-- let's restart server if there is any humans on the servers
		if getHumanCount() > lastHumanCount then
			RunConsoleCommand("changelevel", game.GetMap())
		end
		return nil
	end)
	loader.ResolveDependencies = resolveDependencies
	local initializePackage = async(function(pkg)
		if SERVER then
			-- we are resolving dependencies only on server
			await(resolveDependencies(pkg))
			-- AddCSLuaFile in pkg.send
			local _list_0 = pkg.send
			for _index_0 = 1, #_list_0 do
				local fileName = _list_0[_index_0]
				addcsluafile(URL(fileName, pkg.url).pathname)
			end
		end
		if not pkg.autorun then
			return nil
		end
		Logger:Info("Executing '%s@%s' package...", pkg.name, pkg.version)
		await(asyncImport(pkg.name, esmResolve, nil, pkg.url, pkg.env))
		return nil
	end)
	loader.InitializePackage = initializePackage
	loader.Startup = async(function()
		if SERVER then
			lastHumanCount = getHumanCount()
		end
		Logger:Info("Parsing `packages/` directory...")
		local _, folders = Find("packages/*", LuaPath, true)
		local base = URL("file:///lua/packages/")
		local readTasks, taskCount = { }, 0
		for _index_0 = 1, #folders do
			local folderName = folders[_index_0]
			taskCount = taskCount + 1
			readTasks[taskCount] = packageRead(URL(folderName .. "/", base))
		end
		-- no :>
		local pkgs, pkgCount = { }, 0
		local _list_0 = await(allSettled(readTasks))
		for _index_0 = 1, #_list_0 do
			local result = _list_0[_index_0]
			if result.value then
				pkgCount = pkgCount + 1
				pkgs[pkgCount] = result.value
			elseif result.status == "rejected" then
				display(result.reason)
			end
		end
		if pkgCount == 0 then
			Logger:Info("No packages were found :<")
			return nil
		end
		Logger:Info("Found %d packages! Initializing them...", pkgCount)
		local tasks
		tasks, taskCount = { }, 0
		for _index_0 = 1, #pkgs do
			local pkg = pkgs[_index_0]
			taskCount = taskCount + 1
			tasks[taskCount] = initializePackage(pkg)
		end
		tasks = await(allSettled(tasks))
		for index = 1, taskCount do
			local result = tasks[index]
			if result.status == "rejected" then
				display(result.reason)
			end
		end
		return nil
	end)
end

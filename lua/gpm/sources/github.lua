local _G = _G
local pairs, tostring, gpm = _G.pairs, _G.tostring, _G.gpm
local environment, Logger = gpm.environment, gpm.Logger
local URL, Package, SourceError = environment.URL, environment.Package, environment.SourceError
local async, await = environment.async, environment.await
-- libraries
local Read, IsFile, IterateZipFiles, MountGMA, Set, Write
do
	local _obj_0 = environment.file
	Read, IsFile, IterateZipFiles, MountGMA, Set, Write = _obj_0.Read, _obj_0.IsFile, _obj_0.IterateZipFiles, _obj_0.MountGMA, _obj_0.Set, _obj_0.Write
end
local match, lower, sub, ByteSplit, IndexOf, StartsWith
do
	local _obj_0 = environment.string
	match, lower, sub, ByteSplit, IndexOf, StartsWith = _obj_0.match, _obj_0.lower, _obj_0.sub, _obj_0.ByteSplit, _obj_0.IndexOf, _obj_0.StartsWith
end
local getRepository, getTree, getBlob, fetchZip
do
	local _obj_0 = environment.github
	getRepository, getTree, getBlob, fetchZip = _obj_0.getRepository, _obj_0.getTree, _obj_0.getBlob, _obj_0.fetchZip
end
local CRC, JSONToTable, TableToJSON, ByteStream
do
	local _obj_0 = environment.util
	CRC, JSONToTable, TableToJSON, ByteStream = _obj_0.CRC, _obj_0.JSONToTable, _obj_0.TableToJSON, _obj_0.ByteStream
end
local getFile, getDirectory, join
do
	local _obj_0 = environment.path
	getFile, getDirectory, join = _obj_0.getFile, _obj_0.getDirectory, _obj_0.join
end
local GMA
do
	local _obj_0 = environment.addon
	GMA = _obj_0.GMA
end
-- constants
local CACHE_DIR = "/data/gpm/cache/github/"
-- url syntax:
-- github:user/repo[/branch]
-- or
-- github://user/repo[/branch]
local GithubSource
do
	local _class_0
	local GetDefaultBranch, PACKAGE_PATH_PRIORITIES, FindPackageInfo, FetchPackageFile, DownloadRepository, mountedRepositories
	local _parent_0 = gpm.loader.Source
	local _base_0 = {
		FetchInfo = async(function(self, url)
			-- Parse user, repo and branch from the given url
			local segments = ByteSplit(url.pathname, 0x2F)
			local hostname = url.hostname
			if hostname then
				insert(segments, 1, hostname)
			end
			local user = lower(segments[1])
			local repository = lower(segments[2])
			if not (user and user ~= "" and repository and repository ~= "") then
				error(SourceError("Invalid url '" .. tostring(url) .. "' (missing user or repository, got '" .. tostring(user) .. "' and '" .. tostring(repository) .. "')."))
			end
			local branch = segments[3] or GetDefaultBranch(user, repository)
			local packageEntry = FindPackageInfo(user, repository, branch)
			if not packageEntry then
				error(SourceError("Failed to find package file in " .. tostring(user) .. "/" .. tostring(repository) .. " (" .. tostring(branch) .. ")."))
			end
			-- Check if repository already was installed locally
			local pkg = await(Package.read(url))
			if pkg then
				return {
					package = pkg,
					url = url,
					metadata = {
						user = user,
						repository = repository,
						branch = branch,
						packageEntry = packageEntry,
						cached = true
					}
				}
			end
			local packageURL = URL(getFile(packageEntry.path), self:WorkingDirectory(url))
			local packageContent = FetchPackageFile(user, repository, branch, packageEntry)
			if not packageContent then
				error(SourceError("Failed to fetch package file from " .. tostring(url) .. "."))
			end
			-- preventing overwriting existing package file
			if not IsFile(packageURL.pathname) then
				Set(packageURL.pathname, packageContent)
			end
			pkg = await(Package.read(packageURL))
			if not pkg then
				error(SourceError("Failed to read package file from " .. tostring(packageURL) .. ". (url = " .. tostring(url) .. ")"))
			end
			return {
				package = pkg,
				url = url,
				metadata = {
					user = user,
					repository = repository,
					branch = branch,
					packageEntry = packageEntry
				}
			}
		end),
		Install = async(function(self, info, workdir)
			if not workdir then
				workdir = self:WorkingDirectory(info.url).pathname
			end
			if mountedRepositories[workdir] then
				return nil
			end
			local root = getDirectory(info.metadata.packageEntry.path)
			local rootLength = #root + 1
			local handle = DownloadRepository(info.metadata.user, info.metadata.repository, info.metadata.branch)
			-- just in case if Install was called multiple times
			if mountedRepositories[workdir] then
				return nil
			end
			Logger:Debug("Installing package '%s@%s' from Github repository '%s/%s/%s'...", info.package.name, info.package.version, info.metadata.user, info.metadata.repository, info.metadata.branch)
			local gmaPath = CACHE_DIR .. info.metadata.user .. "/" .. info.metadata.repository .. "/" .. info.metadata.branch .. "/files-" .. CRC(workdir) .. ".gma"
			if Read(gmaPath, nil, nil, nil, true) then
				if not MountGMA(gmaPath) then
					error(SourceError("Failed to mount GMA file '" .. tostring(gmaPath) .. "'."))
				end
				return nil
			end
			local gma = GMA()
			gma:SetTitle(info.url.href)
			for entry, err in IterateZipFiles(handle, false) do
				if err then
					Logger:Debug("Skipping file from zipball '%s/%s/%s' with path '%s' and reason '%s'", info.metadata.user, info.metadata.repository, info.metadata.branch, entry.path, err)
					goto _continue_0
				end
				-- first remove first directory from the path (appended by github)
				local entryPath = sub(entry.path, IndexOf(entry.path, "/") + 1)
				-- then remove the root directory
				if not StartsWith(entryPath, root) then
					goto _continue_0
				end
				entryPath = sub(entryPath, rootLength)
				if entryPath == "" then
					goto _continue_0
				end
				-- add working directory
				entryPath = join(workdir, entryPath)
				gma:SetFile(entryPath, entry.content)
				::_continue_0::
			end
			await(gma:AsyncWrite(gmaPath, true, true))
			if not MountGMA(gmaPath) then
				error(SourceError("Failed to mount GMA file '" .. tostring(gmaPath) .. "'."))
			end
			mountedRepositories[workdir] = true
			return nil
		end)
	}
	for _key_0, _val_0 in pairs(_parent_0.__base) do
		if _base_0[_key_0] == nil and _key_0:match("^__") and not (_key_0 == "__index" and _val_0 == _parent_0.__base) then
			_base_0[_key_0] = _val_0
		end
	end
	if _base_0.__index == nil then
		_base_0.__index = _base_0
	end
	setmetatable(_base_0, _parent_0.__base)
	_class_0 = setmetatable({
		__init = function(self, ...)
			return _class_0.__parent.__init(self, ...)
		end,
		__base = _base_0,
		__name = "GithubSource",
		__parent = _parent_0
	}, {
		__index = function(cls, name)
			local val = rawget(_base_0, name)
			if val == nil then
				local parent = rawget(cls, "__parent")
				if parent then
					return parent[name]
				end
			else
				return val
			end
		end,
		__call = function(cls, ...)
			local _self_0 = setmetatable({ }, _base_0)
			cls.__init(_self_0, ...)
			return _self_0
		end
	})
	_base_0.__class = _class_0
	local self = _class_0;
	GetDefaultBranch = function(user, repository)
		-- if we have local default branch, just use it and do not fetch it from github
		-- probably it wont be changed, and there is no need to recheck it every time
		local filePath = CACHE_DIR .. user .. "/" .. repository .. "/default_branch.txt"
		local branch = Read(filePath, nil, nil, nil, true)
		if branch then
			return branch
		end
		Logger:Debug("Fetching information for Github repository '%s/%s'...", user, repository)
		branch = (await(getRepository(user, repository))).default_branch
		if not branch then
			error(SourceError("Failed to fetch default branch for '" .. tostring(user) .. "/" .. tostring(repository) .. "' from Github API."))
		end
		-- save the default branch to the cache
		Write(filePath, branch, nil, nil, true)
		return branch
	end
	PACKAGE_PATH_PRIORITIES = {
		["^package%..+$"] = 10,
		["package.yue"] = 11,
		["package.moon"] = 12,
		["package.lua"] = 15,
		["package%..+"] = 20
	}
	FindPackageInfo = function(user, repository, tree_sha)
		local filePath = CACHE_DIR .. user .. "/" .. repository .. "/" .. tree_sha .. "/package.entry.json"
		local entry = JSONToTable(Read(filePath, nil, nil, nil, true) or "", true, true)
		if entry then
			return entry
		end
		Logger:Debug("Fetching file tree from Github repository '%s/%s/%s'...", user, repository, tree_sha)
		local res = await(getTree(user, repository, tree_sha, true))
		local entries = { }
		local _list_0 = res.tree
		for _index_0 = 1, #_list_0 do
			local entry = _list_0[_index_0]
			if entry.type == "blob" and match(entry.path, "package%..+$") then
				entries[#entries + 1] = entry
			end
		end
		local packageEntry = nil
		if #entries == 1 then
			packageEntry = entries[1]
		else
			-- welp, we have multiple package.lua files, lets try to find the correct one
			local priority = math.huge
			for _index_0 = 1, #entries do
				local entry = entries[_index_0]
				for pattern, p in pairs(PACKAGE_PATH_PRIORITIES) do
					if match(entry.path, pattern) then
						if pattern == entry.path then
							p = p - 10
						end
						if p < priority then
							priority = p
							packageEntry = entry
						end
					end
				end
			end
		end
		if packageEntry then
			Write(filePath, TableToJSON(packageEntry, false), nil, nil, true)
		end
		return packageEntry
	end
	FetchPackageFile = function(user, repository, branch, entry)
		local filePath = CACHE_DIR .. user .. "/" .. repository .. "/" .. branch .. "/package.txt"
		local package = Read(filePath, nil, nil, nil, true)
		if package then
			return package
		end
		Logger:Debug("Fetching package file from Github repository '%s/%s/%s'... (sha = '%s')", user, repository, branch, entry.sha)
		local res = await(getBlob(user, repository, entry.sha))
		Write(filePath, res.content, nil, nil, true)
		return res.content
	end
	DownloadRepository = function(user, repository, branch)
		local filePath = CACHE_DIR .. user .. "/" .. repository .. "/" .. branch .. "/files.zip.dat"
		local data = Read(filePath, nil, nil, nil, true)
		if data then
			return ByteStream(data)
		end
		Logger:Debug("Downloading repository '%s/%s/%s'...", user, repository, branch)
		data = await(fetchZip(user, repository, branch))
		Write(filePath, data, nil, nil, true)
		return ByteStream(data)
	end
	mountedRepositories = { }
	if _parent_0.__inherited then
		_parent_0.__inherited(_parent_0, _class_0)
	end
	GithubSource = _class_0
end
return GithubSource("github")

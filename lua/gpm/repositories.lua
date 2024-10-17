local _G = _G
local istable, gpm, tostring = _G.istable, _G.gpm, _G.tostring
local environment, Logger = gpm.environment, gpm.Logger
local table, util, CLIENT, SERVER, MENU_DLL, argument, pairs = environment.table, environment.util, environment.CLIENT, environment.SERVER, environment.MENU_DLL, environment.argument, environment.pairs
local JSONToTable, Version = util.JSONToTable, util.Version
local isSQLWorker = SERVER or MENU_DLL
local sql = isSQLWorker and gpm.sql.repositories or nil
local sort_fn
sort_fn = function(a, b)
	return a.version > b.version
end
local repositories = gpm.repositories
if not istable(repositories) then
	repositories = { }
	gpm.repositories = repositories
end
local TYPE_JSON = 0
repositories.TYPE_JSON = 0
local TYPE_GITHUB = 5
repositories.TYPE_GITHUB = 5
local list = repositories.List
if not istable(list) then
	if isSQLWorker then
		list = sql.getRepositories()
		if #list == 0 then
			sql.addRepository("https://raw.githubusercontent.com/Pika-Software/gpm-repositories/main/main.json")
			list = sql.getRepositories()
		end
		local getPackages = sql.getPackages
		for _index_0 = 1, #list do
			local repository = list[_index_0]
			repository.packages = getPackages(repository)
		end
		repositories.List = list
		if SERVER then
			environment.file.Set("/lua/gpm/vfs/repositories.lua", "return '" .. util.TableToJSON(list, false) .. "'", gpm.PREFIX .. "::Repositories")
			_G.AddCSLuaFile("lua/gpm/vfs/repositories.lua")
		end
	elseif CLIENT then
		list = JSONToTable(_G.include("gpm/vfs/repositories.lua"), true, false)
		repositories.List = list
	end
end
local getLastID
getLastID = function(tbl)
	local id = 0
	for _, value in pairs(tbl) do
		id = value.id
	end
	return id + 1
end
repositories.AddRepository = function(href)
	argument(href, 1, "string")
	if table.HasValue(list, href, true) then
		return nil
	end
	if isSQLWorker then
		sql.addRepository(href)
	end
	local index = #list + 1
	list[index] = {
		id = getLastID(list),
		packages = { },
		url = href
	}
	return index
end
repositories.RemoveRepository = function(href)
	argument(href, 1, "string")
	if not table.HasValue(list, href, true) then
		return nil
	end
	if isSQLWorker then
		sql.removeRepository(href)
	end
	return table.RemoveByValue(list, href, true)
end
local URL, async, await, futures = environment.URL, environment.async, environment.await, environment.futures
local IsURL, match, find
do
	local _obj_0 = environment.string
	IsURL, match, find = _obj_0.IsURL, _obj_0.match, _obj_0.find
end
local getRepositoryTags
do
	local _obj_0 = environment.github
	getRepositoryTags = _obj_0.getRepositoryTags
end
local CachedFetch
do
	local _obj_0 = environment.http
	CachedFetch = _obj_0.CachedFetch
end
local sort
do
	local _obj_0 = environment.table
	sort = _obj_0.sort
end
local apis = repositories.APIs
if not istable(apis) then
	apis = { }
	repositories.APIs = apis
end
apis["github.com"] = function(url, name, parent)
	local owner, repo = match(url.pathname, "^/([^/]+)/([^/]+)/?$")
	if not (owner and repo) then
		return nil
	end
	name = name or repo
	local ok, tags = pawait(getRepositoryTags(owner, repo))
	if ok then
		-- convert tags to version
		for index = 1, #tags, 1 do
			tags[index] = {
				version = Version(tags[index].name)
			}
		end
		return {
			name = name,
			url = owner .. "/" .. repo,
			type = TYPE_GITHUB,
			versions = tags
		}
	end
	return nil
end
local fetchPackages
do
	local getExtension
	do
		local _obj_0 = environment.path
		getExtension = _obj_0.getExtension
	end
	local isstring = environment.isstring
	fetchPackages = async(function(url, name)
		if not IsURL(url) then
			if IsURL(name) then
				url = name
			else
				Logger:Error("Invalid package '" .. tostring(name) .. "' URL: " .. tostring(url))
				return nil
			end
		end
		if isstring(url) then
			url = URL(url)
		end
		local fn = apis[url.hostname]
		if fn then
			return fn(url, name)
		end
		if getExtension(url.pathname) ~= "json" then
			return nil
		end
		local ok, response = pawait(CachedFetch(url.href))
		if not ok or response.status ~= 200 then
			return nil
		end
		local tbl = JSONToTable(response.body)
		if not tbl then
			return nil
		end
		local versions, length = { }, 0
		for version, href in pairs(tbl) do
			length = length + 1
			versions[length] = {
				version = Version(version),
				metadata = href
			}
		end
		return {
			name = name,
			url = "",
			type = TYPE_JSON,
			versions = versions
		}
	end)
	repositories.FetchPackages = fetchPackages
end
local syncSQL
if isSQLWorker then
	local updateRepository = sql.updateRepository
	syncSQL = function(repository)
		updateRepository(repository, repository.packages)
		return nil
	end
	repositories.SyncSQL = syncSQL
end
local performPackage
performPackage = function(repository, package)
	if not package then
		return nil
	end
	package.repositoryId = repository.id
	local name, versions = package.name, package.versions
	local packages = repository.packages
	local length = #packages
	for index = 1, length, 1 do
		local pkg = packages[index]
		if pkg.name == name then
			pkg.url = package.url
			pkg.type = package.type
			local packageVersions = pkg.versions
			local count = #versions
			for index = 1, count, 1 do
				local new, exists = versions[index], false
				for _index_0 = 1, #packageVersions do
					local exist = packageVersions[_index_0]
					if new.version == exist.version then
						exists = true
						break
					end
				end
				if not exists then
					count = count + 1
					packageVersions[count] = new
				end
			end
			sort(packageVersions, sort_fn)
			if isSQLWorker then
				syncSQL(repository)
			end
			return nil
		end
	end
	package.id = getLastID(packages)
	sort(package.versions, sort_fn)
	packages[length + 1] = package
	if isSQLWorker then
		syncSQL(repository)
	end
	return nil
end
repositories.PerformPackage = performPackage
local updateRepository = async(function(repository, map, pattern, withPattern)
	local tasks, length = { }, 0
	if pattern then
		if withPattern then
			for name, href in pairs(map) do
				if find(name, pattern, 1, false) then
					length = length + 1
					tasks[length] = fetchPackages(href, name)
				end
			end
		else
			local href = map[pattern]
			if href then
				length = 1
				tasks[1] = fetchPackages(href, pattern)
			end
		end
	else
		for name, href in pairs(map) do
			length = length + 1
			tasks[length] = fetchPackages(href, name)
		end
	end
	if length == 0 then
		return nil
	end
	if length == 1 then
		performPackage(repository, await(tasks[1]))
		return nil
	end
	local _list_0 = await(futures.allSettled(tasks))
	for _index_0 = 1, #_list_0 do
		local result = _list_0[_index_0]
		performPackage(repository, result.value)
	end
	return nil
end)
repositories.UpdateRepository = updateRepository
local searchPackages
searchPackages = function(repository, name, version, withPattern)
	local latest = version == "latest"
	local packages, count = { }, 0
	local _list_0 = repository.packages
	for _index_0 = 1, #_list_0 do
		local package = _list_0[_index_0]
		if name then
			if withPattern then
				if not find(package.name, name, 1, false) then
					goto _continue_0
				end
			elseif package.name ~= name then
				goto _continue_0
			end
		end
		local _list_1 = package.versions
		for _index_1 = 1, #_list_1 do
			local tbl = _list_1[_index_1]
			if version and not (latest or tbl.version % version) then
				goto _continue_1
			end
			count = count + 1
			packages[count] = package
			::_continue_1::
		end
		::_continue_0::
	end
	return packages
end
repositories.SearchPackages = searchPackages
local fetchRepository = async(function(repository, name, version, withPattern, offlineMode)
	local packages = repository.packages
	if not (name or version) then
		if offlineMode then
			return packages
		end
		local success, response = pawait(CachedFetch(repository.url))
		if not success or response.status ~= 200 then
			Logger:Warn("Failed to fetch repository '%s': %s", repository.url, response)
			return packages
		end
		local map = JSONToTable(response.body, true, true)
		if not map then
			return packages
		end
		await(updateRepository(repository, map, nil, false))
		return packages
	end
	if offlineMode then
		return searchPackages(repository, name, version, withPattern)
	end
	local success, response = pawait(CachedFetch(repository.url))
	if not success or response.status ~= 200 then
		Logger:Warn("Failed to fetch repository '%s': %s", repository.url, response)
		return searchPackages(repository, name, version, withPattern)
	end
	local map = JSONToTable(response.body, true, true)
	if not map then
		return searchPackages(repository, name, version, withPattern)
	end
	await(updateRepository(repository, map, name, withPattern))
	return searchPackages(repository, name, version, withPattern)
end)
repositories.FetchRepository = fetchRepository
do
	local Find
	do
		local _obj_0 = _G.file
		Find = _obj_0.Find
	end
	local formatters = repositories.Formatters
	if not istable(formatters) then
		formatters = { }
		repositories.Formatters = formatters
	end
	formatters[TYPE_GITHUB] = function(package, searchable)
		local version
		if searchable then
			local _list_0 = package.versions
			for _index_0 = 1, #_list_0 do
				local tbl = _list_0[_index_0]
				if tbl.version % searchable then
					version = tbl.version
					break
				end
			end
		else
			version = package.versions[1].version
		end
		return {
			name = package.name,
			url = "github://" .. package.url .. "/" .. tostring(version),
			version = version
		}
	end
	formatters[TYPE_JSON] = function(package, searchable)
		local url, version
		if searchable then
			local _list_0 = package.versions
			for _index_0 = 1, #_list_0 do
				local tbl = _list_0[_index_0]
				if tbl.version % searchable then
					url, version = tbl.metadata, tbl.version
					break
				end
			end
		else
			local tbl = package.versions[1]
			url, version = tbl.metadata, tbl.version
		end
		return {
			name = package.name,
			url = url,
			version = version
		}
	end
	local str_sort
	str_sort = function(a, b)
		return a < b
	end
	repositories.FindPackage = async(function(name, version, offlineMode, withPattern)
		argument(name, 1, "string")
		local packageName = name
		if withPattern then
			local _, folders = Find("gpm/vfs/packages/*", "LUA")
			for _index_0 = 1, #folders do
				local folderName = folders[_index_0]
				if find(folderName, name, 1, false) then
					packageName = folderName
					break
				end
			end
		end
		local _, versions = Find("gpm/vfs/packages/" .. packageName .. "/*", "LUA")
		if #versions > 0 then
			sort(versions, str_sort)
			local versionObj
			if version then
				argument(version, 2, "string")
				for _index_0 = 1, #versions do
					local folderName = versions[_index_0]
					versionObj = Version(folderName)
					if versionObj % version then
						break
					end
				end
			else
				versionObj = Version(versions[1])
			end
			if versionObj then
				return {
					name = packageName,
					url = "file:///lua/gpm/vfs/packages/" .. packageName .. "/" .. tostring(versionObj) .. "/",
					version = versionObj
				}
			end
		end
		for _index_0 = 1, #list do
			local repository = list[_index_0]
			local packages = await(fetchRepository(repository, name, version, withPattern, offlineMode))
			if #packages ~= 0 then
				local package = packages[1]
				local formatter = formatters[package.type] or formatters[TYPE_JSON]
				if formatter then
					return formatter(package, version)
				end
				return package
			end
		end
		return nil
	end)
end

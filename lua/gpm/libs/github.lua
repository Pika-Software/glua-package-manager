local _module_0 = { }
-- Github API library
local _G = _G
local tonumber, tostring, SysTime, error, gpm = _G.tonumber, _G.tostring, _G.SysTime, _G.error, _G.gpm
local environment = gpm.environment
local HTTP, async, await, WebClientError = environment.HTTP, environment.async, environment.await, environment.WebClientError
local Base64Decode, JSONToTable
do
	local _obj_0 = environment.util
	Base64Decode, JSONToTable = _obj_0.Base64Decode, _obj_0.JSONToTable
end
local upper, gsub, IsURL
do
	local _obj_0 = environment.string
	upper, gsub, IsURL = _obj_0.upper, _obj_0.gsub, _obj_0.IsURL
end
local sleep
do
	local _obj_0 = environment.futures
	sleep = _obj_0.sleep
end
local time
do
	local _obj_0 = environment.os
	time = _obj_0.time
end
local api_token
if SERVER then
	local convar = _G.CreateConVar("gpm_github_token", "", {
		_G.FCVAR_ARCHIVE,
		_G.FCVAR_PROTECTED,
		16
	}, "https://github.com/settings/tokens")
	_G.cvars.AddChangeCallback(convar:GetName(), function(_, __, new)
		api_token = new
	end, gpm.PREFIX .. "::Github API")
	api_token = convar:GetString()
else
	api_token = ""
end
-- https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting
local mutationNextTime = 0
local rateLimitReset = 0
local request = async(function(method, path, headers, body, cache)
	if not IsURL(path) then
		path = "https://api.github.com" .. path
	end
	headers = headers or { }
	if not headers["Authorization"] and api_token ~= "" then
		headers["Authorization"] = "Bearer " .. api_token
	end
	if not headers["Accept"] then
		headers["Accept"] = "application/vnd.github+json"
	end
	if not headers["X-GitHub-Api-Version"] then
		headers["X-GitHub-Api-Version"] = "2022-11-28"
	end
	local currentTime = time()
	if rateLimitReset > currentTime then
		local diff = rateLimitReset - currentTime
		if diff < 30 then
			await(sleep(diff))
		else
			error(WebClientError("Github API rate limit exceeded (" .. tostring(path) .. ")"))
		end
	end
	method = upper(method)
	-- Rate limit mutative requests
	if method == "POST" or method == "PATCH" or method == "PUT" or method == "DELETE" then
		local diff = mutationNextTime - SysTime()
		if diff > 0 then
			mutationNextTime = mutationNextTime + 1000
			await(sleep(diff))
		else
			mutationNextTime = SysTime() + 1000
		end
	end
	-- i believe there is no reason to implement queue, since requests are queued by the engine
	local result = await(HTTP({
		url = path,
		method = method,
		headers = headers,
		body = body,
		etag = cache ~= false,
		cache = cache ~= false
	}))
	if (result.status == 429 or result.status == 403) and headers["x-ratelimit-remaining"] == "0" then
		local reset = tonumber(headers["x-ratelimit-reset"], 10)
		if reset then
			rateLimitReset = reset
		end
		error(WebClientError("Github API rate limit exceeded (" .. tostring(result.status) .. ") (" .. tostring(path) .. ")"))
	end
	return result
end)
_module_0["request"] = request
local apiRequest = async(function(method, path, headers, body, cache)
	local result = await(request(method, path, headers, body, cache))
	if not (result.status >= 200 and result.status < 300) then
		error(WebClientError("Failed to fetch data from Github API (" .. tostring(result.status) .. ") (" .. tostring(path) .. ")"))
	end
	local data = JSONToTable(result.body, true, true)
	if not data then
		error(WebClientError("Failed to parse JSON response from Github API (" .. tostring(result.status) .. ") (" .. tostring(path) .. ")"))
	end
	return data
end)
_module_0["apiRequest"] = apiRequest
local template
template = function(path, data)
	return gsub(path, "{([%w_-]-)}", function(str)
		return tostring(data[str])
	end), nil
end
_module_0["template"] = template
local templateRequest
templateRequest = function(method, path, data)
	return apiRequest(method, template(path, data))
end
_module_0["templateRequest"] = templateRequest
local getRepository
getRepository = function(owner, repo)
	return templateRequest("GET", "/repos/{owner}/{repo}", {
		owner = owner,
		repo = repo
	})
end
_module_0["getRepository"] = getRepository
local getRepositoryTags
getRepositoryTags = function(owner, repo)
	-- TODO: implement pagination?
	return templateRequest("GET", "/repos/{owner}/{repo}/tags?per_page=100", {
		owner = owner,
		repo = repo
	})
end
_module_0["getRepositoryTags"] = getRepositoryTags
local getTree
getTree = function(owner, repo, tree_sha, recursive)
	if recursive == nil then
		recursive = false
	end
	return templateRequest("GET", "/repos/{owner}/{repo}/git/trees/{tree_sha}?recursive={recursive}", {
		owner = owner,
		repo = repo,
		tree_sha = tree_sha,
		recursive = recursive
	})
end
_module_0["getTree"] = getTree
local getBlob = async(function(owner, repo, file_sha)
	local result = await(templateRequest("GET", "/repos/{owner}/{repo}/git/blobs/{file_sha}", {
		owner = owner,
		repo = repo,
		file_sha = file_sha
	}))
	if result.encoding == "base64" then
		result.content = Base64Decode(result.content)
		result.encoding = "raw"
	end
	return result
end)
_module_0["getBlob"] = getBlob
local fetchZip = async(function(owner, repo, ref)
	local result = await(request("GET", "/repos/" .. tostring(owner) .. "/" .. tostring(repo) .. "/zipball/" .. tostring(ref)))
	if result.status ~= 200 then
		error(WebClientError("Failed to fetch zipball (" .. tostring(owner) .. "/" .. tostring(repo) .. "/" .. tostring(ref) .. ") from Github API (" .. tostring(result.status) .. ")"))
	end
	return result.body
end)
_module_0["fetchZip"] = fetchZip
return _module_0

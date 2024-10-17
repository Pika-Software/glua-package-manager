local _G = _G
local gpm, istable, tonumber, SysTime = _G.gpm, _G.istable, _G.tonumber, _G.SysTime
local environment, Logger, sql = gpm.environment, gpm.Logger, gpm.sql
local gmatch, upper, ByteSplit
do
	local _obj_0 = environment.string
	gmatch, upper, ByteSplit = _obj_0.gmatch, _obj_0.upper, _obj_0.ByteSplit
end
local await, async, argument, http, isstring, WebClientError, Future = environment.await, environment.async, environment.argument, environment.http, environment.isstring, environment.WebClientError, environment.Future
if not isstring(http.UserAgent) then
	http.UserAgent = "gLua Package Manager/" .. gpm.VERSION .. " - Garry's Mod/" .. VERSIONSTR
end
local client, clientName, returnsState, userAgentKey = _G.HTTP, "Garry's Mod", true, nil
do
	local clients = {
		{
			Name = "reqwest",
			Client = "reqwest",
			Available = SERVER,
			ReturnsState = false,
			UserAgentKey = "User-Agent"
		},
		{
			Name = "chttp",
			Client = "CHTTP",
			Available = CLIENT or SERVER,
			ReturnsState = false
		}
	}
	for _index_0 = 1, #clients do
		local item = clients[_index_0]
		if item.Available and (util.IsBinaryModuleInstalled(item.Name) and pcall(require, item.Name)) then
			client, clientName, returnsState, userAgentKey = _G[item.Client], item.Name, item.ReturnsState, item.UserAgentKey
			break
		end
	end
	Logger:Info("'%s' was connected as HTTP client.", clientName)
end
local HTTP
do
	local defaultTimeout, globalCacheLifetime = 10, 30 * 60
	do
		local CreateConVar = _G.CreateConVar
		local flags = _G.bit.bor(_G.FCVAR_ARCHIVE, _G.FCVAR_REPLICATED)
		defaultTimeout = CreateConVar("http_timeout", "10", flags, "Default http timeout for gpm http library.", 3, 300):GetInt()
		globalCacheLifetime = CreateConVar("gpm_http_cache_lifetime", "30", flags, "Cache lifetime for gpm http library in minutes."):GetInt() * 60
	end
	do
		local AddChangeCallback
		do
			local _obj_0 = environment.cvars
			AddChangeCallback = _obj_0.AddChangeCallback
		end
		AddChangeCallback("http_timeout", function(_, __, new)
			defaultTimeout = tonumber(new, 10)
		end, gpm.PREFIX .. "::HTTP")
		AddChangeCallback("gpm_http_cache_lifetime", function(_, __, new)
			globalCacheLifetime = tonumber(new, 10) * 60
		end, gpm.PREFIX .. "::HTTP")
	end
	local requestCache = {
		["GET"] = { },
		["POST"] = { },
		["HEAD"] = { },
		["PUT"] = { },
		["DELETE"] = { },
		["PATCH"] = { },
		["OPTIONS"] = { }
	}
	local isValidCache
	isValidCache = function(cache)
		return (SysTime() - cache.start) < (cache.age or globalCacheLifetime or 0)
	end
	do
		local methods = {
			"GET",
			"POST",
			"HEAD",
			"PUT",
			"DELETE",
			"PATCH",
			"OPTIONS"
		}
		local pairs = _G.pairs
		_G.timer.Create(gpm.PREFIX .. "::HTTP", 60, 0, function()
			for _index_0 = 1, #methods do
				local method = methods[_index_0]
				local requests = requestCache[method]
				for href, cache in pairs(requests) do
					if not isValidCache(cache) then
						requests[href] = nil
					end
				end
			end
		end)
	end
	local request
	request = function(self, parameters)
		if client(parameters) or not returnsState then
			Logger:Debug("%s HTTP request to '%s', using '%s', with timeout %d seconds.", parameters.method, parameters.url, clientName, parameters.timeout)
		else
			parameters.failed("failed to initiate http request")
		end
		return nil
	end
	local queue = { }
	_G.timer.Simple(0, function()
		for _index_0 = 1, #queue do
			local func = queue[_index_0]
			func()
		end
		queue = nil
	end)
	local get, set
	do
		local _obj_0 = sql.http_cache
		get, set = _obj_0.get, _obj_0.set
	end
	local isnumber = environment.isnumber
	HTTP = function(parameters)
		argument(parameters, 1, "table")
		local fut = Future()
		if not isstring(parameters.method) then
			parameters.method = "GET"
		end
		if not isnumber(parameters.timeout) then
			parameters.timeout = defaultTimeout
		end
		if userAgentKey then
			if not istable(parameters.headers) then
				parameters.headers = { }
			end
			parameters.headers[userAgentKey] = http.UserAgent
		end
		parameters.success = function(status, body, headers)
			fut:setResult({
				status = status,
				body = body,
				headers = headers
			})
			return nil
		end
		parameters.failed = function(msg)
			fut:setError(WebClientError(msg))
			return nil
		end
		-- Cache extension
		if parameters.cache then
			local url = parameters.url
			local method = upper(parameters.method)
			if not requestCache[method] then
				requestCache[method] = { }
			end
			local cache = requestCache[method][url]
			if cache and isValidCache(cache) then
				return cache.fut
			end
			cache = {
				fut = fut,
				start = SysTime(),
				age = parameters.cacheLifetime
			}
			requestCache[method][url] = cache
			local success = parameters.success
			parameters.success = function(status, body, headers)
				local cacheControl = headers["cache-control"]
				if cacheControl then
					local options = { }
					for key, value in gmatch(cacheControl, "([%w_-]+)=?([%w_-]*)") do
						options[key] = tonumber(value, 10) or true
					end
					if options["no-cache"] or options["no-store"] then
						requestCache[method][url] = nil
					elseif options["s-maxage"] or options["max-age"] then
						cache.age = options["s-maxage"] or options["max-age"]
					end
				end
				success(status, body, headers)
				return nil
			end
			local failed = parameters.failed
			parameters.failed = function(msg)
				requestCache[method][url] = nil
				failed(msg)
				return nil
			end
		end
		-- ETag extension
		if parameters.etag then
			local url = parameters.url
			local data = get(url)
			if data then
				if not istable(parameters.headers) then
					parameters.headers = { }
				end
				parameters.headers["If-None-Match"] = data.etag
			end
			local success = parameters.success
			parameters.success = function(status, body, headers)
				if status == 304 then
					body = data.content
					status = 200
				elseif status == 200 and headers["etag"] then
					set(url, headers["etag"], body)
				end
				success(status, body, headers)
				return nil
			end
		end
		if queue then
			queue[#queue + 1] = function()
				return request(fut, parameters)
			end
		else
			request(fut, parameters)
		end
		return fut
	end
	environment.HTTP = HTTP
end
-- https://github.com/luvit/luvit/blob/master/deps/http-codec.lua
-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
-- https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
local statusCodes = setmetatable({
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[207] = "Multi-Status",
	[208] = "Already Reported",
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Moved Temporarily",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[307] = "Temporary Redirect",
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Time-out",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Request Entity Too Large",
	[414] = "Request-URI Too Large",
	[415] = "Unsupported Media Type",
	[416] = "Requested Range Not Satisfiable",
	[417] = "Expectation Failed",
	[418] = "I'm a teapot",
	[422] = "Unprocessable Entity",
	[423] = "Locked",
	[424] = "Failed Dependency",
	[425] = "Unordered Collection",
	[426] = "Upgrade Required",
	[428] = "Precondition Required",
	[429] = "Too Many Requests",
	[431] = "Request Header Fields Too Large",
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Time-out",
	[505] = "HTTP Version not supported",
	[506] = "Variant Also Negotiates",
	[507] = "Insufficient Storage",
	[508] = "Loop Detected",
	[509] = "Bandwidth Limit Exceeded",
	[510] = "Not Extended",
	[511] = "Network Authentication Required"
}, {
	__index = function()
		return "Unknown"
	end
})
http.StatusCodes = statusCodes
do
	local concat, LowerKeyNames, Flip
	do
		local _obj_0 = environment.table
		concat, LowerKeyNames, Flip = _obj_0.concat, _obj_0.LowerKeyNames, _obj_0.Flip
	end
	local stripFile, stripExtension
	do
		local _obj_0 = environment.path
		stripFile, stripExtension = _obj_0.stripFile, _obj_0.stripExtension
	end
	local MountZIPData
	do
		local _obj_0 = environment.file
		MountZIPData = _obj_0.MountZIPData
	end
	local error, URL = environment.error, environment.URL
	local GMA
	do
		local _obj_0 = environment.addon
		GMA = _obj_0.GMA
	end
	http.Fetch = function(url, headers, timeout)
		return HTTP({
			url = url,
			method = "GET",
			headers = headers,
			timeout = timeout
		})
	end
	http.Post = function(url, parameters, headers, timeout)
		return HTTP({
			url = url,
			method = "POST",
			headers = headers,
			timeout = timeout,
			parameters = parameters
		})
	end
	local cachedFetch
	cachedFetch = function(url, headers, timeout, cacheLifetime)
		return HTTP({
			url = url,
			method = "GET",
			headers = headers,
			timeout = timeout,
			cache = true,
			cacheLifetime = cacheLifetime
		})
	end
	http.CachedFetch = cachedFetch
	http.CachedPost = function(url, parameters, headers, timeout, cacheLifetime)
		return HTTP({
			url = url,
			method = "POST",
			headers = headers,
			timeout = timeout,
			parameters = parameters,
			cache = true,
			cacheLifetime = cacheLifetime
		})
	end
	http.FileInfo = async(function(href, headers, timeout)
		local directoryPath, fileName = stripFile(URL(href).pathname)
		local result = await(HTTP({
			url = href,
			method = "HEAD",
			headers = headers,
			timeout = timeout
		}))
		if result.status ~= 200 then
			error(WebClientError("request failed " .. href .. " ( " .. statusCodes[result.status] .. " [" .. result.status .. "] )"))
			return nil
		end
		headers = LowerKeyNames(result.headers)
		return {
			size = headers["content-length"],
			type = headers["content-type"],
			directory = directoryPath,
			file = fileName
		}
	end)
	local materialExtensions = {
		["vtf"] = true,
		["vmt"] = true,
		["png"] = true,
		["jpg"] = true,
		["jpeg"] = true
	}
	local soundExtensions = {
		["mp3"] = true,
		["wav"] = true,
		["ogg"] = true
	}
	local otherExtensions = {
		["txt"] = true,
		["dat"] = true,
		["json"] = true,
		["xml"] = true,
		["csv"] = true,
		["dem"] = true,
		["vcd"] = true
	}
	http.Download = async(function(url, headers, timeout)
		if isstring(url) then
			url = URL(url)
		end
		local result = await(cachedFetch(url.href, headers, timeout))
		if result.status ~= 200 then
			error(WebClientError("request failed " .. url.href .. " (" .. statusCodes[result.status] .. " [" .. result.status .. "] )"))
			return nil
		end
		local filePath, extension = stripExtension(url.pathname)
		if extension == "gma" then
			local gma = GMA(result.body, true)
			if not gma:VerifyCRC() then
				error(WebClientError("Invalid CRC checksum for '" .. url.href .. "'"))
			end
			gma:SetTitle(url.href)
			return await(gma:AsyncMount(false))
		end
		if extension == "zip" then
			return MountZIPData(result.body, url.href)
		end
		filePath = concat(Flip(ByteSplit(url.hostname, 0x2E)), "/") .. filePath .. "."
		if extension == "lua" then
			filePath = "lua/gpm/downloads/" .. filePath .. extension
		elseif soundExtensions[extension] then
			filePath = "sound/gpm/downloads/" .. filePath .. extension
		elseif materialExtensions[extension] then
			filePath = "materials/gpm/downloads/" .. filePath .. extension
		elseif otherExtensions[extension] then
			filePath = "data_static/gpm/downloads/" .. filePath .. extension
		else
			filePath = "data_static/gpm/downloads/" .. filePath .. extension .. ".dat"
		end
		local gma = GMA()
		gma:SetTitle(url.href)
		gma:AddFile(filePath, result.body, false)
		await(gma:AsyncMount(false))
		return filePath
	end)
end

local _G = _G
local SERVER, istable = _G.SERVER, _G.istable
local Find
do
	local _obj_0 = _G.file
	Find = _obj_0.Find
end
local gpm = _G.gpm
if not istable(gpm) then
	local VERSION = "2.0.0"
	gpm = {
		VERSION = VERSION,
		PREFIX = "gpm@" .. VERSION
	}
	_G.gpm = gpm
end
if SERVER then
	local AddCSLuaFile = _G.AddCSLuaFile
	local _list_0 = Find("gpm/libs/*.lua", "lsv")
	for _index_0 = 1, #_list_0 do
		local fileName = _list_0[_index_0]
		AddCSLuaFile("gpm/libs/" .. fileName)
	end
	local _list_1 = Find("gpm/libs/3rd-party/*.lua", "lsv")
	for _index_0 = 1, #_list_1 do
		local fileName = _list_1[_index_0]
		AddCSLuaFile("gpm/libs/3rd-party/" .. fileName)
	end
	local _list_2 = Find("gpm/sources/*.lua", "lsv")
	for _index_0 = 1, #_list_2 do
		local fileName = _list_2[_index_0]
		AddCSLuaFile("gpm/sources/" .. fileName)
	end
	AddCSLuaFile("gpm/repositories.lua")
	AddCSLuaFile("gpm/transport.lua")
	AddCSLuaFile("gpm/post-util.lua")
	AddCSLuaFile("gpm/loader.lua")
	AddCSLuaFile("gpm/init.lua")
	AddCSLuaFile("gpm/util.lua")
	AddCSLuaFile("gpm/sql.lua")
end
gpm.StartTime = SysTime()
do
	local username = cvars and cvars.String(SERVER and "hostname" or "name", "unknown user") or "unknown"
	local splashes = {
		"eW91dHViZS5jb20vd2F0Y2g/dj1kUXc0dzlXZ1hjUQ==",
		"I'm not here to tell you how great I am!",
		"We will have a great Future together.",
		"I'm here to show you how great I am!",
		"Millions of pieces without a tether",
		"Why are we always looking for more?",
		"Don't worry, " .. username .. " :>",
		"Never forget to finish your tasks!",
		"T2gsIHlvdSdyZSBhIHNtYXJ0IG9uZS4=",
		"Take it in and breathe the light",
		"Big Brother is watching you",
		"Hello, " .. username .. "!",
		"I'll make you a promise.",
		"Flying over rooftops...",
		"We need more packages!",
		"Play SOMA sometime;",
		"Where's fireworks!?",
		"Looking For More ♪",
		"Now on Yuescript!",
		"I'm watching you.",
		"Faster than ever.",
		"Love Wins Again ♪",
		"v" .. gpm.VERSION,
		"Blazing fast ☄",
		"Here For You ♪",
		"Good Enough ♪",
		"Hello World!",
		"Star Glide ♪",
		"Once Again ♪",
		"Data Loss ♪",
		"Sandblast ♪",
		"That's me!",
		"I see you.",
		"Light Up ♪"
	}
	local count = #splashes + 1
	splashes[count] = "Wow, here more " .. (count - 1) .. " splashes!"
	local splash = splashes[math.random(1, count)]
	for i = 1, (25 - #splash) / 2 do
		if i % 2 == 1 then
			splash = splash .. " "
		end
		splash = " " .. splash
	end
	_G.print(_G.string.format("\n                                     ___          __            \n                                   /'___`\\      /'__`\\          \n     __    _____     ___ ___      /\\_\\ /\\ \\    /\\ \\/\\ \\         \n   /'_ `\\ /\\ '__`\\ /' __` __`\\    \\/_/// /__   \\ \\ \\ \\ \\        \n  /\\ \\L\\ \\\\ \\ \\L\\ \\/\\ \\/\\ \\/\\ \\      // /_\\ \\ __\\ \\ \\_\\ \\   \n  \\ \\____ \\\\ \\ ,__/\\ \\_\\ \\_\\ \\_\\    /\\______//\\_\\\\ \\____/   \n   \\/___L\\ \\\\ \\ \\/  \\/_/\\/_/\\/_/    \\/_____/ \\/_/ \\/___/    \n     /\\____/ \\ \\_\\                                          \n     \\_/__/   \\/_/                %s                        \n\n  GitHub: https://github.com/Pika-Software\n  Discord: https://discord.gg/Gzak99XGvv\n  Website: https://p1ka.eu\n  Developers: Pika Software\n  License: MIT\n", splash))
end
local environment = gpm.environment
if not istable(environment) then
	environment = { }
	gpm.environment = environment
end
local sandboxMetatable
do
	local getmetatable, setmetatable, rawset = _G.getmetatable, _G.setmetatable, _G.rawset
	environment.CLIENT = _G.CLIENT == true
	environment.SERVER = _G.SERVER == true
	environment.MENU = _G.MENU_DLL == true
	environment._G = environment
	local sandbox
	sandbox = function(tbl)
		return setmetatable({ }, sandboxMetatable(tbl))
	end
	sandboxMetatable = function(parent)
		return {
			__sandbox = true,
			__index = function(child, key)
				local value = parent[key]
				if istable(value) then
					local metatable = getmetatable(value)
					if not metatable or metatable.__sandbox then
						local sbox = sandbox(value)
						rawset(child, key, sbox)
						return sbox
					end
				end
				return value
			end
		}
	end
	setmetatable(environment, sandboxMetatable(_G))
	setmetatable(gpm, {
		__index = environment
	})
	local table = environment.table
	table.SandboxMetatable = sandboxMetatable
	table.Sandbox = sandbox
end
local include = _G.include
include("gpm/util.lua")
local Logger = include("gpm/libs/logger.lua")
environment.path = include("gpm/libs/path.lua")
-- gm_error
for key, value in _G.pairs(include("gpm/libs/error.lua")) do
	environment[key] = value
end
environment.utf8 = setmetatable(include("gpm/libs/utf8.lua"), sandboxMetatable(_G.utf8))
environment.struct = include("gpm/libs/struct.lua")
include("gpm/libs/3rd-party/bigint.lua")
include("gpm/libs/date.lua")
-- LibDeflate
local deflate = include("gpm/libs/3rd-party/deflate.lua")
Logger:Info("LibDeflate v%s loaded.", deflate._VERSION)
environment.deflate = deflate
-- task system (async, await, Futures)
include("gpm/libs/futures.lua")
-- gm_url
do
	local url = include("gpm/libs/url.lua")
	environment.IsURLSearchParams = url.IsURLSearchParams
	environment.URLSearchParams = url.URLSearchParams
	environment.isurl = url.IsURL
	environment.URL = url.URL
	local http = environment.http
	http.EncodeURIComponent = url.encodeURIComponent
	http.DecodeURIComponent = url.decodeURIComponent
	http.EncodeURI = url.encodeURI
	http.DecodeURI = url.decodeURI
end
include("gpm/post-util.lua")
include("gpm/sql.lua")
gpm.sql.migrate("initial file table")
include("gpm/libs/file.lua")
include("gpm/libs/http.lua")
include("gpm/libs/net.lua")
-- Github API
environment.github = include("gpm/libs/github.lua")
-- Lua Transport
include("gpm/transport.lua")
-- Plugins
local _list_0 = Find("gpm/plugins/*.lua", "LUA")
for _index_0 = 1, #_list_0 do
	local fileName = _list_0[_index_0]
	include("gpm/plugins/" .. fileName)
end
-- Package Manager
include("gpm/repositories.lua")
include("gpm/loader.lua")
if SERVER then
	include("gpm/cli.lua")
end
-- Code Sources
local _list_1 = Find("gpm/sources/*.lua", "LUA")
for _index_0 = 1, #_list_1 do
	local fileName = _list_1[_index_0]
	include("gpm/sources/" .. fileName)
end
-- our little sandbox ( TODO: remove on release )
if SERVER then
	include("gpm/test.lua")
end
environment.futures.run(gpm.loader.Startup())
Logger:Info("Start-up time: %.4f sec.", SysTime() - gpm.StartTime)
return gpm

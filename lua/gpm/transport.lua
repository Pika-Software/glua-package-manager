local _G = _G
local gpm = _G.gpm
local environment, Logger = gpm.environment, gpm.Logger
if _G.SERVER then
	local transport = rawget(gpm, "Transport")
	if not istable(transport) then
		transport = { }
		rawset(gpm, "Transport", transport)
	end
	transport.legacy = _G.AddCSLuaFile
	transport.net = function(filePath)
		return nil
	end
	local selected = transport[_G.CreateConVar("gpm_lua_transport", "legacy", _G.FCVAR_ARCHIVE, "Selected Lua transport"):GetString()] or transport.legacy
	_G.cvars.AddChangeCallback("gpm_lua_transport", function(_, __, str)
		selected = transport[str] or transport.legacy
	end, gpm.PREFIX .. "::Lua Transport:")
	gpm.SendFile = function(filePath)
		Logger:Debug("Sending file '" .. filePath .. "' to client...")
		return selected(filePath)
	end
else
	gpm.SendFile = environment.debug.fempty
end

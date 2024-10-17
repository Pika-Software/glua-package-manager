local _G = _G
local gpm = _G.gpm
local environment, Logger = gpm.environment, gpm.Logger
local concommand = environment.concommand
-- just in case :>
if not concommand then
	return
end
local lower, StartsWith
do
	local _obj_0 = environment.string
	lower, StartsWith = _obj_0.lower, _obj_0.StartsWith
end
local concat, remove
do
	local _obj_0 = environment.table
	concat, remove = _obj_0.concat, _obj_0.remove
end
local pairs = environment.pairs
local Add = concommand.Add
local commands = {
	install = {
		help = "Install a package",
		call = function(args) end,
		hint = function(args) end
	},
	uninstall = {
		help = "Remove a package",
		call = function(args) end,
		hint = function(args) end
	},
	reload = {
		help = "Reload a package",
		call = function(args) end,
		hint = function(args) end
	},
	run = {
		help = "Run arbitrary package scripts",
		call = function(args) end,
		hint = function(args) end
	},
	update = {
		help = "Updates package list from repositories",
		call = function(args) end,
		hint = function(args) end
	},
	upgrade = {
		help = "WIP",
		call = function(args) end,
		hint = function(args) end
	},
	purge = {
		help = "WIP",
		call = function(args) end,
		hint = function(args) end
	},
	pull = {
		help = "WIP",
		call = function(args) end,
		hint = function(args) end
	},
	list = {
		help = "Lists installed packages",
		call = function(args)
			local lines, count = { }, 0
			for name, versions in pairs(gpm.Packages) do
				local buffer, length = { }, 0
				for version in pairs(versions) do
					length = length + 1
					buffer[length] = version:__tostring()
				end
				count = count + 1
				lines[count] = count .. ". " .. name .. ": " .. concat(buffer, ", ", 1, length)
			end
			count = count + 1
			lines[count] = "Total: " .. count
			Logger:Info("Package list:\n" .. concat(lines, "\n", 1, count))
			return nil
		end
	},
	info = {
		help = "Shows information about the package manager",
		call = function(args) end,
		hint = function(args) end
	},
	search = {
		help = "Search for packages in repositories",
		call = function(args) end,
		hint = function(args) end
	}
}
local list = { }
for name in pairs(commands) do
	list[#list + 1] = "gpm " .. name
end
do
	local helpList = { }
	commands.help = {
		help = "Shows this help",
		call = function(_, args)
			local cmd = args[1]
			if cmd then
				cmd = lower(cmd)
				local command = commands[cmd]
				if command then
					local help = command.help
					if help then
						Logger:Info("help (%s): %s.", cmd, help)
						return nil
					end
				end
			else
				cmd = "none"
			end
			Logger:Warn("help (%s): No help found.", cmd)
			return nil
		end,
		hint = function(args)
			local str = args[1]
			if not str then
				return helpList
			end
			str = "gpm help " .. lower(str)
			local suggestions, length = { }, 0
			for _index_0 = 1, #helpList do
				local name = helpList[_index_0]
				if StartsWith(name, str) then
					length = length + 1
					suggestions[length] = name
				end
			end
			if length == 0 then
				return nil
			end
			return suggestions
		end
	}
	for name in pairs(commands) do
		helpList[#helpList + 1] = "gpm help " .. name
	end
end
return Add("gpm", function(ply, _, args)
	local command
	if #args ~= 0 then
		command = commands[lower(remove(args, 1))]
	end
	if command then
		command.call(ply, args)
	end
	return nil
end, function(_, __, args)
	local str = args[1]
	if not str then
		return list
	end
	local cmd = lower(remove(args, 1))
	str = "gpm " .. cmd
	local suggestions, length = { }, 0
	for _index_0 = 1, #list do
		local name = list[_index_0]
		if name == str then
			suggestions = nil
			break
		elseif StartsWith(name, str) then
			length = length + 1
			suggestions[length] = name
		end
	end
	if suggestions and length ~= 0 then
		return suggestions
	end
	local command = commands[cmd]
	if command then
		local func = command.hint
		if func then
			return func(args)
		end
	end
	return nil
end, gpm.PREFIX)

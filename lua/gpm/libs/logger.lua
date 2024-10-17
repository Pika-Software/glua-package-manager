local _G = _G
local date
do
	local _obj_0 = _G.os
	date = _obj_0.date
end
local gpm, tostring, MsgC = _G.gpm, _G.tostring, _G.MsgC
local environment, IsInDebug = gpm.environment, gpm.IsInDebug
local format, gsub, sub, len
do
	local _obj_0 = environment.string
	format, gsub, sub, len = _obj_0.format, _obj_0.gsub, _obj_0.sub, _obj_0.len
end
local Color, argument, color_white = environment.Color, environment.argument, environment.color_white
local dateScheme = _G.CreateConVar("gpm_logger_date", "0", _G.FCVAR_ARCHIVE, "Allows the logger to display date.", 0, 1):GetBool() and "%d-%m-%Y %H:%M:%S " or "%H:%M:%S "
_G.cvars.AddChangeCallback("gpm_logger_date", function(_, __, new)
	dateScheme = (new == "1" and "%d-%m-%Y %H:%M:%S " or "%H:%M:%S ")
end, gpm.PREFIX .. "::Logger")
local primaryTextColor = Color(200, 200, 200)
local secondaryTextColor = Color(150, 150, 150)
local info = Color(70, 135, 255)
local warn = Color(255, 130, 90)
local error = Color(250, 55, 40)
local debug = Color(0, 200, 150)
local state, stateColor
if MENU_DLL then
	state = "[Main Menu] "
	stateColor = Color(75, 175, 80)
elseif CLIENT then
	state = "[ Client ]  "
	stateColor = Color(225, 170, 10)
elseif SERVER then
	state = "[ Server ]  "
	stateColor = Color(5, 170, 250)
else
	state = "[ Unknown ] "
	stateColor = color_white
end
local log
log = function(self, color, level, str, ...)
	if self.interpolation then
		local args = {
			...
		}
		for index = 1, #args do
			args[tostring(index)] = tostring(args[index])
		end
		str = gsub(str, "{([0-9]+)}", args)
	else
		str = format(str, ...)
	end
	local title = self.title
	local titleLength = len(title)
	if titleLength > 64 then
		title = sub(title, 1, 64)
		titleLength = 64
		self.title = title
	end
	if (len(str) + titleLength) > 950 then
		str = sub(str, 1, 950 - titleLength) .. "..."
	end
	MsgC(secondaryTextColor, date(dateScheme), stateColor, state, color, level, secondaryTextColor, " --> ", self.title_color, title, secondaryTextColor, " : ", self.text_color, str .. "\n")
	return nil
end
local loggerClass = environment.class("Logger", {
	__tostring = function(self)
		return format("Logger: %p [%s]", self, self.title)
	end,
	new = function(self, title, title_color, interpolation, debug_func)
		argument(title, 1, "string")
		self.title = title
		if title_color then
			argument(title_color, 2, "Color")
			self.title_color = title_color
		else
			self.title_color = color_white
		end
		if interpolation == nil then
			self.interpolation = true
		else
			self.interpolation = interpolation == true
		end
		if debug_func then
			argument(debug_func, 1, "function")
			self.IsInDebug = debug_func
		else
			self.IsInDebug = IsInDebug
		end
		self.text_color = primaryTextColor
		return nil
	end,
	Log = log,
	Info = function(self, ...)
		log(self, info, "INFO ", ...)
		return nil
	end,
	Warn = function(self, ...)
		log(self, warn, "WARN ", ...)
		return nil
	end,
	Error = function(self, ...)
		log(self, error, "ERROR", ...)
		return nil
	end,
	Debug = function(self, ...)
		if self:IsInDebug() then
			log(self, debug, "DEBUG", ...)
		end
		return nil
	end
})
environment.util.Logger = loggerClass
local logger = loggerClass(gpm.PREFIX, environment.Color(180, 180, 255), false)
gpm.Logger = logger
return logger

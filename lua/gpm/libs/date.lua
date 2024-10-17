local _G = _G
local environment
do
	local _obj_0 = _G.gpm
	environment = _obj_0.environment
end
local pairs, error, tonumber, tostring, setmetatable = _G.pairs, _G.error, _G.tonumber, _G.tostring, _G.setmetatable
local format, lower, rep, len, sub, gsub, gmatch, find
do
	local _obj_0 = environment.string
	format, lower, rep, len, sub, gsub, gmatch, find = _obj_0.format, _obj_0.lower, _obj_0.rep, _obj_0.len, _obj_0.sub, _obj_0.gsub, _obj_0.gmatch, _obj_0.find
end
local band, bor, lshift, rshift
do
	local _obj_0 = environment.bit
	band, bor, lshift, rshift = _obj_0.band, _obj_0.bor, _obj_0.lshift, _obj_0.rshift
end
local floor, abs, trunc, fdiv
do
	local _obj_0 = environment.math
	floor, abs, trunc, fdiv = _obj_0.floor, _obj_0.abs, _obj_0.trunc, _obj_0.fdiv
end
local time, date
do
	local _obj_0 = environment.os
	time, date = _obj_0.time, _obj_0.date
end
local unpack
do
	local _obj_0 = environment.table
	unpack = _obj_0.unpack
end
local type = environment.type
-- < CONSTANTS >
local HOURS = 24
local MINUTES = 60
local SECONDS = 60
local MILLISECONDS = 1000
local DAYMINUTES = HOURS * MINUTES
local DAYSECONDS = DAYMINUTES * SECONDS
local DAYMILLISECONDS = DAYSECONDS * MILLISECONDS
local HOURSECONDS = MINUTES * SECONDS
local HOURMILLISECONDS = HOURSECONDS * MILLISECONDS
local MINUTEMILLISECONDS = SECONDS * MILLISECONDS
local DAYNUM_MAX = 365242500
local DAYNUM_MIN = -365242500
local DAYNUM_DEF = 0
local CENTURYFLIP = 0
-- removes the decimal part of a number
local truncString
truncString = function(str)
	local n = tonumber(str, 10)
	return n and trunc(n)
end
-- is `str` in string list `tbl`, `ml` is the minimun len
local inlist
inlist = function(str, tbl, min_length, tn)
	local length = len(str)
	if length < (min_length or 0) then
		return nil
	end
	str = lower(str)
	for key, value in pairs(tbl) do
		if str == lower(sub(value, 1, length)) then
			if tn then
				tn[0] = key
			end
			return key
		end
	end
end
--[[ DATE FUNCTIONS ]]
local sl_weekdays = {
	[00] = "Sunday",
	[01] = "Monday",
	[02] = "Tuesday",
	[03] = "Wednesday",
	[04] = "Thursday",
	[05] = "Friday",
	[06] = "Saturday",
	[07] = "Sun",
	[08] = "Mon",
	[09] = "Tue",
	[10] = "Wed",
	[11] = "Thu",
	[12] = "Fri",
	[13] = "Sat"
}
local sl_meridian = {
	[-1] = "AM",
	[01] = "PM"
}
local sl_months = {
	[00] = "January",
	[01] = "February",
	[02] = "March",
	[03] = "April",
	[04] = "May",
	[05] = "June",
	[06] = "July",
	[07] = "August",
	[08] = "September",
	[09] = "October",
	[10] = "November",
	[11] = "December",
	[12] = "Jan",
	[13] = "Feb",
	[14] = "Mar",
	[15] = "Apr",
	[16] = "May",
	[17] = "Jun",
	[18] = "Jul",
	[19] = "Aug",
	[20] = "Sep",
	[21] = "Oct",
	[22] = "Nov",
	[23] = "Dec"
}
-- added the ".2"  to avoid collision, use `fix` to remove
local sl_timezone = {
	[000] = "utc",
	[0.2] = "gmt",
	[300] = "est",
	[240] = "edt",
	[360] = "cst",
	[300.2] = "cdt",
	[420] = "mst",
	[360.2] = "mdt",
	[480] = "pst",
	[420.2] = "pdt"
}
-- is year year leap year?
-- year must be int!
local isleapyear
isleapyear = function(year)
	return (year % 4) == 0 and ((year % 100) ~= 0 or (year % 400) == 0)
end
-- day since year 0
-- year must be int!
local dayfromyear
dayfromyear = function(year)
	return 365 * year + floor(year / 4) - floor(year / 100) + floor(year / 400)
end
-- day number from date, month is zero base
local makedaynum
makedaynum = function(year, month, day)
	local month_offset = ((month % 12) + 10) % 12
	return dayfromyear(year + floor(month / 12) - floor(month_offset / 10)) + floor((month_offset * 306 + 5) / 10) + day - 307
end
-- date from day number, month is zero base
local breakdaynum
breakdaynum = function(g)
	g = g + 306
	local year = floor((10000 * g + 14780) / 3652425)
	local day = g - dayfromyear(year)
	if day < 0 then
		year = year - 1
		day = g - dayfromyear(year)
	end
	local mi = floor((100 * day + 52) / 3060)
	return floor((mi + 2) / 12) + year, (mi + 2) % 12, day - floor((mi * 306 + 5) / 10) + 1
end
-- day fraction from time
local makedayfrc
makedayfrc = function(hour, min, sec, ms)
	return ((hour * 60 + min) * 60 + sec) * MILLISECONDS + ms
end
-- time from day fraction
local breakdayfrc
breakdayfrc = function(day_fraction)
	return floor(day_fraction / HOURMILLISECONDS) % HOURS, floor(day_fraction / MINUTEMILLISECONDS) % MINUTES, floor(day_fraction / MILLISECONDS) % SECONDS, day_fraction % MILLISECONDS
end
-- weekday sunday = 0, monday = 1 ...
local weekday
weekday = function(day_number)
	return (day_number + 1) % 7
end
-- yearday 0 based ...
local yearday
yearday = function(day_number)
	return day_number - dayfromyear(breakdaynum(day_number) - 1)
end
-- parse value as a month
local getmontharg
getmontharg = function(value)
	local month = tonumber(value, 10)
	return (month and trunc(month - 1)) or inlist(tostring(value) or "", sl_months, 2)
end
-- get __day_number of isoweek one of year
local isow1
isow1 = function(year)
	local f = makedaynum(year, 0, 4)
	local day = weekday(f)
	day = day == 0 and 7 or day
	return f + (1 - day)
end
local isowy
isowy = function(day_number)
	local w1
	local year = breakdaynum(day_number)
	if day_number >= makedaynum(year, 11, 29) then
		w1 = isow1(year + 1)
		if day_number < w1 then
			w1 = isow1(year)
		else
			year = year + 1
		end
	else
		w1 = isow1(year)
		if day_number < w1 then
			w1 = isow1(year - 1)
			year = year - 1
		end
	end
	return floor((day_number - w1) / 7) + 1, year
end
local isoy
isoy = function(day_number)
	local year = breakdaynum(day_number)
	return year + (((day_number >= makedaynum(year, 11, 29)) and (day_number >= isow1(year + 1))) and 1 or (day_number < isow1(year) and -1 or 0))
end
local makedaynum_isoywd
makedaynum_isoywd = function(year, w, day)
	return isow1(year) + 7 * w + day - 8
end
-- simplified: isow1(year) + ((w-1)*7) + (day-1)
local internal_methods = { }
local fmtstr = "%x %X"
-- shout invalid arg
local date_error_arg
date_error_arg = function()
	return error("invalid argument(sec)", 3)
end
-- create new date object
local date_new
date_new = function(day_number, day_fraction)
	return setmetatable({
		__day_number = day_number,
		__day_fraction = day_fraction
	}, internal_methods)
end
-- magic year table
local date_epoch, year_table
local getequivyear
getequivyear = function(value)
	assert(not year_table)
	year_table = { }
	local dateWeek, dateYear
	local obj = date_epoch:Copy()
	for _ = 0, 3000 do
		obj:SetYear(obj:GetYear() + 1, 1, 1)
		dateYear = obj:GetYear()
		dateWeek = obj:GetWeekDay() * (isleapyear(dateYear) and -1 or 1)
		if not year_table[dateWeek] then
			year_table[dateWeek] = dateYear
		end
		if year_table[-7] and year_table[-6] and year_table[-5] and year_table[-4] and year_table[-3] and year_table[-2] and year_table[-1] and year_table[1] and year_table[2] and year_table[3] and year_table[4] and year_table[5] and year_table[6] and year_table[7] then
			getequivyear = function(year)
				return year_table[(weekday(makedaynum(year, 0, 1)) + 1) * (isleapyear(year) and -1 or 1)]
			end
			return getequivyear(value)
		end
	end
end
local DATE_EPOCH
-- TimeValue from date and time
local totv
totv = function(year, month, day, hour, min, sec)
	return (makedaynum(year, month, day) - DATE_EPOCH) * DAYSECONDS + ((hour * 60 + min) * 60 + sec)
end
-- TimeValue from TimeTable
local tmtotv
tmtotv = function(time_table)
	return time_table and totv(time_table.year, time_table.month - 1, time_table.day, time_table.hour, time_table.min, time_table.sec)
end
-- Returns the bias in seconds of utc time __day_number and __day_fraction
local getbiasutc2
getbiasutc2 = function(self)
	local year, month, day = breakdaynum(self.__day_number)
	local hour, min, sec = breakdayfrc(self.__day_fraction)
	local tvu = totv(year, month, day, hour, min, sec)
	local tml = date("*t", tvu)
	-- failed try the magic
	if (not tml) or (tml.year > (year + 1) or tml.year < (year - 1)) then
		year = getequivyear(year)
		tvu = totv(year, month, day, hour, min, sec)
		tml = date("*t", tvu)
	end
	local tvl = tmtotv(tml)
	if tvu and tvl then
		return tvu - tvl, tvu, tvl
	end
	return error("failed to get bias from utc time")
end
-- Returns the bias in seconds of local time day_number and day_fraction
local getbiasloc2
getbiasloc2 = function(day_number, day_fraction)
	-- extract date and time
	local year, month, day = breakdaynum(day_number)
	local hour, min, sec = breakdayfrc(day_fraction)
	month = month + 1
	-- get equivalent TimeTable
	local tml = {
		year = year,
		month = month,
		day = day,
		hour = hour,
		min = min,
		sec = sec
	}
	-- get equivalent TimeValue
	local tvl = tmtotv(tml)
	local tvu
	local chkutc
	chkutc = function()
		tml.isdst = nil
		local tvug = time(tml)
		if tvug and (tvl == tmtotv(date("*t", tvug))) then
			tvu = tvug
			return nil
		end
		tml.isdst = true
		local tvud = time(tml)
		if tvud and (tvl == tmtotv(date("*t", tvud))) then
			tvu = tvud
			return nil
		end
		tvu = tvud or tvug
	end
	chkutc()
	if not tvu then
		tml.year = getequivyear(year)
		tvl = tmtotv(tml)
		chkutc()
	end
	return ((tvu and tvl) and (tvu - tvl)) or error("failed to get bias from local time"), tvu, tvl
end
-- ^Lua regular expression is not as powerful as Perl$
local stringWalkerClass = environment.class("StringWalker", {
	new = function(self, str)
		self.length = len(str)
		self.i, self.e = 1, 1
		self.data = str
		return nil
	end,
	aimchr = function(self)
		return "\n" .. self.data .. "\n" .. rep(".", self.e - 1) .. "^"
	end,
	finish = function(self)
		return self.i > self.length
	end,
	back = function(self)
		self.i = self.e
		return self
	end,
	restart = function(self)
		self.i, self.e = 1, 1
		return self
	end,
	match = function(self, str)
		return find(self.data, str, self.i)
	end,
	__call = function(self, str, func)
		local is, ie
		is, ie, self[1], self[2], self[3], self[4], self[5] = find(self.data, str, self.i)
		if is then
			self.e, self.i = self.i, 1 + ie
			if func then
				func(unpack(self))
			end
			return self
		end
		return nil
	end
})
--[[ THE DATE OBJECT METHODS ]]
--
internal_methods.Normalize = function(self)
	local day_fraction = self.__day_fraction
	local day_number = trunc(self.__day_number) + floor(day_fraction / DAYMILLISECONDS)
	self.__day_number = day_number
	day_fraction = day_fraction % DAYMILLISECONDS
	if day_fraction < 0 then
		day_fraction = day_fraction + DAYMILLISECONDS
	end
	self.__day_fraction = day_fraction
	return (day_number >= DAYNUM_MIN and day_number <= DAYNUM_MAX) and self or error("date beyond imposed limits:" .. self)
end
internal_methods.GetDate = function(self)
	local year, month, day = breakdaynum(self.__day_number)
	return year, month + 1, day
end
internal_methods.GetTime = function(self)
	return breakdayfrc(self.__day_fraction)
end
internal_methods.GetClockHour = function(self)
	local hour = self:GetHours()
	return hour > 12 and (hour % 12) or (hour == 0 and 12 or hour)
end
internal_methods.GetYearDay = function(self)
	return yearday(self.__day_number) + 1
end
-- in lua weekday is sunday = 1, monday = 2 ...
internal_methods.GetWeekDay = function(self)
	return weekday(self.__day_number) + 1
end
internal_methods.GetYear = function(self)
	return breakdaynum(self.__day_number), nil
end
local _
-- in lua month is 1 base
internal_methods.GetMonth = function(self)
	local r
	_, r, _ = breakdaynum(self.__day_number)
	return r + 1
end
internal_methods.GetDay = function(self)
	local r
	_, _, r = breakdaynum(self.__day_number)
	return r
end
internal_methods.GetHours = function(self)
	return floor(self.__day_fraction / HOURMILLISECONDS) % HOURS
end
internal_methods.GetMinutes = function(self)
	return floor(self.__day_fraction / MINUTEMILLISECONDS) % MINUTES
end
internal_methods.GetSeconds = function(self)
	return floor(self.__day_fraction / MILLISECONDS) % SECONDS
end
internal_methods.GetMilliseconds = function(self, u)
	local x = self.__day_fraction % MILLISECONDS
	return u and ((x * u) / MILLISECONDS) or x
end
internal_methods.GetFloatSeconds = function(self)
	return (floor(self.__day_fraction / MILLISECONDS) % SECONDS) + ((self.__day_fraction % MILLISECONDS) / MILLISECONDS)
end
internal_methods.GetWeekNumber = function(self, wdb)
	local wd, yd = weekday(self.__day_number), yearday(self.__day_number)
	if wdb then
		wdb = tonumber(wdb, 10)
		if wdb then
			wd = (wd - (wdb - 1)) % 7
		else
			return date_error_arg()
		end
	end
	return (yd < wd and 0) or (floor(yd / 7) + (((yd % 7) >= wd) and 1 or 0))
end
-- sunday = 7, monday = 1 ...
internal_methods.GetISOWeekDay = function(self)
	return ((weekday(self.__day_number) - 1) % 7) + 1
end
internal_methods.GetISOWeekNumber = function(self)
	return isowy(self.__day_number)
end
internal_methods.GetISOYear = function(self)
	return isoy(self.__day_number)
end
internal_methods.GetISODate = function(self)
	local w, year = isowy(self.__day_number)
	return year, w, self:GetISOWeekDay()
end
internal_methods.SetISOYear = function(self, year, w, day)
	local cy, cw, cd = self:GetISODate()
	if year then
		cy = trunc(tonumber(year, 10))
	end
	if w then
		cw = trunc(tonumber(w, 10))
	end
	if day then
		cd = trunc(tonumber(day, 10))
	end
	if cy and cw and cd then
		self.__day_number = makedaynum_isoywd(cy, cw, cd)
		return self:Normalize()
	end
	return date_error_arg()
end
internal_methods.SetISOWeekDay = function(self, day)
	return self:SetISOYear(nil, nil, day)
end
internal_methods.SetISOWeekNumber = function(self, w, day)
	return self:SetISOYear(nil, w, day)
end
internal_methods.SetYear = function(self, year, month, day)
	local cy, cm, cd = breakdaynum(self.__day_number)
	if year then
		cy = trunc(tonumber(year, 10))
	end
	if month then
		cm = getmontharg(month)
	end
	if day then
		cd = trunc(tonumber(day, 10))
	end
	if cy and cm and cd then
		self.__day_number = makedaynum(cy, cm, cd)
		return self:Normalize()
	end
	return date_error_arg()
end
internal_methods.SetMonth = function(self, month, day)
	return self:SetYear(nil, month, day)
end
internal_methods.SetDay = function(self, day)
	return self:SetYear(nil, nil, day)
end
internal_methods.SetHours = function(self, hour, month, sec, ms)
	local ch, cm, cs, ck = breakdayfrc(self.__day_fraction)
	ch, cm, cs, ck = tonumber(hour or ch, 10), tonumber(month or cm, 10), tonumber(sec or cs, 10), tonumber(ms and (ms * MILLISECONDS) or ck, 10)
	if ch and cm and cs and ck then
		self.__day_fraction = makedayfrc(ch, cm, cs, ck)
		return self:Normalize()
	end
	return date_error_arg()
end
internal_methods.SetMinutes = function(self, month, sec, ms)
	return self:SetHours(nil, month, sec, ms)
end
internal_methods.SetSeconds = function(self, sec, ms)
	return self:SetHours(nil, nil, sec, ms)
end
internal_methods.SetMilliseconds = function(self, ms)
	return self:SetHours(nil, nil, nil, ms)
end
internal_methods.SpanMilliseconds = function(self)
	return self.__day_number * DAYMILLISECONDS + self.__day_fraction
end
internal_methods.SpanSeconds = function(self)
	return (self.__day_number * DAYMILLISECONDS + self.__day_fraction) / MILLISECONDS
end
internal_methods.SpanMinutes = function(self)
	return (self.__day_number * DAYMILLISECONDS + self.__day_fraction) / MINUTEMILLISECONDS
end
internal_methods.SpanHours = function(self)
	return (self.__day_number * DAYMILLISECONDS + self.__day_fraction) / HOURMILLISECONDS
end
internal_methods.SpanDays = function(self)
	return (self.__day_number * DAYMILLISECONDS + self.__day_fraction) / DAYMILLISECONDS
end
internal_methods.AddYears = function(self, year, month, day)
	local cy, cm, cd = breakdaynum(self.__day_number)
	if year then
		year = trunc(tonumber(year, 10))
	else
		year = 0
	end
	if month then
		month = trunc(tonumber(month, 10))
	else
		month = 0
	end
	if day then
		day = trunc(tonumber(day, 10))
	else
		day = 0
	end
	if year and month and day then
		self.__day_number = makedaynum(cy + year, cm + month, cd + day)
		return self:Normalize()
	end
	return date_error_arg()
end
internal_methods.AddMonths = function(self, month, day)
	return self:AddYears(nil, month, day)
end
do
	local dobj_adddayfrc
	dobj_adddayfrc = function(self, n, pt, pd)
		n = tonumber(n, 10)
		if n then
			local x = floor(n / pd)
			self.__day_number = self.__day_number + x
			self.__day_fraction = self.__day_fraction + (n - x * pd) * pt
			return self:Normalize()
		end
		return date_error_arg()
	end
	internal_methods.AddDays = function(self, n)
		return dobj_adddayfrc(self, n, DAYMILLISECONDS, 1)
	end
	internal_methods.AddHours = function(self, n)
		return dobj_adddayfrc(self, n, HOURMILLISECONDS, HOURS)
	end
	internal_methods.AddMinutes = function(self, n)
		return dobj_adddayfrc(self, n, MINUTEMILLISECONDS, DAYMINUTES)
	end
	internal_methods.AddSeconds = function(self, n)
		return dobj_adddayfrc(self, n, MILLISECONDS, DAYSECONDS)
	end
	internal_methods.AddMilliseconds = function(self, n)
		return dobj_adddayfrc(self, n, 1, DAYMILLISECONDS)
	end
end
do
	local tvspec = {
		["%a"] = function(self)
			return sl_weekdays[weekday(self.__day_number) + 7]
		end,
		["%A"] = function(self)
			return sl_weekdays[weekday(self.__day_number)]
		end,
		["%b"] = function(self)
			return sl_months[self:GetMonth() - 1 + 12]
		end,
		["%B"] = function(self)
			return sl_months[self:GetMonth() - 1]
		end,
		["%C"] = function(self)
			return format("%.2d", trunc(self:GetYear() / 100))
		end,
		["%d"] = function(self)
			return format("%.2d", self:GetDay())
		end,
		["%g"] = function(self)
			return format("%.2d", self:GetISOYear() % 100)
		end,
		["%G"] = function(self)
			return format("%.4d", self:GetISOYear())
		end,
		["%h"] = function(self)
			return self:fmt0("%b")
		end,
		["%H"] = function(self)
			return format("%.2d", self:GetHours())
		end,
		["%I"] = function(self)
			return format("%.2d", self:GetClockHour())
		end,
		["%j"] = function(self)
			return format("%.3d", self:GetYearDay())
		end,
		["%m"] = function(self)
			return format("%.2d", self:GetMonth())
		end,
		["%M"] = function(self)
			return format("%.2d", self:GetMinutes())
		end,
		["%p"] = function(self)
			return sl_meridian[self:GetHours() > 11 and 1 or -1]
		end,
		["%S"] = function(self)
			return format("%.2d", self:GetSeconds())
		end,
		["%u"] = function(self)
			return self:GetISOWeekDay()
		end,
		["%U"] = function(self)
			return format("%.2d", self:GetWeekNumber())
		end,
		["%V"] = function(self)
			return format("%.2d", self:GetISOWeekNumber())
		end,
		["%w"] = function(self)
			return self:GetWeekDay() - 1
		end,
		["%W"] = function(self)
			return format("%.2d", self:GetWeekNumber(2))
		end,
		["%y"] = function(self)
			return format("%.2d", self:GetYear() % 100)
		end,
		["%Y"] = function(self)
			return format("%.4d", self:GetYear())
		end,
		["%z"] = function(self)
			local b = -self:GetBIAS()
			local x = abs(b)
			return format("%s%.4d", b < 0 and "-" or "+", trunc(x / 60) * 100 + floor(x % 60))
		end,
		["%Z"] = function(self)
			return self:GetTimeZone()
		end,
		["%\b"] = function(self)
			local x = self:GetYear()
			return format("%.4d%s", x > 0 and x or (1 - x), x > 0 and "" or " BCE")
		end,
		["%\f"] = function(self)
			local x = self:GetFloatSeconds()
			return format("%s%.9f", x >= 10 and "" or "0", x)
		end,
		["%%"] = function(self)
			return "%"
		end,
		["%r"] = function(self)
			return self:fmt0("%I:%M:%S %p")
		end,
		["%R"] = function(self)
			return self:fmt0("%I:%M")
		end,
		["%T"] = function(self)
			return self:fmt0("%H:%M:%S")
		end,
		["%D"] = function(self)
			return self:fmt0("%m/%d/%y")
		end,
		["%F"] = function(self)
			return self:fmt0("%Y-%m-%d")
		end,
		["%c"] = function(self)
			return self:fmt0("%x %X")
		end,
		["%x"] = function(self)
			return self:fmt0("%a %b %d %\b")
		end,
		["%X"] = function(self)
			return self:fmt0("%H:%M:%\f")
		end,
		["${iso}"] = function(self)
			return self:fmt0("%Y-%m-%dT%T")
		end,
		["${http}"] = function(self)
			return self:fmt0("%a, %d %b %Y %T GMT")
		end,
		["${ctime}"] = function(self)
			return self:fmt0("%a %b %d %T GMT %Y")
		end,
		["${rfc850}"] = function(self)
			return self:fmt0("%A, %d-%b-%y %T GMT")
		end,
		["${rfc1123}"] = function(self)
			return self:fmt0("%a, %d %b %Y %T GMT")
		end,
		["${asctime}"] = function(self)
			return self:fmt0("%a %b %d %T %Y")
		end
	}
	local fmt0
	fmt0 = function(self, str)
		return gsub(str, "%%[%a%%\b\f]", function(x)
			local f = tvspec[x]
			return (f and f(self)) or x
		end), nil
	end
	internal_methods.fmt0 = fmt0
	do
		local _tmp_0
		_tmp_0 = function(self, str)
			str = str or (self.fmtstr or fmtstr)
			return fmt0(self, gmatch(str, "${%w+}") and gsub(str, "${%w+}", function(x)
				local f = tvspec[x]
				return (f and f(self)) or x
			end) or str), nil
		end
		internal_methods.Format = _tmp_0
		internal_methods.__tostring = _tmp_0
	end
end
internal_methods.ToTable = function(self)
	local year, month, day = breakdaynum(self.__day_number)
	local hour, min, sec = breakdayfrc(self.__day_fraction)
	return {
		year = year,
		month = month,
		day = day,
		hour = hour,
		min = min,
		sec = sec
	}
end
internal_methods.ToUnix = function(self)
	local year, month, day = breakdaynum(self.__day_number)
	local hour, min, sec = breakdayfrc(self.__day_fraction)
	return totv(year, month, day, hour, min, sec)
end
internal_methods.ToDOS = function(self)
	local year, month, day = breakdaynum(self.__day_number)
	local hour, min, sec = breakdayfrc(self.__day_fraction)
	return bor(lshift(hour, 11), lshift(min, 5), fdiv(sec, 2)), bor(lshift(year - 1980, 9), lshift(month, 5), day)
end
internal_methods.__lt = function(self, b)
	if isnumber(b) then
		return self:ToUnix() < b
	end
	if self.__day_number == b.__day_number then
		return self.__day_fraction < b.__day_fraction
	end
	return self.__day_number < b.__day_number
end
internal_methods.__le = function(self, b)
	if isnumber(b) then
		return self:ToUnix() <= b
	end
	if self.__day_number == b.__day_number then
		return self.__day_fraction <= b.__day_fraction
	end
	return self.__day_number <= b.__day_number
end
internal_methods.__eq = function(self, b)
	if isnumber(b) then
		return self:ToUnix() == b
	end
	return (self.__day_number == b.__day_number) and (self.__day_fraction == b.__day_fraction)
end
local dateClass
internal_methods.__mul = function(a, b)
	if isnumber(b) then
		return date_new(a.__day_number * b, a.__day_fraction * b):Normalize()
	end
	b = dateClass(b)
	return date_new(a.__day_number * b.__day_number, a.__day_fraction * b.__day_fraction):Normalize()
end
internal_methods.__div = function(a, b)
	if isnumber(b) then
		return date_new(a.__day_number / b, a.__day_fraction / b):Normalize()
	end
	b = dateClass(b)
	return date_new(a.__day_number / b.__day_number, a.__day_fraction / b.__day_fraction):Normalize()
end
internal_methods.__sub = function(a, b)
	if isnumber(b) then
		return a:Copy():AddSeconds(b)
	end
	b = dateClass(b)
	return date_new(a.__day_number - b.__day_number, a.__day_fraction - b.__day_fraction):Normalize()
end
internal_methods.__add = function(a, b)
	if isnumber(b) then
		return a:Copy():AddSeconds(b)
	end
	b = dateClass(b)
	return date_new(a.__day_number + b.__day_number, a.__day_fraction + b.__day_fraction):Normalize()
end
internal_methods.__concat = function(a, b)
	return a:Format() .. tostring(b)
end
internal_methods.Copy = function(self)
	return date_new(self.__day_number, self.__day_fraction)
end
--[[ THE LOCAL DATE OBJECT METHODS ]]
--
internal_methods.ToLocal = function(self)
	local bias = getbiasutc2(self)
	if bias then
		-- utc = local + bias; local = utc - bias
		self.__day_fraction = self.__day_fraction - (bias * MILLISECONDS)
		return self:Normalize()
	end
	return self
end
internal_methods.ToUTC = function(self)
	local day_fraction = self.__day_fraction
	local bias = getbiasloc2(self.__day_number, day_fraction)
	if bias then
		-- utc = local + bias;
		self.__day_fraction = day_fraction + bias * MILLISECONDS
		return self:Normalize()
	end
	return self
end
internal_methods.GetBIAS = function(self)
	return getbiasloc2(self.__day_number, self.__day_fraction) / SECONDS
end
internal_methods.GetTimeZone = function(self, retName)
	local tvu
	_, tvu, _ = getbiasloc2(self.__day_number, self.__day_fraction)
	return tvu and date(retName and "%Z" or "%z", tvu) or ""
end
do
	local date_parse
	date_parse = function(str)
		local year, month, day, hour, min, sec, z, w, u, j, e, x, c
		local sw = stringWalkerClass(gsub(gsub(str, "(%b())", ""), "^(%s*)", ""))
		local error_dup
		error_dup = function(q)
			error("duplicate value: " .. (q or "") .. sw:aimchr())
			return nil
		end
		local error_syn
		error_syn = function(q)
			error("syntax error: " .. (q or "") .. sw:aimchr())
			return nil
		end
		local error_inv
		error_inv = function(q)
			error("invalid date: " .. (q or "") .. sw:aimchr())
			return nil
		end
		local sety
		sety = function(q)
			year = year and error_dup() or tonumber(q, 10)
			return nil
		end
		local setm
		setm = function(q)
			month = (month or w or j) and error_dup(month or w or j) or tonumber(q, 10)
			return nil
		end
		local setd
		setd = function(q)
			day = day and error_dup() or tonumber(q, 10)
			return nil
		end
		local seth
		seth = function(q)
			hour = hour and error_dup() or tonumber(q, 10)
			return nil
		end
		local setr
		setr = function(q)
			min = min and error_dup() or tonumber(q, 10)
			return nil
		end
		local sets
		sets = function(q)
			sec = sec and error_dup() or tonumber(q, 10)
			return nil
		end
		local adds
		adds = function(q)
			sec = sec + tonumber("." .. sub(q, 2, -1), 10)
			return nil
		end
		local setj
		setj = function(q)
			j = (month or w or j) and error_dup() or tonumber(q, 10)
			return nil
		end
		local setz
		setz = function(q)
			z = (z ~= 0 and z) and error_dup() or q
			return nil
		end
		local setzn
		setzn = function(zs, zn)
			zn = tonumber(zn, 10)
			setz(((zn < 24) and (zn * 60) or ((zn % 100) + floor(zn / 100) * 60)) * (zs == "+" and -1 or 1))
			return nil
		end
		local setzc
		setzc = function(zs, zh, zm)
			setz(((tonumber(zh, 10) * 60) + tonumber(zm, 10)) * (zs == "+" and -1 or 1))
			return nil
		end
		if not (sw("^(%d%d%d%d)", sety) and (sw("^(%-?)(%d%d)%1(%d%d)", function(_, a, b)
			setm(tonumber(a, 10))
			setd(tonumber(b, 10))
			return nil
		end) or sw("^(%-?)[Ww](%d%d)%1(%d?)", function(_, a, b)
			w, u = tonumber(a, 10), tonumber(b or 1, 10)
			return nil
		end) or sw("^%-?(%d%d%d)", setj) or sw("^%-?(%d%d)", function(a)
			setm(a)
			setd(1)
			return nil
		end)) and ((sw("^%s*[Tt]?(%d%d):?", seth) and sw("^(%d%d):?", setr) and sw("^(%d%d)", sets) and sw("^([,%.]%d+)", adds) and sw("%s*([+-])(%d%d):?(%d%d)%s*$", setzc)) or sw:finish() or (sw("^%s*$") or sw("^%s*[Zz]%s*$") or sw("^%s-([%+%-])(%d%d):?(%d%d)%s*$", setzc) or sw("^%s*([%+%-])(%d%d)%s*$", setzn)))) then
			sw:restart()
			year, month, day, hour, min, sec, z, w, u, j = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
			repeat
				if sw("^[tT:]?%s*(%d%d?):", seth) then
					_ = sw("^%s*(%d%d?)", setr) and sw("^%s*:%s*(%d%d?)", sets) and sw("^([,%.]%d+)", adds)
				elseif sw("^(%d+)[/\\%s,-]?%s*") then
					x, c = tonumber(sw[1], 10), len(sw[1])
					if (x >= 70) or (month and day and not year) or (c > 3) then
						sety(x + ((x >= 100 or c > 3) and 0 or x < CENTURYFLIP and 2000 or 1900))
					else
						if month then
							setd(x)
						else
							month = x
						end
					end
				elseif sw("^(%a+)[/\\%s,-]?%s*") then
					x = sw[1]
					if inlist(x, sl_months, 2, sw) then
						if month and not day and not year then
							day, month = month, false
						end
						setm((sw[0] % 12) + 1)
					elseif inlist(x, sl_timezone, 2, sw) then
						c = truncString(sw[0])
						if c ~= 0 then
							setz(c)
						end
					elseif not inlist(x, sl_weekdays, 2, sw) then
						sw:back()
						if sw("^([bB])%s*(%.?)%s*[Cc]%s*(%2)%s*[Ee]%s*(%2)%s*") or sw("^([bB])%s*(%.?)%s*[Cc]%s*(%2)%s*") then
							e = e and error_dup() or -1
						elseif sw("^([aA])%s*(%.?)%s*[Dd]%s*(%2)%s*") or sw("^([cC])%s*(%.?)%s*[Ee]%s*(%2)%s*") then
							e = e and error_dup() or 1
						elseif sw("^([PApa])%s*(%.?)%s*[Mm]?%s*(%2)%s*") then
							x = lower(sw[1])
							if not hour or hour > 12 or hour < 0 then
								return error_inv()
							end
							if x == "a" and hour == 12 then
								hour = 0
							end
							if x == "p" and hour ~= 12 then
								hour = hour + 12
							end
						else
							error_syn()
						end
					end
				elseif not (sw("^([+-])(%d%d?):(%d%d)", setzc) or sw("^([+-])(%d+)", setzn) or sw("^[Zz]%s*$")) then
					error_syn("?")
				end
				sw("^%s*")
			until sw:finish()
		end
		-- if date is given, it must be complete year, month & day
		if (not year and not hour) or ((month and not day) or (day and not month)) or ((month and w) or (month and j) or (j and w)) then
			return error_inv("!")
		end
		-- fix month
		if month then
			month = month - 1
		end
		-- fix year if we are on BCE
		if e and e < 0 and year > 0 then
			year = 1 - year
		end
		--  create date object
		return (year and ((w and makedaynum_isoywd(year, w, u)) or (j and makedaynum(year, 0, j)) or makedaynum(year, month, day))) or DAYNUM_DEF, makedayfrc(hour or 0, min or 0, sec or 0, 0) + ((z or 0) * MINUTEMILLISECONDS)
	end
	internal_methods.new = function(self, arg1, month, day, hour, min, sec, ms)
		local year
		if arg1 then
			if month then
				year, month, day = truncString(arg1), getmontharg(month), truncString(day)
				hour, min, sec, ms = tonumber(hour or 0, 10), tonumber(min or 0, 10), tonumber(sec or 0, 10), tonumber(ms or 0, 10)
				if year and month and day and hour and min and sec and ms then
					self.__day_number = makedaynum(year, month, day)
					self.__day_fraction = makedayfrc(hour, min, sec, ms * MILLISECONDS)
					self:Normalize()
					return nil
				end
				date_error_arg()
				return nil
			end
			local argType = type(arg1)
			if argType == "number" then
				self.__day_number = date_epoch.__day_number
				self.__day_fraction = date_epoch.__day_fraction
				self:AddSeconds(arg1)
				return nil
			end
			if argType == "string" then
				self.__day_number, self.__day_fraction = date_parse(arg1)
				return nil
			end
			if argType == "boolean" then
				local time_table = date(arg1 and "!*t" or "*t")
				self.__day_number = makedaynum(time_table.year, time_table.month - 1, time_table.day) or DAYNUM_DEF
				self.__day_fraction = makedayfrc(time_table.hour or 0, time_table.min or 0, time_table.sec or 0, 0)
				return nil
			end
			if argType == "Date" then
				self.__day_number = year.__day_number
				self.__day_fraction = year.__day_fraction
				return nil
			end
			if argType == "table" then
				year, month, day = truncString(arg1.year), getmontharg(arg1.month), truncString(arg1.day)
				hour, min, sec, ms = tonumber(arg1.hour, 10), tonumber(arg1.min, 10), tonumber(arg1.sec, 10), tonumber(arg1.ms, 10)
				-- atleast there is time or complete date
				if (year or month or day) and not (year and month and day) then
					error("incomplete table", 3)
					return nil
				end
				self.__day_number = year and makedaynum(year, month - 1, day) or DAYNUM_DEF
				self.__day_fraction = makedayfrc(hour or 0, min or 0, sec or 0, ms and (ms * MILLISECONDS) or 0)
				return nil
			end
			error("bad argument #1 to Date (string/number/boolean/table expected, got " .. argType .. ")", 3)
			return nil
		end
		local time_table = date("*t")
		self.__day_number = makedaynum(time_table.year, time_table.month - 1, time_table.day) or DAYNUM_DEF
		self.__day_fraction = makedayfrc(time_table.hour or 0, time_table.min or 0, time_table.sec or 0, 0)
		return nil
	end
end
local static_methods = { }
static_methods.Time = function(hour, min, sec, ms)
	hour, min, sec, ms = tonumber(hour or 0, 10), tonumber(min or 0, 10), tonumber(sec or 0, 10), tonumber(ms or 0, 10)
	if hour and min and sec and ms then
		return date_new(DAYNUM_DEF, makedayfrc(hour, min, sec, ms * MILLISECONDS))
	end
	return date_error_arg()
end
static_methods.IsLeapYear = function(value)
	local year = truncString(value)
	if not year then
		year = dateClass(value)
		year = year and year:GetYear()
	end
	return isleapyear(year + 0)
end
static_methods.Epoch = function()
	return date_epoch:Copy()
end
static_methods.ISO = function(year, w, day)
	return date_new(makedaynum_isoywd(year + 0, w and (w + 0) or 1, day and (day + 0) or 1), 0)
end
do
	local fromUnix
	fromUnix = function(seconds)
		local object = date_new(date_epoch.__day_number, date_epoch.__day_fraction)
		object:AddSeconds(seconds)
		return object
	end
	static_methods.FromUnix = fromUnix
	static_methods.FromDOS = function(t, d)
		local time_table = {
			year = 10,
			month = 1,
			day = 1,
			hour = 0,
			min = 0,
			sec = 0
		}
		if t then
			time_table.hour = rshift(band(t, 0xF800), 11)
			time_table.min = rshift(band(t, 0x07E0), 5)
			time_table.sec = band(t, 0x001F) * 2
		end
		if d then
			time_table.year = time_table.year + rshift(band(d, 0xFE00), 9)
			time_table.month = rshift(band(d, 0x01E0), 5)
			time_table.day = band(d, 0x001F)
		end
		local object = date_new(date_epoch.__day_number, date_epoch.__day_fraction)
		object:AddSeconds(time_table.sec)
		object:AddMinutes(time_table.min)
		object:AddHours(time_table.hour)
		object:AddDays(time_table.day - 1)
		object:AddMonths(time_table.month)
		object:AddYears(time_table.year)
		return object
	end
end
static_methods.diff = function(a, b)
	if isnumber(b) then
		return a:ToUnix() - b
	end
	return a - b
end
do
	local Read, Write
	do
		local _obj_0 = environment.struct.io.I
		Read, Write = _obj_0.Read, _obj_0.Write
	end
	internal_methods.ToBinary = function(self)
		return Write(nil, self.__day_number, 4) .. Write(nil, self.__day_fraction, 4)
	end
	static_methods.FromBinary = function(str)
		local length = len(str)
		if length < 8 then
			error("binary data was corrupted", 2)
			return nil
		end
		return date_new(Read(nil, sub(str, 1, 4), 4), Read(nil, sub(str, 5, length), 4))
	end
end
dateClass = environment.class("Date", internal_methods, static_methods)
local time_table = date("!*t", 0)
if time_table then
	date_epoch = dateClass(time_table)
	-- the distance from our epoch to os epoch in __day_number
	DATE_EPOCH = date_epoch and date_epoch:SpanDays()
else
	date_epoch = setmetatable({ }, {
		__index = function()
			return error("failed to get the epoch date")
		end
	})
end
environment.util.Date = dateClass

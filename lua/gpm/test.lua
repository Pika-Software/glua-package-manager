local Error, debug, async, await = gpm.Error, gpm.debug, gpm.async, gpm.await
local format = string.format
local SysTime = _G.SysTime
local iter = 10000
local warmup = math.min(iter / 100, 100)
local bench
bench = function(name, fn)
	-- Warmup
	for i = 1, warmup do
		fn()
	end
	collectgarbage("stop")
	local st = SysTime()
	for i = 1, iter do
		fn()
	end
	st = SysTime() - st
	collectgarbage("restart")
	print(format("%d iterations of %s, took %f sec.", iter, name, st))
	return st
end
local URL = gpm.URL
local FindSource
do
	local _obj_0 = gpm.loader
	FindSource = _obj_0.FindSource
end
local main = async(function() end)
return gpm.futures.run(main())

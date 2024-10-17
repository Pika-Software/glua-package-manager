local print
print = function(...)
	local tbl = {
		...
	}
	local len = #tbl
	for i = 1, len do
		tbl[i] = tostring(tbl[i])
	end
	return Logger:Info(table.concat(tbl, "\t"))
end
local data
do
	local _obj_0 = include("./async_module.lua")
	data = _obj_0.data
end
print("data from async module: ", data)
print("me:", __package)
print("and:", __module)
return nil

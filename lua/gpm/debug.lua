local SortedPairs = SortedPairs
local isstring = isstring
local istable = istable

local function SearchGlobalName( searchable, nextTable, usedTables )
	if (nextTable == nil) then return end
	usedTables[ nextTable ] = true

	for key, value in SortedPairs( nextTable ) do
		if (key == '__index') then continue end
		if (key == '_G') then continue end
		if (value == searchable) then
			return key
		elseif istable( value ) then
			if usedTables[ value ] then continue end
			local founded = SearchGlobalName( searchable, value, usedTables )
			if isstring( founded ) then
				if isstring( key ) then
					return key .. '.' .. founded
				else
					return founded
				end
			end
		end
	end
end

do

	local debug_getregistry = debug.getregistry
	local debug_getlocal = debug.getlocal
	local assert = assert

	function debug.getfname( searchable, level )
		assert( searchable ~= nil, 'Searchable cannot be nil!' )
		local localTable = {}

		local i = 1
		while (true) do
			local key, value = debug_getlocal( level or 2, i )
			if (key == nil) then break end
			localTable[ key ] = value
			i = i + 1
		end

		do
			local result = SearchGlobalName( searchable, localTable, {} )
			if (result) then
				return result
			end
		end

		local loaded = debug_getregistry()._LOADED

		local packages = loaded.package
		if istable( packages ) then
			local nextTable = packages.loaded
			if istable( nextTable ) then
				local result = SearchGlobalName( searchable, nextTable, {} )
				if (result) then
					return result
				end
			end
		end

		local global = loaded._G
		if istable( global ) then
			local result = SearchGlobalName( searchable, loaded._G, {} )
			if (result) then
				return result
			end
		end
	end

end

function debug.fempty()
end

do

	local isfunction = isfunction
	local ArgAssert = ArgAssert

	local functions = {}
	function debug.getf( name )
		ArgAssert( name, 1, 'string' )
		local func = functions[ name ]
		if isfunction( func ) then
			return func
		else
			return emptyFunction
		end
	end

	function debug.setf( func, override )
		ArgAssert( func, 1, 'function' )

		local name = debug.getfname( func, 3 )
		if override or (functions[ name ] == nil) then
			functions[ name ] = func
			return func
		end

		return functions[ name ]
	end

end
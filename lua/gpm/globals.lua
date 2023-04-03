local string = string

do

	local debug_getinfo = debug.getinfo
	local error = error
	local type = type

	function ArgAssert( value, argNum, argType, errorlevel )
		local valueType = string.lower( type( value ) )
		if (valueType == argType) then return end

		local dinfo = debug_getinfo( 2, "n" )
		local fname = dinfo and dinfo.name or "func"
		error( string.format( "bad argument #%d to \'%s\' (%s expected, got %s)", argNum, fname, argType, valueType ), errorlevel or 3)
	end

end

do
	local table_concat = table.concat
	function file.Path( ... )
		return table_concat( {...}, "/" )
	end
end

do

	local TYPE_FILE = TYPE_FILE
	local TypeID = TypeID

	function isFile( any )
		return TypeID( any ) == TYPE_FILE
	end

end

function string.IsURL( str )
	ArgAssert( str, 1, "string" )
	return string.match( str, "^https?://.*" ) ~= nil
end

-- Make JIT happy
function debug.fempty()
end

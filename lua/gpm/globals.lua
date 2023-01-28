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

	local tonumber = tonumber
	local Color = Color

	function HEXToColor( str )
		local hex = string.Replace( str, "#", "" )
		if (#hex > 3) then
			return Color( tonumber( "0x" .. string.sub( hex,  1, 2 ) ), tonumber( "0x" .. string.sub( hex,  3, 4 ) ), tonumber( "0x" .. string.sub( hex,  5, 6 ) ) )
		else
			return Color( tonumber( "0x" .. string.sub( hex,  1, 1 ) ) * 17, tonumber( "0x" .. string.sub( hex,  2, 2 ) ) * 17, tonumber( "0x" .. string.sub( hex,  3, 3 ) ) * 17 )
		end
	end

end

function ColorToHEX( color )
	return "#" .. string.format( "%x", (color.r * 0x10000) + (color.g * 0x100) + color.b )
end

do
	local table_concat = table.concat
	function file.Path( ... )
		return table_concat( {...}, "/" )
	end
end

-- Make JIT happy
function gpm.EmptyFunc()
end

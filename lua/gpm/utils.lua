-- Libraries
local string = string
local table = table

-- Functions
local debug_getinfo = debug.getinfo
local tonumber = tonumber
local module = module
local error = error
local pairs = pairs
local type = type

-- Checks if argument have valid type
function ArgAssert( value, argNum, expected, errorlevel )
    local valueType = type( value )
    if valueType == expected then return end

    local dinfo = debug_getinfo( 2, "n" )
    error( string.format( "bad argument #%d to \'%s\' (%s expected, got %s)", argNum, dinfo and dinfo.name or "func", expected, valueType ), errorlevel or 3 )
end

--
do

    local TYPE_FILE = TYPE_FILE
    local TypeID = TypeID

    function isFile( any )
        return TypeID( any ) == TYPE_FILE
    end

end

-- Make JIT happy
function debug.fempty()
end

module( "gpm.utils" )

function LowerTableKeys( tbl )
    for key, value in pairs( tbl ) do
        if type( value ) == "table" then value = LowerTableKeys( value ) end
        if type( key ) ~= "string" then continue end
        tbl[ key ] = nil; tbl[ string.lower( key ) ] = value
    end
end

function Version( number )
    if not number then return "invalid version" end
    local version = string.format( "%06d", number )
    return string.format( "%d.%d.%d", tonumber( string.sub( version, 0, 2 ) ), tonumber( string.sub( version, 3, 4 ) ), tonumber( string.sub( version, 5 ) ) )
end

function GetCurrentFile()
    for i = 2, 6 do
        local info = debug_getinfo( i, "S" )
        if not info then break end
        if info.what == "main" then return info.short_src end
    end
end

module( "gpm.path" )

-- File path fix
function Fix( filePath )
    filePath = string.lower( filePath )
    filePath = string.gsub( filePath, "\\", "/" )
    filePath = string.gsub( filePath, "/+", "/" )
    return filePath
end

-- File path join
function Join( filePath, ... )
    return Fix( table.concat( { filePath, ... }, "/" ) )
end

-- File path localization
function Localize( filePath )
    filePath = string.gsub( filePath, "^addons/[%w%-_]-/", "" )
    filePath = string.gsub( filePath, "^lua/", "" )
    return filePath
end
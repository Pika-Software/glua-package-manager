local isfunction = isfunction
local ArgAssert = ArgAssert
local istable = istable
local debug = debug
local pairs = pairs
local _G = _G

module( "gpm.environment", package.seeall )

--
do

    local metaCache = {}
    function LinkTables( a, b )
        ArgAssert( a, 1, "table" )
        ArgAssert( b, 2, "table" )

        local meta = metaCache[ b ]
        if (meta == nil) then
            meta = {
                ["__index"] = b
            }

            metaCache[ b ] = meta
        end

        debug.setmetatable( a, meta )
        return a
    end

end

--
function Create( func, env )
    ArgAssert( func, 1, "function" )

    local new = {}
    debug.setfenv( func, LinkTables( new, env or _G ) )
    return new, func
end

--
function CopyFunction( func )
    ArgAssert( func, 1, "function" )
    return function( ... )
        return func( ... )
    end
end

--
function Set( env, path, object )
    ArgAssert( env, 1, "table" )
    ArgAssert( path, 2, "string" )

    local levels = string.Split( path, "." )
    local len = #levels
    local last = env

    for num, level in ipairs( levels ) do
        if (num == len) then
            last[ level ] = object
            return true
        end

        local tbl = last[ level ]
        if (tbl == nil) then
            last[ level ] = {}
        elseif not istable( tbl ) then
            return
        end

        last = last[ level ]
    end

    return false
end

--
do

    function SetFunction( env, path, func, makeCopy )
        ArgAssert( func, 1, "function" )
        if (makeCopy) then
            func = CopyFunction( func )
        end

        debug.setfenv( func, env )
        return Set( env, path, func )
    end

end

--
function SetTable( env, path, tbl, makeCopy )
    ArgAssert( env, 1, "table" )
    ArgAssert( tbl, 3, "table" )

    local object = {}
    for key, value in pairs( tbl ) do
        if istable( key ) then
            key = SetTable( env, nil, tbl, makeCopy )
        elseif makeCopy and isfunction( key ) then
            debug.setfenv( key, env )
            key = CopyFunction( key )
        end

        if istable( value ) then
            value = SetTable( env, nil, tbl, makeCopy )
        elseif makeCopy and isfunction( value ) then
            debug.setfenv( value, env )
            value = CopyFunction( value )
        end

        object[ key ] = value
    end

    if (path) then
        return Set( env, path, object )
    else
        return object
    end
end

--
function SetLinkedTable( env, path, tbl )
    return Set( env, path, LinkTables( {}, tbl ) )
end
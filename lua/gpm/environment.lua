-- Variables
local table_SetValue = table.SetValue
local setmetatable = setmetatable
local debug_fcopy = debug.fcopy
local ArgAssert = ArgAssert
local setfenv = setfenv
local pairs = pairs
local type = type
local _G = _G

module( "gpm.environment" )

function SetFunction( env, path, func, makeCopy )
    ArgAssert( func, 1, "function" )
    return table_SetValue( env, path, setfenv( makeCopy and debug_fcopy( func ) or func, env ) )
end

do

    local metaCache = {}

    function LinkTables( a, b )
        ArgAssert( a, 1, "table" )
        ArgAssert( b, 2, "table" )

        local meta = metaCache[ b ]
        if meta == nil then
            meta = {
                ["__index"] = b
            }

            metaCache[ b ] = meta
        end

        setmetatable( a, meta )
        return a
    end

end

function SetLinkedTable( env, path, tbl )
    return table_SetValue( env, path, LinkTables( {}, tbl ) )
end

function Create( func, env )
    ArgAssert( func, 1, "function" )

    local new = {}
    return new, setfenv( func, LinkTables( new, env or _G ) )
end

function SetTable( env, path, tbl, makeCopy )
    ArgAssert( env, 1, "table" )
    ArgAssert( tbl, 3, "table" )

    local object = {}
    for key, value in pairs( tbl ) do
        if type( key ) == "table" then
            key = SetTable( env, nil, tbl, makeCopy )
        elseif makeCopy and type( key ) == "function" then
            key = debug_fcopy( setfenv( key, env ) )
        end

        if type( value ) == "table" then
            value = SetTable( env, nil, tbl, makeCopy )
        elseif makeCopy and type( value ) == "function" then
            value = debug_fcopy( setfenv( value, env ) )
        end

        object[ key ] = value
    end

    if path ~= nil then
        return table_SetValue( env, path, object )
    else
        return object
    end
end
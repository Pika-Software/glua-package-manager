local table_SetValue = table.SetValue
local setmetatable = setmetatable
local debug_fcopy = debug.fcopy
local isfunction = isfunction
local ArgAssert = ArgAssert
local istable = istable
local setfenv = setfenv
local pairs = pairs
local _G = _G

module( "gpm.environment" )

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

        setmetatable( a, meta )
        return a
    end

end

--
function Create( func, env )
    ArgAssert( func, 1, "function" )

    local new = {}
    setfenv( func, LinkTables( new, env or _G ) )
    return new, func
end

--

--
do

    function SetFunction( env, path, func, makeCopy )
        ArgAssert( func, 1, "function" )
        if (makeCopy) then
            func = debug_fcopy( func )
        end

        return table_SetValue( env, path, setfenv( func, env ) )
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
            key = debug_fcopy( setfenv( key, env ) )
        end

        if istable( value ) then
            value = SetTable( env, nil, tbl, makeCopy )
        elseif makeCopy and isfunction( value ) then
            value = debug_fcopy( setfenv( value, env ) )
        end

        object[ key ] = value
    end

    if (path) then
        return table_SetValue( env, path, object )
    else
        return object
    end
end

--
function SetLinkedTable( env, path, tbl )
    return table_SetValue( env, path, LinkTables( {}, tbl ) )
end
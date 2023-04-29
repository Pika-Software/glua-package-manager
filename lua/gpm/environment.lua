-- Libraries
local table = table

-- Variables
local getmetatable = getmetatable
local setmetatable = setmetatable
local debug_fcopy = debug.fcopy
local ArgAssert = ArgAssert
local setfenv = setfenv
local rawget = rawget
local rawset = rawset
local ipairs = ipairs
local pairs = pairs
local type = type
local _G = _G

module( "gpm.environment" )

function SetValue( env, path, func, makeCopy )
    ArgAssert( func, 1, "function" )
    return table.SetValue( env, path, setfenv( makeCopy and debug_fcopy( func ) or func, env ) )
end

do

    local meta = {}

    function meta:__index( key )
        local indexes = rawget( self, "__indexes" )
        if indexes ~= nil then
            for _, index in ipairs( indexes ) do
                local value = index[ key ]
                if value == nil then continue end

                return value
            end
        end

        -- return rawget( self, key )
    end

    function LinkMetaTables( a, b )
        ArgAssert( a, 1, "table" )
        ArgAssert( b, 2, "table" )

        local aMeta = getmetatable( a )
        if aMeta ~= meta then
            setmetatable( a, meta )

            local indexes = rawget( a, "__indexes" )
            if type( indexes ) ~= "table" then
                indexes = {}; rawset( a, "__indexes", indexes )
            end

            table.RemoveByValue( indexes, b )
            table.insert( indexes, 1, b )
        end

        return a
    end

end

function Create( func, env )
    ArgAssert( func, 1, "function" )

    local new = {}
    return new, setfenv( func, LinkMetaTables( new, env or _G ) )
end

function SetLinkedTable( env, path, tbl )
    return table.SetValue( env, path, LinkMetaTables( {}, tbl ) )
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
        return table.SetValue( env, path, object )
    else
        return object
    end
end
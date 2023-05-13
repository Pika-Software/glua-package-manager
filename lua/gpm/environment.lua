-- Libraries
local table = table

-- Variables
local getmetatable = getmetatable
local setmetatable = setmetatable
local debug_fcopy = debug.fcopy
local ArgAssert = gpm.ArgAssert
local setfenv = setfenv
local rawget = rawget
local rawset = rawset
local ipairs = ipairs
local pairs = pairs
local type = type

module( "gpm.environment" )

function SetValue( env, path, value, makeCopy )
    if type( value ) == "function" then
        if makeCopy then
            value = debug_fcopy( value )
        end

        setfenv( value, env )
    elseif makeCopy then
        value = table.Copy( value )
    end

    return table.SetValue( env, path, value )
end

do

    local ENVIRONMENT = {}

    function ENVIRONMENT:__index( key )
        local indexes = rawget( self, "__indexes" )
        if not indexes then return end

        for _, index in ipairs( indexes ) do
            local value = index[ key ]
            if value ~= nil then
                return value
            end
        end
    end

    function LinkMetaTables( a, b )
        ArgAssert( a, 1, "table" )
        ArgAssert( b, 2, "table" )

        local metaTable = getmetatable( a )
        if metaTable ~= ENVIRONMENT then
            setmetatable( a, ENVIRONMENT )
        end

        local indexes = rawget( a, "__indexes" )
        if type( indexes ) ~= "table" then
            indexes = {}; rawset( a, "__indexes", indexes )
        end

        table.RemoveByValue( indexes, b )
        table.insert( indexes, 1, b )

        return a
    end

end

function Create( func, env )
    ArgAssert( func, 1, "function" )

    local new = {}
    if type( env ) == "table" then
        LinkMetaTables( new, env )
    end

    return new, setfenv( func, new )
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

    if not path then return object end

    return table.SetValue( env, path, object )
end
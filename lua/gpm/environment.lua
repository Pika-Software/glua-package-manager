-- Libraries
local table = table

-- Variables
local setmetatable = setmetatable
local debug_fcopy = debug.fcopy
local ArgAssert = gpm.ArgAssert
local setfenv = setfenv
local rawget = rawget
local ipairs = ipairs
local pairs = pairs
local type = type

module( "gpm.environment" )

function SetValue( environment, path, value, makeCopy )
    if type( value ) == "function" then
        if makeCopy then
            value = debug_fcopy( value )
        end

        setfenv( value, environment )
    elseif makeCopy then
        value = table.Copy( value )
    end

    return table.SetValue( environment, path, value )
end

do

    local ENVIRONMENT = {}

    function ENVIRONMENT:__index( key )
        for _, index in ipairs( rawget( self, "__indexes" ) ) do
            local value = index[ key ]
            if value ~= nil then
                return value
            end
        end
    end

    function Link( a, b )
        local indexes = rawget( a, "__indexes" )
        table.RemoveByValue( indexes, b )
        table.insert( indexes, 1, b )
        return a
    end

    function Create( tbl )
        local environment = setmetatable( {
            ["__indexes"] = {}
        }, ENVIRONMENT )

        if type( tbl ) ~= "table" then
            return environment
        end

        return Link( environment, tbl )
    end

end

function SetLinkedTable( environment, path, tbl )
    return table.SetValue( environment, path, Create( tbl ) )
end

function SetTable( environment, path, tbl, makeCopy )
    ArgAssert( environment, 1, "table" )
    ArgAssert( tbl, 3, "table" )

    local object = {}
    for key, value in pairs( tbl ) do
        if type( key ) == "table" then
            key = SetTable( environment, nil, tbl, makeCopy )
        elseif makeCopy and type( key ) == "function" then
            key = debug_fcopy( setfenv( key, environment ) )
        end

        if type( value ) == "table" then
            value = SetTable( environment, nil, tbl, makeCopy )
        elseif makeCopy and type( value ) == "function" then
            value = debug_fcopy( setfenv( value, environment ) )
        end

        object[ key ] = value
    end

    if not path then return object end

    return table.SetValue( environment, path, object )
end
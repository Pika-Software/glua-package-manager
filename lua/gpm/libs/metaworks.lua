local table_RemoveByIValue = table.RemoveByIValue
local debug_setmetatable = debug.setmetatable
local table_SetValue = table.SetValue
local debug_setfenv = debug.setfenv
local table_Lookup = table.Lookup
local table_insert = table.insert
local rawget = rawget
local error = error
local type = type

module( "metaworks" )
_VERSION = "1.0.0"

GetValue = table_Lookup

function SetValue( tbl, keyPath, value )
    if type( value ) == "function" then
        debug_setfenv( value, tbl )
    end

    return table_SetValue( tbl, keyPath, value )
end

function GetLinks( tbl )
    return rawget( tbl, "__indexes" )
end

function UnLink( table1, table2 )
    table_RemoveByIValue( GetLinks( table1 ), table2 )
    return table1
end

function Link( table1, table2 )
    UnLink( table1, table2 )
    table_insert( GetLinks( table1 ), 1, table2 )
    return table1
end

if type( META ) ~= "table" then
    META = {}
end

function META:__index( key )
    local links = GetLinks( self )
    for index = 1, #links do
        local value = rawget( links[ index ], key )
        if value ~= nil then
            return value
        end
    end
end

function Create( any )
    local object = {
        ["__indexes"] = {}
    }

    debug_setmetatable( object, META )

    if any ~= nil then
        return Link( object, any )
    end

    return object
end

function CreateLink( object, read, write )
    local meta = {}
    if read then
        meta.__index = object
    end

    if write then
        meta.__newindex = object
    end

    local result = {}
    if debug_setmetatable( result, meta ) then
        return result, meta
    end

    error( "Unable to create a link to a given object." )
end
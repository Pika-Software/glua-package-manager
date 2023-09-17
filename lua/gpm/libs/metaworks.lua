local debug_setmetatable = debug.setmetatable
local rawget = rawget
local type = type

local metaworks = gpm.metaworks
if type( metaworks ) ~= "table" then
    metaworks = {}; gpm.metaworks = metaworks
end

metaworks.VERSION = "1.0.0"
metaworks.GetValue = table.Lookup

do

    local table_SetValue = table.SetValue
    local debug_setfenv = debug.setfenv

    function metaworks.SetValue( tbl, keyPath, value )
        if type( value ) == "function" then
            debug_setfenv( value, tbl )
        end

        return table_SetValue( tbl, keyPath, value )
    end

end

function metaworks.GetLinks( tbl )
    return rawget( tbl, "__indexes" )
end

local metaworks_GetLinks = metaworks.GetLinks

do
    local table_RemoveByIValue = table.RemoveByIValue
    function metaworks.UnLink( table1, table2 )
        table_RemoveByIValue( metaworks_GetLinks( table1 ), table2 )
        return table1
    end
end

do

    local metaworks_UnLink = metaworks.UnLink
    local table_insert = table.insert

    function metaworks.Link( table1, table2 )
        metaworks_UnLink( table1, table2 )
        table_insert( metaworks_GetLinks( table1 ), 1, table2 )
        return table1
    end

end

do

    local metaworks_Link = metaworks.Link

    local meta = metaworks.META
    if type( meta ) ~= "table" then
        meta = {}; metaworks.META = meta
    end

    function meta:__index( key )
        local links = metaworks_GetLinks( self )
        for index = 1, #links do
            local value = rawget( links[ index ], key )
            if value ~= nil then
                return value
            end
        end
    end

    function metaworks.Create( any )
        local object = {
            ["__indexes"] = {}
        }

        debug_setmetatable( object, meta )

        if any ~= nil then
            return metaworks_Link( object, any )
        end

        return object
    end

end

local error = error

function metaworks.CreateLink( object, read, write )
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

return metaworks
if SERVER
    AddCSLuaFile!

debug_setmetatable = debug.setmetatable
rawget = rawget
error = error
type = type

metaworks = gpm.Lib "metaworks"
metaworks.VERSION = "1.0.0"
metaworks.GetValue = table.Lookup

do

    table_SetValue = table.SetValue
    debug_setfenv = debug.setfenv

    metaworks.SetValue = ( tbl, keyPath, value ) ->
        if type( value ) == "function" then
            debug_setfenv( value, tbl )
        table_SetValue( tbl, keyPath, value )

metaworks.GetLinks = ( tbl ) ->
    rawget( tbl, "__indexes" )

metaworks_GetLinks = metaworks.GetLinks

do
    table_RemoveByIValue = table.RemoveByIValue
    metaworks.UnLink = ( table1, table2 ) ->
        table_RemoveByIValue( metaworks_GetLinks( table1 ), table2 )
        table1

do

    metaworks_UnLink = metaworks.UnLink
    table_insert = table.insert

    metaworks.Link = ( table1, table2 ) ->
        metaworks_UnLink( table1, table2 )
        table_insert( metaworks_GetLinks( table1 ), 1, table2 )
        table1

do

    metaworks_Link = metaworks.Link

    meta = metaworks.META
    if type( meta ) ~= "table"
        meta = {}
        metaworks.META = meta

    meta.__index = ( key ) ->
        for link in *metaworks_GetLinks( self )
            value = rawget( link, key )
            if value ~= nil
                return value

    metaworks.Create = ( any ) ->
        object = { __indexes: {} }
        debug_setmetatable( object, meta )

        if any ~= nil
            return metaworks_Link( object, any )

        object

metaworks.CreateLink = ( object, read, write ) ->
    meta = {}
    if read
        meta.__index = object

    if write
        meta.__newindex = object

    result = {}
    if debug_setmetatable( result, meta )
        return result, meta

    error( "Unable to create a link to a given object." )

metaworks
-- Libraries
local table = table
local debug = debug

-- Variables
local setmetatable = setmetatable
local rawget = rawget
local ipairs = ipairs
local type = type

module( "gpm.environment" )

function SetValue( environment, path, value, makeCopy )
    if type( value ) == "function" then
        if makeCopy then
            value = debug.fcopy( value )
        end

        debug.setfenv( value, environment )
    elseif makeCopy then
        value = table.Copy( value )
    end

    return table.SetValue( environment, path, value )
end

do

    if type( ENVIRONMENT ) ~= "table" then
        ENVIRONMENT = {}
    end

    function GetLinks( environment )
        return rawget( environment, "__indexes" )
    end

    function ENVIRONMENT:__index( key )
        local links = GetLinks( self )
        for index = 1, #links do
            local value = links[ index ][ key ]
            if value == nil then continue end
            return value
        end
    end

    function Link( environment1, environment2 )
        UnLink( environment1, environment2 )
        table.insert( GetLinks( environment1 ), 1, environment2 )
        return environment1
    end

    function UnLink( environment1, environment2 )
        local links = GetLinks( environment1 )
        for index, environment in ipairs( links ) do
            if environment == environment2 then
                table.remove( links, index )
                break
            end
        end

        return environment1
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
local ArgAssert = ArgAssert
local Color = Color

module( 'gpm.colors' )

local all = {
    ['white'] = Color( 255, 255, 255 ),
    ['client'] = Color( 225, 170, 10 ),
    ['server'] = Color( 5, 170, 250 ),
    ['200'] = Color( 200, 200, 200 ),
    ['150'] = Color( 150, 150, 150 ),
    ['menu'] = Color( 75, 175, 80 ),
    ['green'] = Color( 0, 255, 0 ),
    ['blue'] = Color( 0, 0, 255 ),
    ['red'] = Color( 255, 0, 0 ),
    ['black'] = Color( 0, 0, 0 )
}

-- White & Black
White = all.white
Black = all.black

-- RGB
Green = all.green
Blue = all.blue
Red = all.red

-- Server, Client & Menu
Client = all.client
Server = all.server

-- Get color by name
function Get( name )
    local color = all[ name ]
    if (color) then
        return color
    end

    return all.white
end

-- Set color by name
function Set( name, value )
    ArgAssert( name, 1, 'string' )
    ArgAssert( value, 2, 'table' )

    local color = all[ name ]
    if (color) then
        color.r = value.r
        color.g = value.g
        color.b = value.b
        color.a = value.a
        return
    end

    all[ name ] = value
end

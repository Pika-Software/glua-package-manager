-- Libraries
local promise = gpm.promise
local file = file

module( "gpm.sources.gmad", package.seeall )

function CanImport( filePath )
    return file.Exists( filePath, "GAME" ) and string.EndsWith( filePath, ".gma.dat" ) or string.EndsWith( filePath, ".gma" )
end

Import = promise.Async( function( filePath )

end )
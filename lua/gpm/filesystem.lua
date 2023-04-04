-- Libraries
local promise = gpm.promise
local file = file

-- Variables
local string_format = string.format

do

    local File = FindMetaTable( "File" )

    function File:SkipEmpty()
        while not self:EndOfFile() do
            if self:ReadByte() ~= 0 then self:Skip( -1 ) break end
        end
    end

    function File:ReadString()
        local startPos = self:Tell()
        local len = 0

        while not self:EndOfFile() and self:ReadByte() ~= 0 do
            len = len + 1
        end

        self:Seek( startPos )
        local data = self:Read( len )
        self:Skip( 1 )

        return data
    end

    function File:WriteString( str )
        self:Write( str )
        self:WriteByte( 0 )
    end

end

module( "gpm.filesystem", package.seeall )

for key, value in pairs( file ) do
    gpm.filesystem[ key ] = value
end

function Size( filePath, gamePath )
    local fileClass = file.Open( filePath, "rb", gamePath )
    if not fileClass then return -1 end

    local size = fileClass:Size()
    fileClass:Close()

    if not size then return -1 end
    return size
end

-- Sync Methods
function Read( filePath, gamePath )
    local fileClass = file.Open( filePath, "rb", gamePath )
    if not fileClass then return "" end

    local content = fileClass:Read( fileClass:Size() )
    fileClass:Close()

    if not content then return "" end
    return content
end

-- Async Methods
ERROR_CODES = {
    [-8] = "not mine",
    [-7] = "retry later",
    [-6] = "alignment",
    [-5] = "failure",
    [-4] = "reading",
    [-3] = "no memory",
    [-2] = "unknownid",
    [-1] = "cannot open file",
    [1] = "pending",
    [2] = "in progress",
    [3] = "aborted",
    [4] = "unserviced"
}

function AsyncError( errorCode, filePath, gamePath )
    local errorMessage = ERROR_CODES[ errorCode ]
    if not errorMessage then
        errorMessage = "unknown error"
    end

    return string_format( "error code %s, %s, file %s (%s)", errorCode, errorMessage, filePath, gamePath )
end

function AsyncRead( filePath, gamePath )
    local p = promise.New()

    local result = file.AsyncRead( filePath, gamePath, function( _, __, status, content )
        if status ~= 0 then
            return p:Reject( AsyncError( status, filePath, gamePath ) )
        end

        p:Resolve( content )
    end )

    if result ~= 0 then
       p:Reject( AsyncError( result, filePath, gamePath ) )
    end

    return p
end

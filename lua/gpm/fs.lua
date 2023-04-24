-- Libraries
local promise = gpm.promise
local string = string
local file = file

-- Variables
local CompileString = CompileString
local ipairs = ipairs
local pcall = pcall

-- https://github.com/WilliamVenner/gm_async_write
if not file.AsyncWrite and util.IsBinaryModuleInstalled( "async_write" ) then require( "async_write" ) end

module( "gpm.fs" )

Delete = file.Delete
Exists = file.Exists
Rename = file.Rename
IsDir = file.IsDir
Open = file.Open
Find = file.Find
Size = file.Size
Time = file.Time

function Read( filePath, gamePath )
    local fileClass = file.Open( filePath, "rb", gamePath )
    if not fileClass then return end

    local content = fileClass:Read( fileClass:Size() )
    fileClass:Close()

    return content
end

function Write( filePath, contents )
    local fileClass = file.Open( filePath, "wb", "DATA" )
    if not fileClass then return end
    fileClass:Write( contents )
    fileClass:Close()
end

function Append( filePath, contents )
    local fileClass = file.Open( filePath, "ab", "DATA" )
    if not fileClass then return end
    fileClass:Write( contents )
    fileClass:Close()
end

function CreateDir( folderPath )
    local currentPath = nil
    for _, folderName in ipairs( string.Split( folderPath, "/" ) ) do
        if currentPath == nil then
            currentPath = folderName
        else
            currentPath = currentPath .. "/" .. folderName
        end

        if not file.IsDir( currentPath, "DATA" ) then
            file.Delete( currentPath )
            file.CreateDir( currentPath )
        end
    end
end

function AsyncRead( filePath, gamePath )
    local p = promise.New()

    local status = file.AsyncRead( filePath, gamePath, function( filePath, gamePath, status, content )
        if status ~= 0 then return p:Reject( "Error code: " .. status ) end
        p:Resolve( {
            ["filePath"] = filePath,
            ["gamePath"] = gamePath,
            ["content"] = content
        } )
    end )

    if status ~= 0 then
        p:Reject( "Error code: " .. status )
    end

    return p
end

Compile = promise.Async( function( filePath, gamePath, handleError )
    local ok, result = AsyncRead( filePath, gamePath ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local ok, result = pcall( CompileString, result.content, result.filePath, handleError )
    if not ok then return promise.Reject( result ) end
    if not result then return promise.Reject( "File `" .. filePath .. "` (" .. gamePath .. ") compilation failed." ) end

    return result
end )

if not file.AsyncWrite or not file.AsyncAppend then

    function AsyncWrite( filePath, content )
        local p = promise.New()

        Write( filePath, content )

        if Exists( filePath, "DATA" ) then
            p:Resolve( filePath )
        else
            p:Reject( "failed" )
        end

        return p
    end

    function AsyncAppend( filePath, content )
        local p = promise.New()

        Append( filePath, content )
        p:Resolve( filePath )

        return p
    end

    return
end

function AsyncWrite( filePath, content )
    local p = promise.New()

    local status = file.AsyncWrite( filePath, content, function( filePath, status )
        if status ~= 0 then return p:Reject( "Error code: " .. status ) end
        p:Resolve( filePath )
    end )

    if status ~= 0 then
        p:Reject( "Error code: " .. status )
    end

    return p
end

function AsyncAppend( filePath, content )
    local p = promise.New()

    local status = file.AsyncAppend( filePath, content, function( filePath, status )
        if status ~= 0 then return p:Reject( "Error code: " .. status ) end
        p:Resolve( filePath )
    end )

    if status ~= 0 then
        p:Reject( "Error code: " .. status )
    end

    return p
end
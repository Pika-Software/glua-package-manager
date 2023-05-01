if not asyncio then
    -- https://github.com/Pika-Software/gm_asyncio
    if util.IsBinaryModuleInstalled( "asyncio" ) then
        require( "asyncio" )
    -- https://github.com/WilliamVenner/gm_async_write
    elseif not file.AsyncWrite and util.IsBinaryModuleInstalled( "async_write" ) then
        require( "async_write" )
    end
end

-- Libraries
local promise = gpm.promise
local asyncio = asyncio
local string = string
local file = file

-- Variables
local CompileString = CompileString
local math_max = math.max
local SERVER = SERVER
local ipairs = ipairs
local pcall = pcall
local type = type

module( "gpm.fs" )

Delete = file.Delete
Exists = file.Exists
Rename = file.Rename
IsDir = file.IsDir
Open = file.Open
Find = file.Find
Size = file.Size
Time = file.Time

function Read( filePath, gamePath, lenght )
    local fileClass = file.Open( filePath, "rb", gamePath )
    if not fileClass then return end

    local fileContent = fileClass:Read( type( lenght ) == "number" and math_max( 0, lenght ) or fileClass:Size() )
    fileClass:Close()

    return fileContent
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

Compile = promise.Async( function( filePath, gamePath, handleError )
    local ok, result = AsyncRead( filePath, gamePath ):SafeAwait()
    if not ok then return promise.Reject( result ) end

    local ok, result = pcall( CompileString, result.fileContent, result.filePath, handleError )
    if not ok then return promise.Reject( result ) end
    if not result then return promise.Reject( "File `" .. filePath .. "` (" .. gamePath .. ") compilation failed." ) end

    return result
end )

if asyncio ~= nil then

    function AsyncRead( filePath, gamePath )
        local p = promise.New()

        if asyncio.AsyncRead( filePath, gamePath, function( filePath, gamePath, status, fileContent )
            if status ~= 0 then return p:Reject( "Error code: " .. status ) end
            p:Resolve( {
                ["fileContent"] = fileContent,
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end ) ~= 0 then
            p:Reject( "Error code: " .. status )
        end

        return p
    end

    function AsyncWrite( filePath, fileContent )
        local p = promise.New()

        if asyncio.AsyncWrite( filePath, fileContent, function( filePath, gamePath, status )
            if status ~= 0 then return p:Reject( "Error code: " .. status ) end
            p:Resolve( {
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end ) ~= 0 then
            p:Reject( "Error code: " .. status )
        end

        return p
    end

    function AsyncAppend( filePath, fileContent )
        local p = promise.New()

        if asyncio.AsyncAppend( filePath, fileContent, function( filePath, gamePath, status )
            if status ~= 0 then return p:Reject( "Error code: " .. status ) end
            p:Resolve( {
                ["filePath"] = filePath,
                ["gamePath"] = gamePath
            } )
        end ) ~= 0 then
            p:Reject( "Error code: " .. status )
        end

        return p
    end

    return
end

function AsyncRead( filePath, gamePath )
    local p = promise.New()

    if file.AsyncRead( filePath, gamePath, function( filePath, gamePath, status, fileContent )
        if status ~= 0 then return p:Reject( "Error code: " .. status ) end
        p:Resolve( {
            ["filePath"] = filePath,
            ["gamePath"] = gamePath,
            ["fileContent"] = fileContent
        } )
    end ) ~= 0 then
        p:Reject( "Error code: " .. status )
    end

    return p
end

if not file.AsyncWrite or not file.AsyncAppend then

    function AsyncWrite( filePath, fileContent )
        local p = promise.New()

        Write( filePath, fileContent )

        if Exists( filePath, "DATA" ) then
            p:Resolve( {
                ["filePath"] = filePath
            } )
        else
            p:Reject( "failed" )
        end

        return p
    end

    function AsyncAppend( filePath, fileContent )
        local p = promise.New()

        Append( filePath, fileContent )
        p:Resolve( {
            ["filePath"] = filePath
        } )

        return p
    end

    return
end

if not SERVER then return end

function AsyncWrite( filePath, fileContent )
    local p = promise.New()

    if file.AsyncWrite( filePath, fileContent, function( filePath, status )
        if status ~= 0 then return p:Reject( "Error code: " .. status ) end
        p:Resolve( {
            ["filePath"] = filePath
        } )
    end ) ~= 0 then
        p:Reject( "Error code: " .. status )
    end

    return p
end

function AsyncAppend( filePath, fileContent )
    local p = promise.New()

    if file.AsyncAppend( filePath, fileContent, function( filePath, status )
        if status ~= 0 then return p:Reject( "Error code: " .. status ) end
        p:Resolve( {
            ["filePath"] = filePath
        } )
    end ) ~= 0 then
        p:Reject( "Error code: " .. status )
    end

    return p
end
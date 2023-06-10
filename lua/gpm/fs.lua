-- https://github.com/Pika-Software/gm_asyncio
if util.IsBinaryModuleInstalled( "asyncio" ) then
    gpm.Logger:Info( "A third-party file system API 'asyncio' has been initialized." )
    require( "asyncio" )
-- https://github.com/WilliamVenner/gm_async_write
elseif SERVER and util.IsBinaryModuleInstalled( "async_write" ) then
    gpm.Logger:Info( "A third-party file system API 'async_write' has been initialized." )
    require( "async_write" )
end

-- Libraries
local asyncio = asyncio
local promise = promise
local string = string
local table = table
local file = file

-- Variables
local CompileString = CompileString
local math_max = math.max
local ipairs = ipairs
local assert = assert
local type = type

module( "gpm.fs" )

Delete = file.Delete
Rename = file.Rename
Open = file.Open
Find = file.Find
Size = file.Size
Time = file.Time

function Exists( filePath, gamePath )
    if SERVER then return file.Exists( filePath, gamePath ) end
    if file.Exists( filePath, gamePath ) then return true end

    local files, folders = file.Find( filePath .. "*", gamePath )
    if not files or not folders then return false end
    if #files == 0 and #folders == 0 then return false end

    local splits = string.Split( filePath, "/" )
    local fileName = splits[ #splits ]

    return table.HasIValue( files, fileName ) or table.HasIValue( folders, fileName )
end

function IsDir( filePath, gamePath )
    if SERVER then return file.IsDir( filePath, gamePath ) end
    if file.IsDir( filePath, gamePath ) then return true end

    local _, folders = file.Find( filePath .. "*", gamePath )
    if folders == nil or #folders == 0 then return false end

    local splits = string.Split( filePath, "/" )
    return table.HasIValue( folders, splits[ #splits ] )
end

function IsFile( filePath, gamePath )
    if SERVER then
        return file.Exists( filePath, gamePath ) and not file.IsDir( filePath, gamePath )
    end

    if file.Exists( filePath, gamePath ) and not file.IsDir( filePath, gamePath ) then return true end

    local files, _ = file.Find( filePath .. "*", gamePath )
    if not files or #files == 0 then return false end
    local splits = string.Split( filePath, "/" )

    return table.HasIValue( files, splits[ #splits ] )
end

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
        if not folderName then continue end

        currentPath = currentPath and ( currentPath .. "/" .. folderName ) or folderName
        if IsDir( currentPath, "DATA" ) then continue end

        file.Delete( currentPath )
        file.CreateDir( currentPath )
    end

    return currentPath
end

Compile = promise.Async( function( filePath, gamePath, handleError )
    local data = AsyncRead( filePath, gamePath ):Await()
    local func = CompileString( data.fileContent, data.filePath, handleError )
    assert( type( func ) == "function", "file '" .. filePath .. "' (" .. gamePath .. ") compilation failed." )
    return func
end )

if type( asyncio ) == "table" then
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

if type( file.AsyncWrite ) == "function" then

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

else

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

end

if type( file.AsyncAppen ) == "function" then

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

else

    function AsyncAppend( filePath, fileContent )
        local p = promise.New()

        Append( filePath, fileContent )
        p:Resolve( {
            ["filePath"] = filePath
        } )

        return p
    end

end
-- Libraries
local string = string
local debug = debug
local table = table
local gpm = gpm

-- Variables
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local type = type

-- https://wiki.facepunch.com/gmod/string.StartsWith
string.StartsWith = string.StartsWith or string.StartWith

-- https://wiki.facepunch.com/gmod/string.Split
function string.Split( str, separator )
    return string.Explode( separator, str, false )
end

do

    local TYPE_NONE = TYPE_NONE

    local types = gpm.Types
    if type( types ) ~= "table" then
        types = {
            -- https://wiki.facepunch.com/gmod/Enums/TYPE
            ["Names"] = {
                [TYPE_PARTICLESYSTEM] = "CNewParticleEffect",
                [TYPE_PROJECTEDTEXTURE] = "ProjectedTexture",
                [TYPE_PIXELVISHANDLE] = "pixelvis_handle_t",
                [TYPE_RECIPIENTFILTER] = "CRecipientFilter",
                [TYPE_SOUNDHANDLE] = "IGModAudioChannel",
                [TYPE_LIGHTUSERDATA] = "light userdata",
                [TYPE_PARTICLEEMITTER] = "CLuaEmitter",
                [TYPE_DAMAGEINFO] = "CTakeDamageInfo",
                [TYPE_LOCOMOTION] = "CLuaLocomotion",
                [TYPE_SURFACEINFO] = "SurfaceInfo",
                [TYPE_PHYSCOLLIDE] = "PhysCollide",
                [TYPE_EFFECTDATA] = "CEffectData",
                [TYPE_PARTICLE] = "CLuaParticle",
                [TYPE_NAVLADDER] = "CNavLadder",
                [TYPE_VIDEO] = "IVideoWriter",
                [TYPE_MATERIAL] = "IMaterial",
                [TYPE_MOVEDATA] = "CMoveData",
                [TYPE_PATH] = "PathFollower",
                [TYPE_SOUND] = "CSoundPatch",
                [TYPE_USERDATA] = "userdata",
                [TYPE_FUNCTION] = "function",
                [TYPE_TEXTURE] = "ITexture",
                [TYPE_USERCMD] = "CUserCmd",
                [TYPE_RESTORE] = "IRestore",
                [TYPE_NAVAREA] = "CNavArea",
                [TYPE_PHYSOBJ] = "PhysObj",
                [TYPE_DLIGHT] = "dlight_t",
                [TYPE_USERMSG] = "bf_read",
                [TYPE_MATRIX] = "VMatrix",
                [TYPE_CONVAR] = "ConVar",
                [TYPE_VECTOR] = "Vector",
                [TYPE_ENTITY] = "Entity",
                [TYPE_THREAD] = "thread",
                [TYPE_STRING] = "string",
                [TYPE_NUMBER] = "number",
                [TYPE_NONE] = "unknown",
                [TYPE_BOOL] = "boolean",
                [TYPE_IMESH] = "IMesh",
                [TYPE_PANEL] = "Panel",
                [TYPE_ANGLE] = "Angle",
                [TYPE_COLOR] = "Color",
                [TYPE_TABLE] = "table",
                [TYPE_SAVE] = "ISave",
                [TYPE_FILE] = "File",
                [TYPE_NIL] = "nil"
            },
            ["IDs"] = {}
        }

        gpm.Types = types
    end

    local ids = types.IDs

    -- https://wiki.facepunch.com/gmod/Global.TypeID
    do

        local TypeID = TypeID

        function gpm.TypeID( any )
            for _, data in ipairs( ids ) do
                if data[ 1 ]( any ) then
                    return data[ 2 ]
                end
            end

            return TypeID( any )
        end

    end

    local names = types.Names

    -- https://wiki.facepunch.com/gmod/Global.type
    function gpm.type( any )
        local str = names[ gpm.TypeID( any ) ]
        if str ~= nil then return str end
        return names[ TYPE_NONE ] or "unknown"
    end

    -- gpm.AddType( typeName, func )
    function gpm.AddType( typeName, func )
        gpm.ArgAssert( typeName, 1, "string" )
        gpm.ArgAssert( func, 2, "function" )

        local index = 256
        for key, name in pairs( names ) do
            if typeName == name then
                index = key
                break
            elseif key >= index then
                index = key + 1
            end
        end

        names[ index ] = typeName

        for index2, data in ipairs( ids ) do
            if index == data[ 2 ] then
                table.remove( ids, index2 )
                break
            end
        end

        ids[ #ids + 1 ] = { func, index }
        return index
    end

end

-- Checks if argument have valid type
do

    local error = error

    function gpm.ArgAssert( value, argNum, expected, errorlevel )
        local valueType = gpm.type( value )
        if valueType == expected then
            return value
        end

        local dinfo = debug.getinfo( 2, "n" )
        error( string.format( "bad argument #%d to \'%s\' (%s expected, got %s)", argNum, dinfo and dinfo.name or "func", expected, valueType ), errorlevel or 3 )
    end

end

-- Returns true if string is url
function string.IsURL( str )
    return string.match( str, "^https?://.+$" ) ~= nil
end

-- Make JIT happy
function debug.fempty()
end

function debug.fcall( func )
    return func()
end

-- FileClass extensions
do

    local meta = FindMetaTable( "File" )

    function meta:SkipEmpty()
        while not self:EndOfFile() do
            if self:ReadByte() ~= 0 then self:Skip( -1 ) break end
        end
    end

    function meta:ReadString()
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

    function meta:WriteString( str )
        self:Write( str )
        self:WriteByte( 0 )
    end

end

-- https://wiki.facepunch.com/gmod/Global.IsColor
do

    local meta = FindMetaTable( "Color" )
    local getmetatable = getmetatable

    function IsColor( any )
        if getmetatable( any ) == meta then
            return true
        end

        if type( any ) == "table" then
            return type( any.r ) == "number" and type( any.g ) == "number" and type( any.b ) == "number"
        end

        return false
    end

    gpm.AddType( "Color", IsColor )

end

do

    local timer_Simple = timer.Simple
    local unpack = unpack

    function util.NextTick( func, ... )
        gpm.ArgAssert( func, 1, "function" )

        local args = {...}
        timer_Simple( 0, function()
            if #args ~= 0 then
                func( unpack( args ) )
                return
            end

            func()
        end )
    end

end

function table.HasIValue( tbl, any )
    for _, value in ipairs( tbl ) do
        if value == any then
            return true
        end
    end

    return false
end

function table.RemoveByIValue( tbl, any )
    for index, value in ipairs( tbl ) do
        if value ~= any then continue end
        return table.remove( tbl, index )
    end
end

function table.Lookup( tbl, str, default )
    for _, key in ipairs( string.Split( str, "." ) ) do
        tbl = tbl[ key ]
        if not tbl then return default end
    end

    return tbl
end

function table.SetValue( tbl, str, value, ifEmpty )
    local keys = string.Split( str, "." )
    local count = #keys

    for num, key in ipairs( keys ) do
        if num == count then
            local oldValue = tbl[ key ]
            if oldValue ~= nil and ifEmpty then
                return oldValue
            end

            tbl[ key ] = value
            return value
        end

        local nextValue = tbl[ key ]
        if nextValue == nil then
            tbl[ key ] = {}
        elseif type( nextValue ) ~= "table" then
            return
        end

        tbl = tbl[ key ]
    end
end

do

    local file_Exists = file.Exists
    local system = system
    local jit = jit

    local suffix = ( { "osx64", "osx", "linux64", "linux", "win64", "win32" } )[ ( system.IsWindows() and 4 or 0 ) + ( system.IsLinux() and 2 or 0 ) + ( jit.arch == "x86" and 1 or 0 ) + 1 ]
    local fmt = "lua/bin/gm" .. ( CLIENT and "cl" or "sv" ) .. "_%s_%s.dll"
    local fmt = "lua/bin/gm" .. ( ( CLIENT and not MENU_DLL ) and "cl" or "sv" ) .. "_%s_%s.dll"

    function util.IsBinaryModuleInstalled( name )
        gpm.ArgAssert( name, 1, "string" )

        if file_Exists( string.format( fmt, name, suffix ), "GAME" ) then
            return true
        end

        if jit.versionnum ~= 20004 and jit.arch == "x86" and system.IsLinux() then
            return file_Exists( string.format( fmt, name, "linux32" ), "GAME" )
        end

        return false
    end

end

function util.IsLuaModuleInstalled( name )
    return gpm.fs.IsFile( "includes/modules/" .. name .. ".lua", "LUA" )
end

-- paths
local paths = gpm.paths
if type( paths ) ~= "table" then
    paths = {}; gpm.paths = paths
end

-- File path fix
function paths.Fix( filePath )
    return string.lower( string.gsub( filePath, "[/\\]+", "/" ) )
end

-- File path join
function paths.Join( ... )
    local args, filePath = { ... }
    local len = #args
    for i = 1, len do
        if filePath ~= nil then
            filePath = filePath .. args[ i ]
        else
            filePath = args[ i ]
        end

        if i == len then
            return paths.Fix( filePath )
        end

        filePath = filePath .. "/"
    end
end

-- File path localization
function paths.Localize( filePath )
    filePath = string.gsub( filePath, "^cache/moonloader/", "" )
    filePath = string.gsub( filePath, "^addons/[%w%-_]-/", "" )
    filePath = string.gsub( filePath, "^lua/", "" )
    return filePath
end

-- Change file extension to .lua
function paths.FormatToLua( filePath )
    local extension = string.GetExtensionFromFilename( filePath )
    if extension ~= "lua" then
        if extension then
            filePath = string.gsub( filePath, "%..+$", ".lua" )
        else
            filePath = filePath .. ".lua"
        end
    end

    return filePath
end

-- utils
local utils = gpm.utils
if type( utils ) ~= "table" then
    utils = {}; gpm.utils = utils
end

function utils.LowerTableKeys( tbl )
    for key, value in pairs( tbl ) do
        if type( value ) == "table" then
            value = utils.LowerTableKeys( value )
        end

        local keyType = type( key )
        if keyType == "string" then
            tbl[ key ] = nil; tbl[ string.lower( key ) ] = value
        elseif keyType == "table" then
            tbl[ key ] = nil; tbl[ utils.LowerTableKeys( key ) ] = value
        end
    end

    return tbl
end

function utils.Version( number )
    if not number then return "unknown" end
    if type( number ) == "string" then return number end
    local version = string.format( "%06d", number )
    return string.format( "%d.%d.%d", tonumber( string.sub( version, 0, 2 ) ), tonumber( string.sub( version, 3, 4 ) ), tonumber( string.sub( version, 5 ) ) )
end

function utils.GetCurrentFilePath()
    for i = 2, 6 do
        local info = debug.getinfo( i, "S" )
        if not info then break end
        if info.what ~= "main" then continue end
        return paths.Localize( paths.Fix( info.short_src ) )
    end
end

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
-- https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
local codes = {
    --[[--------------------
        Successful 2XX
    --------------------]]--
    [200] = {"OK", "The resource has been obtained"},
    [201] = {"Created", "The request succeeded, and a new resource was created as a result"},
    [202] = {"Accepted", "The request has been received but not yet acted upon"},
    [203] = {"Non-Authoritative Information", "This response code means the returned metadata is not exactly the same as is available from the origin server"},
    [204] = {"No Content", "The request has been send with no errors also there is no content to send for this request, but the headers may be useful"},
    [205] = {"Reset Content", "This response tells the client to reset the document view, so for example to clear the content of a form, reset a canvas state, or to refresh the UI"},
    [206] = {"Partial Content", "The request has succeeded and the body contains the requested ranges of data, as described in the Range header of the request"},
    [207] = {"Multi-Status", "This response code indicates that there might be a mixture of responses"},
    [208] = {"Already Reported", "This response code is used in a 207 (207 Multi-Status) response to save space and avoid conflicts"},

    --[[--------------------
        Client Error 4XX
    --------------------]]--
    [400] = {"Bad Request", "The server was unable to interpret the request given invalid syntax"},
    [401] = {"Unauthorized", "Authentication is required to get the requested response"},
    [403] = {"Forbidden", "You don't have the necessary permissions for certain content, so the server is refusing to grant an appropriate response"},
    [404] = {"Not Found", "The server was unable to find the requested content"},
    [405] = {"Method Not Allowed", "The requested method is known to the server but it has been disabled and cannot be used"},
    [408] = {"Request Timeout", "A timeout has occurred while processing an HTTP request"},
    [409] = {"Conflict", "The server encountered a conflict with the request sent with the current state of the server"},
    [410] = {"Gone", "The requested content has been deleted from the server"},
    [411] = {"Length Required", "The server rejected the request because the Content-Length is not defined"},
    [418] = {"I'm a teapot", "This client error response code indicates that the server refuses to brew coffee because it is, permanently, a teapot."},
    [429] = {"Rate limit reached for requests", "This error message indicates that you have hit your assigned rate limit for the API"},

    --[[--------------------
        Server Error 5XX
    --------------------]]--
    [500] = {"Internal Server Error", "This response means that the server encountered an unexpected condition that prevented it from fulfilling the request"},
    [501] = {"Not Implemented", "This response means that the server does not support the functionality required to fulfill the request"},
    [502] = {"Bad Gateway", "This response means that the server, while acting as a gateway or proxy, received an invalid response from the upstream server"},
    [503] = {"Service Unavailable", "This response means that the server is not ready to handle the request"},
    [504] = {"Gateway Timeout", "This response means that the server, while acting as a gateway or proxy, did not get a response in time from the upstream server that it needed in order to complete the request"},
    [505] = {"HTTP Version Not Supported", "This response status code indicates that the HTTP version used in the request is not supported by the server"},
    [507] = {"Insufficient Storage", "This operation couldn't succeed, maybe because the request it's too large to fit on a disk"},
    [508] = {"Loop Detected", "This status indicates that the entire operation failed, the server terminated an operation because it encountered an infinite loop"},
}

function http.GetStatusDescription( code )
    local data = codes[ code ]
    if data then
        return data[ 1 ], data[ 2 ]
    end
end
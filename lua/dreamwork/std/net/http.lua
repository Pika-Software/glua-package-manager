local _G = _G

local http_storage = dreamwork.storage.http
local Logger = dreamwork.Logger

---@class dreamwork.std
local std = dreamwork.std

local raw = std.raw
local raw_tonumber = raw.tonumber

local string = std.string
local string_gmatch = string.gmatch

local time = std.time
local time_elapsed = time.elapsed

local json = std.json
local json_serialize = json.serialize

local isNumber = std.isNumber
local isString = std.isString

local setTimeout = std.setTimeout
local error = std.error

local Future = std.Future


local http_client, client_name
if std.loadbinary( "reqwest" ) then
    ---@diagnostic disable-next-line: undefined-field
    local reqwest = _G.reqwest

    local user_agent = "DreamWork/" .. dreamwork.Version .. " - Garry's Mod/" .. std.GAME_VERSION
    local default_headers = { [ "User-Agent" ] = user_agent }

    function http_client( parameters )
        if parameters.headers == nil then
            parameters.headers = default_headers
        elseif parameters.headers[ "User-Agent" ] == nil then
            parameters.headers[ "User-Agent" ] = user_agent
        end

        reqwest( parameters )
        return true
    end

    client_name = "reqwest"
elseif std.LUA_CLIENT_SERVER and std.loadbinary( "chttp" ) then
    ---@diagnostic disable-next-line: undefined-field
    http_client = _G.CHTTP
    client_name = "chttp"
else
    http_client = _G.HTTP
    client_name = "Garry's Mod"
end

if http_client == nil then
    Logger:error( "HTTP client '%s' loading failed, sending requests is not possible.", client_name )
    http_client = std.debug.fempty
else
    Logger:info( "'%s' was loaded & connected as HTTP client.", client_name )
end

---@cast http_client fun( params: table ): boolean | nil

local make_request
do

    local queue, length = {}, 0

    ---@param parameters table
    function make_request( parameters )
        length = length + 1
        queue[ length ] = parameters
        return true
    end

    setTimeout( function()
        make_request = http_client

        for i = 1, length, 1 do
            http_client( queue[ i ] )
            queue[ i ] = nil
        end

        ---@diagnostic disable-next-line: cast-local-type
        queue, length = nil, nil
    end )

end

--- [SHARED AND MENU]
---
--- The http library allows either the server or client to communicate with external websites via HTTP.
---
---@class dreamwork.std.http
local http = std.http or {}
std.http = http

if http.StatusCodes == nil then

    --- [SHARED AND MENU]
    ---
    --- The table that converts HTTP status codes into their descriptions.
    ---
    ---@type table<integer, string>
    http.StatusCodes = {
        [ 100 ] = "Continue - Request received, please continue",
        [ 101 ] = "Switching Protocols - Switching to new protocol; obey Upgrade header",
        [ 102 ] = "Processing - WebDAV; request received and processing",

        [ 200 ] = "OK - Request succeeded",
        [ 201 ] = "Created - Resource successfully created",
        [ 202 ] = "Accepted - Request accepted but not completed",
        [ 203 ] = "Non-Authoritative Information - Returned meta info is from a third party",
        [ 204 ] = "No Content - No content to send for this request",
        [ 205 ] = "Reset Content - Reset the document view",
        [ 206 ] = "Partial Content - Partial GET successful",

        [ 300 ] = "Multiple Choices - Multiple options available",
        [ 301 ] = "Moved Permanently - Resource has been permanently moved",
        [ 302 ] = "Found - Resource temporarily moved",
        [ 303 ] = "See Other - See another URI using GET",
        [ 304 ] = "Not Modified - Resource not modified since last request",
        [ 307 ] = "Temporary Redirect - Resource temporarily moved, use original method",
        [ 308 ] = "Permanent Redirect - Resource moved permanently, use original method",

        [ 400 ] = "Bad Request - Malformed syntax or invalid request",
        [ 401 ] = "Unauthorized - Authentication required",
        [ 402 ] = "Payment Required - Reserved for future use",
        [ 403 ] = "Forbidden - Server understands but refuses to authorize",
        [ 404 ] = "Not Found - Resource not found",
        [ 405 ] = "Method Not Allowed - HTTP method not allowed",
        [ 406 ] = "Not Acceptable - No acceptable representation available",
        [ 408 ] = "Request Timeout - Client took too long",
        [ 409 ] = "Conflict - Request conflicts with current state",
        [ 410 ] = "Gone - Resource permanently unavailable",
        [ 418 ] = "I'm a teapot - April Fools joke / RFC 2324",
        [ 429 ] = "Too Many Requests - Rate limit exceeded",

        [ 500 ] = "Internal Server Error - Generic server error",
        [ 501 ] = "Not Implemented - Server doesn't support requested feature",
        [ 502 ] = "Bad Gateway - Invalid response from upstream server",
        [ 503 ] = "Service Unavailable - Server temporarily overloaded or down",
        [ 504 ] = "Gateway Timeout - Upstream server failed to respond in time",
        [ 505 ] = "HTTP Version Not Supported - Unsupported HTTP version"
    }

    std.setmetatable( http.StatusCodes, {
        __index = function( _, code )
            return "Unknown status code (" .. code .. ")"
        end
    } )

end

local dreamwork_http_timeout, dreamwork_http_cache_ttl
do

    ---@type dreamwork.std.console.Variable.Options
    local cvar_options = {
        name = "dreamwork.http.timeout",
        description = "The default timeout for http requests.",
        replicated = not std.LUA_MENU,
        archive = std.LUA_MENU_SERVER,
        type = "float",
        default = 10,
        min = 0,
        max = 300
    }

    dreamwork_http_timeout = std.console.Variable( cvar_options )
    http.Timeout = dreamwork_http_timeout

    cvar_options.name = "dreamwork.http.cache.ttl"
    cvar_options.description = "The cache time to live for the dreamwork http library in minutes."
    cvar_options.default = 1
    cvar_options.max = 40320

    dreamwork_http_cache_ttl = std.console.Variable( cvar_options )
    http.CacheTTL = dreamwork_http_cache_ttl

end

do

    -- TODO: make cookies

    ---@class dreamwork.std.Cookies : dreamwork.std.Object
    ---@field __class dreamwork.std.CookiesClass
    local Cookies = std.class.base( "http.Cookies" )

    -- TODO: https://github.com/nmap/nmap/blob/master/nselib/http.lua#L1010
    -- TODO: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cookie
    -- TODO: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie

    function Cookies:get( name, url )
        local cookie = self[ name ]


        return cookie
    end

    function Cookies:set( name, value, options )
        local cookie = {
            value = value
        }

        self[ name ] = cookie
    end

    ---@class dreamwork.std.CookiesClass : dreamwork.std.Cookies
    ---@field __base dreamwork.std.Cookies
    ---@overload fun(): dreamwork.std.Cookies
    local CookiesClass = std.class.create( Cookies )
    http.Cookies = CookiesClass

end

---@class dreamwork.std.http.Request.session_cache
---@field future dreamwork.std.Future
---@field start number
---@field age number

---@type table<string, dreamwork.std.http.Request.session_cache>
local session_cache = {}

--- [SHARED AND MENU]
---
--- Executes an asynchronous http request with the given options.
---
---@param options dreamwork.std.http.Request The request options.
---@return dreamwork.std.http.Response data The response.
---@see dreamwork.std.http.Request for the request options structure.
---@see dreamwork.std.http.Response for the response structure.
---@async
local function request( options )
    local search_parameters = options.parameters
    if std.isURLSearchParams( search_parameters ) then
        ---@cast search_parameters dreamwork.std.URL.SearchParams

        ---@type table<string, string | string[]>
        local parameters = {}

        for key, value in search_parameters:iterator() do
            local old_value = parameters[ key ]
            if old_value == nil then
                parameters[ key ] = value
            elseif isString( old_value ) then
                ---@cast old_value string
                parameters[ key ] = { old_value, value }
            else
                old_value[ #old_value + 1 ] = value
            end
        end

        options.parameters = parameters
    end

    local url = options.url
    if url == nil then
        error( "URL is nil", 2 )
    elseif not isString( url ) then
        ---@cast url dreamwork.std.URL
        url = url.href
        options.url = url
    end

    ---@cast url string

    local method = options.method or "GET"
    options.method = method

    local timeout = options.timeout
    if timeout == nil or not isNumber( timeout ) then
        ---@diagnostic disable-next-line: cast-local-type
        timeout = dreamwork_http_timeout.value
        ---@cast timeout number
    end

    options.timeout = timeout

    ---@diagnostic disable-next-line: inject-field
    options.type = options.content_type
    options.content_type = nil

    -- TODO: add package logger searching
    Logger:debug( "%s HTTP request to '%s', using '%s', with timeout %f seconds.", method, url, client_name, timeout )

    local f = Future()

    ---@diagnostic disable-next-line: inject-field
    function options.success( status, body, headers )
        f:setResult( { status = status, body = body, headers = headers } )
    end

    ---@diagnostic disable-next-line: inject-field
    function options.failed( msg )
        f:setError( msg )
    end

    -- Cache extension
    if options.cache then
        options.cache = nil

        local identifier = json_serialize( { url, method, options.parameters, options.headers }, false )

        local data = session_cache[ identifier ]
        if data ~= nil and (time_elapsed() - data.start) < data.age then
            return data.future:await()
        end

        local cache_ttl = options.cache_ttl
        options.cache_ttl = nil

        if not isNumber( cache_ttl ) then
            cache_ttl = dreamwork_http_cache_ttl.value * 60
        end

        ---@cast cache_ttl number

        ---@type dreamwork.std.http.Request.session_cache
        data = {
            future = f,
            start = time_elapsed(),
            age = cache_ttl
        }

        session_cache[ identifier ] = data

        local success = options.success

        ---@diagnostic disable-next-line: inject-field
        function options.success( status, body, headers )
            local cache_control = headers[ "cache-control" ]
            if cache_control ~= nil then
                local cache_options = {}
                for key, value in string_gmatch( cache_control, "([%w_-]+)=?([%w_-]*)" ) do
                    cache_options[ key ] = raw_tonumber( value, 10 ) or true
                end

                if cache_options[ "no-cache" ] or cache_options[ "no-store" ] then
                    session_cache[ identifier ] = nil
                elseif cache_options[ "s-maxage" ] or cache_options[ "max-age" ] then
                    data.age = cache_options[ "s-maxage" ] or cache_options[ "max-age" ]
                end
            end

            success( status, body, headers )
        end

        local failed = options.failed

        ---@diagnostic disable-next-line: inject-field
        function options.failed( msg )
            session_cache[ identifier ] = nil
            failed( msg )
        end

    end

    -- ETag extension
    if options.etag then
        options.etag = nil

        local data = http_storage.read( url )
        if data ~= nil then
            local headers = options.headers
            if headers == nil then
                headers = {
                    [ "If-None-Match" ] = data.etag
                }

                options.headers = headers
            else
                headers[ "If-None-Match" ] = data.etag
            end
        end

        local success = options.success

        ---@diagnostic disable-next-line: inject-field
        function options.success( status, body, headers )
            if status == 304 then
                status, body = 200, data and data.content or ""
            elseif status == 200 and headers.etag then
                http_storage.write( url, headers.etag, body )
            end

            success( status, body, headers )
        end
    end

    if make_request( options ) == false then
        options.failed( "failed to connect to '" .. client_name .. "' http client for '" .. url .. "'" )
    end

    return f:await()
end

http.request = request

--- [SHARED AND MENU]
---
--- Sends a GET request.
---
---@param url dreamwork.std.http.Request.url The URL to send the request to.
---@param headers? dreamwork.std.http.Request.headers The headers to send with the request.
---@param timeout? integer The timeout in seconds.
---@return dreamwork.std.http.Response response The response from the request.
---@async
function http.get( url, headers, timeout )
    return request( {
        method = "GET",
        url = url,
        headers = headers,
        timeout = timeout
    } )
end

--- [SHARED AND MENU]
---
--- Sends a POST request.
---
---@param url dreamwork.std.http.Request.url The URL to send the request to.
---@param parameters? dreamwork.std.http.Request.parameters The body to send with the request.
---@param headers? dreamwork.std.http.Request.headers The headers to send with the request.
---@param timeout? integer The timeout in seconds.
---@return dreamwork.std.http.Response response The response from the request.
---@async
function http.post( url, parameters, headers, timeout )
    return request( {
        method = "POST",
        url = url,
        parameters = parameters,
        headers = headers,
        timeout = timeout
    } )
end

-- TODO: https://github.com/nmap/nmap/blob/master/nselib/http.lua#L1222-L1307

--- [SHARED AND MENU]
---
--- Sends a HEAD request.
---
---@param url dreamwork.std.http.Request.url The URL to send the request to.
---@param headers? dreamwork.std.http.Request.headers The headers to send with the request.
---@param timeout? integer The timeout in seconds.
---@return dreamwork.std.http.Response response The response from the request.
---@async
function http.head( url, headers, timeout )
    return request( {
        url = url,
        method = "HEAD",
        headers = headers,
        timeout = timeout
    } )
end

if std.LUA_MENU then

    local glua_GetAPIManifest = _G.GetAPIManifest
    local json_deserialize = std.encoding.json.deserialize

    -- TODO: move into separate file http.facepunch.getManifest

    --- [MENU]
    ---
    --- Gets miscellaneous information from Facepunches API.
    ---
    ---@param timeout number? The timeout in seconds.
    ---@return table data The data returned from the API.
    ---@async
    function http.getFacepunchManifest( timeout )
        local f = Future()

        glua_GetAPIManifest( function( json )
            if json == nil then
                f:setError( "failed to get manifest from Facepunch API, unknown error" )
            else
                local data = json_deserialize( json )
                if data == nil then
                    f:setError( "failed to get manifest from Facepunch API, invalid JSON" )
                else
                    f:setResult( data )
                end
            end

        end )

        if timeout == nil then
            timeout = 30
        end

        if timeout > 0 then
            setTimeout( function()
                if f:isPending() then
                    f:setError( "failed to get manifest from Facepunch API, timed out" )
                end
            end, timeout )
        end

        return f:await()
    end

end

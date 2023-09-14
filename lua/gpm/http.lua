local gpm = gpm
local promise_New = promise.New
local ArgAssert = gpm.ArgAssert
local logger = gpm.Logger
local type = type

-- https://github.com/WilliamVenner/gmsv_reqwest
-- https://github.com/timschumi/gmod-chttp

local HTTP, isReqwest = HTTP, false
if SERVER and game.IsDedicated() then
    if util.IsBinaryModuleInstalled( "reqwest" ) and pcall( require, "reqwest" ) then
        logger:Info( "A third-party http client 'reqwest' has been initialized." )
        isReqwest = true
        HTTP = reqwest
    elseif util.IsBinaryModuleInstalled( "chttp" ) and pcall( require, "chttp" ) then
        logger:Info( "A third-party http client 'chttp' has been initialized." )
        HTTP = CHTTP
    end
end

local function request( parameters )
    logger:Debug( "%s HTTP request to %s (timeout %d sec)", parameters.method, parameters.url, parameters.timeout )
    return HTTP( parameters )
end

local queue = {}
util.NextTick( function()
    for _, func in ipairs( queue ) do
        func()
    end

    queue = nil
end )

local gpm_http_timeout, userAgent = CreateConVar( "gpm_http_timeout", "10", FCVAR_ARCHIVE, "Default http timeout for gpm http library.", 5, 300 )
if isReqwest then
    userAgent = string.format( "GLua Package Manager/%s - Garry's Mod/%s", gpm.VERSION, VERSIONSTR )
end

local function asyncHTTP( parameters )
    ArgAssert( parameters, 1, "table" )
    local p = promise_New()

    if type( parameters.method ) ~= "string" then
        parameters.method = "GET"
    end

    if type( parameters.timeout ) ~= "number" then
        parameters.timeout = gpm_http_timeout:GetInt()
    end

    if type( parameters.headers ) ~= "table" then
        parameters.headers = {}
    end

    if isReqwest then
        parameters.headers["User-Agent"] = userAgent
    end

    parameters.success = function( code, body, headers )
        p:Resolve( {
            ["code"] = code,
            ["body"] = body,
            ["headers"] = headers
        } )
    end

    parameters.failed = function( err )
        p:Reject( err )
    end

    if queue ~= nil then
        queue[ #queue + 1 ] = function()
            request( parameters )
        end
    else
        request( parameters )
    end

    return p
end

gpm.HTTP = asyncHTTP

local lib = gpm.http
if type( lib ) ~= "table" then
    lib = gpm.metaworks.CreateLink( http, true, false )
    gpm.http = lib
end

function lib.Fetch( url, headers, timeout )
    return asyncHTTP( {
        ["url"] = url,
        ["headers"] = headers,
        ["timeout"] = timeout
    } )
end

function lib.Post( url, parameters, headers, timeout )
    return asyncHTTP( {
        ["url"] = url,
        ["method"] = "POST",
        ["headers"] = headers,
        ["parameters"] = parameters,
        ["timeout"] = timeout
    } )
end
local gpm = gpm
local promise_New = promise.New
local ArgAssert = gpm.ArgAssert
local logger = gpm.Logger
local type = type

-- https://github.com/WilliamVenner/gmsv_reqwest
-- https://github.com/timschumi/gmod-chttp

local HTTP = HTTP
if SERVER and game.IsDedicated() then
    if util.IsBinaryModuleInstalled( "reqwest" ) and pcall( require, "reqwest" ) then
        logger:Info( "A third-party http client 'reqwest' has been initialized." )
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

local timeout = CreateConVar( "gpm_http_timeout", "10", FCVAR_ARCHIVE, "Default http timeout for gpm http library.", 5, 300 )
local userAgent = string.format( "GLua Package Manager/%s - Garry's Mod/%s", gpm.VERSION, VERSIONSTR )

local queue = {}
util.NextTick( function()
    for _, func in ipairs( queue ) do
        func()
    end

    queue = nil
end )

local function asyncHTTP( parameters )
    ArgAssert( parameters, 1, "table" )
    local promise = promise_New()

    if type( parameters.method ) ~= "string" then
        parameters.method = "GET"
    end

    if type( parameters.timeout ) ~= "number" then
        parameters.timeout = timeout:GetInt()
    end

    if type( parameters.headers ) ~= "table" then
        parameters.headers = {}
    end

    parameters.headers["User-Agent"] = userAgent

    parameters.success = function( code, body, headers )
        promise:Resolve( {
            ["code"] = code,
            ["body"] = body,
            ["headers"] = headers
        } )
    end

    parameters.failed = function( err )
        promise:Reject( err )
    end

    if queue ~= nil then
        queue[ #queue + 1 ] = function()
            request( parameters )
        end
    else
        request( parameters )
    end

    return promise
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
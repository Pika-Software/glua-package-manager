local promise = gpm.promise
local logger = gpm.Logger
local ipairs = ipairs
local util = util
local type = type

-- https://github.com/WilliamVenner/gmsv_reqwest
-- https://github.com/timschumi/gmod-chttp
if SERVER and game.IsDedicated() then
    if util.IsBinaryModuleInstalled( "reqwest" ) then
        logger:Info( "A third-party http client 'reqwest' has been initialized." )
        require( "reqwest" )
    elseif util.IsBinaryModuleInstalled( "chttp" ) then
        logger:Info( "A third-party http client 'chttp' has been initialized." )
        require( "chttp" )
    end
end

local defaultTimeout = CreateConVar( "gpm_http_timeout", "10", FCVAR_ARCHIVE, "Default http timeout for gpm http library.", 5, 300 )
local userAgent = string.format( "%s/%s %s", "GLua Package Manager", gpm.utils.Version( gpm._VERSION ), "Garry's Mod" )
local client = reqwest or CHTTP or HTTP

module( "gpm.http" )

local function request( p, parameters )
    if client( parameters ) then return end
    p:Reject( "failed to make http request" )
end

local queue = {}

function HTTP( parameters )
    local p = promise.New()

    if type( parameters.headers ) ~= "table" then
        parameters.headers = {}
    end

    parameters.headers["User-Agent"] = userAgent

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
            request( p, parameters )
        end
    else
        request( p, parameters )
    end

    return p
end

util.NextTick( function()
    for _, func in ipairs( queue ) do
        func()
    end

    queue = nil
end )

function Fetch( url, headers, timeout )
    return HTTP( {
        ["url"] = url,
        ["headers"] = headers,
        ["timeout"] = type( timeout ) == "number" and timeout or defaultTimeout:GetInt()
    } )
end

function Post( url, parameters, headers, timeout )
    return HTTP( {
        ["url"] = url,
        ["method"] = "POST",
        ["headers"] = headers,
        ["parameters"] = parameters,
        ["timeout"] = type( timeout ) == "number" and timeout or defaultTimeout:GetInt()
    } )
end
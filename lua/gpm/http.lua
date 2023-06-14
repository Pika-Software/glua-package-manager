local promise = promise
local ipairs = ipairs
local util = util
local type = type

-- https://github.com/WilliamVenner/gmsv_reqwest
-- https://github.com/timschumi/gmod-chttp
if SERVER then
    if util.IsBinaryModuleInstalled( "reqwest" ) and pcall( require, "reqwest" ) then
        gpm.Logger:Info( "A third-party http client 'reqwest' has been initialized." )
    elseif util.IsBinaryModuleInstalled( "chttp" ) and pcall( require, "chttp" ) then
        gpm.Logger:Info( "A third-party http client 'chttp' has been initialized." )
    end
end

local defaultTimeout = CreateConVar( "gpm_http_timeout", "10", FCVAR_ARCHIVE, "Default http timeout for gpm http library.", 5, 300 )
local userAgent = string.format( "%s/%s %s", "GLua Package Manager", gpm.utils.Version( gpm._VERSION ), "Garry's Mod" )
local client = reqwest or CHTTP or HTTP

module( "gpm.http" )

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
            client( parameters )
        end
    else
        client( parameters )
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
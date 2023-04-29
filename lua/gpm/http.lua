local promise = gpm.promise
local type = type

-- https://github.com/WilliamVenner/gmsv_reqwest
if SERVER and not reqwest and not CHTTP and game.IsDedicated() then
    if util.IsBinaryModuleInstalled( "reqwest" ) then
        require( "reqwest" )
    elseif util.IsBinaryModuleInstalled( "chttp" ) then
        require( "chttp" )
    end
end

-- https://github.com/timschumi/gmod-chttp
if CLIENT and not CHTTP and util.IsBinaryModuleInstalled( "chttp" ) then
    require( "chttp" )
end

local defaultTimeout = CreateConVar( "gpm_http_timeout", "10", FCVAR_ARCHIVE, " - default http timeout for gpm http library.", 5, 300 )
local userAgent = string.format( "%s/%s %s", "GLua Package Manager", gpm.utils.Version( gpm._VERSION ), "Garry's Mod" )
local client = reqwest or CHTTP or HTTP

module( "gpm.http" )

function HTTP( parameters )
    local p = promise.New()

    parameters.headers = parameters.headers or {}
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


    local ok = client( parameters )
    if not ok then
        p:Reject( "failed to make http request" )
    end

    return p
end

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
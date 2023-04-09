local promise = gpm.promise
local type = type

if CLIENT or MENU_DLL or game.IsDedicated() then
    if not reqwest and util.IsBinaryModuleInstalled( "reqwest" ) then require( "reqwest" ) end
    if not reqwest and not CHTTP and util.IsBinaryModuleInstalled( "chttp" ) then require( "chttp" ) end
end

local defaultTimeout = CreateConVar( "gpm_http_timeout", "60", FCVAR_ARCHIVE, " - default http timeout for gpm http library.", 5, 300 )
local client = reqwest or CHTTP or HTTP

module( "gpm.http" )

function HTTP( parameters )
    local p = promise.New()

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
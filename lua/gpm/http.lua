-- Libraries
local promise = gpm.promise
local file = file

-- Variables
local os_time = os.time

if not reqwest and not CHTTP then
    if util.IsBinaryModuleInstalled( "reqwest" ) then
        require( "reqwest" )
    end

    if not reqwest and util.IsBinaryModuleInstalled( "chttp" ) then
        require( "chttp" )
    end
end

local client = reqwest or CHTTP or HTTP

module( "gpm.http", package.seeall )

local DEFAULT_TIMEOUT = 60

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
        ["timeout"] = timeout or DEFAULT_TIMEOUT
    } )
end

function Post( url, parameters, headers, timeout )
    return HTTP( {
        ["url"] = url,
        ["method"] = "POST",
        ["headers"] = headers,
        ["parameters"] = parameters,
        ["timeout"] = timeout or DEFAULT_TIMEOUT
    } )
end

Download = promise.Async( function( url, filePath, headers, lifeTime )
    if ( lifeTime ~= nil ) and file.Exists( filePath, "DATA" ) and ( os_time() - file.Time( filePath, "DATA" ) ) < lifeTime then
        return {
            ["content"] = file.Read( filePath, "DATA" ),
            ["filePath"] = filePath
        }
    end

    local ok, result = Fetch( url, headers, 120 ):SafeAwait()
    if not ok then return promise.Reject( result ) end
    if result.code ~= 200 then return promise.Reject( "invalid response http code - " .. result.code ) end

    file.Write( filePath, result.body )

    return {
        ["filePath"] = filePath,
        ["content"] = result.body
    }
end )

local gpm = gpm
local http = http
local util = gpm.util
local metaworks = gpm.metaworks

local promise_New = promise.New
local logger = gpm.Logger
local type = type

local lib = gpm.http
if type( lib ) ~= "table" then
    lib = metaworks.CreateLink( http, true )
    gpm.http = lib
end

local clients = lib.Clients
if type( clients ) ~= "table" then
    clients = {
        {
            ["Name"] = "Garry's Mod",
            ["Client"] = "HTTP",
            ["Installed"] = true
        }
    }

    if SERVER then
        table.insert( clients, 1, {
            ["Name"] = "chttp",
            ["Client"] = "CHTTP"
        } )

        table.insert( clients, 1, {
            ["Name"] = "reqwest",
            ["Client"] = "reqwest"
        } )
    end

    lib.Clients = clients
end

local client, clientName = lib.Client, lib.ClientName
if type( client ) ~= "function" then
    for _, data in ipairs( clients ) do
        if not data.Installed and not ( util.IsBinaryModuleInstalled( data.Name ) and pcall( require, data.Name ) ) then continue end

        clientName = data.Name
        lib.ClientName = clientName

        client = _G[ data.Client ]
        lib.Client = client

        logger:Info( "'%s' has been selected as gpm HTTP client.", data.Name )
        break
    end
end

local function request( parameters )
    logger:Debug( "%s HTTP request to %s (timeout %d sec)", parameters.method, parameters.url, parameters.timeout )
    client( parameters )
end

local queue = {}
util.NextTick( function()
    for _, func in ipairs( queue ) do
        func()
    end

    queue = nil
end )

local function HTTP( parameters )
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

    if clientName == "reqwest" then
        local userAgent = lib.UserAgent
        if not userAgent then
            userAgent = string.format( "GLua Package Manager/%s - Garry's Mod/%s", gpm.VERSION, VERSIONSTR )
            lib.UserAgent = userAgent
        end

        parameters.headers["User-Agent"] = userAgent
    end

    parameters.success = function( code, body, headers )
        p:Resolve( {
            ["code"] = code,
            ["body"] = body,
            ["headers"] = headers
        } )
    end

    parameters.failed = function( msg )
        p:Reject( msg )
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

gpm.HTTP = HTTP


local timeout = CreateConVar( "http_timeout", "10", FCVAR_ARCHIVE, "Default http timeout for gpm http library.", 3, 300 )

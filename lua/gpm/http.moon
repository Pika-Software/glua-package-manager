SERVER = SERVER
if SERVER
    AddCSLuaFile!

gpm = gpm
http = http
util = gpm.util

gpm_ArgAssert = gpm.ArgAssert
promise_New = promise.New
logger = gpm.Logger
type = type
_G = _G

lib = gpm.Lib "http", gpm.metaworks.CreateLink( http, true )
client, clientName = nil, nil
do
    clients = {
        {
            Name: "Garry's Mod",
            Client: "HTTP",
            Installed: true
        }
    }

    if SERVER
        table.insert( clients, 1, {
            Client: "CHTTP",
            Name: "chttp"
        } )

        table.insert( clients, 1, {
            Client: "reqwest",
            Name: "reqwest"
        } )


    for item in *clients
        if item.Installed or ( util.IsBinaryModuleInstalled( item.Name ) and pcall( require, item.Name ) )
            client, clientName = _G[ item.Client ], item.Name
            logger\Info( "'%s' was connected as HTTP client.", item.Name )
            break


request = ( parameters ) ->
    logger\Debug( "%s HTTP request to '%s', using '%s', with timeout %d seconds.", parameters.method, parameters.url, clientName, parameters.timeout )
    client( parameters )

queue = {}
util.NextTick( () ->
    for func in *queue
        func!
    queue = nil
)

http_timeout = CreateConVar( "http_timeout", "10", FCVAR_ARCHIVE, "Default http timeout for gpm http library.", 3, 300 )\GetInt!
cvars.AddChangeCallback( "http_timeout", ( _, __, int ) ->
    http_timeout = tonumber( int ) or 10,
"gLua Package Manager" )

HTTP = ( parameters ) ->
    gpm_ArgAssert( parameters, 1, "table" )
    p = promise_New()

    if type( parameters.method ) ~= "string"
        parameters.method = "GET"

    if type( parameters.timeout ) ~= "number"
        parameters.timeout = http_timeout

    if type( parameters.headers ) ~= "table"
        parameters.headers = {}

    if clientName == "reqwest"
        userAgent = lib.UserAgent
        if not userAgent
            userAgent = string.format( "GLua Package Manager/%s - Garry's Mod/%s", gpm.VERSION, VERSIONSTR )
            lib.UserAgent = userAgent

        parameters.headers["User-Agent"] = userAgent

    parameters.success = ( code, body, headers ) ->
        p\Resolve {
            headers: headers,
            body: body,
            code: code
        }

    parameters.failed = ( msg ) ->
        p\Reject( msg )

    if queue ~= nil
        queue[ #queue + 1 ] = () ->
            request( parameters )
    else
        request( parameters )

    p

gpm.HTTP = HTTP

lib.Fetch = ( url, headers, timeout ) ->
    HTTP( {
        headers: headers,
        timeout: timeout,
        url: url
    } )

lib.Post = ( url, parameters, headers, timeout ) ->
    HTTP( {
        parameters: parameters,
        headers: headers,
        timeout: timeout,
        method: "POST",
        url: url
    } )
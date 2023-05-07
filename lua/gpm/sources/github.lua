-- Libraries
local sources = gpm.sources
local promise = gpm.promise
local logger = gpm.Logger
local http = gpm.http
local string = string

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack

module( "gpm.sources.github" )

function CanImport( filePath )
    return string.match( filePath, "github.com/(.+)" ) ~= nil
end

Try = promise.Async( function( url, parentPackage )
    local ok, result = http.Fetch( url ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    if result.code ~= 200 then
        return promise.Reject( "invalid response http code - " .. result.code )
    end

    local ok, result = sources.http.Import( url, parentPackage ):SafeAwait()
    if ok then return result end

    ErrorNoHaltWithStack( result )
end )

TryTree = promise.Async( function( user, repository, tree, parentPackage )
    local ok, result = Try( string.format( "https://raw.githubusercontent.com/%s/%s/%s/package.json", user, repository, tree ), parentPackage ):SafeAwait()
    if ok then return result end

    ok, result = Try( string.format( "https://github.com/%s/%s/archive/refs/heads/%s.zip", user, repository, tree ), parentPackage ):SafeAwait()
    if ok then return result end

    return promise.Reject( result )
end )

Import = promise.Async( function( url, parentPackage )
    if not string.IsURL( url ) then url = "https://" .. url end

    local user, repository = string.match( url, "github.com/([%w_%-%.]+)/([%w_%-%.]+)" )
    if not user then
        logger:Error( "`%s` import failed, attempt to download failed - repository not recognized.", url )
        return
    end

    if not repository then
        logger:Error( "`%s` import failed, attempt to download failed - user not recognized.", url )
        return
    end

    local tree = string.match( url, "/tree/([%w_%-%.%/]+)")
    if tree ~= nil then
        local ok, result = TryTree( user, repository, tree, parentPackage ):SafeAwait()
        if ok then return result end
    end

    local ok, result = TryTree( user, repository, "main", parentPackage ):SafeAwait()
    if ok then return result end

    ok, result = TryTree( user, repository, "master", parentPackage ):SafeAwait()
    if ok then return result end

    logger:Error( "`%s` import failed, %s.", url, result )
end )
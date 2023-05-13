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

function GetInfo( url )
    local user, repository = string.match( url, "github.com/([%w_%-%.]+)/([%w_%-%.]+)" )
    return {
        ["tree"] = string.match( url, "/tree/([%w_%-%.%/]+)"),
        ["repository"] = repository,
        ["importPath"] = url,
        ["user"] = user,
        ["url"] = url
    }
end

Try = promise.Async( function( url )
    local ok, result = http.Fetch( url ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    if result.code ~= 200 then
        return promise.Reject( "invalid response http code - " .. result.code )
    end

    local ok, result = sources.http.Import( sources.http.GetInfo( url ) ):SafeAwait()
    if ok then return result end

    ErrorNoHaltWithStack( result )
end )

TryTree = promise.Async( function( user, repository, tree )
    local ok, result = Try( string.format( "https://raw.githubusercontent.com/%s/%s/%s/package.json", user, repository, tree ) ):SafeAwait()
    if ok then return result end

    ok, result = Try( string.format( "https://github.com/%s/%s/archive/refs/heads/%s.zip", user, repository, tree ) ):SafeAwait()
    if ok then return result end

    return promise.Reject( result )
end )

Import = promise.Async( function( info )
    local user = info.user
    if not user then
        logger:Error( "Package `%s` import failed, attempt to download failed - repository not recognized.", info.url )
        return
    end

    local repository = info.repository
    if not repository then
        logger:Error( "Package `%s` import failed, attempt to download failed - user not recognized.", info.url )
        return
    end

    local tree = info.tree
    if tree then
        local ok, result = TryTree( user, repository, tree ):SafeAwait()
        if ok then return result end
    end

    local ok, result = TryTree( user, repository, "main" ):SafeAwait()
    if ok then return result end

    ok, result = TryTree( user, repository, "master" ):SafeAwait()
    if ok then return result end

    logger:Error( "Package `%s` import failed, %s.", info.url, result )
end )
-- Libraries
local sources = gpm.sources
local promise = gpm.promise
local string = string

module( "gpm.sources.github" )

function CanImport( filePath )
    return string.match( filePath, "github.com/(.+)" ) ~= nil
end

Import = promise.Async( function( url, parentPackage )
    if not string.IsURL( url ) then url = "https://" .. url end

    local user, repository = string.match( url, "github.com/([%w_%-%.]+)/([%w_%-%.]+)" )
    if not user then
        return promise.Reject( string.format( "Attempt to download `%s` package failed, repository not recognized.", url ) )
    end

    if not repository then
        return promise.Reject( string.format( "Attempt to download `%s` package failed, user not recognized.", url ) )
    end

    local tree = string.match( url, "/tree/([%w_%-%.%/]+)")
    if tree ~= nil then
        local ok, result = sources.http.Import( string.format( "https://raw.githubusercontent.com/%s/%s/%s/package.json", user, repository, tree ), parentPackage ):SafeAwait()
        if ok then return promise.Resolve( result ) end

        ok, result = sources.http.Import( string.format( "https://github.com/%s/%s/archive/refs/heads/%s.zip", user, repository, tree ), parentPackage ):SafeAwait()
        if ok then return promise.Resolve( result ) end
    end

    local ok, result = sources.http.Import( string.format( "https://raw.githubusercontent.com/%s/%s/main/package.json", user, repository ), parentPackage ):SafeAwait()
    if ok then return promise.Resolve( result ) end

    ok, result = sources.http.Import( string.format( "https://github.com/%s/%s/archive/refs/heads/main.zip", user, repository ), parentPackage ):SafeAwait()
    if ok then return promise.Resolve( result ) end

    ok, result = sources.http.Import( string.format( "https://raw.githubusercontent.com/%s/%s/master/package.json", user, repository ), parentPackage ):SafeAwait()
    if ok then return promise.Resolve( result ) end

    ok, result = sources.http.Import( string.format( "https://github.com/%s/%s/archive/refs/heads/master.zip", user, repository ), parentPackage ):SafeAwait()
    if ok then return promise.Resolve( result ) end

    return promise.Reject( result )
end )
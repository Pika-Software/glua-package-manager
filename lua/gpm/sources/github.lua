local gpm = gpm

-- Libraries
local promise = promise
local http = gpm.http
local string = string

module( "gpm.sources.github" )

function CanImport( filePath )
    return string.match( filePath, "github.com/(.+)" ) ~= nil
end

IsAvailable = promise.Async( function( user, repository, tree )
    local url = string.format( "https://github.com/%s/%s/archive/refs/heads/%s.zip", user, repository, tree )

    local ok, result = http.Fetch( url ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    if result.code ~= 200 then
        return promise.Reject( "Invalid response http code - " .. result.code )
    end

    return url
end )

GetMetadata = promise.Async( function( importPath )
    local user, repository = string.match( importPath, "github.com/([%w_%-%.]+)/([%w_%-%.]+)" )
    if not user then return promise.Reject( "Attempt to download failed - repository not recognized." ) end
    if not repository then return promise.Reject( "Attempt to download failed - user not recognized." ) end

    local metadata = {}

    local tree = string.match( importPath, "/tree/([%w_%-%.%/]+)")
    if tree ~= nil then
        local ok, result = IsAvailable( user, repository, tree ):SafeAwait()
        if ok then
            metadata.url = result
            return metadata
        end
    end

    local ok, result = IsAvailable( user, repository, "main" ):SafeAwait()
    if ok then
        metadata.url = result
        return metadata
    end

    ok, result = IsAvailable( user, repository, "master" ):SafeAwait()
    if ok then
        metadata.url = result
        return metadata
    end

    return promise.Reject( result )
end )

Import = promise.Async( function( metadata )
    return gpm.SourceImport( "http", metadata.url )
end )
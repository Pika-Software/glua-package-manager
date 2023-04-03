
local promise = gpm.promise

module( "gpm.sources.zip", package.seeall )

Import = promise.Async(function(path)
    return promise.Reject("not implemented")
end)
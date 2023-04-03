local debug_getinfo = debug.getinfo
local module = module
local string = string
local table = table

module( "gpm.utils" )

function GetCurrentFile()
    for i = 2, 6 do
        local info = debug_getinfo(i, "S")
        if not info then break end
        if info.what == "main" then return info.short_src end
    end
end

module( "gpm.path" )

-- File path fix
function Fix( filePath )
    filePath = string.lower( filePath )
    filePath = string.gsub( filePath, "\\", "/" )
    filePath = string.gsub( filePath, "/+", "/" )
    return filePath
end

-- File path join
function Join( filePath, ... )
    return path.Fix( table.concat( { filePath, ... }, "/" ) )
end

-- File path localization
function Localize( filePath )
    filePath = string.gsub( filePath, "^addons/[%w%-_]-/", "" )
    filePath = string.gsub( filePath, "^lua/", "" )
    return filePath
end
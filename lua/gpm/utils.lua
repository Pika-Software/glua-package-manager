local debug_getinfo = debug.getinfo
local table = table
local gpm = gpm

module( "gpm.utils" )

function GetCurrentFile()
    for i = 2, 6 do
        local info = debug_getinfo(i, "S")
        if not info then break end
        if info.what == "main" then return info.short_src end
    end
end

-- Localises
function LocalizePath(path)
    if path then
        return path:gsub("^addons/[%w%-_]-/", ""):gsub("^lua/", "")
    end
end

do -- Path utils
    path = path or {}

    function path.Fix(path)
        return path:lower():gsub("\\", "/"):gsub("/+", "/")
    end

    function path.Join(dir, ...)
        return path.Fix( table.concat({ dir, ... }, "/") )
    end

    gpm.path = path
end

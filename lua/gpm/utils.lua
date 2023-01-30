local debug_getinfo = debug.getinfo

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

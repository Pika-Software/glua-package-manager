-- Libraries
local string = string
local file = file

-- Global table
local gluaFixes = gpm.GLuaFixes
if not gluaFixes then
    gluaFixes = {}; gpm.GLuaFixes = gluaFixes
end

-- https://wiki.facepunch.com/gmod/file.Exists
-- https://wiki.facepunch.com/gmod/file.IsDir
do

    local SERVER = SERVER
    local ipairs = ipairs

    local file_Exists = table.SetValue( gluaFixes, "file.Exists", file.Exists, true )
    local file_IsDir = table.SetValue( gluaFixes, "file.IsDir", file.IsDir, true )

    function file.IsDir( filePath, gamePath )
        if SERVER then return file_IsDir( filePath, gamePath ) end
        if file_IsDir( filePath, gamePath ) then return true end

        local _, folders = file.Find( filePath .. "*", gamePath )
        if ( folders == nil or #folders == 0 ) then return false end

        local splits = string.Split( filePath, "/" )
        local folderName = splits[ #splits ]

        for _, value in ipairs( folders ) do
            if ( value == folderName ) then return true end
        end

        return false
    end

    function file.Exists( filePath, gamePath )
        if SERVER then return file_Exists( filePath, gamePath ) end
        if file_Exists( filePath, gamePath ) then return true end

        local files, folders = file.Find( filePath .. "*", gamePath )
        if not files or not folders then return false end
        if ( #files == 0 and #folders == 0 ) then return false end

        local splits = string.Split( filePath, "/" )
        local fileName = splits[ #splits ]

        for _, value in ipairs( files ) do
            if ( value == fileName ) then return true end
        end

        for _, value in ipairs( folders ) do
            if ( value == fileName ) then return true end
        end

        return false
    end

end

-- https://wiki.facepunch.com/gmod/util.IsBinaryModuleInstalled
do

    local CLIENT = CLIENT
    local error = error
    local type = type

    local suffix = ( { "osx64", "osx", "linux64", "linux", "win64", "win32" } )[ ( system.IsWindows() and 4 or 0 ) + ( system.IsLinux() and 2 or 0 ) + ( jit.arch == "x86" and 1 or 0 ) + 1 ]
    local fmt = "lua/bin/gm" .. ( CLIENT and "cl" or "sv" ) .. "_%s_%s.dll"
    local fmt = "lua/bin/gm" .. ( ( CLIENT and not MENU_DLL ) and "cl" or "sv" ) .. "_%s_%s.dll"

    function util.IsBinaryModuleInstalled( name )
        if type( name ) ~= "string" then
            error( "bad argument #1 to 'IsBinaryModuleInstalled' (string expected, got " .. type( name ) .. ")" )
        elseif #name == 0 then
            error( "bad argument #1 to 'IsBinaryModuleInstalled' (string cannot be empty)" )
        end

        if file.Exists( string.format( fmt, name, suffix ), "GAME" ) then
            return true
        end

        -- Edge case - on Linux 32-bit x86-64 branch, linux32 is also supported as a suffix
        if jit.versionnum ~= 20004 and jit.arch == "x86" and system.IsLinux() then
            return file.Exists( string.format( fmt, name, "linux32" ), "GAME" )
        end

        return false
    end

end
-- Libraries
local promise = gpm.promise
local logger = gpm.Logger
local paths = gpm.paths
local fs = gpm.fs
local gpm = gpm

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local ipairs = ipairs
local pairs = pairs
local type = type

-- Source functions
do

    local sources = gpm.sources

    function gpm.LuaPackageExists( filePath )
        return sources.lua.CanImport( filePath )
    end

    function gpm.GetLuaFiles()
        return sources.lua.Files
    end

end

function gpm.ErrorHandler( packagePath, str )
    logger:Error( "Package `%s` import failed, see above to see the error.", packagePath )
    ErrorNoHaltWithStack( str )
end

do

    local sources = {}
    for _, source in pairs( gpm.sources ) do
        sources[ #sources + 1 ] = source
    end

    local processes = {}

    function gpm.AsyncImport( packagePath, parentPackage, isAutorun )
        ArgAssert( packagePath, 1, "string" )
        packagePath = paths.Fix( packagePath )

        local p = processes[ packagePath ]
        if not promise.IsPromise( p ) then
            for _, source in ipairs( sources ) do
                if type( source.CanImport ) ~= "function" then continue end
                if not source.CanImport( packagePath ) then continue end
                p = source.Import( packagePath, parentPackage, isAutorun )
                processes[ packagePath ] = p
                break
            end

            if not promise.IsPromise( p ) then
                gpm.ErrorHandler( packagePath, "Requested package doesn't exist!" )
            end
        end

        return p
    end

end

do

    local assert = assert

    function gpm.Import( filePath, async, parentPackage, isAutorun )
        assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

        local p = gpm.AsyncImport( filePath, parentPackage, isAutorun )
        if not async then
            local ok, result = p:SafeAwait()
            if not ok then
                gpm.ErrorHandler( filePath, result )
                return
            end

            return result
        end

        return p
    end

    _G.import = gpm.Import

end

function gpm.ImportFolder( folderPath, parentPackage, isAutorun )
    folderPath = paths.Fix( folderPath )

    if not fs.IsDir( folderPath, gpm.LuaRealm ) then
        logger:Warn( "Import impossible, folder '%s' is empty, skipping...", folderPath )
        return
    end

    logger:Info( "Starting to import packages from '%s'", folderPath )

    local files, folders = fs.Find( folderPath .. "/*", gpm.LuaRealm )
    for _, folderName in ipairs( folders ) do
        local packagePath = folderPath .. "/" .. folderName
        gpm.Import( packagePath, true, parentPackage, isAutorun ):Catch( function( str )
            gpm.ErrorHandler( packagePath, result )
        end )
    end

    for _, fileName in ipairs( files ) do
        local packagePath = folderPath .. "/" .. fileName
        gpm.Import( packagePath, true, parentPackage, isAutorun ):Catch( function( str )
            gpm.ErrorHandler( packagePath, result )
        end )
    end

end

do

    local sideColor = gpm.logger.SIDE_COLOR
    local MsgC = MsgC

    function gpm.PrintPackageList()
        MsgC( sideColor, SERVER and "Server" or "Client", logger.TextColor, " packages:\n" )

        local total = 0
        for name, packages in pairs( gpm.Packages ) do
            local versions = {}
            for version in pairs( packages ) do
                versions[ #versions + 1 ] = version
                total = total + 1
            end

            MsgC( sideColor, "\t* ", logger.TextColor, string.format( "%s@%s\n", name, table.concat( versions, ", " ) ) )
        end

        MsgC( sideColor, "\tTotal: ", logger.TextColor, total, "\n" )
    end

end

do

    local cachePath = "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/"
    local workshopPath = "gpm/" .. ( SERVER and "server" or "client" ) .. "/workshop/"

    function gpm.ClearCache()
        local count, size = 0, 0

        for _, fileName in ipairs( fs.Find( cachePath .. "*", "DATA" ) ) do
            local filePath = cachePath .. fileName
            local fileSize = fs.Size( filePath, "DATA" )
            fs.Delete( filePath )

            if fs.Exists( filePath, "DATA" ) then
                logger:Warn( "Unable to remove file `%s` probably used by the game, restart game and try again.", filePath )
                continue
            end

            size = size + fileSize
            count = count + 1
        end

        for _, fileName in ipairs( fs.Find( workshopPath .. "*", "DATA" ) ) do
            local filePath = workshopPath .. fileName
            local fileSize = fs.Size( filePath, "DATA" )
            fs.Delete( filePath )

            if fs.Exists( filePath, "DATA" ) then
                logger:Warn( "Unable to remove file `%s` probably used by the game, restart game and try again.", filePath )
                continue
            end

            size = size + fileSize
            count = count + 1
        end

        logger:Info( "Deleted %d cache files, freeing up %dMB of space.", count, size / 1024 / 1024 )
    end

end

if SERVER then

    concommand.Add( "gpm_clear_cache", function( ply )
        if not ply or ply:IsListenServerHost() then
            gpm.ClearCache()
        end

        ply:SendLua( "gpm.ClearCache()" )
    end )

    concommand.Add( "gpm_list", function( ply )
        if not ply or ply:IsListenServerHost() then
            gpm.PrintPackageList()
        end

        ply:SendLua( "gpm.PrintPackageList()" )
    end )

    local BroadcastLua = BroadcastLua

    concommand.Add( "gpm_reload", function( ply )
        if not ply or ply:IsSuperAdmin() then
            BroadcastLua( "include( \"gpm/init.lua\" )" )
            include( "gpm/init.lua" )
            hook.Run( "GPM - Reloaded" )
            return
        end

        ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
    end )

end

local pkgs = gpm.Packages
if type( pkgs ) == "table" then
    for packageName in pairs( pkgs ) do
        pkgs[ packageName ] = nil
    end
end

gpm.ImportFolder( "gpm/packages", nil, true )
gpm.ImportFolder( "packages", nil, true )
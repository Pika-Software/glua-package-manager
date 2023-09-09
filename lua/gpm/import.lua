local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local fs = gpm.fs

-- Variables
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local table_HasIValue = table.HasIValue
local gpm_IsPackage = gpm.IsPackage
local ArgAssert = gpm.ArgAssert
local logger = gpm.Logger
local ipairs = ipairs
local assert = assert
local error = error
local type = type

local sources = gpm.sources
if not sources then
    sources = {}; gpm.sources = sources
end

do
    local sourcesFolder = "gpm/sources/"
    for _, fileName in ipairs( fs.Find( sourcesFolder .. "*", "LUA" ) ) do
        local filePath = sourcesFolder .. fileName
        if SERVER then
            AddCSLuaFile( filePath )
        end

        include( filePath )
    end
end

local activeGamemode = engine.ActiveGamemode()
local singlePlayer = game.SinglePlayer()
local map = game.GetMap()

do

    local sourceList = {}
    for sourceName in pairs( sources ) do
        sourceList[ #sourceList + 1 ] = sourceName
    end

    table.sort( sourceList, function( a, b )
        return ( sources[ a ].Priority or 10 ) > ( sources[ b ].Priority or 10 )
    end )

    function gpm.CanImport( importPath )
        for _, sourceName in ipairs( sourceList ) do
            local source = sources[ sourceName ]
            if not source then continue end
            if source.CanImport( importPath ) then return true end
        end

        return false
    end

    function gpm.CanBeInstalled( metadata, source )
        local init = metadata.init
        if SERVER and not init.server then
            return false, "package does not support running on the server"
        end

        if CLIENT and not init.client then
            return false, "package does not support running on the client"
        end

        if MENU_DLL and not init.menu then
            return false, "package does not support running in menu"
        end

        if metadata.singleplayer and not singlePlayer then
            return false, "package cannot be executed in a singleplayer game"
        end

        local gamemodes = metadata.gamemodes
        local gamemodesType = type( gamemodes )
        if ( gamemodesType == "string" and gamemodes ~= activeGamemode ) or ( gamemodesType == "table" and not table_HasIValue( gamemodes, activeGamemode ) ) then
            return false, "package does not support active gamemode"
        end

        local maps = metadata.maps
        local mapsType = type( maps )
        if ( mapsType == "string" and maps ~= map ) or ( mapsType == "table" and not table_HasIValue( maps, map ) ) then
            return false, "package does not support current map"
        end

        return true
    end

    local tasks = gpm.Tasks
    if type( tasks ) ~= "table" then
        tasks = {}; gpm.Tasks = tasks
    end

    gpm.SourceImport = promise.Async( function( sourceName, importPath )
        local task = tasks[ importPath ]
        if task then
            return task
        end

        local source = sources[ sourceName ]
        if not source then
            return promise.Reject( "source not found" )
        end

        local metadata = {}
        if type( source.GetMetadata ) == "function" then
            local ok, result = source.GetMetadata( importPath ):SafeAwait()
            if not ok then
                return promise.Reject( result )
            end

            metadata = result
        end

        metadata.importpath = importPath
        metadata.sourcename = sourceName

        package.FormatMetadata( metadata )

        local ok, message = gpm.CanBeInstalled( metadata, source )
        if not ok then
            return promise.Reject( message )
        end

        task = source.Import( metadata )
        tasks[ importPath ] = task
        task:Catch( function()
            tasks[ importPath ] = nil
        end )

        return task
    end )

    gpm.AsyncImport = promise.Async( function( importPath, parent, autorun )
        ArgAssert( importPath, 1, "string" )

        local task = tasks[ importPath ]
        if not task then
            for _, sourceName in ipairs( sourceList ) do
                local source = sources[ sourceName ]
                if not source then continue end
                if not source.CanImport( importPath ) then continue end

                local metadata = {}
                if type( source.GetMetadata ) == "function" then
                    local ok, result = source.GetMetadata( importPath ):SafeAwait()
                    if not ok then return promise.Reject( result ) end
                    metadata = result
                end

                metadata.importpath = importPath
                metadata.sourcename = sourceName
                package.FormatMetadata( metadata )

                local ok, message = gpm.CanBeInstalled( metadata, source )
                if not ok then
                    return promise.Reject( message )
                end

                if autorun and not metadata.autorun then
                    return promise.Reject( "autorun restricted." )
                end

                task = gpm.SourceImport( sourceName, importPath )
                break
            end

            if not task then
                return promise.Reject( "Requested package doesn't exist." )
            end
        end

        package.Link( parent, task )
        return task
    end )

end

function gpm.Import( importPath, async, parent )
    assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

    local task = gpm.AsyncImport( importPath, parent )
    if not async then
        local ok, result = task:SafeAwait()
        if not ok then
            error( result, 2 )
        end

        if gpm_IsPackage( result ) then
            return result:GetResult(), result
        end

        return result
    end

    return task
end

_G.import = gpm.Import

gpm.AsyncInstall = promise.Async( function( parent, ... )
    local arguments = {...}
    local length = #arguments

    for index, importPath in ipairs( arguments ) do
        if not gpm.CanImport( importPath ) then continue end

        local ok, result = gpm.AsyncImport( importPath, parent, false ):SafeAwait()
        if not ok then
            if index ~= length then continue end
            return promise.Reject( result )
        end

        return result
    end

    return promise.Reject( "Not one of the listed packages '" .. table.concat( arguments, ", " ) .. "' could be imported." )
end )

function gpm.Install( parent, async, ... )
    assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

    local task = gpm.AsyncInstall( parent, ... )
    if not async then
        local ok, result = task:SafeAwait()
        if not ok then
            error( result, 2 )
        end

        if gpm_IsPackage( result ) then
            return result:GetResult(), result
        end

        return result
    end

    return task
end

_G.install = gpm.Install

function gpm.ImportFolder( folderPath, parent, autorun )
    if not fs.IsDir( folderPath, "LUA" ) then
        logger:Warn( "Import impossible, folder '%s' does not exist, skipping...", folderPath )
        return
    end

    logger:Info( "Started import packages from folder: '%s'", folderPath )

    local files, folders = fs.Find( folderPath .. "/*", "LUA" )
    for _, fileName in ipairs( files ) do
        local importPath = folderPath .. "/" .. fileName
        gpm.AsyncImport( importPath, parent, autorun ):Catch( function( message )
            logger:Error( "Package '%s' import failed, %s", importPath, message )
        end )
    end

    for _, folderName in ipairs( folders ) do
        local importPath = folderPath .. "/" .. folderName
        gpm.AsyncImport( importPath, parent, autorun ):Catch( function( message )
            logger:Error( "Package '%s' import failed, %s", importPath, message )
        end )
    end
end
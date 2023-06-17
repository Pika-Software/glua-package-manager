local gpm = gpm

-- Libraries
local package = gpm.package
local promise = promise
local string = string
local fs = gpm.fs

-- Variables
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local table_HasIValue = table.HasIValue
local IsPackage = gpm.IsPackage
local logger = gpm.Logger
local ipairs = ipairs
local assert = assert
local type = type

local sources = gpm.sources
if not sources then
    sources = {}; gpm.sources = sources
end

for _, filePath in ipairs( fs.Find( "gpm/sources/*", "LUA" ) ) do
    local extension = string.GetExtensionFromFilename( filePath )
    gpm.IncludeComponent( "sources/" .. string.sub( filePath, 1, #filePath - ( ( extension ~= nil and #extension or 0 ) + 1 ) ) )
end

local activeGamemode = engine.ActiveGamemode()
local singlePlayer = game.SinglePlayer()
local map = game.GetMap()

do

    local sourceList = {}
    for sourceName in pairs( sources ) do
        sourceList[ #sourceList + 1 ] = sourceName
    end

    function gpm.CanImport( importPath )
        for _, sourceName in ipairs( sourceList ) do
            local source = sources[ sourceName ]
            if not source then continue end
            if source.CanImport( importPath ) then return true end
        end

        return false
    end

    function gpm.LocatePackage( ... )
        for number, importPath in ipairs( {...} ) do
            gpm.ArgAssert( importPath, number, "string" )
            if gpm.CanImport( importPath ) then return importPath end
        end
    end

    local metadatas = {}

    local getMetadata = promise.Async( function( importPath, sourceName, source )
        local metadata = metadatas[ sourceName .. ";" .. importPath ]
        if not metadata then
            if type( source.GetMetadata ) == "function" then
                local ok, result = source.GetMetadata( importPath ):SafeAwait()
                if not ok then
                    return promise.Reject( result )
                end

                metadata = result
            else
                metadata = {}
            end

            metadata = package.FormatMetadata( metadata )
            metadatas[ sourceName .. ";" .. importPath ] = metadata
        end

        if type( metadata.name ) ~= "string" then
            metadata.name = importPath
        end

        metadata.importpath = importPath
        metadata.source = sourceName

        return metadata
    end )

    local tasks = gpm.ImportTasks
    if type( tasks ) ~= "table" then
        tasks = {}; gpm.ImportTasks = tasks
    end

    gpm.SourceImport = promise.Async( function( sourceName, importPath )
        local task = tasks[ importPath ]
        if not task then
            local source = sources[ sourceName ]
            if not source then
                return promise.Reject( "Requested package source not found." )
            end

            local ok, result = getMetadata( importPath, sourceName, source ):SafeAwait()
            if not ok then
                return promise.Reject( result )
            end

            if CLIENT and not result.client then
                return promise.Reject( "Package does not support running on the client." )
            end

            if SERVER then
                if result.client and source.SendToClient then
                    source.SendToClient( result, source )
                end

                if not result.server then
                    return promise.Reject( "Package does not support running on the server." )
                end
            end

            if MENU_DLL and not result.menu then
                return promise.Reject( "Package does not support running in menu." )
            end

            if result.singleplayer and not singlePlayer then
                return promise.Reject( "Package cannot be executed in a singleplayer game." )
            end

            local gamemodes = result.gamemodes
            local gamemodesType = type( gamemodes )
            if ( gamemodesType == "string" and gamemodes ~= activeGamemode ) or ( gamemodesType == "table" and not table_HasIValue( gamemodes, activeGamemode ) ) then
                return promise.Reject( "Package does not support active gamemode." )
            end

            local maps = result.maps
            local mapsType = type( maps )
            if ( mapsType == "string" and maps ~= map ) or ( mapsType == "table" and not table_HasIValue( maps, map ) ) then
                return promise.Reject( "Package does not support current map." )
            end

            task = source.Import( result )
            tasks[ importPath ] = task
        end

        return task
    end )

    gpm.AsyncImport = promise.Async( function( importPath, pkg, autorun )
        local task = tasks[ importPath ]
        if not task then
            for _, sourceName in ipairs( sourceList ) do
                local source = sources[ sourceName ]
                if not source then continue end
                if not source.CanImport( importPath ) then continue end

                local ok, result = getMetadata( importPath, sourceName, source ):SafeAwait()
                if not ok then
                    return promise.Reject( result )
                end

                if SERVER then
                    if result.client and source.SendToClient then
                        source.SendToClient( result, source )
                    end

                    if not result.server then return end
                end

                if autorun and not result.autorun then
                    logger:Debug( "Package '%s' autorun restricted.", importPath )
                    return
                end

                if CLIENT and not result.client then return end
                if MENU_DLL and not result.menu then return end

                if result.singleplayer and not singlePlayer then
                    logger:Error( "Package '%s' import failed, package cannot be executed in a singleplayer game.", importPath )
                    return
                end

                local gamemodes = result.gamemodes
                local gamemodesType = type( gamemodes )
                if ( gamemodesType == "string" and gamemodes ~= activeGamemode ) or ( gamemodesType == "table" and not table_HasIValue( gamemodes, activeGamemode ) ) then
                    logger:Error( "Package '%s' import failed, package does not support active gamemode.", importPath )
                    return
                end

                local maps = result.maps
                local mapsType = type( maps )
                if ( mapsType == "string" and maps ~= map ) or ( mapsType == "table" and not table_HasIValue( maps, map ) ) then
                    logger:Error( "Package '%s' import failed, package does not support current map.", importPath )
                    return
                end

                task = gpm.SourceImport( sourceName, importPath )
                break
            end
        end

        if not task then
            return promise.Reject( "Requested package doesn't exist." )
        end

        task:Catch( function( message )
            logger:Error( "Package '%s' import failed, see above to see the error.", importPath )
            ErrorNoHaltWithStack( message )
        end )

        if IsPackage( pkg ) then
            if task:IsPending() then
                task:Then( function( pkg2 )
                    if IsPackage( pkg2 ) then
                        pkg:Link( pkg2 )
                    end
                end )
            elseif task:IsFulfilled() then
                local pkg2 = task:GetResult()
                if IsPackage( pkg2 ) then
                    pkg:Link( pkg2 )
                end
            end
        end

        return task
    end )

end

function gpm.Import( importPath, async, pkg2 )
    assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

    local task = gpm.AsyncImport( importPath, pkg2 )

    if not async then
        local pkg = task:Await()
        if not pkg then return end
        return pkg:GetResult(), pkg
    end

    return task
end

_G.import = gpm.Import

gpm.AsyncInstall = promise.Async( function( pkg2, ... )
    local arguments = {...}
    local length = #arguments

    for number, importPath in ipairs( arguments ) do
        if not gpm.CanImport( importPath ) then continue end

        local ok, result = gpm.AsyncImport( importPath, pkg2, false ):SafeAwait()
        if not ok then
            if number ~= length then continue end
            return promise.Reject( result )
        end

        return result
    end

    error( "Not one of the listed packages could be imported." )
end )

function gpm.Install( pkg2, async, ... )
    assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

    local task = gpm.AsyncInstall( pkg2, ... )
    task:Catch( ErrorNoHaltWithStack )

    if not async then
        local pkg = task:Await()
        if not pkg then return end
        return pkg:GetResult(), pkg
    end

    return task
end

_G.install = gpm.Install

function gpm.ImportFolder( folderPath, pkg2, autorun )
    if not fs.IsDir( folderPath, "LUA" ) then
        logger:Warn( "Import impossible, folder '%s' does not exist, skipping...", folderPath )
        return
    end

    logger:Info( "Started import from folder: %s", folderPath )

    local files, folders = fs.Find( folderPath .. "/*", "LUA" )
    for _, folderName in ipairs( folders ) do
        local importPath = folderPath .. "/" .. folderName
        gpm.AsyncImport( importPath, pkg2, autorun )
    end

    for _, fileName in ipairs( files ) do
        local importPath = folderPath .. "/" .. fileName
        gpm.AsyncImport( importPath, pkg2, autorun )
    end
end
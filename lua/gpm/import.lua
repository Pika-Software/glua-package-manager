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
local luaGamePath = gpm.LuaGamePath
local logger = gpm.Logger
local Error = gpm.Error
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
            if not source.CanImport( importPath ) then continue end
            return true
        end

        return false
    end

    function gpm.LocatePackage( importPath, alternative )
        gpm.ArgAssert( importPath, 1, "string" )
        if gpm.CanImport( importPath ) then
            return importPath
        end

        if type( alternative ) ~= "string" then
            return importPath
        end

        return alternative
    end

    local tasks, metadatas = {}, {}

    gpm.SourceImport = promise.Async( function( sourceName, importPath )
        local task = tasks[ importPath ]
        if not task then
            local source = sources[ sourceName ]
            if not source then
                return promise.Reject( "Requested package source not found." )
            end

            local metadata = metadatas[ sourceName .. ";" .. importPath ]
            if not metadata then
                if type( source.GetMetadata ) == "function" then
                    metadata = package.GetMetadata( source.GetMetadata( importPath ):Await() )
                else
                    metadata = package.GetMetadata( {} )
                end

                metadatas[ sourceName .. ";" .. importPath ] = metadata
            end

            if CLIENT and not metadata.client then
                return promise.Reject( "Package does not support running on the client." )
            end

            if MENU_DLL and not metadata.menu then
                return promise.Reject( "Package does not support running in menu." )
            end

            if metadata.singleplayer and not singlePlayer then
                return promise.Reject( "Package cannot be executed in a singleplayer game." )
            end

            local gamemodes = metadata.gamemodes
            local gamemodesType = type( gamemodes )
            if ( gamemodesType == "string" and gamemodes ~= activeGamemode ) or ( gamemodesType == "table" and not table_HasIValue( gamemodes, activeGamemode ) ) then
                return promise.Reject( "Package does not support active gamemode." )
            end

            local maps = metadata.maps
            local mapsType = type( maps )
            if ( mapsType == "string" and maps ~= map ) or ( mapsType == "table" and not table_HasIValue( maps, map ) ) then
                return promise.Reject( "Package does not support current map." )
            end

            if type( metadata.name ) ~= "string" then
                metadata.name = importPath
            end

            metadata.import_path = importPath
            metadata.source = sourceName

            if SERVER then
                if metadata.client and type( source.SendToClient ) == "function" then
                    source.SendToClient( metadata )
                end

                if not metadata.server then
                    return promise.Reject( "Package does not support running on the server." )
                end
            end

            task = source.Import( metadata )
            tasks[ importPath ] = task
        end

        return task
    end )

    gpm.AsyncImport = promise.Async( function( importPath, pkg, autorun )
        if not string.IsURL( importPath ) then
            importPath = gpm.paths.Fix( importPath )
        end

        local task = tasks[ importPath ]
        if not task then
            for _, sourceName in ipairs( sourceList ) do
                local source = sources[ sourceName ]
                if not source then continue end

                if not source.CanImport( importPath ) then continue end

                local metadata = metadatas[ sourceName .. ";" .. importPath ]
                if not metadata then
                    if type( source.GetMetadata ) == "function" then
                        metadata = package.GetMetadata( source.GetMetadata( importPath ):Await() )
                    else
                        metadata = package.GetMetadata( {} )
                    end

                    metadatas[ sourceName .. ";" .. importPath ] = metadata
                end

                if SERVER and metadata.client and type( source.SendToClient ) == "function" then
                    source.SendToClient( metadata )
                end

                if autorun then
                    if SERVER and not metadata.server then return end
                    if not metadata.autorun then
                        logger:Debug( "[%s] Package '%s' autorun restricted.", sourceName, importPath )
                        return
                    end
                end

                if SERVER and not metadata.server then
                    return promise.Reject( "Package does not support running on the server." )
                end

                task = gpm.SourceImport( sourceName, importPath )
                break
            end
        end

        if not task then
            return promise.Reject( "Requested package doesn't exist." )
        end

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

function gpm.Import( importPath, async, pkg )
    assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

    local task = gpm.AsyncImport( importPath, pkg )
    task:Catch( function( message )
        Error( importPath, message, true )
    end )

    if not async then
        local pkg = task:Await()
        if not pkg then return end
        return pkg:GetResult(), pkg
    end

    return task
end

_G.import = gpm.Import

function ImportFolder( folderPath, pkg, autorun )
    if not fs.IsDir( folderPath, luaGamePath ) then
        logger:Warn( "Import impossible, folder '%s' does not exist, skipping...", folderPath )
        return
    end

    logger:Info( "Starting to import packages from '%s'", folderPath )

    local files, folders = fs.Find( folderPath .. "/*", luaGamePath )
    for _, folderName in ipairs( folders ) do
        local importPath = folderPath .. "/" .. folderName
        gpm.AsyncImport( importPath, pkg, autorun ):Catch( function( message )
            Error( importPath, message, true, "lua" )
        end )
    end

    for _, fileName in ipairs( files ) do
        local importPath = folderPath .. "/" .. fileName
        gpm.AsyncImport( importPath, pkg, autorun ):Catch( function( message )
            Error( importPath, message, true, "lua" )
        end )
    end
end
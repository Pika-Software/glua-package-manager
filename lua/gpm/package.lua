local gpm = gpm

-- Libraries
local environment = gpm.environment
local promise = promise
local paths = gpm.paths
local utils = gpm.utils
local string = string
local table = table
local fs = gpm.fs

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local CLIENT, SERVER = CLIENT, SERVER
local luaGamePath = gpm.LuaGamePath
local AddCSLuaFile = AddCSLuaFile
local getmetatable = getmetatable
local setmetatable = setmetatable
local logger = gpm.Logger
local require = require
local SysTime = SysTime
local setfenv = setfenv
local error = error
local pairs = pairs
local pcall = pcall
local type = type
local _G = _G

module( "gpm.package" )

-- Get all registered packages
function GetAll()
    return gpm.Packages
end

-- Get one registered package
function Get( importPath )
    return gpm.Packages[ importPath ]
end

-- Get package by name/pattern
function Find( searchable, ignoreImportNames, noPatterns )
    local result = {}
    for importPath, pkg in pairs( gpm.Packages ) do
        if not ignoreImportNames and string.find( importPath, searchable, 1, noPatterns ) then
            result[ #result + 1 ] = pkg
        elseif pkg.name and string.find( pkg.name, searchable, 1, noPatterns ) then
            result[ #result + 1 ] = pkg
        end
    end

    return result
end

do

    local environment = {
        ["__index"] = _G
    }

    local function getMetadata( source )
        if type( source ) == "table" then
            utils.LowerTableKeys( source )

            -- Package name & entry point
            if type( source.name ) ~= "string" then
                source.name = nil
            end

            -- Menu
            source.menu = source.menu == true

            -- Main file
            if CLIENT and type( source.cl_main ) == "string" and not source.menu then
                source.main = source.cl_main
            end

            if type( source.main ) ~= "string" then
                source.main = nil
            end

            -- Version
            source.version = utils.Version( source.version )

            -- Gamemodes
            local gamemodesType = type( source.gamemodes )
            if ( gamemodesType ~= "string" and gamemodesType ~= "table" ) or source.menu then
                source.gamemodes = nil
            end

            -- Single-player
            source.singleplayer = source.singleplayer == true

            -- Maps
            local mapsType = type( source.maps )
            if ( mapsType ~= "string" and mapsType ~= "table" ) or source.menu then
                source.maps = nil
            end

            -- Realms
            source.client = source.client ~= false and not source.menu
            source.server = source.server ~= false and not source.menu

            -- Isolation & autorun
            source.isolation = source.isolation ~= false
            source.autorun = source.autorun == true

            -- Color
            if gpm.type( source.color ) ~= "Color" then
                source.color = nil
            end

            -- Logger
            source.logger = source.logger == true

            -- Files to send to the client ( package and main will already be added and there is no need to specify them here )
            if type( source.send ) ~= "table" or source.menu then
                source.send = nil
            end

            return source
        elseif type( source ) == "function" then
            local metadata = {}

            setmetatable( metadata, environment )
                setfenv( source, metadata )
                local ok, result = pcall( source )
            setmetatable( metadata, nil )

            if not ok then
                ErrorNoHaltWithStack( result )
                return
            end

            result = result or metadata

            if type( result ) ~= "table" then return end
            if type( result.package ) == "table" then
                result = result.package
            end

            return getMetadata( result )
        end
    end

    GetMetadata = getMetadata

end

-- Package Meta
do

    PACKAGE = PACKAGE or {}
    PACKAGE.__index = PACKAGE

    function PACKAGE:GetMetadata()
        return self.metadata
    end

    function PACKAGE:GetName()
        return table.Lookup( self, "metadata.name", "unknown" )
    end

    function PACKAGE:GetVersion()
        return table.Lookup( self, "metadata.version", "unknown" )
    end

    function PACKAGE:GetIdentifier( name )
        local identifier = string.format( "%s@%s", self:GetName(), self:GetVersion() )
        if type( name ) ~= "string" then return identifier end
        return identifier .. "::" .. name
    end

    function PACKAGE:GetSourceName()
        return table.Lookup( self, "metadata.source", "unknown" )
    end

    PACKAGE.__tostring = PACKAGE.GetIdentifier

    function PACKAGE:GetEnvironment()
        return self.environment
    end

    function PACKAGE:GetLogger()
        return self.logger
    end

    function PACKAGE:GetResult()
        return self.result
    end

    function PACKAGE:GetImportPath()
        return table.Lookup( self, "metadata.import_path" )
    end

    function PACKAGE:GetFolder()
        return table.Lookup( self, "metadata.folder" )
    end

    function PACKAGE:GetFiles()
        return self.files
    end

    function PACKAGE:GetFileList()
        local fileList = {}
        for filePath in pairs( self.files ) do
            fileList[ #fileList + 1 ] = filePath
        end

        return fileList
    end

    function PACKAGE:IsIsolated()
        return table.Lookup( self, "metadata.isolation" )
    end

    function PACKAGE:Link( package2 )
        gpm.ArgAssert( package2, 1, "Package" )

        local env = self:GetEnvironment()
        if not env then return end

        local env2 = package2:GetEnvironment()
        if not env2 then return end

        logger:Debug( "'%s' -> '%s'", package2:GetIdentifier(), self:GetIdentifier() )
        environment.LinkMetaTables( env, env2 )
    end

    local function isPackage( any ) return getmetatable( any ) == PACKAGE end
    gpm.IsPackage = isPackage
    _G.IsPackage = isPackage

    _G.TYPE_PACKAGE = gpm.AddType( "Package", isPackage )

end

Initialize = promise.Async( function( metadata, func, files )
    if type( files ) ~= "table" then
        files = nil
    end

    -- Measuring package startup time
    local stopwatch = SysTime()

    -- Creating package object
    local pkg = setmetatable( {}, PACKAGE )
    pkg.metadata = metadata
    pkg.files = files

    if metadata.isolation then

        -- Creating environment for package
        local env = environment.Create( func, _G )
        pkg.environment = env
        setfenv( func, env )

        -- Globals
        environment.SetLinkedTable( env, "gpm", gpm )
        env._VERSION = metadata.version
        env.ArgAssert = gpm.ArgAssert
        env.TypeID = gpm.TypeID
        env.type = gpm.type
        env.http = gpm.http
        env.file = fs

        -- Binding package object to gpm.Package & _PKG
        table.SetValue( env, "gpm.Package", pkg )
        table.SetValue( env, "_PKG", pkg )

        -- Logger
        if metadata.logger then
            pkg.logger = gpm.logger.Create( pkg:GetIdentifier(), metadata.color )
            table.SetValue( env, "gpm.Logger", pkg.logger )
        end

        -- import
        environment.SetValue( env, "import", function( importPath, async, pkg2 )
            if gpm.IsPackage( pkg2 ) then
                return gpm.Import( importPath, async, pkg2 )
            end

            return gpm.Import( importPath, async, pkg )
        end )

        env.gpm.Import = env.import

        -- include
        environment.SetValue( env, "include", function( fileName )
            gpm.ArgAssert( fileName, 1, "string" )
            fileName = paths.Fix( fileName )

            local func = nil
            if files ~= nil then
                func = files[ fileName ]
            end

            if type( func ) ~= "function" then
                local currentFile = utils.GetCurrentFile()
                if currentFile then
                    local folder = paths.Localize( string.GetPathFromFilename( currentFile ) )
                    if folder then
                        local filePath = folder .. fileName
                        if fs.IsFile( filePath, luaGamePath ) then
                            func = gpm.CompileLua( filePath ):Await()
                        end
                    end
                end
            end

            if type( func ) ~= "function" and fs.IsFile( fileName, luaGamePath ) then
                func = gpm.CompileLua( fileName ):Await()
            end

            if type( func ) == "function" then
                setfenv( func, env )
                return func()
            end

            error( "Couldn't include file '" .. fileName .. "' - File not found" )
        end )

        -- AddCSLuaFile
        if SERVER then
            environment.SetValue( env, "AddCSLuaFile", function( fileName )
                local currentFile = utils.GetCurrentFile()
                if currentFile then
                    local luaPath = paths.Localize( currentFile )
                    if fileName ~= nil then
                        gpm.ArgAssert( fileName, 1, "string" )
                    else
                        fileName = string.GetFileFromFilename( luaPath )
                    end

                    local folder = string.GetPathFromFilename( luaPath )
                    if folder then
                        local filePath = folder .. fileName
                        if fs.IsFile( filePath, luaGamePath ) then
                            return AddCSLuaFile( filePath )
                        end
                    end
                end

                if type( fileName ) == "string" and fs.IsFile( fileName, luaGamePath ) then
                    return AddCSLuaFile( fileName )
                end

                error( "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found" )
            end )
        end

        -- require
        environment.SetValue( env, "require", function( name, alternative )
            gpm.ArgAssert( name, 1, "string" )

            local hasAlternative = type( alternative ) == "string"
            if util.IsBinaryModuleInstalled( name ) then
                return require( name )
            elseif hasAlternative and util.IsBinaryModuleInstalled( alternative ) then
                return require( alternative )
            end

            local importPath = "includes/modules/" .. name .. ".lua"
            if fs.IsFile( importPath, luaGamePath ) then
                return gpm.Import( importPath, false, pkg )
            elseif hasAlternative and not string.IsURL( alternative ) then
                importPath = "includes/modules/" .. alternative .. ".lua"
                if fs.IsFile( importPath, luaGamePath ) then
                    return gpm.Import( importPath, false, pkg )
                end
            end

            return gpm.Import( gpm.LocatePackage( name, alternative ), false, pkg )
        end )

    end

    -- Run
    local ok, result = pcall( func, pkg )
    if not ok then return promise.Reject( result ) end

    -- Saving result to package
    pkg.result = result

    -- Saving in global table & final log
    local importPath = metadata.import_path
    logger:Info( "[%s] Package '%s' was successfully imported, it took %.4f seconds.", pkg:GetSourceName(), pkg:GetIdentifier(), SysTime() - stopwatch )
    gpm.Packages[ importPath ] = pkg

    return pkg
end )
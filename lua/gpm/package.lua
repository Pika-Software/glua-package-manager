
local gpm = gpm

-- Libraries
local environment = gpm.environment
local promise = promise
local paths = gpm.paths
local utils = gpm.utils
local string = string
local table = table
local fs = gpm.fs
local util = util

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local CLIENT, SERVER = CLIENT, SERVER
local AddCSLuaFile = AddCSLuaFile
local getmetatable = getmetatable
local setmetatable = setmetatable
local logger = gpm.Logger
local require = require
local SysTime = SysTime
local setfenv = setfenv
local ipairs = ipairs
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
            source.menu = source.menu ~= false

            -- Main file
            if CLIENT and type( source.cl_main ) == "string" then
                source.main = source.cl_main
            end

            if type( source.main ) ~= "string" then
                source.main = nil
            end

            -- Version
            source.version = utils.Version( source.version )

            -- Gamemodes
            local gamemodesType = type( source.gamemodes )
            if gamemodesType ~= "string" and gamemodesType ~= "table" then
                source.gamemodes = nil
            end

            -- Single-player
            source.singleplayer = source.singleplayer == true

            -- Maps
            local mapsType = type( source.maps )
            if mapsType ~= "string" and mapsType ~= "table" then
                source.maps = nil
            end

            -- Realms
            source.client = source.client ~= false
            source.server = source.server ~= false

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
            if type( source.send ) ~= "table" then
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

local function getCurrentLuaPath()
    local filePath = utils.GetCurrentFile()
    if not filePath then return end
    return paths.Localize( paths.Fix( filePath ) )
end

if SERVER then

    function AddClientLuaFile( fileName )
        local filePath = nil
        local luaPath = getCurrentLuaPath()
        if luaPath then
            if fileName ~= nil then
                gpm.ArgAssert( fileName, 1, "string" )
            else
                fileName = string.GetFileFromFilename( luaPath )
            end

            local folder = string.GetPathFromFilename( luaPath )
            if folder and #folder > 0 then
                filePath = paths.Fix( folder .. fileName )
            end
        else
            gpm.ArgAssert( fileName, 1, "string" )
        end

        if filePath ~= nil and not fs.IsFile( "lua/" .. filePath, "GAME" ) then
            filePath = paths.Fix( fileName )
        end

        if fs.IsFile( "lua/" .. filePath, "GAME" ) then
            return AddCSLuaFile( filePath )
        end

        error( "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found" )
    end

end

local addClientLuaFile = SERVER and AddClientLuaFile

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
        env.gpm.Package = pkg
        env._PKG = pkg

        -- Logger
        if metadata.logger then
            pkg.logger = gpm.logger.Create( pkg:GetIdentifier(), metadata.color )
            table.SetValue( env, "gpm.Logger", pkg.logger )
        end

        -- import
        env["gpm.Import"] = function( importPath, async, pkg2 )
            if gpm.IsPackage( pkg2 ) then
                return gpm.Import( importPath, async, pkg2 )
            end

            return gpm.Import( importPath, async, pkg )
        end

        env.import = env["gpm.Import"]

        -- install
        env["gpm.Install"] = function( pkg2, async, ... )
            if gpm.IsPackage( pkg2 ) then
                return gpm.Install( pkg2, async, ... )
            end

            return gpm.Install( pkg, async, ... )
        end

        env.install = function( ... )
            return gpm.Install( pkg, false, ... )
        end

        -- require
        env.require = function( ... )
            local arguments = {...}
            local lenght = #arguments

            for number, name in ipairs( arguments ) do
                gpm.ArgAssert( name, number, "string" )

                if string.IsURL( name ) then
                    if not gpm.CanImport( name ) then continue end

                    local ok, result = gpm.AsyncImport( name, pkg, false ):SafeAwait()
                    if not ok then
                        if number ~= lenght then continue end
                        error( result )
                    end

                    return result
                end

                if util.IsBinaryModuleInstalled( name ) then
                    return require( name )
                end

                if util.IsLuaModuleInstalled( name ) then
                    local pkg2 = gpm.SourceImport( "lua", "includes/modules/" .. name .. ".lua" ):Await()
                    pkg:Link( pkg2 )
                    return pkg2:GetResult()
                end
            end

            error( "Not one of the listed packages could be required." )
        end

        -- include
        env.include = function( fileName )
            gpm.ArgAssert( fileName, 1, "string" )

            local func = nil
            if files ~= nil then
                func = files[ paths.Fix( fileName ) ]
            end

            if type( func ) ~= "function" then
                local luaPath = getCurrentLuaPath()
                if luaPath then
                    local folder = string.GetPathFromFilename( luaPath )
                    if folder and #folder > 0 then
                        local filePath = paths.Fix( folder .. fileName )
                        if fs.IsFile( "lua/" .. filePath, "GAME" ) then
                            func = gpm.CompileLua( filePath ):Await()
                        end
                    end
                end
            end

            if type( func ) ~= "function" then
                local filePath = paths.Fix( fileName )
                if fs.IsFile( "lua/" .. filePath, "GAME" ) then
                    func = gpm.CompileLua( filePath ):Await()
                end
            end

            if type( func ) == "function" then
                setfenv( func, env )
                return func()
            end

            error( "Couldn't include file '" .. fileName .. "' - File not found" )
        end

        -- AddCSLuaFile
        if SERVER then
            env.AddCSLuaFile = addClientLuaFile
        end

    end

    -- Run
    local ok, result = pcall( func, pkg )
    if not ok then
        return promise.Reject( result )
    end

    -- Saving result to package
    pkg.result = result

    -- Saving in global table & final log
    local importPath = metadata.import_path
    logger:Info( "[%s] Package '%s' was successfully imported, it took %.4f seconds.", pkg:GetSourceName(), pkg:GetIdentifier(), SysTime() - stopwatch )
    gpm.Packages[ importPath ] = pkg

    return pkg
end )

local gpm = gpm

-- Libraries
local environment = gpm.environment
local paths = gpm.paths
local utils = gpm.utils
local string = string
local table = table
local fs = gpm.fs

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local CLIENT, SERVER = CLIENT, SERVER
local AddCSLuaFile = AddCSLuaFile
local getmetatable = getmetatable
local setmetatable = setmetatable
local luaRealm = gpm.LuaRealm
local logger = gpm.Logger
local require = require
local SysTime = SysTime
local setfenv = setfenv
local xpcall = xpcall
local error = error
local pairs = pairs
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

-- gpm.package.GetMetadata( source )
do

    local environment = {
        ["__index"] = _G
    }

    local function getMetadata( source )
        if type( source ) == "table" then
            -- Package name & entry point
            if type( source.name ) ~= "string" then
                source.name = nil
            end

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
            source.singleplayer = source.singleplayer ~= false

            -- Maps
            local mapsType = type( source.maps )
            if mapsType ~= "string" and mapsType ~= "table" then
                source.maps = nil
            end

            -- Realms
            source.client = source.client ~= false
            source.server = source.server ~= false
            source.menu = source.menu == true

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

            local ok, result = xpcall( source, ErrorNoHaltWithStack )
            setmetatable( metadata, nil )

            if not ok then return end
            result = result or metadata

            if type( result ) ~= "table" then return end
            result = utils.LowerTableKeys( result )

            if type( result.package ) ~= "table" then
                return getMetadata( result )
            end

            return getMetadata( result.package )
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
        return table.Lookup( self, "metadata.importPath" )
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

        environment.LinkMetaTables( env, env2 )
    end

    local function isPackage( any ) return getmetatable( any ) == PACKAGE end
    gpm.IsPackage = isPackage
    _G.IsPackage = isPackage

    _G.TYPE_PACKAGE = gpm.AddType( "Package", isPackage )

end

-- Function run in package
local function run( func, package )
    local environment = package:GetEnvironment()
    if environment then
        setfenv( func, environment )
    end

    return func()
end

Run = run

-- Safe function run in package
local function safeRun( func, package, errorHandler )
    return xpcall( run, errorHandler, func, package )
end

SafeRun = safeRun

-- This function will return compiled lua files by the path
local function getCompiledFile( filePath, files )
    local func = nil
    if files ~= nil then
        func = files[ filePath ]
    end

    if not func and fs.IsFile( filePath, luaRealm ) then
        local ok, result = gpm.CompileLua( filePath )
        if ok then
            func = result
        end
    end

    return func
end

GetCompiledFile = getCompiledFile

function Initialize( metadata, func, files )
    gpm.ArgAssert( metadata, 1, "table" )
    gpm.ArgAssert( func, 2, "function" )

    if type( files ) ~= "table" then files = nil end

    -- Measuring package startup time
    local stopwatch = SysTime()

    -- Creating package object
    local package = setmetatable( {}, PACKAGE )
    package.metadata = metadata
    package.files = files

    if metadata.isolation then

        -- Creating environment for package
        local env = environment.Create( func, _G )
        package.environment = env

        -- Globals
        environment.SetLinkedTable( env, "gpm", gpm )
        env._VERSION = metadata.version
        env.ArgAssert = gpm.ArgAssert
        env.promise = gpm.promise
        env.TypeID = gpm.TypeID
        env.type = gpm.type
        env.http = gpm.http
        env.file = fs

        -- Binding package object to gpm.Package & _PKG
        table.SetValue( env, "gpm.Package", package )
        table.SetValue( env, "_PKG", package )

        -- Logger
        if metadata.logger then
            package.logger = gpm.logger.Create( package:GetIdentifier(), metadata.color )
            table.SetValue( env, "gpm.Logger", package.logger )
        end

        environment.SetValue( env, "import", function( filePath, async )
            return gpm.Import( filePath, async, package )
        end )

        -- include
        environment.SetValue( env, "include", function( fileName )
            local currentFile = utils.GetCurrentFile()
            if currentFile then
                local folder = string.GetPathFromFilename( paths.Localize( currentFile ) )
                if folder then
                    local func = getCompiledFile( folder .. fileName, files )
                    if func then
                        return run( func, package )
                    end
                end
            end

            local func = getCompiledFile( fileName, files )
            if func then
                return run( func, package )
            end

            error( "Couldn't include file '" .. fileName .. "' - File not found" )
        end )

        -- AddCSLuaFile
        if SERVER then
            environment.SetValue( env, "AddCSLuaFile", function( fileName )
                local currentFile = utils.GetCurrentFile()
                if currentFile then
                    if fileName ~= nil then
                        gpm.ArgAssert( fileName, 1, "string" )
                    else
                        fileName = currentFile
                    end

                    local folder = string.GetPathFromFilename( paths.Localize( currentFile ) )
                    if folder then
                        local filePath = folder .. fileName
                        if fs.IsFile( filePath, luaRealm ) then
                            return AddCSLuaFile( filePath )
                        end
                    end
                end

                if fs.IsFile( fileName, luaRealm ) then
                    return AddCSLuaFile( fileName )
                end

                error( "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found" )
            end )
        end

        -- require
        environment.SetValue( env, "require", function( name )
            if util.IsBinaryModuleInstalled( name ) then return require( name ) end

            local ok, result = gpm.SourceImport( "lua", "includes/modules/" .. name .. ".lua", _PKG, false ):SafeAwait()
            if ok then return result end

            error( "Module '" .. name .. "' not found!" )
        end )

    end

    local importPath = metadata.importPath

    -- Run
    local ok, result = safeRun( func, package, ErrorNoHaltWithStack )
    if not ok then
        logger:Error( "Package '%s' import failed, see above for the reason.", importPath )
        return
    end

    -- Saving result to package
    package.result = result

    -- Saving in global table & final log
    logger:Info( "Package '%s' was successfully imported, it took %.4f seconds.", importPath, SysTime() - stopwatch )
    gpm.Packages[ importPath ] = package

    return package
end
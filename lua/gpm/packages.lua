-- Libraries
local gpm = gpm
local environment = gpm.environment
local paths = gpm.paths
local utils = gpm.utils
local string = string
local table = table
local fs = gpm.fs

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local AddCSLuaFile = AddCSLuaFile
local getmetatable = getmetatable
local setmetatable = setmetatable
local ArgAssert = ArgAssert
local tostring = tostring
local logger = gpm.Logger
local require = require
local SysTime = SysTime
local IsColor = IsColor
local setfenv = setfenv
local xpcall = xpcall
local pairs = pairs
local type = type
local _G = _G

-- Packages table
local packages = gpm.Packages
if type( packages ) ~= "table" then
    packages = {}; gpm.Packages = packages
end

module( "gpm.packages", package.seeall )

-- Get all registered packages
function GetAll()
    return packages
end

-- Get one registered package
function Get( packageName )
    return packages[ packageName ]
end

-- gpm.packages.GetMetadata( source )
do

    local environment = {
        ["__index"] = _G
    }

    local function getMetadata( source )
        if type( source ) == "table" then
            -- Package name, main file & author
            source.name = type( source.name ) == "string" and source.name or nil
            source.main = type( source.main ) == "string" and source.main or nil
            source.author = type( source.author ) == "string" and source.author or nil

            -- Version
            source.version = utils.Version( source.version )

            -- Gamemode
            local gamemodeType = type( source.gamemode )
            if gamemodeType ~= "string" and gamemodeType ~= "table" then
                source.gamemode = nil
            end

            -- Single-player
            source.singleplayer = source.singleplayer ~= false

            -- Realms
            source.client = source.client ~= false
            source.server = source.server ~= false

            -- Isolation & autorun
            source.isolation = source.isolation ~= false
            source.autorun = source.autorun == true

            -- Color & logger
            source.color = IsColor( source.color ) and source.color or nil
            source.logger = source.logger == true

            -- Files to send to the client ( package and main will already be added and there is no need to specify them here )
            source.send = type( source.send ) == "table" and source.send or nil

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

    function PACKAGE:GetFilePath()
        return table.Lookup( self, "metadata.filePath" )
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

local modules = {}

function Initialize( metadata, func, files )
    ArgAssert( metadata, 1, "table" )
    ArgAssert( func, 2, "function" )
    ArgAssert( files, 3, "table" )

    -- Measuring package startup time
    local stopwatch = SysTime()

    -- Creating package object
    local gPackage = setmetatable( {}, PACKAGE )
    gPackage.metadata = metadata
    gPackage.files = files

    if metadata.isolation then

        -- Creating environment for package
        local packageEnv = environment.Create( func, _G )
        gPackage.environment = packageEnv

        -- Globals
        environment.SetLinkedTable( packageEnv, "gpm", gpm )
        packageEnv._VERSION = metadata.version
        packageEnv.promise = gpm.promise
        packageEnv.TypeID = gpm.TypeID
        packageEnv.type = gpm.type
        packageEnv.http = gpm.http
        packageEnv.file = fs

        -- Binding package object to gpm.Package
        table.SetValue( packageEnv, "gpm.Package", gPackage )

        -- Logger
        if metadata.logger then
            gPackage.logger = gpm.logger.Create( gPackage:GetIdentifier(), metadata.color )
            table.SetValue( packageEnv, "gpm.Logger", gPackage.logger )
        end

        environment.SetValue( packageEnv, "import", function( filePath, async )
            return gpm.Import( filePath, async, gPackage )
        end )

        -- include
        environment.SetValue( packageEnv, "include", function( fileName )
            local currentFile = utils.GetCurrentFile()
            if currentFile then
                local folder = string.GetPathFromFilename( paths.Localize( currentFile ) )
                if folder then
                    local func = files[ folder .. fileName ]
                    if func then
                        return run( func, gPackage )
                    end
                end
            end

            local func = files[ fileName ]
            if func then
                return run( func, gPackage )
            end

            ErrorNoHaltWithStack( "Couldn't include file '" .. tostring( fileName ) .. "' - File not found" )
        end )

        -- AddCSLuaFile
        if SERVER then
            environment.SetValue( packageEnv, "AddCSLuaFile", function( fileName )
                local currentFile = utils.GetCurrentFile()
                if currentFile then
                    if fileName ~= nil then
                        ArgAssert( fileName, 1, "string" )
                    else
                        fileName = currentFile
                    end

                    local folder = string.GetPathFromFilename( paths.Localize( currentFile ) )
                    if folder then
                        local filePath = folder .. fileName
                        if fs.Exists( filePath, gpm.LuaRealm ) then
                            return AddCSLuaFile( filePath )
                        end
                    end
                end

                if fs.Exists( fileName, gpm.LuaRealm ) then
                    return AddCSLuaFile( fileName )
                end

                ErrorNoHaltWithStack( "Couldn't AddCSLuaFile file '" .. tostring( fileName ) .. "' - File not found" )
            end )
        end

        -- require
        environment.SetValue( packageEnv, "require", function( name )
            if util.IsBinaryModuleInstalled( name ) then
                return require( name )
            end

            local package2 = modules[ name ]
            if gpm.IsPackage( package2 ) then
                gpm.packages.LinkPackages( gPackage, package2 )
                return package2:GetResult()
            end

            local ok, result = gpm.Import( "includes/modules/" .. name .. ".lua", true, gPackage, false ):SafeAwait()
            if ok then
                modules[ name ] = result
                return result
            end

            ErrorNoHaltWithStack( "Module `" .. name .. "` not found!" )
        end )

    end

    -- Package folder
    local packagePath = metadata.filePath

    -- Run
    local ok, result = safeRun( func, gPackage, ErrorNoHaltWithStack )
    if not ok then
        logger:Error( "Package `%s` start-up failed, see above for the reason, it took %.4f seconds.", packagePath, SysTime() - stopwatch )
        return
    end

    -- Saving result to gPackage
    gPackage.result = result

    -- Saving in global table & final log
    logger:Info( "Package `%s` was successfully loaded, it took %.4f seconds.", packagePath, SysTime() - stopwatch )

    local versions = packages[ packagePath ]
    if type( versions ) ~= "table" then
        versions = {}; packages[ packagePath ] = versions
    end

    versions[ gPackage:GetVersion() ] = gPackage

    return gPackage
end

function LinkPackages( package1, package2 )
    ArgAssert( package1, 1, "Package" )
    ArgAssert( package2, 2, "Package" )

    local environment1, environment2 = package1:GetEnvironment(), package2:GetEnvironment()
    logger:Debug( "Packages `%s` <- `%s` import status: %s", package1, package2, ( environment1 ~= nil and environment2 ~= nil ) and "success" or "failed" )
    if not environment1 or not environment2 then return end

    environment.LinkMetaTables( environment1, environment2 )
end
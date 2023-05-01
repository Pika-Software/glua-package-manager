-- Libraries
local environment = gpm.environment
local paths = gpm.paths
local utils = gpm.utils
local string = string
local table = table

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local AddCSLuaFile = AddCSLuaFile
local getmetatable = getmetatable
local setmetatable = setmetatable
local ArgAssert = ArgAssert
local tostring = tostring
local logger = gpm.Logger
local SysTime = SysTime
local IsColor = IsColor
local setfenv = setfenv
local xpcall = xpcall
local Color = Color
local pairs = pairs
local type = type
local _G = _G

-- Packages table
local pkgs = gpm.Packages
if type( pkgs ) ~= "table" then
    pkgs = {}; gpm.Packages = pkgs
end

module( "gpm.packages", package.seeall )

-- Get all registered packages
function GetAll()
    return pkgs
end

-- Get one registered package
function Get( packageName )
    return pkgs[ packageName ]
end

function GetMetadata( source )
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
        local env = {
            ["Color"] = Color
        }

        setfenv( source, env )

        local ok, result = xpcall( source, ErrorNoHaltWithStack )
        if not ok then return end
        result = result or env

        if type( result ) ~= "table" then return end
        result = utils.LowerTableKeys( result )

        if type( result.package ) ~= "table" then
            return GetMetadata( result )
        end

        return GetMetadata( result.package )
    end
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

    local function isPackage( any ) return getmetatable( any ) == PACKAGE end
    _G.IsPackage = isPackage
    IsPackage = isPackage

    local typePackage = gpm.AddType( "Package", isPackage )
    _G.TYPE_PACKAGE = typePackage
    TYPE_PACKAGE = typePackage

end

local function run( gPackage, func )
    local env = gPackage.environment
    if env ~= nil then
        setfenv( func, env )
    end

    return func()
end

Run = run

local function safeRun( gPackage, func, errorHandler )
    return xpcall( Run, errorHandler, gPackage, func )
end

SafeRun = safeRun

local function findFilePath( fileName, files )
    if type( fileName ) ~= "string" or type( files ) ~= "table" then return end

    local currentFile = utils.GetCurrentFile()
    if currentFile ~= nil then
        local folder = string.GetPathFromFilename( paths.Localize( currentFile ) )
        if type( folder ) == "string" then
            local filePath = folder .. fileName
            if files[ filePath ] then
                return filePath
            end
        end
    end

    if files[ fileName ] then
        return fileName
    end
end

FindFilePath = findFilePath

function Initialize( metadata, func, files, parentPackage )
    ArgAssert( metadata, 1, "table" )
    ArgAssert( func, 2, "function" )
    ArgAssert( files, 3, "table" )

    local versions = pkgs[ metadata.name ]
    if versions ~= nil then
        local gPackage = versions[ metadata.version ]
        if IsPackage( gPackage ) then
            if metadata.isolation and IsPackage( parentPackage ) then
                environment.LinkMetaTables( parentPackage.environment, gPackage.environment )
            end

            return gPackage.result
        end
    end

    -- Measuring package startup time
    local stopwatch = SysTime()

    -- Creating package object
    local gPackage = setmetatable( {}, PACKAGE )
    gPackage.metadata = metadata
    gPackage.files = files

    if metadata.logger then
        gPackage.logger = gpm.logger.Create( gPackage:GetIdentifier(), metadata.color )
    end

    if metadata.isolation then

        -- Creating environment for package
        local packageEnv = environment.Create( func )
        gPackage.environment = packageEnv

        -- Adding to the parent package
        if IsPackage( parentPackage ) then
            environment.LinkMetaTables( parentPackage.environment, packageEnv )
        end

        -- Binding package object to gpm.Package
        environment.SetLinkedTable( packageEnv, "gpm", gpm )

        -- GPM globals
        table.SetValue( packageEnv, "gpm.Logger", gPackage.logger )
        table.SetValue( packageEnv, "gpm.Package", gPackage )

        -- Globals
        packageEnv._VERSION = metadata.version
        packageEnv.promise = gpm.promise
        packageEnv.TypeID = gpm.TypeID
        packageEnv.type = gpm.type
        packageEnv.http = gpm.http
        packageEnv.file = gpm.fs

        environment.SetValue( packageEnv, "import", function( filePath, async, parentPackage )
            return gpm.Import( filePath, async, parentPackage or gpm.Package )
        end )

        -- include
        environment.SetValue( packageEnv, "include", function( fileName )
            local filePath = findFilePath( fileName, files )
            if filePath then
                local func = files[ filePath ]
                if func then
                    return run( gPackage, func )
                end
            end

            ErrorNoHaltWithStack( "Couldn't include file '" .. tostring( fileName ) .. "' - File not found" )
        end )

        -- AddCSLuaFile
        if SERVER then
            environment.SetValue( packageEnv, "AddCSLuaFile", function( fileName )
                if not fileName then
                    fileName = paths.Localize( utils.GetCurrentFile() )
                end

                local filePath = findFilePath( fileName, files )
                if filePath then
                    return AddCSLuaFile( filePath )
                end

                -- ErrorNoHaltWithStack( "Couldn't AddCSLuaFile file '" .. tostring( fileName ) .. "' - File not found" )
            end )
        end

    end

    -- Run
    local ok, result = safeRun( gPackage, func, ErrorNoHaltWithStack )
    if not ok then
        logger:Error( "Package `%s` start-up failed, see above for the reason, it took %.4f seconds.", gPackage, SysTime() - stopwatch )
        return
    end

    -- Saving result to gPackage
    gPackage.result = result

    -- Saving in global table & final log
    logger:Info( "Package `%s` was successfully loaded, it took %.4f seconds.", gPackage, SysTime() - stopwatch )

    local packageName = gPackage:GetName()
    pkgs[ packageName ] = pkgs[ packageName ] or {}
    pkgs[ packageName ][ gPackage:GetVersion() ] = gPackage

    return result
end
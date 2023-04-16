-- Libraries
local environment = gpm.environment
local paths = gpm.paths
local utils = gpm.utils
local string = string
local table = table

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local AddCSLuaFile = AddCSLuaFile
local ArgAssert = ArgAssert
local logger = gpm.Logger
local setfenv = setfenv
local xpcall = xpcall
local pairs = pairs
local type = type

-- Packages table
local pkgs = gpm.Packages
if type( pkgs ) ~= "table" then
    pkgs = {}; gpm.Packages = pkgs
end

TYPE_PACKAGE = 256

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
        local version = source.version
        if isnumber( version ) then
            source.version = version
        else
            source.version = 1
        end

        -- Realms
        source.client = source.client ~= false
        source.server = source.server ~= false

        -- Package isolation & logger
        source.isolation = source.isolation ~= false
        source.logger = source.logger ~= false

        -- Files to send to the client ( package and main will already be added and there is no need to specify them here )
        source.send = type( source.send ) == "table" and source.send or nil

        return source
    elseif type( source ) == "function" then
        local env = {}
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
        return self.metadata.name
    end

    function PACKAGE:GetVersion()
        return self.metadata.version
    end

    function PACKAGE:GetIdentifier( name )
        local identifier = string.format( "%s@%s", self:GetName(), utils.Version( self:GetVersion() ) )
        if name then
            if type( name ) == "string" then
                return identifier .. "::" .. name
            end

            return name
        end

        return identifier
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

    do

        local getmetatable = getmetatable

        function IsPackage( any )
            return getmetatable( any ) == PACKAGE
        end

        list.Set( "GPM - Type Names", TYPE_PACKAGE, "Package" )
        gpm.SetTypeID( TYPE_PACKAGE, IsPackage )

    end

end

function Run( gPackage, func )
    local env = gPackage.environment
    if env ~= nil then
        setfenv( func, env )
    end

    return func()
end

function SafeRun( gPackage, func, errorHandler )
    return xpcall( Run, errorHandler, gPackage, func )
end

function FindFilePath( fileName, files )
    if type( fileName ) ~= "string" or type( files ) ~= "table" then return end

    local currentFile = utils.GetCurrentFile()
    if currentFile ~= nil then
        local folder = string.GetPathFromFilename( paths.Localize( currentFile ) )
        if type( folder ) == "string" then
            local path = paths.Join( folder, fileName )
            if files[ path ] then return path end
        end
    end

    return files[ fileName ] and fileName
end

do

    local setmetatable = setmetatable
    local packages = gpm.packages
    local tostring = tostring
    local SysTime = SysTime

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

            -- Globals
            table.SetValue( packageEnv, "gpm.Logger", gPackage.logger )
            table.SetValue( packageEnv, "gpm.Package", gPackage, true )
            table.SetValue( packageEnv, "_VERSION", metadata.version )
            table.SetValue( packageEnv, "promise", gpm.promise )
            table.SetValue( packageEnv, "TypeID", gpm.TypeID )
            table.SetValue( packageEnv, "type", gpm.type )
            table.SetValue( packageEnv, "http", gpm.http )
            table.SetValue( packageEnv, "file", gpm.fs )

            environment.SetValue( packageEnv, "import", function( filePath, async, parentPackage )
                return gpm.Import( filePath, async, parentPackage or gpm.Package )
            end )

            -- include
            environment.SetValue( packageEnv, "include", function( fileName )
                local path = packages.FindFilePath( fileName, files )

                if path and files[ path ] then
                    return packages.Run( gpm.Package, files[ path ] )
                end

                ErrorNoHaltWithStack( "Couldn't include file '" .. tostring( fileName ) .. "' - File not found" )
            end )

            -- AddCSLuaFile
            if SERVER then
                environment.SetValue( packageEnv, "AddCSLuaFile", function( fileName )
                    if fileName == nil then fileName = paths.Localize( utils.GetCurrentFile() ) end
                    local path = packages.FindFilePath( fileName, files )
                    if path then return AddCSLuaFile( path ) end

                    ErrorNoHaltWithStack( "Couldn't AddCSLuaFile file '" .. tostring( fileName ) .. "' - File not found" )
                end )
            end

        end

        -- Run
        local ok, result = SafeRun( gPackage, func, ErrorNoHaltWithStack )
        if not ok then
            logger:Warn( "Package `%s` failed to load, see above for the reason, it took %.4f seconds.", gPackage, SysTime() - stopwatch )
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

end

if SERVER then

    concommand.Add( "gpm_list", function( ply )
        if ply ~= nil and not ply:IsListenServerHost() then return end

        logger:Info( "Package list:" )
        for name, versions in pairs( pkgs ) do
            local vTbl = {}
            for version in pairs( versions ) do
                vTbl[ #vTbl + 1 ] = utils.Version( version )
            end

            logger:Info( "%s@%s", name, table.concat( vTbl, ", " ) )
        end
    end )

end

if CLIENT then

    concommand.Add( "gpm_list", function()
        logger:Info( "Package list:" )
        for name, versions in pairs( pkgs ) do
            local vTbl = {}
            for version in pairs( versions ) do
                vTbl[ #vTbl + 1 ] = utils.Version( version )
            end

            logger:Info( "%s@%s", name, table.concat( vTbl, ", " ) )
        end
    end )

end
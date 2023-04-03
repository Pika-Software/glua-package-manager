-- Libraries
local environment = gpm.environment
local string = string

-- Functions
local debug_setfenv = debug.setfenv
local AddCSLuaFile = AddCSLuaFile

-- Packages table
local packages = gpm.Packages
if not istable( packages ) then
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

function GetMetaData( source )
    if istable( source ) then
        local metadata = {}
        metadata.name = isstring( source.name ) and source.name or nil
        metadata.main = isstring( source.main ) and source.main or nil

        local version = source.version
        if isnumber( version ) then
            metadata.version = gpm.utils.Version( version )
        else
            metadata.version = "0.0.1"
        end

        metadata.server = metadata.server == true
        metadata.client = metadata.client == true

        return metadata
    elseif isfunction( source ) then
        local env = {}
        setfenv( source, env )

        local ok, result = xpcall( source, ErrorNoHaltWithStack )
        if ( ok and result ~= nil ) then
            if not istable( result ) then
                env = gpm.utils.LowerTableKeys( env )
                if not env.package then return env end
                return env.package
            end

            return GetMetaData( result )
        end
    end
end

-- Package Meta
do

    PACKAGE = PACKAGE or {}
    PACKAGE.__index = PACKAGE

    function PACKAGE:GetInfo()
        return self.Info
    end

    function PACKAGE:GetName()
        return self.Info.name
    end

    function PACKAGE:GetVersion()
        return self.Info.version
    end

    function PACKAGE:GetIdentifier( name )
        local identifier = string.format( "%s@%s", self:GetName(), self:GetVersion() )
        if name then
            if isstring( name ) then
                return identifier .. "::" .. name
            end

            return name
        end

        return identifier
    end

    function PACKAGE:__tostring()
        return self:GetIdentifier()
    end

    function PACKAGE:GetEnvironment()
        return self.Environment
    end

    function PACKAGE:GetLogger()
        return self.Logger
    end

    function PACKAGE:GetResult()
        return self.Result
    end

end

function Run( gPackage, func )
    debug_setfenv( func, gPackage:GetEnvironment() )
    return func()
end

function SafeRun( gPackage, func, errorHandler )
    return xpcall( Run, errorHandler, gPackage, func )
end

local function FindFilePathInFiles( fileName, files )
    if not isstring( fileName ) or not istable( files ) then return end

    local currentDir = string.GetPathFromFilename( gpm.path.Localize( gpm.utils.GetCurrentFile() ) )
    if isstring( currentDir ) then
        local path = string.gsub( currentDir .. "/" .. fileName, "//", "/" )
        if files[ path ] then return path end
    end

    return files[ fileName ] and fileName
end

function InitializePackage( metadata, func, files, env )
    local startTime = SysTime()

    -- Creating environment for package
    local packageEnv = environment.Create( func, env )

    -- Creating package object
    local gPackage = setmetatable( {}, PACKAGE )
    gPackage.Environment = packageEnv
    gPackage.Info = metadata
    gPackage.Files = files

    print( gPackage:GetIdentifier() )

    gPackage.Logger = gpm.logger.Create( gPackage:GetIdentifier(), metadata.color )

    -- Binding package object to gpm.Package
    environment.SetLinkedTable( packageEnv, "gpm", gpm )
    environment.Set( packageEnv, "gpm.Package", gPackage )
    environment.Set( packageEnv, "gpm.Logger", gPackage:GetLogger() )

    -- Include
    environment.SetFunction( packageEnv, "include", function( fileName )
        local path = FindFilePathInFiles( fileName, files )

        if path and files[ path ] then
            return gpm.packages.Run( gpm.Package, files[ path ] )
        end

        ErrorNoHaltWithStack( "Couldn't include file '" .. tostring( fileName ) .. "' - File not found" )
    end )

    -- AddCSLuaFile
    if (SERVER) then
        environment.SetFunction( packageEnv, "AddCSLuaFile", function( fileName )
            local path = FindFilePathInFiles( fileName, files )
            if path then
                return AddCSLuaFile( path )
            end

            ErrorNoHaltWithStack( "Couldn't include file '" .. tostring( fileName ) .. "' - File not found" )
        end )
    end

    -- Run
    local ok, result = SafeRun( gPackage, func, function( str )
        gPackage.Logger:Error( str )
    end )

    if not ok then
        gpm.Logger:Warn( "Package `%s` failed to load, see above for the reason, it took %.4f seconds.", gPackage, SysTime() - startTime )
        return
    end

    -- Saving result to gPackage
    gPackage.Result = result

    -- Saving in global table & final log
    gpm.Logger:Info( "Package `%s` was successfully loaded, it took %.4f seconds.", gPackage, SysTime() - startTime )

    local packageName = gPackage:GetName()
    packages[ packageName ] = packages[ packageName ] or {}
    packages[ packageName ][ gPackage:GetVersion() ] = gPackage

    return result
end
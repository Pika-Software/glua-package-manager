local environment = gpm.environment
local timer = timer
local hook = hook
local net = net
local AddCSLuaFile = AddCSLuaFile
local debug_setfenv = debug.setfenv

gpm.Packages = gpm.Packages or {}

module( "gpm.package", package.seeall )

function ParseTable(tbl)
    if not istable(tbl) then return end

    local info = {}
    info.name = isstring(tbl.name) and tbl.name or "no name"
    info.version = isstring(tbl.version) and tbl.version or "0.0.1"
    info.main = isstring(tbl.main) and tbl.main or nil

    return info
end

function ParseTableFromFunc(func)
    if isfunction(func) then
        local ok, data = pcall(func)
        return ok and ParseTable(data)
    end
end

-- Get one existing package
function Get( packageName )
    return gpm.Packages[ packageName ]
end

-- Get all existing packages
function GetAll()
    return gpm.Packages
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

    function PACKAGE:GetIdentifier(name)
        local identifier = ("%s@%s"):format( self:GetName(), self:GetVersion() )
        if name then
            if isstring(name) then return identifier .. "::" .. name end
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

local function FindFilePathInFiles(fileName, files)
    if not isstring(fileName) or not istable(files) then return end

    local currentDir = string.GetPathFromFilename( gpm.path.Localize( gpm.utils.GetCurrentFile() ) )

    if isstring(currentDir) then
        local path = string.gsub(currentDir .. "/" .. fileName, "//", "/")
        if files[path] then return path end
    end

    return files[fileName] and fileName
end

function SetupHookLibrary(packageEnv)
    local hook = hook
    environment.SetLinkedTable( packageEnv, "hook", hook )

    local hooks = {}
    environment.SetFunction( packageEnv, "hook.GetTable", function()
        return hooks
    end )

    environment.SetFunction( packageEnv, "hook.Add", function( eventName, identifier, value, ... )
        hook.Add( eventName, gpm.Package:GetIdentifier(identifier), value, ... )

        if (hooks[ eventName ] == nil) then hooks[ eventName ] = {} end
        hooks[ eventName ][ identifier ] = value
    end )

    environment.SetFunction( packageEnv, "hook.Remove", function( eventName, identifier, ... )
        if hooks[eventName] and hooks[eventName][identifier] then
            identifier = gpm.Package:GetIdentifier(identifier)
        end

        hook.Remove( eventName, identifier, ... )

        if hooks[eventName] then
            hooks[eventName][identifier] = nil
        end
    end )

    environment.Set( packageEnv, "hook.GetGlobalTable", hook.GetTable )
end

function SetupNetworkLibrary(packageEnv)
    local util = util
    local net = net
    environment.SetLinkedTable( packageEnv, "net", net )
    environment.SetLinkedTable( packageEnv, "util", util )

    local networkStrings = {}

    if SERVER then
        environment.SetFunction( packageEnv, "util.AddNetworkString", function( str, ... )
            local name = gpm.Package:GetIdentifier(str)
            networkStrings[str] = name
            return util.AddNetworkString( name, ... )
        end )
    end

    environment.SetFunction( packageEnv, "Receive", function( messageName, ... )
        local name = gpm.Package:GetIdentifier(messageName)
        networkStrings[messageName] = name
        return net.Receive( name, ... )
    end )

    environment.SetFunction( packageEnv, "net.Start", function( messageName, ... )
        return net.Start( networkStrings[messageName] or messageName, ... )
    end )
end

function SetupNetworkLibrary(packageEnv)
    local timer = timer
    environment.SetLinkedTable( packageEnv, "timer", timer )

    -- Adjust
    environment.SetFunction( packageEnv, "timer.Adjust", function( identifier, ... )
        return timer.Adjust( self.Package:GetIdentifier( identifier ), ... )
    end )

    -- Create
    environment.SetFunction( packageEnv, "timer.Create", function( identifier, ... )
        return timer.Create( self.Package:GetIdentifier( identifier ), ... )
    end )

    -- Exists
    environment.SetFunction( packageEnv, "timer.Exists", function( identifier, ... )
        return timer.Exists( self.Package:GetIdentifier( identifier ), ... )
    end )

    -- Pause
    environment.SetFunction( packageEnv, "timer.Pause", function( identifier, ... )
        return timer.Pause( self.Package:GetIdentifier( identifier ), ... )
    end )

    environment.SetFunction( packageEnv, "timer.UnPause", function( identifier, ... )
        return timer.UnPause( self.Package:GetIdentifier( identifier ), ... )
    end )

    -- Remove
    local timerRemove = function( identifier, ... )
        return timer.Remove( self.Package:GetIdentifier( identifier ), ... )
    end

    environment.SetFunction( packageEnv, "timer.Remove", timerRemove )
    environment.SetFunction( packageEnv, "timer.Destroy", timerRemove )

    -- TimeLeft & RepsLeft
    environment.SetFunction( packageEnv, "timer.TimeLeft", function( identifier, ... )
        return timer.TimeLeft( self.Package:GetIdentifier( identifier ), ... )
    end )

    environment.SetFunction( packageEnv, "timer.RepsLeft", function( identifier, ... )
        return timer.RepsLeft( self.Package:GetIdentifier( identifier ), ... )
    end )

    -- Start, Stop & Toggle
    environment.SetFunction( packageEnv, "timer.Start", function( identifier, ... )
        return timer.Start( self.Package:GetIdentifier( identifier ), ... )
    end )

    environment.SetFunction( packageEnv, "timer.Stop", function( identifier, ... )
        return timer.Stop( self.Package:GetIdentifier( identifier ), ... )
    end )

    environment.SetFunction( packageEnv, "timer.Toggle", function( identifier, ... )
        return timer.Toggle( self.Package:GetIdentifier( identifier ), ... )
    end )
end

function Run(package, func)
    debug_setfenv(func, package:GetEnvironment())
    return func()
end

function SafeRun(package, func, errorHandler)
    return xpcall(Run, errorHandler, package, func)
end

function InitializePackage( packageInfo, func, files, env )
    local startTime = SysTime()

    -- Creating environment for package
    local packageEnv = environment.Create( func, env )

    -- Creating package object
    local packageObject = setmetatable( {}, PACKAGE )
    packageObject.Info = packageInfo
    packageObject.Environment = packageEnv
    packageObject.Logger = gpm.logger.Create( packageObject:GetIdentifier(), packageInfo.color )

    -- Binding package object to gpm.Package
    environment.SetLinkedTable( packageEnv, "gpm", gpm )
    environment.Set( packageEnv, "gpm.Package", packageObject )
    environment.Set( packageEnv, "gpm.Logger", packageObject:GetLogger() )

    -- Setting up libraries
    SetupHookLibrary( packageEnv )
    SetupNetworkLibrary( packageEnv )
    SetupNetworkLibrary( packageEnv )

    -- Include
    environment.SetFunction( packageEnv, "include", function( fileName )
        local path = FindFilePathInFiles(fileName, files)

        if path and files[path] then
            return gpm.package.Run( gpm.Package, files[path] )
        end

        ErrorNoHaltWithStack( "Couldn't include file '" .. tostring(fileName) .. "' - File not found" )
    end )

    -- AddCSLuaFile
    if (SERVER) then
        environment.SetFunction( packageEnv, "AddCSLuaFile", function( fileName )
            local path = FindFilePathInFiles( fileName, files )
            if path then
                return AddCSLuaFile( path )
            end

            ErrorNoHaltWithStack( "Couldn't include file '" .. tostring(fileName) .. "' - File not found" )
        end)
    end

    -- Run
    local ok, result = SafeRun( packageObject, func, function(str)
        packageObject.Logger:Error( str )
    end )

    if not ok then
        gpm.Logger:Warn( "Package `%s` failed to load, see above for the reason, it took %.4f seconds.", packageObject, SysTime() - startTime )
        return
    end

    -- Saving result to packageObject
    packageObject.Result = result

    -- Saving in global table & final log
    gpm.Logger:Info( "Package `%s` was successfully loaded, it took %.4f seconds.", packageObject, SysTime() - startTime )
    if not gpm.Packages[ packageObject:GetName() ] then gpm.Packages[ packageObject:GetName() ] = {} end
    gpm.Packages[ packageObject:GetName() ][ packageObject:GetVersion() ] = packageObject

    return result
end

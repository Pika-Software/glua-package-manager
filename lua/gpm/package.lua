local gpm = gpm

-- Libraries
local environment = gpm.environment
local concommand = concommand
local properties = properties
local promise = promise
local paths = gpm.paths
local utils = gpm.utils
local string = string
local table = table
local cvars = cvars
local timer = timer
local fs = gpm.fs
local util = util
local hook = hook
local net = net

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local CLIENT, SERVER = CLIENT, SERVER
local AddCSLuaFile = AddCSLuaFile
local getmetatable = getmetatable
local setmetatable = setmetatable
local hook_Run = hook.Run
local logger = gpm.Logger
local require = require
local SysTime = SysTime
local setfenv = setfenv
local rawset = rawset
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

            -- Isolation features
            source.concommands = source.concommands ~= false and source.isolation
            source.properties = source.properties ~= false and source.isolation
            source.timers = source.timers ~= false and source.isolation
            source.hooks = source.hooks ~= false and source.isolation
            source.cvars = source.cvars ~= false and source.isolation
            source.net = source.net == true and source.isolation

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
        return self.Metadata
    end

    function PACKAGE:GetImportPath()
        return table.Lookup( self, "Metadata.import_path" )
    end

    function PACKAGE:GetFolder()
        return table.Lookup( self, "Metadata.folder" )
    end

    function PACKAGE:GetName()
        return table.Lookup( self, "Metadata.name", self:GetImportPath() or "unknown" )
    end

    function PACKAGE:GetVersion()
        return table.Lookup( self, "Metadata.version", "unknown" )
    end

    function PACKAGE:GetIdentifier( name )
        local identifier = string.format( "%s@%s", self:GetName(), self:GetVersion() )
        if type( name ) ~= "string" then return identifier end
        return identifier .. "::" .. name
    end

    function PACKAGE:GetSourceName()
        return table.Lookup( self, "Metadata.source", "unknown" )
    end

    PACKAGE.__tostring = PACKAGE.GetIdentifier

    function PACKAGE:GetEnvironment()
        return self.Environment
    end

    function PACKAGE:GetLogger()
        return self.Logger
    end

    function PACKAGE:GetResult()
        return self.Result
    end

    function PACKAGE:GetFiles()
        return self.Files
    end

    function PACKAGE:GetFileList()
        local fileList = {}
        for filePath in pairs( self.Files ) do
            fileList[ #fileList + 1 ] = filePath
        end

        return fileList
    end

    function PACKAGE:IsIsolated()
        return table.Lookup( self, "Metadata.isolation" )
    end

    function PACKAGE:HasEnvironment()
        return type( self:GetEnvironment() ) == "table"
    end

    function PACKAGE:GetChildren()
        return self.Children
    end

    function PACKAGE:AddChild( child )
        table.insert( self.Children, 1, child )
    end

    function PACKAGE:RemoveChild( child )
        local children = self.Children
        for index, pkg in ipairs( children ) do
            if pkg ~= child then continue end
            return table.remove( children, index )
        end
    end

    function PACKAGE:Link( package2 )
        gpm.ArgAssert( package2, 1, "Package" )

        local environment1 = self:GetEnvironment()
        if not environment1 then return false end

        local environment2 = package2:GetEnvironment()
        if not environment2 then return false end

        environment.Link( environment1, environment2 )
        self:RemoveChild( child )
        self:AddChild( child )

        logger:Debug( "'%s' ---> '%s'", package2:GetIdentifier(), self:GetIdentifier() )
        return true
    end

    function PACKAGE:UnLink( package2 )
        gpm.ArgAssert( package2, 1, "Package" )

        local environment1 = self:GetEnvironment()
        if not environment1 then return false end

        local environment2 = package2:GetEnvironment()
        if not environment2 then return false end

        environment.UnLink( environment1, environment2 )
        self:RemoveChild( child )

        logger:Debug( "'%s' -/-> '%s'", package2:GetIdentifier(), self:GetIdentifier() )
        return true
    end

    PACKAGE.Install = promise.Async( function( self )
        local func = self.Main
        if not func then
            return promise.Reject( "Missing package '" .. self:GetIdentifier() ..  "' entry point." )
        end

        local stopwatch = SysTime()

        local env = self:GetEnvironment()
        if env ~= nil then
            setfenv( func, env )
        end

        local ok, result = pcall( func, self )
        if not ok then
            return promise.Reject( result )
        end

        self.Result = result

        local ok, err = pcall( hook_Run, "PackageInstalled", self )
        if not ok then
            ErrorNoHaltWithStack( err )
        end

        gpm.Packages[ self:GetImportPath() ] = self
        self.Installed = true

        logger:Info( "Package '%s' was successfully installed, took %.4f seconds.", self:GetIdentifier(), SysTime() - stopwatch )

        return result
    end )

    function PACKAGE:IsInstalled()
        return self.Installed
    end

    function PACKAGE:UnInstall( noDependencies )
        local stopwatch = SysTime()

        local ok, err = pcall( hook_Run, "PackageRemoved", self )
        if not ok then
            ErrorNoHaltWithStack( err )
        end

        local env = self:GetEnvironment()
        if type( env ) == "table" then
            for _, pkg in ipairs( self.Children ) do
                if noDependencies then
                    logger:Error( "Package '%s' uninstallation failed, dependencies found, try use -f to force uninstallation, took %.4f seconds.", self:GetIdentifier(), SysTime() - stopwatch )
                    return
                end

                if pkg:IsInstalled() then
                    pkg:UnInstall()
                    pkg:UnLink( self )
                end
            end

            local metadata, internal = self.Metadata, self.Internal

            -- Hooks
            if metadata.hooks then
                for eventName, data in pairs( internal.Hooks ) do
                    for identifier in pairs( data ) do
                        hook.Remove( eventName, identifier )
                    end
                end
            end

            -- Timers
            if metadata.timers then
                for identifier in pairs( internal.Timers ) do
                    timer.Remove( identifier )
                end
            end

            -- Cvars
            if metadata.cvars then
                for name, cvar in pairs( internal.Cvars ) do
                    for identifier in pairs( cvar ) do
                        cvars.RemoveChangeCallback( name, identifier )
                    end
                end
            end

            -- ConCommands
            if metadata.concommands then
                for name in pairs( internal.ConCommands ) do
                    concommand.Remove( name )
                end
            end

            -- Properties
            if metadata.properties then
                for name in pairs( internal.Properties ) do
                    properties.List[ string.lower( name ) ] = nil
                end
            end

            -- Network strings
            if metadata.net then
                for messageName in pairs( internal.NetworkStrings ) do
                    net.Receivers[ messageName ] = nil
                end
            end
        end

        local importPath = self:GetImportPath()
        gpm.ImportTasks[ importPath ] = nil
        gpm.Packages[ importPath ] = nil
        self.Installed = nil

        logger:Info( "Package '%s' was successfully uninstalled, took %.4f seconds.", self:GetIdentifier(), SysTime() - stopwatch )
    end

    local function isPackage( any )
        return getmetatable( any ) == PACKAGE
    end

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

        if fileName and fs.IsFile( "lua/" .. fileName, "GAME" ) then
            filePath = paths.Fix( fileName )
        end

        if filePath and fs.IsFile( "lua/" .. filePath, "GAME" ) then
            return AddCSLuaFile( filePath )
        end

        error( "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found" )
    end

end

local addClientLuaFile = SERVER and AddClientLuaFile

local internalMeta = {
    ["__index"] = function( self, index )
        local value = {}
        rawset( self, index, value )
        return value
    end
}

local timerBlacklist = {
    ["Destroy"] = true,
    ["Remove"] = true,
    ["Simple"] = true
}

Initialize = promise.Async( function( metadata, func, files )
    if type( files ) ~= "table" then
        files = nil
    end

    -- Creating package object
    local pkg = setmetatable( {}, PACKAGE )
    pkg.Metadata = metadata
    pkg.Installed = false
    pkg.Files = files
    pkg.Main = func

    if metadata.isolation then

        pkg.Children = {}

        local hookList = setmetatable( {}, internalMeta )
        local cvarList = setmetatable( {}, internalMeta )
        local networkStrings = {}
        local concommandList = {}
        local propertiesList = {}
        local timers = {}

        pkg.Internal = {
            ["NetworkStrings"] = networkStrings,
            ["ConCommands"] = concommandList,
            ["Properties"] = propertiesList,
            ["Cvars"] = cvarList,
            ["Hooks"] = hookList,
            ["Timers"] = timers
        }

        -- Creating environment for package
        local env = environment.Create( _G )
        pkg.Environment = env

        -- Globals
        environment.SetLinkedTable( env, "gpm", gpm )
        env._VERSION = metadata.version
        env.ArgAssert = gpm.ArgAssert
        env.TypeID = gpm.TypeID
        env.type = gpm.type
        env.http = gpm.http
        env.file = fs

        -- Binding package object to gpm.Package & _PKG
        environment.SetValue( env, "gpm.Package", pkg )
        env._PKG = pkg

        -- Logger
        if metadata.logger then
            pkg.Logger = gpm.logger.Create( pkg:GetIdentifier(), metadata.color )
            table.SetValue( env, "gpm.Logger", pkg.Logger )
        end

        -- import
        env.import = function( importPath, async, pkg2 )
            if gpm.IsPackage( pkg2 ) then
                return gpm.Import( importPath, async, pkg2 )
            end

            return gpm.Import( importPath, async, pkg )
        end

        environment.SetValue( env, "gpm.Import", env.import )

        -- install
        env.install = function( ... )
            return gpm.Install( pkg, false, ... )
        end

        environment.SetValue( env, "gpm.Install", function( pkg2, async, ... )
            if gpm.IsPackage( pkg2 ) then
                return gpm.Install( pkg2, async, ... )
            end

            return gpm.Install( pkg, async, ... )
        end )

        -- require
        env.require = function( ... )
            local arguments = {...}
            local length = #arguments

            for number, name in ipairs( arguments ) do
                gpm.ArgAssert( name, number, "string" )

                if string.IsURL( name ) then
                    if not gpm.CanImport( name ) then continue end

                    local ok, result = gpm.AsyncImport( name, pkg, false ):SafeAwait()
                    if not ok then
                        if number ~= length then continue end
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

        -- Hooks
        if metadata.hooks then

            environment.SetLinkedTable( env, "hook", hook )

            environment.SetValue( env, "hook.Add", function( eventName, identifier, ... )
                if type( identifier ) == "string" then
                    identifier = pkg:GetIdentifier( identifier )
                end

                hookList[ eventName ][ identifier ] = true
                return hook.Add( eventName, identifier, ... )
            end )

            environment.SetValue( env, "hook.Remove", function( eventName, identifier, ... )
                if type( identifier ) == "string" then
                    identifier = pkg:GetIdentifier( identifier )
                end

                hookList[ eventName ][ identifier ] = nil
                return hook.Remove( eventName, identifier, ... )
            end )

        end

        -- Timers
        if metadata.timers then

            environment.SetLinkedTable( env, "timer", timer )

            for key, func in pairs( timer ) do
                if timerBlacklist[ key ] then continue end
                env.timer[ key ] = function( identifier, ... )
                    identifier = pkg:GetIdentifier( identifier )
                    timers[ identifier ] = true

                    return func( identifier, ... )
                end
            end

            local function removeFunction( identifier, ... )
                identifier = pkg:GetIdentifier( identifier )
                timers[ identifier ] = nil

                return timer.Remove( identifier, ... )
            end

            environment.SetValue( env, "timer.Destroy", removeFunction )
            environment.SetValue( env, "timer.Remove", removeFunction )

        end

        -- Cvars
        if metadata.cvars then

            environment.SetLinkedTable( env, "cvars", cvars )

            environment.SetValue( env, "cvars.AddChangeCallback", function( name, func, identifier, ... )
                identifier = pkg:GetIdentifier( type( identifier ) == "string" and identifier or "Default" )
                cvarList[ name ][ identifier ] = true

                return cvars.AddChangeCallback( name, func, identifier, ... )
            end )

            environment.SetValue( env, "cvars.RemoveChangeCallback", function( name, identifier, ... )
                identifier = pkg:GetIdentifier( type( identifier ) == "string" and identifier or "Default" )
                cvarList[ name ][ identifier ] = nil

                return cvars.RemoveChangeCallback( name, identifier, ... )
            end )

        end

        -- ConCommands
        if metadata.concommands then

            environment.SetLinkedTable( env, "concommand", concommand )

            environment.SetValue( env, "concommand.Add", function( name, ... )
                concommandList[ name ] = true
                return concommand.Add( name, ... )
            end )

            environment.SetValue( env, "concommand.Remove", function( name, ... )
                concommandList[ name ] = nil
                return concommand.Remove( name, ... )
            end )

        end

        -- Net
        if metadata.net then

            environment.SetLinkedTable( env, "net", net )

            environment.SetValue( env, "net.Receive", function( messageName, ... )
                messageName = pkg:GetIdentifier( messageName )
                networkStrings[ messageName ] = true

                return net.Receive( messageName, ... )
            end )

            environment.SetValue( env, "net.Start", function( messageName, ... )
                return net.Start( pkg:GetIdentifier( messageName ), ... )
            end )

            if SERVER then

                environment.SetLinkedTable( env, "util", util )

                environment.SetValue( env, "util.AddNetworkString", function( messageName, ... )
                    messageName = pkg:GetIdentifier( messageName )
                    networkStrings[ messageName ] = true

                    return util.AddNetworkString( messageName, ... )
                end )

            end

        end

        -- Properties
        if metadata.properties then

            environment.SetLinkedTable( env, "properties", properties )

            environment.SetValue( env, "properties.Add", function( name, ... )
                name = pkg:GetIdentifier( name )
                propertiesList[ name ] = true

                return properties.Add( name, ... )
            end )

        end

    end

    -- Installing
    pkg:Install():Await()

    return pkg
end )
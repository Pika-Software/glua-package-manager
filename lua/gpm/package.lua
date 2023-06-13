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
local debug = debug
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
local rawset = rawset
local ipairs = ipairs
local error = error
local pairs = pairs
local pcall = pcall
local type = type
local _G = _G

module( "gpm.package" )

-- Get package by name/pattern
function Find( searchable, ignoreImportNames, noPatterns )
    local result = {}
    for importPath, pkg in pairs( gpm.Packages ) do
        if not ignoreImportNames and importPath == searchable then
            result[ #result + 1 ] = pkg
            continue
        end

        local name = pkg:GetName()
        if not name then continue end
        if string.find( name, searchable, 1, noPatterns ) ~= nil then
            result[ #result + 1 ] = pkg
        end
    end

    return result
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

        if fileName and fs.IsFile( fileName, "LUA" ) then
            filePath = paths.Fix( fileName )
        end

        if filePath ~= nil then
            local extension = string.GetExtensionFromFilename( filePath )
            if extension == "moon" then
                filePath = string.sub( filePath, 1, #filePath - #extension ) .. "lua"
            end

            if fs.IsFile( filePath, "LUA" ) then
                return AddCSLuaFile( filePath )
            end
        end

        error( "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found" )
    end

end

do

    local environment = {
        ["__index"] = _G
    }

    function BuildMetadata( source )
        if type( source ) == "table" then
            utils.LowerTableKeys( source )

            -- Package name & entry point
            if type( source.name ) ~= "string" then
                source.name = nil
            end

            -- Menu
            source.menu = source.menu ~= false

            -- Main file
            if type( source.cl_main ) ~= "string" then
                source.cl_main = nil
            elseif CLIENT then
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
            source.environment = source.environment ~= false
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
            local autonames = source.autonames
            if type( autonames ) == "table" then
                autonames.properties = autonames.properties ~= false and source.environment
                autonames.timer = autonames.timer ~= false and source.environment
                autonames.cvars = autonames.cvars ~= false and source.environment
                autonames.hook = autonames.hook ~= false and source.environment
                autonames.net = autonames.net == true and source.environment
            else
                source.autonames = nil
            end

            return source
        elseif type( source ) == "function" then
            local metadata = {}

            setmetatable( metadata, environment )
                debug.setfenv( source, metadata )
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

            return BuildMetadata( result )
        end
    end

end

-- Package Meta
do

    PACKAGE = PACKAGE or {}
    PACKAGE.__index = PACKAGE

    function PACKAGE:GetMetadata()
        return self.Metadata
    end

    function PACKAGE:GetImportPath()
        return table.Lookup( self, "Metadata.importpath" )
    end

    function PACKAGE:GetMainFilePath()
        return table.Lookup( self, "Metadata.main" )
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

    function PACKAGE:HasAutoNames( libraryName )
        local autoNames = table.Lookup( self, "Metadata.autonames", false )
        if not autoNames then
            return autoNames
        end

        return autoNames[ libraryName ]
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

    function PACKAGE:IsInstalled()
        return self.Installed
    end

    function PACKAGE:HasEnvironment()
        return type( self:GetEnvironment() ) == "table"
    end

    -- Children
    function PACKAGE:GetChildren()
        return self.Children
    end

    function PACKAGE:AddChild( child )
        table.insert( self:GetChildren(), 1, child )
    end

    function PACKAGE:RemoveChild( child )
        local children = self:GetChildren()
        for index, pkg in ipairs( children ) do
            if pkg ~= child then continue end
            return table.remove( children, index )
        end
    end

    -- Package linking
    function PACKAGE:Link( package2 )
        gpm.ArgAssert( package2, 1, "Package" )

        local environment1 = self:GetEnvironment()
        if not environment1 then return false end

        local environment2 = package2:GetEnvironment()
        if not environment2 then return false end

        environment.Link( environment1, environment2 )
        package2:RemoveChild( self )
        package2:AddChild( self )

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
        package2:RemoveChild( self )

        logger:Debug( "'%s' -/-> '%s'", package2:GetIdentifier(), self:GetIdentifier() )
        return true
    end

    -- Environment
    do

        local internalMeta = {
            ["__index"] = function( self, index )
                local value = {}
                rawset( self, index, value )
                return value
            end
        }

        local addCSLuaFile = SERVER and AddClientLuaFile or debug.fempty

        function PACKAGE:EnvironmentInit( metadata )
            local env = self.Environment
            if type( env ) ~= "table" then
                env = environment.Create( _G )
                self.Environment = env

                env.AddCSLuaFile = addCSLuaFile
                env.ArgAssert = gpm.ArgAssert
                env.TypeID = gpm.TypeID
                env.http = gpm.http
                env.type = gpm.type
                env._PKG = self
                env.file = fs
            end

            env._VERSION = metadata.version

            local main = self.Main
            if type( main ) == "function" then
                debug.setfenv( main, env )
            end

            local files = self.Files
            for _, func in pairs( files ) do
                debug.setfenv( func, env )
            end

            -- GPM link
            local _gpm = environment.SetLinkedTable( env, "gpm", gpm )
            _gpm.Package = self

            -- Logger
            if metadata.logger then
                local logger = gpm.logger.Create( self:GetIdentifier(), metadata.color )
                _gpm.Logger = logger
                self.Logger = logger
            end

            -- import
            do

                local function import( importPath, async, pkg2 )
                    if gpm.IsPackage( pkg2 ) then
                        return gpm.Import( importPath, async, pkg2 )
                    end

                    return gpm.Import( importPath, async, self )
                end

                _gpm.Import = import
                env.import = import

            end

            -- install
            env.install = function( ... )
                return gpm.Install( self, false, ... )
            end

            _gpm.Install = function( pkg2, async, ... )
                if gpm.IsPackage( pkg2 ) then
                    return gpm.Install( pkg2, async, ... )
                end

                return gpm.Install( self, async, ... )
            end

            -- include
            env.include = function( fileName )
                gpm.ArgAssert( fileName, 1, "string" )

                local func = files[ paths.Fix( fileName ) ]
                if type( func ) == "function" then
                    return func( self )
                end

                local luaPath = getCurrentLuaPath()
                if luaPath then
                    local folder = string.GetPathFromFilename( luaPath )
                    if folder and #folder > 0 then
                        local filePath = paths.Fix( folder .. fileName )
                        if fs.IsFile( filePath, "LUA" ) then
                            local ok, result = gpm.Compile( filePath ):SafeAwait()
                            if not ok then
                                error( result )
                            end

                            files[ fileName ] = debug.setfenv( result, env )
                            return result( self )
                        end
                    end
                end

                local filePath = paths.Fix( fileName )
                if fs.IsFile( filePath, "LUA" ) then
                    local ok, result = gpm.Compile( filePath ):SafeAwait()
                    if not ok then
                        error( result )
                    end

                    files[ fileName ] = debug.setfenv( result, env )
                    return result( self )
                end

                error( "Couldn't include file '" .. fileName .. "' - File not found" )
            end

            -- require
            env.require = function( ... )
                local arguments = {...}
                local lenght = #arguments

                for number, name in ipairs( arguments ) do
                    gpm.ArgAssert( name, number, "string" )

                    if string.IsURL( name ) then
                        if not gpm.CanImport( name ) then continue end

                        local ok, result = gpm.AsyncImport( name, self, false ):SafeAwait()
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
                        local ok, result = gpm.SourceImport( "lua", "includes/modules/" .. name .. ".lua" ):SafeAwait()
                        if not ok then
                            error( result )
                        end

                        self:Link( result )
                        return result:GetResult()
                    end
                end

                error( "Not one of the listed packages could be required." )
            end

            local callbacks = self.Callbacks
            if not callbacks then
                callbacks = {}; self.Callbacks = callbacks
            end

            -- Hooks
            do

                local data = setmetatable( {}, internalMeta )
                local autoNames = self:HasAutoNames( "hook" )
                callbacks.hook = data

                local obj, metatable = environment.SetLinkedTable( env, "hook", hook )

                function obj.Add( eventName, identifier, ... )
                    if autoNames and type( identifier ) == "string" then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ eventName ][ identifier ] = true
                    return hook.Add( eventName, identifier, ... )
                end

                function obj.Remove( eventName, identifier, ... )
                    if autoNames and type( identifier ) == "string" then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ eventName ][ identifier ] = nil
                    return hook.Remove( eventName, identifier, ... )
                end

                metatable.__newindex = hook

            end

            -- Timers
            do

                local data = {}
                callbacks.timer = data
                local autoNames = self:HasAutoNames( "timer" )

                local obj, metatable = environment.SetLinkedTable( env, "timer", timer )

                for key, func in pairs( timer ) do
                    if key == "Destroy" or key == "Remove" or key == "Simple" then continue end
                    obj[ key ] = function( identifier, ... )
                        if autoNames then
                            identifier = self:GetIdentifier( identifier )
                        end

                        data[ identifier ] = true
                        return func( identifier, ... )
                    end
                end

                local function removeFunction( identifier, ... )
                    if autoNames then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ identifier ] = nil
                    return timer.Remove( identifier, ... )
                end

                obj.Destroy = removeFunction
                obj.Remove = removeFunction

                metatable.__newindex = timer

            end

            -- ConVars
            do

                local data = setmetatable( {}, internalMeta )
                local autoNames = self:HasAutoNames( "cvars" )
                callbacks.cvars = data

                local obj, metatable = environment.SetLinkedTable( env, "cvars", cvars )

                function obj.AddChangeCallback( name, func, identifier, ... )
                    if type( identifier ) ~= "string" then
                        identifier = "Default"
                    end

                    if autoNames then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ name ][ identifier ] = true
                    return cvars.AddChangeCallback( name, func, identifier, ... )
                end

                function obj.RemoveChangeCallback( name, identifier, ... )
                    if type( identifier ) ~= "string" then
                        identifier = "Default"
                    end

                    if autoNames then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ name ][ identifier ] = nil
                    return cvars.RemoveChangeCallback( name, identifier, ... )
                end

                metatable.__newindex = cvars

            end

            -- ConCommands
            do

                local data = {}
                callbacks.concommand = data

                local obj, metatable = environment.SetLinkedTable( env, "concommand", concommand )

                function obj.Add( name, ... )
                    data[ name ] = true
                    return concommand.Add( name, ... )
                end

                function obj.Remove( name, ... )
                    data[ name ] = nil
                    return concommand.Remove( name, ... )
                end

                metatable.__newindex = concommand

            end

            -- Net
            do

                local data = {}
                callbacks.net = data
                local autoNames = self:HasAutoNames( "net" )

                do

                    local obj, metatable = environment.SetLinkedTable( env, "net", net )

                    function obj.Receive( messageName, ... )
                        if autoNames then
                            messageName = self:GetIdentifier( messageName )
                        end

                        data[ messageName ] = true
                        return net.Receive( messageName, ... )
                    end

                    if autoNames then
                        function obj.Start( messageName, ... )
                            return net.Start( self:GetIdentifier( messageName ), ... )
                        end
                    end

                    metatable.__newindex = net

                end

                if SERVER then

                    local obj, metatable = environment.SetLinkedTable( env, "util", util )

                    function obj.AddNetworkString( messageName, ... )
                        if autoNames then
                            messageName = self:GetIdentifier( messageName )
                        end

                        data[ messageName ] = true
                        return util.AddNetworkString( messageName, ... )
                    end

                    metatable.__newindex = util

                end

            end

            -- Properties
            do

                local data = {}
                callbacks.properties = data
                local autoNames = self:HasAutoNames( "properties" )

                local obj, metatable = environment.SetLinkedTable( env, "properties", properties )

                function obj.Add( name, ... )
                    if autoNames then
                        name = self:GetIdentifier( name )
                    end

                    data[ string.lower( name ) ] = true
                    return properties.Add( name, ... )
                end

                metatable.__newindex = properties

            end

            return env
        end

    end

    function PACKAGE:ClearCallbacks()
        local callbacks = self.Callbacks
        if type( callbacks ) ~= "table" then return end

        -- Hooks
        local library = callbacks.hook
        if type( library ) == "table" then
            for eventName, data in pairs( library ) do
                for identifier in pairs( data ) do
                    hook.Remove( eventName, identifier )
                    library[ eventName ][ identifier ] = nil
                end

                library[ eventName ] = nil
            end
        end

        -- Timers
        library = callbacks.timer
        if type( library ) == "table" then
            for identifier in pairs( library ) do
                timer.Remove( identifier )
                library[ identifier ] = nil
            end
        end

        -- ConVars
        library = callbacks.cvars
        if type( library ) == "table" then
            for name, cvar in pairs( library ) do
                for identifier in pairs( cvar ) do
                    cvars.RemoveChangeCallback( name, identifier )
                    library[ name ][ identifier ] = nil
                end

                library[ name ] = nil
            end
        end

        -- ConCommands
        library = callbacks.concommand
        if type( library ) == "table" then
            for name in pairs( library ) do
                concommand.Remove( name )
                library[ name ] = nil
            end
        end

        -- Properties
        library = callbacks.properties
        if type( library ) == "table" then
            for name in pairs( library ) do
                properties.List[ name ] = nil
                library[ name ] = nil
            end
        end

        -- Network strings
        library = callbacks.net
        if type( library ) == "table" then
            for messageName in pairs( library ) do
                net.Receivers[ messageName ] = nil
                library[ messageName ] = nil
            end
        end

        local main = self.Main
        if main then
            debug.setfenv( main, _G )
        end

        local files = self.Files
        if files then
            for _, func in pairs( files ) do
                debug.setfenv( func, _G )
            end
        end
    end

    -- Initialize
    PACKAGE.Initialize = promise.Async( function( self, nMetadata, nFiles )
        local metadata = self.Metadata
        if type( nMetadata ) == "table" then
            table.Empty( metadata )
            for key, value in pairs( nMetadata ) do
                metadata[ key ] = value
            end
        end

        if type( nFiles ) == "table" then
            local files = self.Files
            table.Empty( files )
            for key, value in pairs( nFiles ) do
                files[ key ] = value
            end
        end

        self:ClearCallbacks()

        if metadata.environment then
            return self:EnvironmentInit( metadata )
        end

        self.Environment = nil
        self.Callbacks = nil
    end )

    -- Install/Uninstall/Reload
    PACKAGE.Install = promise.Async( function( self )
        local stopwatch = SysTime()

        local main = self.Main
        if not main then
            return promise.Reject( "Missing package '" .. self:GetIdentifier() ..  "' entry point." )
        end

        local ok, result = pcall( main, self )
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

    function PACKAGE:Uninstall()
        local stopwatch = SysTime()

        local ok, err = pcall( hook_Run, "PackageRemoved", self )
        if not ok then
            ErrorNoHaltWithStack( err )
        end

        for index, pkg in ipairs( self.Children ) do
            self.Children[ index ] = nil
            pkg:UnLink( self )
            pkg:Uninstall()
        end

        if self:HasEnvironment() then
            self:ClearCallbacks()
        end

        gpm.Packages[ self:GetImportPath() ] = nil
        self.Installed = nil

        logger:Info( "Package '%s' was successfully uninstalled, took %.4f seconds.", self:GetIdentifier(), SysTime() - stopwatch )
    end

    PACKAGE.Reload = promise.Async( function( self, dontSendToClients )
        local stopwatch = SysTime()

        if self:HasEnvironment() then
            self:ClearCallbacks()
        end

        local sourceName = self:GetSourceName()
        local source = gpm.sources[ sourceName ]
        if not source then
            return promise.Reject( "Package source '" .. sourceName .. "' not found, package data is probably corrupted." )
        end

        local importPath = self:GetImportPath()
        local getMetadata, metadata = source.GetMetadata, nil
        if getMetadata then
            local ok, result = getMetadata( importPath ):SafeAwait()
            if not ok then
                return promise.Reject( result )
            end

            metadata = result
        end

        if metadata ~= nil then
            if type( metadata.name ) ~= "string" then
                metadata.name = importPath
            end

            metadata.importpath = importPath
            metadata.source = sourceName
            BuildMetadata( metadata )
        end

        if SERVER then
            local sendToClient = source.SendToClient
            if sendToClient ~= nil then
                source.SendToClient( metadata )
            end
        end

        local compileMain = source.CompileMain
        if compileMain then
            local ok, result = compileMain( self:GetMainFilePath() ):SafeAwait()
            if not ok then
                return promise.Reject( result )
            end

            self.Main = result
        end

        local ok, result = self:Initialize( metadata ):SafeAwait()
        if not ok then
            return promise.Reject( result )
        end

        local main = self.Main
        if not main then
            return promise.Reject( "Missing package '" .. self:GetIdentifier() ..  "' entry point." )
        end

        local ok, result = pcall( main, self )
        if not ok then
            return promise.Reject( result )
        end

        self.Result = result

        local ok, err = pcall( hook_Run, "PackageReloaded", self )
        if not ok then
            ErrorNoHaltWithStack( err )
        end

        if SERVER and not dontSendToClients then
            net.Start( "GPM.Networking" )
                net.WriteUInt( 5, 3 )
                net.WriteString( importPath )
            net.Broadcast()
        end

        logger:Info( "Package '%s' was successfully reloaded, took %.4f seconds.", self:GetIdentifier(), SysTime() - stopwatch )
        return result
    end )

    local function isPackage( any )
        return getmetatable( any ) == PACKAGE
    end

    gpm.IsPackage = isPackage
    _G.TYPE_PACKAGE = gpm.AddType( "Package", isPackage )

end

Initialize = promise.Async( function( metadata, func, files )
    local pkg = setmetatable( {
        ["Installed"] = false,
        ["Metadata"] = {},
        ["Children"] = {},
        ["Files"] = {},
        ["Main"] = func
    }, PACKAGE )

    local ok, result = pkg:Initialize( metadata, files ):SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    local ok, result = pkg:Install():SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    return pkg
end )
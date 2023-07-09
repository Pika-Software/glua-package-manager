local gpm = gpm

-- Libraries
local metaworks = gpm.metaworks
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
local CLIENT, SERVER, MENU_DLL = CLIENT, SERVER, MENU_DLL
local addCSLuaFile = AddCSLuaFile
local getmetatable = getmetatable
local setmetatable = setmetatable
local ArgAssert = gpm.ArgAssert
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

if SERVER then

    function AddCSLuaFile( fileName )
        local luaPath = utils.GetCurrentFilePath()
        if not fileName and luaPath and fs.IsFile( luaPath, "LUA" ) then
            return addCSLuaFile( luaPath )
        end

        ArgAssert( fileName, 1, "string" )
        fileName = paths.FormatToLua( paths.Fix( fileName ) )

        if luaPath then
            local folder = string.GetPathFromFilename( luaPath )
            if folder then
                local filePath = folder .. fileName
                if fs.IsLuaFile( filePath, "LUA", true ) then
                    return addCSLuaFile( filePath )
                end
            end
        end

        if fs.IsLuaFile( fileName, "LUA", true ) then
            return addCSLuaFile( fileName )
        end

        error( "Couldn't AddCSLuaFile file '" .. fileName .. "' - File not found" )
    end

end

function FormatInit( init )
    local initType = type( init )
    if initType == "table" then
        utils.LowerTableKeys( init )

        local server = init.server
        if type( server ) ~= "string" or #server == 0 then
            init.server = nil
        end

        local client = init.client
        if type( client ) ~= "string" or #client == 0 then
            init.client = nil
        end

        local menu = init.menu
        if type( menu ) ~= "string" or #menu == 0 then
            init.menu = nil
        end

        return init
    elseif initType == "string" then
        return {
            ["server"] = init,
            ["client"] = init,
            ["menu"] = init
        }
    end

    return {
        ["server"] = "init.lua",
        ["client"] = "init.lua",
        ["menu"] = "init.lua"
    }
end

function GetCurrentInitByRealm( init )
    if SERVER then
        return init.server
    elseif CLIENT then
        return init.client
    elseif MENU_DLL then
        return init.menu
    end
end

function FormatMetadata( metadata )
    utils.LowerTableKeys( metadata )

    if type( metadata.name ) ~= "string" then
        local importPath = metadata.importpath
        if type( importPath ) then
            metadata.name = importPath
        else
            metadata.name = nil
        end
    end

    metadata.init = FormatInit( metadata.init )
    metadata.version = utils.Version( metadata.version )

    local hasEnvironment = metadata.environment ~= false
    metadata.environment = hasEnvironment
    metadata.autorun = metadata.autorun == true

    -- Files to send to the client ( package and init will already be added and there is no need to specify them here )
    if type( metadata.send ) ~= "table" then
        metadata.send = nil
    end

    -- Logger and logs color
    metadata.logger = metadata.logger ~= false

    if gpm.type( metadata.color ) ~= "Color" then
        metadata.color = nil
    end

    -- Single-player restriction
    metadata.singleplayer = metadata.singleplayer == true

    -- Allowed gamemodes
    local gamemodesType = type( metadata.gamemodes )
    if gamemodesType ~= "string" and gamemodesType ~= "table" then
        metadata.gamemodes = nil
    end

    -- Allowed maps
    local mapsType = type( metadata.maps )
    if mapsType ~= "string" and mapsType ~= "table" then
        metadata.maps = nil
    end

    -- Libs autonames feature
    local autonames = metadata.autonames
    if type( autonames ) == "table" then
        autonames.properties = autonames.properties ~= false and hasEnvironment
        autonames.timer = autonames.timer ~= false and hasEnvironment
        autonames.cvars = autonames.cvars ~= false and hasEnvironment
        autonames.hook = autonames.hook ~= false and hasEnvironment
        autonames.net = autonames.net == true and hasEnvironment
    else
        metadata.autonames = {
            ["properties"] = hasEnvironment,
            ["timer"] = hasEnvironment,
            ["cvars"] = hasEnvironment,
            ["hook"] = hasEnvironment,
            ["net"] = false
        }
    end

    local defaults = metadata.defaults
    if type( defaults ) == "table" then
        defaults.typeid = autonames.typeid ~= false and hasEnvironment
        defaults.http = autonames.http ~= false and hasEnvironment
        defaults.type = autonames.type ~= false and hasEnvironment
        defaults.file = autonames.file ~= false and hasEnvironment
    else
        metadata.defaults = {
            ["typeid"] = hasEnvironment,
            ["http"] = hasEnvironment,
            ["type"] = hasEnvironment,
            ["file"] = hasEnvironment
        }
    end

    return metadata
end

do

    local link = metaworks.CreateLink( _G, true, false )

    function ExtractMetadata( func )
        local environment = {}
        debug.setmetatable( environment, link )
        debug.setfenv( func, environment )

        local metadata = func()
        if type( metadata ) ~= "table" then
            debug.setmetatable( environment, nil )
            metadata = environment
        end

        local PACKAGE = metadata.package
        if type( PACKAGE ) == "table" then
            metadata = PACKAGE
        end

        return metadata
    end

end

function Link( pkg, target )
    if not pkg or not target then return end
    ArgAssert( pkg, 1, "Package" )

    if IsPackage( target ) then
        local ok, message = pcall( pkg.Link, pkg, target )
        if not ok then
            logger:Error( "Linking package '%s' to package '%s' failed, %s.", pkg:GetIdentifier(), target:GetIdentifier(), message )
        end

        return true
    end

    if promise.IsPromise( target ) then
        if target:IsPending() then
            target:Then( function( result )
                Link( pkg, result )
            end )
        elseif target:IsFulfilled() then
            Link( pkg, target:GetResult() )
        end

        return true
    end

    if type( target ) == "table" then
        for _, subTarget in ipairs( target ) do
            Link( pkg, subTarget )
        end

        return true
    end

    return false
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
        return table.Lookup( self, "Metadata.sourcename", "unknown" )
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
        return type( self.Environment ) == "table"
    end

    -- Children
    function PACKAGE:GetChildren()
        return self.Children
    end

    function PACKAGE:AddChild( child )
        table.insert( self:GetChildren(), 1, child )
    end

    function PACKAGE:RemoveChild( child )
        return table.RemoveByIValue( self:GetChildren(), child )
    end

    -- Package linking
    function PACKAGE:Link( package2 )
        ArgAssert( package2, 1, "Package" )

        local environment1 = self:GetEnvironment()
        if not environment1 then
            error( "primary package environment is missing" )
        end

        local environment2 = package2:GetEnvironment()
        if not environment2 then
            error( "second package environment is missing" )
        end

        metaworks.Link( environment1, environment2 )
        package2:RemoveChild( self )
        package2:AddChild( self )

        logger:Debug( "'%s' ---> '%s'", package2:GetIdentifier(), self:GetIdentifier() )
        return true
    end

    function PACKAGE:UnLink( package2 )
        ArgAssert( package2, 1, "Package" )

        local environment1 = self:GetEnvironment()
        if not environment1 then
            error( "primary package environment is missing" )
        end

        local environment2 = package2:GetEnvironment()
        if not environment2 then
            error( "second package environment is missing" )
        end

        metaworks.UnLink( environment1, environment2 )
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

        local addCSLuaFile = SERVER and AddCSLuaFile or debug.fempty

        function PACKAGE:EnvironmentInit( metadata )
            local environment = self.Environment
            if type( environment ) ~= "table" then
                environment = metaworks.Create( _G )
                self.Environment = environment
                environment._PKG = self

                environment.AddCSLuaFile = addCSLuaFile
                environment.ArgAssert = ArgAssert
            end

            environment.TypeID = nil
            environment.http = nil
            environment.type = nil
            environment.file = nil

            local defaults = metadata.defaults
            if defaults then
                if defaults.typeid then environment.TypeID = gpm.TypeID end
                if defaults.http then environment.http = gpm.http end
                if defaults.type then environment.type = gpm.type end
                if defaults.file then environment.file = fs end
            end

            environment._VERSION = metadata.version

            local init = self.Init
            if init then
                debug.setfenv( init, environment )
            end

            local files = self.Files
            for _, func in pairs( files ) do
                debug.setfenv( func, environment )
            end

            -- GPM link

            local gpml = metaworks.CreateLink( gpm, true, false )
            environment.gpm = gpml
            gpml.Package = self

            -- Logger
            if metadata.logger then
                local logger = gpm.CreateLogger( self:GetIdentifier(), metadata.color )
                gpml.Logger = logger
                self.Logger = logger
            end

            -- import
            do

                local function import( importPath, async, pkg2 )
                    local task
                    if IsPackage( pkg2 ) then
                        task = gpm.Import( importPath, true, pkg2 )
                    else
                        task = gpm.Import( importPath, true, self )
                    end

                    if not async then
                        local result = task:Await()
                        if IsPackage( result ) then
                            return result:GetResult(), result
                        end

                        return result
                    end

                    return task
                end

                gpml.Import = import
                environment.import = import

            end

            -- install
            environment.install = function( ... )
                local result = gpm.Install( self, true, ... ):Await()
                if IsPackage( result ) then
                    return result:GetResult(), result
                end

                return result
            end

            gpml.Install = function( pkg2, async, ... )
                local task
                if IsPackage( pkg2 ) then
                    task = gpm.Install( pkg2, true, ... )
                else
                    task = gpm.Install( self, true, ... )
                end

                if not async then
                    local result = task:Await()
                    if IsPackage( result ) then
                        return result:GetResult(), result
                    end

                    return result
                end

                return task
            end

            -- include
            environment.include = function( fileName )
                ArgAssert( fileName, 1, "string" )
                fileName = paths.FormatToLua( paths.Fix( fileName ) )

                local func = files[ fileName ]
                if type( func ) == "function" then
                    return func( self )
                end

                local luaPath = utils.GetCurrentFilePath()
                if luaPath then
                    local folder = string.GetPathFromFilename( luaPath )
                    if folder then
                        local filePath = folder .. fileName
                        if fs.IsLuaFile( filePath, "LUA", true ) then
                            local func = debug.setfenv( gpm.CompileLua( filePath ), environment )
                            files[ fileName ] = func
                            return func( self )
                        end
                    end
                end

                if fs.IsLuaFile( fileName, "LUA", true ) then
                    local func = debug.setfenv( gpm.CompileLua( fileName ), environment )
                    files[ fileName ] = func
                    return func( self )
                end

                error( "Couldn't include file '" .. fileName .. "' - File not found" )
            end

            -- require
            environment.require = function( ... )
                local arguments = {...}
                local lenght = #arguments

                for index, name in ipairs( arguments ) do
                    ArgAssert( name, index, "string" )

                    if string.IsURL( name ) then
                        if not gpm.CanImport( name ) then continue end

                        local ok, pkg = gpm.AsyncImport( name, self, false ):SafeAwait()
                        if not ok then
                            if index ~= lenght then continue end
                            error( pkg )
                        end

                        return pkg
                    end

                    if util.IsBinaryModuleInstalled( name ) then
                        return require( name )
                    end

                    if util.IsLuaModuleInstalled( name ) then
                        local ok, pkg = gpm.SourceImport( "lua", "includes/modules/" .. name .. ".lua" ):SafeAwait()
                        if not ok then
                            error( pkg )
                        end

                        Link( self, pkg )
                        return pkg.Result
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

                local link, meta = metaworks.CreateLink( hook, true, false )
                environment.hook = link

                function link.Add( eventName, identifier, ... )
                    if autoNames and type( identifier ) == "string" then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ eventName ][ identifier ] = true
                    return hook.Add( eventName, identifier, ... )
                end

                function link.Remove( eventName, identifier, ... )
                    if autoNames and type( identifier ) == "string" then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ eventName ][ identifier ] = nil
                    return hook.Remove( eventName, identifier, ... )
                end

                meta.__newindex = hook

            end

            -- Timers
            do

                local data = {}
                callbacks.timer = data
                local autoNames = self:HasAutoNames( "timer" )

                local link, meta = metaworks.CreateLink( timer, true, false )
                environment.timer = link

                for key, func in pairs( timer ) do
                    if key == "Destroy" or key == "Remove" or key == "Simple" then continue end
                    link[ key ] = function( identifier, ... )
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

                link.Destroy = removeFunction
                link.Remove = removeFunction

                meta.__newindex = timer

            end

            -- ConVars
            do

                local data = setmetatable( {}, internalMeta )
                local autoNames = self:HasAutoNames( "cvars" )
                callbacks.cvars = data

                local link, meta = metaworks.CreateLink( cvars, true, false )
                environment.cvars = link

                function link.AddChangeCallback( name, func, identifier, ... )
                    if type( identifier ) ~= "string" then
                        identifier = "Default"
                    end

                    if autoNames then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ name ][ identifier ] = true
                    return cvars.AddChangeCallback( name, func, identifier, ... )
                end

                function link.RemoveChangeCallback( name, identifier, ... )
                    if type( identifier ) ~= "string" then
                        identifier = "Default"
                    end

                    if autoNames then
                        identifier = self:GetIdentifier( identifier )
                    end

                    data[ name ][ identifier ] = nil
                    return cvars.RemoveChangeCallback( name, identifier, ... )
                end

                meta.__newindex = cvars

            end

            -- ConCommands
            do

                local data = {}
                callbacks.concommand = data

                local link, meta = metaworks.CreateLink( concommand, true, false )
                environment.concommand = link

                function link.Add( name, ... )
                    data[ name ] = true
                    return concommand.Add( name, ... )
                end

                function link.Remove( name, ... )
                    data[ name ] = nil
                    return concommand.Remove( name, ... )
                end

                meta.__newindex = concommand

            end

            -- Net
            if not MENU_DLL then

                local data = {}
                callbacks.net = data
                local autoNames = self:HasAutoNames( "net" )

                do

                    local link, meta = metaworks.CreateLink( net, true, false )
                    environment.net = link

                    function link.Receive( messageName, ... )
                        if autoNames then
                            messageName = self:GetIdentifier( messageName )
                        end

                        data[ messageName ] = true
                        return net.Receive( messageName, ... )
                    end

                    if autoNames then
                        function link.Start( messageName, ... )
                            return net.Start( self:GetIdentifier( messageName ), ... )
                        end
                    end

                    meta.__newindex = net

                end

                if SERVER then

                    local link, meta = metaworks.CreateLink( util, true, false )
                    environment.util = link

                    function link.AddNetworkString( messageName, ... )
                        if autoNames then
                            messageName = self:GetIdentifier( messageName )
                        end

                        data[ messageName ] = true
                        return util.AddNetworkString( messageName, ... )
                    end

                    meta.__newindex = util

                end

            end

            -- Properties
            do

                local data = {}
                callbacks.properties = data
                local autoNames = self:HasAutoNames( "properties" )

                local link, meta = metaworks.CreateLink( properties, true, false )
                environment.properties = link

                function link.Add( name, ... )
                    if autoNames then
                        name = self:GetIdentifier( name )
                    end

                    data[ string.lower( name ) ] = true
                    return properties.Add( name, ... )
                end

                meta.__newindex = properties

            end

            return environment
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

        local init = self.Init
        if init then
            debug.setfenv( init, _G )
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

    PACKAGE.Run = promise.Async( function( self )
        local init = self.Init
        if not init then
            return promise.Reject( "Missing package '" .. self:GetIdentifier() ..  "' entry point." )
        end

        local ok, result = pcall( init, self )
        if not ok then
            return promise.Reject( result )
        end

        self.Result = result
        return result
    end )

    -- Install/Uninstall/Reload
    PACKAGE.Install = promise.Async( function( self )
        local stopwatch = SysTime()

        local ok, result = self:Run():SafeAwait()
        if not ok then
            return promise.Reject( result )
        end

        gpm.Packages[ self:GetImportPath() ] = self
        self.Installed = true

        local ok, err = pcall( hook_Run, "PackageInstalled", self )
        if not ok then
            ErrorNoHaltWithStack( err )
        end

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

        local importPath = self:GetImportPath()
        gpm.ImportTasks[ importPath ] = nil
        gpm.Packages[ importPath ] = nil
        self.Installed = nil

        logger:Info( "Package '%s' was successfully uninstalled, took %.4f seconds.", self:GetIdentifier(), SysTime() - stopwatch )
    end

    function PACKAGE:IsReloading()
        return self.Reloading or false
    end

    PACKAGE.Reload = promise.Async( function( self, dontSendToClients )
        if self:IsReloading() then return end
        local stopwatch = SysTime()

        local sourceName = self:GetSourceName()
        local source = gpm.sources[ sourceName ]
        if not source then
            return promise.Reject( "Package source '" .. sourceName .. "' not found, package data is probably corrupted." )
        end

        if not source.Reload then
            return promise.Reject( "Package '" .. self:GetIdentifier() .. "' reload failed, source '" .. sourceName .. "' does not support package reloading." )
        end

        self.Reloading = true
        self:ClearCallbacks()

        local importPath, metadata = self:GetImportPath()
        if source.GetMetadata then
            local ok, result = source.GetMetadata( importPath ):SafeAwait()
            if not ok then
                return promise.Reject( result )
            end

            metadata = result
        end

        if not metadata then
            metadata = {}
        end

        if type( metadata.name ) ~= "string" then
            metadata.name = importPath
        end

        metadata.importpath = importPath
        metadata.sourcename = sourceName
        FormatMetadata( metadata )

        local ok, result = source.Reload( self, metadata ):SafeAwait()
        self.Reloading = nil

        if not ok then
            return promise.Reject( result )
        end

        local ok, err = pcall( hook_Run, "PackageReloaded", self )
        if not ok then
            ErrorNoHaltWithStack( err )
        end

        logger:Info( "Package '%s' was successfully reloaded, took %.4f seconds.", self:GetIdentifier(), SysTime() - stopwatch )
        return result
    end )

    function IsPackage( any )
        return getmetatable( any ) == PACKAGE
    end

    gpm.IsPackage = IsPackage
    _G.TYPE_PACKAGE = gpm.AddType( "Package", IsPackage )

end

Initialize = promise.Async( function( metadata, func, files )
    local pkg = setmetatable( {
        ["Installed"] = false,
        ["Metadata"] = {},
        ["Children"] = {},
        ["Files"] = {},
        ["Init"] = func
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
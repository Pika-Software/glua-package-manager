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
                autonames.properties = autonames.properties == true and source.environment
                autonames.timer = autonames.timer == true and source.environment
                autonames.cvars = autonames.cvars == true and source.environment
                autonames.hook = autonames.hook == true and source.environment
                autonames.net = autonames.net == true and source.environment
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
        return table.Lookup( self, "Metadata.importpath" )
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

    function PACKAGE:GetFileList()
        local fileList = {}
        for filePath in pairs( self:GetFiles() ) do
            fileList[ #fileList + 1 ] = filePath
        end

        return fileList
    end

    function PACKAGE:HasEnvironment()
        return type( self:GetEnvironment() ) == "table"
    end

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
            debug.setfenv( func, env )
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

            local libraries = self.Libraries

            -- Hooks
            local data = libraries.hook
            if type( data ) == "table" then
                for eventName, data in pairs( data ) do
                    for identifier in pairs( data ) do
                        hook.Remove( eventName, identifier )
                        data[ eventName ][ identifier ] = nil
                    end

                    data[ eventName ] = nil
                end
            end

            -- Timers
            data = libraries.timer
            if type( data ) == "table" then
                for identifier in pairs( data ) do
                    timer.Remove( identifier )
                    data[ identifier ] = nil
                end
            end

            -- ConVars
            data = libraries.cvars
            if type( data ) == "table" then
                for name, cvar in pairs( data ) do
                    for identifier in pairs( cvar ) do
                        cvars.RemoveChangeCallback( name, identifier )
                        data[ name ][ identifier ] = nil
                    end

                    data[ name ] = nil
                end
            end

            -- ConCommands
            data = libraries.concommand
            if type( data ) == "table" then
                for name in pairs( data ) do
                    concommand.Remove( name )
                    data[ name ] = nil
                end
            end

            -- Properties
            data = libraries.properties
            if type( data ) == "table" then
                for name in pairs( data ) do
                    properties.List[ name ] = nil
                    data[ name ] = nil
                end
            end

            -- Network strings
            data = libraries.net
            if type( data ) == "table" then
                for messageName in pairs( data ) do
                    net.Receivers[ messageName ] = nil
                    data[ messageName ] = nil
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

local addCSLuaFile = SERVER and AddClientLuaFile or debug.fempty

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
        files = {}
    end

    -- Creating package object
    local pkg = setmetatable( {}, PACKAGE )
    pkg.Metadata = metadata
    pkg.Installed = false
    pkg.Files = files
    pkg.Main = func

    if metadata.environment then
        for _, func in ipairs( files ) do
            debug.setfenv( func, env )
        end

        pkg.Children = {}

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

        -- AddCSLuaFile
        env.AddCSLuaFile = addCSLuaFile

        -- include
        env.include = function( fileName )
            gpm.ArgAssert( fileName, 1, "string" )

            local func = files[ paths.Fix( fileName ) ]
            if type( func ) == "function" then
                return func( pkg )
            end

            local luaPath = getCurrentLuaPath()
            if luaPath then
                local folder = string.GetPathFromFilename( luaPath )
                if folder and #folder > 0 then
                    local filePath = paths.Fix( folder .. fileName )
                    if fs.IsFile( filePath, "LUA" ) then
                        func = gpm.CompileLua( filePath ):Await()
                        if type( func ) == "function" then
                            files[ fileName ] = debug.setfenv( func, env )
                            return func( pkg )
                        end
                    end
                end
            end

            local filePath = paths.Fix( fileName )
            if fs.IsFile( filePath, "LUA" ) then
                func = gpm.CompileLua( filePath ):Await()
                if type( func ) == "function" then
                    files[ fileName ] = debug.setfenv( func, env )
                    return func( pkg )
                end
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

        pkg.Libraries = {}

        -- Hooks
        do

            local data = setmetatable( {}, internalMeta )
            local autoNames = pkg:HasAutoNames( "hook" )
            pkg.Libraries.hook = data

            local obj, metatable = environment.SetLinkedTable( env, "hook", hook )

            function obj.Add( eventName, identifier, ... )
                if autoNames and type( identifier ) == "string" then
                    identifier = pkg:GetIdentifier( identifier )
                end

                data[ eventName ][ identifier ] = true
                return hook.Add( eventName, identifier, ... )
            end

            function obj.Remove( eventName, identifier, ... )
                if autoNames and type( identifier ) == "string" then
                    identifier = pkg:GetIdentifier( identifier )
                end

                data[ eventName ][ identifier ] = nil
                return hook.Remove( eventName, identifier, ... )
            end

            metatable.__newindex = hook

        end

        -- Timers
        do

            local data = {}
            pkg.Libraries.timer = data
            local autoNames = pkg:HasAutoNames( "timer" )

            local obj, metatable = environment.SetLinkedTable( env, "timer", timer )

            for key, func in pairs( timer ) do
                if timerBlacklist[ key ] then continue end
                obj[ key ] = function( identifier, ... )
                    if autoNames then
                        identifier = pkg:GetIdentifier( identifier )
                    end

                    data[ identifier ] = true
                    return func( identifier, ... )
                end
            end

            local function removeFunction( identifier, ... )
                if autoNames then
                    identifier = pkg:GetIdentifier( identifier )
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
            local autoNames = pkg:HasAutoNames( "cvars" )
            pkg.Libraries.cvars = data

            local obj, metatable = environment.SetLinkedTable( env, "cvars", cvars )

            function obj.AddChangeCallback( name, func, identifier, ... )
                if type( identifier ) ~= "string" then
                    identifier = "Default"
                end

                if autoNames then
                    identifier = pkg:GetIdentifier( identifier )
                end

                data[ name ][ identifier ] = true
                return cvars.AddChangeCallback( name, func, identifier, ... )
            end

            function obj.RemoveChangeCallback( name, identifier, ... )
                if type( identifier ) ~= "string" then
                    identifier = "Default"
                end

                if autoNames then
                    identifier = pkg:GetIdentifier( identifier )
                end

                data[ name ][ identifier ] = nil
                return cvars.RemoveChangeCallback( name, identifier, ... )
            end

            metatable.__newindex = cvars

        end

        -- ConCommands
        do

            local data = {}
            pkg.Libraries.concommand = data

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
            pkg.Libraries.net = data
            local autoNames = pkg:HasAutoNames( "net" )

            do

                local obj, metatable = environment.SetLinkedTable( env, "net", net )

                function obj.Receive( messageName, ... )
                    if autoNames then
                        messageName = pkg:GetIdentifier( messageName )
                    end

                    data[ messageName ] = true
                    return net.Receive( messageName, ... )
                end

                if autoNames then
                    function obj.Start( messageName, ... )
                        return net.Start( pkg:GetIdentifier( messageName ), ... )
                    end
                end

                metatable.__newindex = net

            end

            if SERVER then

                local obj, metatable = environment.SetLinkedTable( env, "util", util )

                function obj.AddNetworkString( messageName, ... )
                    if autoNames then
                        messageName = pkg:GetIdentifier( messageName )
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
            pkg.Libraries.properties = data
            local autoNames = pkg:HasAutoNames( "properties" )

            local obj, metatable = environment.SetLinkedTable( env, "properties", properties )

            function obj.Add( name, ... )
                if autoNames then
                    name = pkg:GetIdentifier( name )
                end

                data[ string.lower( name ) ] = true
                return properties.Add( name, ... )
            end

            metatable.__newindex = properties

        end
    end

    -- Installing
    local ok, result = pkg:Install():SafeAwait()
    if not ok then
        return promise.Reject( result )
    end

    return pkg
end )
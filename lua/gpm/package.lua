local environment = gpm.environment
local timer = timer
local hook = hook
local net = net

gpm.Packages = gpm.Packages or {}

module( "gpm.package", package.seeall )

-- Get one existing package
function Get( packageName )
    return gpm.Packages[ packageName ]
end

-- Get all existing packages
function GetAll()
    return gpm.Packages
end

-- Package Meta
local meta = {}
meta.__index = meta

function meta:GetName()
    return self.Name
end

function meta:GetEnvironment()
    return self.Environment
end

function meta:GetFunction()
    return self.Function
end

function meta:GetVersion()
    return self.Version
end

function meta:GetLogger()
    return self.Logger
end

function meta:GetFolder()
    return self.Folder
end

function meta:GetResult()
    return self.Result
end

local function FindFileInFiles(fileName, files, current_dir)
    if not isstring(fileName) or not istable(files) then return end

    if isstring(current_dir) then
        local path = current_dir .. "/" .. fileName
        if files[path] then return files[path] end
    end

    return files[fileName]
end

function Load( packageInfo, func, files, env )
    local startTime = SysTime()

    -- Getting Info
    local packageName = packageInfo.name .. " (" .. packageInfo.version .. ")"
    local function packageIdentifier( str )
        return packageName .. " - " .. str
    end

    -- Environment Create
    local packageEnv = environment.Create( func, env )

    -- Hooks
    do

        environment.SetLinkedTable( packageEnv, "hook", hook )

        local hooks = {}
        environment.SetFunction( packageEnv, "hook.GetTable", function()
            return hooks
        end )

        environment.SetFunction( packageEnv, "hook.Add", function( eventName, identifier, value, ... )
            if isstring( identifier ) then
                hook.Add( eventName, packageIdentifier( identifier ), value, ... )
            else
                hook.Add( eventName, identifier, value, ... )
            end

            if (hooks[ eventName ] == nil) then
                hooks[ eventName ] = {}
            end

            hooks[ eventName ][ identifier ] = value
        end )

        environment.SetFunction( packageEnv, "hook.Remove", function( eventName, identifier, ... )
            if isstring( identifier ) then
                hook.Remove( eventName, packageIdentifier( identifier ), ... )
            else
                hook.Remove( eventName, identifier, ... )
            end

            if (hooks[ eventName ] == nil) then
                return
            end

            hooks[ eventName ][ identifier ] = nil
        end )

        environment.Set( packageEnv, "hook.GetGlobalTable", hook.GetTable )

    end

    -- Network
    do

        environment.SetLinkedTable( packageEnv, "net", net )

        environment.SetFunction( packageEnv, "Receive", function( messageName, ... )
            return net.Receive( packageIdentifier( messageName ), ... )
        end )

        environment.SetFunction( packageEnv, "net.Start", function( messageName, ... )
            return net.Start( packageIdentifier( messageName ), ... )
        end )

    end

    -- Utils
    if (SERVER) then

        environment.SetLinkedTable( packageEnv, "util", util )

        environment.SetFunction( packageEnv, "util.AddNetworkString", function( str, ... )
            return util.AddNetworkString( packageIdentifier( str ), ... )
        end )

    end

    -- Timers
    do

        environment.SetLinkedTable( packageEnv, "timer", timer )

        -- Adjust
        environment.SetFunction( packageEnv, "timer.Adjust", function( identifier, ... )
            return timer.Adjust( packageIdentifier( identifier ), ... )
        end )

        -- Create
        environment.SetFunction( packageEnv, "timer.Create", function( identifier, ... )
            return timer.Create( packageIdentifier( identifier ), ... )
        end )

        -- Exists
        environment.SetFunction( packageEnv, "timer.Exists", function( identifier, ... )
            return timer.Exists( packageIdentifier( identifier ), ... )
        end )

        -- Pause
        environment.SetFunction( packageEnv, "timer.Pause", function( identifier, ... )
            return timer.Pause( packageIdentifier( identifier ), ... )
        end )

        environment.SetFunction( packageEnv, "timer.UnPause", function( identifier, ... )
            return timer.UnPause( packageIdentifier( identifier ), ... )
        end )

        -- Remove
        local timerRemove = function( identifier, ... )
            return timer.Remove( packageIdentifier( identifier ), ... )
        end

        environment.SetFunction( packageEnv, "timer.Remove", timerRemove )
        environment.SetFunction( packageEnv, "timer.Destroy", timerRemove )

        -- TimeLeft & RepsLeft
        environment.SetFunction( packageEnv, "timer.TimeLeft", function( identifier, ... )
            return timer.TimeLeft( packageIdentifier( identifier ), ... )
        end )

        environment.SetFunction( packageEnv, "timer.RepsLeft", function( identifier, ... )
            return timer.RepsLeft( packageIdentifier( identifier ), ... )
        end )

        -- Start, Stop & Toggle
        environment.SetFunction( packageEnv, "timer.Start", function( identifier, ... )
            return timer.Start( packageIdentifier( identifier ), ... )
        end )

        environment.SetFunction( packageEnv, "timer.Stop", function( identifier, ... )
            return timer.Stop( packageIdentifier( identifier ), ... )
        end )

        environment.SetFunction( packageEnv, "timer.Toggle", function( identifier, ... )
            return timer.Toggle( packageIdentifier( identifier ), ... )
        end )

    end

    -- Render Target
    if (CLIENT) then

        environment.SetFunction( packageEnv, "GetRenderTarget", function( name, ... )
            return GetRenderTarget( packageIdentifier( name ), ... )
        end )

        environment.SetFunction( packageEnv, "GetRenderTargetEx", function( name, ... )
            return GetRenderTargetEx( packageIdentifier( name ), ... )
        end )

    end

    -- Include
    environment.SetFunction( packageEnv, "include", function( fileName )
        ArgAssert( fileName, 1, "string" )

        PrintTable( debug.getinfo( 2 ) )
        -- local fileFunc = files[ fileName ]

        print( FindFileInFiles )

        -- if (fileFunc) then
        --     return fileFunc()
        -- end

        ErrorNoHaltWithStack( "Couldn't include file '" .. fileName .. "' - File not found" )
        -- return include( fileName )
    end )

    -- AddCSLuaFile
    if (SERVER) then
        environment.SetFunction( packageEnv, "AddCSLuaFile", function( fileName )
            return AddCSLuaFile( fileName )
        end)
    end

    -- GPM
    environment.SetLinkedTable( packageEnv, "gpm", gpm )

    -- Logger
    local logger = gpm.logger.Create( packageName, packageInfo.color )
    environment.Set( packageEnv, "gpm.Logger", logger )

    -- Creating meta
    local packageObject = setmetatable( {
        ["Folder"] = string.GetPathFromFilename( packageInfo.main ),
        ["Version"] = packageInfo.version,
        ["Environment"] = packageEnv,
        ["Name"] = packageInfo.name,
        ["Function"] = func,
        ["Logger"] = logger
    }, meta )

    -- Package
    environment.Set( packageEnv, "gpm.Package", packageObject )

    -- Run
    local result = { xpcall( func, function( str )
        logger:Error( str )
    end ) }

    if not result[1] then
        gpm.Logger:Warn( "Package `%s` loading failed, see above for the reason, it took %.4f seconds.", packageName, SysTime() - startTime )
        return
    end

    -- Result Saving
    table.remove( result, 1 )
    packageObject.Return = result

    -- Saving in global table & final log
    gpm.Logger:Info( "Package `%s` was successfully loaded, it took %.4f seconds.", packageName, SysTime() - startTime )
    gpm.Packages[ packageName ] = packageObject
    return packageObject
end


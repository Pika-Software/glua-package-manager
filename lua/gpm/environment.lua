local debug_setfenv = debug.setfenv
local setmetatable = setmetatable
local table_Copy = table.Copy
local ArgAssert = ArgAssert
local isstring = isstring
local istable = istable
local pairs = pairs
local timer = timer
local hook = hook
local _G = _G

module( 'gpm.environment' )

-- Create
do

    local cache = {}
    function Create( func, env )
        ArgAssert( func, 1, 'function' )
        env = env or _G

        local meta = cache[ env ]
        if (meta == nil) then
            meta = {
                ['__index'] = env
            }

            cache[ env ] = meta
        end

        local new = {}
        debug_setfenv( func, setmetatable( new, meta ) )
        return new
    end

end

-- Custom Hooks
function CustomHooks( env, name )
    ArgAssert( env, 1, 'table' )
    ArgAssert( name, 2, 'string' )

    local lib = table_Copy( hook )

    do

        local hooks = {}
        function lib.GetTable()
            return hooks
        end

        function lib.Add( eventName, identifier, func, ... )
            ArgAssert( eventName, 1, 'string' )
            ArgAssert( func, 3, 'function' )

            if isstring( identifier ) then
                hook.Add( eventName, name .. ' - ' .. identifier, func, ... )
            else
                hook.Add( eventName, identifier, func, ... )
            end

            if (hooks[ eventName ] == nil) then
                hooks[ eventName ] = {}
            end

            hooks[ eventName ][ identifier ] = func
        end

        function lib.Remove( eventName, identifier, ... )
            ArgAssert( eventName, 1, 'string' )

            if isstring( identifier ) then
                hook.Remove( eventName, name .. ' - ' .. identifier, ... )
            else
                hook.Remove( eventName, identifier, ... )
            end

            if (hooks[ eventName ] == nil) then
                return
            end

            hooks[ eventName ][ identifier ] = nil
        end

        lib.Call = hook.Call
        lib.Run = hook.Run

    end

    env.hook = lib
end

function RemoveCustomHooks( env )
    ArgAssert( env, 1, 'table' )

    local lib = env.hook
    if istable( lib ) and (lib ~= hook) then
        for eventName, functions in pairs( lib.GetTable() ) do
            for identifier in pairs( functions ) do
                lib.Remove( eventName, identifier )
            end
        end
    end
end

-- Custom Timers
function CustomTimers( env, name )
    ArgAssert( env, 1, 'table' )
    ArgAssert( name, 2, 'string' )

    local lib = table_Copy( timer )
    lib.__Timers = {}

    function lib.Adjust( identifier, ... )
        return timer.Adjust( name .. ' - ' .. identifier, ... )
    end

    function lib.Create( identifier, ... )
        identifier = name .. ' - ' .. identifier
        lib.__Timers[ identifier ] = true

        return timer.Create( identifier, ... )
    end

    function lib.Exists( identifier, ... )
        return timer.Exists( name .. ' - ' .. identifier, ... )
    end

    function lib.Pause( identifier, ... )
        return timer.Pause( name .. ' - ' .. identifier, ... )
    end

    function lib.Remove( identifier, ... )
        identifier = name .. ' - ' .. identifier
        lib.__Timers[ identifier ] = nil

        return timer.Remove( identifier, ... )
    end

    function lib.RepsLeft( identifier, ... )
        return timer.RepsLeft( name .. ' - ' .. identifier, ...)
    end

    function lib.Start( identifier, ... )
        return timer.Start( name .. ' - ' .. identifier, ... )
    end

    function lib.Stop( identifier, ... )
        return timer.Stop( name .. ' - ' .. identifier, ... )
    end

    function lib.TimeLeft( identifier, ... )
        return timer.TimeLeft( name .. ' - ' .. identifier, ... )
    end

    function lib.Toggle( identifier, ... )
        return timer.Toggle( name .. ' - ' .. identifier, ... )
    end

    function lib.UnPause( identifier, ... )
        return timer.UnPause( name .. ' - ' .. identifier, ... )
    end

    -- Alias
    lib.Destroy = lib.Remove

    env.timer = lib
end

function RemoveCustomTimers( env )
    ArgAssert( env, 1, 'table' )

    local lib = env.timer
    if istable( lib ) and (lib ~= timer) then
        local timers = lib.__Timers
        if istable( timers ) then
            for identifier in pairs( timers ) do
                timer.Remove( identifier )
            end
        end
    end
end
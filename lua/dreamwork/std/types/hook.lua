---@class dreamwork.std
local std = dreamwork.std

local debug = std.debug
local debug_fempty = debug.fempty

local table = std.table
local table_sort = table.sort
local table_remove = table.remove
local table_unpack = table.unpack

local string = std.string
local string_format = string.format

local class = std.class

local pcall = std.pcall
local error = std.error
local is = std.is

local Future = std.Future


--- [SHARED AND MENU]
---
--- A hook is a named, prioritized event pipeline that other code can attach
--- handlers to and later call to run them. Handlers are grouped into four
--- ordered stages - `peek`, `provide`, `mixin`, and `observe` - which run in
--- that order each time the hook is called via `Hook:call` (or by calling the
--- hook object itself, since it is callable).
---
--- Hook call pipeline, stages run in this order:
---
--- ```md
--- ┌─────────┐
--- │  peek   │ --> Always called, return is optional;
--- └─────────┘     if any handler returns a value,
---      ↓          it overrides the `provide` stage.
--- ┌─────────┐
--- │ provide │ --> Called only if `peek` produced `nil`.
--- └─────────┘     First hook that returns a value wins,
---      ↓          its return value becomes the result.
--- ┌─────────┐
--- │  mixin  │ --> Called as long as a result exists.
--- └─────────┘     Lets handlers mutate the result,
---      ↓          receiving both the old & new value.
--- ┌─────────┐
--- │ observe │ --> Read-only listeners for the final
--- └─────────┘     result and args. Any return values
---                 will be ignored.
---```
---
---@class dreamwork.std.Hook<T> : dreamwork.std.Object
---@field __class dreamwork.std.HookClass
---@field name string The name of the hook.
---@field protected running boolean Whether the hook is currently running.
---@field protected has_changes boolean Whether the hook has changes to apply.
---@field protected peek_handlers (dreamwork.std.Hook<T> | fun( ...: any ): T)[]
---@field protected peek_priorities table<(dreamwork.std.Hook<T> | fun( ...: any ): T), integer>
---@field protected provide_handlers (dreamwork.std.Hook<T> | fun( ...: any ): T)[]
---@field protected provide_priorities table<(dreamwork.std.Hook<T> | fun( ...: any ): T), integer>
---@field protected observe_handlers (dreamwork.std.Hook<T> | fun( ...: any ): T)[]
---@field protected observe_priorities table<(dreamwork.std.Hook<T> | fun( ...: any ): T), integer>
---@field protected mixin_handlers (dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T)[]
---@field protected mixin_priorities table<(dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T), integer>
local Hook = class.base( "Hook", false, nil )

---@return string
---@protected
function Hook:__represent()
    return string_format( "Hook: %p [%s][%s]", self, self.name, self.running and "running" or "stopped" )
end

---@return boolean
---@protected
function Hook:__toboolean()
    return self.running
end

---@return integer
---@protected
function Hook:__len()
    return self.peek_handlers[ 0 ] +
        self.provide_handlers[ 0 ] +
        self.mixin_handlers[ 0 ] +
        self.observe_handlers[ 0 ]
end

---@param name string | nil
---@protected
function Hook:__init( name )
    self.name = name or string_format( "%p", self )
    self.has_changes = false
    self.running = false
    self:clear()
end

--- [SHARED AND MENU]
---
--- Checks if the hook is running currently.
---
---@return boolean is_running Returns `true` if the hook is running currently, otherwise `false`.
function Hook:isRunning()
    return self.running
end

---@generic T
---@param self dreamwork.std.Hook<T>
---@param handlers (dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T)[]
---@param priorities table<( dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T ), integer>
---@param handler dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T
---@return boolean
local function detach_type( self, handlers, priorities, handler )
    local count = handlers[ 0 ]
    for i = count, 1, -1 do
        if handlers[ i ] == handler then
            priorities[ handler ] = nil

            ---@diagnostic disable-next-line: invisible
            if self.running then
                handlers[ i ] = debug_fempty
                ---@diagnostic disable-next-line: invisible
                self.has_changes = true
            else
                table_remove( handlers, i )
                handlers[ 0 ] = count - 1
            end

            return true
        end
    end

    return false
end

local active_priorities

---@generic T
---@param a dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T
---@param b dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T
---@return boolean
local function priority_sort( a, b )
    return active_priorities[ a ] < active_priorities[ b ]
end

---@generic T
---@param handlers (dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T)[]
---@param priorities table<( dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T ), integer>
local function sync_priorities( handlers, priorities )
    active_priorities = priorities
    table_sort( handlers, priority_sort )
end

---@generic T
---@param self dreamwork.std.Hook<T>
---@param handlers (dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T)[]
---@param priorities table<( dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T ), integer>
---@param handler dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T
---@param priority integer | nil
local function attach_type( self, handlers, priorities, handler, priority )
    for i = handlers[ 0 ], 1, -1 do
        if handlers[ i ] == handler then
            if priority ~= nil and priorities[ handler ] ~= priority then
                priorities[ handler ] = priority

                ---@diagnostic disable-next-line: invisible
                if self.running then
                    ---@diagnostic disable-next-line: invisible
                    self.has_changes = true
                else
                    sync_priorities( handlers, priorities )
                end
            end

            return
        end
    end

    local count = handlers[ 0 ] + 1
    handlers[ count ] = handler
    handlers[ 0 ] = count

    priorities[ handler ] = priority or 0

    ---@diagnostic disable-next-line: invisible
    if self.running then
        ---@diagnostic disable-next-line: invisible
        self.has_changes = true
    else
        sync_priorities( handlers, priorities )
    end
end

--- [SHARED AND MENU]
---
--- Detaches a previously attached handler from the given stage of the hook.
--- If the hook is currently running, the handler is replaced with a no-op and
--- the actual removal is deferred until the hook finishes running.
---
---@generic T
---@param self dreamwork.std.Hook<T>
---@param type "provide" | "peek" | "observe" | "mixin" | nil The stage to detach the handler from. Defaults to `"provide"` when `nil`.
---@param handler dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): T The exact handler reference that was previously passed to `attach`.
---@return boolean is_detached Returns `true` if the handler was found and detached, otherwise `false`.
function Hook:detach( type, handler )
    if type == nil or type == "provide" then
        return detach_type( self, self.provide_handlers, self.provide_priorities, handler )
    elseif type == "peek" then
        return detach_type( self, self.peek_handlers, self.peek_priorities, handler )
    elseif type == "observe" then
        return detach_type( self, self.observe_handlers, self.observe_priorities, handler )
    elseif type == "mixin" then
        return detach_type( self, self.mixin_handlers, self.mixin_priorities, handler )
    end

    error( "attempt to detach unknown hook type", 2 )
    return false
end

---@generic T
---@param self dreamwork.std.Hook<T>
---@param parent dreamwork.std.Hook<T>
---@return boolean is_contained
local function contains_parent( self, parent )
    if self == parent then
        return true
    end

    local peeks = self.peek_handlers
    for i = 1, peeks[ 0 ], 1 do
        ---@type dreamwork.std.Hook<any>
        local value = peeks[ i ]
        if is( value, Hook ) and (value == parent or contains_parent( value, parent )) then
            return true
        end
    end

    local providers = self.provide_handlers
    for i = 1, providers[ 0 ], 1 do
        ---@type dreamwork.std.Hook<any>
        local value = providers[ i ]
        if is( value, Hook ) and (value == parent or contains_parent( value, parent )) then
            return true
        end
    end

    local mixins = self.mixin_handlers
    for i = 1, mixins[ 0 ], 1 do
        ---@type dreamwork.std.Hook<any>
        local value = mixins[ i ]
        if is( value, Hook ) and (value == parent or contains_parent( value, parent )) then
            return true
        end
    end

    local observers = self.observe_handlers
    for i = 1, observers[ 0 ], 1 do
        ---@type dreamwork.std.Hook<any>
        local value = observers[ i ]
        if is( value, Hook ) and (value == parent or contains_parent( value, parent )) then
            return true
        end
    end

    return false
end

--- [SHARED AND MENU]
---
--- Attaches a handler function to the given stage of the hook.
--- If the handler is already attached to that stage, only its priority is
--- updated (when a new one is supplied); it will not be attached twice.
---
--- If the hook is currently running, the change is deferred and applied once
--- the hook finishes running.
---
---@generic T
---@param self dreamwork.std.Hook<T>
---@param type "provide" | "peek" | "observe" | "mixin" | nil The stage to attach the handler to. Defaults to `"provide"` when `nil`.
---@param handler dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any )
---@param priority integer | nil The priority of the handler within its stage; handlers with a lower value run earlier. Defaults to `0`.
---@overload fun( self: dreamwork.std.Hook<T>, type: "peek", handler: ( dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): ( T | nil ) ), priority: ( integer | nil ) )
---@overload fun( self: dreamwork.std.Hook<T>, type: ( "provide" | nil ), handler: ( dreamwork.std.Hook<T> | dreamwork.std.Mixin<T> | fun( ...: any ): ( T | nil ) ), priority: ( integer | nil ) )
---@overload fun( self: dreamwork.std.Hook<T>, type: "mixin", handler: fun( old_value: ( T | nil ), new_value: T, ...: any ): ( T | nil ), priority: ( integer | nil ) )
---@overload fun( self: dreamwork.std.Hook<T>, type: "observe", handler: fun( value: T, ...: any ), priority: ( integer | nil ) )
function Hook:attach( type, handler, priority )
    if is( handler, Hook ) and ---@cast handler dreamwork.std.Hook<any>
        contains_parent( handler, self ) then
        error( "attempt to create circular hook reference", 2 )
    end

    if type == nil or type == "provide" then
        return attach_type( self, self.provide_handlers, self.provide_priorities, handler, priority )
    elseif type == "peek" then
        return attach_type( self, self.peek_handlers, self.peek_priorities, handler, priority )
    elseif type == "observe" then
        return attach_type( self, self.observe_handlers, self.observe_priorities, handler, priority )
    elseif type == "mixin" then
        return attach_type( self, self.mixin_handlers, self.mixin_priorities, handler, priority )
    end

    error( "attempt to attach unknown hook type", 2 )
end

---@generic T
---@param self dreamwork.std.Hook<T>
---@return boolean
local function hook_cancel( self )
    ---@diagnostic disable-next-line: invisible
    if not self.running then
        return false
    end

    ---@diagnostic disable-next-line: invisible
    if self.has_changes then
        local peeks = self.peek_handlers
        local peek_size = peeks[ 0 ]

        for i = peek_size, 1, -1 do
            if peeks[ i ] == debug_fempty then
                peek_size = peek_size - 1
                table_remove( peeks, i )
            end
        end

        peeks[ 0 ] = peek_size

        sync_priorities( peeks, self.peek_priorities )

        local providers = self.provide_handlers
        local provider_size = providers[ 0 ]

        for i = provider_size, 1, -1 do
            if providers[ i ] == debug_fempty then
                provider_size = provider_size - 1
                table_remove( providers, i )
            end
        end

        providers[ 0 ] = provider_size

        sync_priorities( providers, self.provide_priorities )

        local observers = self.observe_handlers
        local observer_size = observers[ 0 ]

        for i = observer_size, 1, -1 do
            if observers[ i ] == debug_fempty then
                observer_size = observer_size - 1
                table_remove( observers, i )
            end
        end

        observers[ 0 ] = observer_size

        sync_priorities( observers, self.observe_priorities )

        local mixins = self.mixin_handlers
        local mixin_size = mixins[ 0 ]

        for i = mixin_size, 1, -1 do
            if mixins[ i ] == debug_fempty then
                mixin_size = mixin_size - 1
                table_remove( mixins, i )
            end
        end

        mixins[ 0 ] = mixin_size

        sync_priorities( mixins, self.mixin_priorities )

        ---@diagnostic disable-next-line: invisible
        self.has_changes = false
    end

    ---@diagnostic disable-next-line: invisible
    self.running = false
    return true
end

Hook.cancel = hook_cancel

--- [SHARED AND MENU]
---
--- Cancels the hook if it is currently running, and removes every handler
--- attached to every stage (`peek`, `provide`, `observe`, `mixin`), resetting
--- their priority tables as well.
---
function Hook:clear()
    hook_cancel( self )

    self.peek_handlers = { [ 0 ] = 0 }
    self.peek_priorities = {}

    self.provide_handlers = { [ 0 ] = 0 }
    self.provide_priorities = {}

    self.observe_handlers = { [ 0 ] = 0 }
    self.observe_priorities = {}

    self.mixin_handlers = { [ 0 ] = 0 }
    self.mixin_priorities = {}
end

--- [SHARED AND MENU]
---
--- Runs the hook, calling its handlers in order across all four stages:
--- `peek` (early handlers that may short-circuit the result), `provide`
--- (produces the base result), `mixin` (allowed to transform the result),
--- and `observe` (read-only listeners called with the final result).
---
--- Throws (and cancels the hook) if any handler errors, or if the hook is
--- already running.
---
---@generic T
---@param self dreamwork.std.Hook<T>
---@param ... any Arguments forwarded to every handler in every stage.
---@return T | nil result The final value produced by `peek`/`provide` and possibly transformed by `mixin` handlers; `nil` if no handler produced a value.
function Hook:call( ... )
    if self.running then
        error( "hook is already running, please wait until it finish", 2 )
    end

    self.running = true

    -- peek stage
    local peeks = self.peek_handlers
    local peek_value

    for i = 1, peeks[ 0 ], 1 do
        local is_successful_peek, peek_result = pcall( peeks[ i ], ... )
        if is_successful_peek then
            if peek_result ~= nil then
                peek_value = peek_result
            end
        else
            hook_cancel( self )
            error( peek_result, 2 )
        end
    end

    -- provide stage
    local providers = self.provide_handlers
    local provide_value

    if peek_value == nil then
        for i = 1, providers[ 0 ], 1 do
            local is_successful_provide, provide_result = pcall( providers[ i ], ... )
            if is_successful_provide then
                if provide_result ~= nil then
                    provide_value = provide_result
                    break
                end
            else
                hook_cancel( self )
                error( provide_result, 2 )
            end
        end
    else
        provide_value = peek_value
    end

    -- mixin stage
    if provide_value ~= nil then
        local mixins = self.mixin_handlers
        local mixin_value

        for i = 1, mixins[ 0 ], 1 do
            local is_successful_mixin, mixin_result = pcall( mixins[ i ], mixin_value, provide_value, ... )
            if is_successful_mixin then
                mixin_value, provide_value = provide_value, mixin_result
            else
                hook_cancel( self )
                error( mixin_result, 2 )
            end
        end
    end

    -- observe stage
    local observers = self.observe_handlers
    for i = 1, observers[ 0 ], 1 do
        local is_successful_observation, error_message = pcall( observers[ i ], provide_value, ... )
        if not is_successful_observation then
            hook_cancel( self )
            error( error_message, 2 )
        end
    end

    hook_cancel( self )

    return provide_value
end

Hook.__call = Hook.call

--- [SHARED AND MENU]
---
--- Attaches a handler function to the hook that automatically detaches
--- itself right before being invoked, so it only ever runs once.
---
---@generic T
---@param self dreamwork.std.Hook<T>
---@param type "provide" | "peek" | "observe" | "mixin" | nil The stage to attach the handler to. Defaults to `"provide"` when `nil`.
---@param handler dreamwork.std.Hook<T> | fun( ...: any )
---@param priority integer | nil The priority of the handler within its stage; handlers with a lower value run earlier. Defaults to `0`.
---@overload fun( self: dreamwork.std.Hook<T>, type: ( "peek" | nil ), handler: ( dreamwork.std.Hook<T> | fun( ...: any ): ( T | nil ) ), priority: ( integer | nil ) )
---@overload fun( self: dreamwork.std.Hook<T>, type: "provide", handler: ( dreamwork.std.Hook<T> | fun( ...: any ): T ), priority: ( integer | nil ) )
---@overload fun( self: dreamwork.std.Hook<T>, type: "mixin", handler: ( dreamwork.std.Mixin<T> | fun( old_value: ( T | nil ), new_value: T, ...: any ): T ), priority: ( integer | nil ) )
---@overload fun( self: dreamwork.std.Hook<T>, type: "observe", handler: fun( value: T, ...: any ), priority: ( integer | nil ) )
function Hook:once( type, handler, priority )
    local function temp_func( ... )
        self:detach( type, temp_func )
        return handler( ... )
    end

    return self:attach( type, temp_func, priority )
end

--- [SHARED AND MENU]
---
--- Asynchronously suspends the caller until the given stage of the hook is
--- next called, then resumes with the arguments that stage's handler
--- received.
---
---@param type "provide" | "peek" | "observe" | "mixin" The stage to wait for.
---@return any ... The arguments passed to the handler when the awaited stage fired.
---@async
function Hook:await( type )
    local f = Future()

    self:once( type, function( ... )
        f:setResult( { ... } )
    end )

    return table_unpack( f:await() )
end

--- [SHARED AND MENU]
---
--- The class used to create new `Hook` instances.
---
---@class dreamwork.std.HookClass : dreamwork.std.Hook
---@field __base dreamwork.std.Hook
---@overload fun( name: string? ): dreamwork.std.Hook
std.Hook = class.create( Hook )

---@class dreamwork
local dreamwork = dreamwork

local engine = dreamwork.engine
local engine_hookCall = engine.hookCall

---@class dreamwork.std
local std = dreamwork.std

local debug = std.debug
local debug_Stack = debug.Stack

local gc = std.gc
local gc_setTableRules = gc.setTableRules

local table = std.table
local table_remove = table.remove

local string = std.string
local string_match = string.match
local string_format = string.format

local coroutine = std.coroutine
local coroutine_yield = coroutine.yield
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_running = coroutine.running

local isFunction = std.isFunction
local setTimeout = std.setTimeout
local tostring = std.tostring
local xpcall = std.xpcall
local error = std.error
local pcall = std.pcall
local len = std.len

local AsyncError = std.AsyncError
local Queue = std.Queue

local class = std.class

--- [SHARED AND MENU]
---
--- This library provides Python-like futures for asynchronous programming,
--- such as `Futures`, `Tasks`, `Channels`, and async iterators.
---
--- Author: [Retr0](https://github.com/dankmolot)
---
---@class dreamwork.std.futures
local futures = {}
std.futures = futures

---@class dreamwork.Future
---@field RESULT_YIELD dreamwork.std.Symbol
---@field RESULT_ERROR dreamwork.std.Symbol
---@field RESULT_END dreamwork.std.Symbol
---@field ACTION_CANCEL dreamwork.std.Symbol
---@field ACTION_RESUME dreamwork.std.Symbol
---@field Listeners table<thread, function>
---@field AsyncListeners table<thread, thread>
---@field Stacks table<thread, dreamwork.std.debug.Stack>
---@field Threads table<thread, thread>
dreamwork.Future = dreamwork.Future or {
    RESULT_YIELD = std.Symbol( "FUTURE_RESULT_YIELD" ),
    RESULT_ERROR = std.Symbol( "FUTURE_RESULT_ERROR" ),
    RESULT_END = std.Symbol( "FUTURE_RESULT_END" ),

    ACTION_CANCEL = std.Symbol( "FUTURE_ACTION_CANCEL" ),
    ACTION_RESUME = std.Symbol( "FUTURE_ACTION_RESUME" ),

    ---@type table<thread, function>
    Listeners = {},

    ---@type table<thread, thread>
    AsyncListeners = {},

    ---@type table<thread, dreamwork.std.debug.Stack>
    Stacks = {},
}

local dreamwork_Future = dreamwork.Future

local RESULT_YIELD = dreamwork_Future.RESULT_YIELD
local RESULT_ERROR = dreamwork_Future.RESULT_ERROR
local RESULT_END = dreamwork_Future.RESULT_END

local ACTION_CANCEL = dreamwork_Future.ACTION_CANCEL
local ACTION_RESUME = dreamwork_Future.ACTION_RESUME

local Listeners = dreamwork_Future.Listeners
gc_setTableRules( Listeners, true, false )

local AsyncListeners = dreamwork_Future.AsyncListeners
gc_setTableRules( AsyncListeners, true, false )

local Stacks = dreamwork_Future.Stacks

std.setmetatable( Stacks, {
    __index = function( self, thread )
        local stack = debug_Stack()
        self[ thread ] = stack
        return stack
    end,
    __mode = "k"
} )

--- [SHARED AND MENU]
---
--- Abstract type that is used to type hint async functions.
---
---@see dreamwork.std.futures.apairs for example
---@alias dreamwork.std.futures.AsyncIterator<K, V> table<K, V> | nil
---@alias AsyncIterator<K, V> dreamwork.std.futures.AsyncIterator<K, V>

---@alias dreamwork.std.futures.Awaitable { await: async fun(...): ... }
---@alias Awaitable dreamwork.std.futures.Awaitable

futures.running = coroutine_running

--- [SHARED AND MENU]
---
--- Returns the debug stack tracked for the current coroutine,
--- or `nil` if called outside of a coroutine.
---
---@return dreamwork.std.debug.Stack | nil
function futures.stack()
    local co = coroutine_running()
    if co ~= nil then
        return Stacks[ co ]
    end

    return nil
end

local error_object = AsyncError()

---@async
---@param co thread
---@param ok boolean
local function async_thread_result( co, ok, ... )
    local fn = Listeners[ co ]
    if isFunction( fn ) then
        fn( ok, ... )
    elseif not ok then
        if (...) ~= ACTION_CANCEL then
            local error_str = tostring( ... )
            error_object.stack = Stacks[ co ]
            error_object.message = string_match( error_str, "^[^:]+:%d+: ([^\n]+)" ) or error_str
            error_object:display()
        end
    end
end

---@generic T
---@param error_value T
---@return T
local function stack_handler( error_value )
    Stacks[ coroutine_running() ]:capture( 2, 1, 2 )
    return error_value
end

---@async
local function async_thread( fn, ... )
    ---@diagnostic disable-next-line: param-type-mismatch
    return async_thread_result( coroutine_running(), xpcall( fn, stack_handler, ... ) )
end

--- [SHARED AND MENU]
---
--- Executes a function in a new coroutine
--- you can use this function to call async functions even in sync code
--- callback will be called when function returned or errored
--- it will be called with these arguments:
--- * ok: boolean - whether the function returned without errors
--- * ... - return values of the function (or error message)
---
--- ## Example
--- ```lua
--- ---@async
--- local function asyncFunction( a, b )
---     sleep( 1 )
---     return
--- end
---
--- futures.run( asyncFunction, function( ok, result )
---     if ok then
---         print( "result:", result ) -- result: 4
---     else
---         print( "error:", result )
---     end
--- end, 2, 2 ) -- 2 and 2 are arguments for asyncFunction
--- ```
---
---@see dreamwork.std.futures.cancel you can cancel returned coroutine from this function
---@param target async fun(...):... The function to execute.
---@param callback fun(ok: boolean, ...)? The callback function.
---@param ... any Arguments to pass into the target function
---@return thread co The created coroutine object.
local function futures_run( target, callback, ... )
    local new_co = coroutine_create( async_thread )
    Listeners[ new_co ] = callback

    local co = coroutine_running()
    local co_stack

    if co == nil then
        co_stack = Stacks[ new_co ]
    else
        co_stack = Stacks[ co ]
        Stacks[ new_co ] = co_stack
    end

    co_stack:capture( 2, 0, 0, 2 )

    local ok, error_value = coroutine_resume( new_co, target, ... )
    if not ok then
        error( error_value, 2, false )
    end

    return new_co
end

futures.run = futures_run

---@async
local function handle_pending( value, ... )
    if value == ACTION_CANCEL then
        return error( ACTION_CANCEL, 2, false )
    end

    return value, ...
end

--- [SHARED AND MENU]
---
--- Puts current coroutine to sleep until futures.wakeup is called
--- can be used to wait for some event.
---
--- ## Example
--- ```lua
--- ---@async
--- local function request( url )
---     local co = futures.running()
---
---     http.Fetch( url, function( body, size, headers, code )
---         futures.wakeup( co, body )
---     end)
---
---     return futures.pending() -- this will return all arguments passed to futures.wakeup
--- end
---
--- local function main()
---     local body = request( "https://example.com" )
---     print( body ) -- <!DOCTYPE html>...
--- end
---
--- futures.run( main )
--- ```
---@see dreamwork.std.futures.wakeup
---@async
---@return ...
local function futures_pending()
    return handle_pending( coroutine_yield() )
end

futures.pending = futures_pending

--- [SHARED AND MENU]
---
--- Used to wake up a pending coroutine.
---
---@see dreamwork.std.futures.pending for example
---@param co thread The coroutine currently suspended inside `futures.pending`.
---@param ... any Values to return from that `futures.pending()` call.
function futures.wakeup( co, ... )
    coroutine_resume( co, ... )
end

--- [SHARED AND MENU]
---
--- Cancels execution of passed coroutine.
---
--- `CancelError` will be thrown in coroutine.
---
--- NB! pcall inside coroutine can catch this error
--- so coroutine may not be cancelled because of pcall.
---
--- ## Example
--- ```lua
--- ---@async
--- local function work()
---     while true do
---        print( "working" )
---        sleep( 1 )
---     end
--- end
---
--- local co = futures.run( work, function(ok, value )
---     -- because we cancelled coroutine
---     -- ok will be false
---     -- value will be CancelError
--- end)
---
--- futures.cancel( co ) -- this will stop coroutine from executing
--- ```
---@param co thread The coroutine to cancel.
function futures.cancel( co )
    local status = coroutine_status( co )
    if status == "suspended" then
        coroutine_resume( co, ACTION_CANCEL )
    elseif status == "normal" and coroutine_running() then
        -- let's hope that passed coroutine resumed us
        ---@diagnostic disable-next-line: await-in-sync
        coroutine_yield( ACTION_CANCEL )
    elseif status == "running" then
        error( ACTION_CANCEL, 2, false )
    end
end

--- [SHARED AND MENU]
---
--- Transfers data between coroutines in symmetrical way
--- used in asynchronous iterators
--- you probably should not use it.
---
---@see dreamwork.std.futures.apairs for example
---
---@param co thread The coroutine to transfer control and values to.
---@param ... any Values to pass to `co`.
---@return boolean success
---@return any ...
---@async
local function futures_transfer( co, ... )
    local status = coroutine_status( co )
    if status == "suspended" then
        return coroutine_resume( co, ... )
    elseif status == "normal" then
        return true, coroutine_yield( ... )
    elseif status == "running" then
        return false, "cannot transfer to a running coroutine"
    else
        return false, "thread is dead"
    end
end

futures.transfer = futures_transfer

---@async
local function handle_yield( ok, value, ... )
    -- ignore errors, they must be handled by whoever calls us
    if not ok or value == RESULT_ERROR then
        return
    end

    if value == ACTION_CANCEL then
        return error( ACTION_CANCEL, 2, false )
    elseif value == ACTION_RESUME then
        return ...
    elseif value ~= nil then
        return error( "invalid yield action: " .. tostring( value ), 2, false )
    end

    -- caller probably went sleeping
    return handle_yield( true, coroutine_yield() )
end

do

    --- [SHARED AND MENU]
    ---
    --- Yields given arguments to the apairs listener.
    ---
    ---@see dreamwork.std.futures.apairs for example
    ---
    ---@param ... any Values to yield to the listener.
    ---@return ... any Values passed back to this coroutine via ACTION_RESUME.
    ---@async
    local function futures_yield( ... )
        local listener = AsyncListeners[ coroutine_running() ]
        if listener == nil then
            -- whaat? we don't have a listener?!
            error( ACTION_CANCEL, 2, false )
        end

        return handle_yield( futures_transfer( listener, RESULT_YIELD, ... ) )
    end

    futures.yield = futures_yield
    std.yield = futures_yield

end

---@async
local function async_iteratable_thread( fn, ... )
    coroutine_yield() -- wait until anext wakes us up

    local ok, err = pcall( fn, ... )

    local listener = AsyncListeners[ coroutine_running() ]
    if listener then
        if ok then
            futures_transfer( listener, RESULT_END )
        else
            futures_transfer( listener, RESULT_ERROR, err )
        end
    elseif not ok then
        error( err, 2, false )
    end
end

---@async
---@param co thread
---@param ok boolean
local function handle_anext( co, ok, value, ... )
    if not ok then
        return error( value, 2, false )
    end

    if value == RESULT_YIELD then
        return ...
    elseif value == RESULT_END then
        return -- return nothing so for loop with be stopped
    elseif value == RESULT_ERROR then
        return error( ..., 2, false )
    elseif value ~= nil then
        engine_hookCall( "dreamwork.lua.error", "invalid anext result: " .. tostring( value ), 2 )
    end

    -- iterator went sleeping, wait until it wakes us up
    return handle_anext( co, true, coroutine_yield() )
end

--- [SHARED AND MENU]
---
--- Retrieves the next value from an async iterator coroutine.
---
--- Returned by `futures.apairs`;
--- you probably shouldn't call it directly.
---
---@see dreamwork.std.futures.apairs for example
---
---@param iterator thread The async-iterator coroutine, as returned by `futures.apairs`.
---@param ... any Values to resume the iterator with.
---@return any ... The next yielded value(s), or nothing if the iterator finished.
---@async
local function futures_anext( iterator, ... )
    return handle_anext( iterator, futures_transfer( iterator, ACTION_RESUME, ... ) )
end

futures.anext = futures_anext

--- [SHARED AND MENU]
---
--- Iterates over async iterator, calling it with given arguments.
---
--- ## Example
--- ```lua
--- ---@async
--- ---@return AsyncIterator<number>
--- local function count( from, to )
---     for i = from, to do
---         futures.yield( i )
---     end
--- end
---
--- local function main()
---     for i in futures.apairs( count, 1, 5 ) do
---         print( i ) -- 1, 2, 3, 4, 5
---     end
--- end
---
--- futures.run( main )
--- ```
---
---@see dreamwork.std.futures.yield
---@see dreamwork.std.futures.AsyncIterator
---
---@generic K, V
---@param iterator async fun(...): dreamwork.std.futures.AsyncIterator<K, V> The async iterator function to drive.
---@param ... any Arguments to pass to `iterator`.
---@return async fun(...): K, V
---@return thread
---@async
local function futures_apairs( iterator, ... )
    local co = coroutine_create( async_iteratable_thread )
    AsyncListeners[ co ] = coroutine_running()
    coroutine_resume( co, iterator, ... )
    return futures_anext, co
end

futures.apairs = futures_apairs
std.apairs = futures_apairs

--- [SHARED AND MENU]
---
--- Collects all values from async iterator into a list.
---
---@generic V
---@param iterator async fun(...): dreamwork.std.futures.AsyncIterator<V> The async iterator to collect values from.
---@param ... any Arguments to pass to `iterator`.
---@return V[] results
---@return number length
---@async
function futures.collect( iterator, ... )
    local results, length = {}, 0
    for value in futures_apairs( iterator, ... ) do
        length = length + 1
        results[ length ] = value
    end

    return results, length
end

--- [SHARED AND MENU]
---
--- Collects all values from async iterator into a table.
---
---@generic K, V
---@param iterator async fun(...): dreamwork.std.futures.AsyncIterator<K, V> The async iterator to collect entries from.
---@param ... any Arguments to pass to `iterator`.
---@return table<K, V> result
---@async
function futures.collectTable( iterator, ... )
    local result = {}
    for k, v in futures_apairs( iterator, ... ) do
        result[ k ] = v
    end

    return result
end

do

    --- [SHARED AND MENU]
    ---
    --- Futures are objects that hold the result that can be assigned asynchronously
    --- they can be awaited to get the result
    --- or add callback with :addCallback(...) method.
    ---
    --- ```lua
    --- local fut = futures.Future()
    ---
    --- fut:addCallback( function( fut )
    ---     print( fut:result() ) -- "hello world"
    --- end )
    ---
    --- fut:setResult( "hello world" )
    ---
    --- -- or you can await it
    ---
    --- ---@async
    --- local function main()
    ---     print( fut:await() ) -- "hello world"
    --- end
    ---
    --- futures.run( main )
    ---
    --- -- also you can set error or cancel it
    --- fut:setError( "something went wrong" )
    --- fut:cancel()
    --- ```
    ---@class dreamwork.std.Future<T> : dreamwork.std.Object
    ---@field __class dreamwork.std.futures.FutureClass
    ---@field protected callbacks function[] The list of callbacks that will be called when future is done.
    ---@field protected state `0` | `1` | `2` `0` - PENDING, `1` - FINISHED, `2` - CANCELLED.
    ---@field protected result_value T The result value of the future.
    ---@field protected error_value string The error value of the future.
    local Future = std.Future and std.Future.__base or class.base( "Future" )

    ---@alias Future dreamwork.std.Future

    ---@protected
    function Future:__init()
        self.callbacks = { [ 0 ] = 0 }
        self.state = 0
    end

    ---@protected
    function Future:__tostring()
        local state = self.state
        if state ~= 0 then
            if state == 2 then
                return string_format( "Future: %p [cancelled]", self )
            elseif self.error_value then
                return string_format( "Future: %p [failure][%s]", self, tostring( self.error_value ) )
            end

            return string_format( "Future: %p [success][%s]", self, tostring( self.result_value ) )
        end

        return string_format( "Future: %p [pending]", self )
    end

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if Future is pending.
    ---
    ---@return boolean
    function Future:isPending()
        return self.state == 0
    end

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if Future is finished (or cancelled).
    ---
    ---@return boolean
    function Future:isFinished()
        return self.state ~= 0
    end

    --- [SHARED AND MENU]
    ---
    --- Returns true if Future was cancelled.
    ---
    ---@return boolean
    function Future:isCancelled()
        return self.state == 2
    end

    --- [SHARED AND MENU]
    ---
    --- Runs all callbacks.
    ---
    ---@private
    function Future:runCallbacks()
        local callbacks = self.callbacks
        self.callbacks = { [ 0 ] = 0 }

        for i = 1, callbacks[ 0 ], 1 do
            local success, error_message = pcall( callbacks[ i ], self )
            if not success then
                engine_hookCall( "dreamwork.lua.error", error_message, 3 )
            end
        end
    end

    --- [SHARED AND MENU]
    ---
    --- Adds callback that will be called when future is done
    --- if future is already done, callback will be called immediately.
    ---
    ---@see dreamwork.std.Future.removeCallback for removing callback
    ---
    ---@generic T
    ---@param self dreamwork.std.Future<T>
    ---@param fn fun( fut: dreamwork.std.Future<T> ) The callback to invoke with the future once it's done.
    function Future:addCallback( fn )
        if self.state ~= 0 then
            local success, error_message = pcall( fn, self )
            if not success then
                engine_hookCall( "dreamwork.lua.error", error_message, 3 )
            end

            return
        end

        local callbacks = self.callbacks
        local callback_count = callbacks[ 0 ]

        for i = callback_count, 1, -1 do
            if callbacks[ i ] == fn then
                callbacks[ callback_count ] = table_remove( callbacks, i )
                return
            end
        end

        callback_count = callback_count + 1
        callbacks[ callback_count ] = fn
        callbacks[ 0 ] = callback_count
    end

    --- [SHARED AND MENU]
    ---
    --- Removes callback that was previously added with `:addCallback`.
    ---
    ---@see dreamwork.std.Future.addCallback for adding callback
    ---
    ---@generic T
    ---@param self dreamwork.std.Future<T>
    ---@param fn function The callback previously passed to `:addCallback`.
    function Future:removeCallback( fn )
        local callbacks = self.callbacks
        local callback_count = callbacks[ 0 ]

        for i = callback_count, 1, -1 do
            if callbacks[ i ] == fn then
                table_remove( callbacks, i )
                callbacks[ 0 ] = callback_count - 1
                return
            end
        end
    end

    --- [SHARED AND MENU]
    ---
    --- Sets result of the Future, marks it as finished, and runs all callbacks
    --- if future is already finished, error will be thrown.
    ---
    ---@see dreamwork.std.Future.result to retrieve result
    ---@see dreamwork.std.Future.await to asynchronously retrieve result
    ---
    ---@generic T
    ---@param self dreamwork.std.Future<T>
    ---@param result T The value to resolve the future with.
    function Future:setResult( result )
        if self.state ~= 0 then
            error( "future is already finished", 2, false )
        end

        self.state = 1
        self.result_value = result

        self:runCallbacks()
    end

    --- [SHARED AND MENU]
    ---
    --- Sets error of the Future, marks it as finished, and runs all callbacks
    --- if future is already finished, error will be thrown.
    ---
    ---@param err string The error to fail the future with.
    function Future:setError( err )
        if self.state ~= 0 then
            error( "future is already finished", 2, false )
        end

        self.state = 1
        self.error_value = err

        self:runCallbacks()
    end

    --- [SHARED AND MENU]
    ---
    --- Tries to cancel future, if it's already done, returns `false`
    --- otherwise marks it as cancelled, runs all callbacks and returns `true`.
    ---
    ---@return boolean cancelled
    function Future:cancel()
        if self.state ~= 0 then
            return false
        end

        self.state = 2
        self:runCallbacks()
        return true
    end

    --- [SHARED AND MENU]
    ---
    --- Returns the future's error, if any:
    --- * if cancelled, returns "future was cancelled"
    --- * if still pending, returns "future is not finished"
    --- * if finished successfully, returns nil
    --- * if finished with an error, returns that error
    ---
    ---@see dreamwork.std.Future.setError
    ---@return string | nil
    function Future:error()
        local state = self.state
        if state == 2 then
            return "future was cancelled"
        elseif state == 0 then
            return "future is not finished"
        end

        return self.error_value
    end

    --- [SHARED AND MENU]
    ---
    --- Returns result if future is finished
    --- otherwise throws an error.
    ---
    ---@see dreamwork.std.Future.setResult
    ---@generic T
    ---@param self dreamwork.std.Future<T>
    ---@return T
    function Future:result()
        local state = self.state

        if state == 2 then
            error( "future was cancelled", 2, false )
        elseif state == 0 then
            error( "future is not finished", 2, false )
        end

        local error_value = self.error_value
        if error_value == nil then
            return self.result_value
        end

        error( error_value, 2, false )
    end

    --- [SHARED AND MENU]
    ---
    --- Await until future will be finished
    --- if it contains an error, then it will be thrown.
    ---
    ---@async
    ---@generic T
    ---@param self dreamwork.std.Future<T>
    ---@return T
    function Future:await()
        if self.state == 0 then
            local co = coroutine_running()
            if co == nil then
                error( "`Future:await` cannot be called outside async context.", 2, false )
            end

            self:addCallback( function()
                coroutine_resume( co )
            end )

            futures_pending()
        end

        if self.state == 0 then
            error( "future hasn't changed it's state wtf???", 2, false )
        end

        return self:result()
    end

    --- [SHARED AND MENU]
    ---
    --- The class used to create new `Future` instances.
    ---
    ---@class dreamwork.std.futures.FutureClass : dreamwork.std.Future
    ---@field __base dreamwork.std.Future
    ---@overload fun(): dreamwork.std.Future
    std.Future = class.create( Future )

end

do

    --- [SHARED AND MENU]
    ---
    --- Async task object.
    ---
    ---@class dreamwork.std.futures.Task<T> : dreamwork.std.Future
    ---@field __class dreamwork.std.futures.TaskClass
    ---@field __parent dreamwork.std.Future
    ---@field protected setResult fun( self: dreamwork.std.futures.Task<T>, result: T )
    ---@field protected setError fun( self: dreamwork.std.futures.Task<T>, error: self )
    ---@field addCallback fun( self: dreamwork.std.futures.Task<T>, callback: fun( task: dreamwork.std.futures.Task<T> ) )
    local Task = std.Task and std.Task.__base or class.base( "Task", false, std.Future )

    ---@diagnostic disable-next-line: duplicate-doc-alias
    ---@alias Task dreamwork.std.futures.Task

    ---@protected
    ---@param fn async fun(...): any
    function Task:__init( fn, ... )
        self.__parent.__init( self )

        futures_run( fn, function( ok, value )
            if ok then
                self:setResult( value )
            elseif value == ACTION_CANCEL then
                self:cancel()
            else
                self:setError( value )
            end
        end, ... )
    end

    --- [SHARED AND MENU]
    ---
    --- The class used to create new `Task` instances.
    ---
    --- Task is a Future wrapper around futures.run(...) to retrieve result of async function
    --- when task is created, it will immediately run given function.
    ---
    --- ## Example
    --- ```lua
    --- local function request( url )
    ---     -- asynchronous work....
    ---     return body
    --- end
    ---
    --- local task = futures.Task( request, "https://example.com" )
    --- task:addCallback( function( task )
    ---     local body = task:result()
    ---     print( body ) -- <!DOCTYPE html>...
    --- end )
    --- ```
    ---
    ---@class dreamwork.std.futures.TaskClass : dreamwork.std.futures.Task
    ---@field __base dreamwork.std.futures.Task
    ---@overload fun( fn: ( async fun( ...: any ): any ), ...: any ): dreamwork.std.futures.Task
    std.Task = class.create( Task )

end

do

    --- [SHARED AND MENU]
    ---
    --- A channel is a queue-type object that can be used by multiple coroutines.
    ---
    ---@class dreamwork.std.futures.Channel<T> : dreamwork.std.Object
    ---@field __class dreamwork.std.futures.ChannelClass
    ---@field max_size integer Maximum size of the channel.
    ---@field protected queue dreamwork.std.Queue<T> Queue of values.
    ---@field protected getters dreamwork.std.Queue<thread> Queue of getters.
    ---@field protected setters dreamwork.std.Queue<thread> Queue of setters.
    ---@field protected closed boolean `true` if the channel is closed, `false` otherwise.
    local Channel = std.Channel and std.Channel.__base or class.base( "Channel" )

    ---@protected
    ---@param max_size number? Maximum size of the channel.
    function Channel:__init( max_size )
        if max_size and max_size < 0 then
            error( "`max_size` must be greater or equal to 0", 2, false )
        end

        self.max_size = max_size or 0
        self.queue = Queue()
        self.getters = Queue()
        self.setters = Queue()
        self.closed = false
    end

    ---@return integer
    ---@protected
    function Channel:__len()
        return len( self.queue )
    end

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if the channel is empty, `false` otherwise.
    ---
    ---@return boolean isEmpty
    function Channel:isEmpty()
        return self.queue:isEmpty()
    end

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if the channel is full, `false` otherwise.
    ---
    ---@return boolean isFull
    function Channel:isFull()
        local max_size = self.max_size
        if max_size == 0 then
            return false
        end

        return len( self.queue ) >= max_size
    end

    --- [SHARED AND MENU]
    ---
    --- Closes the channel.
    ---
    function Channel:close()
        self.closed = true

        -- wake up all getters and setters
        local getters = self.getters
        while not getters:isEmpty() do
            ---@diagnostic disable-next-line: param-type-mismatch
            coroutine_resume( getters:pop() )
        end

        local setters = self.setters
        while not setters:isEmpty() do
            ---@diagnostic disable-next-line: param-type-mismatch
            coroutine_resume( setters:pop() )
        end
    end

    --- [SHARED AND MENU]
    ---
    --- Returns `true` if the channel is closed, `false` otherwise.
    ---
    ---@return boolean isClosed
    function Channel:isClosed()
        return self.closed
    end

    --- [SHARED AND MENU]
    ---
    --- Puts a value into the channel.
    ---
    ---@generic T
    ---@param self dreamwork.std.futures.Channel<T>
    ---@param value T The value to push. Must not be `nil`.
    ---@param force boolean? If `true`, push without waiting for space, bypassing the max-size check.
    ---@return boolean success
    function Channel:push( value, force )
        if value == nil then
            return false
        end

        if force ~= true then
            local co = coroutine_running()
            if co == nil then
                error( "`Channel:push` cannot be called outside async context without `force`.", 2, false )
            end

            while (self:isFull() and not self.closed) do
                self.setters:push( co )
                futures_pending()
            end
        end

        if self:isFull() or self.closed then
            return false
        end

        self.queue:push( value )

        local getter = self.getters:pop()
        if getter then
            coroutine_resume( getter )
        end

        return true
    end

    --- [SHARED AND MENU]
    ---
    --- Gets a value from the channel.
    ---
    ---@generic T
    ---@param self dreamwork.std.futures.Channel<T>
    ---@param force boolean? If `true`, pop without waiting for a value even if the channel is empty.
    ---@return T | nil value
    function Channel:pop( force )
        if force ~= true then
            local co = coroutine_running()
            if co == nil then
                error( "`Channel:pop` cannot be called outside async context without `force`.", 2, false )
            end

            while self:isEmpty() and not self.closed do
                self.getters:push( co )
                futures_pending()
            end
        end

        if self:isEmpty() or self.closed then
            return nil
        end

        local value = self.queue:pop()

        local setter = self.setters:pop()
        if setter then
            coroutine_resume( setter )
        end

        return value
    end

    --- [SHARED AND MENU]
    ---
    --- The class used to create new `Channel` instances.
    ---
    --- A channel is a queue-type class that can be used by multiple coroutines.
    ---
    ---@class dreamwork.std.futures.ChannelClass : dreamwork.std.futures.Channel
    ---@field __base dreamwork.std.futures.Channel
    ---@overload fun( maxsize: number? ): dreamwork.std.futures.Channel
    std.Channel = class.create( Channel )

end

--- [SHARED AND MENU]
---
--- Awaits concurrently all given `awaitables` and returns results in table.
---
---@async
---@param awaitables Awaitable[]
---@return any[]
local function awaitList( awaitables )
    local results = {}
    for i = 1, len( awaitables ), 1 do
        results[ i ] = awaitables[ i ]:await()
    end

    return results
end

--- [SHARED AND MENU]
---
--- Cancels all given awaitables.
---
---@param awaitables (Awaitable | { cancel: function })[]
local function cancelList( awaitables )
    for i = 1, len( awaitables ), 1 do
        local awaitable = awaitables[ i ]
        if isFunction( awaitable.cancel ) then
            awaitable:cancel()
        end
    end
end

--- [SHARED AND MENU]
---
--- Awaits all given `awaitables` (in order) and returns their results in a table.
---
--- Each item must implement `:await()` (e.g. Future/Task) — plain functions are not supported.
---
--- If any awaitable throws, the error is re-thrown and all remaining awaitables are cancelled.
---
---@param awaitables Awaitable[] The list of awaitables (e.g. Future/Task instances) to await.
---@return any[]
---@async
function futures.all( awaitables )
    local ok, result = pcall( awaitList, awaitables )
    if ok then
        return result
    end

    cancelList( awaitables )
    error( result, 2, false )
end

--- [SHARED AND MENU]
---
--- Returns first result of futures, or error.
---
--- Other awaitables will be cancelled after first result or error.
---
---@param futureList Future[] The list of futures to race against each other.
---@return any
---@async
function futures.any( futureList )
    local co = coroutine_running()
    if co == nil then
        error( "`futures.any` cannot be called outside async context.", 2, false )
    end

    local finished = false

    local function callback( fut )
        if not finished then
            finished = true
            coroutine_resume( co, fut )
        end
    end

    for i = 1, len( futureList ), 1 do
        futureList[ i ]:addCallback( callback )
    end

    ---@type Future
    local fut = futures_pending()
    cancelList( futureList )
    return fut:result()
end

--- [SHARED AND MENU]
---
--- Puts current thread to sleep for given amount of seconds.
---
---@see dreamwork.std.futures.pending
---@see dreamwork.std.futures.wakeup
---
---@param seconds number How long to sleep, in seconds.
---@async
function futures.sleep( seconds )
    local co = coroutine_running()
    if co == nil then
        error( "`futures.sleep` cannot be called outside async context.", 2, false )
    end

    ---@cast co thread
    setTimeout( function()
        coroutine_resume( co )
    end, seconds )

    futures_pending()
end

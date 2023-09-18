--[[
    MIT License

    Copyright (c) 2023 Retro

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

--[[
    A library that mostly implements Promise/A+ specification for GLua
    https://github.com/dankmolot/gm_promise

    Documentation can be found at: https://github.com/dankmolot/gm_promise
    This version gm_promise was specially modified by PrikolMen:-b for GPM.
]]

local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local string_format = string.format
local getmetatable = getmetatable
local setmetatable = setmetatable
local timer_Simple = timer.Simple
local table_insert = table.insert
local ErrorNoHalt = ErrorNoHalt
local isfunction = isfunction
local coroutine = coroutine
local tostring = tostring
local istable = istable
local ipairs = ipairs
local xpcall = xpcall
local error = error
local type = type

local developerMode = GetConVar( "developer" ):GetInt() > 0
cvars.AddChangeCallback( "developer", function( _, __, new )
    developerMode = ( tonumber( new ) or 0 ) > 0
end )

-- local promise = gpm.promise
-- if type( promise ) ~= "table" then
--     promise = {}; gpm.promise = promise
-- end

module( "promise" )
VERSION = "1.5.0"

local function PromiseErrorHandler( ... )
    if developerMode then
        ErrorNoHaltWithStack( ... )
    end

    return ...
end

local PROMISE_PENDING = 0
local PROMISE_REJECTED = 1
local PROMISE_FULFILLED = 2

_M.PROMISE_PENDING = PROMISE_PENDING
_M.PROMISE_REJECTED = PROMISE_REJECTED
_M.PROMISE_FULFILLED = PROMISE_FULFILLED

VALID_STATES = {
    [ PROMISE_PENDING ] = true,
    [ PROMISE_REJECTED ] = true,
    [ PROMISE_FULFILLED ] = true
}

-- Promise object
do

    if type( PROMISE ) ~= "table" then
        PROMISE = {}
    end

    PROMISE.__index = PROMISE

    function PROMISE:GetResult() return self.result end
    function PROMISE:GetState() return self.state end

    function PROMISE:IsPending() return PROMISE.GetState( self ) == PROMISE_PENDING end
    function PROMISE:IsFulfilled() return PROMISE.GetState( self ) == PROMISE_FULFILLED end
    function PROMISE:IsRejected() return PROMISE.GetState( self ) == PROMISE_REJECTED end

    function PROMISE:__tostring()
        if PROMISE.GetResult( self ) == nil then
            return string_format( "Promise %p {<%s>}", self, PROMISE.GetState( self ) )
        end

        return string_format( "Promise %p {<%s>: %s}", self, PROMISE.GetState( self ), tostring( PROMISE.GetResult( self ) ) )
    end

    function PROMISE:ProcessQueue()
        if PROMISE.IsPending( self ) then return end

        if not self.processed and #self.queue == 0 then
            if PROMISE.IsRejected( self ) then
                ErrorNoHalt( "Unhandled promise error: " .. tostring( PROMISE.GetResult( self ) ) .. "\n\n" )
            end

            return
        end

        self.processed = true

        for index, promise in ipairs( self.queue ) do
            self.queue[ index ] = nil

            local isFulfilled = PROMISE.IsFulfilled( self )

            local handler, ok, result = isFulfilled and promise.OnFulfill or promise.OnReject
            if handler then
                ok, result = xpcall( handler, PromiseErrorHandler, PROMISE.GetResult( self ) )
            else
                ok, result = isFulfilled, PROMISE.GetResult( self )
            end

            if ok then
                PROMISE.Resolve( promise, result )
            else
                PROMISE.Reject( promise, result )
            end
        end
    end

    function PROMISE:ChangeState( state, value )
        if not PROMISE.IsPending( self ) or PROMISE.GetState( self ) == state or not VALID_STATES[ state ] then return end
        self.state, self.result = state, value

        if PROMISE.IsFulfilled( self ) then
            PROMISE.ProcessQueue( self )
            return
        end

        -- We must wait for reject handlers, so we won't throw error about unhandler error
        timer_Simple( 0, function()
            if self.processed then return end
            PROMISE.ProcessQueue( self )
        end )
    end

    function PROMISE:Resolve( promise )
        if self == promise then
            return PROMISE.Reject( self, "promise fulfill value refer to promise itself" )
        end

        if IsThenable( promise ) then
            if IsPromise( promise ) and not PROMISE.IsPending( promise ) then
                table_insert( promise.queue, self )
                PROMISE.ProcessQueue( promise )
                return
            end

            -- A little hack for thenable objects
            local called = false
            local function onFulfill( value )
                if called then return end
                called = true

                return PROMISE.Resolve( self, value )
            end

            local function onReject( msg )
                if called then return end
                called = true

                return PROMISE.Reject( self, msg )
            end

            local ok, msg = xpcall( function()
                PROMISE.Then( promise, onFulfill, onReject )
            end, PromiseErrorHandler )

            if not ok then OnReject( msg ) end
            return
        end

        PROMISE.ChangeState( self, PROMISE_FULFILLED, promise )
    end

    function PROMISE:Reject( msg )
        PROMISE.ChangeState( self, PROMISE_REJECTED, msg )
    end

    function PROMISE:Then( onFulfill, onReject )
        local promise = New()
        if isfunction( onFulfill ) then
            promise.OnFulfill = onFulfill
        end

        if isfunction( onReject ) then
            promise.OnReject = onReject
        end

        table_insert( self.queue, promise )
        PROMISE.ProcessQueue( self )
        return promise
    end

    function PROMISE:Catch( onReject )
        return PROMISE.Then( self, nil, onReject )
    end

    function PROMISE:SafeAwait()
        local co = coroutine.running()
        if not co then
            return false, "await only works in coroutines or async functions!"
        end

        if PROMISE.IsPending( self ) then
            local function resume()
                coroutine.resume( co )
            end

            PROMISE.Then( self, resume, resume )
            coroutine.yield()
        end

        self.processed = true
        return PROMISE.IsFulfilled( self ), PROMISE.GetResult( self )
    end

    function PROMISE:Await( ignoreErrors )
        local ok, result = PROMISE.SafeAwait( self )
        if not ok then
            if not ignoreErrors then
                return error( result, 2 )
            end

            return
        end

        return result
    end

end

function IsThenable( obj )
    return istable( obj ) and isfunction( obj.Then )
end

function IsAwaitable( obj )
    return istable( obj ) and isfunction( obj.Await )
end

function IsPromise( obj )
    return getmetatable( obj ) == PROMISE
end

function RunningInAsync()
    return coroutine.running()
end

-- Creates new promise object
function New( func )
    local promise = setmetatable( {
        ["state"] = PROMISE_PENDING,
        ["queue"] = {}
    }, PROMISE )

    -- TODO: args
    if func then
        func( function( value )
            PROMISE.Resolve( promise, value )
        end, function( msg )
            PROMISE.Reject( promise, msg )
        end )
    end

    return promise
end

function Async( func )
    return function( ... )
        local promise = New()

        coroutine.resume( coroutine.create( function( self, ... )
            local ok, result = xpcall( func, PromiseErrorHandler, ... )
            if ok then
                PROMISE.Resolve( self, result )
                return
            end

            PROMISE.Reject( self, result )
        end ), promise, ... )

        return promise
    end
end

function SafeAwait( promise )
    if IsPromise( promise ) then
        return PROMISE.SafeAwait( promise )
    end

    return true, promise
end

function Await( promise, ignoreErrors )
    if IsAwaitable( promise ) then
        return PROMISE.Await( promise, ignoreErrors )
    end

    return promise
end

function Delay( time )
    return New( function( resolve )
        timer_Simple( time, resolve )
    end )
end

function Sleep( delay )
    if not RunningInAsync() then
        error( "sleep should be performed in the coroutine/async function" )
    end

    PROMISE.SafeAwait( Delay( delay or 0 ) )
end

function Resolve( value )
    if IsPromise( value ) then
        return value
    end

    return New( function( resolve )
        resolve( value )
    end )
end

function Reject( msg )
    if IsPromise( msg ) then
        return msg
    end

    return New( function( _, reject )
        reject( msg )
    end )
end

function All( promises )
    if #promises == 0 then
        return Resolve( promises )
    end

    local results, count = {}, #promises
    local new_promise = New()

    local onFulfill = function( index )
        return function( value )
            if not PROMISE.IsPending( new_promise ) then return end
            results[ index ] = value

            if #results ~= count then return end
            PROMISE.Resolve( new_promise, results )
        end
    end

    local function onReject( msg )
        if not PROMISE.IsPending( new_promise ) then return end
        PROMISE.Reject( new_promise, msg )
    end

    for index, promise in ipairs( promises ) do
        if IsThenable( promise ) then
            PROMISE.Then( promise, onFulfill( index ), onReject )
            continue
        end

        results[ index ] = PROMISE.GetResult( promise )
    end

    return new_promise
end

function Race( promises )
    if #promises == 0 then
        return Resolve( promises )
    end

    local new_promise = New()

    local function onFulfill( value )
        if not PROMISE.IsPending( new_promise ) then return end
        PROMISE.Resolve( new_promise, value )
    end

    local function onReject( msg )
        if not PROMISE.IsPending( new_promise ) then return end
        PROMISE.Reject( new_promise, msg )
    end

    for _, promise in ipairs( promises ) do
        if not IsThenable( promise ) then continue end
        PROMISE.Then( promise, onFulfill, onReject )
    end

    return new_promise
end

return _M
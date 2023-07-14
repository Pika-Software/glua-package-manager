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
local Either = Either
local xpcall = xpcall
local error = error
local _HTTP = HTTP

local developer = GetConVar( "developer" )

module( "promise" )
VERSION = "1.4.1"

local function PromiseErrorHandler(...)
    if developer:GetInt() > 0 then
        ErrorNoHaltWithStack(...)
    end

    return ...
end

-- Promise object
do
    local VALID_STATES = {
        ["pending"] = true,
        ["fulfilled"] = true,
        ["rejected"] = true,
    }

    PROMISE = PROMISE or {}
    PROMISE.__index = PROMISE

    function PROMISE:GetState()
        return self.state or "pending"
    end
    function PROMISE:IsPending() return self:GetState() == "pending" end
    function PROMISE:IsFulfilled() return self:GetState() == "fulfilled" end
    function PROMISE:IsRejected() return self:GetState() == "rejected" end

    function PROMISE:GetResult()
        return self.result
    end

    function PROMISE:__tostring()
        if self:GetResult() == nil then return string_format("Promise %p {<%s>}", self, self:GetState()) end
        return string_format( "Promise %p {<%s>: %s}", self, self:GetState(), tostring(self:GetResult()) )
    end

    function PROMISE:_ProcessQueue()
        if self:IsPending() then return end
        if not self._processed and #self._queue == 0 then
            if self:IsRejected() then ErrorNoHalt("Unhandled promise error: " .. tostring(self:GetResult()) .. "\n\n") end
            return
        end

        self._processed = true

        for i, promise in ipairs(self._queue) do
            self._queue[i] = nil
            local handler = Either(self:IsFulfilled(), promise._OnFulfill, promise._OnReject)

            local ok, result
            if handler then
                ok, result = xpcall(handler, PromiseErrorHandler, self:GetResult())
            else
                ok, result = self:IsFulfilled(), self:GetResult()
            end

            if ok then
                promise:Resolve(result)
            else
                promise:Reject(result)
            end
        end
    end

    function PROMISE:_ChangeState(state, value)
        if not self:IsPending() or self:GetState() == state or not VALID_STATES[state] then return end
        self.state = state
        self.result = value

        if self:IsFulfilled() then
            self:_ProcessQueue()
        else
            -- We must wait for reject handlers, so we won't throw error about unhandler error
            timer_Simple(0, function()
                if not self._processed then
                    self:_ProcessQueue()
                end
            end)
        end
    end

    function PROMISE:Resolve(value)
        if self == value then return self:Reject("promise fulfill value refer to promise itself") end
        if IsThenable(value) then
            if IsPromise(value) and not value:IsPending() then
                table_insert(value._queue, self)
                value:_ProcessQueue()
            return end

            -- A little hack for thenable objects
            local called = false
            local function onFulfill(result)
                if called then return end
                called = true
                return self:Resolve(result)
            end

            local function onReject(err)
                if called then return end
                called = true
                return self:Reject(err)
            end

            local ok, err = xpcall(function()
                value:Then(onFulfill, onReject)
            end, PromiseErrorHandler)

            if not ok then OnReject(err) end
        return end

        self:_ChangeState("fulfilled", value)
    end

    function PROMISE:Reject(value)
        self:_ChangeState("rejected", value)
    end

    function PROMISE:Then(onFulfill, onReject)
        local promise = New()
        if isfunction(onFulfill) then
            promise._OnFulfill = onFulfill
        end

        if isfunction(onReject) then
            promise._OnReject = onReject
        end

        table_insert(self._queue, promise)
        self:_ProcessQueue()

        return promise
    end

    function PROMISE:Catch(onReject)
        return self:Then(nil, onReject)
    end

    function PROMISE:SafeAwait()
        local co = coroutine.running()
        if not co then return false, ":Await() only works in coroutines or async functions!" end

        if self:IsPending() then
            local function resume()
                coroutine.resume(co)
            end

            self:Then(resume, resume)

            coroutine.yield()
        end

        self._processed = true
        return self:IsFulfilled(), self:GetResult()
    end

    function PROMISE:Await(ignoreErrors)
        local ok, result = self:SafeAwait()
        if not ok then
            if not ignoreErrors then return error(result, 2) end
        return end

        return result
    end
end

function IsThenable(obj)
    return istable(obj) and isfunction(obj.Then)
end

function IsAwaitable(obj)
    return istable(obj) and isfunction(obj.Await)
end

function IsPromise(obj)
    return getmetatable(obj) == PROMISE
end

function RunningInAsync()
    return coroutine.running()
end

-- Creates new promise object
function New(func)
    local promise = setmetatable({}, PROMISE)
    promise._queue = {}

    if isfunction(func) then
        local function resolve(value)
            promise:Resolve(value)
        end

        local function reject(err)
            promise:Reject(err)
        end

        func(resolve, reject)
    end

    return promise
end

function Async(func)
    if not isfunction(func) then return end

    local function run(p, ...)
        local ok, result = xpcall(func, PromiseErrorHandler, ...)
        if ok then
            p:Resolve(result)
        else
            p:Reject(result)
        end
    end

    return function(...)
        local p = New()

        local co = coroutine.create(run)
        coroutine.resume(co, p, ...)

        return p
    end
end

function SafeAwait(p)
    if IsPromise(p) then return p:SafeAwait() end
    return true, p
end

function Await(p, ignoreErrors)
    if IsAwaitable(p) then return p:Await(ignoreErrors) end
    return p
end

function Delay(time)
    return New(function(resolve) timer_Simple(time, resolve) end)
end

function Resolve(value)
    if IsPromise(value) then return value end
    return New(function(resolve) resolve(value) end)
end

function Reject(err)
    if IsPromise(value) then return value end
    return New(function(_, reject) reject(err) end)
end

function All(promises)
    if #promises == 0 then return Resolve({}) end

    local new_promise = New()

    local results = {}
    local calls = 0
    local totalCalls = #promises

    local onFulfill = function(i)
        return function(result)
            if not new_promise:IsPending() then return end
            results[i] = result
            calls = calls + 1

            if calls == totalCalls then
                new_promise:Resolve(results)
            end
        end
    end

    local function onReject(err)
        if new_promise:IsPending() then new_promise:Reject(err) end
    end

    for i, p in ipairs(promises) do
        if IsThenable(p) then
            p:Then( onFulfill(i), onReject )
        else
            results[i] = result
            calls = calls + 1
        end
    end

    return new_promise
end

function Race(promises)
    if #promises == 0 then return Resolve({}) end

    local new_promise = New()

    local onFulfill = function(result)
        if new_promise:IsPending() then new_promise:Resolve(result) end
    end

    local onReject = function(err)
        if new_promise:IsPending() then new_promise:Reject(err) end
    end

    for i, p in ipairs(promises) do
        if IsThenable(p) then
            p:Then(onFulfill, onReject)
        end
    end

    return new_promise
end

-- Async version of HTTP
function HTTP(parameters)
    local p = New()

    parameters.success = function(code, body, headers)
        p:Resolve({
            code = code,
            body = body,
            headers = headers
        })
    end
    parameters.failed = function(err)
        p:Reject(err)
    end

    local ok = _HTTP(parameters)
    if not ok then p:Reject("failed to make http request") end
    return p
end

function Sleep( delay )
    if not RunningInAsync() then
        error( "sleep should be performed in the coroutine/async function" )
    end

    Delay( delay ):SafeAwait()
end
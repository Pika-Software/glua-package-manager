-- Promise implementation from Lua close to a specification Promise/A+
-- made by Retro ;)
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
local assert = assert
local error = error
local pcall = pcall
local error = error

module( "gpm.promise" )

do -- Promise object
    local function DefaultFulfillCallback(value) return value end
    local function DefaultRejectCallback(err) error(err) end

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
            if self:IsRejected() then ErrorNoHalt("Unhandler promise error: " .. tostring(self:GetResult()) .. "\n\n") end
            return
        end

        self._processed = true

        for i, promise in ipairs(self._queue) do
            self._queue[i] = nil
            local handler = self:IsFulfilled() and (promise._OnFulfill or DefaultFulfillCallback) or (promise._OnReject or DefaultRejectCallback)

            local ok, result = pcall(handler, self:GetResult())
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
            -- We must wait for reject handlers
            timer_Simple(0, function() self:_ProcessQueue() end)
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

            local ok, err = pcall(function()
                value:Then(onFulfill, onReject)
            end)

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

    function PROMISE:Await()
        local co = coroutine.running()
        assert(co, ":Await() only works in coroutines or async functions!")

        if self:IsPending() then
            local function resume()
                coroutine.resume(co)
            end

            self:Then(resume, resume)

            coroutine.yield()
        end

        local result = self:GetResult()
        assert(self:IsFulfilled(), result)

        return result
    end
end -- Promise object

function IsThenable(obj)
    return istable(obj) and isfunction(obj.Then)
end

function IsAwaitable(obj)
    return istable(obj) and isfunction(obj.Await)
end

function IsPromise(obj)
    return getmetatable(obj) == PROMISE
end

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
        local ok, result = pcall(func, ...)
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

function Await(p)
    if IsAwaitable(p) then return p:Await() end
end

function Delay(time)
    return New(function(resolve) timer_Simple(time, resolve) end)
end

function Resolve(value)
    if IsPromise(value) then return value end
    return Promise(function(resolve) resolve(value) end)
end

function Reject(err)
    if IsPromise(value) then return value end
    return Promise(function(_, reject) reject(err) end)
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
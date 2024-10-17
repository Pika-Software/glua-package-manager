local gpm, setmetatable = _G.gpm, _G.setmetatable
local environment, string, RuntimeError, FutureError, FutureCancelError, TypeError, InvalidStateError = gpm.environment, gpm.string, gpm.RuntimeError, gpm.FutureError, gpm.FutureCancelError, gpm.TypeError, gpm.InvalidStateError
local throw, iserror, isstring, isnumber, isthread, isfunction, tostring, type, getmetatable, xpcall, pcall = gpm.throw, gpm.iserror, gpm.isstring, gpm.isnumber, gpm.isthread, gpm.isfunction, gpm.tostring, gpm.type, gpm.getmetatable, gpm.xpcall, gpm.pcall
local match = string.match
local futures = environment.futures
if not futures then
	futures = { }
	environment.futures = futures
	futures.listeners = { }
	setmetatable(futures.listeners, {
		__mode = "kv"
	})
end
local listeners = futures.listeners
local ACTION_RUN = 1
futures.ACTION_RUN = 1
local ACTION_ITERATE = 2
futures.ACTION_ITERATE = 2
local ACTION_CANCEL = 3
futures.ACTION_CANCEL = 3
local ACTION_WAKEUP = 4
futures.ACTION_WAKEUP = 4
local RESULT_FINISHED = 6
futures.RESULT_FINISHED = 6
local RESULT_FAILED = 7
futures.RESULT_FAILED = 7
local RESULT_PENDING = 8
futures.RESULT_PENDING = 8
local RESULT_YIELDING = 9
futures.RESULT_YIELDING = 9
local RESULT_CANCELLED = 10
futures.RESULT_CANCELLED = 10
-- low level API to control coroutines
-- also allows to use coroutines symmetricaly
local coro = { }
futures.coro = coro
local coroCreate = coroutine.create
coro.create = coroCreate
local coroStatus = coroutine.status
coro.status = coroStatus
local coroRunning = coroutine.running
coro.running = coroRunning
local coroResume = coroutine.resume
coro.resume = coroResume
local coroYield = coroutine.yield
coro.yield = coroYield
-- transforms RESULT_FAILED into error
local handleTransfer
handleTransfer = function(ok, value, ...)
	if ok and value == RESULT_FAILED then
		return false, ...
	end
	return ok, value, ...
end
-- low level API for symmetrically transfering data between coroutines
-- if thread == nil then coro.yield(...) is called
local coroTransfer
coroTransfer = function(thread, ...)
	local status = thread and coroStatus(thread) or "normal"
	if status == "normal" then
		return handleTransfer(true, coroYield(...))
	end
	if status == "suspended" then
		return handleTransfer(coroResume(thread, ...))
	end
	if status == "dead" then
		return false, FutureError("coro.transfer(...): thread '" .. tostring(thread) .. "' is dead, unable to transfer data to it")
	end
	if status == "running" then
		return false, FutureError("coro.transfer(...): running == thread")
	end
	return false, FutureError("coro.transfer(...): unknown status '" .. tostring(status) .. "' for thread '" .. tostring(thread) .. "'")
end
coro.transfer = coroTransfer
local isCancel
isCancel = function(err)
	return iserror(err, "FutureCancelError")
end
local transformError
transformError = function(err)
	if isnumber(err) then
		err = tostring(err)
	end
	if isstring(err) then
		local file, line, message = match(err, "^([A-Za-z0-9%-_/.]+):(%d+): (.*)")
		if file and line then
			err = RuntimeError(message, file, line, 5)
		else
			err = RuntimeError(err, nil, nil, 4)
			err.fileName = nil
			err.lineNumber = nil
		end
	end
	return err
end
local displayError
displayError = function(err)
	if iserror(err) then
		return err:display()
	end
	return RuntimeError.display(err)
end
local asyncBackgroundThread
asyncBackgroundThread = function(silent, ok, err)
	if not silent and not ok then
		return displayError(err)
	end
	return RESULT_FINISHED
end
local asyncIteratableThread
asyncIteratableThread = function(ok, value, ...)
	local current = coroRunning()
	local listener = listeners[current]
	local result = ok and RESULT_FINISHED or RESULT_FAILED
	if not ok and iserror(value, "FutureCancelError") then
		ok = true
		result = RESULT_CANCELLED
	end
	if isthread(listener) then
		local status = coroStatus(listener)
		if status == "normal" then
			return result, value, ...
		end
		if status == "suspended" then
			coroResume(listener, result, value, ...)
			return
		end
		if status == "dead" or status == "running" then
			displayError(FutureError("listener '" .. tostring(listener) .. "' is dead/running, cannot return result"))
			return
		end
	end
	if isfunction(listener) then
		if not ok then
			listener(current, false, value, ...)
		else
			listener(current, true, result, value, ...)
		end
		return
	end
	displayError(FutureError("async function in thread '" .. tostring(current) .. "' has invalid listener '" .. tostring(listener) .. "'"))
	return
end
local asyncThread
asyncThread = function(fn, ...)
	local action, value = coroYield()
	if action == ACTION_RUN then
		-- run async thread in background, and display error unless specified to be silent
		return asyncBackgroundThread(value == nil and true or value, xpcall(fn, transformError, ...))
	end
	if action == ACTION_ITERATE then
		if not (isthread(value) or isfunction(value)) then
			throw(transformError(FutureError("async function '" .. tostring(fn) .. "' was started with invalid listener '" .. tostring(value) .. "'")))
		end
		listeners[coroRunning()] = value
		return asyncIteratableThread(xpcall(fn, transformError, ...))
	end
	if action == ACTION_CANCEL then
		return RESULT_CANCELLED, value or FutureCancelError()
	end
	throw(transformError(FutureError("async function '" .. tostring(fn) .. "' was started with invalid action '" .. tostring(action) .. "'")))
	return
end
do
	local _tmp_0
	_tmp_0 = function(fn)
		return function(...)
			local thread = coroCreate(asyncThread)
			local ok, err = coroResume(thread, fn, ...)
			if ok then
				return thread
			end
			return throw(err)
		end
	end
	environment.async = _tmp_0
	futures.async = _tmp_0
end
futures.run = function(thread, callback)
	if not isthread(thread) then
		return throw(TypeError("run(...) expects a thread, got " .. tostring(type(thread))))
	end
	if callback then
		if not isfunction(callback) then
			return throw(TypeError("run(...) expects a function as a callback, got " .. tostring(type(callback))))
		end
		coroResume(thread, ACTION_ITERATE, callback)
		return
	end
	coroResume(thread, ACTION_RUN)
	return
end
local yieldInner
yieldInner = function(current, listener, ok, action, value, ...)
	if not ok then
		if isCancel(action) then
			return throw(action)
		end
		-- error happened in async thread
		-- so async thread must handle it, not us
		return throw(FutureCancelError("unexpected error happened in async thread"))
	end
	if action == ACTION_ITERATE then
		if value and listener ~= value then
			listeners[current] = value
		end
		return ...
	end
	if action == ACTION_CANCEL then
		-- listener cancelled us :(((
		throw(value or FutureCancelError())
	end
	return throw(FutureError("unexpected action '" .. tostring(action) .. "' from listener '" .. tostring(listener) .. "'"))
end
do
	local _tmp_0
	_tmp_0 = function(...)
		local current = coroRunning()
		if not current then
			return throw(FutureError("yield(...) cannot be called outside of async function"))
		end
		local listener = listeners[current]
		if isthread(listener) then
			return yieldInner(current, listener, coroTransfer(listener, RESULT_YIELDING, ...))
		end
		if isfunction(listener) then
			return listener(current, true, RESULT_YIELDING, ...)
		end
		return throw(FutureError("yield(...) was called, but listener is invalid ('" .. tostring(listener) .. "')"))
	end
	environment.yield = _tmp_0
	futures.yield = _tmp_0
end
futures.cancel = function(thread)
	local current = coroRunning()
	if not current then
		return throw(FutureError("cancel(...) cannot be called outside of async function"))
	end
	if not isthread(thread) then
		local meta = getmetatable(thread)
		if meta and meta.__acancel then
			return meta.__acancel(thread, current)
		end
		return throw(TypeError("cancel(...) expects a thread, got '" .. tostring(thread) .. "'"))
	end
	local ok = coroTransfer(thread, ACTION_CANCEL, FutureCancelError())
	return ok
end
local anextInner
anextInner = function(ok, result, ...)
	if not ok then
		return throw(result)
	end
	if result == RESULT_YIELDING then
		return ...
	end
	if result == RESULT_FINISHED or result == RESULT_CANCELLED then
		return
	end
	if result == RESULT_PENDING then
		return anextInner(coroTransfer(nil, RESULT_PENDING))
	end
	throw(FutureError("unexpected result '" .. tostring(result) .. "' in anext(...)"))
	return
end
local anext
anext = function(thread, ...)
	local current = coroRunning()
	if not current then
		return throw(FutureError("anext(...) cannot be called outside of async function"))
	end
	if not isthread(thread) then
		-- support for custom defined async iterators
		local meta = getmetatable(thread)
		if meta and meta.__aiter then
			return meta.__aiter(thread, current)
		end
		return throw(TypeError("anext(...) expects a thread, got '" .. tostring(thread) .. "'"))
	end
	return anextInner(coroTransfer(thread, ACTION_ITERATE, current, ...))
end
environment.anext = anext
futures.anext = anext
do
	local _tmp_0
	_tmp_0 = function(thread, ...)
		return anext, thread, ...
	end
	environment.apairs = _tmp_0
	futures.apairs = _tmp_0
end
local awaitInner
awaitInner = function(thread, ok, result, ...)
	if not ok then
		return throw(result)
	end
	if result == RESULT_FINISHED then
		return ...
	end
	if result == RESULT_PENDING then
		return awaitInner(thread, coroTransfer(nil, RESULT_PENDING))
	end
	if result == RESULT_CANCELLED then
		return
	end
	if result == RESULT_YIELDING then
		futures.cancel(thread)
		return throw(FutureError("unable await(...) async generator"))
	end
	throw(FutureError("unexpected result '" .. tostring(result) .. "' in await(...)"))
	return
end
local await
await = function(thread)
	local current = coroRunning()
	if not current then
		return throw(FutureError("await(...) cannot be called outside of async function"))
	end
	if not isthread(thread) then
		-- support for custom defined awaitables
		local meta = getmetatable(thread)
		if meta and meta.__await then
			return meta.__await(thread, current)
		end
		return throw(TypeError("await(...) expects a thread, got '" .. tostring(thread) .. "'"))
	end
	return awaitInner(thread, coroTransfer(thread, ACTION_ITERATE, current))
end
environment.await = await
futures.await = await
do
	local _tmp_0
	_tmp_0 = function(thread)
		return pcall(await, thread)
	end
	environment.pawait = _tmp_0
	futures.pawait = _tmp_0
end
local isawaitable
isawaitable = function(any)
	if isthread(any) then
		return true
	end
	local meta = getmetatable(any)
	return meta and meta.__await
end
environment.isawaitable = isawaitable
futures.isawaitable = isawaitable
-- Suspends current coroutine until futures.continue(...) is called
-- Used internally by Future
local pending
pending = function()
	if not coroRunning() then
		return throw(FutureError("futures.pending() cannot be called outside of async function"))
	end
	local action, value = coroYield(RESULT_PENDING)
	if action == ACTION_CANCEL then
		return throw(value or FutureCancelError())
	end
	if action == ACTION_WAKEUP then
		return value
	end
	return throw(FutureError("unexpected action '" .. tostring(action) .. "' in futures.pending(...)"))
end
futures.pending = pending
-- Resumes coroutine that was waiting with futures.pending(...)
-- You also can optionally pass a value to it
-- Used internally by Future
local wakeup
wakeup = function(thread, value)
	coroResume(thread, ACTION_WAKEUP, value)
	return
end
futures.wakeup = wakeup
do
	local FUTURE_STATE_PENDING = 1
	local FUTURE_STATE_FINISHED = 2
	local FUTURE_STATE_CANCELLED = 3
	local _runCallbacks
	_runCallbacks = function(self)
		local callbacks = self._callbacks
		if not callbacks then
			return
		end
		self._callbacks = { }
		for _index_0 = 1, #callbacks do
			local fn = callbacks[_index_0]
			xpcall(fn, displayError, self)
		end
	end
	local done
	done = function(self)
		return self._state ~= FUTURE_STATE_PENDING
	end
	local cancelled
	cancelled = function(self)
		return self._state == FUTURE_STATE_CANCELLED
	end
	local result
	result = function(self)
		if self._state == FUTURE_STATE_CANCELLED then
			return throw(InvalidStateError("future was cancelled"))
		elseif self._state ~= FUTURE_STATE_FINISHED then
			return throw(InvalidStateError("future is not finished yet"))
		end
		if self._error then
			return throw(self._error)
		end
		return self._result
	end
	local addCallback
	addCallback = function(self, fn)
		if done(self) then
			return xpcall(fn, RuntimeError.display, self)
		else
			local _obj_0 = self._callbacks
			_obj_0[#_obj_0 + 1] = fn
		end
	end
	local Future = environment.class("Future", {
		FUTURE_STATE_PENDING = FUTURE_STATE_PENDING,
		FUTURE_STATE_FINISHED = FUTURE_STATE_FINISHED,
		FUTURE_STATE_CANCELLED = FUTURE_STATE_CANCELLED,
		done = done,
		cancelled = cancelled,
		cancel = cancel,
		addCallback = addCallback,
		result = result,
		new = function(self)
			self._state = FUTURE_STATE_PENDING
			self._callbacks = { }
		end,
		error = function(self)
			if self._state == FUTURE_STATE_CANCELLED then
				throw(InvalidStateError("future was cancelled"))
			elseif self._state ~= FUTURE_STATE_FINISHED then
				throw(InvalidStateError("future is not finished yet"))
			end
			return self._error
		end,
		setResult = function(self, result)
			if self._state ~= FUTURE_STATE_PENDING then
				throw(InvalidStateError("future is already finished"))
			end
			self._result = result
			self._state = FUTURE_STATE_FINISHED
			_runCallbacks(self)
			return
		end,
		setError = function(self, err)
			if self._state ~= FUTURE_STATE_PENDING then
				throw(InvalidStateError("future is already finished"))
			end
			self._error = err
			self._state = FUTURE_STATE_FINISHED
			_runCallbacks(self)
			return
		end,
		cancel = function(self)
			if done(self) then
				return false
			end
			self._state = FUTURE_STATE_CANCELLED
			_runCallbacks(self)
			return true
		end,
		removeCallback = function(self, fn)
			local callbacks = { }
			local _list_0 = self._callbacks
			for _index_0 = 1, #_list_0 do
				local cb = _list_0[_index_0]
				if cb ~= fn then
					callbacks[#callbacks + 1] = cb
				end
			end
			self._callbacks = callbacks
		end,
		__await = function(self, current)
			if not done(self) then
				addCallback(self, function()
					return wakeup(current)
				end)
				pending()
			end
			if not done(self) then
				throw(InvalidStateError("future is not finished even after it's state changed???"))
			end
			return result(self)
		end,
		__acancel = function(self)
			return self:cancel()
		end
	})
	environment.Future = Future
	futures.Future = Future
	do
		local _tmp_0
		_tmp_0 = function(any)
			local metatable = getmetatable(any)
			return metatable and metatable.__class == Future
		end
		environment.isfuture = _tmp_0
		futures.IsFuture = _tmp_0
	end
end
do
	local Future, run = futures.Future, futures.run
	local cancelThread = futures.cancel
	local cancelFuture = Future.cancel
	local setResult = Future.setResult
	local setError = Future.setError
	local cancel
	cancel = function(self, ...)
		cancelThread(self._thread)
		return cancelFuture(self, ...)
	end
	local Task = environment.class("Task", {
		new = function(self, thread)
			if not isthread(thread) then
				return throw(TypeError("Task(...) expects a thread, got " .. tostring(type(thread))))
			end
			-- ugly, but yeah, this is gpm classes
			self.__class.__parent.__init(self)
			self._thread = thread
			run(thread, function(thread, ok, result, ...)
				if not ok then
					return setError(self, result)
				end
				if result == RESULT_FINISHED then
					return setResult(self, ...)
				end
				if result == RESULT_YIELDING then
					cancelThread(thread)
					return setError(self, FutureError("Task(...) unable to wait for async generator result"))
				end
				if result == RESULT_CANCELLED then
					return cancelFuture(self)
				end
				return setError(self, FutureError("unexpected result '" .. tostring(result) .. "' from thread '" .. tostring(thread) .. "'"))
			end)
			return
		end,
		cancel = cancel,
		getThread = function(self)
			return self._thread
		end
	}, nil, Future)
	environment.Task = Task
	futures.Task = Task
	-- Make set* methods private
	Task.__base.setResult = nil
	Task.__base.setError = nil
end
do
	local Future, async
	Future, async, await = futures.Future, futures.async, futures.await
	local QueueIsFull, QueueIsEmpty = environment.QueueIsFull, environment.QueueIsEmpty
	-- Basic queue without any async stuff, just put and get
	local BasicQueue = environment.class("BasicQueue", {
		new = function(self)
			self._queue = { }
			self._getp = 0
			self._putp = 0
		end,
		put = function(self, value)
			if value ~= nil then
				self._putp = self._putp + 1
				self._queue[self._putp] = value
				return true
			end
			return false
		end,
		get = function(self)
			if self._getp ~= self._putp then
				self._getp = self._getp + 1
				local value = self._queue[self._getp]
				self._queue[self._getp] = nil
				if self._getp == self._putp then
					self._getp = 0
					self._putp = 0
				end
				return value
			end
		end,
		size = function(self)
			return self._putp - self._getp
		end,
		empty = function(self)
			return self._getp == self._putp
		end
	})
	futures.BasicQueue = BasicQueue
	futures.Queue = environment.class("Queue", {
		new = function(self, maxSize)
			if maxSize == nil then
				maxSize = 0
			end
			if maxSize < 0 then
				return throw(TypeError("Queue(...) expects maxSize to be >= 0, got " .. tostring(maxSize)))
			end
			self._queue = BasicQueue()
			self._getters = BasicQueue()
			self._setters = BasicQueue()
			self._closed = false
			self._maxSize = maxSize
		end,
		qsize = function(self)
			return self._queue:size()
		end,
		empty = function(self)
			return self._queue:empty()
		end,
		full = function(self)
			if self._maxSize == 0 then
				return false
			end
			return self:qsize() >= self._maxSize
		end,
		putNow = function(self, value)
			if self:full() or self:closed() then
				return false
			end
			if self._queue:put(value) then
				do
					local getter = self._getters:get()
					if getter then
						wakeup(getter)
					end
				end
				return true
			end
			return false
		end,
		getNow = function(self)
			if self:empty() or self:closed() then
				return nil
			end
			local value = self._queue:get()
			if value ~= nil then
				local setter = self._setters:get()
				if setter then
					wakeup(setter)
				end
			end
			return value
		end,
		get = async(function(self, block)
			if block == nil then
				block = true
			end
			while block and self:empty() and not self:closed() do
				self._getters:put(coroRunning())
				pending()
			end
			return self:getNow()
		end),
		put = async(function(self, value, block)
			if block == nil then
				block = true
			end
			while block and self:full() and not self:closed() do
				self._setters:put(coroRunning())
				pending()
			end
			return self:putNow(value)
		end),
		close = function(self)
			if self._closed then
				return
			end
			self._closed = true
			while not self._getters:empty() do
				wakeup(self._getters:get())
			end
			while not self._setters:empty() do
				wakeup(self._setters:get())
			end
			return
		end,
		closed = function(self)
			return self._closed
		end
	})
end
do
	local Future, Task = futures.Future, futures.Task
	-- converts thread to Task and waits for task/future-like object to finish and calls callback with task
	local waitForTask
	waitForTask = function(task, fn)
		if isthread(task) then
			task = Task(task)
		end
		if not (task.addCallback and task.result and task.error and task.cancelled) then
			return false
		end
		task:addCallback(fn)
		return true
	end
	futures.all = function(tasks)
		local fut, results, taskLen = Future(), { }, #tasks
		if taskLen ~= 0 then
			local totalDone = 0
			for i = 1, taskLen do
				waitForTask(tasks[i], function(task)
					if fut:done() then
						return
					end
					if task:cancelled() then
						fut:cancel()
						return
					end
					do
						local err = task:error()
						if err then
							fut:setError(err)
							return
						end
					end
					results[i] = task:result()
					totalDone = totalDone + 1
					if totalDone == taskLen then
						return fut:setResult(results)
					end
				end)
			end
		else
			fut:setResult(results)
		end
		return fut
	end
	futures.allSettled = function(tasks)
		local fut, results, taskLen = Future(), { }, #tasks
		if taskLen ~= 0 then
			local totalDone = 0
			for i = 1, taskLen do
				waitForTask(tasks[i], function(task)
					if fut:done() then
						return
					end
					-- backwards compability with promise.allSettled? do we need it?
					local status = (task:cancelled() or task:error()) and "rejected" or "fulfilled"
					results[i] = {
						status = status,
						value = status == "fulfilled" and task:result() or nil,
						reason = status == "rejected" and task:error() or nil
					}
					totalDone = totalDone + 1
					if totalDone == taskLen then
						return fut:setResult(results)
					end
				end)
			end
		else
			fut:setResult(results)
		end
		return fut
	end
end
do
	local Simple
	do
		local _obj_0 = gpm.timer
		Simple = _obj_0.Simple
	end
	local Future
	Future, await = futures.Future, futures.await
	local sleep
	sleep = function(seconds, result)
		local fut = Future()
		Simple(seconds, function()
			return fut:setResult(result)
		end)
		return fut
	end
	futures.sleep = sleep
	environment.sleep = function(...)
		return await(sleep(...))
	end
end

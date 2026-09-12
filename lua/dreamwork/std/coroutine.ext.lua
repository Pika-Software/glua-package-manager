local std = dreamwork.std

local time = std.time
local time_elapsed = time.elapsed

---@class dreamwork.std.coroutine
local coroutine = std.coroutine
local coroutine_yield = coroutine.yield

--- [SHARED AND MENU]
---
--- Repeatedly yields the coroutine for the given duration before continuing.
---
---@param seconds number
---@async
function coroutine.wait( seconds )
    local end_time = time_elapsed() + seconds
    ::coroutine_wait::

    if end_time >= time_elapsed() then
        coroutine_yield()
        goto coroutine_wait
    end
end

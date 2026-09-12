local glua_coroutine = coroutine
local coroutine_status = glua_coroutine.status
local coroutine_running = glua_coroutine.running

---@class dreamwork.std
local std = dreamwork.std

--- [SHARED AND MENU]
---
--- coroutine library
---
--- Coroutines are similar to threads, however they do not run simultaneously.
---
--- They offer a way to split up tasks and dynamically pause & resume functions.
---
---@class dreamwork.std.coroutine
local coroutine = {
    create = glua_coroutine.create,
    resume = glua_coroutine.resume,

    ---@type fun(): running: thread | nil
    running = coroutine_running,

    status = coroutine_status,
    wrap = glua_coroutine.wrap,
    yield = glua_coroutine.yield,

    ---@diagnostic disable-next-line: deprecated
    isyieldable = glua_coroutine.isyieldable,
}

std.coroutine = coroutine

if coroutine.isyieldable == nil then

    --- [SHARED AND MENU]
    ---
    --- Returns `true` when the running coroutine can yield.
    ---
    --- [View documents](command:extension.lua.doc?["en-us/51/manual.html/pdf-coroutine.isyieldable"])
    ---
    ---@return boolean is_yieldable
    ---@nodiscard
    ---@diagnostic disable-next-line: duplicate-set-field
    function coroutine.isyieldable()
        local co = coroutine_running()
        return co ~= nil and coroutine_status( co ) == "running"
    end

end

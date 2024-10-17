local _module_0 = { }
--[[
    MIT License

    Copyright (c) 2023-2024 Retro

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
local _G = _G
local environment
do
	local _obj_0 = _G.gpm
	environment = _obj_0.environment
end
local string, isstring = environment.string, environment.isstring
local getmetatable, tostring, ErrorNoHaltWithStack, ErrorNoHalt = _G.getmetatable, _G.tostring, _G.ErrorNoHaltWithStack, _G.ErrorNoHalt
local getstack, getupvalue, getlocal, fempty
do
	local _obj_0 = environment.debug
	getstack, getupvalue, getlocal, fempty = _obj_0.getstack, _obj_0.getupvalue, _obj_0.getlocal, _obj_0.fempty
end
local concat
do
	local _obj_0 = environment.table
	concat = _obj_0.concat
end
local classExtend = environment.extend
local format, rep = string.format, string.rep
local errorClass
local iserror
iserror = function(obj, name)
	if name == nil then
		name = "Error"
	end
	local metatable = getmetatable(obj)
	local cls = metatable and metatable.__class
	while cls do
		if cls.__name == name then
			return true
		end
		cls = cls.__parent
	end
	return false
end
_module_0["iserror"] = iserror
local _callStack = {
	n = 0
}
local captureStack
captureStack = function(stackPos)
	return getstack(stackPos or 1)
end
local pushCallStack
pushCallStack = function(stack)
	local size = _callStack.n + 1
	_callStack[size] = stack
	_callStack.n = size
end
local popCallStack
popCallStack = function()
	local pos = _callStack.n
	if pos == 0 then
		return nil
	end
	local stack = _callStack[pos]
	_callStack[pos] = nil
	_callStack.n = pos - 1
	return stack
end
-- Should be used with captureStack
local appendStack
appendStack = function(stack)
	local previous = _callStack[_callStack.n]
	return pushCallStack({
		stack,
		previous
	})
end
local mergeStack
mergeStack = function(stack)
	local pos = #stack
	local currentCallStack = _callStack[_callStack.n]
	while currentCallStack do
		-- just copy over info fields
		local _list_0 = currentCallStack[1]
		for _index_0 = 1, #_list_0 do
			local info = _list_0[_index_0]
			pos = pos + 1
			stack[pos] = info
		end
		-- get next call stack
		currentCallStack = currentCallStack[2]
	end
	return stack
end
local dumpFile = fempty
do
	local min, max, floor, log10, huge
	do
		local _obj_0 = _G.math
		min, max, floor, log10, huge = _obj_0.min, _obj_0.max, _obj_0.floor, _obj_0.log10, _obj_0.huge
	end
	local Split, find, sub, len = string.Split, string.find, string.sub, string.len
	local MsgC, Color = environment.MsgC, environment.Color
	local Read
	do
		local _obj_0 = environment.file
		Read = _obj_0.Read
	end
	local gray = Color(180, 180, 180)
	local white = Color(225, 225, 225)
	local danger = Color(239, 68, 68)
	dumpFile = function(message, fileName, line)
		if not (fileName and line) then
			return nil
		end
		local data = Read(fileName, "GAME")
		if not (data and len(data) > 0) then
			return nil
		end
		local lines = Split(data, "\n")
		if not (lines and lines[line]) then
			return nil
		end
		local start = max(1, line - 5)
		local finish = min(#lines, line + 3)
		local numWidth = floor(log10(finish)) + 1
		local longestLine = 0
		local firstChar = huge
		for i = start, finish do
			local code = lines[i]
			local pos = find(code, "%S")
			if pos and pos < firstChar then
				firstChar = pos
			end
			longestLine = max(longestLine, len(code))
		end
		longestLine = min(longestLine - firstChar, 120)
		MsgC(gray, rep(" ", numWidth + 3), rep("_", longestLine + 4), "\n", rep(" ", numWidth + 2), "|\n")
		local numFormat = " %0" .. numWidth .. "d | "
		for i = start, finish do
			local code = lines[i]
			MsgC(i == line and white or gray, format(numFormat, i), sub(code, firstChar, longestLine + firstChar), "\n")
			if i == line then
				local space = (find(code, "%S") or 1) - 1
				MsgC(gray, rep(" ", numWidth + 2), "| ", sub(code, firstChar, space), danger, "^ ", tostring(message), "\n")
				MsgC(gray, rep(" ", numWidth + 2), "|\n")
			end
		end
		MsgC(gray, rep(" ", numWidth + 2), "|\n", rep(" ", numWidth + 3), rep("¯", longestLine + 4), "\n\n")
		return nil
	end
end
errorClass = environment.class("Error", {
	name = "Error",
	new = function(self, message, fileName, lineNumber, stackPos)
		if stackPos == nil then
			stackPos = 3
		end
		self.message = message
		self.fileName = fileName
		self.lineNumber = lineNumber
		local stack = captureStack(stackPos)
		self.stack = stack
		mergeStack(stack)
		local first = stack[1]
		if first then
			self.fileName = self.fileName or first.short_src
			self.lineNumber = self.lineNumber or first.currentline
			-- TODO: prevent recording these values on client in production
			if getupvalue and first.func and first.nups and first.nups > 0 then
				local upvalues = { }
				self.upvalues = upvalues
				for i = 1, first.nups do
					local name, value = getupvalue(first.func, i)
					if name == nil then
						self.upvalues = nil
						break
					end
					upvalues[i] = {
						name = name,
						value = value
					}
				end
			end
			if getlocal then
				local locals, count = { }, 0
				local i = 1
				while true do
					local name, value = getlocal(stackPos, i)
					if name == nil then
						break
					end
					if name ~= "(*temporary)" then
						count = count + 1
						locals[count] = {
							name = name,
							value = value
						}
					end
					i = i + 1
				end
				if count ~= 0 then
					self.locals = locals
				end
			end
		end
		return nil
	end,
	__tostring = function(self)
		if self.fileName then
			return format("%s:%d: %s: %s", self.fileName, self.lineNumber or 0, self.name, self.message)
		end
		return self.name .. ": " .. self.message
	end,
	display = function(self)
		if isstring(self) then
			return ErrorNoHaltWithStack(self)
		end
		local lines, length = {
			"\n[ERROR] " .. tostring(self)
		}, 1
		-- Add stack trace
		local stack = self.stack
		if stack then
			for i = 1, #stack do
				local info = stack[i]
				length = length + 1
				lines[length] = format("%s %d. %s - %s:%d", rep(" ", i), i, info.name or "unknown", info.short_src, info.currentline or -1)
			end
		end
		-- Add locals
		local locals = self.locals
		if locals then
			length = length + 1
			lines[length] = "\n=== Locals ==="
			for _index_0 = 1, #locals do
				local entry = locals[_index_0]
				length = length + 1
				lines[length] = format("  - %s = %s", entry.name, entry.value)
			end
		end
		-- Add upvalues
		local upvalues = self.upvalues
		if upvalues then
			length = length + 1
			lines[length] = "\n=== Upvalues ==="
			for _index_0 = 1, #upvalues do
				local entry = upvalues[_index_0]
				length = length + 1
				lines[length] = format("  - %s = %s", entry.name, entry.value)
			end
		end
		length = length + 1
		lines[length] = "\n"
		ErrorNoHalt(concat(lines, "\n", 1, length))
		-- TODO: disable this in client-side production environment
		if self.message and self.fileName and self.lineNumber then
			dumpFile(self.name .. ": " .. self.message, self.fileName, self.lineNumber)
		end
		return nil
	end
}, {
	__inherited = function(self, child)
		child.__base.name = child.__name or self.name
	end,
	_callStack = _callStack,
	captureStack = captureStack,
	pushCallStack = pushCallStack,
	popCallStack = popCallStack,
	appendStack = appendStack,
	mergeStack = mergeStack,
	is = iserror
})
local NotImplementedError = classExtend(errorClass, "NotImplementedError")
_module_0["NotImplementedError"] = NotImplementedError
local FutureCancelError = classExtend(errorClass, "FutureCancelError")
_module_0["FutureCancelError"] = FutureCancelError
local InvalidStateError = classExtend(errorClass, "InvalidStateError")
_module_0["InvalidStateError"] = InvalidStateError
local CodeCompileError = classExtend(errorClass, "CodeCompileError")
_module_0["CodeCompileError"] = CodeCompileError
local FileSystemError = classExtend(errorClass, "FileSystemError")
_module_0["FileSystemError"] = FileSystemError
local WebClientError = classExtend(errorClass, "WebClientError")
_module_0["WebClientError"] = WebClientError
local RuntimeError = classExtend(errorClass, "RuntimeError")
_module_0["RuntimeError"] = RuntimeError
local PackageError = classExtend(errorClass, "PackageError")
_module_0["PackageError"] = PackageError
local ModuleError = classExtend(errorClass, "ModuleError")
_module_0["ModuleError"] = ModuleError
local SourceError = classExtend(errorClass, "SourceError")
_module_0["SourceError"] = SourceError
local FutureError = classExtend(errorClass, "FutureError")
_module_0["FutureError"] = FutureError
local AddonError = classExtend(errorClass, "AddonError")
_module_0["AddonError"] = AddonError
local RangeError = classExtend(errorClass, "RangeError")
_module_0["RangeError"] = RangeError
local TypeError = classExtend(errorClass, "TypeError")
_module_0["TypeError"] = TypeError
local SQLError = classExtend(errorClass, "SQLError")
_module_0["SQLError"] = SQLError
local Error = errorClass
_module_0["Error"] = Error
return _module_0

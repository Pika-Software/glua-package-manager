local gpm = _G.gpm
local Error = gpm.Error
return {
	cases = {
		{
			name = "error(...) must throw always string unless in coroutine",
			func = function()
				local throw = gpm.throw
				-- expect we are in main thread
				expect(coroutine.running()).to.beNil()
				local expectThrowValue
				expectThrowValue = function(val, expected)
					if isstring(val) or isnumber(val) then
						return expect(throw, val).to.errWith(expected or val)
					else
						local ok, err = pcall(throw, val)
						expect(ok).to.beFalse()
						return expect(err).to.equal(expected or val)
					end
				end
				local expectThrowString
				expectThrowString = function(val)
					return expectThrowValue(val, tostring(val))
				end
				-- check throw works as vanilla error inside coroutine
				local co = coroutine.create(function()
					expectThrowValue("foo bar")
					expectThrowValue({ })
					expectThrowValue(true)
					expectThrowValue(nil)
					expectThrowValue(newproxy())
					return expectThrowString(123)
				end)
				do
					local ok, err = coroutine.resume(co)
					if not ok then
						error(err)
					end
				end
				-- check throw always throws value converted to string inside main thread
				expectThrowString("foo bar")
				expectThrowString({ })
				expectThrowString(true)
				expectThrowString(nil)
				expectThrowString(newproxy())
				expectThrowString(123)
				expectThrowString(Error("hello world"))
				return
			end
		}
	}
}

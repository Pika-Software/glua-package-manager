local gpm = _G.gpm
local file, path = gpm.file, gpm.path
local LUA_GAME_PATH = SERVER and "lsv" or CLIENT and "lcl" or MENU_DLL and "LuaMenu" or "LUA"
return {
	cases = {
		{
			name = "NormalizeGamePath(...) must convert absolute path to correct format",
			func = function()
				local NormalizeGamePath = file.NormalizeGamePath
				local test
				test = function(input, filePath, gamePath)
					local resultPath, resultGamePath = NormalizeGamePath(input)
					expect(resultPath).to.equal(filePath)
					expect(resultGamePath).to.equal(gamePath)
					return
				end
				test("/", "", "GAME")
				test("/hello.txt", "hello.txt", "GAME")
				test("/lua/foo/bar.lua", "foo/bar.lua", LUA_GAME_PATH)
				test("/lua", "lua", "GAME")
				test("/data/", "", "DATA")
				test("/data/hello.txt", "hello.txt", "DATA")
				test("/data/foo/bar.lua", "foo/bar.lua", "DATA")
				test("/materials/test.png", "materials/test.png", "GAME")
				test("/foo/bar/xyz/123/ok.gz", "foo/bar/xyz/123/ok.gz", "GAME")
				test("hello/world.mp3", "hello/world.mp3", "GAME")
				test("lua/gpm/init.lua", "gpm/init.lua", LUA_GAME_PATH)
				return test("data/hello.txt", "hello.txt", "DATA")
			end
		},
		{
			name = "NormalizeGamePath(...) must handle relative paths",
			func = function()
				local NormalizeGamePath = file.NormalizeGamePath
				local root = string.sub(path.getCurrentDirectory(nil, true), 2)
				if root == "" then
					-- if we are unable to get the current directory, NormalizeGamePath should fail
					expect(NormalizeGamePath, "./test.lua").to.err()
					return
				end
				-- unfortunately, unable to test this with concommand
				local filePath, gamePath = NormalizeGamePath("./test.lua")
				expect(filePath).to.equal(root .. "/test.lua")
				expect(gamePath).to.equal(LUA_GAME_PATH)
				filePath, gamePath = NormalizeGamePath("./foo.bar", "DATA")
				expect(filePath).to.equal(root .. "/foo.bar")
				return expect(gamePath).to.equal(LUA_GAME_PATH)
			end
		},
		{
			name = "NormalizeGamePath(...) should not modify paths that are already in the correct format",
			func = function()
				local NormalizeGamePath = file.NormalizeGamePath
				local test
				test = function(filePath, gamePath)
					local resultPath, resultGamePath = NormalizeGamePath(filePath, gamePath)
					expect(resultPath).to.equal(filePath)
					expect(resultGamePath).to.equal(gamePath)
					return
				end
				test("abc/def", "GAME")
				test("abc/def", "DATA")
				test("data/hello", "GAME")
				test("data/hello", "DATA")
				test("lua/gpm/init.lua", LUA_GAME_PATH)
				test("lua/gpm/init.lua", "GAME")
				test("", "ABC")
				test("hello/world.vtf", "FOO / BAR")
				return
			end
		},
		{
			name = "NormalizeGamePath(...) should handle URL objects (not strings)",
			func = function()
				local NormalizeGamePath = file.NormalizeGamePath
				local URL = gpm.URL
				-- NormalizeGamePath should fail if the URL is not a file
				expect(NormalizeGamePath, URL("http://example.com/test.lua")).to.err()
				local filePath, gamePath = NormalizeGamePath(URL("file:///hello/world.txt"))
				expect(filePath).to.equal("hello/world.txt")
				expect(gamePath).to.equal("GAME")
				filePath, gamePath = NormalizeGamePath(URL("file:///lua/gpm/init.lua"))
				expect(filePath).to.equal("gpm/init.lua")
				expect(gamePath).to.equal(LUA_GAME_PATH)
				filePath, gamePath = NormalizeGamePath(URL("file://abc/hello.txt"))
				expect(filePath).to.equal("hello.txt")
				return expect(gamePath).to.equal("GAME")
			end
		}
	}
}

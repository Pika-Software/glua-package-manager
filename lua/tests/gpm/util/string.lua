local gpm = _G.gpm
local string, table = gpm.string, gpm.table
return {
	cases = {
		{
			name = "string.slice(...) must return a slice of given string",
			func = function()
				local test
				test = function(str, startPos, endPos, expected)
					local result = string.slice(str, startPos, endPos)
					return expect(result).to.equal(expected)
				end
				test("hello", 1, 5, "hello")
				test("hello", 1, 1, "h")
				test("hello", 5, 5, "o")
				test("hello", 0, 0, "")
				return
			end
		},
		{
			name = "string.StartsWith(...) must return true if string starts with given string",
			func = function()
				local test1
				test1 = function(str, startStr)
					local result = string.StartsWith(str, startStr)
					return expect(result).to.beTrue()
				end
				test1("hello", "hel")
				test1("hello", "hello")
				test1("hello", "hell")
				local test2
				test2 = function(str, startStr)
					local result = string.StartsWith(str, startStr)
					return expect(result).to.beFalse()
				end
				test2("hello", "his")
				test2("hello", "helll")
				test2("hello", "helllll")
				return
			end
		},
		{
			name = "string.EndsWith(...) must return true if string ends with given string",
			func = function()
				local test1
				test1 = function(str, endStr)
					local result = string.EndsWith(str, endStr)
					return expect(result).to.beTrue()
				end
				test1("hello", "lo")
				test1("hello", "hello")
				test1("hello", "ello")
				local test2
				test2 = function(str, endStr)
					local result = string.EndsWith(str, endStr)
					return expect(result).to.beFalse()
				end
				test2("hello", "ll")
				test2("hello", "helll")
				test2("hello", "helllll")
				return
			end
		},
		{
			name = "string.concat(...) must concatenate given strings",
			func = function()
				local test
				test = function(expected, ...)
					local result = string.concat(...)
					return expect(result).to.equal(expected)
				end
				test("hello world", "hello", " world")
				test("oh hi mark", "oh ", "hi", " mark")
				test("glua package manager", "glua", " ", "package", " ", "manager")
				return
			end
		},
		{
			name = "string.IndexOf(...) must return index of given string",
			func = function()
				local paragraph = "I think Ruth's dog is cuter than your dog!"
				local test
				test = function(str, searchable, position, withPattern, expected)
					expect(string.IndexOf(str, searchable, position, withPattern)).to.equal(expected)
					return
				end
				test(paragraph, "dog", 1, false, 16)
				test(paragraph, "dog", 17, false, 39)
				test(paragraph, "%w+'s", 1, true, 9)
				return
			end
		},
		{
			name = "string.Split(...) must return split strings",
			func = function()
				local Equal = table.Equal
				local test
				test = function(str, pattern, withPattern, expected)
					return expect(Equal(string.Split(str, pattern, withPattern), expected)).to.beTrue()
				end
				test("hello world", " ", false, {
					"hello",
					"world"
				})
				test("hello world", "%s+", true, {
					"hello",
					"world"
				})
				test("hello user, can you help other users?", "user", false, {
					"hello ",
					", can you help other ",
					"s?"
				})
				return
			end
		},
		{
			name = "string.Count(...) must return pattern repetition count",
			func = function()
				local test
				test = function(str, pattern, withPattern, expected)
					return expect(string.Count(str, pattern, withPattern)).to.equal(expected)
				end
				test("hello world", "l", false, 3)
				test("hello world", "o", false, 2)
				test("hello world", "x", false, 0)
				test("visual studio code", "[ios]", true, 6)
				return
			end
		},
		{
			name = "string.ByteSplit(...) must return table with splited parts of given string by byte",
			func = function()
				local Equal = table.Equal
				local test
				test = function(str, byte, expected)
					return expect(Equal(string.ByteSplit(str, byte), expected)).to.beTrue()
				end
				test("hello world", 0x20, {
					"hello",
					"world"
				})
				test("glua performance is really bad", 0x20, {
					"glua",
					"performance",
					"is",
					"really",
					"bad"
				})
				test("more and more strings", 0x6F, {
					"m",
					"re and m",
					"re strings"
				})
				return
			end
		},
		{
			name = "string.ByteCount(...) must return byte count of given string",
			func = function()
				local test
				test = function(str, byte, expected)
					return expect(string.ByteCount(str, byte)).to.equal(expected)
				end
				test("hello world", 0x20, 1)
				test("hello again", 0x61, 2)
				test("+++++++++++++", 0x2B, 13)
				return
			end
		},
		{
			name = "string.TrimByte(...) must return trimmed string",
			func = function()
				local test
				test = function(str, bytes, expected)
					return expect(string.TrimByte(str, bytes)).to.equal(expected)
				end
				test("hello world", 0x20, "hello world")
				test("lllo worllll", 0x6C, "o wor")
				test("                  hello world", 0x20, "hello world", 1)
				test("hello world                  ", 0x20, "hello world", -1)
				return
			end
		},
		{
			name = "string.TrimBytes(...) must return trimmed string",
			func = function()
				local test
				test = function(str, bytes, expected)
					return expect(string.TrimBytes(str, bytes)).to.equal(expected)
				end
				test("   hello world   ", {
					0x20
				}, "hello world")
				test("\t\t\t\thello world                      ", {
					0x20,
					0x09
				}, "hello world")
				test("lllllllllllllllllllooolllllllllllll\t\t\t\t\t            ", {
					0x20,
					0x09,
					0x6C
				}, "ooo")
				return
			end
		},
		{
			name = "string.PatternSafe(...) must return safe pattern",
			func = function()
				local test
				test = function(pattern, expected)
					return expect(string.PatternSafe(pattern)).to.equal(expected)
				end
				test("hello", "hello")
				test("hello%world", "hello%%world")
				test("(hello)[world]", "%(hello%)%[world%]")
				test("[[\\$$]]", "%[%[\\%$%$%]%]")
				return
			end
		},
		{
			name = "string.Trim(...) must return trimmed string",
			func = function()
				local test
				test = function(str, pattern, expected)
					return expect(string.Trim(str, pattern)).to.equal(expected)
				end
				test("hello world", " ", "hello world")
				test("     hello world\t\t\t\t\t", "%s", "hello world", 0)
				test("     \t\t\tok,,,", "%s%p", "ok")
				test("\n\n\n\t\t\t\t\rtest", "%c", "test", 1)
				test("yep              ", nil, "yep", -1)
				return
			end
		},
		{
			name = "string.IsURL(...) must return true if given string is URL",
			func = function()
				local test
				test = function(str, expected)
					return expect(string.IsURL(str)).to.equal(expected)
				end
				test("https://google.com", true)
				test("http://google.com", true)
				test("google.com", false)
				test("www.google.com", false)
				test("file://google.com", true)
				test("ftp://google.com:80", false)
				return
			end
		},
		{
			name = "string.Extract(...) must return table with splited parts of given string",
			func = function()
				local test
				test = function(str, pattern, default, expected)
					return expect(string.Extract(str, pattern, default)).to.equal(expected)
				end
				test("hello world", " ", nil, "helloworld")
				test("hello world", "^%w+", nil, " world")
				test("hello user, can you help other users?", "user", nil, "hello , can you help other users?")
				return
			end
		},
		{
			name = "string.Left(...) must return left part of given string",
			func = function()
				local test
				test = function(str, num, expected)
					return expect(string.Left(str, num)).to.equal(expected)
				end
				test("hello world", 5, "hello")
				test("hello world", 0, "")
				test("hello world", 10, "hello worl")
				return
			end
		},
		{
			name = "string.Right(...) must return right part of given string",
			func = function()
				local test
				test = function(str, num, expected)
					return expect(string.Right(str, num)).to.equal(expected)
				end
				test("hello world", 5, "world")
				test("hello world", 0, "hello world")
				test("hello world", 5, "world")
				return
			end
		},
		{
			name = "string.Replace(...) must return replaced string",
			func = function()
				local test
				test = function(str, searchable, replaceable, withPattern, expected)
					return expect(string.Replace(str, searchable, replaceable, withPattern)).to.equal(expected)
				end
				test("hello world", "hello", "hi", false, "hi world")
				test("hello world", ".", "*", true, "***********")
				test("my little message", " ", "_", true, "my_little_message")
				return
			end
		}
	}
}

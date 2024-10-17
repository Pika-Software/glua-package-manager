local gpm = _G.gpm
local table = gpm.table
return {
	cases = {
		{
			name = "table.IsEmpty(...) must return true if table is empty",
			func = function()
				local IsEmpty = table.IsEmpty
				expect(IsEmpty({ })).to.beTrue()
				expect(IsEmpty({
					"hello"
				})).to.beFalse()
				expect(IsEmpty({
					nil,
					"world"
				})).to.beFalse()
				expect(IsEmpty({
					foo = "bar"
				})).to.beFalse()
				return
			end
		},
		{
			name = "table.Count(...) must return number of elements in table",
			func = function()
				local Count = table.Count
				expect(Count({ })).to.equal(0)
				expect(Count({
					"hello"
				})).to.equal(1)
				expect(Count({
					nil,
					"world"
				})).to.equal(1)
				expect(Count({
					foo = "bar"
				})).to.equal(1)
				expect(Count({
					foo = "bar",
					hello = "world"
				})).to.equal(2)
				expect(Count({
					1,
					2,
					3,
					test = "Count",
					gpm = "Awesome"
				}))
				return
			end
		},
		{
			name = "table.Equal(...) must return true if tables are equal",
			func = function()
				local Equal = table.Equal
				local example = { }
				expect(Equal(example, example)).to.beTrue()
				expect(Equal({ }, { })).to.beTrue()
				expect(Equal({
					"hello"
				}, {
					"hello"
				})).to.beTrue()
				expect(Equal({
					nil,
					"world"
				}, {
					nil,
					"world"
				})).to.beTrue()
				expect(Equal({
					foo = "bar"
				}, {
					foo = "bar"
				})).to.beTrue()
				expect(Equal({
					foo = "bar",
					hello = "world"
				}, {
					foo = "bar",
					hello = "world"
				})).to.beTrue()
				expect(Equal({
					1,
					2,
					3,
					test = "Count",
					gpm = "Awesome"
				}, {
					1,
					2,
					3,
					test = "Count",
					gpm = "Awesome"
				})).to.beTrue()
				expect(Equal({
					{
						nested = "table"
					}
				}, {
					{
						nested = "table"
					}
				})).to.beTrue()
				expect(Equal({
					false
				}, {
					false
				})).to.beTrue()
				expect(Equal({
					"hello"
				}, {
					"world"
				})).to.beFalse()
				expect(Equal({
					nil,
					"world"
				}, {
					"world"
				})).to.beFalse()
				expect(Equal({
					foo = "bar"
				}, {
					foo = "bar",
					hello = "world"
				})).to.beFalse()
				expect(Equal({
					1,
					2,
					3,
					test = "Count",
					gpm = "Awesome"
				}, {
					1,
					2,
					3,
					test = "Count"
				})).to.beFalse()
				expect(Equal({
					{
						nested = "table"
					}
				}, {
					{
						nested = "table",
						unnested = "array"
					}
				})).to.beFalse()
				return
			end
		},
		{
			name = "table.unpack(...) must work same as unpack(...)",
			func = function()
				local Equal = table.Equal
				local test
				test = function(...)
					local result1 = {
						table.unpack(...)
					}
					local result2 = {
						unpack(...)
					}
					return expect(Equal(result1, result2)).to.beTrue()
				end
				test({
					1,
					2,
					3,
					4,
					5
				})
				test({
					1,
					2,
					3,
					nil,
					5
				})
				test({
					nil,
					2,
					3,
					nil,
					5
				})
				test({
					1,
					2,
					3,
					4,
					5
				}, 1, 5)
				test({
					nil,
					2,
					3,
					nil,
					5
				}, 1, 5)
				test({
					nil,
					2,
					3,
					nil,
					5
				}, 1, 3)
				test({
					"hello",
					1,
					true,
					function() end,
					"world",
					{ },
					false
				})
				test({ })
				return
			end
		},
		{
			name = "table.pack(...) must have .n field and contain all values",
			func = function()
				local test
				test = function(...)
					local n = select("#", ...)
					local result = table.pack(...)
					expect(result.n).to.equal(n)
					return expect(table.Equal(result, {
						n = n,
						...
					})).to.beTrue()
				end
				test()
				test(1, 2, 3, 4)
				test(nil, 2, false, "hello", { })
				return
			end
		},
		{
			name = "table.create(...) must create table with specified length and values",
			func = function()
				local Equal = table.Equal
				local test
				test = function(expected, length, ...)
					local result = table.create(length, ...)
					return expect(Equal(result, expected)).to.beTrue()
				end
				test({ })
				test({ }, 0)
				test({ }, 100, nil)
				test({
					1,
					2,
					3
				}, 3, 1, 2, 3)
				test({
					1,
					2,
					3,
					4,
					5
				}, 5, 1, 2, 3, 4, 5)
				return nil
			end
		},
		{
			name = "table.move(...) must move values from one table to another",
			func = function()
				local Equal = table.Equal
				local test
				test = function(expected, source, first, last, offset, destination)
					return expect(Equal(table.move(source, first, last, offset, destination), expected)).to.beTrue()
				end
				test({
					"a"
				}, {
					"a",
					"b",
					"c"
				}, 1, 1, 1, { })
				test({
					"a",
					"b",
					"c"
				}, {
					"a",
					"b",
					"c"
				}, 2, 3, 2, {
					"a"
				})
				test({
					"a",
					"b",
					"c"
				}, {
					"a",
					"b",
					"c"
				}, 3, 3, 3, {
					"a",
					"b"
				})
				test({
					"hello",
					"hello"
				}, {
					"hello",
					"world"
				}, 1, 1, 2)
				return nil
			end
		},
		{
			name = "table.copy(...) must copy table",
			func = function()
				local test
				test = function(source, isSequential, deepCopy, copyKeys)
					expect(table.Equal(table.copy(source, isSequential, deepCopy, copyKeys), source)).to.beTrue()
					return nil
				end
			end
		},
		{
			name = "table.Add(...) must add values to table",
			func = function()
				local test
				test = function(target, source)
					local targetCopy = table.Copy(target)
					table.Add(target, source)
					_G.table.Add(targetCopy, source)
					return expect(table.Equal(target, targetCopy)).to.beTrue()
				end
				test({ }, { })
				test({ }, {
					1,
					2,
					3
				})
				test({
					1,
					2,
					3
				}, { })
				test({
					1,
					2,
					3
				}, {
					4,
					5,
					6
				})
				test({
					"One",
					"Two"
				}, {
					"Three",
					"Four",
					"Five"
				})
				test({
					"One",
					"Two"
				}, {
					nil,
					"Three",
					"Four",
					"Five"
				})
				test({
					true,
					false
				}, {
					test = "everyting"
				})
				return
			end
		},
		{
			name = "table.Add(...) with isSequantial=true must work sequantialy",
			func = function()
				local test
				test = function(target, source, expected)
					table.Add(target, source, true)
					return expect(table.Equal(target, expected)).to.beTrue()
				end
				test({ }, { }, { })
				test({
					1
				}, {
					2
				}, {
					1,
					2
				})
				test({
					nil,
					3,
					4
				}, {
					1,
					2,
					3
				}, {
					nil,
					3,
					4,
					1,
					2,
					3
				})
				test({
					"never",
					"gonna",
					"give",
					"you"
				}, {
					nil,
					"up"
				}, {
					"never",
					"gonna",
					"give",
					"you",
					nil,
					"up"
				})
				test({
					true
				}, {
					will = "be",
					false
				}, {
					true,
					false
				})
				local t = { }
				t[3] = true
				test(t, {
					false
				}, {
					false,
					nil,
					true
				})
				return
			end
		},
		{
			name = "table.Flip(...) must invert keys and values",
			func = function()
				local test
				test = function(input, expected)
					local result1 = table.Flip(input)
					local result2 = table.Flip(input, true)
					expect(table.Equal(result1, result2)).to.beTrue()
					return expect(table.Equal(result2, expected)).to.beTrue()
				end
				test({ }, { })
				test({
					["hello"] = "world"
				}, {
					["world"] = "hello"
				})
				test({
					[true] = false
				}, {
					[false] = true
				})
				test({
					[3] = 1
				}, {
					[1] = 3
				})
				test({
					["never"] = "gonna",
					["give"] = "you",
					"up"
				}, {
					["gonna"] = "never",
					["you"] = "give",
					["up"] = 1
				})
				return
			end
		},
		{
			name = "table.Reverse(...) must work same as original",
			func = function()
				local test
				test = function(input, expected)
					local result1 = table.Reverse(input)
					local result2 = table.Reverse(input, true)
					expect(table.Equal(result1, result2)).to.beTrue()
					return expect(table.Equal(result2, expected)).to.beTrue()
				end
				test({ }, { })
				test({
					1,
					2,
					3
				}, {
					3,
					2,
					1
				})
				test({
					"hello",
					"world"
				}, {
					"world",
					"hello"
				})
				test({
					true,
					false
				}, {
					false,
					true
				})
				test({
					nil,
					3,
					4
				}, {
					4,
					3,
					nil
				})
				test({
					"never",
					"gonna",
					"give",
					"you"
				}, {
					"you",
					"give",
					"gonna",
					"never"
				})
				return
			end
		},
		{
			name = "table.HasValue(...) must return true if table has value",
			func = function()
				local test
				test = function(input, value, expected, isSequantial)
					return expect(table.HasValue(input, value, isSequantial)).to.equal(expected)
				end
				test({ }, "hello", false)
				test({
					"hello"
				}, "hello", true)
				test({
					"hello"
				}, "world", false)
				test({
					test = "hello"
				}, "hello", true)
				test({
					"hello",
					"world"
				}, "hello", true, true)
				test({
					"hello",
					"world"
				}, "world", true, true)
				test({
					"hello",
					"world"
				}, "test", false, true)
				test({
					1,
					2,
					3,
					4
				}, "welcome", false, true)
				return
			end
		},
		{
			name = "table.Empty(...) must empty any table",
			func = function()
				local test
				test = function(input)
					table.Empty(input)
					return expect(table.IsEmpty(input)).to.beTrue()
				end
				test({ })
				test({
					1,
					2,
					3
				})
				test({
					true,
					false,
					"ok"
				})
				test({
					nil,
					{ },
					hello = "world",
					["test"] = "empty",
					foo = { }
				})
				return
			end
		},
		{
			name = "table.GetKeys(...) must return all keys in table",
			func = function()
				local test
				test = function(input, expected)
					local result = table.GetKeys(input)
					return expect(table.Equal(result, expected)).to.beTrue()
				end
				test({ }, { })
				test({
					1,
					2,
					3
				}, {
					1,
					2,
					3
				})
				test({
					true,
					false,
					"ok"
				}, {
					1,
					2,
					3
				})
				test({
					nil,
					{ },
					hello = "world",
					["test"] = "empty",
					foo = { }
				}, {
					2,
					"hello",
					"test",
					"foo"
				})
				test({
					[false] = true
				}, {
					false
				})
				return
			end
		},
		{
			name = "table.GetValues(...) must return all values in table",
			func = function()
				local test
				test = function(input, expected)
					local result = table.GetValues(input)
					return expect(table.Equal(result, expected)).to.beTrue()
				end
				test({ }, { })
				test({
					1,
					2,
					3
				}, {
					1,
					2,
					3
				})
				test({
					true,
					false,
					"ok"
				}, {
					true,
					false,
					"ok"
				})
				test({
					nil,
					{ },
					hello = "world",
					["test"] = "empty",
					foo = { }
				}, {
					{ },
					"world",
					"empty",
					{ }
				})
				test({
					[false] = true
				}, {
					true
				})
				return
			end
		},
		{
			name = "table.IsSequential(...) must return true if table is sequential",
			func = function()
				local test
				test = function(input, expected)
					return expect(table.IsSequential(input)).to.equal(expected)
				end
				test({ }, true)
				test({
					1,
					2,
					3
				}, true)
				test({
					true,
					false,
					"ok"
				}, true)
				test({
					nil,
					{ },
					hello = "world",
					["test"] = "empty",
					foo = { }
				}, false)
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10,
					11,
					12,
					13,
					14,
					15,
					16,
					17,
					18,
					19,
					20
				}, true)
				test({
					[false] = true
				}, false)
				return
			end
		},
		{
			name = "table.RemoveByValue(...) must remove value from table",
			func = function()
				local test
				test = function(input, value, expected, isSequantial)
					table.RemoveByValue(input, value, isSequantial)
					return expect(table.Equal(input, expected)).to.beTrue()
				end
				test({ }, "hello", { }, false)
				test({
					"hello"
				}, "hello", { }, false)
				test({
					"hello"
				}, "world", {
					"hello"
				}, false)
				test({
					"hello",
					"world"
				}, "hello", {
					"world"
				}, true)
				test({
					"hello",
					"world"
				}, "world", {
					"hello"
				}, true)
				test({
					"hello",
					"world"
				}, "test", {
					"hello",
					"world"
				}, true)
				test({
					1,
					2,
					3,
					4
				}, "welcome", {
					1,
					2,
					3,
					4
				}, true)
				return
			end
		},
		{
			name = "table.RemoveSameValues(...) must remove multiple same values",
			func = function()
				local test
				test = function(input, value, expected, isSequantial)
					table.RemoveSameValues(input, value, isSequantial)
					return expect(table.Equal(input, expected)).to.beTrue()
				end
				test({ }, "hello", { }, false)
				test({
					"hello"
				}, "hello", { }, false)
				test({
					"hello"
				}, "world", {
					"hello"
				}, false)
				test({
					"hello",
					"world"
				}, "hello", {
					"world"
				}, true)
				test({
					"hello",
					"world"
				}, "world", {
					"hello"
				}, true)
				test({
					"hello",
					"world"
				}, "test", {
					"hello",
					"world"
				}, true)
				test({
					1,
					2,
					3,
					4
				}, "welcome", {
					1,
					2,
					3,
					4
				}, true)
				test({
					1,
					2,
					3,
					4,
					1,
					2,
					3,
					4
				}, 1, {
					2,
					3,
					4,
					2,
					3,
					4
				}, true)
				test({
					1,
					2,
					3,
					4,
					1,
					2,
					3,
					4
				}, 1, {
					2,
					3,
					4,
					2,
					3,
					4
				}, true)
				test({
					1,
					2,
					3,
					4,
					1,
					2,
					3,
					4
				}, 1, {
					2,
					3,
					4,
					2,
					3,
					4
				}, true)
				return
			end
		},
		{
			name = "table.GetValue(...) must tranverse table with given key delimited by '.'",
			func = function()
				local test
				test = function(tbl, key, expected)
					return expect(table.GetValue(tbl, key)).to.equal(expected)
				end
				test({ }, "test", nil)
				test({
					["test"] = "works"
				}, "test", "works")
				test({
					["test"] = {
						["works"] = "fine"
					}
				}, "test.works", "fine")
				test({
					["test"] = {
						["works"] = {
							["fine"] = "too"
						}
					}
				}, "test.works.fine", "too")
				test({
					["test"] = {
						["works"] = {
							["fine"] = "too"
						}
					}
				}, "test.works.fine.ok", nil)
				test({
					["test"] = {
						["works"] = {
							["fine"] = "too"
						}
					}
				}, "test.wont.work.really", nil)
				test({ }, "test.wont.work.really", nil)
				return
			end
		},
		{
			name = "table.SetValue(...) must set value by given key delimited by '.' and create missing tables",
			func = function()
				local test
				test = function(tbl, key, value, expected)
					table.SetValue(tbl, key, value)
					return expect(table.Equal(tbl, expected)).to.beTrue()
				end
				test({ }, "test", "works", {
					test = "works"
				})
				test({
					test = "works"
				}, "test", "fine", {
					test = "fine"
				})
				test({
					test = "fine"
				}, "test.works", "fine", {
					test = {
						works = "fine"
					}
				})
				test({
					test = {
						works = "fine"
					}
				}, "test.works.fine", "too", {
					test = {
						works = {
							fine = "too"
						}
					}
				})
				test({
					test = {
						works = {
							fine = "too"
						}
					}
				}, "test.works.fine", "too", {
					test = {
						works = {
							fine = "too"
						}
					}
				})
				test({
					test = {
						works = {
							fine = "too"
						}
					}
				}, "test.works.fine.ok", "too", {
					test = {
						works = {
							fine = {
								ok = "too"
							}
						}
					}
				})
				test({
					test = {
						works = {
							fine = "too"
						}
					}
				}, "test.wont.work.really", "too", {
					test = {
						works = {
							fine = "too"
						},
						wont = {
							work = {
								really = "too"
							}
						}
					}
				})
				test({ }, "test.wont.work.really", "too", {
					test = {
						wont = {
							work = {
								really = "too"
							}
						}
					}
				})
				return
			end
		},
		{
			name = "table.Slice(...) must return a slice of given table",
			func = function()
				local test
				test = function(tbl, startPos, endPos)
					local result = table.Slice(tbl, startPos, endPos)
					return expect(table.Equal(result, {
						table.unpack(tbl, startPos, endPos)
					})).to.beTrue()
				end
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}, 1, 5)
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}, 3, 7)
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}, 5, 10)
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}, 1, 10)
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}, 1, 1)
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}, 10, 10)
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}, 10, 1)
				test({
					false,
					true,
					nil,
					"hello"
				}, 1, 4)
				test({
					false,
					true,
					nil,
					"hello"
				}, 2, 3)
				return
			end
		},
		{
			name = "table.Shuffle(...) must shuffle randomly given tabel",
			func = function()
				local tbl = {
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9,
					10
				}
				local result = table.Shuffle(table.Copy(tbl))
				expect(table.Equal(result, tbl)).to.beFalse()
				expect(table.Count(result)).to.equal(table.Count(tbl))
				expect(table.Equal(table.GetKeys(tbl), table.GetKeys(result))).to.beTrue()
				expect(table.Equal(table.GetValues(tbl), table.GetValues(result))).to.beFalse()
				return
			end
		},
		{
			name = "table.Random(...) must return random key and value from given table",
			func = function()
				local test
				test = function(tbl, isSequantial)
					local value, key = table.Random(tbl, isSequantial)
					expect(tbl[key]).to.equal(value)
					-- cant really test randomness here
					return
				end
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9
				})
				test({
					1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9
				}, true)
				test({
					["hello"] = "world",
					["test"] = "this",
					"very",
					"random",
					["test"] = "that",
					["must"] = "not",
					"fail"
				})
				test({
					true,
					false,
					nil,
					true,
					false,
					nil,
					false
				})
				test({
					true,
					false,
					nil,
					true,
					false,
					nil,
					false
				}, true)
				return
			end
		},
		{
			name = "table.LowerKeyNames(...) must lowercase each key in table",
			func = function()
				local test
				test = function(tbl, expected)
					local result = table.LowerKeyNames(tbl)
					return expect(table.Equal(result, expected)).to.beTrue()
				end
				test({ }, { })
				test({
					["Hello"] = "World"
				}, {
					["hello"] = "World"
				})
				test({
					["Hello"] = "World",
					["Test"] = "This"
				}, {
					["hello"] = "World",
					["test"] = "This"
				})
				test({
					1,
					2,
					3,
					4,
					"TEST",
					["EVERY"] = "THING"
				}, {
					1,
					2,
					3,
					4,
					"TEST",
					["every"] = "THING"
				})
				return
			end
		},
		{
			name = "table.Flip(...) must work as original table.Flip",
			func = function()
				local test
				test = function(tbl, expected)
					local result = table.Flip(tbl)
					return expect(table.Equal(result, expected)).to.beTrue()
				end
				test({ }, { })
				test({
					["hello"] = "world"
				}, {
					["world"] = "hello"
				})
				test({
					[true] = false
				}, {
					[false] = true
				})
				test({
					[3] = 1
				}, {
					[1] = 3
				})
				test({
					["never"] = "gonna",
					["give"] = "you",
					"up"
				}, {
					["gonna"] = "never",
					["you"] = "give",
					["up"] = 1
				})
				return
			end
		}
	}
}

---@meta

---@alias bool boolean

--- [SHARED AND MENU]
---
--- Dreamwork powered metatables.
---
---@class dreamwork.std.Metatable<K, V>
local metatable = {}

---
--- Human-readable type name.
---
--- Changes the behavior of `type( value )` and `tostring( value )`.
---
---@type string?
metatable.__type = nil

---
--- Legacy type name used by some systems.
---
--- **DO NOT USE THIS**
---
---@type string?
metatable.MetaName = nil

---
--- Legacy numeric type identifier.
---
--- **DO NOT USE THIS**
---
---@type integer?
metatable.MetaID = nil

---
--- Controls how "weak" a table is.
---
--- If present, must be one of the following strings:
--- - `"k"`, for a table with weak keys;
--- - `"v"`, for a table with weak values;
--- - `"kv"`, for a table with both weak keys and values.
---
--- A table with weak keys and strong values is also called an ephemeron table.
---
--- In an ephemeron table, a value is considered reachable only if its key is reachable.
---
--- In particular, if the only reference to a key comes through its value, the pair is removed.
---
--- See [§2.5.4](https://www.lua.org/manual/5.4/manual.html#2.5.4)
---
---@type "k" | "v" | "kv" | nil
metatable.__mode = nil

---
--- Changes the behavior of `getmetatable( value )`.
---
--- If object does not have a metatable, returns nil.
---
--- Otherwise, if the object's metatable has a `__metatable` field, returns the associated value.
---
--- Otherwise, returns the metatable of the given object.
---
---@type any
metatable.__metatable = nil

---
--- Used very rarely internally and by `tostring( value )` if the `__tostring` metamethod is missing.
---
--- See [`luaL_newmetatable`](https://www.lua.org/manual/5.4/manual.html#luaL_newmetatable)
---
---@type string | nil
metatable.__name = nil

---
--- If the metatable of `v` has a `__tostring` field,
--- then tostring calls the corresponding value with `v` as the argument,
--- and uses the result of the call as its result.
---
--- Otherwise, if the metatable of `v` has a `__name` field with a string value,
--- tostring may use that string in its final result.
---
---@generic K, V
---@type fun(self: table<K, V>): string
metatable.__tostring = nil

---
--- Called when the the garbage collector detects that the corresponding table or userdata is dead.
---
--- **Important:** In ~~LuaJIT~~ garrysmod this metamethod is **not called** for tables, only used for `userdata`.
---
--- See [§2.5.3](https://www.lua.org/manual/5.4/manual.html#2.5.3)
---
---@generic K, V
---@type fun(self: table<K, V>)
metatable.__gc = nil

---
--- Called when a variable is closed.
---
--- See [§3.3.8](https://www.lua.org/manual/5.4/manual.html#3.3.8)
---
---@generic K, V
---@type fun(self: table<K, V>, errobj: any): any
metatable.__close = nil

---
--- The addition `+` operation.
---
--- `a + b = result`
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): table<K, V>
metatable.__add = nil

---
--- The subtraction `-` operation.
---
--- `a - b = result`
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): table<K, V>
metatable.__sub = nil

---
--- The multiplication `*` operation.
---
--- `a * b = result`
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): table<K, V>
metatable.__mul = nil

---
--- The division `/` operation.
---
--- `a / b = result`
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): table<K, V>
metatable.__div = nil

---
--- The negation/unary `-` operation.
---
--- `-a = result`
---
--- This is equivalent to `a * -1`.
---
---@generic K, V
---@type fun(self: table<K, V>): table<K, V>
metatable.__unm = nil

---
--- The modulo `%` operation.
---
--- `a % b = result`
---
--- This is equivalent to `math.mod( a, b )`.
---
--- Note that this is different from `math.modf( a )`, which returns the remainder and fractional part of a number.
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): table<K, V>
metatable.__mod = nil

---
--- The exponentiation `^` operation.
---
--- `a ^ b = result`
---
--- This is equivalent to `math.pow( a, b )`.
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): table<K, V>
metatable.__pow = nil

---
--- The floor division `//` operation.
---
--- Used by `math.fdiv( a, b )` function.
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): table<K, V>
metatable.__idiv = nil

---
--- The bitwise AND `&` operation.
---
--- Used by `bit.band( a, b )` function.
---
---@generic K, V
---@type fun(self: table<K, V>, ...: table<K, V>?): table<K, V>
metatable.__band = nil

---
--- The bitwise OR `|` operation.
---
--- Used by `bit.bor( a, b )` function.
---
---@generic K, V
---@type fun(self: table<K, V>, ...: table<K, V>?): table<K, V>
metatable.__bor = nil

---
--- The bitwise XOR `~` operation.
---
--- Used by `bit.bxor( a, b )` function.
---
---@generic K, V
---@type fun(self: table<K, V>, ...: table<K, V>?): table<K, V>
metatable.__bxor = nil

---
--- The bitwise NOT `~` operation.
---
--- Used by `bit.bnot( a )` function.
---
---@generic K, V
---@type fun(self: table<K, V>): table<K, V>
metatable.__bnot = nil

---
--- The left shift `<<` operation.
---
--- Used by `bit.lshift( a, b )` function.
---
---@generic T
---@type fun( self: T, bit_count: integer ): T
metatable.__shl = nil

---
--- The right shift `>>` operation.
---
--- Used by `bit.rshift( a, b )` function.
---
---@generic T
---@type fun( self: T, bit_count: integer ): T
metatable.__shr = nil

---
--- The arithmetic right shift operation.
---
--- Like `__shr`, but the vacated high-order bits are filled with copies of the sign bit
--- instead of zeros, so the sign of the value is preserved.
---
--- Used by `bit.arshift( a, b )` function.
---
---@generic T
---@type fun( self: T, bit_count: integer ): T
metatable.__shar = nil

---
--- The bit rotate left operation.
---
--- Rotates bits to the left; bits shifted out of the top are wrapped around and shifted
--- back in at the bottom, so no bits are lost.
---
--- Used by `bit.rol( a, b )` function.
---
---@generic T
---@type fun( self: T, bit_count: integer ): T
metatable.__brol = nil

---
--- The bit rotate right operation.
---
--- Rotates bits to the right; bits shifted out of the bottom are wrapped around and shifted
--- back in at the top, so no bits are lost.
---
--- Used by `bit.ror( a, b )` function.
---
---@generic T
---@type fun( self: T, bit_count: integer ): T
metatable.__bror = nil

---
--- The byte swap operation.
---
--- Reverses the byte order (endianness) of a 32-bit integer, swapping its four
--- constituent bytes end-to-end.
---
--- Used by `bit.bswap( a )` function.
---
---@generic T
---@type fun( self: T ): T
metatable.__bswp = nil

---
--- The concatenation `..` operation.
---
--- Behavior similar to calculation operators,
--- except that Lua will try a metamethod if
--- any operand is neither a string nor a number
--- (which is always coercible to a string).
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): string | table<K, V>
metatable.__concat = nil

---
--- The length `#` operation.
---
--- Used by `len( value )` function.
---
--- If the object is not a string, Lua will try its metamethod.
---
--- If there is a metamethod,
--- Lua calls it with the object as argument,
--- and the result of the call (always adjusted to one value) is the result of the operation.
---
--- If there is no metamethod but the object is a table,
--- then Lua uses the table length operation.
---
--- Otherwise, Lua raises an error.
---
--- See [§3.4.7](https://www.lua.org/manual/5.4/manual.html#3.4.7)
---
---@generic K, V
---@type fun(self: table<K, V>): integer
metatable.__len = nil

---
--- The equal `==` operation.
---
--- Behavior similar to calculation operators,
--- except that Lua will try a metamethod only
--- when the values being compared are either
--- both tables or both full userdata and
--- they are not primitively equal.
---
--- The result of the call is always converted to a `boolean`.
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): boolean
metatable.__eq = nil

---
--- The less than `<` operation.
---
--- Behavior similar to calculation operators,
--- except that Lua will try a metamethod only
--- when the values being compared are neither
--- both numbers nor both strings.
---
--- Moreover, the result of the call is always converted to a boolean.
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): boolean
metatable.__lt = nil

---
--- The less equal `<=` operation.
---
--- Behavior similar to the less than operation.
---
---@generic K, V
---@type fun(self: table<K, V>, other: any): boolean
metatable.__le = nil

---
--- The indexing access operation `table[key]`.
---
--- This event happens when `table` is not a table or when `key` is not present in `table`.
---
--- The metavalue is looked up in the metatable of `table`.
---
--- The metavalue for this event can be either a function, a table, or any value with an `__index` metavalue.
---
--- If it is a function, it is called with `table` and `key` as arguments, and the result of the call (adjusted to one value) is the result of the operation.
---
--- Otherwise, the final result is the result of indexing this metavalue with `key`.
---
--- This indexing is regular, not raw, and therefore can trigger another `__index` metavalue.
---
--- **Examples**:
--- ```lua
--- local data = {foo = 'bar'}
--- local proxy = setmetatable({}, {__index = data})
---
--- print(proxy.foo) --> 'bar'
--- ```
--- ```lua
--- local tab = setmetatable({count = 0}, {
---   __index = function(self, _k)
---     self.count = self.count + 1
---     return self.count
---   end
--- })
---
--- print(tab.indextest) --> 1
--- print(tab.indextestagain) --> 2
--- print(tab.asdfasdf) --> 3
--- print(tab[1234]) --> 4
--- ```
---
---@generic K, V
---@type table<K, V> | (fun(self: table<K, V>, key: K): V?)
metatable.__index = nil

---
--- The indexing assignment `table[key] = value`.
---
--- Like the index event, this event happens when `table` is not a table or when `key` is not present in `table`.
---
--- The metavalue is looked up in the metatable of `table`.
---
--- Like with indexing, the metavalue for this event can be either a function, a table, or any value with an `__newindex` metavalue.
---
--- If it is a function, it is called with `table`, `key`, and `value` as arguments.
---
--- Otherwise, Lua repeats the indexing assignment over this metavalue with the same key and value.
---
--- This assignment is regular, not raw, and therefore can trigger another `__newindex` metavalue.
---
--- Whenever a `__newindex` metavalue is invoked, Lua does not perform the primitive assignment.
---
--- If needed, the metamethod itself can call rawset to do the assignment.
---
--- **Examples:**
---
--- ```lua
--- local t = setmetatable({}, {
---   __newindex = function(t, key, value)
---     if type(value) == 'number' then
---       rawset(t, key, value * value)
---     else
---       rawset(t, key, value)
---     end
---   end
--- })
---
--- t.foo = 'foo'
--- t.bar = 4
--- t.la = 10
--- print(t.foo) --> 'foo'
--- print(t.bar) --> 16
--- print(t.la) --> 100
--- ```
---
---@generic K, V
---@type table<K, V> | (fun(self: table<K, V>, key: K, value: V))
metatable.__newindex = nil

---
--- The call operation `func(args)`.
---
--- This event happens when Lua tries to call a non-function value (that is, `func` is not a function).
---
--- Instead of use `isFunction( value )` you can use `isCallable( value )` that checks  if a value is callable.
---
--- The metamethod is looked up in `func`.
---
--- If present, the metamethod is called with `func` as its first argument, followed by the arguments of the original call (`args`).
---
--- All results of the call are the results of the operation.
---
--- This is the only metamethod that allows multiple results.
---
--- **Examples:**
---
--- ```lua
--- local t = setmetatable({}, {
---   __call = function(t, ...)
---     print('Called with:', ...)
---   end
--- })
---
--- t(1, 2, 3) --> 'Called with: 1 2 3'
--- ```
---
---@generic K, V
---@type fun(self: table<K, V>, ...: any ): any
metatable.__call = nil

---
--- Affects iteration when using the `pairs()` function, letting you define a custom iterator function (see [`pairs()`](https://www.lua.org/manual/5.4/manual.html#pdf-pairs), [`next()`](https://www.lua.org/manual/5.4/manual.html#pdf-next)).
---
---@generic K, V
---@type fun(self: table<K, V>): fun(tbl: table<K, V>, key: K?): K?, V?
metatable.__pairs = nil

---
--- Creates a copy of the given object.
---
--- This is used by the `copy( value )` function.
--- If not defined, a shallow copy will be created using the default Lua copying mechanism.
---
--- If you want to create a deep copy, you will need to implement this metamethod yourself.
---
---@generic K, V
---@type fun(self: table<K, V>): table<K, V>
metatable.__copy = nil

---
--- Serializes the object into a writer.
---
---@generic K, V
---@type fun(self: table<K, V>, writer: dreamwork.std.BinaryWriter, ...: any?)
metatable.__serialize = nil

---
--- Deserializes the object from a reader.
---
---@generic K, V
---@type fun(self: table<K, V>, reader: dreamwork.std.BinaryReader, ...: any?)
metatable.__deserialize = nil

---
--- Converts the object into a number.
---
---@generic K, V
---@type fun(self: table<K, V>, base: integer): number | integer
metatable.__tonumber = nil

---
--- Converts the object into a boolean value.
---
---@generic K, V
---@type fun(self: table<K, V>): boolean
metatable.__toboolean = nil

---
--- Converts the object into a color.
---
---@generic K, V
---@type fun(self: table<K, V>): dreamwork.std.Color
metatable.__tocolor = nil

---
--- Returns a developer-oriented representation of the object.
---
--- This is used by the `represent( value )` function and in the debugger.
---
--- Also this affects `print`-like functions.
---
---@generic K, V
---@type fun(self: table<K, V>): string
metatable.__represent = nil

---
--- Checks whether the object is valid.
---
---@generic K, V
---@type fun(self: table<K, V>): boolean
metatable.__isvalid = nil

---
--- Returns a stable hash value for the object.
---
---@generic K, V
---@type fun(self: table<K, V>): integer
metatable.__hash = nil

---
--- Returns binary size of the `object` as integer of bit/bytes.
---
---@generic K, V
---@type fun(self: table<K, V>, as_bytes: boolean): integer
metatable.__sizeof = nil

--- [SHARED AND MENU]
---
--- Specifies what information to retrieve from `debug.getinfo`.
---
--- Each letter selects a group of fields to populate on the returned
--- `debuginfo` table; unrequested fields are left `nil`.
---
--- Multiple letters can be combined in a single string (e.g. `"nSl"`).
---
---@alias dreamwork.std.debug.InfoWhat string
---|+"f" # Function value. Fills `func`.
---|+"l" # Current line. Fills `currentline`.
---|+"L" # Active lines. Fills `activelines`.
---|+"n" # Name info. Fills `name` and `namewhat`.
---|+"S" # Source info. Fills `source`, `short_src`, `linedefined`, `lastlinedefined`, and `what`.
---|+"u" # Upvalue/parameter info. Fills `nups`, `nparams`, and `isvararg`.
---|+">" # LuaJIT extension; causes this function to use the last argument to get the data from, instead of treating it as a stack level; the function value is popped/consumed in the process. No fields of its own — combine with other letters (e.g. `">S"`).

--- [SHARED AND MENU]
---
--- Contains information about a function.
---
--- [View documents](http://www.lua.org/manual/5.4/manual.html#pdf-debug.getinfo)
---
---@class dreamwork.std.debug.Info
---@field name             string | nil  The name of the function, if a reasonable name can be found. Only valid when `what` includes `"n"`.
---@field namewhat         string | nil  Explains the `name` field. Its value may be `"global"`, `"local"`, `"method"`, `"field"`, `"upvalue"`, or `""` (the empty string) when no other option applies.
---@field source           string | nil  The source of the chunk that created the function. If it starts with `@`, the function was defined in a file whose name follows the `@`. If it starts with `=`, the remainder describes the source in a user-dependent manner. Otherwise, the function was defined in a string equal to `source`.
---@field short_src        string | nil  A "printable" version of `source`, to be used in error messages.
---@field linedefined      integer | nil The line number where the definition of the function starts.
---@field lastlinedefined  integer | nil The line number where the definition of the function ends.
---@field what             "Lua" | "C" | nil  The type of the function: `"Lua"` if it's a normal Lua function, `"C"` if it's a C function, `"main"` if it's the main part of a chunk.
---@field currentline      integer | nil The current line where the given function is executing. -1 when no line information is available.
---@field nups             integer | nil The number of upvalues of the function.
---@field nparams          integer | nil The number of fixed parameters of the function (always 0 for C functions).
---@field isvararg         boolean | nil `true` if the function is a vararg function (always `true` for C functions).
---@field func             function | nil The function itself. Only valid when `what` includes `"f"`.
---@field activelines      table<integer, ( true | nil )> | nil A set whose keys are the line numbers with associated code (i.e. valid lines for breakpoints); each present key maps to `true`. Only valid when `what` includes `"L"`.

---@class getregistry
getregistry = {}

--- [SHARED AND MENU]
---
--- Returns the registry table.
---
--- [View documents](http://www.lua.org/manual/5.4/manual.html#pdf-debug.getregistry)
---
---@return table
---@nodiscard
function getregistry.Get() end

--- [SHARED AND MENU]
---
--- HTTP request method.
---
---@alias dreamwork.std.http.Request.method
---| "HEAD" # Same as `GET`, but only retrieves headers (no body).
---| "GET" # Retrieve data from a server.
---| "POST" # Send data to the server to create a resource.
---| "PUT" # Replace a resource entirely at the given URL.
---| "PATCH" # Partially update a resource.
---| "DELETE" # Remove a resource from the server.
---| "OPTIONS" # Describe communication options for the target resource.

--- [SHARED AND MENU]
---
--- HTTP request URL.
---
---@alias dreamwork.std.http.Request.url
---| string # Absolute URL as a string.
---| dreamwork.std.URL # Absolute URL object.
---| "http://" # Default protocol.
---| "https://" # Default secure protocol.

--- [SHARED AND MENU]
---
--- HTTP request content type.
---
---@alias dreamwork.std.http.Request.content_type
---| string
---| "text/plain; charset=utf-8"
---| "text/html; charset=utf-8"
---| "text/css; charset=utf-8"
---| "text/csv; charset=utf-8"
---| "text/javascript; charset=utf-8"
---| "application/json; charset=utf-8"
---| "application/xml; charset=utf-8"
---| "application/x-www-form-urlencoded"
---| "multipart/form-data"
---| "application/yaml; charset=utf-8"
---| "application/octet-stream"
---| "application/pdf"
---| "application/zip"
---| "application/x-pem-file"
---| "application/jwt"
---| "application/vnd.api+json; charset=utf-8"
---| "image/png"
---| "image/jpeg"
---| "image/gif"
---| "audio/mpeg"
---| "audio/ogg"
---| "video/mp4"
---| "video/webm"

--- [SHARED AND MENU]
---
--- HTTP request headers.
---
---@alias dreamwork.std.http.Request.headers table<string, string>

--- [SHARED AND MENU]
---
--- HTTP request parameters.
---
---@alias dreamwork.std.http.Request.parameters dreamwork.std.URL.SearchParams | table | nil

do

    --- [SHARED AND MENU]
    ---
    --- Options table for `http.request` function.
    ---
    ---@class dreamwork.std.http.Request
    local request = {}

    --- Request method.
    ---
    ---@type dreamwork.std.http.Request.method
    request.method = nil

    --- Request URL.
    ---
    ---@type dreamwork.std.http.Request.url
    request.url = nil

    --- KeyValue table for parameters.
    ---
    --- This is only applicable to the following request methods: **HEAD**, **GET**, **POST**
    ---
    ---@type dreamwork.std.http.Request.parameters
    request.parameters = nil

    --- Body string for POST data.
    ---
    --- If set, will override parameters.
    ---
    ---@type string?
    request.body = nil

    --- Content type for body.
    ---
    ---@type dreamwork.std.http.Request.content_type?
    request.content_type = "text/plain; charset=utf-8"

    --- KeyValue table for headers.
    ---
    ---@type dreamwork.std.http.Request.headers?
    request.headers = nil

    --- The timeout for the connection in seconds.
    ---
    --- The default timeout is 60 seconds.
    ---
    --- `0` means no timeout.
    ---
    ---@type integer?
    request.timeout = 60

    --- Whether to cache the response.
    ---
    ---@type boolean?
    request.cache = false

    --- The cache time to live for the request.
    ---
    ---@type number?
    request.cache_ttl = nil

    --- Whether to use ETag caching.
    ---
    ---@type boolean?
    request.etag = false

end

do

    --- [SHARED AND MENU]
    ---
    --- The success callback.
    ---
    ---@class dreamwork.std.http.Response
    local response = {}

    --- The response status code.
    ---
    ---@type integer
    response.status = nil

    --- The response body.
    ---
    ---@type string
    response.body = nil

    --- The response headers.
    ---
    ---@type dreamwork.std.http.Request.headers
    response.headers = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- The server information table.
    ---@class dreamwork.std.server.Info
    local server_info = {}

    --- The server ping in milliseconds.
    ---@type number
    server_info.ping = 0

    --- The server name.
    ---
    --- This value is set on the server by the `hostname` convar.
    ---@type string
    server_info.name = "Garry's Mod"

    --- The name of the loaded level on the server.
    ---
    --- BSP: `maps/{name}.bsp`
    --- AI navigation: `maps/{name}.ain`
    --- Navigation Mesh: `maps/{name}.nav`
    ---@type string
    server_info.level_name = "gm_construct"

    --- Contains the version number of GMod.
    ---@type number
    server_info.version = 201211

    --- The server address in IP:Port format.
    ---@type string
    server_info.address = "127.0.0.1:27015"

    --- Two digit country code in the [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) standard.
    ---
    --- This value is set on the server by the [sv_location](https://wiki.facepunch.com/gmod/Downloading_a_Dedicated_Server#locationflag) convar.
    ---@type string?
    server_info.country = nil

    --- Time when you last played on this server, as UNIX timestamp or 0.
    ---@type number
    server_info.last_played_time = 0

    --- Whether this server has password or not.
    ---
    --- On the server, this value is set by the console variable `sv_password`.
    ---@type boolean
    server_info.has_password = false

    --- Is the server signed into an anonymous account?
    ---
    --- The value will be `false` if `+sv_setsteamaccount` is equal to a valid Steam game server token.
    ---
    --- [Steam Game Server Accounts](https://wiki.facepunch.com/gmod/Steam_Game_Server_Accounts)
    ---@type boolean
    server_info.is_anonymous = false

    --- The number of players on the server.
    ---
    --- This is a total player count including both real people and bots created by the server.
    ---@type number
    server_info.player_count = 0

    --- The maximum number of players on the server.
    ---
    --- This value can be set at server startup using the console variable [`+maxplayers`](https://developer.valvesoftware.com/wiki/Maxplayers).
    ---@type number
    server_info.player_limit = 0

    --- The number of bots on the server created by the server itself.
    ---@type number
    server_info.bot_count = 0

    --- The number of real people (game clients) on the server.
    ---@type number
    server_info.human_count = 0

    --- The [gamemode folder](https://wiki.facepunch.com/gmod/Gamemode_Creation#gamemodefolder) name and the [`GM.Folder`](https://wiki.facepunch.com/gmod/Gamemode_Creation#gamemodefoldername) value.
    ---
    --- This applies to Garry's gamemodes, they are different from the gamemodes in dreamwork...
    ---@type string
    server_info.gamemode_name = "sandbox"

    --- The [`GM.Name`](https://wiki.facepunch.com/gmod/Gamemode_Creation#sharedlua) value.
    ---
    --- This applies to Garry's gamemodes, they are different from the gamemodes in dreamwork...
    ---@type string
    server_info.gamemode_title = "Sandbox"

    --- The identifier of the gamemode workshop item in the Steam workshop.
    ---@type string?
    server_info.gamemode_wsid = nil

    --- The [category](https://wiki.facepunch.com/gmod/Gamemode_Creation#gamemodetextfile) of the gamemode, ex. `pvp`, `pve`, `rp` or `roleplay`.
    ---@type string
    server_info.gamemode_category = "other"

end

do

    --- [MENU]
    ---
    --- Queries the servers for it's information.
    ---@class dreamwork.std.server.QueryData
    local query_data = {}

    --- The game directory to get the servers for
    ---@type string
    query_data.directory = "garrysmod"

    --- Type of servers to retrieve. Valid values are `internet`, `favorite`, `history` and `lan`
    ---@type string
    query_data.type = nil

    --- Steam application ID to get the servers for
    ---@type number
    query_data.appid = 4000

    --- Called when a new server is found and queried.
    ---
    --- Function argument(s):
    --- * number `ping` - Latency to the server.
    --- * string `name` - Name of the server
    --- * string `gamemode_title` - "Nice" gamemode name
    --- * string `level_name` - Current map
    --- * number `player_count` - Total player number ( bot + human )
    --- * number `player_limit` - Maximum reported amount of players
    --- * number `bot_count` - Amount of bots on the server
    --- * boolean `has_password` - Whether this server has password or not
    --- * number `last_played_time` - Time when you last played on this server, as UNIX timestamp or 0
    --- * string `address` - IP Address of the server
    --- * string `gamemode_name` - Gamemode folder name
    --- * number `gamemode_wsid` - Gamemode Steam Workshop ID
    --- * boolean `is_anonymous` - Is the server signed into an anonymous account?
    --- * string `version` - Version number, same format as jit.version_number
    --- * string `country` - Two digit country code, `us` if nil
    --- * string `gamemode_category` - Category of the gamemode, ex. `pvp`, `pve`, `rp` or `roleplay`
    ---
    --- Function return value(s):
    --- * boolean `stop` - Return `false` to stop the query.
    ---@type fun( ping: number, name: string, gamemode_title: string, level_name: string, player_count: number, player_limit: number, bot_count: number, has_password: boolean, last_played_time: number, address: string, gamemode_name: string, gamemode_wsid: number, is_anonymous: boolean, version: string, country: string, gamemode_category: string ): boolean
    query_data.server_queried = nil

    --- Called if the query has failed, called with the servers IP Address
    ---@type function
    query_data.query_failed = nil

    --- Called when the query is finished. No arguments
    ---@type function
    query_data.finished = nil

end

do

    ---@class dreamwork.std.console.Command : dreamwork.std.Object
    local command = {}

    --- **READ-ONLY**
    ---
    --- The name of the console command/variable.
    ---
    ---@type string
    command.name = nil

    --- **READ-ONLY**
    ---
    --- The help text of the console command/variable.
    ---
    ---@type string?
    command.description = nil

    --- **READ-ONLY**
    ---
    --- The console command/variable flags.
    ---
    --- Used in engine internally.
    ---
    --- [C++ Code](https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/sp/src/public/tier1/iconvar.h#L39)
    ---
    --- [Valve Wiki](https://developer.valvesoftware.com/wiki/Developer_Console_Control#The_FCVAR_flags)
    ---
    --- [Facepunch Wiki](https://wiki.facepunch.com/gmod/Enums/FCVAR)
    ---
    ---@type integer?
    command.flags = nil

    --- **READ-ONLY**
    ---
    --- If this is set, don't add to linked list, etc.
    ---
    ---@type boolean?
    command.unregistered = nil

    --- **READ-ONLY**
    ---
    --- Hidden in released products.
    ---
    --- Flag is removed automatically if `ALLOW_DEVELOPMENT_CVARS` is defined in C++.
    ---
    ---@type boolean?
    command.development_only = nil

    --- **READ-ONLY**
    ---
    --- Defined by the game DLL.
    ---
    ---@type boolean?
    command.game_dll = nil

    --- **READ-ONLY**
    ---
    --- Defined by the client DLL.
    ---
    ---@type boolean?
    command.client_dll = nil

    --- **READ-ONLY**
    ---
    --- Doesn't appear in find or autocomplete.
    ---
    --- Like `development_only`, but can't be compiled out.
    ---
    ---@type boolean?
    command.hidden = nil

    --- **READ-ONLY**
    ---
    --- It's a server cvar, but we don't send the data since it's a password, etc.
    ---
    --- Sends `1` if it's not bland/zero, `0` otherwise as value.
    ---
    ---@type boolean?
    command.protected = nil

    --- **READ-ONLY**
    ---
    --- This cvar cannot be changed by clients connected to a multiplayer server.
    ---
    ---@type boolean?
    command.sponly = nil

    --- **READ-ONLY**
    ---
    --- Save the cvar value into either `client.vdf` or `server.vdf`.
    ---
    ---@type boolean?
    command.archive = nil

    --- **READ-ONLY**
    ---
    --- For server-side cvars, notifies all players with blue chat text when the value gets changed, also makes the convar appear in [A2S_RULES](https://developer.valvesoftware.com/wiki/Server_queries#A2S_RULES).
    ---
    ---@type boolean?
    command.notify = nil

    --- **READ-ONLY**
    ---
    --- For client-side commands, sends the value to the server.
    ---
    ---@type boolean?
    command.userinfo = nil

    --- **READ-ONLY**
    ---
    --- In multiplayer, prevents this command/variable from being used unless the server has `sv_cheats` turned on.
    ---
    --- If a client connects to a server where cheats are disabled (which is the default), all client side console variables labeled as `cheat` are reverted to their default values and can't be changed as long as the client stays connected.
    ---
    --- Console commands marked as `cheat` can't be executed either.
    ---
    --- As a general rule of thumb, any client-side command that isn't specifically meant to be configured by users should be marked with this flag, as even the most harmless looking commands can sometimes be misused to cheat.
    ---
    --- For server-side only commands you can be more lenient, since these would have no effect when changed by connected clients anyway.
    ---
    ---@type boolean?
    command.cheat = nil

    --- **READ-ONLY**
    ---
    --- This cvar's string cannot contain unprintable characters ( e.g., used for player name etc ).
    ---
    ---@type boolean?
    command.printable_only = nil

    --- **READ-ONLY**
    ---
    --- If this is a server-side, don't log changes to the log file / console if we are creating a log.
    ---
    ---@type boolean?
    command.unlogged = nil

    --- **READ-ONLY**
    ---
    --- Tells the engine to never print this console variable as a string.
    ---
    --- This is used for variables which may contain control characters.
    ---
    ---@type boolean?
    command.never_as_string = nil

    --- **READ-ONLY**
    ---
    --- When set on a console variable, all connected clients will be forced to match the server-side value.
    ---
    --- This should be used for shared code where it's important that both sides run the exact same path using the same data.
    ---
    --- (e.g. predicted movement/weapons, game rules)
    ---
    ---@type boolean?
    command.replicated = nil

    --- **READ-ONLY**
    ---
    --- When starting to record a demo file, explicitly adds the value of this console variable to the recording to ensure a correct playback.
    ---
    ---@type boolean?
    command.demo = nil

    --- **READ-ONLY**
    ---
    --- Opposite of `DEMO`, ensures the cvar is not recorded in demos.
    ---
    ---@type boolean?
    command.dont_record = nil

    --- **READ-ONLY**
    ---
    --- If set and this variable changes, it forces a material reload.
    ---
    ---@type boolean?
    command.reload_materials = nil

    --- **READ-ONLY**
    ---
    --- If set and this variable changes, it forces a texture reload.
    ---
    ---@type boolean?
    command.reload_textures = nil

    --- **READ-ONLY**
    ---
    --- Prevents this variable from being changed while the client is currently in a server, due to the possibility of exploitation of the command (e.g. `fps_max`).
    ---
    ---@type boolean?
    command.not_connected = nil

    --- **READ-ONLY**
    ---
    --- Indicates this cvar is read from the material system thread.
    ---
    ---@type boolean?
    command.material_system_thread = nil

    --- **READ-ONLY**
    ---
    --- Like `archive`, but for [Xbox 360](https://de.wikipedia.org/wiki/Xbox_360).
    ---
    --- Needless to say, this is not particularly useful to most modders.
    ---
    --- Save the cvar value into `config.vdf` on XBox.
    ---
    ---@type boolean?
    command.archive_xbox = nil

    --- **READ-ONLY**
    ---
    --- Used as a debugging tool necessary to check material system thread convars.
    ---
    ---@type boolean?
    command.accessible_from_threads = nil

    --- **READ-ONLY**
    ---
    --- The server is allowed to execute this command on clients via `ClientCommand/NET_StringCmd/CBaseClientState::ProcessStringCmd`.
    ---
    ---@type boolean?
    command.server_can_execute = nil

    --- **READ-ONLY**
    ---
    --- If this is set, then the server is not allowed to query this cvar's value (via `IServerPluginHelpers::StartQueryCvarValue`).
    ---
    ---@type boolean?
    command.server_cannot_query = nil

    --- **READ-ONLY**
    ---
    --- `IVEngineClient::ClientCmd` is allowed to execute this command.
    ---
    ---@type boolean?
    command.clientcmd_can_execute = nil

    --- **READ-ONLY**
    ---
    --- Summary of `reload_materials`, `reload_textures` and `material_system_thread`.
    ---
    ---@type boolean?
    command.material_thread_mask = nil

    --- **READ-ONLY**
    ---
    --- Sets automatically on all cvars and console commands created by the `client` Lua state.
    ---
    ---@type boolean?
    command.lua_client = nil

    --- **READ-ONLY**
    ---
    --- Sets automatically on all cvars and console commands created by the `server` Lua state.
    ---
    ---@type boolean?
    command.lua_server = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- Table used by `console.Command` class constructor.
    ---
    ---@class dreamwork.std.console.Command.Options
    local options = {}

    --- The name of the console command/variable.
    ---
    ---@type string
    options.name = nil

    --- The help text of the console command/variable.
    ---
    ---@type string?
    options.description = nil

    --- The console command/variable flags.
    ---
    --- Used in engine internally.
    ---
    --- [C++ Code](https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/sp/src/public/tier1/iconvar.h#L39)
    ---
    --- [Valve Wiki](https://developer.valvesoftware.com/wiki/Developer_Console_Control#The_FCVAR_flags)
    ---
    --- [Facepunch Wiki](https://wiki.facepunch.com/gmod/Enums/FCVAR)
    ---
    ---@type integer?
    options.flags = nil

    --- If this is set, don't add to linked list, etc.
    ---
    ---@type boolean?
    options.unregistered = nil

    --- Hidden in released products.
    ---
    --- Flag is removed automatically if `ALLOW_DEVELOPMENT_CVARS` is defined in C++.
    ---
    ---@type boolean?
    options.development_only = nil

    --- Defined by the game DLL.
    ---
    ---@type boolean?
    options.game_dll = nil

    --- Defined by the client DLL.
    ---
    ---@type boolean?
    options.client_dll = nil

    --- Doesn't appear in find or autocomplete.
    ---
    --- Like `development_only`, but can't be compiled out.
    ---
    ---@type boolean?
    options.hidden = nil

    --- It's a server cvar, but we don't send the data since it's a password, etc.
    ---
    --- Sends `1` if it's not bland/zero, `0` otherwise as value.
    ---
    ---@type boolean?
    options.protected = nil

    --- This cvar cannot be changed by clients connected to a multiplayer server.
    ---
    ---@type boolean?
    options.sponly = nil

    --- Save the cvar value into either `client.vdf` or `server.vdf`.
    ---
    ---@type boolean?
    options.archive = nil

    --- For server-side cvars, notifies all players with blue chat text when the value gets changed, also makes the convar appear in [A2S_RULES](https://developer.valvesoftware.com/wiki/Server_queries#A2S_RULES).
    ---
    ---@type boolean?
    options.notify = nil

    --- For client-side commands, sends the value to the server.
    ---
    ---@type boolean?
    options.userinfo = nil

    --- In multiplayer, prevents this command/variable from being used unless the server has `sv_cheats` turned on.
    ---
    --- If a client connects to a server where cheats are disabled (which is the default), all client side console variables labeled as `cheat` are reverted to their default values and can't be changed as long as the client stays connected.
    ---
    --- Console commands marked as `cheat` can't be executed either.
    ---
    --- As a general rule of thumb, any client-side command that isn't specifically meant to be configured by users should be marked with this flag, as even the most harmless looking commands can sometimes be misused to cheat.
    ---
    --- For server-side only commands you can be more lenient, since these would have no effect when changed by connected clients anyway.
    ---
    ---@type boolean?
    options.cheat = nil

    --- This cvar's string cannot contain unprintable characters ( e.g., used for player name etc ).
    ---
    ---@type boolean?
    options.printable_only = nil

    --- If this is a server-side, don't log changes to the log file / console if we are creating a log.
    ---
    ---@type boolean?
    options.unlogged = nil

    --- Tells the engine to never print this console variable as a string.
    ---
    --- This is used for variables which may contain control characters.
    ---
    ---@type boolean?
    options.never_as_string = nil

    --- When set on a console variable, all connected clients will be forced to match the server-side value.
    ---
    --- This should be used for shared code where it's important that both sides run the exact same path using the same data.
    ---
    --- (e.g. predicted movement/weapons, game rules)
    ---
    ---@type boolean?
    options.replicated = nil

    --- When starting to record a demo file, explicitly adds the value of this console variable to the recording to ensure a correct playback.
    ---
    ---@type boolean?
    options.demo = nil

    --- Opposite of `DEMO`, ensures the cvar is not recorded in demos.
    ---
    ---@type boolean?
    options.dont_record = nil

    --- If set and this variable changes, it forces a material reload.
    ---
    ---@type boolean?
    options.reload_materials = nil

    --- If set and this variable changes, it forces a texture reload.
    ---
    ---@type boolean?
    options.reload_textures = nil

    --- Prevents this variable from being changed while the client is currently in a server, due to the possibility of exploitation of the command (e.g. `fps_max`).
    ---
    ---@type boolean?
    options.not_connected = nil

    --- Indicates this cvar is read from the material system thread.
    ---
    ---@type boolean?
    options.material_system_thread = nil

    --- Like `archive`, but for [Xbox 360](https://de.wikipedia.org/wiki/Xbox_360).
    ---
    --- Needless to say, this is not particularly useful to most modders.
    ---
    --- Save the cvar value into `config.vdf` on XBox.
    ---
    ---@type boolean?
    options.archive_xbox = nil

    --- Used as a debugging tool necessary to check material system thread convars.
    ---
    ---@type boolean?
    options.accessible_from_threads = nil

    --- The server is allowed to execute this command on clients via `ClientCommand/NET_StringCmd/CBaseClientState::ProcessStringCmd`.
    ---
    ---@type boolean?
    options.server_can_execute = nil

    --- If this is set, then the server is not allowed to query this cvar's value (via `IServerPluginHelpers::StartQueryCvarValue`).
    ---
    ---@type boolean?
    options.server_cannot_query = nil

    --- `IVEngineClient::ClientCmd` is allowed to execute this command.
    ---
    ---@type boolean?
    options.clientcmd_can_execute = nil

    --- Summary of `reload_materials`, `reload_textures` and `material_system_thread`.
    ---
    ---@type boolean?
    options.material_thread_mask = nil

    --- Set automatically on all cvars and console commands created by the `client` Lua state.
    ---
    ---@type boolean?
    options.lua_client = nil

    --- Set automatically on all cvars and console commands created by the `server` Lua state.
    ---
    ---@type boolean?
    options.lua_server = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- Table used by `console.Variable` class constructor.
    ---
    ---@class dreamwork.std.console.Variable.Options : dreamwork.std.console.Command.Options
    local options = {}

    --- The type of the console variable.
    ---
    ---@type dreamwork.std.console.VariableType?
    options.type = nil

    --- The default value of the console variable.
    ---
    ---@type dreamwork.std.console.VariableValue?
    options.default = nil

    --- The minimal value of the console variable.
    ---
    ---@type number?
    options.min = nil

    --- The maximum value of the console variable.
    ---
    ---@type number?
    options.max = nil

end

do

    ---@class dreamwork.std.console.Variable : dreamwork.std.console.Command
    local variable = {}

    --- The type of the console variable.
    ---
    ---@type dreamwork.std.console.VariableType
    variable.type = nil

    --- **READ-ONLY**
    ---
    --- The default value of the console variable.
    ---
    ---@type dreamwork.std.console.VariableValue
    variable.default = nil

    --- [SHARED AND MENU]
    ---
    --- The value of the console variable.
    ---
    ---@type dreamwork.std.console.VariableValue
    variable.value = nil

    --- **READ-ONLY**
    ---
    --- The minimal value of the console variable.
    ---
    ---@type number | nil
    variable.min = nil

    --- **READ-ONLY**
    ---
    --- The maximum value of the console variable.
    ---
    ---@type number | nil
    variable.max = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- Table used by `console.Logger` constructor.
    ---
    ---@class dreamwork.std.console.Logger.Options
    local options = {}

    --- The title of the logger.
    ---@type string | nil
    options.title = nil

    --- The color of the title.
    ---@type dreamwork.std.Color | nil
    options.color = nil

    --- The color of the text.
    ---@type dreamwork.std.Color | nil
    options.text_color = nil

    --- Whether to interpolate the message.
    ---@type boolean | nil
    options.interpolation = nil

    --- The developer mode check function.
    ---@type ( fun(): boolean ) | nil
    options.debug = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- The result table of executing `path.parse`.
    ---
    ---    ┌─────────────────────┬────────────┐
    ---    │          dir        │    base    │
    ---    ├──────┬              ├──────┬─────┤
    ---    │ root │              │ name │ ext │
    ---    "  /    home/user/dir/  file  .txt "
    ---    └──────┴──────────────┴──────┴─────┘
    --- (All spaces in the "" line should be ignored. They are purely for formatting.)
    ---
    ---@class dreamwork.std.path.Data
    local path_data = {}

    --- The root of the file path.
    ---
    ---@type "/" | ""
    path_data.root = ""

    --- The directory of the file path.
    ---
    ---@type string
    path_data.dir = ""

    --- The `basename` of the file path, basically the name of the file with extension.
    ---
    ---@type string
    path_data.base = ""

    --- The name of file in the file path.
    ---
    ---@type string
    path_data.name = ""

    --- The extension of file in the file path.
    ---
    ---@type string
    path_data.ext = ""

    --- Whether the file path is absolute or not.
    ---
    ---@type boolean
    path_data.abs = false

end

do

    --- [SHARED AND MENU]
    ---
    --- The URL state object.
    ---@class dreamwork.std.URL.State
    ---@field scheme string?
    ---@field username string?
    ---@field password string?
    ---@field hostname string | table | number | nil
    ---@field port number?
    ---@field path string | table | nil
    ---@field fragment string?
    ---@field query string | dreamwork.std.URL.SearchParams
    local URLState = {}

end

do

    --- [SHARED AND MENU]
    ---
    --- Git Tree
    ---
    --- The hierarchy between files in a Git repository.
    ---
    ---@class dreamwork.std.http.github.Tree
    local tree = {}

    --- The SHA1 of the tree.
    ---
    ---@type string
    tree.sha = nil

    --- The URL of the tree.
    ---
    ---@type string
    tree.url = nil

    --- Whether the tree is truncated.
    ---
    --- If truncated is true in the response
    --- then the number of items in the tree
    --- array exceeded our maximum limit.
    ---
    --- If you need to fetch more items,
    --- use the non-recursive method of
    --- fetching trees, and fetch one
    --- sub-tree at a time.
    ---
    ---@type boolean
    tree.truncated = nil

    --- [SHARED AND MENU]
    ---
    --- A list of files and directories in the tree.
    ---
    ---@class dreamwork.std.http.github.Tree.Item[]
    tree.tree = nil

    --- [SHARED AND MENU]
    ---
    --- A single file or directory in a tree.
    ---
    ---@class dreamwork.std.http.github.Tree.Item
    local item = {}

    --- The path to the file or directory.
    ---
    ---@type string
    tree.path = nil

    --- The type of item that this is.
    ---
    ---| Mode    | Meaning                      | Types    |
    ---|:--------|:-----------------------------|:---------|
    ---|`100644` | Normal file (non-executable) | `Blob`
    ---|`100755` | Executable file              | `Blob`
    ---|`040000` | Directory                    | `Tree`
    ---|`120000` | Symbolic link                | `Blob`
    ---|`160000` | Git submodule (commit ref)   | `Commit`
    ---
    ---@type string
    tree.mode = nil

    --- The type of item that this is.
    ---
    --- One of "blob", "tree", "commit".
    ---
    ---@type string
    tree.type = nil

    --- The SHA1 of the item.
    ---
    ---@type string
    tree.sha = nil

    --- The size of the item in bytes.
    ---
    ---@type number
    tree.size = nil

    --- The URL of the item.
    ---
    ---@type string
    tree.url = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- A GitHub user.
    ---
    ---@class dreamwork.std.http.github.User
    local user = {}

    --- Unique numeric ID of the user on GitHub.
    ---
    ---@type integer
    user.id = nil

    --- GitHub username.
    ---
    ---@type string
    user.login = nil

    --- GitHub user avatar URL.
    ---
    ---@type string
    user.avatar_url = nil

    --- Type of GitHub account: `"User"` for individuals, `"Organization"` for orgs.
    ---
    ---@type string
    user.type = nil

    --- API URL to fetch general user profile data in JSON.
    ---
    ---@type string
    user.url = nil

    --- Not a standard GitHub field in public APIs;
    ---
    --- (likely indicates visibility like `"public"` or `"private"` view).
    ---
    ---@type string
    user.user_view_type = nil

    --- API endpoint to fetch users who follow this user.
    ---
    ---@type string
    user.followers_url = nil

    --- Template URL for users this user is following.
    ---
    --- Replace `{other_user}` with a username to check specific following status.
    ---
    ---@type string
    user.following_url = nil

    --- Template API URL to fetch gists (code snippets) by this user.
    ---
    --- `{gist_id}` is optional to target a specific gist.
    ---
    ---@type string
    user.gists_url = nil

    --- URL to the user’s GitHub profile (viewed in browser).
    ---
    ---@type string
    user.html_url = nil

    --- Internal GitHub GraphQL node ID, base64-encoded.
    ---
    ---@type string
    user.node_id = nil

    --- API URL to fetch organizations this user belongs to.
    ---
    ---@type string
    user.organizations_url = nil

    --- API URL to list GitHub events received by this user (e.g., starred, forked repos).
    ---
    ---@type string
    user.received_events_url = nil

    --- API URL to list this user’s public repositories.
    ---
    ---@type string
    user.repos_url = nil

    --- `true` if the user is a GitHub staff/admin, `false` otherwise.
    ---
    ---@type boolean
    user.site_admin = nil

    --- Template API URL to see repositories starred by this user.
    ---
    --- Replace `{owner}` and `{repo}` with specific values if needed.
    ---
    ---@type string
    user.starred_url = nil

    --- API URL to fetch repos this user is subscribed to (watching for updates).
    ---
    ---@type string
    user.subscriptions_url = nil

    --- [SHARED AND MENU]
    ---
    --- A GitHub user who has contributed to a repository.
    ---
    ---@class dreamwork.std.http.github.Contributor : dreamwork.std.http.github.User
    local contributor = {}

    --- API endpoint to retrieve the public events
    --- performed by the user (such as pushes,
    --- issues opened, pull requests, etc.).
    ---
    --- Format: `https://api.github.com/users/{username}/events`
    ---
    ---@type string
    contributor.events_url = nil

    --- Number of contributions made by this user.
    ---
    ---@type integer
    contributor.contributions = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- A GitHub repository tag commit.
    ---
    ---@class dreamwork.std.http.github.Repository.Tag.Commit
    local commit = {}

    --- The SHA-1 hash of the commit that this tag points to.
    ---
    ---@type string
    commit.sha = nil

    --- API URL to fetch full information about the commit for this tag.
    ---
    ---@type string
    commit.url = nil

    --- [SHARED AND MENU]
    ---
    --- A GitHub repository tag.
    ---
    ---@class dreamwork.std.http.github.Repository.Tag
    local tag = {}

    --- Name of the tag.
    ---
    ---@type string
    tag.name = nil

    --- Commit associated with the tag.
    ---
    ---@type dreamwork.std.http.github.Repository.Tag.Commit
    tag.commit = nil

    --- URL to download the source code at this tag as a ZIP archive.
    ---
    ---@type string
    tag.zipball_url = nil

    --- URL to download the source code at this tag as a TAR.GZ archive.
    ---
    ---@type string
    tag.tarball_url = nil

    --- Internal GraphQL node ID for the tag object (base64 encoded).
    ---
    ---@type string
    tag.node_id = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- The GitHub license.
    ---
    ---@class dreamwork.std.http.github.License
    local license = {}

    --- Full human-readable name of the license (e.g., "MIT License").
    ---
    ---@type string
    license.name = nil

    --- A short machine-readable license identifier (e.g., "mit" for MIT License, "gpl-3.0" for GNU GPL v3).
    ---
    ---@type string
    license.key = nil

    --- API URL to fetch full license information from GitHub's API (can contain license text, permissions, conditions, etc.).
    ---
    ---@type string
    license.url = nil

    --- [SPDX](https://spdx.dev/) identifier for the license (standardized license codes like MIT, GPL-3.0, etc.).
    ---
    ---@type string
    license.spdx_id = nil

    --- GitHub's internal GraphQL node ID for the license, base64 encoded.
    ---
    ---@type string
    license.node_id = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- The GitHub repository.
    ---
    ---@class dreamwork.std.http.github.Repository
    local repository = {}

    --- Unique numeric ID of the repository.
    ---
    ---@type integer
    repository.id = nil

    --- The name of the repository.
    ---
    ---@type string
    repository.name = nil

    --- The description of the repository.
    ---
    ---@type string
    repository.description = nil

    --- Information about the repository owner.
    ---
    ---@type dreamwork.std.http.github.User
    repository.owner = nil

    --- Repository visibility level (public, private, internal).
    ---
    ---@type string
    repository.visibility = nil

    --- The full name of the repository, e.g. "Pika-Software/dreamwork".
    ---
    ---@type string
    repository.full_name = nil

    --- Size of the repository in kilobytes (KB).
    ---
    ---@type number
    repository.size = nil

    --- Timestamp when the repository was created.
    ---
    ---@type string
    repository.created_at = nil

    --- Timestamp of the last push (commit) to any branch.
    ---
    ---@type string
    repository.pushed_at = nil

    --- Timestamp when the repository was last updated (includes metadata changes, not only code).
    ---
    ---@type string
    repository.updated_at = nil

    --- Whether the repository is disabled (e.g., archived or locked by GitHub).
    ---
    ---@type boolean
    repository.disabled = nil

    --- Whether the repository is private (`true`) or public (`false`).
    ---
    ---@type boolean
    repository.private = nil

    --- The name of the default branch of the repository.
    ---
    ---@type string
    repository.default_branch = nil

    --- Number of forks plus other derivatives of the repository (usually matches `forks_count`).
    ---
    ---@type number
    repository.network_count = nil

    --- Internal GitHub GraphQL node ID, base64 encoded.
    ---
    ---@type string
    repository.node_id = nil

    --- Number of open issues currently in the repository.
    ---
    ---@type integer
    repository.open_issues_count = nil

    --- Whether this repository is a fork of another repository.
    ---
    ---@type boolean
    repository.fork = nil

    --- Number of forks (copies) made by users.
    ---
    ---@type integer
    repository.forks_count = nil

    --- API endpoint for the repository itself.
    ---
    ---@type string
    repository.url = nil

    --- URL to the GitHub repository page (the one you visit in browser).
    ---
    ---@type string
    repository.html_url = nil

    --- Git URL to clone the repository over Git protocol.
    ---
    ---@type string
    repository.git_url = nil

    --- SSH URL for cloning the repository over SSH.
    ---
    ---@type string
    repository.ssh_url = nil

    --- Whether GitHub Discussions feature is enabled.
    ---
    ---@type boolean
    repository.has_discussions = nil

    --- Whether the repository has downloadable releases or binaries.
    ---
    ---@type boolean
    repository.has_downloads = nil

    --- Whether the Issues feature is enabled for the repository.
    ---
    ---@type boolean
    repository.has_issues = nil

    --- Whether GitHub Pages (static site hosting) is enabled for the repository.
    ---
    ---@type boolean
    repository.has_pages = nil

    --- Whether GitHub Projects (kanban/project boards) is enabled.
    ---
    ---@type boolean
    repository.has_projects = nil

    --- Whether the repository has a wiki enabled.
    ---
    ---@type boolean
    repository.has_wiki = nil

    --- Whether the repository is marked as a template (for creating new repositories based on it).
    ---
    ---@type boolean
    repository.is_template = nil

    --- Main programming language detected in the repository.
    ---
    ---@type string
    repository.language = nil

    --- Number of stars (likes) the repository has received.
    ---
    ---@type integer
    repository.stargazers_count = nil

    --- Number of people watching (subscribed to notifications) the repository.
    ---
    ---@type integer
    repository.subscribers_count = nil

    --- Number of watchers (again, often identical to stargazers_count).
    ---
    ---@type integer
    repository.watchers_count = nil

    --- Temporary token for cloning private repos without credentials (usually empty unless needed).
    ---
    ---@type string
    repository.temp_clone_token = nil

    --- List of topics/tags associated with the repo (e.g., ["lua", "cryptography", "gmod"]).
    ---
    ---@type string[]
    repository.topics = nil

    --- Information about the software license attached to the repository.
    ---
    ---@type dreamwork.std.http.github.License
    repository.license = nil

    --- Information about the repository owner.
    ---
    ---@type dreamwork.std.http.github.User
    repository.owner = nil

    --- Whether commits made via the web interface require sign-off (DCO compliance).
    ---
    ---@type boolean
    repository.web_commit_signoff_required = nil

    --- Either `true` to allow private forks, or `false` to prevent private forks.
    ---
    ---@type boolean
    repository.allow_forking = nil

    --- Whether to archive this repository. `false` will unarchive a previously archived repository.
    ---
    ---@type boolean
    repository.archived = nil

    --- A list of permissions for the repository.
    ---
    ---@type table<string, boolean>
    repository.permissions = nil

    --- The archive format for the repository.
    ---
    ---@type string
    repository.archive_url = nil

    --- The assignees format for the repository.
    ---
    ---@type string
    repository.assignees_url = nil

    --- The blobs format for the repository.
    ---
    ---@type string
    repository.blobs_url = nil

    --- The branches format for the repository.
    ---
    ---@type string
    repository.branches_url = nil

    --- The clone format for the repository.
    ---
    ---@type string
    repository.clone_url = nil

    --- The collaborators format for the repository.
    ---
    ---@type string
    repository.collaborators_url = nil

    --- The comments format for the repository.
    ---
    ---@type string
    repository.comments_url = nil

    --- The commits format for the repository.
    ---
    ---@type string
    repository.commits_url = nil

    --- The compare format for the repository.
    ---
    ---@type string
    repository.compare_url = nil

    --- The contents format for the repository.
    ---
    ---@type string
    repository.contents_url = nil

    --- The contributors format for the repository.
    ---
    ---@type string
    repository.contributors_url = nil

    --- The deployments format for the repository.
    ---
    ---@type string
    repository.deployments_url = nil

    --- The downloads format for the repository.
    ---
    ---@type string
    repository.downloads_url = nil

    --- The events format for the repository.
    ---
    ---@type string
    repository.events_url = nil

    --- The forks format for the repository.
    ---
    ---@type string
    repository.forks_url = nil

    --- The git_commits format for the repository.
    ---
    ---@type string
    repository.git_commits_url = nil

    --- The git_refs format for the repository.
    ---
    ---@type string
    repository.git_refs_url = nil

    --- The git_tags format for the repository.
    ---
    ---@type string
    repository.git_tags_url = nil

    --- The hooks format for the repository.
    ---
    ---@type string
    repository.hooks_url = nil

    --- The issue_comment_url format for the repository.
    ---
    ---@type string
    repository.issue_comment_url = nil

    --- The issue_events format for the repository.
    ---
    ---@type string
    repository.issue_events_url = nil

    --- The issues format for the repository.
    ---
    ---@type string
    repository.issues_url = nil

    --- API endpoint template for fetching pull requests. `{number}` can be replaced with a pull request ID.
    ---
    ---@type string
    repository.pulls_url = nil

    --- The keys format for the repository.
    ---
    ---@type string
    repository.keys_url = nil

    --- The labels format for the repository.
    ---
    ---@type string
    repository.labels_url = nil

    --- The languages format for the repository.
    ---
    ---@type string
    repository.languages_url = nil

    --- The merges format for the repository.
    ---
    ---@type string
    repository.merges_url = nil

    --- The milestones format for the repository.
    ---
    ---@type string
    repository.milestones_url = nil

    ---
    ---
    ---@type string
    repository.notifications_url = nil

    --- API endpoint template for accessing release information. `{id}` is the release ID.
    ---
    ---@type string
    repository.releases_url = nil

    --- API endpoint to list all users who have starred the repository.
    ---
    ---@type string
    repository.stargazers_url = nil

    --- API endpoint for commit statuses (e.g., CI checks) per SHA-1. `{sha}` is the commit SHA-1.
    ---
    ---@type string
    repository.statuses_url = nil

    --- API endpoint to list the watchers (subscribers).
    ---
    ---@type string
    repository.subscribers_url = nil

    --- API endpoint to manage or check a user's subscription to the repository.
    ---
    ---@type string
    repository.subscription_url = nil

    --- URL for cloning the repo over Subversion (legacy).
    ---
    ---@type string
    repository.svn_url = nil

    --- API endpoint to list tags (version snapshots) in the repo.
    ---
    ---@type string
    repository.tags_url = nil

    --- API endpoint listing teams with access to the repository (for organizations).
    ---
    ---@type string
    repository.teams_url = nil

    --- API endpoint template to get Git trees (object structure) by SHA.
    ---
    ---@type string
    repository.trees_url = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- A GitHub blob object.
    ---
    ---@class dreamwork.std.http.github.Blob
    local blob = {}

    --- The base64-encoded content of the file.
    ---
    --- You must decode it to get the original file contents.
    ---
    ---@type string
    blob.content = nil

    --- Encoding format used for content.
    ---
    --- Always `"base64"` for blobs.
    ---
    ---@type string
    blob.encoding = nil

    --- API URL to access this blob object.
    ---
    ---@type string
    blob.url = nil

    --- SHA-1 hash of the blob (unique identifier for the file contents).
    ---
    ---@type string
    blob.sha = nil

    --- Size of the content in bytes (here, 19 bytes).
    ---
    ---@type integer
    blob.size = nil

    --- Internal GitHub GraphQL node ID, base64-encoded.
    ---
    ---@type string
    blob.node_id = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- The options for the pbkdf2 function.
    ---
    ---@class dreamwork.std.pbkdf2.Options
    local options = {}

    --- The input password or passphrase to derive a key from.
    ---
    --- Not limited in length, but longer passphrases are usually stronger.
    ---
    ---@type string
    options.password = nil

    --- A unique, random value added to the password before hashing.
    ---
    --- Prevents rainbow table attacks.
    ---
    --- Common size: `16` to `32 bytes.
    ---
    ---@type string
    options.salt = nil

    --- Number of hashing iterations, higher values make brute-force attacks harder.
    ---
    --- Recommended minimums:
    --- * `100,000+` for general applications.
    --- * `300,000+` for secure storage (as of 2024 recommendations).
    ---
    --- Default value: `4096`
    ---
    ---@type integer | nil
    options.iterations = 4096

    --- Desired length of the derived key (in bytes).
    ---
    --- Default value: `16`
    ---
    ---@type integer | nil
    options.length = 16

    --- The hash algorithm class to use for the key derivation.
    ---
    ---@type dreamwork.std.HashClass
    options.hash = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- Source game item.
    ---
    ---@class dreamwork.std.game.Item
    local game = {}

    --- The name of the game.
    ---
    ---@type string
    game.title = nil

    --- The Steam application ID of the game.
    ---
    ---@type integer
    game.appid = nil

    --- The mount folder name of the game.
    ---
    ---@type string
    game.folder = nil

    --- Whether the game is installed or not.
    ---
    ---@type boolean
    game.installed = nil

    --- Whether the game is mounted or not.
    ---
    ---@type boolean
    game.mounted = nil

    --- Whether the game is owned or not.
    ---
    ---@type boolean
    game.owned = nil

end

--- [SHARED AND MENU]
---
--- The Steam Workshop publication content type.
---
---@alias dreamwork.std.steam.workshop.Item.ContentType "addon" | "save" | "dupe" | "demo"

--- [SHARED AND MENU]
---
--- The Steam Workshop publication type.
---
---@alias dreamwork.std.steam.workshop.Item.Type "gamemode" | "map" | "weapon" | "vehicle" | "npc" | "entity" | "tool" | "effects" | "model" | "servercontent"

--- [SHARED AND MENU]
---
--- The Steam Workshop addon tag.
---
---@alias dreamwork.std.steam.workshop.Item.AddonTag "fun" | "roleplay" | "scenic" | "movie" | "realism" | "cartoon" | "water" | "comic" | "build"

--- [SHARED AND MENU]
---
--- The Steam Workshop dupe tag.
---
---@alias dreamwork.std.steam.workshop.Item.DupeTag "buildings" | "machines" | "posed" | "scenes" | "vehicles" | "other"

--- [SHARED AND MENU]
---
--- The Steam Workshop save tag.
---
---@alias dreamwork.std.steam.workshop.Item.SaveTag "buildings" | "courses" | "machines" | "scenes" | "other"

--- [SHARED AND MENU]
---
--- The Steam Workshop tag.
---
---@alias dreamwork.std.steam.workshop.Item.Tag dreamwork.std.steam.workshop.Item.ContentType | dreamwork.std.steam.workshop.Item.Type | dreamwork.std.steam.workshop.Item.AddonTag | dreamwork.std.steam.workshop.Item.DupeTag | dreamwork.std.steam.workshop.Item.SaveTag

--- [SHARED AND MENU]
---
--- The Steam Workshop search type.
---
---@alias dreamwork.std.steam.workshop.Item.SearchType "friendfavorite" | "subscribed" | "friends" | "favorite" | "trending" | "popular" | "latest" | "mine"

do

    --- The params table that was used in `Addon` search functions.
    ---@class dreamwork.std.steam.workshop.Item.SearchParams
    local search_params = {}

    --- The type of items to retrieve.
    ---@type dreamwork.std.steam.workshop.Item.SearchType?
    search_params.type = nil

    --- A table of tags to match.
    ---@type string[]?
    search_params.tags = nil

    --- How much of results to skip from first one.
    ---@type number?
    search_params.offset = 0

    --- How many items to retrieve, up to 50 at a time.
    ---@type number?
    search_params.count = 50

    --- This determines a time period, in range of days from 0 to 365.
    ---@type number?
    search_params.days = 365

    --- If specified, receives items from the workshop created by the owner of SteamID64.
    ---@type string?
    search_params.steamid64 = "0"

    --- If specified, retrieves items from your workshop, and also eliminates the 'steamid64' key.
    ---@type boolean?
    search_params.owned = false

    --- Response time, after which the function will be terminated with an error (default 30)
    ---@type number?
    search_params.timeout = 30

end

--- [SHARED AND MENU]
---
--- The Steam Workshop content descriptor.
---
---@alias dreamwork.std.steam.workshop.Warning "general_mature" | "gore" | "suggestive" | "nudity" | "adult_only"

--- [SHARED AND MENU]
---
--- Visibility of a Steam Workshop item.
---
---@alias dreamwork.std.steam.workshop.Visibility "public" | "friends-only" | "private" | "unlisted" | "developer-only" | "unknown"

do

    --- [SHARED AND MENU]
    ---
    --- The Steam Workshop item details.
    ---
    ---@class dreamwork.std.steam.workshop.ItemInfo
    local item_info = {}

    --- The ID of the item.
    ---
    ---@type string
    item_info.id = nil

    --- The title of the item.
    ---
    ---@type string
    item_info.title = nil

    --- The description of the item.
    ---
    ---@type string
    item_info.description = nil

    --- The visibility of the item.
    ---
    ---@type dreamwork.std.steam.workshop.Visibility
    item_info.visibility = nil

    --- The list of content descriptors for this item.
    ---
    ---@type dreamwork.std.steam.workshop.Warning[] | nil
    item_info.warnings = nil

    --- The tags of the item.
    ---
    ---@type dreamwork.std.steam.workshop.Item.Tag[]
    item_info.tags = nil

    --- If the addon is subscribed, this value represents whether it is installed on the client and its files are accessible, `false` otherwise.
    ---
    ---@type boolean
    item_info.installed = nil

    --- If the addon is subscribed, this value represents whether it is disabled on the client, `false` otherwise.
    ---
    ---@type boolean
    item_info.disabled = nil

    --- Whether the item is banned or not.
    ---
    ---@type boolean
    item_info.banned = nil

    --- The `steam.Identifier of the original uploader of the addon.
    ---
    ---@type dreamwork.std.steam.Identifier
    item_info.owner_id = nil

    --- The internal file ID of the item.
    ---
    ---@type integer
    item_info.file_id = nil

    --- The file size of the item in bytes.
    ---
    ---@type integer
    item_info.file_size = nil

    --- The internal preview ID of the item.
    ---
    ---@type integer
    item_info.preview_id = nil

    --- The URL to the preview image.
    ---
    ---@type string
    item_info.preview_url = nil

    --- The size of the preview image in bytes.
    ---
    ---@type integer
    item_info.preview_size = nil

    --- Unix timestamp of when the item was created
    ---@type integer
    item_info.created_at = nil

    --- Unix timestamp of when the file was last updated
    ---@type integer
    item_info.updated_at = nil

    --- A list of child Workshop Items for this item.
    ---
    --- For collections this will be sub-collections, for workshop items this will be the items they depend on.
    ---
    ---@type string[]
    item_info.children = nil

    --- If this key is set, no other data will be present in the response.
    ---
    --- Values above 0 represent Steam Error codes, values below 0 mean the following:
    --- * -1 means Failed to create query
    --- * -2 means Failed to send query
    --- * -3 means Received 0 or more than 1 result
    --- * -4 means Failed to get item data from the response
    --- * -5 means Workshop item ID in the response is invalid
    --- * -6 means Workshop item ID in response is mismatching the requested file ID
    ---@type integer
    item_info.error = nil

    --- Number of "up" votes for this item.
    ---@type number
    item_info.votes_up = nil

    --- Number of "down" votes for this item.
    ---@type number
    item_info.votes_down = nil

    --- Number of total votes (up and down) for this item. This is NOT `up - down`.
    ---@type number
    item_info.votes_total = nil

    --- The up down vote ratio for this item, i.e. `1` is when every vote is `up`, `0.5` is when half of the total votes are the up votes, etc.
    ---@type number
    item_info.votes_score = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- A Steam API response.
    ---
    ---@class dreamwork.std.steam.workshop.Response
    local response = {}

    --- The reason why the request failed.
    ---
    --- Will be `nil` if `success` is `true`.
    ---
    ---@type string | nil
    response.reason = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- Details of a Steam Workshop item.
    ---
    ---@class dreamwork.std.steam.workshop.Item.Details : dreamwork.std.steam.workshop.Response
    local details = {}

    --- The ID of the item in the Steam Workshop.
    ---
    ---@type string
    details.id = nil

    --- The title of the item.
    ---
    ---@type string
    details.title = nil

    --- The description of the item.
    ---
    ---@type string
    details.description = nil

    --- The URL to the preview image of the item.
    ---
    ---@type string
    details.preview_url = nil

    --- The visibility of the item.
    ---
    ---@type dreamwork.std.steam.workshop.Visibility
    details.visibility = nil

    --- The tags of the item.
    ---
    ---@type dreamwork.std.steam.workshop.Item.Tag[]
    details.tags = nil

    --- Whether the item is banned or not.
    ---
    ---@type boolean
    details.banned = nil

    --- The reason why the item is banned.
    ---
    --- `nil` if the item is not banned.
    ---
    ---@type string | nil
    details.ban_reason = nil

    --- The number of times the item has been favorited.
    ---
    ---@type integer
    details.favorited = nil

    --- The number of times the item has been subscribed to.
    ---
    ---@type integer
    details.subscriptions = nil

    --- The number of times the item has been viewed.
    ---
    ---@type integer
    details.views = nil

    --- The `steam.Identifier of the original uploader of the addon.
    ---
    ---@type dreamwork.std.steam.Identifier
    details.owner_id = nil

    --- The time, in unix format, when the item was created.
    ---
    ---@type number
    details.created_at = nil

    --- The time, in unix format, when the item was last updated.
    ---
    ---@type number
    details.updated_at = nil

    --- The internal name of the uploaded file.
    ---
    ---@type string
    details.file_name = nil

    --- The file size of the item in bytes.
    ---
    ---@type integer
    details.file_size = nil

    --- The URL to the file of the item.
    ---
    --- Mostly empty string.
    ---
    ---@type string
    details.file_url = nil

    --- The app id of the game using the item (usually same as creator_app_id).
    ---
    ---@type integer
    details.consumer_app_id = nil

    --- The app id of the tool used to upload it (e.g., GMod = 4000).
    ---
    ---@type integer
    details.creator_app_id = nil

    --- The content handle ID (internal Steam CDN ref).
    ---
    ---@type string
    details.hcontent_file = nil

    --- The content handle ID for the preview image.
    ---
    ---@type string
    details.hcontent_preview = nil

end

--- [SHARED AND MENU]
---
--- The type of a Steam Workshop item.
---
--- Ref: https://partner.steamgames.com/doc/api/ISteamRemoteStorage#EWorkshopFileType
---@alias dreamwork.std.steam.EWorkshopFileType "item" | "microtransaction" | "collection" | "artwork" | "video" | "screenshot" | "game" | "software" | "concept" | "web_guide" | "integrated_guide" | "merch" | "controller_binding" | "steamworks_access_invite" | "steam_video" | "game_managed_item"

do

    --- [SHARED AND MENU]
    ---
    --- Details of a Steam Workshop collection item.
    ---
    ---@class dreamwork.std.steam.workshop.Collection.Details.Item
    local item = {}

    --- The ID of the item in the Steam Workshop.
    ---
    ---@type string
    item.id = nil

    --- The type of the item.
    ---
    ---@type dreamwork.std.steam.EWorkshopFileType
    item.type = nil

    --- The order of the item in the collection.
    ---
    ---@type integer
    item.order = nil

end

do

    --- [SHARED AND MENU]
    ---
    --- Details of a Steam Workshop collection.
    ---
    ---@class dreamwork.std.steam.workshop.Collection.Details : dreamwork.std.steam.workshop.Response
    local details = {}

    --- The ID of the collection in the Steam Workshop.
    ---
    ---@type string
    details.id = nil

    --- The list of items in the collection or `nil` if request failed.
    ---
    --- The items are sorted in the order they are in the collection.
    ---
    ---@type dreamwork.std.steam.workshop.Collection.Details.Item[] | nil
    details.items = nil

end

---@alias dreamwork.std.Material.Shader.name string
---| "accumbuff5sample"
---| "Aftershock_dx9"
---| "Bik"
---| "Bik_dx80"
---| "Bik_dx81"
---| "Bloom"
---| "BlurFilterX"
---| "BlurFilterX_DX80"
---| "BlurFilterY"
---| "BlurFilterY_DX80"
---| "BufferClearObeyStencil_DX8"
---| "BufferClearObeyStencil_DX9"
---| "Cable_DX8"
---| "Cable_DX9"
---| "Cloak_DX90"
---| "ColorCorrection"
---| "Core_DX80"
---| "Core_DX90"
---| "DebugDrawEnvmapMask"
---| "DebugMorphAccumulator"
---| "DebugMRTTexture"
---| "DebugNormalMap"
---| "DebugTextureView_dx9"
---| "DecalBaseTimesLightmapAlphaBlendSelfIllum_DX8"
---| "DecalBaseTimesLightmapAlphaBlendSelfIllum_DX9"
---| "DecalModulate_dx9"
---| "DepthWrite" Used for writting depth buffer — render.GetResolvedFullFrameDepth.
---| "Downsample"
---| "Downsample_nohdr"
---| "Downsample_nohdr_DX80"
---| "Engine_Post_dx9"
---| "EyeGlint_dx9"
---| "EyeRefract_dx9"
---| "Eyes_dx6"
---| "Eyes_dx8"
---| "Eyes_dx9"
---| "Fillrate"
---| "floatcombine"
---| "floatcombine_autoexpose"
---| "floattoscreen"
---| "floattoscreen_vanilla"
---| "GooInGlass"
---| "HDRCombineTo16Bit"
---| "HDRSelectRange"
---| "hsl_filmgrain_pass1"
---| "hsl_filmgrain_pass2"
---| "HSV"
---| "IntroScreenSpaceEffect"
---| "IntroScreenSpaceEffect_dx80"
---| "LightmappedGeneric" The shader used for world brushes.
---| "LightmappedGeneric_Decal"
---| "LightmappedGeneric_DX8"
---| "LightmappedReflective" Used for reflective surfaces such as wet floor.
---| "LightmappedReflective_DX90"
---| "Modulate"
---| "Modulate_DX8"
---| "Modulate_DX9"
---| "MorphAccumulate_DX9"
---| "MorphWeight_DX9"
---| "MotionBlur_dx9"
---| "Occlusion_DX8"
---| "Occlusion_DX9"
---| "Overlay_Fit"
---| "Portal_DX60"
---| "Portal_DX80"
---| "Portal_DX90"
---| "PortalRefract_dx8"
---| "PortalRefract_dx9"
---| "PortalStaticOverlay"
---| "PortalStaticOverlay"
---| "PortalStaticOverlay_DX60"
---| "Predator_DX80"
---| "Refract"
---| "Refract_DX80"
---| "Refract_DX90"
---| "Sample4x4"
---| "Sample4x4_Blend"
---| "screenspace_general" Wrapper for providing custom pixel (and in some games vector) shaders.
---| "screenspace_general_dx8"
---| "screenspace_general_dx9"
---| "sfm_blurfilterx_shader"
---| "sfm_blurfiltery_shader"
---| "sfm_downsample_shader"
---| "sfm_integercombine_shader"
---| "Shadow"
---| "Shadow_DX8"
---| "ShadowBuild_DX8"
---| "ShadowBuild_DX9"
---| "ShadowModel_DX8"
---| "ShadowModel_DX9"
---| "ShatteredGlass"
---| "ShatteredGlass_DX8"
---| "showz" Depth buffer debugger.
---| "Sky_DX9"
---| "Sky_HDR_DX9"
---| "Sprite_DX8"
---| "Sprite_DX9"
---| "Spritecard"
---| "Spritecard_DX8"
---| "Teeth_DX6"
---| "Teeth_DX8"
---| "Teeth_DX9"
---| "TreeLeaf"
---| "UnlitGeneric" The shader used for GUI materials.
---| "UnlitGeneric_DX8"
---| "UnlitTwoTexture_DX8"
---| "UnlitTwoTexture_DX9"
---| "VertexLitGeneric" The shader used for models.
---| "VertexLitGeneric_DX8"
---| "VolumeClouds_dx9"
---| "VortWarp_dx8"
---| "VortWarp_DX9"
---| "Water_DX81"
---| "Water_DX90"
---| "WindowImposter_DX80"
---| "WindowImposter_DX90"
---| "Wireframe_DX8"
---| "Wireframe_DX9"
---| "WorldTwoTextureBlend"
---| "WorldTwoTextureBlend_DX8"
---| "WorldVertexAlpha_DX8"
---| "WorldVertexTransition_DX8"
---| "WorldVertexTransition_DX9"
---| "WriteStencil_DX8"
---| "WriteStencil_DX9"
---| "WriteZ_DX8"
---| "WriteZ_DX9"
---| "YUV"

--- [SHARED AND MENU]
---
--- https://developer.valvesoftware.com/wiki/Category:Shader_parameters
---
---@class dreamwork.std.Material.Shader.parameters
local shader_parameters = {}

---@type string | nil
shader_parameters[ "$basetexture" ] = nil

---@type string | nil
shader_parameters[ "$basetexture2" ] = nil

---@type VMatrix | nil
shader_parameters[ "$basetexturetransform" ] = nil

---@type VMatrix | nil
shader_parameters[ "$basetexturetransform2" ] = nil

---@type integer | nil
shader_parameters[ "$frame" ] = nil

---@type integer | nil
shader_parameters[ "$frame2" ] = nil

---@type string | nil
shader_parameters[ "$surfaceprop" ] = nil

-- TODO: https://developer.valvesoftware.com/wiki/Category:Shader_parameters ->>

shader_parameters[ "$decal" ] = nil
shader_parameters[ "$decalscale" ] = nil
shader_parameters[ "$modelmaterial" ] = nil
shader_parameters[ "$decalfadeduration" ] = nil
shader_parameters[ "$decalfadetime" ] = nil
shader_parameters[ "$decalsecondpass" ] = nil
shader_parameters[ "$fogscale" ] = nil
shader_parameters[ "$splatter" ] = nil
shader_parameters[ "$detail" ] = nil
shader_parameters[ "$detailtexturetransform" ] = nil
shader_parameters[ "$detailscale" ] = nil
shader_parameters[ "$detailblendfactor" ] = nil
shader_parameters[ "$detailblendmode" ] = nil
shader_parameters[ "$detailtint" ] = nil
shader_parameters[ "$detailframe" ] = nil
shader_parameters[ "$detail_alpha_mask_base_texture" ] = nil
shader_parameters[ "$detail2" ] = nil
shader_parameters[ "$detailscale2" ] = nil
shader_parameters[ "$detailblendfactor2" ] = nil
shader_parameters[ "$detailframe2" ] = nil
shader_parameters[ "$detailtint2" ] = nil

---@type boolean | nil
shader_parameters[ "$model" ] = nil

---@class dreamwork.std.Material.Shader
---@field name dreamwork.std.Material.Shader.name | nil
---@field parameters dreamwork.std.Material.Shader.parameters | nil

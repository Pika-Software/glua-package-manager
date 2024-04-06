-- net/url.lua - a robust url parser and builder
-- Bertrand Mansion, 2011-2021; License MIT
-- https://github.com/golgote/neturl

local string = string
local sub = string.sub
local find = string.find
local gsub = string.gsub
local match = string.match
local lower = string.lower
local format = string.format

local concat = table.concat

local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local isstring = isstring
local istable = istable
local ipairs = ipairs
local pairs = pairs

local META = {
	version = "1.2.0"
}

--- url options
-- - `separator` is set to `&` by default but could be anything like `&amp;amp;` or `;`
-- - `cumulative_parameters` is false by default. If true, query parameters with the same name will be stored in a table.
-- - `legal_in_path` is a table of characters that will not be url encoded in path components
-- - `legal_in_query` is a table of characters that will not be url encoded in query values. Query parameters only support a small set of legal characters (-_.).
-- - `query_plus_is_space` is true by default, so a plus sign in a query value will be converted to %20 (space), not %2B (plus)
-- @todo Add option to limit the size of the argument table
-- @todo Add option to limit the depth of the argument table
-- @todo Add option to process dots in parameter names, ie. `param.filter=1`
local options = {
	separator = "&",
	cumulative_parameters = false,
	legal_in_path = {
		[":"] = true, ["-"] = true, ["_"] = true, ["."] = true,
		["!"] = true, ["~"] = true, ["*"] = true, ["'"] = true,
		["("] = true, [")"] = true, ["@"] = true, ["&"] = true,
		["="] = true, ["$"] = true, [","] = true,
		[";"] = true
	},
	legal_in_query = {
		[":"] = true, ["-"] = true, ["_"] = true, ["."] = true,
		[","] = true, ["!"] = true, ["~"] = true, ["*"] = true,
		["'"] = true, [";"] = true, ["("] = true, [")"] = true,
		["@"] = true, ["$"] = true,
	},
	query_plus_is_space = true
}

META.options = options

--- list of known and common scheme ports
-- as documented in <a href="http://www.iana.org/assignments/uri-schemes.html">IANA URI scheme list</a>
local services = {
	ftp = 21,
	ssh = 22,
	sftp = 22,
	telnet = 23,
	smtp = 25,
	tftp = 69,
	gopher = 70,
	http = 80,
	nntp = 119,
	snmp = 161,
	imap = 143,
	prospero = 191,
	ldap = 389,
	https = 443,
	smtps = 465,
	videotex = 516,
	rtsp = 554,
	vemmi = 575,
	starttls = 587,
	ipp = 631,
	acap = 674,
	rsync = 873,
	cap = 1026,
	mtqp = 1038,
	icap = 1344,
	afs = 1483,
	news = 2009,
	nfs = 2049,
	dict = 2628,
	mupdate = 3905,
	iax = 4569,
	sip = 5060,
	jms = 5673
}

META.services = services

local decode
do

	local char = string.char

	function decode( str )
		return gsub( str, "%%(%x%x)", function( value )
			return char( tonumber( value, 16 ) )
		end )
	end

end

local encode
do

	local upper = string.upper
	local byte = string.byte

	function encode( str, legal )
		return gsub( str, "([^%w])", function( value )
			if legal[ value ] then
				return value
			end

			return upper( format( "%%%02x", byte( value ) ) )
		end )
	end

end

-- for query values, + can mean space if configured as such
local function decodeValue( str )
	if options.query_plus_is_space then
		str = gsub( str, "+", " " )
	end

	return decode( str )
end

function META:addSegment( path )
	if isstring( path ) then
		self.path = self.path .. "/" .. encode( gsub( path, "^/+", "" ), options.legal_in_path )
	end

	return self
end

--- builds the url
-- @return a string representing the built url
function META:build()
	local url = ""
	if self.path then
		local path = self.path
		url = url .. tostring( path )
	end

	if self.query then
		local qstring = tostring( self.query )
		if #qstring ~= 0 then
			url = url .. "?" .. qstring
		end
	end

	if self.host then
		local authority = self.host
		if self.port and self.scheme and services[ self.scheme ] ~= self.port then
			authority = authority .. ":" .. self.port
		end

		local userinfo
		if self.user and #self.user ~= 0 then
			userinfo = self.user
			if self.password then
				userinfo = userinfo .. ":" .. self.password
			end
		end

		if userinfo and #userinfo ~= 0 then
			authority = userinfo .. "@" .. authority
		end

		if authority then
			url = "//" .. ( ( #url == 0 ) and authority or ( authority .. "/" .. gsub( url, "^/+", "" ) ) )
		end
	end

	if self.scheme then
		url = self.scheme .. ":" .. url
	end

	if self.fragment then
		url = url .. "#" .. self.fragment
	end

	return url
end

--- builds the querystring
-- @param tab The key/value parameters
-- @param sep The separator to use (optional)
-- @param key The parent key if the value is multi-dimensional (optional)
-- @return a string representing the built querystring
local buildQuery
do

	local sort = table.sort

	local function padnum( number, rest )
		return format( "%03d" .. rest, tonumber( number ) )
	end

	local function sortFunc( a, b )
		return gsub( tostring( a ), "(%d+)(%.)", padnum ) < gsub( tostring( b ), "(%d+)(%.)", padnum )
	end

	function buildQuery( tab, sep, key )
		local query, queryLength = {}, 0
		if not sep then
			sep = options.separator or "&"
		end

		local keys, keysLength = {}, 0
		for value in pairs( tab ) do
			keysLength = keysLength + 1
			keys[ keysLength ] = value
		end

		sort( keys, sortFunc )

		for index = 1, keysLength do
			local name = keys[ index ]
			local value = tab[ name ]

			name = encode( tostring( name ), {
				["-"] = true,
				["_"] = true,
				["."] = true
			} )

			if key then
				if options.cumulative_parameters and find( name, "^%d+$" ) then
					name = tostring( key )
				else
					name = format( "%s[%s]", tostring( key ), tostring( name ) )
				end
			end

			queryLength = queryLength + 1

			if istable( value ) then
				query[ queryLength ] = buildQuery( value, sep, name )
			else
				value = encode( tostring( value ), options.legal_in_query )
				if #value == 0 then
					query[ queryLength ] = name
				else
					query[ queryLength ] = format( "%s=%s", name, value )
				end
			end
		end

		return concat( query, sep )
	end

	META.buildQuery = buildQuery

end

--- Parses the querystring to a table
-- This function can parse multidimensional pairs and is mostly compatible
-- with PHP usage of brackets in key names like ?param[key]=value
-- @param str The querystring to parse
-- @param sep The separator between key/value pairs, defaults to `&`
-- @todo limit the max number of parameters with options.max_parameters
-- @return a table representing the query key/value pairs
local parseQuery
do

	local gmatch = string.gmatch

	function parseQuery( query, sep )
		if not sep then
			sep = options.separator or "&"
		end

		local values = {}
		for key, srt in gmatch( query, format( "([^%q=]+)(=*[^%q=]*)", sep, sep ) ) do
			local keys, keysLength = {}, 0
			key = gsub( decodeValue( key ), "%[([^%]]*)%]", function( value )
				-- extract keys between balanced brackets
				if find( value, "^-?%d+$" ) then
					value = tonumber( value )
				else
					value = decodeValue( value )
				end

				keysLength = keysLength + 1
				keys[ keysLength ] = value
				return "="
			end )

			key = gsub( key, "=+.*$", "" )
			key = gsub( key, "%s", "_" ) -- remove spaces in parameter name

			srt = gsub( key, "^=+", "" )

			if not values[key] then
				values[key] = {}
			end
			if keysLength > 0 and not istable( values[ key ] ) then
				values[ key ] = {}
			elseif keysLength == 0 and istable( values[ key ] ) then
				values[ key ] = decodeValue( srt )
			elseif options.cumulative_parameters and isstring( values[ key ] ) then
				if values[ key ] then
					values[ key ] = { values[ key ], decodeValue( srt ) }
				else
					values[ key ] = { decodeValue( srt ) }
				end
			end

			local t = values[ key ]
			for i, k in ipairs( keys ) do
				if not istable( t ) then
					t = {}
				end

				if #k == 0 then
					k = #t + 1
				end

				if not t[ k ] then
					t[ k ] = {}
				end

				if i == #keys then
					t[ k ] = srt
				end

				t = t[ k ]
			end
		end

		setmetatable( values, { __tostring = buildQuery } )
		return values
	end

	META.parseQuery = parseQuery

end

--- set the url query
-- @param query Can be a string to parse or a table of key/value pairs
-- @return a table representing the query key/value pairs
function META:setQuery( query )
	if istable( query ) then
		query = buildQuery( query )
	end

	self.query = parseQuery( query )
	return query
end

--- set the authority part of the url
-- The authority is parsed to find the user, password, port and host if available.
-- @param authority The string representing the authority
-- @return a string with what remains after the authority was parsed
do

	local rep = string.rep

	local function getIP( str )
		-- ipv4
		local chunks = { match( str, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$" ) }
		if #chunks == 4 then
			for index = 1, 4 do
				if tonumber( chunks[ index ] ) > 255 then
					return false
				end
			end

			return str
		end

		-- ipv6
		chunks = { match( str, "^%[" .. gsub( rep( "([a-fA-F0-9]*):", 8 ), ":$","%%]$" ) ) }
		if #chunks == 8 or #chunks < 8 and match( str, "::" ) and not match( gsub( str, "::", "", 1 ), "::" ) then
			for index = 1, #chunks do
				local chunk = chunks[ index ]
				if #chunk > 0 and tonumber( chunk, 16 ) > 65535 then
					return false
				end
			end

			return str
		end
	end

	function META:setAuthority( authority )
		self.authority = authority
		self.port = nil
		self.host = nil
		self.userinfo = nil
		self.user = nil
		self.password = nil

		authority = gsub( authority, "^([^@]*)@", function( value )
			self.userinfo = value
			return ""
		end )

		authority = gsub( authority, ":(%d+)$", function( value )
			self.port = tonumber( value )
			return ""
		end )

		local ip = getIP( authority )
		if ip then
			self.host = ip
		elseif ip == nil then
			-- domain
			if #authority ~= 0 and not self.host then
				local host = lower( authority )
				if match( host, "^[%d%a%-%.]+$") ~= nil and sub( host, 0, 1) ~= "." and sub( host, -1) ~= "." and find( host, "%.%.") == nil then
					self.host = host
				end
			end
		end

		if self.userinfo then
			local userinfo = self.userinfo
			userinfo = gsub( userinfo, ":([^:]*)$", function( value )
				self.password = value
				return ""
			end )

			if find( userinfo, "^[%w%+%.]+$" ) then
				self.user = userinfo
			else
				-- incorrect userinfo
				self.userinfo = nil
				self.user = nil
				self.password = nil
			end
		end

		return authority
	end

end

--- Parse the url into the designated parts.
-- Depending on the url, the following parts can be available:
-- scheme, userinfo, user, password, authority, host, port, path,
-- query, fragment
-- @param url Url string
-- @return a table with the different parts and a few other functions

do

	local function concatFunc( a, b )
		if istable( a ) then
			return a:build() .. b
		end

		return a .. b:build()
	end

	function META.parse( url )
		local comp = {}
		META.setAuthority( comp, "" )
		META.setQuery( comp, "" )

		url = tostring( url or "" )
		url = gsub( url, "#(.*)$", function( value )
			comp.fragment = value
			return ""
		end)

		url = gsub( url, "^([%w][%w%+%-%.]*)%:", function( value )
			comp.scheme = lower( value )
			return ""
		end )

		url = gsub( url, "%?(.*)", function( value )
			META.setQuery( comp, value )
			return ""
		end)

		url = gsub( url, "^//([^/]*)", function( value )
			META.setAuthority( comp, value )
			return ""
		end )

		comp.path = gsub( url, "([^/]+)", function( value )
			return encode( decode( value ), options.legal_in_path )
		end )

		setmetatable( comp, {
			__index = META,
			__tostring = META.build,
			__concat = concatFunc,
			__div = META.addSegment
		} )

		return comp
	end

end

--- removes dots and slashes in urls when possible
-- This function will also remove multiple slashes
-- @param path The string representing the path to clean
-- @return a string of the path without unnecessary dots and segments
function META.removeDotSegments( path )
	if #path == 0 then
		return path
	end

	local startSlash = false
	local endSlash = false

	if sub( path, 1, 1 ) == "/" then
		startSlash = true
	end

	if ( #path > 1 or startSlash == false ) and sub( path, -1 ) == "/" then
		endSlash = true
	end

	local fields, fieldsLength = {}, 0

	gsub( path, "[^/]+", function( value )
		if value ~= "." then
			fieldsLength = fieldsLength + 1
			fields[ fieldsLength ] = value
		end
	end )

	local result, resultLength = {}, 0

	for index = 1, fieldsLength do
		local value = fields[ index ]
		if value == ".." then
			if resultLength > 0 then
				resultLength = resultLength - 1
			end
		else
			resultLength = resultLength + 1
			result[ resultLength ] = value
		end
	end

	local ret
	if resultLength > 0 then
		ret = concat( result, "/", 1, resultLength )
	else
		ret = ""
	end

	if startSlash then
		ret = "/" .. ret
	end

	if endSlash then
		ret = ret .. "/"
	end

	return ret
end

local function reducePath( base_path, relative_path )
	if sub( relative_path, 1, 1 ) == "/" then
		return "/" .. gsub( relative_path, "^[%./]+", "" )
	end

	local path = base_path
	local startSlash = sub( path, 1, 1 ) ~= "/"
	if #relative_path ~= 0 then
		path = ( startSlash and "" or "/" ) .. gsub( path, "[^/]*$", "" )
	end

	path = path .. relative_path
	path = gsub( path, "([^/]*%./)", function( value )
		if value == "./" then
			return ""
		end

		return value
	end )

	path = gsub( path, "/%.$", "/" )
	local reduced = nil

	while reduced ~= path do
		reduced = path

		path = gsub( reduced, "([^/]*/%.%./)", function( value )
			if value ~= "../../" then
				return ""
			end

			return value
		end )
	end

	path = gsub( path, "([^/]*/%.%.?)$", function( value )
		if value ~= "../.." then
			return ""
		end

		return value
	end )

	reduced = nil
	while reduced ~= path do
		reduced = path
		path = gsub( reduced, "^/?%.%./", "" )
	end

	return ( startSlash and "" or "/" ) .. path
end

--- builds a new url by using the one given as parameter and resolving paths
-- @param other A string or a table representing a url
-- @return a new url table

do

	local next = next

	function META:resolve(other)
		if isstring( self ) then
			self = META.parse( self )
		end

		if isstring( other ) then
			other = META.parse( other )
		end

		if other.scheme then
			return other
		end

		other.scheme = self.scheme

		if not other.authority or #other.authority == 0 then
			other:setAuthority( self.authority )

			if not other.path or #other.path == 0 then
				other.path = self.path

				local query = other.query
				if not query or not next( query ) then
					other.query = self.query
				end
			else
				other.path = reducePath( self.path, other.path )
			end
		end

		return other
	end

end

--- normalize a url path following some common normalization rules
-- described on <a href="http://en.wikipedia.org/wiki/URL_normalization">The URL normalization page of Wikipedia</a>
-- @return the normalized path
function META:normalize()
	if isstring( self ) then
		self = META.parse( self )
	end

	if self.path then
		-- normalize multiple slashes
		self.path = gsub( reducePath( self.path, "" ), "//+", "/" )
	end

	return self
end

return META

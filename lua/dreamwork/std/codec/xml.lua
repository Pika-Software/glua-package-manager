---@class dreamwork.std
local std = dreamwork.std

local isString = std.isString
local isTable = std.isTable

local tostring = std.tostring
local pairs = std.pairs

local raw = std.raw
local raw_next = raw.next
local raw_pairs = raw.pairs
local raw_tonumber = raw.tonumber

local class = std.class

local debug = std.debug
local debug_fempty = debug.fempty
local debug_getmetatable = debug.getmetatable

local table = std.table
local table_concat = table.concat

local string = std.string
local string_byteRep = string.byteRep
local string_sub, string_len = string.sub, string.len
local string_char, string_byte = string.char, string.byte
local string_gsub, string_match = string.gsub, string.match
local string_find, string_format = string.find, string.format
local string_trim, string_isEmpty = string.trim, string.isEmpty

--- [SHARED AND MENU]
---
--- A XML node object, representing a node in an XML document.
---
--- Can be converted to string using `:toString()` or `tostring()`.
---
--- Usage:
---
--- ```lua
--- local root = XMLNode.fromString( [[
--- <root>
---     <child>
---         <title>Test Title</title>
---     </child>
--- </root>
--- ]] )
---
--- print( root:toString( false ) ) -- <root><child><title>Test Title</title></child></root>
--- ```
---
---@class dreamwork.std.XMLNode : dreamwork.std.Object
---@field __class dreamwork.std.XMLNodeClass
---@field name string The name of the node.
---@field attributes nil | table<string, (string | nil)> The attributes of the node.
---@field parent dreamwork.std.XMLNode | nil The parent node.
---@field data nil | string | table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])> The data of the node.
local XMLNode = class.base( "XMLNode", false )

---@alias dreamwork.std.XMLNode.Value string | dreamwork.std.XMLNode

--- [SHARED AND MENU]
---
--- A XML node class, allowing parsing and creation of XML nodes.
---
--- Usage:
---
--- ```lua
--- local root = XMLNode.fromString( [[
--- <root>
---     <child>
---         <title>Test Title</title>
---     </child>
---     <child>
---         <title>Test Title 2</title>
---     </child>
---     <child>
---         <title>Test Title 3</title>
---     </child>
--- </root>
--- ]] )
---
--- print( root:get( "child[2].title" ) ) -- Test Title 2
--- ```
---
---@class dreamwork.std.XMLNodeClass : dreamwork.std.XMLNode
---@field __base dreamwork.std.XMLNode
---@overload fun(name: string, attributes: (table<string, string> | nil), parent: (dreamwork.std.XMLNode | nil) ): dreamwork.std.XMLNode
local XMLNodeClass = class.create( XMLNode )
std.XMLNode = XMLNodeClass

--- [SHARED AND MENU]
---
--- Checks whether the value type is a `XMLNode`.
---
---@param value any
---@return boolean is_xml_node
local function isNode( value )
    return debug_getmetatable( value ) == XMLNode
end

std.isXMLNode = isNode

---@param name string
---@param attributes table<string, string> | nil
---@param parent dreamwork.std.XMLNode | nil
---@protected
function XMLNode:__init( name, attributes, parent )
    self.name = name
    self.parent = parent
    self.attributes = attributes

    if parent == nil then return end

    local parent_data = parent.data
    if parent_data == nil then
        parent.data = {
            [ name ] = self -- create new data with self if parent has no data
        }

        return
    end

    if isString( parent_data ) then
        ---@cast parent_data string

        parent.data = {
            [ name ] = self,
            [ 1 ] = parent_data -- replace string data with map that contains string and self
        }

        return
    end

    ---@cast parent_data table<string, (dreamwork.std.XMLNode.Value | dreamwork.std.XMLNode.Value[])>

    local value = parent_data[ name ]
    if value == nil then
        parent_data[ name ] = self -- put self if no value in map
        return
    end

    if isString( value ) or isNode( value ) then
        ---@cast value string | dreamwork.std.XMLNode
        parent_data[ name ] = { value, self } -- only way is replace string value with `dreamwork.std.XMLNode.Value[]`
        return
    end

    ---@cast value table<string, dreamwork.std.XMLNode.Value[]>

    value[ #value + 1 ] = self -- append self to existing array
end

--- [SHARED AND MENU]
---
--- Checks whether the node is empty.
---
---@return boolean is_empty
function XMLNode:isEmpty()
    return self.data == nil
end

--- [SHARED AND MENU]
---
--- Returns the value of the attribute with the given name or `nil` if not found.
---
---@param name string The name of the attribute to get.
---@return nil | string value The value of the attribute or `nil` if not found.
function XMLNode:getAttribute( name )
    local attributes = self.attributes
    if attributes == nil then
        return nil
    end

    return attributes[ name ]
end

--- [SHARED AND MENU]
---
--- Sets the value of the attribute with the given name.
---
---@param name string The name of the attribute to set.
---@param value string | nil The value to set for the attribute, or `nil` to remove the attribute.
function XMLNode:setAttribute( name, value )
    local attributes = self.attributes
    if attributes == nil then
        self.attributes = {
            [ name ] = value
        }

        return
    end

    attributes[ name ] = value
end

--- [SHARED AND MENU]
---
--- Returns the value of the node at the given key or `nil` if not found.
---
---@param key string The key to look up in the node's data, with dot-separated keys for nested values.
---@return nil | string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[] value The value of the node at the given key, or `nil` if not found.
function XMLNode:get( key )
    local node = self

    ::get_loop::

    local data = node.data
    if data == nil then
        return nil
    end

    if isString( data ) then
        ---@cast data string

        if string_isEmpty( key ) then
            return data
        end

        return nil
    end

    ---@cast data table<string, (dreamwork.std.XMLNode.Value | dreamwork.std.XMLNode.Value[])>

    if string_isEmpty( key ) then
        return nil
    end

    local key_start = string_find( key, ".", 1, true )
    if key_start == nil then
        local index_start, index_end, index_str = string_find( key, "%[%s*(%d+)%s*%]$", 1, false )
        if index_start ~= nil then
            key = string_sub( key, 1, index_start - 1 )
        end

        local data_value

        local str_value = data[ key ]
        if str_value == nil then
            local index = string.toNumber( key )
            if index ~= nil then
                data_value = data[ index ]
            end
        else
            data_value = str_value
        end

        if index_str == nil then
            return data_value
        end

        local data_index = string.toNumber( index_str )
        if data_index == nil then
            std.errorf( 2, false, "invalid index '%s' in key '%s[%s]'", index_str, key, index_str )
            return nil
        end

        return data_value[ data_index ]
    end

    local name = string_sub( key, 1, key_start - 1 )

    local index_start, index_end, index_str = string_find( name, "%[%s*(%d+)%s*%]$", 1, false )
    if index_start ~= nil then
        name = string_sub( name, 1, index_start - 1 )
    end

    local data_value

    local str_value = data[ name ]
    if str_value == nil then
        local index = string.toNumber( name )
        if index ~= nil then
            data_value = data[ index ]
        end
    else
        data_value = str_value
    end

    if data_value == nil then
        return nil
    end

    ---@cast data_value dreamwork.std.XMLNode.Value | dreamwork.std.XMLNode.Value[]

    if isNode( data_value ) then
        ---@cast data_value dreamwork.std.XMLNode
        key = string_sub( key, key_start + 1 )
        node = data_value
        goto get_loop
    end

    if isString( data_value ) then
        ---@cast data_value string
        return nil
    end

    ---@cast data_value dreamwork.std.XMLNode.Value[]

    local sub_value = data_value[ string.toNumber( index_str ) ]
    if isNode( sub_value ) then
        ---@cast sub_value dreamwork.std.XMLNode
        key = string_sub( key, key_start + 1 )
        node = sub_value
        goto get_loop
    end

    return nil
end

--- [SHARED AND MENU]
---
--- Sets the value of the node at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to set, with dot-separated keys for nested values.
---@param value dreamwork.std.XMLNode.Value | dreamwork.std.XMLNode.Value[] | nil The value to set, which can be a string or a node, or `nil` to remove the value.
function XMLNode:set( key, value )
    local node = self

    ::set_loop::

    local data = node.data
    if data == nil or isString( data ) then
        data = {}
        node.data = data
    end

    ---@cast data table<string, (dreamwork.std.XMLNode.Value | dreamwork.std.XMLNode.Value[])>

    local key_start = string_find( key, ".", 1, true )
    if key_start == nil then
        if isNode( value ) then
            ---@cast value dreamwork.std.XMLNode
            value.parent = node
        end

        data[ key ] = value
        return
    end

    local name = string_sub( key, 1, key_start - 1 )
    local key_length = string_len( key )

    if (key_length - key_start) == 0 then
        if isNode( value ) then
            ---@cast value dreamwork.std.XMLNode
            value.parent = node
        end

        data[ name ] = value
        return
    end

    key = string_sub( key, key_start + 1 )

    local data_value = data[ name ]
    if isNode( data_value ) then
        ---@cast data_value dreamwork.std.XMLNode
        node = data_value
        goto set_loop
    end

    node = XMLNodeClass( name, nil, self )
    data[ name ] = node
    goto set_loop
end

--- [SHARED AND MENU]
---
--- Checks if the node contains a value at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to check, with dot-separated keys for nested values.
---@return boolean is_contains Whether the node contains a value at the given key.
function XMLNode:contains( key )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:contains( key_name )
        end

        return false
    end

    local data = self.data
    if data == nil or isString( data ) then
        return false
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    return data[ key ] ~= nil
end

--- [SHARED AND MENU]
---
--- Checks if the node contains a list at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to check, with dot-separated keys for nested values.
---@return boolean is_contains Whether the node contains a list at the given key.
function XMLNode:containsList( key )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:containsList( key_name )
        end

        return false
    end

    local data = self.data
    if data == nil or isString( data ) then
        return false
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    local value = data[ key ]
    return not (value == nil or isString( value ) or isNode( value ))
end

--- [SHARED AND MENU]
---
--- Checks if the node contains a string at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to check, with dot-separated keys for nested values.
---@return boolean is_contains Whether the node contains a string at the given key.
function XMLNode:containsString( key )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:containsString( key_name )
        end

        return false
    end

    local data = self.data
    if data == nil or isString( data ) then
        return false
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    return isString( data[ key ] )
end

--- [SHARED AND MENU]
---
--- Checks if the node contains a node at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to check, with dot-separated keys for nested values.
---@return boolean is_contains Whether the node contains a node at the given key.
function XMLNode:containsNode( key )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:containsNode( key_name )
        end

        return false
    end

    local data = self.data
    if data == nil or isString( data ) then
        return false
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    return isNode( data[ key ] )
end

--- [SHARED AND MENU]
---
--- Returns the length of the list at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to get the length of, with dot-separated keys for nested values.
---@return integer length The length of the list at the given key.
function XMLNode:getLength( key )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:getLength( key_name )
        end

        return 0
    end

    local data = self.data
    if data == nil or isString( data ) then
        return 0
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    local value = data[ key ]
    if value == nil or isString( value ) or isNode( value ) then
        return 0
    end

    ---@cast value dreamwork.std.XMLNode.Value[]
    return #value
end

--- [SHARED AND MENU]
---
--- Pushes a value to the list at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to push the value to, with dot-separated keys for nested values.
---@param value string | dreamwork.std.XMLNode The value to push to the list.
function XMLNode:push( key, value )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:push( key_name, value )
        end

        return
    end

    local data = self.data
    if data == nil or isString( data ) then
        data = {}
        self.data = data
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    if isNode( value ) then
        ---@cast value dreamwork.std.XMLNode
        value.parent = self
    end

    local data_value = data[ key ]
    if data_value == nil then
        data[ key ] = value
        return
    end

    if isString( data_value ) or isNode( data_value ) then
        ---@cast data_value string | dreamwork.std.XMLNode
        data[ key ] = { data_value, value }
        return
    end

    ---@cast data_value dreamwork.std.XMLNode.Value[]
    data_value[ #data_value + 1 ] = value
end

--- [SHARED AND MENU]
---
--- Pops a value from the list at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to pop the value from, with dot-separated keys for nested values.
---@return nil | string | dreamwork.std.XMLNode The popped value, or `nil` if the key does not exist or the value is not a node.
function XMLNode:pop( key )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:pop( key_name )
        end

        return nil
    end

    local data = self.data
    if data == nil or isString( data ) then
        return nil
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    local data_value = data[ key ]
    if data_value == nil then
        return nil
    end

    if isString( data_value ) or isNode( data_value ) then
        ---@cast data_value string | dreamwork.std.XMLNode
        data[ key ] = nil
        return data_value
    end

    ---@cast data_value dreamwork.std.XMLNode.Value[]

    local data_length = #data_value

    local value = data_value[ data_length ]
    data_value[ data_length ] = nil

    return value
end

--- [SHARED AND MENU]
---
--- Removes the value at the given key, supporting dot-separated keys for nested values.
---
---@param key string The key to remove, with dot-separated keys for nested values.
---@return boolean success Returns `true` if the value was removed, `false` otherwise (e.g. key not found).
function XMLNode:remove( key )
    local key_path, key_name = string_match( key, "^(.+)%.([^.]+)$" )
    if key_path ~= nil and key_name ~= nil then
        local node = self:get( key_path )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:remove( key_name )
        end

        return false
    end

    local data = self.data
    if data == nil or isString( data ) then
        return false
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    local data_value = data[ key ]
    if data_value == nil then
        return false
    end

    data[ key ] = nil
    return true
end

--- [SHARED AND MENU]
---
--- Returns an iterator function for the node at the given key, supporting dot-separated keys for nested values.
---
---@param key? string The key to iterate over, with dot-separated keys for nested values.
---@return fun(): string, (string | dreamwork.std.XMLNode) fn The iterator function, which returns key-value pairs for the node at the given key.
function XMLNode:iterator( key )
    if key ~= nil then
        local node = self:get( key )
        if isNode( node ) then
            ---@cast node dreamwork.std.XMLNode
            return node:iterator()
        end

        return debug_fempty
    end

    local data = self.data
    if data == nil then
        return debug_fempty
    end

    if isString( data ) then
        ---@cast data string
        local wait = true

        return function()
            if wait then
                wait = false
                return "", data
            end

            ---@diagnostic disable-next-line: return-type-mismatch
            return nil, nil
        end
    end

    ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

    local data_key, data_value

    local index = 0
    local size = 0

    return function()
        if index == size then
            data_key, data_value = raw_next( data, data_key )

            if data_value == nil then
                ---@diagnostic disable-next-line: return-type-mismatch
                return nil, nil
            end

            if isString( data_value ) or isNode( data_value ) then
                return data_key, data_value
            end

            size = #data_value
            index = 1

            return data_key, data_value[ index ]
        end

        index = index + 1
        return data_key, data_value[ index ]
    end
end

do

    ---@param attributes table<string, (string | nil)>
    ---@return string attributes_str
    local function format_attributes( attributes )
        ---@type string[]
        local lines = {}

        ---@type integer
        local line_count = 0

        for key, value in raw_pairs( attributes ) do
            line_count = line_count + 1
            lines[ line_count ] = string_format( " %s=\"%s\"", key, value )
        end

        if line_count == 0 then
            return ""
        elseif line_count == 1 then
            return lines[ 1 ]
        elseif line_count == 2 then
            return lines[ 1 ] .. lines[ 2 ]
        else
            return table_concat( lines, "", 1, line_count )
        end
    end

    ---@param lines string[]
    ---@param line_count integer
    ---@param name string
    ---@param value any
    ---@param level integer
    ---@param pretty boolean
    ---@return integer
    local function value_to_string( lines, line_count, name, value, level, pretty )
        line_count = line_count + 1

        if pretty then
            lines[ line_count ] = string_format( "%s<%s>%s</%s>", string_byteRep( 0x20, level * 2 ), name, value, name )
        else
            lines[ line_count ] = string_format( "<%s>%s</%s>", name, value, name )
        end

        return line_count
    end

    ---@param lines string[]
    ---@param line_count integer
    ---@param object dreamwork.std.XMLNode
    ---@param name string
    ---@param level integer
    ---@param pretty boolean
    local function node_to_string( lines, line_count, object, name, level, pretty )
        local attributes = object.attributes

        local indent
        if pretty then
            indent = string_byteRep( 0x20, level * 2 )
        else
            indent = ""
        end

        local data = object.data
        if data == nil then
            line_count = line_count + 1

            if attributes == nil then
                lines[ line_count ] = string_format( "%s<%s/>", indent, name )
            else
                lines[ line_count ] = string_format( "%s<%s%s/>", indent, name, format_attributes( attributes ) )
            end

            return line_count
        end

        if isString( data ) then
            ---@cast data string

            line_count = line_count + 1

            if attributes == nil then
                lines[ line_count ] = string_format( "%s<%s>%s</%s>", indent, name, data, name )
            else
                lines[ line_count ] = string_format( "%s<%s%s>%s</%s>", indent, name, format_attributes( attributes ), data, name )
            end

            return line_count
        end

        ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

        line_count = line_count + 1

        if attributes == nil then
            lines[ line_count ] = string_format( "%s<%s>", indent, name )
        else
            lines[ line_count ] = string_format( "%s<%s%s>", indent, name, format_attributes( attributes ) )
        end

        for key, value in raw_pairs( data ) do
            if isNode( value ) then
                ---@cast value dreamwork.std.XMLNode
                line_count = node_to_string( lines, line_count, value, key, level + 1, pretty )
            elseif isString( value ) then
                ---@cast value string
                line_count = value_to_string( lines, line_count, key, value, level + 1, pretty )
            else

                ---@cast value dreamwork.std.XMLNode.Value[]

                for i = 1, #value, 1 do
                    local sub_value = value[ i ]
                    if isNode( sub_value ) then
                        ---@cast sub_value dreamwork.std.XMLNode
                        line_count = node_to_string( lines, line_count, sub_value, key, level + 1, pretty )
                    elseif isString( sub_value ) then
                        ---@cast sub_value string
                        line_count = value_to_string( lines, line_count, key, sub_value, level + 1, pretty )
                    end
                end

            end
        end

        line_count = line_count + 1
        lines[ line_count ] = string_format( "%s</%s>", indent, name )

        return line_count
    end

    --- [SHARED AND MENU]
    ---
    --- Returns the XML string representation of this node.
    ---
    ---@param pretty? boolean Whether to use pretty formatting (indentation and newlines).
    ---@param name? string The name of the node.
    ---@param level? number The indentation level.
    ---@return string str The XML string representation of this node.
    function XMLNode:toString( pretty, name, level )
        local lines = {}

        local line_count = node_to_string( lines, 0, self, name or self.name, level or 0, pretty == true )
        if line_count == 0 then
            return ""
        elseif line_count == 1 then
            return lines[ 1 ]
        elseif line_count == 2 then
            return lines[ 1 ] .. lines[ 2 ]
        else
            return table_concat( lines, pretty and "\n" or "", 1, line_count )
        end
    end

    --- [SHARED AND MENU]
    ---
    --- Converts XML node structure to a Lua table.
    ---
    ---@return table
    function XMLNode:toTable()
        local result = {}

        local data = self.data
        if data ~= nil and not isString( data ) then
            ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

            for key, value in raw_pairs( data ) do
                if isNode( value ) then
                    ---@cast value dreamwork.std.XMLNode
                    result[ key ] = value:toTable()
                else
                    result[ key ] = value
                end
            end
        end

        return result
    end

    ---@return string
    ---@protected
    function XMLNode:__tostring()
        return self:toString( false )
    end

    ---@return string
    ---@protected
    function XMLNode:__represent()
        local attributes = self.attributes
        if attributes == nil then
            return string_format( "XMLNode: %p <%s/>", self, self.name )
        else
            return string_format( "XMLNode: %p <%s%s/>", self, self.name, format_attributes( attributes ) )
        end
    end

end

do

    local entities       = {
        { "&lt;",   "<" },
        { "&gt;",   ">" },
        { "&amp;",  "&" },
        { "&quot;", "\"" },
        { "&apos;", "\'" },
        {
            "&#(%d+);",
            function( code )
                local integer = raw_tonumber( code )
                if integer >= 0 and integer < 256 then
                    return string_char( integer )
                end

                return "&#" .. code .. ";"
            end
        },
        {
            "&#x(%x+);",
            function( code )
                local integer = raw_tonumber( code, 16 )
                if integer >= 0 and integer < 256 then
                    return string_char( integer )
                end

                return "&#x" .. code .. ";"
            end
        }
    }

    local entitiy_count  = #entities

    ---@type string[]
    local entity_pattern = {}

    ---@type fun( code: string ): string
    local entity_replace = {}

    for i = 1, entitiy_count, 1 do
        local data = entities[ i ]
        entity_pattern[ i ] = data[ 1 ]
        entity_replace[ i ] = data[ 2 ]
    end

    ---@param node dreamwork.std.XMLNode
    ---@param tag_name string
    local function tree_endtag( node, tag_name )
        local data = node.data
        if node.attributes ~= nil then return end

        if data == nil then
            data = ""
        elseif not isString( data ) then
            return
        end

        ---@cast data string

        local parent = node.parent
        if parent == nil then return end

        local parent_data = parent.data
        if parent_data == nil then return end

        ---@cast parent_data string | table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

        if isString( parent_data ) then
            ---@cast parent_data string
            --- lol wft, tell me how pls
            return
        end

        ---@cast parent_data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

        ---@type nil | string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[]
        local parent_value = parent_data[ tag_name ]

        if parent_value == nil or parent_value == node then -- basic situation, when parsed nodes just a single string without anything
            ---@cast parent_data table<string, string>
            parent_data[ tag_name ] = data
            return
        end

        if isString( parent_value ) then -- also how, but okaay, lets just merge this mess
            ---@cast parent_value string
            parent_data[ tag_name ] = parent_value .. data
            return
        end

        ---@cast parent_value dreamwork.std.XMLNode.Value[]
        --- rare case when parent data is a sequential table of strings/nodes, but one of them is the node we're replacing

        for i = 1, #parent_value, 1 do
            local sub_value = parent_value[ i ]
            if sub_value == node then
                parent_value[ i ] = data
                break
            end
        end
    end

    ---@param node dreamwork.std.XMLNode
    ---@param text string
    local function tree_text( node, text )
        local data = node.data
        if data == nil then
            node.data = text
            return
        end

        if isString( data ) then
            ---@cast data string
            node.data = data .. text
            return
        end

        local parent = node.parent
        if parent ~= nil then
            local name = node.name

            local parent_data = parent.data
            if parent_data == nil then
                parent.data = {
                    [ name ] = text,
                }

                return
            end

            if not isString( parent_data ) then
                ---@cast parent_data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

                local parent_value = parent_data[ name ]

                if parent_value == nil then
                    parent_data[ name ] = text
                    return
                end

                ---@cast parent_value string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[]

                if isString( parent_value ) then
                    ---@cast parent_value string
                    parent_data[ name ] = parent_value .. text
                    return
                end

                if isNode( parent_value ) then
                    ---@cast parent_value dreamwork.std.XMLNode
                    parent_data[ name ] = { parent_value, text }
                    return
                end

                ---@cast parent_value dreamwork.std.XMLNode.Value[]
                parent_value[ #parent_value + 1 ] = text
                return
            end
        end

        ---@cast data table<string, (string | dreamwork.std.XMLNode | dreamwork.std.XMLNode.Value[])>

        local text_key = data.text
        if text_key == nil then
            data.text = text
        else
            data.text = text_key .. text
        end
    end

    ---@param str string
    ---@param start_position integer
    ---@return string
    ---@return table<string, string> | nil
    local function parse_tag( str, start_position )
        local tag_start, tag_end, tag_name = string_find( str, "^([%w-:_]+)", start_position, false )
        if not tag_name then
            return str, nil
        end

        local attribute_start, attribute_end, attribute_key, attribute_value = string_find( str, "([%w-:_]+)%s*=%s*[\'\"](.-)[\'\"]", tag_end + 1 )
        if attribute_end == nil then
            return tag_name, nil
        end

        ---@type table<string, string>
        local tag_attributes = {
            [ attribute_key ] = attribute_value or ""
        }

        ::parse_attributes::

        attribute_start, attribute_end, attribute_key, attribute_value = string_find( str, "([%w-:_]+)%s*=%s*[\'\"](.-)[\'\"]", attribute_end + 1 )

        if attribute_end ~= nil then
            tag_attributes[ attribute_key ] = attribute_value or ""
            goto parse_attributes
        end

        return tag_name, tag_attributes
    end

    --- [SHARED AND MENU]
    ---
    --- Converts a table to an XML node structure.
    ---
    ---@param tbl table The table to convert to an XML node.
    ---@param name? string The name of the root node.
    ---@return dreamwork.std.XMLNode root_node The root node of the XML tree.
    function XMLNodeClass.fromTable( tbl, name )
        local node = XMLNodeClass( name or "root", nil, nil )

        for key, value in pairs( tbl ) do
            if not isString( key ) then
                key = tostring( key )
            end

            if isNode( value ) then
                ---@cast value dreamwork.std.XMLNode
                node:push( key, value )
            elseif isTable( value ) then
                ---@cast value table
                node:push( key, XMLNodeClass.fromTable( value, key ) )
            elseif isString( value ) then
                ---@cast value string
                node:push( key, value )
            else
                ---@cast value any
                node:push( key, tostring( value ) )
            end
        end

        return node
    end

    --- [SHARED AND MENU]
    ---
    --- Converts an XML string to an XML node structure.
    ---
    ---@param xml_str string
    ---@return dreamwork.std.XMLNode | nil
    function XMLNodeClass.fromString( xml_str )
        ---@type dreamwork.std.XMLNode
        local active_node

        ---@type dreamwork.std.XMLNode
        local root_node

        ---@type integer
        local position = 1
        ::analyze_loop::

        local xml_start, xml_end, xml_content, xml_tag = string_find( xml_str, "^([^<]*)<([^>]-)>", position, false )
        if xml_start == nil or xml_end == nil then
            if string_match( xml_str, "^%s*$", position ) == nil then
                std.errorf( 2, false, "XML parsing failed, no more tags/EOF." )
                return nil
            elseif active_node ~= nil then
                std.errorf( 2, false, "XML parsing failed, incomplete XML." )
                return nil
            end

            return root_node
        end

        if xml_content ~= nil then
            xml_start = xml_start + string_len( xml_content )
            xml_content = string_trim( xml_content, "%s" )

            for i = 1, entitiy_count, 1 do
                xml_content = string_gsub( xml_content, entity_pattern[ i ], entity_replace[ i ] )
            end

            if not string_isEmpty( xml_content ) then
                tree_text( active_node, xml_content )
            end
        end

        xml_tag = string_trim( xml_tag, "%s" )

        local b1, b2, b3, b4,
        b5, b6, b7, b8 = string_byte( xml_tag, 1, 8 )

        local xml_start_with_slash = b1 == 0x2F --[[ / ]]
        if xml_start_with_slash then
            xml_tag = string_sub( xml_tag, 2 )
        end

        local xml_end_with_slash = string_byte( xml_tag, -1, -1 ) == 0x2F --[[ / ]]
        if xml_end_with_slash then
            xml_tag = string_sub( xml_tag, 1, -2 )
        end

        -- PI
        if b1 == 0x3F --[[ ? ]] then
            position = (xml_end or position) + 1
            goto analyze_loop
        end

        -- Comment
        if b1 == 0x21 --[[ ! ]] and b2 == 0x2D --[[ - ]] and b3 == 0x2D --[[ - ]] then
            local comment_start, comment_end = string_find( xml_str, "<!%-%-.-%-%->", position )
            if comment_start then
                position = comment_end + 1
            else
                position = (xml_end or position) + 1
            end

            goto analyze_loop
        end

        -- DOCTYPE
        if b1 == 0x21 --[[ ! ]] and b2 == 0x44 --[[ D ]] and b3 == 0x4F --[[ O ]] and b4 == 0x43 --[[ C ]] and
            b5 == 0x54 --[[ T ]] and b6 == 0x59 --[[ Y ]] and b7 == 0x50 --[[ P ]] and b8 == 0x45 --[[ E ]] then

            local doctype_start, doctype_end = string_find( xml_str, "<!DOCTYPE.-%b[]%s*>", position )
            if not doctype_start then
                doctype_start, doctype_end = string_find( xml_str, "<!DOCTYPE.->", position )
            end

            if doctype_start then
                position = doctype_end + 1
            else
                position = (xml_end or position) + 1
            end

            goto analyze_loop
        end

        -- CDATA
        if b1 == 0x21 --[[ ! ]] and b2 == 0x5B --[[ [ ]] and b3 == 0x43 --[[ C ]] and b4 == 0x44 --[[ D ]] and
            b5 == 0x41 --[[ A ]] and b6 == 0x54 --[[ T ]] and b7 == 0x41 --[[ A ]] and b8 == 0x5B --[[ [ ]] then

            local cdata_start, cdata_end, cdata_text = string_find( xml_str, "<%!%[CDATA%[(.-)%]%]>", position )
            if cdata_start == nil then
                std.errorf( 2, false, "CDATA not found at position %d", position )
                return nil
            end

            tree_text( active_node, cdata_text )

            position = cdata_end + 1
            goto analyze_loop
        end

        local extension_start, extension_end, extension_text
        local error_start, error_end

        ::validation_loop::

        -- If there isn't an attribute without closing quotes (single or double quotes)
        -- then breaks to follow the normal processing of the tag.
        -- Otherwise, try to find where the quotes close.

        error_start, error_end = string_find( xml_tag, "=+?%s*\"[^\"]*$" )
        if error_end == nil then
            error_start, error_end = string_find( xml_tag, "=+?%s*\'[^\']*$" )
            if error_end == nil then
                goto validation_finished
            end
        end

        extension_start, extension_end, extension_text = string_find( xml_str, "(%/?)>", xml_end + 1 )
        if extension_start == nil then
            std.errorf( 2, false, "XML tag not closed at position %d", position )
            return nil
        end

        xml_tag = xml_tag .. string_sub( xml_str, xml_end, extension_end - 1 )

        ---@diagnostic disable-next-line: cast-local-type
        xml_end = extension_end
        goto validation_loop

        ::validation_finished::

        local tag_name, tag_attributes = parse_tag( xml_tag, 1 )
        if xml_start_with_slash then
            if tag_attributes ~= nil then
                std.errorf( 2, false, "Attributes not allowed in end tag (%s)", tag_name )
                return nil
            elseif active_node == nil or active_node.name ~= tag_name then
                std.errorf( 2, false, "Unmatched tag (%s) at position %d", tag_name, position )
                return nil
            end

            tree_endtag( active_node, tag_name )
            active_node = active_node.parent

            position = (xml_end or position) + 1
            goto analyze_loop
        end

        active_node = XMLNodeClass( tag_name, tag_attributes, active_node )

        if root_node == nil then
            root_node = active_node
        end

        -- />
        if xml_end_with_slash then
            tree_endtag( active_node, tag_name )
            active_node = active_node.parent
        end

        position = (xml_end or position) + 1

        ---@diagnostic disable-next-line: missing-return
        goto analyze_loop
    end

end

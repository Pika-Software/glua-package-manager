---@class dreamwork.std
local std = dreamwork.std

local engine = dreamwork.engine

---@class dreamwork.std.Addon: dreamwork.std.Object
---@field __class dreamwork.std.AddonClass
local Addon = std.class.base( "Addon" )

---@class dreamwork.std.AddonClass: dreamwork.std.Addon
---@field __base dreamwork.std.Addon
---@overload fun(): dreamwork.std.Addon
local AddonClass = std.class.create( Addon )
std.Addon = AddonClass

---@protected
function Addon:__init()
    self.id = -1
    self.title = ""
    self.file = nil
end

local function find_workshop_item( wsid )

end

--- [SHARED AND MENU]
---
--- Returns all subscribed publications.
---
---@return dreamwork.std.game.Addon[] items The subscribed addons.
---@return integer item_count The length of the addons found array (`#addons`).
function AddonClass.getDownloaded()

end

--- [SHARED AND MENU]
---
--- Returns all mounted addons.
---
---@return dreamwork.std.steam.workshop.Item[] items The mounted addons.
---@return integer item_count The length of the addons found array (`#addons`).
function AddonClass.getMounted()
    local addons = engine.addons

    local result, length = {}, 0
    for i = 1, engine.addon_count, 1 do
        local data = addons[ i ]
        if data.mounted then
            length = length + 1
            result[ length ] = ItemClass( data.wsid )
        end
    end

    return result, length
end

local raw_get = std.raw.get

local key2fn = {}

function key2fn:title()
    local data = engine.wsid2addon[ self.id ]
    return data ~= nil and data.title
end

function key2fn:file()
    local data = engine.wsid2addon[ self.id ]
    return data ~= nil and data.file
end

function key2fn:id()
    local title = raw_get( self, "title" )
    if title == nil then
        return -1
    end

    local data = engine.title2addon[ title ]
    return data ~= nil and data.id
end

function key2fn:downloaded()
    local data = engine.wsid2addon[ self.id ]
    return data ~= nil and data.downloaded == true
end

function key2fn:mounted()
    local data = engine.title2addon[ self.title ]
    return data ~= nil and data.mounted == true
end

function key2fn:mounted_at()
    local data = engine.wsid2addon[ self.id ]
    return data ~= nil and data.timeadded
end

function key2fn:updated_at()
    local data = engine.wsid2addon[ self.id ]
    return data ~= nil and data.updated
end

function key2fn:size()
    local data = engine.wsid2addon[ self.id ]
    return data ~= nil and data.size
end

do

    local string = std.string

    local string_lower = string.lower
    local table_remove = std.table.remove
    local string_byteSplit = string.byteSplit

    do

        ---@type table<dreamwork.std.steam.workshop.Item.Type, boolean>
        local addon_types = {
            gamemode = true,
            map = true,
            weapon = true,
            vehicle = true,
            npc = true,
            entity = true,
            tool = true,
            effects = true,
            model = true,
            servercontent = true
        }

        function key2fn:type()
            local data = engine.wsid2addon[ self.id ]
            if data == nil then
                return "unknown"
            end

            local tags, length = string_byteSplit( data.tags, 0x2C --[[ , ]] )

            for i = length, 1, -1 do
                local tag = string_lower( tags[ i ] )
                if addon_types[ tag ] then return tag end
            end

            return "unknown"
        end

    end

    do

        ---@type table<dreamwork.std.steam.workshop.Item.AddonTag, boolean>
        local addon_tags = {
            fun = true,
            roleplay = true,
            scenic = true,
            movie = true,
            realism = true,
            cartoon = true,
            water = true,
            comic = true,
            build = true
        }

        function key2fn:tags()
            local data = engine.wsid2addon[ self.id ]
            if data == nil then
                return {}
            end

            local tags, length = string_byteSplit( data.tags, 0x2C --[[ , ]] )

            for i = length, 1, -1 do
                local tag = string_lower( tags[ i ] )
                if addon_tags[ tag ] then
                    tags[ i ] = tag
                else
                    table_remove( tags, i )
                    length = length - 1
                end
            end

            return tags, length
        end

    end

end

---@protected
function Addon:__index( key )
    local fn = key2fn[ key ]
    if fn == nil then
        local value = raw_get( self, key )
        if value == nil then
            return raw_get( Addon, key )
        else
            return value
        end
    else
        return fn( self )
    end
end

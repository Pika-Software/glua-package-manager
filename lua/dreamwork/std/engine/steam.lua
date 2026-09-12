local glua_steamworks = steamworks
local glua_system = system

---@class dreamwork.std
local std = dreamwork.std
local string = std.string

local setTimeout = std.setTimeout
local isString = std.isString
local error = std.error

local Future = std.Future


-- TODO: https://wiki.facepunch.com/gmod/resource.AddWorkshop
-- TODO: https://holylib.raphaelit7.com/addonsystem

--- [SHARED AND MENU]
---
--- Steam API library.
---
---@class dreamwork.std.steam
local steam = {}
std.steam = steam

if glua_system ~= nil then

    steam.getAwayTime = glua_system.UpTime or function() return 0 end
    steam.getAppTime = glua_system.AppTime or steam.getAwayTime
    steam.getTime = glua_system.SteamTime or std.time.now

end

if std.LUA_CLIENT_MENU then

    do

        local glua_achievements = _G.achievements
        local achievements_Count, achievements_GetName, achievements_GetDesc, achievements_GetCount, achievements_GetGoal, achievements_IsAchieved = glua_achievements.Count, glua_achievements.GetName, glua_achievements.GetDesc, glua_achievements.GetCount, glua_achievements.GetGoal, glua_achievements.IsAchieved

        -- TODO: update code/docs

        --- [CLIENT AND MENU]
        ---
        --- Returns information about an achievement (name, description, value, etc.)
        ---
        ---@param id number The ID of achievement to retrieve name of. Note  IDs start from 0, not 1.
        ---@return table | nil table Returns nil if the ID is invalid.
        local function get( id )
            local goal = achievements_GetGoal( id )
            if goal == nil then return nil end

            local isAchieved = achievements_IsAchieved( id )

            return {
                name = achievements_GetName( id ),
                description = achievements_GetDesc( id ),
                value = isAchieved and goal or achievements_GetCount( id ),
                achieved = isAchieved,
                goal = goal
            }
        end

        --- [CLIENT AND MENU]
        ---
        --- The game achievement library.
        ---
        ---@class dreamwork.std.game.achievement
        local achievement = {
            getCount = achievements_Count,
            get = get
        }

        --- [CLIENT AND MENU]
        ---
        --- Checks if an achievement with the given ID exists.
        ---
        ---@param id number
        ---@return boolean exist Returns true if the achievement exists.
        function achievement.exists( id )
            return achievements_IsAchieved( id ) ~= nil
        end

        --- [CLIENT AND MENU]
        ---
        --- Returns information about all achievements.
        ---
        ---@return table achievement_list The list of all achievements.
        ---@return number achievement_count The count of achievements.
        function achievement.getAll()
            local tbl, count = {}, achievements_Count()
            for index = 0, count - 1 do
                tbl[ index + 1 ] = get( index )
            end

            return tbl, count
        end

        game.achievement = achievement

    end

end

--- [SHARED AND MENU]
---
--- Steam [EResult](https://partner.steamgames.com/doc/api/steam_api#EResult) messages.
local EResultMessages = {
    [ 1 ] = "Success.",
    [ 2 ] = "Generic failure.",
    [ 3 ] = "Your Steam client doesn't have a connection to the back-end.",
    [ 5 ] = "Password/ticket is invalid.",
    [ 6 ] = "The user is logged in elsewhere.",
    [ 7 ] = "Protocol version is incorrect.",
    [ 8 ] = "A parameter is incorrect.",
    [ 9 ] = "File was not found.",
    [ 10 ] = "Called method is busy - action not taken.",
    [ 11 ] = "Called object was in an invalid state.",
    [ 12 ] = "The name was invalid.",
    [ 13 ] = "The email was invalid.",
    [ 14 ] = "The name is not unique.",
    [ 15 ] = "Access is denied.",
    [ 16 ] = "Operation timed out.",
    [ 17 ] = "The user is VAC2 banned.",
    [ 18 ] = "Account not found.",
    [ 19 ] = "The Steam ID was invalid.",
    [ 20 ] = "The requested service is currently unavailable.",
    [ 21 ] = "The user is not logged on.",
    [ 22 ] = "Request is pending, it may be in process or waiting on third party.",
    [ 23 ] = "Encryption or Decryption failed.",
    [ 24 ] = "Insufficient privilege.",
    [ 25 ] = "Too much of a good thing.",
    [ 26 ] = "Access has been revoked (used for revoked guest passes.)",
    [ 27 ] = "License/Guest pass the user is trying to access is expired.",
    [ 28 ] = "Guest pass has already been redeemed by account, cannot be used again.",
    [ 29 ] = "The request is a duplicate and the action has already occurred in the past, ignored this time.",
    [ 30 ] = "All the games in this guest pass redemption request are already owned by the user.",
    [ 31 ] = "IP address not found.",
    [ 32 ] = "Failed to write change to the data store.",
    [ 33 ] = "Failed to acquire access lock for this operation.",
    [ 34 ] = "The logon session has been replaced.",
    [ 35 ] = "Failed to connect.",
    [ 36 ] = "The authentication handshake has failed.",
    [ 37 ] = "There has been a generic IO failure.",
    [ 38 ] = "The remote server has disconnected.",
    [ 39 ] = "Failed to find the shopping cart requested.",
    [ 40 ] = "A user blocked the action.",
    [ 41 ] = "The target is ignoring sender.",
    [ 42 ] = "Nothing matching the request found.",
    [ 43 ] = "The account is disabled.",
    [ 44 ] = "This service is not accepting content changes right now.",
    [ 45 ] = "Account doesn't have value, so this feature isn't available.",
    [ 46 ] = "Allowed to take this action, but only because requester is admin.",
    [ 47 ] = "A Version mismatch in content transmitted within the Steam protocol.",
    [ 48 ] = "The current CM can't service the user making a request, user should try another.",
    [ 49 ] = "You are already logged in elsewhere, this cached credential login has failed.",
    [ 50 ] = "The user is logged in elsewhere. (Use k_EResultLoggedInElsewhere instead!)",
    [ 51 ] = "Long running operation has suspended/paused. (eg. content download.)",
    [ 52 ] = "Operation has been canceled, typically by user. (eg. a content download.)",
    [ 53 ] = "Operation canceled because data is ill formed or unrecoverable.",
    [ 54 ] = "Operation canceled - not enough disk space.",
    [ 55 ] = "The remote or IPC call has failed.",
    [ 56 ] = "Password could not be verified as it's unset server side.",
    [ 57 ] = "External account (PSN, Facebook...) is not linked to a Steam account.",
    [ 58 ] = "PSN ticket was invalid.",
    [ 59 ] = "External account (PSN, Facebook...) is already linked to some other account, must explicitly request to replace/delete the link first.",
    [ 60 ] = "The sync cannot resume due to a conflict between the local and remote files.",
    [ 61 ] = "The requested new password is not allowed.",
    [ 62 ] = "New value is the same as the old one. This is used for secret question and answer.",
    [ 63 ] = "Account login denied due to 2nd factor authentication failure.",
    [ 64 ] = "The requested new password is not legal.",
    [ 65 ] = "Account login denied due to auth code invalid.",
    [ 66 ] = "Account login denied due to 2nd factor auth failure - and no mail has been sent.",
    [ 67 ] = "The users hardware does not support Intel's Identity Protection Technology (IPT).",
    [ 68 ] = "Intel's Identity Protection Technology (IPT) has failed to initialize.",
    [ 69 ] = "Operation failed due to parental control restrictions for current user.",
    [ 70 ] = "Facebook query returned an error.",
    [ 71 ] = "Account login denied due to an expired auth code.",
    [ 72 ] = "The login failed due to an IP restriction.",
    [ 73 ] = "The current users account is currently locked for use. This is likely due to a hijacking and pending ownership verification.",
    [ 74 ] = "The logon failed because the accounts email is not verified.",
    [ 75 ] = "There is no URL matching the provided values.",
    [ 76 ] = "Bad Response due to a Parse failure, missing field, etc.",
    [ 77 ] = "The user cannot complete the action until they re-enter their password.",
    [ 78 ] = "The value entered is outside the acceptable range.",
    [ 79 ] = "Something happened that we didn't expect to ever happen.",
    [ 80 ] = "The requested service has been configured to be unavailable.",
    [ 81 ] = "The files submitted to the CEG server are not valid.",
    [ 82 ] = "The device being used is not allowed to perform this action.",
    [ 83 ] = "The action could not be complete because it is region restricted.",
    [ 84 ] = "Temporary rate limit exceeded, try again later, different from k_EResultLimitExceeded which may be permanent.",
    [ 85 ] = "Need two-factor code to login.",
    [ 86 ] = "The thing we're trying to access has been deleted.",
    [ 87 ] = "Login attempt failed, try to throttle response to possible attacker.",
    [ 88 ] = "Two factor authentication (Steam Guard) code is incorrect.",
    [ 89 ] = "The activation code for two-factor authentication (Steam Guard) didn't match.",
    [ 90 ] = "The current account has been associated with multiple partners.",
    [ 91 ] = "The data has not been modified.",
    [ 92 ] = "The account does not have a mobile device associated with it.",
    [ 93 ] = "The time presented is out of range or tolerance.",
    [ 94 ] = "SMS code failure - no match, none pending, etc.",
    [ 95 ] = "Too many accounts access this resource.",
    [ 96 ] = "Too many changes to this account.",
    [ 97 ] = "Too many changes to this phone.",
    [ 98 ] = "Cannot refund to payment method, must use wallet.",
    [ 99 ] = "Cannot send an email.",
    [ 100 ] = "Can't perform operation until payment has settled.",
    [ 101 ] = "The user needs to provide a valid captcha.",
    [ 102 ] = "A game server login token owned by this token's owner has been banned.",
    [ 103 ] = "Game server owner is denied for some other reason such as account locked, community ban, vac ban, missing phone, etc.",
    [ 104 ] = "The type of thing we were requested to act on is invalid.",
    [ 105 ] = "The IP address has been banned from taking this action.",
    [ 106 ] = "This Game Server Login Token (GSLT) has expired from disuse; it can be reset for use.",
    [ 107 ] = "User doesn't have enough wallet funds to complete the action",
    [ 108 ] = "There are too many of this thing pending already"
}

--- [SHARED AND MENU]
---
--- Steam [EWorkshopFileType](https://partner.steamgames.com/doc/api/ISteamRemoteStorage#EWorkshopFileType)'s.
---
---@type table<integer, string>
local EWorkshopFileType = {
    [ 0 ] = "item",
    [ 1 ] = "microtransaction",
    [ 2 ] = "collection",
    [ 3 ] = "artwork",
    [ 4 ] = "video",
    [ 5 ] = "screenshot",
    [ 6 ] = "game",
    [ 7 ] = "software",
    [ 8 ] = "concept",
    [ 9 ] = "webguide",
    [ 10 ] = "web_guide",
    [ 11 ] = "merch",
    [ 12 ] = "controller_binding",
    [ 13 ] = "steamworks_access_invite",
    [ 14 ] = "steam_video",
    [ 15 ] = "game_managed_item"
}

do

    local meta = {
        __index = function( _, code )
            return "unknown code (" .. (code or "nil") .. ")"
        end
    }

    std.setmetatable( EWorkshopFileType, meta )
    std.setmetatable( EResultMessages, meta )

end

--- [SHARED AND MENU]
---
--- Steam [ERemoteStoragePublishedFileVisibility](https://partner.steamgames.com/doc/api/ISteamRemoteStorage#ERemoteStoragePublishedFileVisibility) int32 to string.
---
---@type table<integer, string>
local ERemoteStoragePublishedFileVisibility = {
    [ 0 ] = "public",
    [ 1 ] = "friends_only",
    [ 2 ] = "private",
    [ 3 ] = "unlisted"
}

local default_timeout = std.http.Timeout

if std.LUA_CLIENT_MENU then

    --- [CLIENT AND MENU]
    ---
    --- Returns the name of the player with the given Steam ID.
    ---
    ---@param id dreamwork.std.steam.Identifier The SteamID of the player.
    ---@param timeout? number The timeout in seconds, if `nil` then the default timeout will be used.
    ---@return string name The name of the player.
    ---@async
    function steam.getUserName( id, timeout )
        local f = Future()

        glua_steamworks.RequestPlayerInfo( id:to64(), function( name )
            if name == nil then
                f:setError( "failed to get player name for '" .. id:toSteam3() .. "', unknown error" )
            else
                f:setResult( name )
            end
        end )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to get player name for '" .. id:toSteam3() .. "', timed out" )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        return f:await()
    end

end

--- [SHARED AND MENU]
---
--- The Steam Workshop API library.
---
---@class dreamwork.std.steam.workshop
local workshop = steam.workshop or {}
steam.workshop = workshop

do

    local string_match = string.match

    --- [SHARED AND MENU]
    ---
    --- Checks if the given Steam Workshop item ID is valid.
    ---
    ---@param id? string
    ---@return boolean
    function workshop.isValidID( id )
        return id or id ~= "0" and isString( id ) and string_match( id, "^%d+$", 1 )
    end

end

do

    local Identifier_from64 = steam.Identifier.from64
    local http_StatusCodes = std.http.StatusCodes
    local json_deserialize = std.json.deserialize
    local http_request = std.http.request
    local string_lower = string.lower

    ---@param count_key string
    ---@param args string[]
    ---@param arg_count integer
    ---@return table<string, string>
    local function prepare_parameters( count_key, args, arg_count )
        local parameters = {}

        for i = 0, arg_count - 1, 1 do
            parameters[ "publishedfileids[" .. i .. "]" ] = args[ i + 1 ]
        end

        parameters[ count_key ] = tostring( arg_count )

        return parameters
    end

    do

        --- [SHARED AND MENU]
        ---
        --- Returns the details of a Steam Workshop collection's.
        ---
        ---@param ids string[] The Steam Workshop item ID's.
        ---@param id_count? integer The number of Steam Workshop item ID's.
        ---@param timeout? number The timeout in seconds, if `nil` then the default timeout will be used.
        ---@return dreamwork.std.steam.workshop.Collection.Details[] items The details of the Steam Workshop collections.
        ---@return integer item_count The number of Steam Workshop collections.
        ---@async
        function workshop.getCollectionDetails( ids, id_count, timeout )
            if id_count == nil then
                id_count = #ids
            end

            local http_response = http_request( {
                method = "POST",
                parameters = prepare_parameters( "collectioncount", ids, id_count ),
                url = "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/",
                timeout = timeout
            } )

            if http_response.status ~= 200 then
                error( http_StatusCodes[ http_response.status ], 2 )
            end

            local json_data = json_deserialize( http_response.body or "" )
            if json_data == nil then
                error( "Wrong JSON format - wrong response format", 2 )
            end

            local steam_response = json_data.response
            if steam_response == nil then
                error( "No response - API returned invalid data", 2 )
            elseif steam_response.result ~= 1 then
                error( EResultMessages[ steam_response.result ], 2 )
            end

            local collectiondetails = steam_response.collectiondetails
            if collectiondetails == nil then
                error( "No collectiondetails - API returned invalid data", 2 )
            end

            if #collectiondetails ~= id_count then
                error( "Wrong number of collectiondetails - API returned invalid data", 2 )
            end

            ---@type dreamwork.std.steam.workshop.Collection.Details[]
            local collections = {}

            for i = 1, id_count, 1 do
                local item = collectiondetails[ i ]
                if item.result == 1 then
                    local children = item.children
                    local item_count = #children

                    local output_items = {}

                    ---@type dreamwork.std.steam.workshop.Collection.Details
                    local collection = {
                        id = item.publishedfileid,
                        items = output_items,
                        item_count = item_count
                    }

                    collections[ i ] = collection

                    for j = 1, item_count, 1 do
                        local child = children[ j ]

                        ---@type dreamwork.std.steam.workshop.Collection.Details.Item
                        output_items[ i ] = {
                            id = child.publishedfileid or "",
                            type = EWorkshopFileType[ child.filetype ] or "unknown",
                            order = child.sortorder or -1
                        }
                    end
                else
                    collections[ i ] = {
                        id = item.publishedfileid,
                        reason = EResultMessages[ item.result ]
                    }
                end
            end

            return collections, id_count
        end

    end

    --- [SHARED AND MENU]
    ---
    --- Returns the details of a Steam Workshop item's.
    ---
    ---@param ids string[] The Steam Workshop item ID's.
    ---@param id_count? integer The number of Steam Workshop item ID's.
    ---@param timeout? number The timeout in seconds, if `nil` then the default timeout will be used.
    ---@return dreamwork.std.steam.workshop.Item.Details[] items The details of the Steam Workshop items.
    ---@return integer item_count The number of Steam Workshop items.
    ---@async
    function workshop.getItemDetails( ids, id_count, timeout )
        if id_count == nil then
            id_count = #ids
        end

        local http_response = http_request( {
            method = "POST",
            parameters = prepare_parameters( "itemcount", ids, id_count ),
            url = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/",
            timeout = timeout
        } )

        if http_response.status ~= 200 then
            error( http_StatusCodes[ http_response.status ], 2 )
        end

        local json_data = json_deserialize( http_response.body or "" )
        if json_data == nil then
            error( "Wrong JSON format - wrong response format", 2 )
        end

        local steam_response = json_data.response
        if steam_response == nil then
            error( "No response - API returned invalid data", 2 )
        elseif steam_response.result ~= 1 then
            error( EResultMessages[ steam_response.result ], 2 )
        end

        local publishedfiledetails = steam_response.publishedfiledetails
        if publishedfiledetails == nil then
            error( "No publishedfiledetails - API returned invalid data", 2 )
        end

        if #publishedfiledetails ~= id_count then
            error( "Wrong number of publishedfiledetails - API returned invalid data", 2 )
        end

        local items = {}

        for i = 1, id_count, 1 do
            local details = publishedfiledetails[ i ]
            if details.result == 1 then
                local banned = details.banned == 1
                local tag_strings = {}

                local item = {
                    id = details.publishedfileid,
                    title = details.title,
                    description = details.description,
                    preview_url = details.preview_url,
                    visibility = ERemoteStoragePublishedFileVisibility[ details.visibility ] or "unknown",
                    tags = tag_strings,
                    banned = banned,
                    favorited = details.lifetime_favorited,
                    subscriptions = details.lifetime_subscriptions,
                    views = details.views,
                    owner_id = Identifier_from64( details.creator ),
                    created_at = details.time_created,
                    updated_at = details.time_updated,
                    file_name = details.filename,
                    file_size = details.file_size,
                    file_url = details.file_url,
                    consumer_app_id = details.consumer_app_id,
                    creator_app_id = details.creator_app_id,
                    hcontent_file = details.hcontent_file,
                    hcontent_preview = details.hcontent_preview
                }

                items[ i ] = item

                if not banned then
                    item.ban_reason = nil
                end

                local tags = details.tags

                for j = 1, #tags, 1 do
                    tag_strings[ j ] = string_lower( tags[ j ].tag )
                end
            else
                items[ i ] = {
                    id = details.publishedfileid,
                    reason = EResultMessages[ details.result ] or "unknown error"
                }
            end
        end

        return items, id_count
    end

    do

        local string_byteSplit = string.byteSplit

        -- https://wiki.facepunch.com/gmod/Structures/UGCFileInfo#error
        local error_codes = {
            [ -1 ] = "failed to create query.",
            [ -2 ] = "failed to send query.",
            [ -3 ] = "Steam API response is invalid.",
            [ -4 ] = "failed to get item data from the response.",
            [ -5 ] = "Steam Workshop item ID in the response is invalid.",
            [ -6 ] = "Steam Workshop item ID in response is mismatching the requested file ID."
        }

        --- [SHARED AND MENU]
        ---
        --- Fetches a detailed information about a specific Steam Workshop item or collection.
        ---
        ---@param wsid string The workshop ID of the item/collection.
        ---@param timeout? number The timeout in seconds, if `nil` then the default timeout will be used.
        ---@return dreamwork.std.steam.workshop.ItemInfo info The details of the item/collection.
        ---@async
        function workshop.fetchInfo( wsid, timeout )
            local f = Future()

            glua_steamworks.FileInfo( wsid, function( item )
                if item == nil then
                    f:setError( "failed to fetch info for '" .. wsid .. "', unknown error." )
                    return
                end

                local error_message = error_codes[ item.error or 0 ]
                if error_message ~= nil then
                    f:setError( error_message )
                    return
                end

                ---@cast item UGCFileInfo

                local tags, tag_count = string_byteSplit( item.tags or "", 0x2C --[[ , ]] )
                local tag_list = {}

                for j = 1, tag_count, 1 do
                    tag_list[ j ] = string_lower( tags[ j ] )
                end

                ---@diagnostic disable-next-line: undefined-field
                local warnings = item.content_descriptors
                if warnings and #warnings == 0 then
                    ---@diagnostic disable-next-line: cast-local-type
                    warnings = nil
                end

                f:setResult( {
                    id = item.id,
                    title = item.title,
                    description = item.description,

                    ---@diagnostic disable-next-line: undefined-field
                    visibility = ERemoteStoragePublishedFileVisibility[ item.visibility ] or "unknown",

                    warnings = warnings,
                    tags = tag_list,

                    installed = item.installed,
                    disabled = item.disabled,
                    banned = item.banned,

                    ---@diagnostic disable-next-line: param-type-mismatch
                    owner_id = Identifier_from64( item.owner ),

                    file_id = item.fileid,
                    file_size = item.size,

                    created_at = item.created,
                    updated_at = item.updated,

                    preview_id = item.previewid,
                    preview_url = item.previewurl,
                    preview_size = item.previewsize,

                    votes_score = item.score,
                    votes_total = item.total,
                    votes_down = item.down,
                    votes_up = item.up
                } )
            end )

            setTimeout( function()
                if f:isPending() then
                    f:setError( "fetch info for '" .. wsid .. "' timed out." )
                end

                ---@diagnostic disable-next-line: param-type-mismatch
            end, timeout or default_timeout.value )

            return f:await()
        end

    end

end

if std.LUA_CLIENT_MENU then

    --- [CLIENT AND MENU]
    ---
    --- Returns whether the addon should be mounted on local server start-up.
    ---
    ---@param wsid string The workshop ID of the addon.
    ---@return boolean `true` if the addon is enabled, `false` otherwise.
    ---@see dreamwork.std.steam.workshop.setAddonEnabled
    function workshop.isAddonEnabled( wsid )
        return glua_steamworks.ShouldMountAddon( tostring( wsid ) )
    end

    --- [CLIENT AND MENU]
    ---
    --- Returns whether the publication is subscribed.
    ---
    ---@param wsid string The workshop ID of the addon.
    ---@return boolean `true` if client has subscribed to the item, `false` otherwise.
    ---@see dreamwork.std.steam.workshop.setItemSubscribed
    function workshop.isItemSubscribed( wsid )
        return glua_steamworks.IsSubscribed( wsid )
    end

    --- [CLIENT AND MENU]
    ---
    --- Opens the page of the addon in the Steam Workshop.
    ---
    ---@param wsid string The workshop ID of the addon.
    function workshop.openPage( wsid )
        glua_steamworks.ViewFile( wsid )
    end

    --- [MENU]
    ---
    --- Downloads the icon of the Steam Workshop item and returns the absolute path to the file.
    ---
    ---@param wsid string The workshop ID of the addon.
    ---@param uncompress? boolean Whether the icon should be uncompressed, `true` by default.
    ---@param timeout? number The timeout in seconds, if `nil` then the default timeout will be used.
    ---@return string file_path The absolute path to the icon file.
    ---@async
    function workshop.downloadIcon( wsid, uncompress, timeout )
        local f = Future()

        -- TODO: re-write function with
        -- https://wiki.facepunch.com/gmod/Global.AddonMaterial
        -- to be sure that material readable

        glua_steamworks.Download( wsid, uncompress ~= false, function( file_path )
            if file_path == nil then
                f:setError( "failed to download icon file for '" .. wsid .. "', unknown error." )
            else
                f:setResult( "/workspace/" .. file_path )
            end
        end )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to download icon file for '" .. wsid .. "', timed out." )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        return f:await()
    end

end

if std.LUA_MENU then

    --- [MENU]
    ---
    --- Sets whether the addon should be mounted on local server start-up.
    ---
    ---@param wsid string The workshop ID of the addon.
    ---@param enabled boolean `true` to enable the addon, `false` to disable it.
    ---@see dreamwork.std.steam.workshop.isAddonEnabled
    ---@see dreamwork.std.steam.workshop.reload
    function workshop.setAddonEnabled( wsid, enabled )
        glua_steamworks.SetShouldMountAddon( tostring( wsid ), enabled )
    end

    --- [MENU]
    ---
    --- Subscribes or unsubscribes the publication.
    ---
    ---@param wsid string The workshop ID of the addon.
    ---@param subscribed boolean `true` to subscribe, `false` to unsubscribe.
    ---@see dreamwork.std.steam.workshop.isItemSubscribed
    ---@see dreamwork.std.steam.workshop.reload
    function workshop.setItemSubscribed( wsid, subscribed )
        (subscribed and glua_steamworks.Subscribe or glua_steamworks.Unsubscribe)( wsid )
    end

    --- [MENU]
    ---
    --- Refreshes local Steam Workshop addons.
    ---
    --- This function should be called after changing the list of enabled addons.
    ---
    ---@see dreamwork.std.steam.workshop.isAddonEnabled
    ---@see dreamwork.std.steam.workshop.setItemSubscribed
    function workshop.reload()
        glua_steamworks.ApplyAddons()
    end

    --- [MENU]
    ---
    --- Marks the Steam Workshop item as completed.
    ---
    ---@param wsid string The workshop ID of the addon.
    function workshop.markAsCompleted( wsid )
        glua_steamworks.SetFileCompleted( wsid )
    end

    --- [MENU]
    ---
    --- Marks the Steam Workshop item as played.
    ---
    ---@param wsid string The workshop ID of the addon.
    function workshop.markAsPlayed( wsid )
        glua_steamworks.SetFilePlayed( wsid )
    end

    --- [MENU]
    ---
    --- Votes for the Steam Workshop item.
    ---
    ---@param wsid string The workshop ID of the addon.
    ---@param vote boolean `true` to vote for, `false` to vote against.
    function workshop.vote( wsid, vote )
        glua_steamworks.Vote( wsid, vote )
    end

end

-- https://github.com/WilliamVenner/gmsv_workshop
---@diagnostic disable-next-line: undefined-field
if std.LUA_SERVER and not (std.isTable( steamworks ) and std.isFunction( steamworks.DownloadUGC )) then
    if std.loadbinary( "workshop" ) then
        dreamwork.Logger:info( "'gmsv_workshop' was loaded & connected as server-side Steam Workshop API." )
    else
        dreamwork.Logger:warn( "'gmsv_workshop' is missing, `steam.workshop.download` will do nothing on server." )
    end
end

do

    local fs = std.fs
    local fs_write = fs.write
    local fs_isFile = fs.isFile

    local futures_run = std.futures.run
    local uuid_v7 = std.uuid.v7

    ---@param f dreamwork.std.Future
    ---@param wsid string
    ---@param file_path string?
    ---@param file_class File?
    ---@async
    local function perform_response( f, wsid, file_path, file_class )
        if file_path ~= nil and fs_isFile( "/garrysmod/" .. file_path ) then
            f:setResult( "/workspace/" .. file_path )
            return
        end

        if file_class == nil then
            f:setError( "failed to download addon '" .. wsid .. "', unknown error." )
            return
        end

        local new_path = "/garrysmod/data/dreamwork/cache/workshop/" .. uuid_v7() .. ".gma"
        fs_write( new_path, file_class:Read( file_class:Size() ) )
        f:setResult( new_path )
    end

    fs.makeDirectory( "/garrysmod/data/dreamwork/cache/workshop", true )

    --- [SHARED AND MENU]
    ---
    --- Downloads the item from the Steam Workshop.
    ---
    ---@param wsid string The workshop ID of the addon.
    ---@param timeout number The timeout in seconds, if `nil` then the default timeout will be used.
    ---@return string file_path The absolute path to the downloaded addon `.gma`.
    ---@async
    function workshop.download( wsid, timeout )
        local f = Future()

        local fn = glua_steamworks.DownloadUGC
        if fn == nil then
            f:setError( "failed to download addon '" .. wsid .. "', part of Steam Workshop API is missing." )
            return f:await()
        end

        fn( wsid, function( file_path, file_class )
            futures_run( perform_response, nil, f, wsid, file_path, file_class )
        end )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to download addon '" .. wsid .. "', timed out." )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        return f:await()
    end

end

do

    local math_max, math_clamp = std.math.max, std.math.clamp
    local table_insert = std.table.insert

    local type2type = {
        subscribed = "followed",
        friendfavorite = "friend_favs"
    }

    std.setmetatable( type2type, {
        __index = function( _, key )
            return key
        end
    } )

    --- [SHARED AND MENU]
    ---
    --- Performs a search for publications.
    ---
    ---@param params dreamwork.std.steam.workshop.Item.SearchParams The search parameters.
    ---@param timeout number The timeout in seconds, if `nil` then the default timeout will be used.
    ---@return string[] ids The IDs of the found publications.
    ---@return integer id_count The length of the `ids` array (`#ids`).
    ---@return integer total The total number of found publications.
    ---@async
    function workshop.search( params, timeout )
        local f = Future()

        glua_steamworks.GetList( type2type[ params.type or "latest" ], params.tags, math_max( 0, params.offset or 0 ), math_clamp( params.count or 50, 1, 50 ), math_clamp( params.days or 365, 1, 365 ), params.owned and "1" or (params.steamid64 or "0"), function( data )
            f:setResult( data )
        end )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to perform quick workshop search, timed out." )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        local data = f:await()

        local ids = data.results
        table_insert( ids, 1, ids[ 0 ] )
        ids[ 0 ] = nil

        return ids, data.numresults, data.totalresults
    end

    --- [SHARED AND MENU]
    ---
    --- Performs a quick search for publications.
    ---
    ---@param wtype dreamwork.std.steam.workshop.Item.SearchType The type of the search.
    ---@param wtags string[]? The tags of the search.
    ---@param woffset integer? The offset of the search.
    ---@param timeout number? The timeout in seconds of the search, if `nil` then the default timeout will be used.
    ---@return string[] items The found publications.
    ---@return integer item_count The length of the publications found array (`#publications`).
    ---@return integer total The total number of publications found.
    ---@async
    function workshop.qickSearch( wtype, wtags, woffset, timeout )
        local f = Future()

        ---@diagnostic disable-next-line: param-type-mismatch
        glua_steamworks.GetList( type2type[ wtype or "latest" ], wtags, math_max( 0, woffset or 0 ), 50, 365, "0", function( data )
            f:setResult( data )
        end )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to perform quick workshop search, timed out." )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        local data = f:await()

        local ids = data.results
        table_insert( ids, 1, ids[ 0 ] )
        ids[ 0 ] = nil

        return ids, data.numresults, data.totalresults
    end

    --- [SHARED AND MENU]
    ---
    --- Returns a list of publications published by the client.
    ---
    ---@param wtype dreamwork.std.steam.workshop.Item.SearchType The type of the search.
    ---@param wtags string[]? The tags of the search.
    ---@param woffset integer? The offset of the search.
    ---@param timeout number? The timeout in seconds of the search, if `nil` then the default timeout will be used.
    ---@return string[] ids The found publications IDs.
    ---@return integer item_count The length of the publications found array (`#publications`).
    ---@return integer total The total number of publications found.
    ---@async
    function workshop.getPublished( wtype, wtags, woffset, timeout )
        local f = Future()

        ---@diagnostic disable-next-line: param-type-mismatch
        glua_steamworks.GetList( type2type[ wtype or "latest" ], wtags, math_max( 0, woffset or 0 ), 50, 365, "1", function( data )
            f:setResult( data )
        end )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to perform quick workshop search, timed out." )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        local data = f:await()

        local ids = data.results
        table_insert( ids, 1, ids[ 0 ] )
        ids[ 0 ] = nil

        return ids, data.numresults, data.totalresults
    end

end

if std.LUA_MENU then

    local string_byte, string_sub = string.byte, string.sub
    local steamworks_Publish = glua_steamworks.Publish

    --- [MENU]
    ---
    --- Publishes file to Steam Workshop.
    ---
    ---@param filePath string The absolute path to the addon file.
    ---@param imagePath string The absolute path to the image file.
    ---@param title string The title of the addon.
    ---@param description string? The description of the addon.
    ---@param tags string[] The tags for the addon.
    ---@param changeLog string? The changelog of the publication.
    ---@param timeout number | nil | false The timeout in seconds, if `nil` then the default timeout will be used.
    ---@return string workshop_id The workshop ID of the published addon.
    ---@async
    function workshop.publishItem( filePath, imagePath, title, description, tags, changeLog, timeout )
        -- TODO: make table structure instead arguments
        local f = Future()

        if string_byte( filePath, 1 ) == 0x2F --[[ / ]] then
            filePath = string_sub( filePath, 2 )
        else
            error( "invalid file path '" .. filePath .. "', expected absolute path" )
        end

        steamworks_Publish( filePath, imagePath, title, description or "", tags, function( wsid, errorMsg )
            if isString( errorMsg ) then
                f:setError( errorMsg )
            else
                f:setResult( wsid )
            end
        end, nil, changeLog )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to publish addon, timed out" )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        return f:await()
    end

    --- [MENU]
    ---
    --- Updates an file on Steam Workshop.
    ---
    ---@param filePath string The absolute path to the addon file.
    ---@param imagePath string The absolute path to the image file.
    ---@param title string The title of the addon.
    ---@param description? string The description of the addon.
    ---@param tags string[] The tags for the addon.
    ---@param wsid string The workshop ID of the addon.
    ---@param changeLog string? The changelog of the publication.
    ---@param timeout number | nil | false The timeout in seconds, if `nil` then the default timeout will be used.
    ---@return boolean success `true` if the update was successful, `false` otherwise.
    ---@async
    function workshop.updateItem( filePath, imagePath, title, description, tags, wsid, changeLog, timeout )
        -- TODO: make table structure instead arguments
        local f = Future()

        if string_byte( filePath, 1 ) == 0x2F --[[ / ]] then
            filePath = string_sub( filePath, 2 )
        else
            error( "invalid file path '" .. filePath .. "', expected absolute path" )
        end

        steamworks_Publish( filePath, imagePath, title, description or "", tags, function( _, errorMsg )
            if isString( errorMsg ) then
                f:setError( errorMsg )
            else
                f:setResult( true )
            end
        end, tonumber( wsid, 10 ), changeLog )

        setTimeout( function()
            if f:isPending() then
                f:setError( "failed to update addon '" .. wsid .. "', timed out" )
            end

            ---@diagnostic disable-next-line: param-type-mismatch
        end, timeout or default_timeout.value )

        return f:await()
    end

end

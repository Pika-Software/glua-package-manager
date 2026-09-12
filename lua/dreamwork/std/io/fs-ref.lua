local _G = _G
local dreamwork = _G.dreamwork

local engine = dreamwork.engine

---@class dreamwork.std
local std = dreamwork.std

local futures = std.futures

local dreamwork_logger = dreamwork.Logger

local engine_hookCatch = engine.hookCatch
local engine_hookCall = engine.hookCall

local gc_setTableRules = std.gc.setTableRules
local debug_fempty = std.debug.fempty

local table = std.table
local table_concat = table.concat
local table_remove = table.remove

local string = std.string
local string_len = string.len
local string_byte = string.byte
local string_byteSplit = string.byteSplit
local string_containsByte = string.containsByte

local class = std.class

local time = std.time
local time_now = time.now

local raw = std.raw
local raw_index = raw.index

local path = std.path
local path_split = path.split
local path_resolve = path.resolve
local path_getExtension = path.getExtension

local LUA_CLIENT, LUA_SERVER, LUA_MENU = std.LUA_CLIENT, std.LUA_SERVER, std.LUA_MENU
local setmetatable = std.setmetatable
local tostring = std.tostring
local error = std.error

local Future = std.Future


local glua_file = _G.file
local file_Time = glua_file.Time
local file_Find = glua_file.Find
local file_Size = glua_file.Size
local file_Open = glua_file.Open
local file_IsDir = glua_file.IsDir
local file_Exists = glua_file.Exists
local file_Delete = glua_file.Delete
local file_CreateDir = glua_file.CreateDir


local FILE = std.debug.findmetatable( "File" )
---@cast FILE File

local FILE_Read, FILE_Write = FILE.Read, FILE.Write
local FILE_Close = FILE.Close
local FILE_Size = FILE.Size


---@type table<string, boolean>
local reserved_names = {
    [ "^dreamwork_tmp$.dat" ] = true,
    [ ".." ] = true,
    [ "." ] = true,
    [ "" ] = true
}

local mount_infos = {
}

local async_read, async_write, async_append

---@class dreamwork.std.fs.WriteRespond
---@field status integer
---@field file_path string
---@field game_path string

---@class dreamwork.std.fs.ReadRespond : dreamwork.std.fs.WriteRespond
---@field data string | nil

---@alias async_read_callback fun( file_path: string, game_path: string, status: integer, data: string )

if std.lookupbinary( "asyncio" ) and file.AsyncRead ~= nil and file.AsyncWrite ~= nil and file.AsyncAppend ~= nil then

    local timer = _G.timer
    local timer_Create = timer.Create

    ---@param identifier string
    ---@param delay number
    ---@param repetitions integer
    ---@param event_fn function
    ---@diagnostic disable-next-line: duplicate-set-field
    function timer.Create( identifier, delay, repetitions, event_fn )
        if identifier == "__ASYNCIO_THINK" then
            dreamwork_logger:debug( "Catched 'gm_asyncio' tick event %s, re-attaching to dreamwork engine...", event_fn )
            engine_hookCatch( "Tick", event_fn )
        else
            timer_Create( identifier, delay, repetitions, event_fn )
        end
    end

    if std.loadbinary( "asyncio" ) then

        ---@alias asyncio_write_callback fun( file_path: string, game_path: string, status: integer )

        ---@type fun( file_path: string, game_path: string, callback: async_read_callback ): integer
        local file_AsyncRead = file.AsyncRead

        ---@type fun( file_path: string, data: string, callback: asyncio_write_callback, game_path: string ): integer
        local file_AsyncWrite = file.AsyncWrite

        ---@type fun( file_path: string, data: string, callback: asyncio_write_callback, game_path: string ): integer
        local file_AsyncAppend = file.AsyncAppend

        ---@param file_path string
        ---@param game_path string
        ---@return dreamwork.std.Future future
        ---@async
        function async_read( file_path, game_path )
            local f = Future()

            local status = file_AsyncRead( file_path, game_path, function( _, __, status, data )
                if f:isFinished() then
                    return
                end

                ---@type dreamwork.std.fs.ReadRespond
                f:setResult( {
                    file_path = file_path,
                    game_path = game_path,
                    status = status,
                    data = data
                } )
            end )

            if status < 0 and not f:isFinished() then
                ---@type dreamwork.std.fs.ReadRespond
                f:setResult( {
                    file_path = file_path,
                    game_path = game_path,
                    status = status
                } )
            end

            return f
        end

        ---@param file_path string
        ---@param game_path string
        ---@param data string
        ---@return dreamwork.std.Future future
        ---@async
        function async_write( file_path, game_path, data )
            local f = Future()

            local status = file_AsyncWrite( file_path, data, function( _, __, status )
                if f:isFinished() then
                    return
                end

                ---@type dreamwork.std.fs.WriteRespond
                f:setResult( {
                    file_path = file_path,
                    game_path = game_path,
                    status = status
                } )
            end, game_path )

            if status < 0 and not f:isFinished() then
                ---@type dreamwork.std.fs.WriteRespond
                f:setResult( {
                    file_path = file_path,
                    game_path = game_path,
                    status = status
                } )
            end

            return f
        end

        ---@param file_path string
        ---@param game_path string
        ---@param data string
        ---@return dreamwork.std.Future future
        ---@async
        function async_append( file_path, game_path, data )
            local f = Future()

            local status = file_AsyncAppend( file_path, data, function( _, __, status )
                if f:isFinished() then
                    return
                end

                ---@type dreamwork.std.fs.WriteRespond
                f:setResult( {
                    file_path = file_path,
                    game_path = game_path,
                    status = status
                } )
            end, game_path )

            if status < 0 and not f:isFinished() then
                ---@type dreamwork.std.fs.WriteRespond
                f:setResult( {
                    file_path = file_path,
                    game_path = game_path,
                    status = status
                } )
            end

            return f
        end

        dreamwork_logger:info( "'asyncio' was loaded & connected as file system driver." )
    else
        dreamwork_logger:error( "'asyncio' failed to load, unknown error." )
    end

    timer.Create = timer_Create

end

if (async_write == nil or async_append == nil) and std.loadbinary( "async_write" ) and file.AsyncWrite ~= nil and file.AsyncAppend ~= nil then

    ---@alias async_write_write_callback fun( file_path: string, status: integer )

    ---@type fun( file_path: string, data: string, callback: async_write_write_callback, sync: boolean, game_path: string ): integer
    local file_AsyncWrite = file.AsyncWrite

    ---@type fun( file_path: string, data: string, callback: async_write_write_callback, sync: boolean, game_path: string ): integer
    local file_AsyncAppend = file.AsyncAppend

    ---@param file_path string
    ---@param game_path string
    ---@param data string
    ---@return dreamwork.std.Future future
    ---@async
    function async_write( file_path, game_path, data )
        local f = Future()

        local status = file_AsyncWrite( file_path, data, function( _, status )
            if f:isFinished() then
                return
            end

            ---@type dreamwork.std.fs.WriteRespond
            f:setResult( {
                file_path = file_path,
                game_path = game_path,
                status = status
            } )
        end, false, game_path )

        if status < 0 and not f:isFinished() then
            ---@type dreamwork.std.fs.WriteRespond
            f:setResult( {
                file_path = file_path,
                game_path = game_path,
                status = status
            } )
        end

        return f
    end

    ---@param file_path string
    ---@param game_path string
    ---@param data string
    ---@return dreamwork.std.Future future
    ---@async
    function async_append( file_path, game_path, data )
        local f = Future()

        local status = file_AsyncAppend( file_path, data, function( _, status )
            if f:isFinished() then
                return
            end

            ---@type dreamwork.std.fs.WriteRespond
            f:setResult( {
                file_path = file_path,
                game_path = game_path,
                status = status
            } )
        end, false, game_path )

        if status < 0 and not f:isFinished() then
            ---@type dreamwork.std.fs.WriteRespond
            f:setResult( {
                file_path = file_path,
                game_path = game_path,
                status = status
            } )
        end

        return f
    end

    dreamwork_logger:info( "'async_write' was loaded & connected as file system driver." )

end

if async_read == nil and not LUA_MENU and file.AsyncRead ~= nil then

    ---@type fun( file_path: string, game_path: string, callback: async_read_callback, sync: boolean ): integer
    local file_AsyncRead = file.AsyncRead

    ---@param file_path string
    ---@param game_path string
    ---@return dreamwork.std.Future future
    ---@async
    function async_read( file_path, game_path )
        local f = Future()

        local status = file_AsyncRead( file_path, game_path, function( _, __, status, data )
            if f:isFinished() then
                return
            end

            ---@type dreamwork.std.fs.ReadRespond
            f:setResult( {
                file_path = file_path,
                game_path = game_path,
                status = status,
                data = data
            } )
        end, false )

        if status < 0 and not f:isFinished() then
            ---@type dreamwork.std.fs.ReadRespond
            f:setResult( {
                file_path = file_path,
                game_path = game_path,
                status = status
            } )
        end

        return f
    end

end

if async_read == nil then

    ---@param file_path string
    ---@param game_path string
    ---@return dreamwork.std.Future future
    ---@async
    function async_read( file_path, game_path )
        ---@type dreamwork.std.fs.ReadRespond
        local respond = {
            file_path = file_path,
            game_path = game_path,
            status = 0
        }

        local handler = file_Open( file_path, "rb", game_path )
        if handler == nil then
            respond.status = -1
        else
            respond.data = FILE_Read( handler, FILE_Size( handler ) )
            FILE_Close( handler )
        end

        local f = Future()
        f:setResult( respond )
        return f
    end

end

if async_write == nil then

    ---@param file_path string
    ---@param game_path string
    ---@param data string
    ---@return dreamwork.std.Future future
    ---@async
    function async_write( file_path, game_path, data )
        ---@type dreamwork.std.fs.WriteRespond
        local respond = {
            file_path = file_path,
            game_path = game_path,
            status = 0
        }

        local handler = file_Open( file_path, "wb", game_path )
        if handler == nil then
            respond.status = -1
        else
            FILE_Write( handler, data )
            FILE_Close( handler )
        end

        local f = Future()
        f:setResult( respond )
        return f
    end

end

if async_append == nil then

    ---@param file_path string
    ---@param game_path string
    ---@param data string
    ---@return dreamwork.std.Future future
    ---@async
    function async_append( file_path, game_path, data )
        ---@type dreamwork.std.fs.WriteRespond
        local respond = {
            file_path = file_path,
            game_path = game_path,
            status = 0
        }

        local handler = file_Open( file_path, "ab", game_path )
        if handler == nil then
            respond.status = -1
        else
            FILE_Write( handler, data )
            FILE_Close( handler )
        end

        local f = Future()
        f:setResult( respond )
        return f
    end

end

local make_async_message
do

    ---@type table<integer, string>
    local status_messages = {
        [ -16 ] = "'{1}' {2} failed, unknown error.",
        [ -8 ]  = "'{1}' {2} failed, file name is not part of the file system; please try another one.",
        [ -7 ]  = "'{1}' {2} failed, please retry later. (network problems, etc)",
        [ -6 ]  = "'{1}' {2} failed, read parameters are invalid for unbuffered I/O.",
        [ -5 ]  = "'{1}' {2} failed, hard subsystem failure.",
        [ -4 ]  = "'{1}' {2} failed, read error on file.",
        [ -3 ]  = "'{1}' {2} failed, not enough memory.",
        [ -2 ]  = "'{1}' {2} failed, identifier provided by caller is not recognized.",
        [ -1 ]  = "'{1}' {2} failed, file could not be opened (bad path, not exist, etc).",
        [ 0 ]   = "'{1}' {2} was successfully completed.",
        [ 1 ]   = "'{1}' {2} has been properly queued and awaiting for service.",
        [ 2 ]   = "'{1}' {2} is being accessed.",
        [ 3 ]   = "'{1}' {2} has been interrupted by caller.",
        [ 4 ]   = "'{1}' {2} has not yet been queued."
    }

    local tmp = {}
    gc_setTableRules( tmp, false, true )

    ---@param status integer
    ---@param fs_object dreamwork.std.fs.Object
    ---@param is_writing boolean
    ---@return string
    function make_async_message( status, fs_object, is_writing )
        tmp[ 1 ] = tostring( fs_object )
        tmp[ 2 ] = is_writing and "writing" or "reading"
        return string.interpolate( status_messages[ status ] or status_messages[ -16 ], tmp )
    end

end

local make_watchdog_message
do

    local status_messages = {
        [ 1 ] = "File system object '{1}' created.",
        [ 2 ] = "File system object '{1}' deleted.",
        [ 3 ] = "File system object '{1}' modified.",

        [ -1 ] = "File system object '{1}' not found.",
        [ -2 ] = "File system object '{1}' not readable.",
        [ -3 ] = "File system object '{1}' out of scope.",
        [ -4 ] = "File system object '{1}' unavailable.",
        [ -5 ] = "File system object '{1}' already watched.",
        [ -6 ] = "File system object '{1}' unknown error.",
    }

    local tmp = {}
    gc_setTableRules( tmp, false, true )

    ---@param status integer
    ---@param fs_object dreamwork.std.fs.Object
    ---@return string message
    function make_watchdog_message( status, fs_object )
        tmp[ 1 ] = tostring( fs_object )
        return string.interpolate( status_messages[ status ] or status_messages[ -16 ], tmp )
    end

end

--- [SHARED AND MENU]
---
--- The high-level filesystem library.
---
--- The library provides access to the file system.
---
---@class dreamwork.std.fs
local fs = std.fs or {}
std.fs = fs

---@class dreamwork.std.fs.File : dreamwork.std.Object
---@field __class dreamwork.std.fs.FileClass
---@field name string The name of the file. **READ-ONLY**
---@field size integer The size of the file in bytes. **READ-ONLY**
---@field time integer The last modified time of the file. **READ-ONLY**
---@field path string The path to the file. **READ-ONLY**
---@field parent dreamwork.std.fs.Directory | nil The parent directory. **READ-ONLY**
local File = class.base( "File", true )

---@class dreamwork.std.fs.Directory : dreamwork.std.Object
---@field __class dreamwork.std.fs.DirectoryClass
---@field name string The name of the directory. **READ-ONLY**
---@field size integer The size of the directory in bytes. **READ-ONLY**
---@field time integer The last modified time of the directory. **READ-ONLY**
---@field path string The full path of the directory. **READ-ONLY**
---@field writable boolean If `true`, the directory is directly writable.
---@field parent dreamwork.std.fs.Directory | nil The parent directory. **READ-ONLY**
local Directory = class.base( "Directory", true )

---@class dreamwork.std.fs.FileClass : dreamwork.std.fs.File
---@field __base dreamwork.std.fs.File
---@overload fun( name: string, mount_point: string | nil, mount_path: string | nil ): dreamwork.std.fs.File
local FileClass = class.create( File )

---@class dreamwork.std.fs.DirectoryClass : dreamwork.std.fs.Directory
---@field __base dreamwork.std.fs.Directory
---@overload fun( name: string, mount_point: string | nil, mount_path: string | nil ): dreamwork.std.fs.Directory
local DirectoryClass = class.create( Directory )

---@diagnostic disable-next-line: duplicate-doc-alias
---@alias File dreamwork.std.fs.File
---@alias Directory dreamwork.std.fs.Directory
---@alias dreamwork.std.fs.Object dreamwork.std.fs.File | dreamwork.std.fs.Directory

---@type table<dreamwork.std.fs.Object, string>
local names = {}

do

    local raw_set = raw.set

    ---@type table<integer, boolean>
    local invalid_characters = {
        [ 0x22 ] = true, -- "
        [ 0x27 ] = true, -- '
        [ 0x2A ] = true, -- *
        [ 0x2F ] = true, -- /
        [ 0x5C ] = true, -- \
        [ 0x7C ] = true, -- |
        [ 0x7F ] = true, -- DEL
        [ 0x3A ] = true  -- :
    }

    -- Control characters
    for i = 0, 31, 1 do
        invalid_characters[ i ] = true
    end

    -- Non-printable characters
    for i = 59, 63, 1 do
        invalid_characters[ i ] = true
    end

    setmetatable( names, {
        __newindex = function( self, fs_object, name )
            for index = 1, string_len( name ), 1 do
                if invalid_characters[ string_byte( name, index, index ) ] then
                    std.errorf( 2, false, "directory or file name contains invalid character \\%X at index %d in '%s'", string_byte( name, index, index ), index, name )
                end
            end

            raw_set( self, fs_object, name )
        end,
        __mode = "k"
    } )

end

---@type table<dreamwork.std.fs.Object, string>
local paths = {}

setmetatable( paths, {
    ---@param fs_object dreamwork.std.fs.Object
    __index = function( self, fs_object )
        local name = names[ fs_object ]
        if name == nil then
            return nil
        end

        local object_path = "/" .. name
        self[ fs_object ] = object_path
        return object_path
    end,
    __mode = "k"
} )

---@type table<dreamwork.std.fs.Object, dreamwork.std.fs.Directory>
local parents = {}
-- gc_setTableRules( parents, true, false )

---@type table<dreamwork.std.fs.Directory, table<string | integer, dreamwork.std.fs.Object>>
local descendants = {}

setmetatable( descendants, {
    __index = function( self, fs_object )
        ---@type table<string | integer, dreamwork.std.fs.Object>
        local directory_children = {}
        self[ fs_object ] = directory_children
        return directory_children
    end,
    __mode = "k"
} )

---@type table<dreamwork.std.fs.Directory, integer>
local descendant_counts = {}

setmetatable( descendant_counts, {
    __index = function( self, fs_object )
        return 0
    end,
    __mode = "k"
} )

---@type table<dreamwork.std.fs.Object, integer>
local indexes = {}
gc_setTableRules( indexes, true, false )

---@type table<dreamwork.std.fs.Object, boolean>
local is_directory_object = {}
gc_setTableRules( is_directory_object, true, false )

---@type table<dreamwork.std.fs.Object, string>
local mount_points = {}
gc_setTableRules( mount_points, true, false )

---@type table<dreamwork.std.fs.Object, string>
local mount_paths = {}
gc_setTableRules( mount_paths, true, false )

---@type table<dreamwork.std.fs.Object, integer>
local sizes = {}

setmetatable( sizes, {
    ---@param fs_object dreamwork.std.fs.Object
    __index = function( self, fs_object )
        local object_size = 0

        local mount_point = mount_points[ fs_object ]
        if mount_point ~= nil and not is_directory_object[ fs_object ] then
            object_size = file_Size( mount_paths[ fs_object ], mount_point ) or object_size
        end

        self[ fs_object ] = object_size
        return object_size
    end,
    __mode = "k"
} )

---@type table<dreamwork.std.fs.Object, integer>
local modified_times = {}

setmetatable( modified_times, {
    ---@param fs_object dreamwork.std.fs.Object
    __index = function( self, fs_object )
        local object_time

        local mount_point = mount_points[ fs_object ]
        if mount_point == nil then
            object_time = time_now()
        else
            object_time = file_Time( mount_paths[ fs_object ], mount_point )
        end

        self[ fs_object ] = object_time
        return object_time
    end,
    __mode = "k"
} )

---@type table<dreamwork.std.fs.Object, dreamwork.std.Future[]>
local async_jobs = {}
gc_setTableRules( async_jobs, true, false )

---@type table<dreamwork.std.fs.Object, integer>
local async_job_counts = {}

setmetatable( async_job_counts, {
    __index = function()
        return 0
    end,
    __mode = "k"
} )

--- [SHARED AND MENU]
---
--- Registers a file or directory for asynchronous monitoring.
---
---@param fs_object dreamwork.std.fs.Object
---@param future dreamwork.std.Future
---@return boolean is_registered
local function async_job_register( fs_object, future )
    if future:isFinished() then
        return false
    end

    local job_count = async_job_counts[ fs_object ]

    if job_count == 0 then
        async_jobs[ fs_object ] = { [ 0 ] = Future() }
    end

    job_count = job_count + 1
    async_jobs[ fs_object ][ job_count ] = future

    async_job_counts[ fs_object ] = job_count

    local parent_directory = parents[ fs_object ]
    if parent_directory ~= nil then
        async_job_register( parent_directory, future )
    end

    return true
end

--- [SHARED AND MENU]
---
--- Unregisters a file or directory from asynchronous monitoring.
---
---@param fs_object dreamwork.std.fs.Object
---@param future dreamwork.std.Future
---@return boolean is_unregistered
local function async_job_unregister( fs_object, future )
    local job_count = async_job_counts[ fs_object ]
    if job_count == 0 then
        return false
    end

    local jobs = async_jobs[ fs_object ]

    for i = job_count, 1, -1 do
        if jobs[ i ] == future then
            table_remove( jobs, i )
            job_count = job_count - 1

            if job_count == 0 then
                jobs[ 0 ]:setResult()
                async_jobs[ fs_object ] = nil
                async_job_counts[ fs_object ] = nil
            else
                async_job_counts[ fs_object ] = job_count
            end

            local parent_directory = parents[ fs_object ]
            if parent_directory ~= nil then
                async_job_unregister( parent_directory, future )
            end

            return true
        end
    end

    return false
end

---@param fs_object dreamwork.std.fs.Object
---@return boolean is_busy
local function is_busy( fs_object )
    return async_job_counts[ fs_object ] ~= 0
end

---@param fs_object dreamwork.std.fs.Object
local function async_job_wait( fs_object )
    if is_busy( fs_object ) then
        async_jobs[ fs_object ][ 0 ]:await()
    end
end

---@param fs_object dreamwork.std.fs.Object
---@param parent_directory dreamwork.std.fs.Directory | nil
local function update_path( fs_object, parent_directory )
    if parent_directory == nil then
        paths[ fs_object ] = "/" .. names[ fs_object ]
    else

        local parent_path = paths[ parent_directory ]

        local uint8_1, uint8_2 = string_byte( parent_path, 1, 2 )
        if uint8_1 == 0x2F --[[ / ]] and uint8_2 == nil then
            paths[ fs_object ] = parent_path .. names[ fs_object ]
        else
            paths[ fs_object ] = parent_path .. "/" .. names[ fs_object ]
        end

    end

    if is_directory_object[ fs_object ] then
        ---@cast fs_object dreamwork.std.fs.Directory

        local descendant_list = descendants[ fs_object ]
        for i = 1, descendant_counts[ fs_object ], 1 do
            update_path( descendant_list[ i ], fs_object )
        end
    end
end

---@param parent_directory dreamwork.std.fs.Directory
---@param name string
local function abs_path( parent_directory, name )
    local directory_path = paths[ parent_directory ]

    local uint8_1, uint8_2 = string_byte( directory_path, 1, 2 )
    if uint8_1 == 0x2F --[[ / ]] and uint8_2 == nil then
        return directory_path .. name
    else
        return directory_path .. "/" .. name
    end
end

---@param parent_directory dreamwork.std.fs.Directory
---@param name string
local function rel_path( parent_directory, name )
    local mount_path = mount_paths[ parent_directory ]
    if mount_path == nil or string_byte( mount_path, 1, 1 ) == nil then
        return name
    else
        return mount_path .. "/" .. name
    end
end

---@param directory_object dreamwork.std.fs.Directory
---@param byte_count integer
local function size_add( directory_object, byte_count )
    while directory_object ~= nil do
        sizes[ directory_object ] = sizes[ directory_object ] + byte_count
        directory_object = parents[ directory_object ]
    end
end

---@param parent_directory dreamwork.std.fs.Directory
---@param descendant dreamwork.std.fs.Object
local function insert( parent_directory, descendant )
    if is_directory_object[ descendant ] == nil then
        error( "new descendant must be a File or a Directory", 2 )
    end

    local name = names[ descendant ]
    local descendants_table = descendants[ parent_directory ]

    local previous = descendants_table[ name ]
    if previous ~= nil then
        if previous == descendant then
            return
        else
            error( "file or directory with the same name already exists", 2 )
        end
    end

    local directory_object = parent_directory
    while directory_object ~= nil do
        if directory_object == descendant then
            error( "descendant directory cannot be parent", 2 )
        end

        directory_object = parents[ directory_object ]
    end

    parents[ descendant ] = parent_directory

    local index = descendant_counts[ parent_directory ] + 1
    descendant_counts[ parent_directory ] = index

    indexes[ descendant ] = index

    descendants_table[ index ] = descendant
    descendants_table[ name ] = descendant

    update_path( descendant, parent_directory )

    modified_times[ parent_directory ] = nil
    size_add( parent_directory, sizes[ descendant ] )
end

---@param parent_directory dreamwork.std.fs.Directory
---@param name string
local function eject( parent_directory, name )
    local descendants_table = descendants[ parent_directory ]

    local descendant = descendants_table[ name ]
    if descendant == nil then
        return
    end

    size_add( parent_directory, -sizes[ descendant ] )

    if mount_points[ descendant ] == nil then
        modified_times[ parent_directory ] = time_now()
    else
        modified_times[ parent_directory ] = nil
    end

    update_path( descendant, nil )

    descendants_table[ name ] = nil
    table_remove( descendants_table, indexes[ descendant ] )

    indexes[ descendant ] = nil

    descendant_counts[ parent_directory ] = descendant_counts[ parent_directory ] - 1

    parents[ descendant ] = nil
end

---@param directory_object dreamwork.std.fs.Directory
---@param name string
---@param is_exists? boolean
---@param is_directory? boolean
---@param mount_point? string
---@param mount_path? string
---@return dreamwork.std.fs.Object | nil fs_object
---@return boolean is_directory
local function directory_get( directory_object, name, is_exists, is_directory, mount_point, mount_path )
    if reserved_names[ name ] then
        return nil, false
    end

    local fs_object = descendants[ directory_object ][ name ]
    if fs_object ~= nil then
        return fs_object, is_directory_object[ fs_object ]
    end

    if mount_point == nil then
        mount_point = mount_points[ directory_object ]
    end

    if mount_point == nil then
        return nil, false
    end

    if mount_path == nil then
        mount_path = rel_path( directory_object, name )
    end

    if is_exists == nil then
        is_exists = file_Exists( mount_path, mount_point )
    end

    if is_exists then
        if is_directory == nil then
            is_directory = file_IsDir( mount_path, mount_point )
        end

        if is_directory then
            fs_object = DirectoryClass( name, mount_point, mount_path )
        else
            fs_object = FileClass( name, mount_point, mount_path )
        end

        insert( directory_object, fs_object )

        return fs_object, is_directory
    end

    return nil, false
end

---@param directory_object dreamwork.std.fs.Directory
---@param path_to string
---@param start_position? integer
---@return dreamwork.std.fs.Object | nil fs_object
---@return boolean is_directory
local function directory_lookup( directory_object, path_to, start_position )
    local segments, segment_count = string_byteSplit( path_to, 0x2F --[[ / ]], start_position )

    if segment_count == 1 then
        local name = segments[ 1 ]

        local uint8_1, uint8_2 = string_byte( name, 1, 2 )
        if string_byte( name, 1, 1 ) == nil or (uint8_1 == 0x2E --[[ . ]] and uint8_2 == nil) then
            return directory_object, true
        end

        return directory_get( directory_object, name )
    end

    for i = 1, segment_count, 1 do
        local fs_object, is_directory = directory_get( directory_object, segments[ i ] )
        if i == segment_count then
            return fs_object, is_directory
        elseif is_directory then
            ---@cast fs_object dreamwork.std.fs.Directory
            directory_object = fs_object
        else
            break
        end
    end

    return nil, false
end

--- [SHARED AND MENU]
---
--- The watchdog module.
---
--- Used for files and directories monitoring. (File creation, deletion, modification, etc.)
---
---@class dreamwork.std.fs.watchdog
local watchdog = {}
fs.watchdog = watchdog

---@class dreamwork.std.fs.watchdog.ObjectInfo
---@field name string
---@field object dreamwork.std.fs.Object
---@field is_directory boolean
---@field parent dreamwork.std.fs.Directory
---@field mount_point string
---@field mount_path string
---@field modified_time integer

if std.loadbinary( "efsw" ) then

    local hook = _G.hook
    local hook_Add = hook.Add

    ---@param event_name string
    ---@param identifier string
    ---@param event_fn function
    ---@diagnostic disable-next-line: duplicate-set-field
    function hook.Add( event_name, identifier, event_fn )
        if event_name == "Think" and identifier == "__ESFW_THINK" then
            dreamwork_logger:debug( "Catched 'gm_efsw' tick event %s, re-attaching to dreamwork engine...", event_fn )
            engine_hookCatch( "Tick", event_fn )
        else
            hook_Add( event_name, identifier, event_fn )
        end
    end

    if std.loadbinary( "efsw" ) then
        dreamwork_logger:info( "'gm_efsw' was loaded & connected as file system watcher." )
    else
        dreamwork_logger:error( "'gm_efsw' failed to load, unknown error." )
    end

    hook.Add = hook_Add

    ---@type table<dreamwork.std.fs.Object, integer>
    local watch_ids = {}
    gc_setTableRules( watch_ids, true, false )

    ---@diagnostic disable-next-line: undefined-field
    local efsw = _G.efsw

    ---@type fun( file_path: string, game_path: string ): integer
    local efsw_watch = efsw ~= nil and efsw.Watch or debug_fempty

    ---@type fun( watch_id: integer )
    local efsw_unwatch = efsw ~= nil and efsw.Unwatch or debug_fempty

    --- [SHARED AND MENU]
    ---
    --- Starts monitoring a file or directory.
    ---
    ---@param fs_object dreamwork.std.fs.Object
    ---@return boolean success
    ---@return integer watch_id
    function watchdog.watch( fs_object )
        local watch_id = watch_ids[ fs_object ]
        if watch_id == nil then
            local mount_point = mount_points[ fs_object ]

            if mount_point == nil then
                return false, -3
            end

            watch_id = efsw_watch( mount_paths[ fs_object ], mount_point ) or -1

            if watch_id < 0 then
                return false, watch_id
            else
                watch_ids[ fs_object ] = watch_id
            end
        end

        return true, watch_id
    end

    --- [SHARED AND MENU]
    ---
    --- Stops monitoring a file or directory.
    ---
    ---@param fs_object dreamwork.std.fs.Object The file or directory to stop monitoring.
    ---@return boolean success `true` if the file or directory was successfully unwatched, `false` otherwise.
    function watchdog.unwatch( fs_object )
        local watch_id = watch_ids[ fs_object ]
        if watch_id == nil then
            return false
        end

        watch_ids[ fs_object ] = nil
        efsw_unwatch( watch_id )

        return true
    end

    --- [SHARED AND MENU]
    ---
    --- Checks if a file or directory is being watched.
    ---
    ---@param fs_object string
    ---@return boolean is_watched
    function watchdog.isWatched( fs_object )
        if watch_ids[ fs_object ] ~= nil then
            return true
        end

        local parent_directory = parents[ fs_object ]
        return parent_directory ~= nil and watch_ids[ parent_directory ] ~= nil
    end

    engine_hookCatch( "FileWatchEvent", function( action, watch_id, garrysmod_relative_path )
        if watch_id < 0 then
            return
        end

        local directory_path, file_name = path_split( "/garrysmod/" .. garrysmod_relative_path, false )

        local parent_directory = fs.lookup( directory_path )
        if parent_directory == nil then
            return
        end

        ---@cast parent_directory dreamwork.std.fs.Directory

        local fs_object, is_directory = directory_get( parent_directory, file_name )
        if fs_object == nil or reserved_names[ file_name ] then
            return
        end

        local mount_point = mount_points[ fs_object ]
        local mount_path = mount_paths[ fs_object ]


        ---@type dreamwork.std.fs.watchdog.ObjectInfo
        local watchdog_info = {
            name = file_name,
            object = fs_object,
            is_directory = is_directory,
            parent = parent_directory,
            mount_path = mount_path,
            mount_point = mount_point,
            modified_time = 0
        }

        if action == 2 then
            watchdog_info.modified_time = time_now()
            engine_hookCall( "FileSystemDeleted", watchdog_info )
            return
        end

        watchdog_info.modified_time = file_Time( mount_path, mount_point )

        if action == 1 then
            engine_hookCall( "FileSystemCreated", watchdog_info )
        elseif action == 3 then
            engine_hookCall( "FileSystemModified", watchdog_info )
        end
    end )

else

    ---@type table<dreamwork.std.fs.Object, integer>
    local watch_map = {}
    gc_setTableRules( watch_map, true, false )

    ---@type dreamwork.std.fs.Object[]
    local watch_list = {}
    gc_setTableRules( watch_list, false, true )

    ---@type integer
    local watch_list_size = 0

    ---@type table<dreamwork.std.fs.Directory, dreamwork.std.fs.Object[]>
    local content_lists = {}
    gc_setTableRules( content_lists, true, false )

    ---@type table<dreamwork.std.fs.Directory, integer>
    local content_counts = {}
    gc_setTableRules( content_counts, true, false )

    ---@type table<dreamwork.std.fs.Directory, table<string, dreamwork.std.fs.Object>>
    local content_maps = {}
    gc_setTableRules( content_maps, true, false )

    engine_hookCatch( "FileSystemCreated", function( watchdog_info )
        local parent_directory = watchdog_info.parent

        local content_list = content_lists[ parent_directory ]
        local content_map = content_maps[ parent_directory ]

        if content_list == nil or content_map == nil then
            return
        end

        local name = watchdog_info.name

        if content_map[ name ] == nil then
            local fs_object = watchdog_info.object
            content_map[ name ] = fs_object

            local content_length = content_counts[ parent_directory ] + 1
            content_list[ content_length ] = fs_object
            content_counts[ parent_directory ] = content_length
        end
    end )

    engine_hookCatch( "FileSystemDeleted", function( watchdog_info )
        local parent_directory = watchdog_info.parent

        local content_map = content_maps[ parent_directory ]
        if content_map ~= nil then
            content_map[ watchdog_info.name ] = nil
        end

        local content_list = content_lists[ parent_directory ]
        if content_list ~= nil then
            local content_length = content_counts[ parent_directory ] or 0
            local fs_object = watchdog_info.object

            for i = content_length, 1, -1 do
                if content_list[ i ] == fs_object then
                    table_remove( content_list, i )
                    content_counts[ parent_directory ] = content_length - 1
                    break
                end
            end
        end
    end )

    --- [SHARED AND MENU]
    ---
    --- Starts monitoring a file or directory.
    ---
    ---@param fs_object dreamwork.std.fs.Object
    ---@return boolean success
    ---@return integer watch_id
    function watchdog.watch( fs_object )
        local watch_id = watch_map[ fs_object ]
        if watch_id ~= nil then
            return true, watch_id
        end

        if reserved_names[ names[ fs_object ] ] then
            return false, -4
        end

        local mount_point = mount_points[ fs_object ]
        if mount_point == nil then
            return false, -3
        end

        local mount_path = mount_paths[ fs_object ]

        if not file_Exists( mount_path, mount_point ) then
            return false, -1
        end

        if is_directory_object[ fs_object ] then

            ---@cast fs_object dreamwork.std.fs.Directory

            ---@type dreamwork.std.fs.Object[]
            local content_list = {}

            ---@type table<string, dreamwork.std.fs.Object>
            local content_map = {}
            gc_setTableRules( content_map, false, true )

            ---@type integer
            local content_count = content_counts[ fs_object ] or 0

            fs_object:scan( false, false )

            ---@type dreamwork.std.fs.Object[]
            local fs_files, fs_file_count,
            fs_dirs, fs_dir_count = fs_object:select()

            for i = 1, fs_file_count, 1 do
                local file_object = fs_files[ i ]

                local file_mount_point = mount_points[ file_object ]
                if file_mount_point ~= nil then
                    content_count = content_count + 1
                    content_list[ content_count ] = file_object
                    content_map[ names[ file_object ] ] = file_object

                    modified_times[ file_object ] = file_Time( mount_paths[ file_object ], file_mount_point )
                end
            end

            for i = 1, fs_dir_count, 1 do
                local directory_object = fs_dirs[ i ]

                local directory_mount_point = mount_points[ directory_object ]
                if directory_mount_point ~= nil then
                    content_count = content_count + 1
                    content_list[ content_count ] = directory_object
                    content_map[ names[ directory_object ] ] = directory_object

                    modified_times[ directory_object ] = file_Time( mount_paths[ directory_object ], directory_mount_point )
                end
            end

            content_maps[ fs_object ] = content_map
            content_lists[ fs_object ] = content_list
            content_counts[ fs_object ] = content_count

        end

        watch_list_size = watch_list_size + 1

        watch_list[ watch_list_size ] = fs_object
        watch_map[ fs_object ] = watch_list_size

        modified_times[ fs_object ] = file_Time( mount_path, mount_point )

        return true, watch_list_size
    end

    --- [SHARED AND MENU]
    ---
    --- Stops monitoring a file or directory.
    ---
    ---@param fs_object dreamwork.std.fs.Object The file or directory to stop monitoring.
    ---@return boolean success `true` if the file or directory was successfully unwatched, `false` otherwise.
    function watchdog.unwatch( fs_object )
        if watch_map[ fs_object ] == nil then
            return false
        end

        for i = watch_list_size, 1, -1 do
            if watch_list[ i ] == fs_object then
                table_remove( watch_list, i )
                watch_list_size = watch_list_size - 1
                break
            end
        end

        watch_map[ fs_object ] = nil

        return true
    end

    --- [SHARED AND MENU]
    ---
    --- Checks if a file or directory is being watched.
    ---
    ---@param fs_object dreamwork.std.fs.Object
    ---@return boolean is_watched
    function watchdog.isWatched( fs_object )
        if watch_map[ fs_object ] ~= nil then
            return true
        end

        local parent_directory = parents[ fs_object ]
        return parent_directory ~= nil and watch_map[ parent_directory ] ~= nil
    end

    ---@param dead_fs_object dreamwork.std.fs.Object
    engine_hookCatch( "FileSystemGarbageCollected", function( dead_fs_object )
        for i = watch_list_size, 1, -1 do
            local fs_object = watch_list[ i ]
            if fs_object == dead_fs_object then
                table_remove( watch_list, i )
                watch_list_size = watch_list_size - 1
            elseif is_directory_object[ fs_object ] then
                ---@cast fs_object dreamwork.std.fs.Directory

                local content_list = content_lists[ fs_object ]
                local content_length = content_counts[ fs_object ]

                if content_list ~= nil and content_length ~= nil then
                    for j = content_length, 1, -1 do
                        if content_list[ j ] == fs_object then
                            table_remove( content_list, j )
                            content_counts[ fs_object ] = content_length - 1
                            break
                        end
                    end
                end
            end
        end
    end, 1 )

    local coroutine = std.coroutine
    local coroutine_yield = coroutine.yield
    local coroutine_resume = coroutine.resume

    ---@param parent_directory dreamwork.std.fs.Directory
    ---@param name string
    ---@param is_directory boolean
    ---@param sub_mount_path string
    ---@param mount_point string
    local function watchdog_created_event( parent_directory, name, is_directory, mount_point, sub_mount_path )
        local mount_path = sub_mount_path .. name

        local file_object = directory_get( parent_directory, name, true, is_directory, mount_point, mount_path )
        if file_object ~= nil then
            ---@type dreamwork.std.fs.watchdog.ObjectInfo
            local watchdog_info = {
                name = name,
                object = file_object,
                is_directory = is_directory,
                parent = parent_directory,
                mount_path = mount_path,
                mount_point = mount_point,
                modified_time = file_Time( mount_path, mount_point )
            }

            engine_hookCall( "FileSystemCreated", watchdog_info )
        end
    end

    ---@param parent_directory dreamwork.std.fs.Directory
    ---@param sub_mount_path string
    ---@param mount_point string
    ---@param fs_object dreamwork.std.fs.Object
    ---@param fs_map table<string, boolean>
    local function watchdog_validate( parent_directory, sub_mount_path, mount_point, fs_object, fs_map )
        local name = names[ fs_object ]
        local mount_path = sub_mount_path .. name

        ---@type dreamwork.std.fs.watchdog.ObjectInfo
        local watchdog_info = {
            name = name,
            object = fs_object,
            is_directory = is_directory_object[ fs_object ],
            parent = parent_directory,
            mount_path = mount_path,
            mount_point = mount_point,
            modified_time = 0
        }

        if fs_map[ name ] == nil then
            engine_hookCall( "FileSystemDeleted", watchdog_info )
            return
        end

        local modified_time = file_Time( mount_path, mount_point )
        if modified_time == 0 then
            engine_hookCall( "FileSystemDeleted", watchdog_info )
        elseif modified_times[ fs_object ] ~= modified_time then
            watchdog_info.modified_time = modified_time
            engine_hookCall( "FileSystemModified", watchdog_info )
        end
    end

    ---@param fs_object dreamwork.std.fs.Object
    ---@async
    local function watchdog_update( fs_object )
        local mount_path, mount_point = mount_paths[ fs_object ], mount_points[ fs_object ]
        local is_directory = is_directory_object[ fs_object ]

        if not file_Exists( mount_path, mount_point ) then
            ---@type dreamwork.std.fs.watchdog.ObjectInfo
            local watchdog_info = {
                name = names[ fs_object ],
                object = fs_object,
                is_directory = is_directory,
                parent = parents[ fs_object ],
                mount_path = mount_path,
                mount_point = mount_point,
                modified_time = 0
            }

            engine_hookCall( "FileSystemDeleted", watchdog_info )
            return
        end

        local object_modified_time = file_Time( mount_path, mount_point )
        if object_modified_time ~= modified_times[ fs_object ] then
            ---@type dreamwork.std.fs.watchdog.ObjectInfo
            local watchdog_info = {
                name = names[ fs_object ],
                object = fs_object,
                is_directory = is_directory,
                parent = parents[ fs_object ],
                mount_path = mount_path,
                mount_point = mount_point,
                modified_time = object_modified_time
            }

            engine_hookCall( "FileSystemModified", watchdog_info )
        end

        if is_directory then
            coroutine_yield()

            ---@cast fs_object dreamwork.std.fs.Directory

            if string_byte( mount_path, 1, 1 ) ~= nil then
                mount_path = mount_path .. "/"
            end

            local fs_files, fs_directories = file_Find( mount_path .. "*", mount_point )
            coroutine_yield()

            local content_map = content_maps[ fs_object ]
            local fs_map = {}

            -- Checking for new files
            for i = 1, #fs_files, 1 do
                local file_name = fs_files[ i ]

                if content_map[ file_name ] == nil then
                    watchdog_created_event( fs_object, file_name, false, mount_point, mount_path )
                end

                fs_map[ file_name ] = true
            end

            -- Checking for new directories
            for i = 1, #fs_directories, 1 do
                local directory_name = fs_directories[ i ]

                if content_map[ directory_name ] == nil then
                    watchdog_created_event( fs_object, directory_name, true, mount_point, mount_path )
                end

                fs_map[ directory_name ] = true
            end

            -- Validating already existing files and directories
            local content_list = content_lists[ fs_object ]

            for i = content_counts[ fs_object ], 1, -1 do
                watchdog_validate( fs_object, mount_path, mount_point, content_list[ i ], fs_map )
                coroutine_yield()
            end
        end
    end

    ---@type integer
    local pointer = 1

    ---@async
    local watchdog_thread = coroutine.create( function()
        ::watchdog_update::
        watchdog_update( watch_list[ pointer ] )

        if pointer == watch_list_size then
            pointer = 1
        else
            pointer = pointer + 1
        end

        coroutine_yield()
        goto watchdog_update
    end )

    engine_hookCatch( "Tick", function()
        if watch_list_size == 0 then return end

        coroutine_resume( watchdog_thread )
    end )

    dreamwork_logger:info( "'dreamwork' was connected as file system watcher." )

end

engine_hookCatch( "FileSystemGarbageCollected", watchdog.unwatch )

---@param file_object dreamwork.std.fs.File
---@param stack_level integer
---@async
local function delete_file( file_object, stack_level )
    stack_level = stack_level + 1

    local mount_point = mount_points[ file_object ]
    if mount_point == nil then
        std.errorf( stack_level, false, "'%s' cannot be deleted, file is not mounted.", file_object )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.deletable then
        std.errorf( stack_level, false, "'%s' cannot be deleted, parent directory is not allowing file deletion.", file_object )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    async_job_wait( file_object )

    local parent_directory = parents[ file_object ]
    if parent_directory == nil then
        std.errorf( stack_level, false, "'%s' cannot be deleted, file already deleted.", paths[ file_object ] )
    end

    ---@cast parent_directory dreamwork.std.fs.Directory

    local mount_path = mount_paths[ file_object ]
    local file_name = names[ file_object ]

    file_Delete( mount_path, mount_point )
    -- eject( parent_directory, file_name )

    local directory_mount_path, directory_mount_point = mount_paths[ parent_directory ], mount_points[ parent_directory ]
    local modified_time = file_Time( directory_mount_path, directory_mount_point )

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local file_watchdog_info = {
        name = file_name,
        object = file_object,
        is_directory = false,
        parent = parent_directory,
        mount_path = mount_path,
        mount_point = mount_point,
        modified_time = modified_time
    }

    engine_hookCall( "FileSystemDeleted", file_watchdog_info )

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local directory_watchdog_info = {
        name = names[ parent_directory ],
        object = parent_directory,
        is_directory = true,
        parent = parents[ parent_directory ],
        mount_path = directory_mount_path,
        mount_point = directory_mount_point,
        modified_time = modified_time
    }

    engine_hookCall( "FileSystemModified", directory_watchdog_info )
end

---@param directory_object dreamwork.std.fs.Directory
---@param recursive boolean
---@param stack_level integer
---@async
local function delete_directory( directory_object, recursive, stack_level )
    stack_level = stack_level + 1

    async_job_wait( directory_object )

    local mount_point = mount_points[ directory_object ]
    if mount_point == nil then
        std.errorf( stack_level, false, "'%s' cannot be deleted, directory is not mounted.", directory_object )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.deletable then
        std.errorf( stack_level, false, "'%s' cannot be deleted, parent directory is not allowing directory deletion.", directory_object )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    local mount_path = mount_paths[ directory_object ]

    if not (file_Exists( mount_path, mount_point ) and file_IsDir( mount_path, mount_point )) then
        return
    end

    if recursive then

        local files, file_count,
        directories, directory_count = directory_object:select()

        for i = 1, directory_count, 1 do
            delete_directory( directories[ i ], recursive, stack_level )
        end

        for i = 1, file_count, 1 do
            delete_file( files[ i ], stack_level )
        end

    else

        directory_object:scan( false, false )

        local file_count, directory_count = directory_object:count()
        if file_count ~= 0 or directory_count ~= 0 then
            std.errorf( stack_level, false, "'%s' cannot be deleted, directory is not empty.", paths[ directory_object ] )
        end

    end

    async_job_wait( directory_object )

    local parent_directory = parents[ directory_object ]
    if parent_directory == nil then
        std.errorf( stack_level, false, "'%s' cannot be deleted, directory is root or already deleted.", paths[ directory_object ] )
    end

    ---@cast parent_directory dreamwork.std.fs.Directory

    local directory_name = names[ directory_object ]

    file_Delete( mount_path, mount_point )
    -- eject( parent_directory, directory_name )

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local watchdog_info = {
        name = directory_name,
        object = directory_object,
        is_directory = true,
        parent = parent_directory,
        mount_path = mount_path,
        mount_point = mount_point,
        modified_time = time_now()
    }

    engine_hookCall( "FileSystemDeleted", watchdog_info )
end

-- TODO: rework delete/create/modify events for watchdog to work properly with manual deletion

---@param parent_directory dreamwork.std.fs.Directory
---@param directory_name string
---@param forced boolean
---@param stack_level integer
---@return dreamwork.std.fs.Directory new_directory
---@async
local function make_directory( parent_directory, directory_name, forced, stack_level )
    stack_level = stack_level + 1

    if reserved_names[ directory_name ] then
        std.errorf( stack_level, false, "Directory cannot be created with reserved name '%s'.", directory_name )
    end

    local fs_object, is_directory = directory_get( parent_directory, directory_name )
    if fs_object ~= nil then
        if is_directory then
            ---@cast fs_object dreamwork.std.fs.Directory
            return fs_object
        elseif forced then
            ---@cast fs_object dreamwork.std.fs.File
            fs_object:delete()
        else
            std.errorf( stack_level, false, "Directory cannot be created with name '%s', '%s' already exists.", directory_name, fs_object )
        end
    end

    local mount_point = mount_points[ parent_directory ]
    if mount_point == nil then
        std.errorf( stack_level, false, "'%s' won't allow directory creation, directory is not mounted.", parent_directory )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.writable then
        std.errorf( stack_level, false, "'%s' won't allow directory creation, parent directory is not writable.", parent_directory )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    local mount_path = rel_path( parent_directory, directory_name )

    ---@diagnostic disable-next-line: redundant-parameter
    file_CreateDir( mount_path, mount_point )

    local directory_object = DirectoryClass( directory_name, mount_point, mount_path )
    insert( parent_directory, directory_object )

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local watchdog_info = {
        name = directory_name,
        object = directory_object,
        is_directory = true,
        parent = parent_directory,
        mount_path = mount_path,
        mount_point = mount_point,
        modified_time = file_Time( mount_path, mount_point )
    }

    engine_hookCall( "FileSystemCreated", watchdog_info )

    return directory_object
end

---@param parent_directory dreamwork.std.fs.Directory
---@param file_name string
---@param forced boolean
---@param stack_level integer
---@param data string
---@return dreamwork.std.fs.File
---@async
local function make_file( parent_directory, file_name, forced, stack_level, data )
    stack_level = stack_level + 1

    if reserved_names[ file_name ] then
        std.errorf( stack_level, false, "File cannot be created with reserved name '%s'.", file_name )
    end

    local mount_point = mount_points[ parent_directory ]
    if mount_point == nil then
        std.errorf( stack_level, false, "'%s' won't allow file creation, directory is not mounted.", parent_directory )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil then
        std.errorf( stack_level, false, "'%s' won't allow file creation, parent directory is not writable.", parent_directory )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    if not mount_info.writable_extensions[ path_getExtension( file_name, false ) ] then
        std.errorf( stack_level, false, "'%s' won't allow file creation with name '%s', parent directory is not allowing this extension.", parent_directory, file_name )
    end

    local mount_path = rel_path( parent_directory, file_name )

    local fs_object, is_directory = directory_get( parent_directory, file_name, nil, nil, mount_point, mount_path )
    if fs_object ~= nil then
        if is_directory then
            if forced then
                ---@cast fs_object dreamwork.std.fs.Directory
                fs_object:delete( true )
            else
                std.errorf( stack_level, false, "File cannot be created with name '%s', '%s' already exists.", file_name, fs_object )
            end
        else
            ---@cast fs_object dreamwork.std.fs.File
            return fs_object
        end
    end

    local file_object = FileClass( file_name, mount_point, mount_path )
    insert( parent_directory, file_object )

    file_object:write( data )

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local file_watchdog_info = {
        name = file_name,
        object = file_object,
        is_directory = false,
        parent = parent_directory,
        mount_path = mount_path,
        mount_point = mount_point,
        modified_time = file_Time( mount_path, mount_point )
    }

    engine_hookCall( "FileSystemCreated", file_watchdog_info )

    local directory_mount_path, directory_mount_point = mount_paths[ parent_directory ], mount_points[ parent_directory ]

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local directory_watchdog_info = {
        name = names[ parent_directory ],
        object = parent_directory,
        is_directory = true,
        parent = parents[ parent_directory ],
        mount_path = directory_mount_path,
        mount_point = directory_mount_point,
        modified_time = file_Time( directory_mount_path, directory_mount_point )
    }

    engine_hookCall( "FileSystemModified", directory_watchdog_info )

    return file_object
end

---@param directory_object dreamwork.std.fs.Directory
---@param lookup_path string
---@param forced boolean
---@param stack_level integer
---@param start_position integer
---@return dreamwork.std.fs.Directory directory_object
---@async
local function make_directory_chain( directory_object, lookup_path, forced, start_position, stack_level )
    local segments, segment_count = string_byteSplit( lookup_path, 0x2F --[[ / ]], start_position )
    stack_level = stack_level + 1

    for i = 1, segment_count, 1 do
        directory_object = make_directory( directory_object, segments[ i ], forced, stack_level )
    end

    return directory_object
end

---@param directory_object dreamwork.std.fs.Directory
---@param file_path string
---@param forced boolean
---@param stack_level integer
---@param start_position integer
---@param data string
---@async
local function make_file_chain( directory_object, file_path, forced, start_position, stack_level, data )
    local segments, segment_count = string_byteSplit( file_path, 0x2F --[[ / ]], start_position )
    stack_level = stack_level + 1

    for i = 1, segment_count - 1, 1 do
        directory_object = make_directory( directory_object, segments[ i ], forced, stack_level )
    end

    return make_file( directory_object, segments[ segment_count ], forced, stack_level, data )
end

---@protected
function File:__gc()
    engine_hookCall( "FileSystemGarbageCollected", self, false )
end

---@protected
---@param name string
---@param mount_point string | nil
---@param mount_path string | nil
function File:__init( name, mount_point, mount_path )
    names[ self ] = name
    mount_paths[ self ] = mount_path
    mount_points[ self ] = mount_point
    is_directory_object[ self ] = false

    -- TODO: internal where is perform
end

---@protected
---@param key string
---@return any
function File:__index( key )
    if key == "name" then
        return names[ self ]
    elseif key == "size" then
        return sizes[ self ]
    elseif key == "time" then
        return modified_times[ self ]
    elseif key == "path" then
        return paths[ self ]
    elseif key == "parent" then
        return parents[ self ]
    else
        return raw_index( File, key )
    end
end

---@protected
---@return string
function File:__tostring()
    return string.format( "File: %p [%s]", self, self.path )
end

--- [SHARED AND MENU]
---
--- Checks if file is busy by async operations.
---
---@return boolean is_busy `true` if file is busy, otherwise `false`.
function File:isBusy()
    return async_job_counts[ self ] ~= 0
end

--- [SHARED AND MENU]
---
--- Checks if file is empty or not.
---
--- **Basically checks if file size is 0.**
---
---@return boolean is_empty `true` if file is empty, otherwise `false`.
function File:isEmpty()
    return sizes[ self ] == 0
end

--- [SHARED AND MENU]
---
--- Touches file and sets its last modification time to the current time.
---
---@return integer new_time The new last modification time of file.
---@async
function File:touch()
    local mount_point = mount_points[ self ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be touched, parent directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.writable then
        std.errorf( 2, false, "'%s' cannot be touched, parent directory is not allowing file writing.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    local file_name = names[ self ]
    if not mount_info.writable_extensions[ path_getExtension( file_name, false ) ] then
        std.errorf( 2, false, "'%s' cannot be touched with its name, parent directory is not allowing this extension.", self )
    end

    self:write( self:read() )

    local mount_path = mount_paths[ self ]
    local modified_time = file_Time( mount_path, mount_point )
    -- modified_times[ self ] = modified_time

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local watchdog_info = {
        name = file_name,
        object = self,
        is_directory = false,
        parent = parents[ self ],
        mount_path = mount_path,
        mount_point = mount_point,
        modified_time = modified_time
    }

    engine_hookCall( "FileSystemModified", watchdog_info )

    return modified_time
end

--- [SHARED AND MENU]
---
--- Returns data of the file by given path.
---
---@return string data The file data.
---@async
function File:read()
    local f = async_read( mount_paths[ self ], mount_points[ self ] )
    local is_registered = async_job_register( self, f )

    ---@type dreamwork.std.fs.ReadRespond
    local respond = f:await()

    if is_registered then
        async_job_unregister( self, f )
    end

    if respond.status ~= 0 then
        error( make_async_message( respond.status, self, false ), 2 )
    end

    return respond.data
end

--- [SHARED AND MENU]
---
--- Replaces whole file data with specified.
---
---@param data string The new data to replace with.
---@async
function File:write( data )
    local mount_point = mount_points[ self ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be writen, parent directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.writable then
        std.errorf( 2, false, "'%s' cannot be writen, parent directory is not allowing file writing.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    if not mount_info.writable_extensions[ path_getExtension( names[ self ], false ) ] then
        std.errorf( 2, false, "'%s' cannot be writen with its name, parent directory is not allowing this extension.", self )
    end

    local mount_path = mount_paths[ self ]

    local f = async_write( mount_path, mount_point, data )
    local is_registered = async_job_register( self, f )

    ---@type dreamwork.std.fs.WriteRespond
    local respond = f:await()

    if is_registered then
        async_job_unregister( self, f )
    end

    if respond.status ~= 0 then
        error( make_async_message( respond.status, self, true ), 2 )
    end

    local modified_time = file_Time( mount_path, mount_point )
    -- modified_times[ self ] = modified_time

    local new_size = string_len( data )

    local parent_directory = parents[ self ]
    size_add( parent_directory, -sizes[ self ] )
    size_add( parent_directory, new_size )

    sizes[ self ] = new_size

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local watchdog_info = {
        name = names[ self ],
        object = self,
        is_directory = false,
        parent = parent_directory,
        mount_path = mount_path,
        mount_point = mount_point,
        modified_time = modified_time
    }

    engine_hookCall( "FileSystemModified", watchdog_info )

    return respond
end

--- [SHARED AND MENU]
---
--- Appends data to the end of the file.
---
---@param data string The data to append.
---@async
function File:append( data )
    local mount_point = mount_points[ self ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be writen, parent directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.writable then
        std.errorf( 2, false, "'%s' cannot be writen, parent directory is not allowing file writing.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    if not mount_info.writable_extensions[ path_getExtension( names[ self ], false ) ] then
        std.errorf( 2, false, "'%s' cannot be writen with its name, parent directory is not allowing this extension.", self )
    end

    local mount_path = mount_paths[ self ]

    local f = async_append( mount_path, mount_point, data )
    local is_registered = async_job_register( self, f )

    ---@type dreamwork.std.fs.WriteRespond
    local respond = f:await()

    if is_registered then
        async_job_unregister( self, f )
    end

    if respond.status ~= 0 then
        error( make_async_message( respond.status, self, true ), 2 )
    end

    local modified_time = file_Time( mount_path, mount_point )
    -- modified_times[ self ] = modified_time

    local new_size = file_Size( mount_path, mount_point )

    local parent_directory = parents[ self ]
    size_add( parent_directory, -sizes[ self ] )
    size_add( parent_directory, new_size )

    sizes[ self ] = new_size

    ---@type dreamwork.std.fs.watchdog.ObjectInfo
    local watchdog_info = {
        name = names[ self ],
        object = self,
        is_directory = false,
        parent = parent_directory,
        mount_path = mount_path,
        mount_point = mount_point,
        modified_time = modified_time
    }

    engine_hookCall( "FileSystemModified", watchdog_info )

    return respond
end

--- [SHARED AND MENU]
---
--- Deletes the file from it's parent directory.
---
---@async
function File:delete()
    return delete_file( self, 2 )
end

--- [SHARED AND MENU]
---
--- Moves a file to another directory.
---
---@param directory_object dreamwork.std.fs.Directory The directory to move the file to.
---@param name? string The new name of the file. If `nil`, the original name will be used.
---@param forced? boolean If `true`, the file will be overwritten if it already exists.
---@return dreamwork.std.fs.File file_object The moved file.
---@async
function File:move( directory_object, name, forced )
    local mount_point_to = mount_points[ directory_object ]
    if mount_point_to == nil then
        std.errorf( 2, false, "'%s' cannot be moved, parent directory is not mounted.", self )
    end

    ---@cast mount_point_to string

    local mount_info_to = mount_infos[ mount_point_to ]
    if mount_info_to == nil or not mount_info_to.writable then
        std.errorf( 2, false, "'%s' cannot be moved, parent directory is not allowing file moving.", self )
    end

    ---@cast mount_info_to dreamwork.std.fs.MountInfo

    if name == nil then
        name = names[ self ]
    end

    if not mount_info_to.writable_extensions[ path_getExtension( name, false ) ] then
        std.errorf( 2, false, "'%s' cannot be moved with name '%s', parent directory is not allowing this extension.", self, name )
    end

    local parent_directory = parents[ self ]
    if parent_directory == nil then
        std.errorf( 2, false, "'%s' has no parent directory and cannot be moved.", self )
    end

    ---@cast parent_directory dreamwork.std.fs.Directory

    local data = self:read()
    async_job_wait( self )

    if parents[ self ] ~= parent_directory then
        std.errorf( 2, false, "'%s' has changed its location or been deleted, renaming failed.", self )
    end

    local mount_point_from = mount_points[ parent_directory ]
    if mount_point_from == nil then
        std.errorf( 2, false, "'%s' cannot be moved, parent directory is not mounted.", self )
    end

    ---@cast mount_point_from string

    local mount_info_from = mount_infos[ mount_point_from ]
    if mount_info_from == nil or not mount_info_from.deletable then
        std.errorf( 2, false, "'%s' cannot be moved, parent directory is not allowing file moving.", self )
    end

    ---@cast mount_info_from dreamwork.std.fs.MountInfo

    file_Delete( mount_paths[ self ], mount_point_from )
    eject( parent_directory, name )

    local mount_path = rel_path( directory_object, name )

    local fs_object, is_directory = directory_get( directory_object, name, nil, nil, mount_point_to, mount_path )
    if fs_object ~= nil then
        if is_directory then
            ---@cast fs_object dreamwork.std.fs.Directory
            fs_object:delete( forced )
        else
            ---@cast fs_object dreamwork.std.fs.File
            fs_object:delete()
        end
    end

    names[ self ] = name
    mount_paths[ self ] = mount_path
    mount_points[ self ] = mount_point_to

    insert( directory_object, self )

    self:write( data )

    return self
end

--- [SHARED AND MENU]
---
--- Renames the file to another name in it's parent directory.
---
---@param name string The new name of the file.
---@param forced? boolean If `true`, the file can be renamed to a name that already exists in the parent directory and old one will be deleted.
---@async
function File:rename( name, forced )
    local mount_point = mount_points[ self ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be renamed, parent directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not (mount_info.writable and mount_info.deletable) then
        std.errorf( 2, false, "'%s' cannot be renamed, parent directory is not allowing file renaming.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    if not mount_info.writable_extensions[ path_getExtension( name, false ) ] then
        std.errorf( 2, false, "'%s' cannot be renamed to '%s', parent directory is not allowing this extension.", self, name )
    end

    local parent_directory = parents[ self ]
    if parents[ self ] == nil then
        std.errorf( 2, false, "'%s' has no parent directory and cannot be renamed.", self )
    end

    ---@cast parent_directory dreamwork.std.fs.Directory

    local existing_object, is_directory = directory_get( parent_directory, name )
    if existing_object ~= nil then
        if forced then
            if is_directory then
                ---@cast existing_object dreamwork.std.fs.Directory
                existing_object:delete( forced )
            else
                ---@cast existing_object dreamwork.std.fs.File
                existing_object:delete()
            end
        else
            std.errorf( 2, false, "'%s' already exists in '%'. Use `forced=true` to overwrite it.", existing_object, parent_directory )
        end
    end

    ---@cast existing_object nil

    local data = self:read()
    async_job_wait( self )

    if parents[ self ] ~= parent_directory then
        std.errorf( 2, false, "'%s' has changed its location or been deleted, renaming failed.", self )
    end

    ---@cast parent_directory dreamwork.std.fs.Directory

    file_Delete( mount_paths[ self ], mount_point )
    mount_paths[ self ] = rel_path( parent_directory, name )

    names[ self ] = name
    update_path( self, parent_directory )

    self:write( data )
end

--- [SHARED AND MENU]
---
--- Copies file to another directory.
---
---@param directory_object dreamwork.std.fs.Directory The directory to copy the file to.
---@param name? string The new name of the file. If `nil`, the original name will be used.
---@param forced? boolean If `true`, the file can be copied to a name that already exists in the parent directory and old one will be deleted.
---@return dreamwork.std.fs.File file_object The copied file.
---@async
function File:copy( directory_object, name, forced )
    if name == nil then
        name = names[ self ]
    end

    local mount_point = mount_points[ directory_object ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be copied, parent directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.writable then
        std.errorf( 2, false, "'%s' cannot be copied, parent directory is not writable.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    if not mount_info.writable_extensions[ path_getExtension( name, false ) ] then
        std.errorf( 2, false, "'%s' cannot be copied with name '%s', parent directory is not allowing this extension.", self, name )
    end

    local mount_path = rel_path( directory_object, name )

    local fs_object, is_directory = directory_get( directory_object, name, nil, nil, mount_point, mount_path )
    if fs_object == nil then
        fs_object = FileClass( name, mount_point, mount_path )
        insert( directory_object, fs_object )
    elseif is_directory then
        ---@cast fs_object dreamwork.std.fs.Directory
        fs_object:delete( forced )
    end

    ---@cast fs_object dreamwork.std.fs.File
    fs_object:write( self:read() )
    return fs_object
end

do

    local handlers = {}

    -- TODO: Reader and Writer or something better like FileClass that can returns FileReader and FileWriter in cases

    function File:open()

    end

    function File:close()

    end

end

---@protected
function Directory:__gc()
    engine_hookCall( "FileSystemGarbageCollected", self, true )
end

---@param name string
---@param mount_point string
---@param mount_path string
---@protected
function Directory:__init( name, mount_point, mount_path )
    names[ self ] = name
    is_directory_object[ self ] = true
    mount_paths[ self ] = mount_path
    mount_points[ self ] = mount_point
    update_path( self, nil )

    -- TODO: internal where is perform
end

---@protected
---@param key string
---@return any
function Directory:__index( key )
    if key == "name" then
        return names[ self ]
    elseif key == "size" then
        return sizes[ self ]
    elseif key == "time" then
        return modified_times[ self ]
    elseif key == "path" then
        return paths[ self ]
    elseif key == "writable" then
        local mount_point = mount_points[ self ]
        if mount_point == nil then
            return false
        end

        local mount_info = mount_infos[ mount_point ]
        return mount_info ~= nil and mount_info.writable
    elseif key == "parent" then
        return parents[ self ]
    else
        return raw_index( Directory, key )
    end
end

---@protected
---@return string
function Directory:__tostring()
    return string.format( "Directory: %p [%s]", self, self.path )
end

--- [SHARED AND MENU]
---
--- Checks if directory is busy by async operations.
---
---@return boolean is_busy `true` if directory is busy, otherwise `false`.
function Directory:isBusy()
    return async_job_counts[ self ] ~= 0
end

---@param relative_path string
---@return dreamwork.std.fs.Object | nil fs_object
---@return boolean is_directory
function Directory:lookup( relative_path )
    return directory_lookup( self, relative_path, nil )
end

--- [SHARED AND MENU]
---
--- Gets a file or directory by name.
---
---@param name string The name of the file or directory to get.
---@return dreamwork.std.fs.Object | nil fs_object The file or directory.
---@return boolean is_directory `true` if the object is a directory, otherwise `false`.
function Directory:get( name )
    return directory_get( self, name )
end

do

    local path_wildcard = path.wildcard
    local string_match = string.match

    ---@param wildcard string | nil
    ---@return dreamwork.std.fs.File[], integer, dreamwork.std.fs.Directory[], integer
    function Directory:select( wildcard )
        if wildcard == nil then
            wildcard = "*"
        elseif string_containsByte( wildcard, 0x2F --[[ / ]] ) then
            error( "wildcard cannot contain '/'", 2 )
        end

        local descendants_table = descendants[ self ]

        local directories, directory_count = {}, 0
        local files, file_count = {}, 0

        if wildcard == "*" then

            for i = 1, descendant_counts[ self ], 1 do
                ---@type dreamwork.std.fs.Object
                local fs_object = descendants_table[ i ]
                if is_directory_object[ fs_object ] then
                    directory_count = directory_count + 1
                    directories[ directory_count ] = fs_object
                else
                    file_count = file_count + 1
                    files[ file_count ] = fs_object
                end
            end

        else

            local pattern = path_wildcard( wildcard, false )

            for i = 1, descendant_counts[ self ], 1 do
                ---@type dreamwork.std.fs.Object
                local fs_object = descendants_table[ i ]
                if string_match( names[ fs_object ], pattern ) ~= nil then
                    if is_directory_object[ fs_object ] then
                        directory_count = directory_count + 1
                        directories[ directory_count ] = fs_object
                    else
                        file_count = file_count + 1
                        files[ file_count ] = fs_object
                    end
                end
            end

        end

        local mount_point = mount_points[ self ]

        if mount_point == nil then
            return files, file_count,
                directories, directory_count
        end

        local mount_path = mount_paths[ self ]

        if string_byte( mount_path, 1, 1 ) ~= nil then
            mount_path = mount_path .. "/"
        end

        local fs_files, fs_directories = file_Find( mount_path .. wildcard, mount_point )

        for i = 1, #fs_files, 1 do
            local file_name = fs_files[ i ]
            if descendants_table[ file_name ] == nil and not reserved_names[ file_name ] then
                file_count = file_count + 1
                files[ file_count ] = directory_get( self, file_name, true, false, mount_point, mount_path .. file_name )
            end
        end

        for i = 1, #fs_directories, 1 do
            local directory_name = fs_directories[ i ]
            if descendants_table[ directory_name ] == nil and not reserved_names[ directory_name ] then
                directory_count = directory_count + 1
                directories[ directory_count ] = directory_get( self, directory_name, true, true, mount_point, mount_path .. directory_name )
            end
        end

        return files, file_count,
            directories, directory_count
    end

end

---@return integer, integer
function Directory:count()
    local file_count, directory_count = 0, 0
    local descendants_table = descendants[ self ]

    for i = 1, descendant_counts[ self ], 1 do
        if is_directory_object[ descendants_table[ i ] ] then
            directory_count = directory_count + 1
        else
            file_count = file_count + 1
        end
    end

    return file_count, directory_count
end

---@param deep_scan boolean
---@param full_update boolean
---@param on_new nil | fun( fs_object: dreamwork.std.fs.Object, is_directory: boolean )
---@param on_finish nil | fun( directory_object: dreamwork.std.fs.Directory )
function Directory:scan( deep_scan, full_update, on_new, on_finish )
    local mount_path, mount_point = mount_paths[ self ], mount_points[ self ]
    local descendant_count = descendant_counts[ self ]
    local descendants_table = descendants[ self ]

    if full_update and descendant_count ~= 0 then

        size_add( self, -sizes[ self ] )

        for i = 1, descendant_count, 1 do
            local descendant = descendants[ self ][ i ]
            if not is_directory_object[ descendant ] then
                local descendant_mount_point = mount_points[ descendant ]
                local size, unix_time

                if descendant_mount_point == nil then
                    size = sizes[ descendant ]
                    unix_time = modified_times[ descendant ]
                else
                    local descendant_mount_path = mount_paths[ descendant ]
                    size = file_Size( descendant_mount_path, descendant_mount_point )
                    unix_time = file_Time( descendant_mount_path, descendant_mount_point )
                end

                modified_times[ descendant ] = unix_time
                sizes[ descendant ] = size

                size_add( self, size )
            end
        end

        if mount_point == nil then
            modified_times[ self ] = time_now()
        else
            modified_times[ self ] = file_Time( mount_path, mount_point )
        end

    end

    if mount_point ~= nil then

        if string_byte( mount_path, 1, 1 ) ~= nil then
            mount_path = mount_path .. "/"
        end

        local fs_files, fs_directories = file_Find( mount_path .. "*", mount_point )

        for i = 1, #fs_files, 1 do
            local file_name = fs_files[ i ]
            if descendants_table[ file_name ] == nil and not reserved_names[ file_name ] then
                local file_object = FileClass( file_name, mount_point, mount_path .. file_name )

                insert( self, file_object )

                if on_new ~= nil then
                    on_new( file_object, false )
                end
            end
        end

        for i = 1, #fs_directories, 1 do
            local directory_name = fs_directories[ i ]
            if descendants_table[ directory_name ] == nil and not reserved_names[ directory_name ] then
                local directory_object = DirectoryClass( directory_name, mount_point, mount_path .. directory_name )

                insert( self, directory_object )

                if on_new ~= nil then
                    on_new( directory_object, true )
                end
            end
        end

    end

    if on_finish ~= nil then
        on_finish( self )
    end

    if deep_scan then
        for i = 1, descendant_count, 1 do
            local directory_object = descendants_table[ i ]
            if is_directory_object[ directory_object ] then
                ---@cast directory_object dreamwork.std.fs.Directory
                directory_object:scan( deep_scan, full_update, on_new, on_finish )
            end
        end
    end
end

---@return boolean
function Directory:isEmpty()
    local file_count, directory_count = self:count()
    return file_count == 0 and directory_count == 0
end

---@param file_callback nil | fun( file: dreamwork.std.fs.File )
---@param directory_callback nil | fun( directory_object: dreamwork.std.fs.Directory )
function Directory:foreach( file_callback, directory_callback )
    local files, file_count,
    directories, directory_count = self:select()

    if file_callback == nil then
        if directory_callback == nil then
            return
        end
    else
        for i = 1, file_count, 1 do
            ---@type dreamwork.std.fs.File
            ---@diagnostic disable-next-line: param-type-mismatch
            file_callback( files[ i ] )
        end
    end

    for i = 1, directory_count, 1 do
        ---@type dreamwork.std.fs.Directory
        ---@diagnostic disable-next-line: assign-type-mismatch
        local directory_object = directories[ i ]

        if directory_callback ~= nil then
            directory_callback( directory_object )
        end

        directory_object:foreach( file_callback, directory_callback )
    end
end

--- [SHARED AND MENU]
---
--- Creates a file in the directory.
---
---@param file_name string The name of the file.
---@param forced? boolean If `true`, the file will be overwritten if it already exists.
---@return dreamwork.std.fs.File file_object The created file.
---@async
function Directory:makeFile( file_name, forced )
    return make_file( self, file_name, forced == true, 2, "" )
end

--- [SHARED AND MENU]
---
--- Creates a directory in the directory.
---
---@param directory_name string The name of the directory.
---@param forced? boolean If `true`, the directory will be overwritten if it already exists.
---@return dreamwork.std.fs.Directory directory_object The created directory.
---@async
function Directory:makeDirectory( directory_name, forced )
    return make_directory( self, directory_name, forced == true, 2 )
end

--- [SHARED AND MENU]
---
--- Touches the directory and sets its last modification time to the current time.
---
---@return integer new_time The new last modification time of the directory.
function Directory:touch()
    local mount_point = mount_points[ self ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be touched, directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not (mount_info.writable and mount_info.deletable) then
        std.errorf( 2, false, "'%s' cannot be touched, directory is not available.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    local mount_path = rel_path( self, "^dreamwork_tmp$.dat" )

    local handler = file_Open( mount_path, "wb", mount_point )
    if handler == nil then
        std.errorf( 2, false, "'%s' cannot be touched, file handler is not available.", self )
    end

    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast handler File
    FILE_Close( handler )

    file_Delete( mount_path, mount_point )

    local new_time = file_Time( mount_paths[ self ], mount_point )
    modified_times[ self ] = new_time
    return new_time
end

--- [SHARED AND MENU]
---
--- Deletes a directory.
---
---@param recursive? boolean If `true`, the directory will be deleted even if it contains files or directories.
---@async
function Directory:delete( recursive )
    delete_directory( self, recursive == true, 2 )
end

--- [SHARED AND MENU]
---
--- Copies a file to another directory.
---
---@param directory_object dreamwork.std.fs.Directory The directory to copy the file to.
---@param name? string The new name of the file. If `nil`, the original name will be used.
---@param forced? boolean If `true`, the file will be overwritten if it already exists.
---@async
function Directory:copy( directory_object, name, forced )
    if name == nil then
        name = names[ self ]
    end

    local mount_point = mount_points[ directory_object ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be copied, parent directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not mount_info.writable then
        std.errorf( 2, false, "'%s' cannot be copied, parent directory is not writable.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    -- TODO: add checks to prevent recursion copying

    local fs_object, is_directory = directory_get( directory_object, name, nil, nil, mount_point, nil )
    if fs_object == nil then
        fs_object = directory_object:makeDirectory( name, forced )
    elseif not is_directory then
        ---@cast fs_object dreamwork.std.fs.File
        if forced then
            fs_object:delete()
            fs_object = directory_object:makeDirectory( name, forced )
        else
            std.errorf( 2, false, "'%s' already exists and cannot be overwritten.", fs_object )
        end
    end

    ---@cast fs_object dreamwork.std.fs.Directory

    local files, file_count, directories, directory_count = self:select()

    for i = 1, directory_count, 1 do
        directories[ i ]:copy( fs_object, nil, forced )
    end

    for i = 1, file_count, 1 do
        files[ i ]:copy( fs_object, nil, forced )
    end

    modified_times[ fs_object ] = file_Time( mount_paths[ fs_object ], mount_point )

    return fs_object
end

do

    -- local function directory_move( mount_point, mount_path, new_mount_point, new_mount_path )
    --     if string_byte( mount_path, 1, 1 ) ~= nil then
    --         mount_path = mount_path .. "/"
    --     end

    --     local fs_files, fs_directories = file_Find( mount_path .. "*", mount_point )

    --     for i = 1, #fs_directories, 1 do
    --         directory_move( mount_point, mount_path, new_mount_point, new_mount_path )
    --     end

    --     for i = 1, #fs_files, 1 do

    --     end

    -- end

    --- [SHARED AND MENU]
    ---
    --- Moves a file to another directory.
    ---
    ---@param directory_object dreamwork.std.fs.Directory The directory to move the file to.
    ---@param name? string The new name of the file. If `nil`, the original name will be used.
    ---@param forced? boolean If `true`, the file will be overwritten if it already exists.
    ---@async
    function Directory:move( directory_object, name, forced )
        local mount_point_from = mount_points[ self ]
        if mount_point_from == nil then
            std.errorf( 2, false, "'%s' cannot be moved, parent directory is not mounted.", self )
        end

        ---@cast mount_point_from string

        local mount_point_to = mount_points[ directory_object ]
        if mount_point_to == nil then
            std.errorf( 2, false, "'%s' cannot be moved, parent directory is not mounted.", self )
        end

        ---@cast mount_point_to string

        local mount_info_from = mount_infos[ mount_point_from ]
        if mount_info_from == nil or not mount_info_from.deletable then
            std.errorf( 2, false, "'%s' cannot be moved, parent directory is not allowing file deletion.", self )
        end

        ---@cast mount_info_from dreamwork.std.fs.MountInfo

        local mount_info_to = mount_infos[ mount_point_to ]
        if mount_info_to == nil or not mount_info_to.writable then
            std.errorf( 2, false, "'%s' cannot be moved, parent directory is not allowing file moving.", self )
        end

        local current_name = names[ self ]

        if name == nil then
            name = current_name
        end

        local parent_directory = parents[ self ]
        if parent_directory == nil then
            std.errorf( 2, false, "'%s' has no parent directory and cannot be moved.", self )
        end

        ---@cast parent_directory dreamwork.std.fs.Directory

        local existing_object, is_directory = directory_get( directory_object, name )
        if existing_object ~= nil and not is_directory then
            ---@cast existing_object dreamwork.std.fs.File
            if forced then
                existing_object:delete()
            else
                std.errorf( 2, false, "'%s' already exists in '%'. Use `forced=true` to overwrite it.", existing_object, directory_object )
            end
        end

        ---@cast existing_object nil

        if parents[ self ] ~= parent_directory then
            std.errorf( 2, false, "'%s' has changed its location or been deleted, moving failed.", self )
        end

        local mount_path_from = mount_paths[ self ]
        local mount_path_to = rel_path( directory_object, name )

        -- ---@diagnostic disable-next-line: redundant-parameter
        -- file_CreateDir( mount_path_to, mount_point_to )
        -- names[ self ] = name

        -- eject( parent_directory, current_name )
        -- insert( directory_object, self )

        -- directory_move( mount_point_from, mount_path_from, mount_point_to, mount_path_to )
    end

end

-- TODO: finish directory methods

--- [SHARED AND MENU]
---
--- Renames a file.
---
---@param name string The new name of the file.
---@param forced? boolean If `true`, the file will be renamed even if it already exists.
---@async
function Directory:rename( name, forced )
    local mount_point = mount_points[ self ]
    if mount_point == nil then
        std.errorf( 2, false, "'%s' cannot be renamed, parent directory is not mounted.", self )
    end

    ---@cast mount_point string

    local mount_info = mount_infos[ mount_point ]
    if mount_info == nil or not (mount_info.writable and mount_info.deletable) then
        std.errorf( 2, false, "'%s' cannot be renamed, parent directory is not allowing file renaming.", self )
    end

    ---@cast mount_info dreamwork.std.fs.MountInfo

    local parent_directory = parents[ self ]
    if parents[ self ] == nil then
        std.errorf( 2, false, "'%s' has no parent directory and cannot be renamed.", self )
    end

    ---@cast parent_directory dreamwork.std.fs.Directory

    local existing_object, is_directory = directory_get( parent_directory, name )
    if existing_object ~= nil then
        if forced then
            if is_directory then
                ---@cast existing_object dreamwork.std.fs.Directory
                existing_object:delete( forced )
            else
                ---@cast existing_object dreamwork.std.fs.File
                existing_object:delete()
            end
        else
            std.errorf( 2, false, "'%s' already exists in '%'. Use `forced=true` to overwrite it.", existing_object, parent_directory )
        end
    end

    ---@cast existing_object nil

    if parents[ self ] ~= parent_directory then
        std.errorf( 2, false, "'%s' has changed its location or been deleted, renaming failed.", self )
    end

    local files, file_count,
    directories, directory_count = self:select()

end

---@param prefix? string
---@param is_last? boolean
---@return string
function Directory:toStringTree( prefix, is_last )
    local lines, line_count = {}, 1

    local descendants_table = descendants[ self ]

    local next_prefix
    if prefix == nil then
        lines[ 1 ] = tostring( self )
        next_prefix = " "
    else
        lines[ 1 ] = prefix .. (is_last and "╚═ " or "╠═ ") .. tostring( self )

        local spaces = (is_last and "    " or " ")
        next_prefix = prefix .. (is_last and spaces or "║  " .. spaces)
    end

    local children_length = descendant_counts[ self ]

    for i = 1, children_length, 1 do
        line_count = line_count + 1
        lines[ line_count ] = next_prefix .. "║  "

        line_count = line_count + 1

        local descendant = descendants_table[ i ]
        if is_directory_object[ descendant ] then
            ---@cast descendant dreamwork.std.fs.Directory
            lines[ line_count ] = descendant:toStringTree( next_prefix, i == children_length )
        else
            ---@cast descendant dreamwork.std.fs.File
            lines[ line_count ] = next_prefix .. string.format( "%s %s", i == children_length and "╚═ " or "╠═ ", descendant )
        end
    end

    return table_concat( lines, "\n", 1, line_count )
end

local root = DirectoryClass( "", "BASE_PATH", "" )

---@param game_info dreamwork.engine.GameInfo
---@param is_mounted boolean
engine_hookCatch( "dreamwork.game.mount", function( game_info, is_mounted )
    local game_folder = game_info.folder
    eject( root, game_folder )

    if is_mounted then
        insert( root, DirectoryClass( game_folder, game_folder, "" ) )
    end
end, 2 )

do

    local garrysmod = DirectoryClass( "garrysmod", "MOD", "" )
    insert( root, garrysmod )

    local data = DirectoryClass( "data", "DATA", "" )
    insert( garrysmod, data )

end

do

    local workspace = DirectoryClass( "workspace", "GAME", "" )
    insert( root, workspace )

    local addons = DirectoryClass( "addons" )
    insert( workspace, addons )

    ---@param addon_info dreamwork.engine.AddonInfo
    ---@param is_mounted boolean
    engine_hookCatch( "dreamwork.addon.mount", function( addon_info, is_mounted )
        local addon_folder = addon_info.folder
        eject( addons, addon_folder )

        if is_mounted then
            insert( addons, DirectoryClass( addon_folder, addon_info.title, "" ) )
        end
    end, 2 )

    local download = DirectoryClass( "download", "DOWNLOAD", "" )
    insert( workspace, download )

    local lua = DirectoryClass( "lua", (LUA_SERVER and "lsv" or (LUA_CLIENT and "lcl" or (LUA_MENU and "LuaMenu" or "LUA"))), "" )
    insert( workspace, lua )

    local map = DirectoryClass( "map", "BSP", "" )
    insert( workspace, map )

end

--[[

    TODO: make fake fs file for addon presets that will exists only in menu realm

    _G.LoadAddonPresets
    _G.SaveAddonPresets

    https://wiki.facepunch.com/gmod/Global.LoadPresets
    https://wiki.facepunch.com/gmod/Global.SavePresets

]]

-- TODO: add more fs hooks

--- [SHARED AND MENU]
---
--- Returns the file or directory by given path as a `dreamwork.std.fs.File` or `dreamwork.std.fs.Directory` object.
---
---@param path_to string The path to the file or directory.
---@return dreamwork.std.fs.Object | nil fs_object The file or directory.
---@return boolean is_directory Returns `true` if the object is a directory, otherwise `false`.
function fs.lookup( path_to )
    return directory_lookup( root, path_resolve( path_to ), 2 )
end

--- [SHARED AND MENU]
---
--- Checks if a file or directory exists by given path.
---
---@param path_to string The path to the file or directory.
---@return boolean exists Returns `true` if the file or directory exists, otherwise `false`.
---@return boolean is_directory Returns `true` if the object is a directory, otherwise `false`.
function fs.exists( path_to )
    local fs_object, is_directory = directory_lookup( root, path_resolve( path_to ), 2 )
    return fs_object ~= nil, is_directory
end

--- [SHARED AND MENU]
---
--- Checks if a directory exists by given path.
---
---@param directory_path string The path to the directory.
---@return boolean exists Returns `true` if the directory exists and is not a file, otherwise `false`.
function fs.isDirectory( directory_path )
    local directory_object, is_directory = directory_lookup( root, path_resolve( directory_path ), 2 )
    return directory_object ~= nil and is_directory
end

--- [SHARED AND MENU]
---
--- Checks if a file exists by given path.
---
---@param file_path string The path to the fs.
---@return boolean exists Returns `true` if the file exists and is not a directory, otherwise `false`.
function fs.isFile( file_path )
    local file_object, is_directory = directory_lookup( root, path_resolve( file_path ), 2 )
    return file_object ~= nil and not is_directory
end

--- [SHARED AND MENU]
---
--- Checks if a file or directory is empty by given path.
---
---@param path_to string The path to the file or directory.
---@return boolean empty Returns `true` if the file or directory is empty, otherwise `false`.
---@return boolean is_directory Returns `true` if the object is a directory, otherwise `false`.
function fs.isEmpty( path_to, forced )
    local fs_object, is_directory = directory_lookup( root, path_resolve( path_to ), 2 )
    if fs_object == nil then
        if not forced then
            std.errorf( 2, false, "Path '%s' does not exist.", path_to )
        end

        return true, false
    end

    return fs_object:isEmpty(), is_directory
end

--- [SHARED AND MENU]
---
--- Creates a directory by given path.
---
--- If parent directory does not exist, it will be created.
---
---@param directory_path string The path to the directory.
---@param forced? boolean If `true`, files in the path will be deleted.
---@return dreamwork.std.fs.Directory directory_object The created directory.
---@async
function fs.makeDirectory( directory_path, forced )
    return make_directory_chain( root, path_resolve( directory_path ), forced == true, 2, 2 )
end

--- [SHARED AND MENU]
---
--- Creates a file by given path.
---
--- If the parent directory does not exist, it will be created.
---
--- If file already exists, it will be returned.
---
---@param file_path string The path to file.
---@param forced? boolean If `true`, files in the path will be deleted.
---@param data? string The data to be written to file, if it does not exist.
---@return dreamwork.std.fs.File file_object
---@async
function fs.makeFile( file_path, forced, data )
    return make_file_chain( root, path_resolve( file_path ), forced == true, 2, 2, data or "" )
end

--- [SHARED AND MENU]
---
--- Creates a file at the specified path if it does not exist.
---
--- If the parent directory does not exist, it will be created.
---
--- If file already exists, it will be returned and its last modification time will be updated.
--- If file at the end of the path is a directory, it will be returned and its last modification time will be updated.
---
---@param file_path string
---@param forced? boolean
---@return dreamwork.std.fs.Object fs_object
---@return boolean is_directory
---@async
function fs.touch( file_path, forced )
    local resolved_path = path_resolve( file_path )
    local fs_object, is_directory = directory_lookup( root, resolved_path, 2 )

    if fs_object == nil then
        return make_file_chain( root, resolved_path, forced == true, 2, 2, "" ), false
    end

    fs_object:touch()

    return fs_object, is_directory
end

--- [SHARED AND MENU]
---
--- Returns the time of the last modification of file or directory at the specified path.
---
---@param file_path string The path to file or directory.
---@return integer unix_time The last modified time of file or directory.
function fs.time( file_path, forced )
    local fs_object = directory_lookup( root, path_resolve( file_path ), 2 )
    if fs_object == nil then
        if not forced then
            std.errorf( 2, false, "Path '%s' does not exist.", file_path )
        end

        return 0
    end

    return fs_object.time
end

--- [SHARED AND MENU]
---
--- Returns the size of a file or directory by given path.
---
---@param file_path string The path to the file or directory.
---@return integer size The size of the file or directory in bytes.
function fs.size( file_path, forced )
    local fs_object = directory_lookup( root, path_resolve( file_path ), 2 )
    if fs_object == nil then
        if not forced then
            std.errorf( 2, false, "Path '%s' does not exist.", file_path )
        end

        return 0
    end

    return fs_object.size
end

--- [SHARED AND MENU]
---
--- Searches for files and directories in a directory by wildcard.
---
--- Can be used for file search by setting `searchable` to a wildcard string.
---
---@param directory_path string The path to the directory.
---@param wildcard? string The wildcard to search for.
---@return dreamwork.std.fs.File[] files The list of files in the directory.
---@return integer file_count The number of files in the directory.
---@return dreamwork.std.fs.Directory[] directories The list of directories in the directory.
---@return integer directory_count The number of directories in the directory.
function fs.select( directory_path, wildcard )
    local directory_object, is_directory = directory_lookup( root, path_resolve( directory_path ), 2 )
    if directory_object == nil or not is_directory then
        return {}, 0, {}, 0
    end

    ---@cast directory_object dreamwork.std.fs.Directory
    return directory_object:select( wildcard )
end

do

    local futures_yield = futures.yield

    ---@param file_object dreamwork.std.fs.File
    ---@async
    local function iterate_file( file_object )
        return futures_yield( paths[ file_object ], false )
    end

    ---@param directory_object dreamwork.std.fs.Directory
    ---@async
    local function iterate_directory( directory_object )
        return futures_yield( paths[ directory_object ], true )
    end

    --- [SHARED AND MENU]
    ---
    --- Iterates over all files and directories in a directory by given path.
    ---
    ---@param directory_path string The path to the directory.
    ---@async
    ---@return AsyncIterator<dreamwork.std.fs.Object, boolean> iterator An async iterator that yields the path and a boolean indicating if the object is a directory.
    function fs.iterator( directory_path )
        local fs_object, is_directory = directory_lookup( root, path_resolve( directory_path ), 2 )
        if fs_object ~= nil and is_directory then
            ---@cast fs_object dreamwork.std.fs.Directory
            fs_object:foreach( iterate_file, iterate_directory )
        end
    end

end

--- [SHARED AND MENU]
---
--- Reads data from a file by given path.
---
---@param file_path string The path to the file.
---@return string data The data of the file.
---@async
function fs.read( file_path )
    local file_object, is_directory = directory_lookup( root, path_resolve( file_path ), 2 )
    if file_object == nil then
        std.errorf( 2, false, "Path '%s' does not exist.", file_path )
    end

    if is_directory then
        std.errorf( 2, false, "Path '%s' is a directory.", file_path )
    end

    ---@cast file_object dreamwork.std.fs.File

    return file_object:read()
end

--- [SHARED AND MENU]
---
--- Writes data to a file by given path.
---
---@param file_path string The path to the file.
---@param data string The data to write to the file.
---@param forced? boolean If `true`, then the entire path to the file will be forcibly recreated, and anything that does not match the path will be deleted.
---@return dreamwork.std.fs.File file_object The file object.
---@async
function fs.write( file_path, data, forced )
    forced = forced == true

    local full_path = path_resolve( file_path )
    local directory_path, file_name = path_split( full_path, false )

    local directory_object, is_directory = directory_lookup( root, directory_path, 2 )
    if directory_object ~= nil and not is_directory then
        if forced then
            directory_object = make_directory_chain( root, directory_path, true, 2, 2 )
        else
            std.errorf( 2, false, "Path '%s' is not a directory.", directory_path )
        end
    end

    ---@cast directory_object dreamwork.std.fs.Directory

    local file_object
    file_object, is_directory = directory_object:get( file_name )

    ---@cast file_object dreamwork.std.fs.File | nil

    if file_object == nil or is_directory then
        file_object = make_file( directory_object, file_name, forced, 2, data )
    else
        file_object:write( data )
    end

    return file_object
end

--- [SHARED AND MENU]
---
--- Appends data to a file by given path.
---
---@param file_path string The path to the file.
---@param data string The data to append to the file.
---@param forced? boolean If `true`, then the entire path to the file will be forcibly recreated, and anything that does not match the path will be deleted.
---@return dreamwork.std.fs.File file_object The file object.
---@async
function fs.append( file_path, data, forced )
    forced = forced == true

    local full_path = path_resolve( file_path )
    local directory_path, file_name = path_split( full_path, false )

    local directory_object, is_directory = directory_lookup( root, directory_path, 2 )
    if directory_object == nil or not is_directory then
        if forced then
            directory_object = make_directory_chain( root, directory_path, true, 2, 2 )
        else
            std.errorf( 2, false, "Path '%s' is not a directory.", directory_path )
        end
    end

    ---@cast directory_object dreamwork.std.fs.Directory

    local file_object
    file_object, is_directory = directory_object:get( file_name )

    ---@cast file_object dreamwork.std.fs.File | nil

    if file_object == nil or is_directory then
        file_object = make_file( directory_object, file_name, forced, 2, data )
    else
        file_object:append( data )
    end

    return file_object
end

--- [SHARED AND MENU]
---
--- Deletes a file or directory by given path.
---
---@param path_to string The path to the file or directory.
---@param recursive? boolean If `true`, the file or directory will be deleted even if it contains files or directories.
---@async
function fs.delete( path_to, recursive )
    local full_path = path_resolve( path_to )

    local fs_object, is_directory = directory_lookup( root, full_path, 2 )
    if fs_object == nil then
        std.errorf( 2, false, "Path '%s' does not exist.", full_path )
    end

    ---@cast fs_object dreamwork.std.fs.Object

    if is_directory then
        ---@cast fs_object dreamwork.std.fs.Directory
        fs_object:delete( recursive )
    else
        ---@cast fs_object dreamwork.std.fs.File
        fs_object:delete()
    end
end

--- [SHARED AND MENU]
---
--- Copies a file or directory by given path.
---
---@param source_path string The path to file or directory to copy.
---@param target_path string The path to file or directory to copy to.
---@param forced? boolean If `true`, file or directory will be copied even if it already exists.
---@return dreamwork.std.fs.Object object_copy The copied file or directory.
---@return boolean is_directory `true` if copied object is a directory, otherwise `false`.
---@async
function fs.copy( source_path, target_path, forced )
    local resource_source_path = path_resolve( source_path )

    local source_object, source_is_directory = directory_lookup( root, resource_source_path, 2 )
    if source_object == nil then
        std.errorf( 2, false, "Path '%s' does not exist.", resource_source_path )
    end

    ---@cast source_object dreamwork.std.fs.Object

    local resolved_target_path = path_resolve( target_path )
    local segments, segment_count = string_byteSplit( resolved_target_path, 0x2F --[[ / ]], 2 )

    for i = segment_count, 1, -1 do
        local fs_object, is_directory = directory_lookup( root, table_concat( segments, "/", 1, i ), 2 )
        if is_directory then
            ---@cast fs_object dreamwork.std.fs.Directory

            if i == segment_count then
                return source_object:copy( fs_object, nil, forced ), source_is_directory
            end

            local segments_remaining = segment_count - i
            if segments_remaining ~= 1 then
                for j = 1, segments_remaining - 1, 1 do
                    fs_object = fs_object:makeDirectory( segments[ i + j ], forced )
                end
            end

            return source_object:copy( fs_object, segments[ segment_count ], forced ), source_is_directory
        end
    end

    ---@diagnostic disable-next-line: missing-return
    std.errorf( 2, false, "Path '%s' does not exist.", resolved_target_path )
end

-- TODO: finish fs functions

--- [SHARED AND MENU]
---
--- Moves a file or directory by given path.
---
---@param source_path string The path to file or directory to move.
---@param target_path string The path to file or directory to move to.
---@param forced? boolean If `true`, file or directory will be moved even if it already exists.
---@param recursive? boolean If `true`, all directories in path will be moved if they already exist.
---@async
function fs.move( source_path, target_path, forced, recursive )

end

--- [SHARED AND MENU]
---
--- Renames a file or directory by given path.
---
---@param path_to string The path to file or directory.
---@param name string The new name of file or directory.
---@param forced? boolean If `true`, file or directory will be renamed even if it already exists.
---@param recursive? boolean If `true`, all directories in path will be renamed if they already exist.
---@async
function fs.rename( path_to, name, forced, recursive )

end

local watchdog_isWatched = watchdog.isWatched

do

    local Created = std.Hook( "fs.watchdog.Created" )
    watchdog.Created = Created

    ---@param watchdog_info dreamwork.std.fs.watchdog.ObjectInfo
    engine_hookCatch( "FileSystemCreated", function( watchdog_info )
        local fs_object = watchdog_info.object
        modified_times[ fs_object ] = watchdog_info.modified_time

        dreamwork_logger:debug( "%s '%s' has been created. (%s)", is_directory_object[ fs_object ] and "Directory" or "File", paths[ fs_object ], time.format( "{date_time}", watchdog_info.modified_time ) )

        if watchdog_isWatched( fs_object ) then
            Created:call( fs_object, watchdog_info.is_directory )
        end
    end )

end

do

    local Deleted = std.Hook( "fs.watchdog.Deleted" )
    watchdog.Deleted = Deleted

    ---@param watchdog_info dreamwork.std.fs.watchdog.ObjectInfo
    engine_hookCatch( "FileSystemDeleted", function( watchdog_info )
        local fs_object = watchdog_info.object
        local was_watched = watchdog.unwatch( fs_object )

        dreamwork_logger:debug( "%s '%s' has been deleted. (%s)", is_directory_object[ fs_object ] and "Directory" or "File", paths[ fs_object ], time.format( "{date_time}", watchdog_info.modified_time ) )
        eject( watchdog_info.parent, watchdog_info.name )

        if was_watched then
            Deleted:call( fs_object, watchdog_info.is_directory )
        end
    end )

end

do

    local Modified = std.Hook( "fs.watchdog.Modified" )
    watchdog.Modified = Modified

    ---@param watchdog_info dreamwork.std.fs.watchdog.ObjectInfo
    engine_hookCatch( "FileSystemModified", function( watchdog_info )
        local fs_object = watchdog_info.object
        modified_times[ fs_object ] = watchdog_info.modified_time

        dreamwork_logger:debug( "%s '%s' has been modified. (%s)", is_directory_object[ fs_object ] and "Directory" or "File", paths[ fs_object ], time.format( "{date_time}", watchdog_info.modified_time ) )

        if watchdog_isWatched( fs_object ) then
            Modified:call( fs_object, watchdog_info.is_directory )
        end
    end )

end

--- [SHARED AND MENU]
---
--- Returns the location of the specified file or directory in gmod filesystem.
---
---@param fs_object dreamwork.std.fs.Object The file or directory.
---@return string mount_point The mount point of the file or directory.
---@return string mount_path The mount path of the file or directory.
function fs.whereis( fs_object )
    local mount_point = mount_points[ fs_object ]
    if mount_point == nil then
        return "GAME", ""
    end

    local mount_path = mount_paths[ fs_object ]
    if string_byte( mount_path, 1, 1 ) == nil then
        return mount_point, mount_path
    end

    -- local addons = engine.AddonList

    -- for i = 1, engine.AddonCount, 1 do
    --     local title = addons[ i ].title
    --     if file_Exists( mount_path, title ) then
    --         return title, mount_path
    --     end
    -- end

    -- local games = engine.GameList

    -- for i = 1, engine.GameCount, 1 do
    --     local folder = games[ i ].folder
    --     if file_Exists( mount_path, folder ) then
    --         return folder, mount_path
    --     end
    -- end

    local _, addon_directories = file_Find( "addons/*", "MOD" )

    for i = 1, #addon_directories, 1 do
        local file_path = "addons/" .. addon_directories[ i ] .. "/" .. mount_path
        if file_Exists( file_path, "MOD" ) then
            return "MOD", file_path
        end
    end

    return mount_point, mount_path
end

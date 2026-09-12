---@alias dreamwork.std.fs.AsyncStatus
---| -8 # file name is not part of the file system; please try another one
---| -7 # please retry later (network problems, etc)
---| -6 # hard subsystem failure
---| -5 # read parameters are invalid for unbuffered I/O
---| -4 # read error on file
---| -3 # write error on file
---| -2 # write parameters are invalid for unbuffered I/O
---| -1 # file could not be opened (bad path, not exist, etc)
---|  0 # successfully completed
---|  1 # has been properly queued and awaiting for service
---|  2 # is being accessed
---|  3 # has been interrupted by caller
---|  4 # has not yet been queued

---@alias dreamwork.GModFile.SortingMode
---| "nameasc"
---| "namedesc"
---| "dateasc"
---| "datedesc"

---@alias dreamwork.GModFile.AsyncReadCallback
---| fun( relative_path: string, mount: string, status: dreamwork.std.fs.AsyncStatus, data: ( string | nil ) )

---@alias dreamwork.GModFile.Mode
---| "rb" # read-only, binary
---| "wb" # write-only, binary
---| "ab" # append-only, binary

---@class dreamwork.GModFile

---@class dreamwork.GModFileLib
---@field AsyncRead fun( relative_path: string, mount: string, callback: dreamwork.GModFile.AsyncReadCallback, sync_read: boolean? ): dreamwork.std.fs.AsyncStatus
---@field CreateDir fun( relative_path: string )
---@field Delete fun( relative_path: string, mount: string ): boolean
---@field Exists fun( relative_path: string, mount: string ): boolean
---@field Find fun( wildcard: string, mount: string, sorting_mode: dreamwork.GModFile.SortingMode ): ( string[] | nil ), ( string[] | nil )
---@field IsDir fun( relative_path: string, mount: string ): boolean
---@field Open fun( relative_path: string, mode: dreamwork.GModFile.Mode, mount: string ): dreamwork.GModFile | nil
---@field Rename fun( relative_path: string, new_path: string ): boolean
---@field Size fun( relative_path: string, mount: string ): -1 | integer
---@field Time fun( relative_path: string, mount: string ): 0 | 1 | integer
---@diagnostic disable-next-line: undefined-global
local glua_file = file
local file_Time = glua_file.Time
local file_Find = glua_file.Find
local file_Size = glua_file.Size
local file_Open = glua_file.Open
local file_IsDir = glua_file.IsDir
local file_Exists = glua_file.Exists
local file_Delete = glua_file.Delete
local file_CreateDir = glua_file.CreateDir

---@class dreamwork.HolyFileSystemLib
---@field AddSearchPath fun( system_path: string, mount: string, backwards: boolean? )
---@field AsyncRead fun( relative_path: string, mount: string, callback: dreamwork.GModFile.AsyncReadCallback ): dreamwork.std.fs.AsyncStatus
---@field CreateDir fun( relative_path: string, mount: string? )
---@field Delete fun( relative_path: string, mount: string? )
---@field Exists fun( relative_path: string, mount: string ): boolean
---@field Find fun( wildcard: string, mount: string, sorting_mode: dreamwork.GModFile.SortingMode ): ( string[] | nil ), ( string[] | nil )
---@field FullPathToRelativePath fun( system_path: string, mount: string? ): string | nil
---@field IsDir fun( relative_path: string, mount: string ): boolean
---@field Open fun( relative_path: string, mode: dreamwork.GModFile.Mode, mount: string ): dreamwork.GModFile | nil
---@field RelativePathToFullPath fun( relative_path: string, mount: string ): string | nil
---@field RemoveAllSearchPaths fun()
---@field RemoveSearchPath fun( system_path: string, mount: string )
---@field RemoveSearchPaths fun( mount: string )
---@field Rename fun( relative_path: string, new_path: string, mount: string? ): boolean
---@field Size fun( relative_path: string, mount: string ): -1 | integer
---@field Time fun( relative_path: string, mount: string ): 0 | 1 | integer
---@field TimeAccessed fun( relative_path: string, mount: string ): 0 | integer
---@field TimeCreated fun( relative_path: string, mount: string ): 0 | integer
---@diagnostic disable-next-line: undefined-global
local filesystem = filesystem

---@class dreamwork.std
local std = dreamwork.std

local class = std.class

local LUA_CLIENT = std.LUA_CLIENT
local LUA_SERVER = std.LUA_SERVER
local LUA_MENU = std.LUA_MENU

local debug = std.debug
local debug_fempty = debug.fempty

local string = std.string

local console = std.console

local pcall = std.pcall
local error = std.error


do

    local glua_require = require or debug_fempty

    local SYSTEM_WINDOWS = std.SYSTEM_WINDOWS
    local SYSTEM_LINUX = std.SYSTEM_LINUX
    local SYSTEM_X32 = std.SYSTEM_X32

    local jit_edge = std.jit.edge

    local head = "lua/bin/gm" .. (LUA_CLIENT and "cl" or "sv") .. "_"
    local tail = "_" .. std.SYSTEM_NAME

    --- [SHARED AND MENU]
    ---
    --- Checks if a binary module is available and can be loaded.
    ---
    ---@param name string The binary module name.
    ---@return boolean installed `true` if binary module is available, `false` otherwise.
    ---@return string abs_path The absolute path to binary module.
    local function lookupbinary( name )
        local file_path = head .. name .. tail

        local dll_path = file_path .. ".dll"
        if file_Exists( dll_path, "MOD" ) then
            return true, "/garrysmod/" .. dll_path
        end

        local so_path = file_path .. ".so"
        if file_Exists( so_path, "MOD" ) then
            return true, "/garrysmod/" .. so_path
        end

        if jit_edge and SYSTEM_LINUX and SYSTEM_X32 then
            file_path = head .. name .. "_linux32"

            dll_path = file_path .. ".dll"
            if file_Exists( dll_path, "MOD" ) then
                return true, "/garrysmod/" .. dll_path
            end

            so_path = file_path .. ".so"
            if file_Exists( so_path, "MOD" ) then
                return true, "/garrysmod/" .. so_path
            end
        end

        return false, "/garrysmod/" .. file_path .. (SYSTEM_WINDOWS and ".dll" or ".so")
    end

    std.lookupbinary = lookupbinary

    local sv_allowcslua

    if LUA_SERVER then
        sv_allowcslua = console.Variable.get( "sv_allowcslua", "boolean" )
    end

    --- [SHARED AND MENU]
    ---
    --- Loads a binary module if available.
    ---
    ---@param name string The binary module name, for example: "chttp".
    ---@return boolean success `true` if binary module is successfully installed, `false` otherwise.
    function std.loadbinary( name )
        if lookupbinary( name ) then
            if sv_allowcslua ~= nil and sv_allowcslua.value then
                sv_allowcslua.value = false
            end

            return pcall( glua_require, name )
        end

        return false
    end

end

---@class dreamwork.std.fs.MountInfo
---@field writable boolean If `true` mount allows creating directories inside.
---@field writable_extensions table<string, boolean> The extension map of allowed extensions to write.
---@field deletable boolean If `true` mount allows deleting files and directories.

---@type table<string, dreamwork.std.fs.MountInfo>
local mount_infos = {
    [ "DATA" ] = {
        writable = true,
        deletable = true,
        writable_extensions = {
            -- Taken from https://wiki.facepunch.com/gmod/file.Write
            txt = true,
            dat = true,
            json = true,
            xml = true,
            csv = true,
            dem = true,
            vcd = true,
            gma = true,
            mdl = true,
            phy = true,
            vvd = true,
            vtx = true,
            ani = true,
            vtf = true,
            vmt = true,
            png = true,
            jpg = true,
            jpeg = true,
            mp3 = true,
            wav = true,
            ogg = true
        }
    },
    [ "MOD" ] = {
        writable = false,
        deletable = LUA_MENU,
        writable_extensions = {}
    }
}

---@type table<string, boolean>
local restricted_names = {
    [ "^dreamwork_tmp$.dat" ] = true,
    [ ".." ] = true,
    [ "." ] = true,
    [ "" ] = true
}


---@class dreamwork.std.File : dreamwork.std.Object
local File = class.base( "File", false, nil )

-- TODO: https://wiki.facepunch.com/gmod/resource.AddFile & https://wiki.facepunch.com/gmod/resource.AddSingleFile
-- TODO: https://wiki.facepunch.com/gmod/Global.AddCSLuaFile

-- TODO: https://github.com/RaphaelIT7/gmod-holylib#filesystem

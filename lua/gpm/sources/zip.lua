-- Libraries
local deflatelua = gpm.libs.deflatelua
local promise = gpm.promise
local sources = gpm.sources
local gmad = gpm.gmad
local string = string
local table = table
local util = util
local fs = gpm.fs

-- Variables
local cacheLifetime = GetConVar( "gpm_cache_lifetime" )
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local debug_fempty = debug.fempty
local logger = gpm.Logger
local tostring = tostring
local ipairs = ipairs
local xpcall = xpcall
local type = gpm.type

local cacheFolder = "gpm/" .. ( SERVER and "server" or "client" ) .. "/packages/"
fs.CreateDir( cacheFolder )

module( "gpm.sources.zip" )

function CanImport( filePath )
    return fs.Exists( filePath, "GAME" ) and string.EndsWith( filePath, ".zip.dat" ) or string.EndsWith( filePath, ".zip" )
end

function IterateZipFiles( fileHandle )
    if type( fileHandle ) ~= "File" then return debug_fempty end

    return function()
        if fileHandle:Read( 4 ) ~= "PK\x03\x04" then return end
        fileHandle:Skip( 4 )

        local compressionMethod = fileHandle:ReadUShort()
        fileHandle:Skip( 4 )

        local crc = fileHandle:ReadULong()
        local compressedSize = fileHandle:ReadULong()
        fileHandle:Skip( 4 )

        local fileNameLen = fileHandle:ReadUShort()
        local extraLen = fileHandle:ReadUShort()
        local fileName = fileHandle:Read( fileNameLen )
        fileHandle:Skip( extraLen )

        local data
        if compressionMethod == 0 then
            -- No compression
            data = fileHandle:Read( compressedSize )
        elseif compressionMethod == 8 then
            -- Deflate compression
            local compressedData = fileHandle:Read( compressedSize )

            local out = {}
            local ok = xpcall( deflatelua.inflate, ErrorNoHaltWithStack, {
                ["input"] = compressedData,
                ["output"] = out
            } )

            if ok then
                data = table.concat( out )
            end
        end

        if data and tostring( crc ) ~= util.CRC( data ) then
            data = nil
        end

        return fileName, data
    end
end

local contentFolders = {
    ["particles"] = true,
    ["materials"] = true,
    ["gamemodes"] = true,
    ["resource"] = true,
    ["scripts"] = true,
    ["scenes"] = true,
    ["models"] = true,
    ["sound"] = true,
    ["maps"] = true,
    ["lua"] = true
}

function PerformPath( filePath )
    local result = {}

    local founded = false
    for _, folder in ipairs( string.Split( filePath, "/" ) ) do
        if not founded and contentFolders[ folder ] then
            founded = true
        end

        if founded then
            result[ #result + 1 ] = folder
        end
    end

    if #result > 0 then
        return table.concat( result, "/" )
    end
end

Import = promise.Async( function( filePath, parentPackage )
    local cachePath = cacheFolder .. "zip_" .. util.MD5( filePath ) .. ".gma.dat"
    if fs.Exists( cachePath, "DATA" ) and fs.Time( cachePath, "DATA" ) > ( 60 * 60 * cacheLifetime:GetInt() ) then
        return sources.gmad.Import( "data/" .. cachePath, parentPackage )
    end

    local fileClass = fs.Open( filePath, "rb", "GAME" )
    if not fileClass then
        logger:Error( "Package `%s` import failed, file cannot be readed.", filePath )
        return
    end

    local files = {}
    for filePath, content in IterateZipFiles( fileClass ) do
        if not content then continue end

        filePath = PerformPath( filePath )
        if not filePath then continue end

        files[ #files + 1 ] = { filePath, content }
    end

    fileClass:Close()

    if #files == 0 then
        logger:Error( "Package `%s` import failed, no files to mount.", filePath )
        return
    end

    local gma = gmad.Write( cachePath )
    if not gma then
        logger:Error( "Package `%s` import failed, cache construction error, mounting failed.", filePath )
        return
    end

    gma:SetTitle( filePath )

    for _, data in ipairs( files ) do
        gma:AddFile( data[ 1 ], data[ 2 ] )
    end

    gma:Close()

    return sources.gmad.Import( "data/" .. cachePath, parentPackage )
end )
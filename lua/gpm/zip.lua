-- Libraries
local deflatelua = gpm.libs.deflatelua
local fs = gpm.fs

-- Variables
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local debug_fempty = debug.fempty
local table_concat = table.concat
local util_CRC = util.CRC
local tostring = tostring
local xpcall = xpcall
local type = gpm.type

module( "gpm.zip" )

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
                data = table_concat( out )
            end
        end

        if data and tostring( crc ) ~= util_CRC( data ) then
            data = nil
        end

        return fileName, data
    end
end

function Read( filePath, gamePath )
    local fileHandle = fs.Open( filePath, gamePath )
    if not fileHandle then return end

    local files = {}
    for filePath, content in pairs( IterateZipFiles( fileHandle ) ) do
        if not content then continue end
        files[ filePath ] = content
    end

    return files
end
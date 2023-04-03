local emptyFunc = debug.fempty
local tostring = tostring
local util_CRC = util.CRC

module( "gpm.unzip", package.seeall )

function IterateZipFiles( fileHandle )
    if not isFile( fileHandle ) then
        return emptyFunc
    end

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
        if compressionMethod ~= 0 then
            fileHandle:Skip( compressedSize )
        else
            data = fileHandle:Read( compressedSize )
            if data and tostring( crc ) ~= util_CRC( data ) then
                data = nil
            end
        end

        return fileName, data
    end
end

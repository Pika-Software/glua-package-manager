local promise = gpm.promise
local string = string
local fs = gpm.fs

local debug_fempty = debug.fempty
local util_CRC = util.CRC
local type = gpm.type

module( "gpm.sources.zip", package.seeall )

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

Import = promise.Async( function( filePath, parentPackage )
    local fileClass = fs.Open( filePath, "rb", "GAME" )
    if not fileClass then return promise.Reject( "file not found" ) end

    local files = {}
    for filePath, content in IterateZipFiles( fileClass ) do
        files[ filePath ] = content
        print( filePath, content )
    end

    fileClass:Close()

    for k, v in pairs( files ) do
        print( k, v, #v )
    end

    -- if not packageInfo then return ErrorNoHaltWithStack( "package.lua not found" ) end
    -- if not packageInfo.main or not files[ packageInfo.main ] then
    --     return ErrorNoHaltWithStack( "no main file provided" )
    -- end

    -- packageInfo.ImportedFrom = "ZIP"
    -- packageInfo.ImportedExtra = nil

    -- local main = files[ packageInfo.main ]
    -- return gpm.packages.Initialize( packageInfo, main, files )

end )
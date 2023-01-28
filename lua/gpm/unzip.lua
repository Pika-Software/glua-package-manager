local CRC = util.CRC
local tostring = tostring
local emptyFunc = debug.fempty

module("gpm.unzip", package.seeall)

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
            if data and tostring( crc ) ~= CRC( data ) then
                data = nil
            end
        end

        return fileName, data
    end
end

-- local function SearchCentralDir(f)
--     local maxBack = 0xFFFF
--     local fileSize = f:Size()
--     if fileSize == 0 then return false end

--     if maxBack > fileSize then maxBack = fileSize end

--     f:Seek(fileSize - maxBack)

--     for _ = 1, 64 do -- just in case
--         local buff = f:Read(BUFF_SIZE + 4)
--         if not buff then break end

--         for i = 1, #buff do
--             if buff[i] == "\x50" and
--                buff[i + 1] == "\x4b" and
--                buff[i + 2] == "\x05" and
--                buff[i + 3] == "\x06"
--             then
--                 return i - 1
--             end
--         end

--         f:Seek(f:Tell() - 4)
--     end

--     return false
-- end

local function read(f)
    -- local t1 = SysTime()
    -- for fileName, func in package.GetLuaFuncs( util.IterateZipFiles(f) ) do
    --     print(fileName)
    --     if fileName == "package.lua" then
    --         PrintTable(func())
    --     end
    -- end
    -- local t2 = SysTime()

    -- print("" .. math.Round((t2 - t1) * 1000, 4) .. " ms")

    local files, dirs = file.Find("lua/gm_import/*", "GAME")
    PrintTable(dirs)

    PrintTable(files)
    -- local files = {}

    -- while f:Read(4) == "PK\x03\x04" do
    --     f:Skip(4)
    --     if f:ReadUShort() ~= 0 then continue end
    --     f:Skip(4)
    --     local crc = f:ReadULong()
    --     local compressedSize = f:ReadULong()
    --     f:Skip(4)
    --     local fileNameLen = f:ReadUShort()
    --     local extraLen = f:ReadUShort()
    --     local fileName = f:Read(fileNameLen)
    --     f:Skip(extraLen)

    --     files[fileName] = f:Read(compressedSize)
    -- end

    -- for k, v in pairs(files) do
    --     print(("====== %-40s ======"):format(k))
    --     print(v)
    --     print(string.rep("=", 14 + 40))
    -- end
    -- local centralPos = SearchCentralDir(f)
    -- assert(centralPos, "failed to find zip signature")

    -- f:Seek(centralPos)
    -- f:Skip(4 + 2 + 2) -- skip signature, number of disk, number of disk with cd
    -- local numEntry = f:ReadUShort()
    -- assert(numEntry == f:ReadUShort(), "no zip span allowed here")

    -- local centralDirSize = f:ReadULong()
    -- local centralDirOffset = f:ReadULong()
    -- local comment = f:Read(f:ReadUShort())

    -- f:Seek(centralPos - centralDirSize)

    -- local files = {}
    -- for i = 1, numEntry do
    --     assert(f:Read(4) == "\x50\x4b\x01\x02", "invalid zip header")
    --     local versionMadeBy = f:ReadUShort()
    --     local versionNeeded = f:ReadUShort()

    --     local bitflag = f:ReadUShort()
    --     local compression_method = f:ReadUShort()
    --     f:Skip(4)
    --     local crc = f:ReadULong()
    --     local compressedSize = f:ReadULong()
    --     local uncompressedSize = f:ReadULong()
    --     local filenameLen = f:ReadUShort()
    --     local extraLen = f:ReadUShort()
    --     local commentLen = f:ReadUShort()
    --     local diskNum = f:ReadUShort()
    --     local internalFileAttr = f:ReadUShort()
    --     local externalFileAttr = f:ReadULong()
    --     local relativeOffset = f:ReadULong()
    --     local fileName = f:Read(filenameLen)
    --     local extra = f:Read(extraLen)
    --     local comment = f:Read(commentLen)

    --     print(fileName, internalFileAttr, externalFileAttr)
    -- end

    -- local signature = f:Read(4)
    -- assert(signature == "PK\x03\x04", "not a zip")

    -- local version = f:ReadUShort() -- 20
    -- local bitflag = f:ReadUShort() -- 0
    -- local compression_method = f:ReadUShort() -- 0
    -- local last_mod_time = f:ReadUShort() -- 40745
    -- local last_mod_date = f:ReadUShort() -- 22075
    -- local crc32 = f:ReadULong() -- 0
    -- local comp_size = f:ReadULong() -- 0
    -- local uncomp_size = f:ReadULong() -- 0
    -- local filename_lenght = f:ReadUShort()
    -- local extra_field_lenght = f:ReadUShort()
    -- local filename = f:Read(filename_lenght) -- lua/
    -- local extra = f:Read(extra_field_lenght) -- nil

    -- assert(compression_method == 0, "compressed zip not supported")

    -- print(bit.tohex(f:ReadULong()))
end

concommand.Add("unzip", function()
    local f = file.Open("test.dat", "rb", "DATA")
    assert(f, "no file")

    xpcall(read, ErrorNoHaltWithStack, f)

    f:Close()
end)


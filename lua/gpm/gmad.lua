-- Libraries
local string = string
local file = file
local util = util

-- Variables
local setmetatable = setmetatable
local ArgAssert = ArgAssert
local tonumber = tonumber
local os_time = os.time
local assert = assert
local ipairs = ipairs

module( "gpm.gmad" )

GMA = GMA or {}
GMA.__index = GMA

GMA.Identity = "GMAD"
GMA.Version = 3

function GMA:__tostring()
    return "GMA File \'" .. ( self:GetTitle() or "No Name" ) .. "\'"
end

-- File Metadata
function GMA:GetMetadata()
    return self.Metadata
end

-- Title
function GMA:GetTitle()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.title
end

function GMA:SetTitle( title )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( title, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.title = title
end

-- Description
function GMA:GetDescription()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.description
end

function GMA:SetDescription( description )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( description, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.description = description
end

-- Author
function GMA:GetAuthor()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.author
end

function GMA:SetAuthor( author )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( author, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.author = author
end

-- Required content
function GMA:GetRequiredContent()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.requiredContent
end

function GMA:AddRequiredContent( contentName )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( contentName, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    local requiredContent = metadata.requiredContent
    requiredContent[ #requiredContent + 1 ] = contentName
end

function GMA:ClearRequiredContent()
    assert( self.WriteMode, "To change a gmad file, write mode is required." )

    local metadata = self.Metadata
    if not metadata then return end

    local requiredContent = metadata.requiredContent
    for number in pairs( requiredContent ) do
        requiredContent[ number ] = nil
    end
end

-- File timestamp
function GMA:GetTimestamp()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.fileTimestamp
end

-- Files
function GMA:GetFiles()
    return self.Files
end

function GMA:GetFile( number )
    ArgAssert( number, 1, "number" )

    local files = self:GetFiles()
    if not files then return end

    return files[ number ]
end

function GMA:AddFile( filePath, content )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( filePath, 1, "string" )
    ArgAssert( content, 2, "string" )

    local files = self:GetFiles()
    if not files then return end

    files[ #files + 1 ] = {
        ["size"] = string.len( content ),
        ["crc"] = util.CRC( content ),
        ["content"] = content,
        ["path"] = filePath
    }
end

function GMA:AddFolder( filePath, gamePath )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( filePath, 1, "string" )
    ArgAssert( gamePath, 2, "string" )

    local files = self:GetFiles()
    if not files then return end

    local files, folders = file.Find( filePath .. "/*", gamePath )
    for _, folderName in ipairs( folders ) do
        folderName = filePath .. "/" .. folderName
        self:AddFolder( folderName, gamePath )
    end

    for _, fileName in ipairs( files ) do
        fileName = filePath .. "/" .. fileName
        local content = file.Read( fileName, gamePath )
        if not content then continue end
        self:AddFile( fileName, content )
    end
end

function GMA:ClearFiles()
    local files = self:GetFiles()
    if not files then return end

    for number in pairs( files ) do
        files[ number ] = nil
    end
end

function GMA:ReadFile( number )
    local files = self.Files
    if not files then return end

    local entry = files[ number ]
    if not entry then return end

    local content = entry.content
    if content then return content end

    local metadata = self.Metadata
    if not metadata then return end

    local filesPos = metadata.filesPos
    if not filesPos then return end

    local fileClass = self.File
    if not fileClass then return end

    fileClass:Seek( filesPos + entry.Offset )
    content = fileClass:Read( entry.size )
    entry.content = content
    return content
end

function GMA:ReadAllFiles()
    local fileClass = self.File
    if not fileClass then return end

    local metadata = self.Metadata
    if not metadata then return end

    local filesPos = metadata.filesPos
    if not filesPos then return end

    local files = self.Files
    if not files then return end

    for _, entry in ipairs( files ) do
        if entry.content then continue end
        if not fileClass then continue end

        fileClass:Seek( filesPos + entry.Offset )
        entry.content = fileClass:Read( entry.Size )
    end

    return files
end

function GMA:CheckCRC()
    local files = self:GetFiles()
    if not files then return true end

    for _, entry in ipairs( files ) do
        local crc = entry.crc
        if not crc then continue end

        local content = entry.content
        if not content then continue end

        if util.CRC( content ) ~= crc then
            return false
        end
    end

    return true
end

-- Saving & closing
function GMA:Close()
    local fileClass = self.File
    if not fileClass then return end

    if self.WriteMode then
        fileClass:Write( self.Identity )
        fileClass:WriteByte( self.Version )

        fileClass:WriteULong( 0 )
        fileClass:WriteULong( 0 )

        fileClass:WriteULong( os_time() )
        fileClass:WriteULong( 0 )

        local requiredContent = self:GetRequiredContent()
        if requiredContent ~= nil and #requiredContent > 0 then
            for _, content in ipairs( requiredContent ) do
                fileClass:WriteString( content )
            end
        else
            fileClass:WriteByte( 0 )
        end

        fileClass:WriteString( self:GetTitle() )
        fileClass:WriteString( self:GetDescription() )
        fileClass:WriteString( self:GetAuthor() )

        fileClass:WriteLong( 1 )

        for num, entry in ipairs( self:GetFiles() ) do
            fileClass:WriteULong( num )
            fileClass:WriteString( entry.path )
            fileClass:WriteULong( entry.size )
            fileClass:WriteULong( 0 )
            fileClass:WriteULong( tonumber( entry.crc ) )
        end

        fileClass:WriteULong( 0 )

        for _, entry in ipairs( self:GetFiles() ) do
            fileClass:Write( entry.content )
        end

        fileClass:Flush()
    end

    fileClass:Close()
end

-- Metadata parsing
function Parse( fileClass )
    if fileClass:Read( 4 ) ~= GMA.Identity then return end

    local version = fileClass:ReadByte()
    if ( version > GMA.Version ) then return end

    local gmad = {}

    gmad.fileVersion = version

    fileClass:Skip( 8 )
    gmad.fileTimestamp = fileClass:ReadULong()
    fileClass:Skip( 4 )

    if version > 1 then
        local required = {}

        while not fileClass:EndOfFile() do
            local content = fileClass:ReadString()
            if not content then break end
            required[ #required + 1 ] = content
        end

        gmad.requiredContent = required
    end

    -- Addon info
    gmad.title = fileClass:ReadString()
    gmad.description = fileClass:ReadString()
    gmad.author = fileClass:ReadString()

    -- Addon version (unused)
    gmad.version = fileClass:ReadLong()

    -- Files
    local fileNum = 1
    local offset = 0
    gmad.files = {}

    while fileClass:ReadULong() ~= 0 do
        local entry = {}
        entry.path = fileClass:ReadString()
        entry.size = fileClass:ReadULong()
        fileClass:Skip( 4 )

        entry.crc = fileClass:ReadULong()
        entry.offset = offset

        gmad.files[ fileNum ] = entry
        offset = offset + entry.size
        fileNum = fileNum + 1
    end

    gmad.filesPos = fileClass:Tell()

    local description = gmad.description
    if ( description ~= nil ) then
        gmad.description = util.JSONToTable( description ) or description
    end

    return gmad
end

function Read( fileClass )
    if not fileClass then return end

    local metadata = Parse( fileClass )
    if not metadata then return end

    local instance = setmetatable( {}, GMA )
    instance.Metadata = metadata
    instance.File = fileClass

    instance.Files = metadata.files
    metadata.files = nil

    return instance
end

function Open( filePath, gamePath )
    local fileClass = file.Open( filePath, "rb", gamePath )
    if not fileClass then return end

    local instance = Read( fileClass )
    if not instance then
        fileClass:Close()
        return
    end

    util.NextTick( fileClass.Close, fileClass )

    return instance
end

function Write( filePath )
    local fileClass = file.Open( filePath, "wb", "DATA" )
    if not fileClass then return end

    local instance = setmetatable( {}, GMA )
    instance.File = fileClass
    instance.WriteMode = true
    instance.Files = {}

    instance.Metadata = {
        ["title"] = "Garry\'s Mod Addon",
        ["description"] = "description",
        ["author"] = "Pika Software",
        ["requiredContent"] = {},
        ["files"] = {}
    }

    return instance
end

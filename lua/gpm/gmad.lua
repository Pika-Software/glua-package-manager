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

-- GMAD Metatable
GMAD = GMAD or {}
GMAD.__index = GMAD

GMAD.Identity = "GMAD"
GMAD.Version = 3

function GMAD:Metadata()
    return self.Metadata
end

function GMAD:GetTitle()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.Title
end

function GMAD:SetTitle( str )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( str, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end
    metadata.Title = str
end

function GMAD:GetDescription()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.Description
end

function GMAD:SetDescription( str )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( str, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end
    metadata.Description = str
end

function GMAD:GetAuthor()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.Author
end

function GMAD:SetAuthor( str )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( str, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end
    metadata.Author = str
end

function GMAD:GetRequiredContent()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.RequiredContent
end

function GMAD:AddRequiredContent( str )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( str, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end
    local requiredContent = metadata.RequiredContent
    requiredContent[ #requiredContent + 1 ] = str
end

function GMAD:ClearRequiredContent()
    assert( self.WriteMode, "To change a gmad file, write mode is required." )

    local metadata = self.Metadata
    if not metadata then return end

    local requiredContent = metadata.RequiredContent
    for number in pairs( requiredContent ) do
        requiredContent[ num ] = nil
    end
end

function GMAD:GetTimestamp()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.Timestamp
end

function GMAD:GetFiles()
    local metadata = self.Metadata
    if not metadata then return end

    local files = metadata.Files
    if not files then return end

    return files
end

function GMAD:GetFile( fileID )
    ArgAssert( fileID, 1, "number" )

    local files = self:GetFiles()
    if not files then return end

    return files[ fileID ]
end

function GMAD:AddFile( filePath, content )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( filePath, 1, "string" )
    ArgAssert( content, 2, "string" )

    local files = self:GetFiles()
    if not files then return end

    files[ #files + 1 ] = {
        ["Size"] = string.len( content ),
        ["CRC"] = util.CRC( content ),
        ["Content"] = content,
        ["Path"] = filePath
    }
end

function GMAD:AddFolder( filePath, gamePath )
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
        self:AddFile( fileName, file.Read( fileName, gamePath ) )
    end
end

function GMAD:ClearFiles()
    local files = self:GetFiles()
    if not files then return end

    for number in pairs( files ) do
        files[ number ] = nil
    end
end

function GMAD:ReadFile( fileID )
    local entry = self:GetFile( fileID )
    if not entry then return end

    local content = entry.Content
    if content then return content end

    local fileClass = self.File
    if not fileClass then return end

    fileClass:Seek( self.Metadata.DataPos + entry.Offset )
    content = fileClass:Read( entry.Size )
    entry.Content = content
    return content
end

function GMAD:ReadAllFiles()
    local files = self:GetFiles()
    if not files then return end

    local dataPos = self.Metadata.DataPos
    local fileClass = self.File

    for _, entry in ipairs( files ) do
        if entry.Content then continue end
        if not fileClass then continue end

        fileClass:Seek( dataPos + entry.Offset )
        entry.Content = fileClass:Read( entry.Size )
    end

    return files
end

function GMAD:Close()
    local fileClass = self.File
    if not fileClass then return end

    if self.WriteMode then
        fileClass:Write( self.Identity )
        fileClass:WriteByte( GMAD.Version )

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
            fileClass:WriteString( entry.Path )
            fileClass:WriteULong( entry.Size )
            fileClass:WriteULong( 0 )
            fileClass:WriteULong( tonumber( entry.CRC ) )
        end

        fileClass:WriteULong( 0 )

        for num, entry in ipairs( self:GetFiles() ) do
            fileClass:Write( entry.Content )
        end

        fileClass:Flush()
    end

    fileClass:Close()
end

function Parse( fileClass )
    local gmad = {}
    if fileClass:Read( 4 ) ~= GMAD.Identity then return gmad end

    gmad.Version = fileClass:ReadByte()
    if ( gmad.Version > GMAD.Version ) then return gmad end

    fileClass:Skip( 8 )
    gmad.Timestamp = fileClass:ReadULong()
    fileClass:Skip( 4 )

    if gmad.Version > 1 then
        local required = {}

        while not fileClass:EndOfFile() do
            local content = fileClass:ReadString()
            if not content then break end
            required[ #required + 1 ] = content
        end

        gmad.RequiredContent = required
    end

    gmad.Title = fileClass:ReadString()
    gmad.Description = fileClass:ReadString()
    gmad.Author = fileClass:ReadString()

    gmad.AddonVersion = fileClass:ReadLong()

    local fileNum = 1
    local offset = 0
    gmad.Files = {}

    while fileClass:ReadULong() ~= 0 do
        local entry = {}
        entry.Path = fileClass:ReadString()
        entry.Size = fileClass:ReadULong()
        fileClass:Skip( 4 )

        entry.CRC = fileClass:ReadULong()
        entry.Number = fileNum
        entry.Offset = offset

        gmad.Files[ fileNum ] = entry
        offset = offset + entry.Size
        fileNum = fileNum + 1
    end

    gmad.DataPos = fileClass:Tell()

    local jsonData = util.JSONToTable( gmad.Description )
    gmad.Description = jsonData or gmad.Description

    return gmad
end

function Open( filePath, gamePath )
    local fileClass = file.Open( filePath, "rb", gamePath )
    if not fileClass then return end

    local instance = setmetatable( {}, GMAD )
    instance.Metadata = Parse( fileClass )
    instance.File = fileClass

    -- Close file in next tick
    util.NextTick( instance.Close, instance )

    return instance
end

function Create( filePath )
    local fileClass = file.Open( filePath, "wb", "DATA" )
    if not fileClass then return end

    local instance = setmetatable( {}, GMAD )
    instance.File = fileClass
    instance.WriteMode = true
    instance.Metadata = {
        ["Title"] = "Garry\'s Mod Addon",
        ["Description"] = "description",
        ["Author"] = "Pika Software",
        ["RequiredContent"] = {},
        ["Files"] = {}
    }

    return instance
end

-- Libraries
local utils = gpm.utils
local paths = gpm.paths
local file = file

module( "gpm.pkgf", package.seeall )

PKG = PKG or {}
PKG.__index = PKG

PKG.Identity = "GPKG"
PKG.Version = 1

function PKG:__tostring()
    local status = "stopped"
    if self.File ~= nil then
        status = self.WriteMode and "writing" or "reading"
    end

    return "Package File " .. self:GetName() .. "@" .. utils.Version( self:GetVersion() ) .. " [" .. status  .. "]"
end

-- Package name
function PKG:GetName()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.name
end

function PKG:SetName( name )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( name, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.name = name
end

-- Package version
function PKG:GetVersion()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.version
end

function PKG:SetVersion( version )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( version, 1, "number" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.version = version
end

-- Package author
function PKG:GetAuthor()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.author
end

function PKG:SetAuthor( author )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( author, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.author = author
end

-- Package main file
function PKG:GetMainFile()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.main
end

function PKG:SetMainFile( filePath )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( filePath, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.main = paths.Fix( filePath )
end

-- File timestamp
function PKG:GetTimestamp()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.timestamp
end

-- Files
function PKG:GetFiles()
    local metadata = self.Metadata
    if not metadata then return end

    local files = metadata.Files
    if not files then return end

    return files
end

function PKG:GetFile( number )
    ArgAssert( number, 1, "number" )

    local files = self:GetFiles()
    if not files then return end

    return files[ number ]
end

function PKG:AddFile( filePath, content )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( filePath, 1, "string" )
    ArgAssert( content, 2, "string" )

    local files = self:GetFiles()
    if not files then return end

    files[ #files + 1 ] = {
        ["size"] = string.len( content ),
        ["content"] = content,
        ["path"] = filePath
    }
end

function PKG:AddFolder( filePath, gamePath )
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

function PKG:ClearFiles()
    local files = self:GetFiles()
    if not files then return end

    for number in pairs( files ) do
        files[ number ] = nil
    end
end

function GMA:ReadFile( number )
    local metadata = self.Metadata
    if not metadata then return end

    local files = metadata.Files
    if not files then return end

    local entry = files[ number ]
    if not entry then return end

    local content = entry.content
    if content then return content end

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

    local files = metadata.Files
    if not files then return end

    for _, entry in ipairs( files ) do
        if entry.content then continue end
        if not fileClass then continue end

        fileClass:Seek( filesPos + entry.Offset )
        entry.content = fileClass:Read( entry.Size )
    end

    return files
end

function PKG:Close()
    local fileClass = self.File
    if not fileClass then return end

    if self.WriteMode then
        fileClass:WriteString( self.Identity )
        fileClass:WriteByte( self.Version )

        -- Timestamp
        fileClass:WriteULong( os.time() )

        -- Package name & main file path
        fileClass:WriteString( self:GetName() )
        fileClass:WriteString( self:GetMainFile() )

        -- Package version
        fileClass:WriteULong( self:GetVersion() )

        -- Client & server bools
        fileClass:WriteByte( self:GetClient() )
        fileClass:WriteByte( self:GetServer() )

        -- Package author
        fileClass:WriteString( self:GetAuthor() )

        -- Package files
        for num, entry in ipairs( self:GetFiles() ) do
            fileClass:WriteULong( num )
            fileClass:WriteULong( entry.size )
            fileClass:WriteString( entry.Path )
        end

        fileClass:WriteULong( 0 )

        -- Writing files content
        for _, entry in ipairs( self:GetFiles() ) do
            fileClass:Write( entry.content )
        end

        fileClass:Flush()
    end

    fileClass:Close()
end

function Parse( fileClass )
    if not fileClass then return end

    local identity = PKG.Identity
    if fileClass:Read( #identity ) ~= identity then return end

    local version = fileClass:ReadByte()
    if version > PKG.Version then return end

    local pkg = {}

    pkg.fileVersion = version
    pkg.fileTimestamp = fileClass:ReadULong()

    -- Package name & main file path
    pkg.name = fileClass:ReadString()
    pkg.main = fileClass:ReadString()

    -- Package version
    pkg.version = fileClass:ReadULong()

    -- Client & server bools
    pkg.client = tobool( fileClass:Read( 1 ) )
    pkg.server = tobool( fileClass:Read( 1 ) )

    -- Package author
    pkg.author = fileClass:ReadString()

    -- Package files
    local fileNum = 1
    local offset = 0
    pkg.files = {}

    while fileClass:ReadULong() ~= 0 do
        local entry = {}
        entry.size = fileClass:ReadULong()
        entry.path = fileClass:ReadString()
        entry.offset = offset

        pkg.files[ fileNum ] = entry
        offset = offset + entry.size
        fileNum = fileNum + 1
    end

    fileClass:WriteULong( 0 )

    pkg.filesPos = fileClass:Tell()
end

function Read( fileClass )
    if not fileClass then return end

    local instance = setmetatable( {}, PKG )
    instance.Metadata = Parse( fileClass )
    instance.File = fileClass

    -- Close file in next tick
    util.NextTick( instance.Close, instance )

    return instance
end

function Open( filePath, gamePath )
    return Read( file.Open( filePath, "rb", gamePath ) )
end

function Write( filePath )
    local fileClass = file.Open( filePath, "wb", "DATA" )
    if not fileClass then return end

    local instance = setmetatable( {}, PKG )
    instance.File = fileClass
    instance.WriteMode = true
    instance.Metadata = {}

    return instance
end

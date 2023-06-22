-- Libraries
local string = string
local table = table
local file = file
local util = util

-- Variables
local setmetatable = setmetatable
local ArgAssert = gpm.ArgAssert
local moonloader = moonloader
local tonumber = tonumber
local logger = gpm.Logger
local os_time = os.time
local paths = gpm.paths
local assert = assert
local ipairs = ipairs
local error = error

module( "gmad" )

-- TypeExists( any )
do

    local types = {
        "gamemode",
        "map",
        "weapon",
        "vehicle",
        "npc",
        "entity",
        "tool",
        "effects",
        "model",
        "servercontent"
    }

    function TypeExists( any )
        return table.HasIValue( types, any )
    end

end

-- TagExists( any )
do

    local tags = {
        "fun",
        "roleplay",
        "scenic",
        "movie",
        "realism",
        "cartoon",
        "water",
        "comic",
        "build"
    }

    function TagExists( any )
        return table.HasIValue( tags, any )
    end

end

-- IsAllowedFilePath( filePath )
do

    local wildcard = {
        "lua/*.lua",
        "scenes/*.vcd",
        "particles/*.pcf",
        "resource/fonts/*.ttf",
        "scripts/vehicles/*.txt",
        "resource/localization/*/*.properties",
        "maps/*.bsp",
        "maps/*.nav",
        "maps/*.ain",
        "maps/thumb/*.png",
        "sound/*.wav",
        "sound/*.mp3",
        "sound/*.ogg",
        "materials/*.vmt",
        "materials/*.vtf",
        "materials/*.png",
        "materials/*.jpg",
        "materials/*.jpeg",
        "models/*.mdl",
        "models/*.vtx",
        "models/*.phy",
        "models/*.ani",
        "models/*.vvd",
        "gamemodes/*/*.txt",
        "gamemodes/*/*.fgd",
        "gamemodes/*/logo.png",
        "gamemodes/*/icon24.png",
        "gamemodes/*/gamemode/*.lua",
        "gamemodes/*/entities/effects/*.lua",
        "gamemodes/*/entities/weapons/*.lua",
        "gamemodes/*/entities/entities/*.lua",
        "gamemodes/*/backgrounds/*.png",
        "gamemodes/*/backgrounds/*.jpg",
        "gamemodes/*/backgrounds/*.jpeg",
        "gamemodes/*/content/models/*.mdl",
        "gamemodes/*/content/models/*.vtx",
        "gamemodes/*/content/models/*.phy",
        "gamemodes/*/content/models/*.ani",
        "gamemodes/*/content/models/*.vvd",
        "gamemodes/*/content/materials/*.vmt",
        "gamemodes/*/content/materials/*.vtf",
        "gamemodes/*/content/materials/*.png",
        "gamemodes/*/content/materials/*.jpg",
        "gamemodes/*/content/materials/*.jpeg",
        "gamemodes/*/content/scenes/*.vcd",
        "gamemodes/*/content/particles/*.pcf",
        "gamemodes/*/content/resource/fonts/*.ttf",
        "gamemodes/*/content/scripts/vehicles/*.txt",
        "gamemodes/*/content/resource/localization/*/*.properties",
        "gamemodes/*/content/maps/*.bsp",
        "gamemodes/*/content/maps/*.nav",
        "gamemodes/*/content/maps/*.ain",
        "gamemodes/*/content/maps/thumb/*.png",
        "gamemodes/*/content/sound/*.wav",
        "gamemodes/*/content/sound/*.mp3",
        "gamemodes/*/content/sound/*.ogg"
    }

    -- Formatting to lua patterns
    for index, str in ipairs( wildcard ) do
        wildcard[ index ] = string.Replace( string.Replace( str, ".", "%." ), "*", ".+" )
    end

    function IsAllowedFilePath( filePath )
        local isValid = false
        for _, pattern in ipairs( wildcard ) do
            if not string.find( filePath, pattern ) then continue end
            isValid = true
            break
        end

        return isValid
    end

end

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
    return metadata.Title
end

function GMA:SetTitle( title )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( title, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.Title = title
end

-- Description
function GMA:GetDescription()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.Description
end

function GMA:SetDescription( description )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( description, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end
    metadata.Description = description
end

-- Author
function GMA:GetAuthor()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.Author
end

function GMA:SetAuthor( author )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( author, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    metadata.Author = author
end

-- Required content
function GMA:GetRequiredContent()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.RequiredContent
end

function GMA:AddRequiredContent( contentName )
    assert( self.WriteMode, "To change a gmad file, write mode is required." )
    ArgAssert( contentName, 1, "string" )

    local metadata = self.Metadata
    if not metadata then return end

    local requiredContent = metadata.RequiredContent
    requiredContent[ #requiredContent + 1 ] = contentName
end

function GMA:ClearRequiredContent()
    assert( self.WriteMode, "To change a gmad file, write mode is required." )

    local metadata = self.Metadata
    if not metadata then return end

    table.Empty( metadata.RequiredContent )
end

-- File timestamp
function GMA:GetTimestamp()
    local metadata = self.Metadata
    if not metadata then return end
    return metadata.FileTimestamp
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

    if string.GetExtensionFromFilename( filePath ) == "moon" then
        if not moonloader then
            error( "Attempting to compile a Moonscript file fails, install gm_moonloader and try again, https://github.com/Pika-Software/gm_moonloader." )
        end

        content = moonloader.ToLua( content )
        if not content then
            error( "Compiling the Moonscript '" .. filePath .. "' file into a Lua file failed, GMA file: " .. self.FilePath )
        end

        filePath = paths.FormatToLua( filePath )
    end

    if not IsAllowedFilePath( filePath ) then
        logger:Warn( "File '%s' was not written to GMA because its path is not valid.", filePath )
        return
    end

    ArgAssert( content, 2, "string" )

    local files = self:GetFiles()
    if not files then return end

    for number, entry in ipairs( files ) do
        if entry.Path == filePath then
            table.remove( files, number )
            break
        end
    end

    files[ #files + 1 ] = {
        ["Size"] = string.len( content ),
        ["CRC"] = util.CRC( content ),
        ["Content"] = content,
        ["Path"] = filePath
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
    table.Empty( files )
end

function GMA:ReadFile( number )
    local files = self.Files
    if not files then return end

    local entry = files[ number ]
    if not entry then return end

    local content = entry.Content
    if content then return content end

    local metadata = self.Metadata
    if not metadata then return end

    local filesPos = metadata.FilesPos
    if not filesPos then return end

    local fileClass = self.File
    if not fileClass then return end

    fileClass:Seek( filesPos + entry.Offset )
    content = fileClass:Read( entry.Size )
    entry.Content = content
    return content
end

function GMA:ReadAllFiles()
    local fileClass = self.File
    if not fileClass then return end

    local metadata = self.Metadata
    if not metadata then return end

    local filesPos = metadata.FilesPos
    if not filesPos then return end

    local files = self.Files
    if not files then return end

    for _, entry in ipairs( files ) do
        if entry.Content then continue end
        if not fileClass then continue end

        fileClass:Seek( filesPos + entry.Offset )
        entry.Content = fileClass:Read( entry.Size )
    end

    return files
end

function GMA:CheckCRC()
    local files = self:GetFiles()
    if not files then return true end

    for _, entry in ipairs( files ) do
        local crc = entry.CRC
        if not crc then continue end

        local content = entry.Content
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
            fileClass:WriteString( entry.Path )
            fileClass:WriteULong( entry.Size )
            fileClass:WriteULong( 0 )
            fileClass:WriteULong( tonumber( entry.CRC ) )
        end

        fileClass:WriteULong( 0 )

        for _, entry in ipairs( self:GetFiles() ) do
            fileClass:Write( entry.Content )
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

    local metadata = {
        ["FileVersion"] = version
    }

    fileClass:Skip( 8 )
    metadata.FileTimestamp = fileClass:ReadULong()
    fileClass:Skip( 4 )

    if version > 1 then
        local required = {}

        while not fileClass:EndOfFile() do
            local content = fileClass:ReadString()
            if not content then break end
            required[ #required + 1 ] = content
        end

        metadata.RequiredContent = required
    end

    -- Addon info
    metadata.Title = fileClass:ReadString()
    metadata.Description = fileClass:ReadString()
    metadata.Author = fileClass:ReadString()

    -- Addon version (unused)
    metadata.Version = fileClass:ReadLong()

    -- Files
    local fileNum = 1
    local offset = 0
    metadata.Files = {}

    while fileClass:ReadULong() ~= 0 do
        local entry = {}
        entry.Path = fileClass:ReadString()
        entry.Size = fileClass:ReadULong()
        fileClass:Skip( 4 )

        entry.CRC = fileClass:ReadULong()
        entry.Offset = offset

        metadata.Files[ fileNum ] = entry
        offset = offset + entry.Size
        fileNum = fileNum + 1
    end

    metadata.FilesPos = fileClass:Tell()

    return metadata
end

function Open( fileClass )
    if not fileClass then return end

    local metadata = Parse( fileClass )
    if not metadata then return end

    local instance = setmetatable( {
        ["Files"] = table.Merge( {}, metadata.Files ),
        ["Metadata"] = metadata,
        ["File"] = fileClass
    }, GMA )

    metadata.Files = nil

    return instance
end

function Read( filePath, gamePath )
    local fileClass = file.Open( filePath, "rb", gamePath )
    if not fileClass then return end

    local instance = Open( fileClass )
    if not instance then
        fileClass:Close()
        return
    end

    util.NextTick( function()
        if not fileClass then return end
        fileClass:Close()
    end )

    return instance
end

function Write( filePath )
    local fileClass = file.Open( filePath, "wb", "DATA" )
    if not fileClass then return end

    return setmetatable( {
        ["FilePath"] = filePath,
        ["WriteMode"] = true,
        ["File"] = fileClass,
        ["Files"] = {},
        ["Metadata"] = {
            ["Title"] = "Garry\'s Mod Addon",
            ["Description"] = "Builded by GLua Package Manager",
            ["Author"] = "GLua Package Manager",
            ["RequiredContent"] = {}
        }
    }, GMA )
end
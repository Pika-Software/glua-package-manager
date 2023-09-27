if SERVER
    AddCSLuaFile!

import string, table, ArgAssert, Table from gpm
lib = Table gpm, "gmad"
error = error
type = type

lib.VERSION = "1.0.0"

do

    table_HasIValue = table.HasIValue

    do

        types = {
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

        lib.TypeExists = ( any ) ->
            return table_HasIValue( types, any )

    do

        tags = {
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

        lib.TagExists = ( any ) ->
            return table_HasIValue( tags, any )


lib_IsAllowedFilePath = nil
do

    wildcard = {
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
    do
        string_Replace = string.Replace
        for index, str in ipairs( wildcard )
            wildcard[ index ] = string_Replace( string_Replace( str, ".", "%." ), "*", ".+" )

    string_find = string.find
    lib_IsAllowedFilePath = ( filePath ) ->
        for pattern in *wildcard
            if string_find( filePath, pattern )
                return true
        return false
    lib.IsAllowedFilePath = lib_IsAllowedFilePath

do

    File = FindMetaTable "File"

    File_WriteString = File.WriteString
    File_WriteUInt64 = File.WriteUInt64
    File_ReadString = File.ReadString
    File_ReadUInt64 = File.ReadUInt64
    File_WriteULong = File.WriteULong
    File_EndOfFile = File.EndOfFile
    File_ReadULong = File.ReadULong
    File_WriteLong = File.WriteLong
    File_WriteByte = File.WriteByte
    File_ReadByte = File.ReadByte
    File_ReadLong = File.ReadLong
    File_Write = File.Write
    File_Close = File.Close
    File_Seek = File.Seek
    File_Read = File.Read
    File_Tell = File.Tell

    string_lower = string.lower
    table_Empty = table.Empty
    string_len = string.len
    file_Open = file.Open
    tostring = tostring
    tonumber = tonumber

    class GMA
        Identity: "GMAD"
        Version: 3

        __tostring: =>
            return "GMA File \'" .. @title .. "\'"

        new: =>
            @Title = "unknown"
            @Author = "unknown"
            @Description = "unknown"
            @AddonVersion = 1
            @Timestamp = 0
            @Required = {}
            @SteamID = ""
            @Files = {}

        GetTitle: =>
            return @Title

        SetTitle: ( str ) =>
            ArgAssert( str, 1, "string" )
            @Title = str

        GetAuthor: =>
            return @Author

        SetAuthor: ( str ) =>
            ArgAssert( str, 1, "string" )
            @Author = str

        GetDescription: =>
            return @Description

        SetDescription: ( str ) =>
            ArgAssert( str, 1, "string" )
            @Description = str

        GetAddonVersion: =>
            return @AddonVersion

        SetAddonVersion: ( int32 ) =>
            ArgAssert( int32, 1, "number" )
            @AddonVersion = int32

        GetTimestamp: =>
            return @Timestamp

        SetTimestamp: ( uint64 ) =>
            ArgAssert( uint64, 1, "number" )
            @Timestamp = uint64

        GetSteamID: =>
            return @SteamID

        SetSteamID: ( str ) =>
            ArgAssert( str, 1, "string" )
            @SteamID = str

        Open: ( filePath, gamePath, fileMode ) =>
            @Close!

            unless filePath
                filePath = @FilePath

            unless gamePath
                gamePath = @GamePath

            ArgAssert( filePath, 1, "string" )
            ArgAssert( gamePath, 2, "string" )

            fileHandle = file_Open( filePath, fileMode or "rb", gamePath )
            unless fileHandle
                error "File cannot be open."

            @FilePath = filePath
            @GamePath = gamePath
            @File = fileHandle

            if not fileMode or fileMode == "rb"
                @Parse!

            return fileHandle

        Close: =>
            fileHandle = @File
            if fileHandle
                File_Close( fileHandle )
                @File = nil
                return true
            return false

        Parse: =>
            fileHandle = @File
            unless fileHandle
                error "File is not oppened"

            if File_Read( fileHandle, 4 ) ~= @Identity
                error "File is not a gma"

            version = File_ReadByte( fileHandle )
            if version > @Version
                error "gma version is unsupported"

            @File = fileHandle
            @Version = version

            @SteamID = tostring( File_ReadUInt64( fileHandle ) )
            @Timestamp = File_ReadUInt64( fileHandle )

            if version > 1
                while not File_EndOfFile( fileHandle )
                    contentName = File_ReadString( fileHandle )
                    unless contentName
                        break
                    @Required[ contentName ] = true

            @Title = File_ReadString( fileHandle )
            @Description = File_ReadString( fileHandle )
            @Author = File_ReadString( fileHandle )

            @AddonVersion = File_ReadLong( fileHandle )

            files, offset = @Files, 0
            while not File_EndOfFile( fileHandle )
                index = File_ReadULong( fileHandle )
                if index == 0
                    break

                data = {
                    FilePath: File_ReadString( fileHandle ),
                    Position: offset
                }

                size = File_ReadUInt64( fileHandle )
                data.Size = size
                offset += size

                data.CRC = File_ReadULong( fileHandle )
                files[ index ] = data

            files.Pointer = File_Tell( fileHandle )

        Read: ( filePath, gamePath, readFiles ) =>
            table_Empty( @Required )
            table_Empty( @Files )

            @Open( filePath, gamePath )

            if readFiles
                @ReadFiles!
            @Close!

        VerifyCRC: =>
            for data in *@Files
                crc, content = data.CRC, data.Content
                if crc and content and crc ~= tonumber( util.CRC( content ) )
                    return false, data
            return true

        VerifyFiles: =>
            files = @Files
            if #files == 0
                return false, "unknown"

            for data in *files
                unless lib_IsAllowedFilePath( data.FilePath )
                    return false, data

            return true

        Write: ( filePath, gamePath, doCRCs ) =>
            ok, result = @VerifyFiles!
            unless ok
                error "'" .. result.FilePath .. "' file is not allowed by whitelist!"

            fileHandle = @Open( filePath, gamePath, "wb" )

            File_Write( fileHandle, @Identity )
            File_WriteByte( fileHandle, @Version )

            File_WriteUInt64( fileHandle, tonumber( @SteamID ) or 0 )
            File_WriteUInt64( fileHandle, @Timestamp or os.time() )

            hasRequired = false
            for contentName in pairs( @Required )
                File_WriteString( fileHandle, contentName )
                unless hasRequired
                    hasRequired = true

            unless hasRequired
                File_WriteByte( fileHandle, 0 )

            File_WriteString( fileHandle, @Title )
            File_WriteString( fileHandle, @Description )
            File_WriteString( fileHandle, @Author )

            File_WriteLong( fileHandle, @AddonVersion )

            files = @Files
            for index = 1, #files
                File_WriteULong( fileHandle, index )
                data = files[ index ]

                File_WriteString( fileHandle, string_lower( data.FilePath ) )
                File_WriteUInt64( fileHandle, data.Size )

                if doCRCs
                    File_WriteULong( fileHandle, tonumber( util.CRC( data.Content ) ) or 0 )
                else
                    File_WriteULong( fileHandle, 0 )

            File_WriteULong( fileHandle, 0 )

            for data in *files
                content = data.Content
                unless type( content ) == "string"
                    error "file empty"

                File_Write( fileHandle, content )

            @Close!

            return true

        ReadFile: ( index ) =>
            ArgAssert( index, 1, "number" )

            fileHandle = @File
            unless fileHandle
                error "File is not oppened"

            files = @Files
            data = files[ index ]
            unless data
                error "File is non exists."

            File_Seek( fileHandle, files.Pointer + data.Position )
            data.Content = File_Read( fileHandle, data.Size )
            return data

        ReadFiles: =>
            fileHandle = @File
            unless fileHandle
                error "File is not oppened"

            files = @Files
            pointer = files.Pointer
            for data in *files
                File_Seek( fileHandle, pointer + data.Position )
                data.Content = File_Read( fileHandle, data.Size )

            return files

        GetFile: ( index ) =>
            return @Files[ index ]

        AddFile: ( filePath, content ) =>
            ArgAssert( filePath, 1, "string" )
            ArgAssert( content, 2, "string" )
            files = @Files

            filePath = string_lower( filePath )
            table.RemoveByFunction( files, ( _, data ) ->
                return data.FilePath == filePath
            )

            files[ #files + 1 ] = {
                Size: string_len( content ),
                CRC: tonumber( util.CRC( content ) ) or 0,
                FilePath: filePath,
                Content: content
            }

        ClearFiles: =>
            table_Empty( @files )

        AddRequiredContent: ( contentName ) =>
            ArgAssert( contentName, 1, "string" )
            @requiredContent[ contentName ] = true

        RemoveRequiredContent: ( contentName ) =>
            ArgAssert( contentName, 1, "string" )
            @requiredContent[ contentName ] = nil

        ClearRequiredContent: =>
            table_Empty( @requiredContent )

lib.New = GMAD
return lib
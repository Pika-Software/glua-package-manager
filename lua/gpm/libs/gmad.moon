if SERVER
    AddCSLuaFile!

gpm_ArgAssert = gpm.ArgAssert
lib = gpm.Lib "gmad"
string = gpm.string
table = gpm.table
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
            gpm_ArgAssert( str, 1, "string" )
            @Title = str

        GetAuthor: =>
            return @Author

        SetAuthor: ( str ) =>
            gpm_ArgAssert( str, 1, "string" )
            @Author = str

        GetDescription: =>
            return @Description

        SetDescription: ( str ) =>
            gpm_ArgAssert( str, 1, "string" )
            @Description = str

        GetAddonVersion: =>
            return @AddonVersion

        SetAddonVersion: ( int32 ) =>
            gpm_ArgAssert( int32, 1, "number" )
            @AddonVersion = int32

        GetTimestamp: =>
            return @Timestamp

        SetTimestamp: ( uint64 ) =>
            gpm_ArgAssert( uint64, 1, "number" )
            @Timestamp = uint64

        GetSteamID: =>
            return @SteamID

        SetSteamID: ( str ) =>
            gpm_ArgAssert( str, 1, "string" )
            @SteamID = str

        Open: ( filePath, gamePath, fileMode ) =>
            @Close!

            unless filePath
                filePath = @FilePath

            unless gamePath
                gamePath = @GamePath

            gpm_ArgAssert( filePath, 1, "string" )
            gpm_ArgAssert( gamePath, 2, "string" )

            fileObject = file_Open( filePath, fileMode or "rb", gamePath )
            unless fileObject
                error "File cannot be open."

            @FilePath = filePath
            @GamePath = gamePath
            @File = fileObject

            if not fileMode or fileMode == "rb"
                @Parse!

            return fileObject

        Close: =>
            fileObject = @File
            if fileObject
                File_Close( fileObject )
                @File = nil
                return true
            return false

        Parse: =>
            fileObject = @File
            unless fileObject
                error "File is not oppened"

            if File_Read( fileObject, 4 ) ~= @Identity
                error "File is not a gma"

            version = File_ReadByte( fileObject )
            if version > @Version
                error "gma version is unsupported"

            @File = fileObject
            @Version = version

            @SteamID = tostring( File_ReadUInt64( fileObject ) )
            @Timestamp = File_ReadUInt64( fileObject )

            if version > 1
                while not File_EndOfFile( fileObject )
                    contentName = File_ReadString( fileObject )
                    unless contentName
                        break
                    @Required[ contentName ] = true

            @Title = File_ReadString( fileObject )
            @Description = File_ReadString( fileObject )
            @Author = File_ReadString( fileObject )

            @AddonVersion = File_ReadLong( fileObject )

            files, offset = @Files, 0
            while not File_EndOfFile( fileObject )
                index = File_ReadULong( fileObject )
                if index == 0
                    break

                data = {
                    FilePath: File_ReadString( fileObject ),
                    Position: offset
                }

                size = File_ReadUInt64( fileObject )
                data.Size = size
                offset += size

                data.CRC = File_ReadULong( fileObject )
                files[ index ] = data

            files.Pointer = File_Tell( fileObject )

        Read: ( filePath, gamePath, readFiles ) =>
            table.Empty( @Required )
            table.Empty( @Files )

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

            fileObject = @Open( filePath, gamePath, "wb" )

            File_Write( fileObject, @Identity )
            File_WriteByte( fileObject, @Version )

            File_WriteUInt64( fileObject, tonumber( @SteamID ) or 0 )
            File_WriteUInt64( fileObject, @Timestamp or os.time() )

            hasRequired = false
            for contentName in pairs( @Required )
                File_WriteString( fileObject, contentName )
                unless hasRequired
                    hasRequired = true

            unless hasRequired
                File_WriteByte( fileObject, 0 )

            File_WriteString( fileObject, @Title )
            File_WriteString( fileObject, @Description )
            File_WriteString( fileObject, @Author )

            File_WriteLong( fileObject, @AddonVersion )

            files = @Files
            for index = 1, #files
                File_WriteULong( fileObject, index )
                data = files[ index ]

                File_WriteString( fileObject, string_lower( data.FilePath ) )
                File_WriteUInt64( fileObject, data.Size )

                if doCRCs
                    File_WriteULong( fileObject, tonumber( util.CRC( data.Content ) ) or 0 )
                else
                    File_WriteULong( fileObject, 0 )

            File_WriteULong( fileObject, 0 )

            for data in *files
                content = data.Content
                unless type( content ) == "string"
                    error "file empty"

                File_Write( fileObject, content )

            @Close!

            return true

        ReadFile: ( index ) =>
            gpm_ArgAssert( index, 1, "number" )

            fileObject = @File
            unless fileObject
                error "File is not oppened"

            files = @Files
            data = files[ index ]
            unless data
                error "File is non exists."

            File_Seek( fileObject, files.Pointer + data.Position )
            data.Content = File_Read( fileObject, data.Size )
            return data

        ReadFiles: =>
            fileObject = @File
            unless fileObject
                error "File is not oppened"

            files = @Files
            pointer = files.Pointer
            for data in *files
                File_Seek( fileObject, pointer + data.Position )
                data.Content = File_Read( fileObject, data.Size )

            return files

        GetFile: ( index ) =>
            return @Files[ index ]

        AddFile: ( filePath, content ) =>
            gpm_ArgAssert( filePath, 1, "string" )
            gpm_ArgAssert( content, 2, "string" )
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
            table.Empty( @files )

        AddRequiredContent: ( contentName ) =>
            gpm_ArgAssert( contentName, 1, "string" )
            @requiredContent[ contentName ] = true

        RemoveRequiredContent: ( contentName ) =>
            gpm_ArgAssert( contentName, 1, "string" )
            @requiredContent[ contentName ] = nil

        ClearRequiredContent: =>
            table.Empty( @requiredContent )

lib.New = GMAD
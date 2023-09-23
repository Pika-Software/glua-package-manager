gpm_ArgAssert = gpm.ArgAssert
lib = gpm.Lib "gmad"
error = error
type = type

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

File = FindMetaTable "File"

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
        @SteamID = 0
        @Files = {}

    Open: ( filePath, gamePath, fileMode ) =>
        @Close!

        fileObject = file.Open( filePath, fileMode or "rb", gamePath )
        unless fileObject
            error "File cannot be open."

        @File = fileObject
        return fileObject

    Close: =>
        fileObject = @File
        if fileObject
            File.Close( fileObject )
            @File = nil
            return true
        return false

    Parse: =>
        fileObject = @File
        unless fileObject
            error "File is not oppened"

        if File.Read( fileObject, 4 ) ~= @Identity
            error "File is not a gma"

        version = File.ReadByte( fileObject )
        if version > @Version
            error "gma version is unsupported"

        @File = fileObject
        @Version = version

        @SteamID = File.ReadUInt64( fileObject )
        @Timestamp = File.ReadUInt64( fileObject )

        if version > 1
            while not File.EndOfFile( fileObject )
                contentName = File.ReadString( fileObject )
                unless contentName
                    break
                @Required[ contentName ] = true

        @Title = File.ReadString( fileObject )
        @Description = File.ReadString( fileObject )
        @Author = File.ReadString( fileObject )

        @AddonVersion = File.ReadLong( fileObject )

        files, offset = @Files, 0
        while not File.EndOfFile( fileObject )
            index = File.ReadULong( fileObject )
            if index == 0
                break

            data = {
                FilePath: File.ReadString( fileObject ),
                Position: offset
            }

            size = File.ReadUInt64( fileObject )
            data.Size = size
            offset += size

            data.CRC = File.ReadULong( fileObject )
            files[ index ] = data

        files.Pointer = File.Tell( fileObject )

    Read: ( filePath, gamePath, readFiles ) =>
        gpm_ArgAssert( filePath, 1, "string" )
        gpm_ArgAssert( gamePath, 2, "string" )

        table.Empty( @Required )
        table.Empty( @Files )

        @Open( filePath, gamePath )
        @Parse!

        if readFiles
            @ReadFiles!
        @Close!

    ReadFile: ( index ) =>
        fileObject = @File
        unless fileObject
            error "File is not oppened"

        files = @Files
        data = files[ index ]
        unless data
            error "File is non exists."

        File.Seek( fileObject, files.Pointer + data.Position )
        data.Content = File.Read( fileObject, data.Size )
        return data

    ReadFiles: =>
        fileObject = @File
        unless fileObject
            error "File is not oppened"

        files = @Files
        pointer = files.Pointer
        for data in *files
            File.Seek( fileObject, pointer + data.Position )
            data.Content = File.Read( fileObject, data.Size )
        return files

    VerifyCRC: =>
        for data in *@Files
            crc, content = data.CRC, data.Content
            if crc and content and crc ~= util.CRC( content )
                return false
        return true

    VerifyFiles: =>
        files = @Files
        unless #files == 0
            return false

        for filePath in *files
            unless lib_IsAllowedFilePath( filePath )
                return false

        return true

    Write: ( filePath, gamePath, doCRCs ) =>
        gpm_ArgAssert( filePath, 1, "string" )
        gpm_ArgAssert( gamePath, 2, "string" )

        unless @VerifyFiles!
            error "Not allowed by whitelist"

        fileObject = @Open( filePath, gamePath, "wb" )

        File.Write( fileObject, @Identity )
        File.WriteByte( fileObject, @Version )

        File.WriteUInt64( fileObject, @SteamID or 0 )
        File.WriteUInt64( fileObject, @Timestamp or os.time() )

        hasRequired = false
        for contentName in pairs( @Required )
            File.WriteString( fileObject, contentName )
            unless hasRequired
                hasRequired = true

        unless hasRequired
            File.WriteByte( fileObject, 0 )

        File.WriteString( fileObject, @Title )
        File.WriteString( fileObject, @Description )
        File.WriteString( fileObject, @Author )

        File.WriteLong( fileObject, @AddonVersion )

        files = @Files
        for index = 1, #files
            File.WiteULong( fileObject, index )
            data = files[ index ]

            File.WriteString( fileObject, string.lower( data.FilePath ) )
            File.WriteUInt64( fileObject, data.Size )

            if doCRCs
                File.WriteLong( fileObject, util.CRC( data.Content ) )
            else
                File.WriteLong( fileObject, 0 )

        File.WiteULong( fileObject, 0 )

        for index = 1, #files
            data = files[ index ]

            content = data.Content
            if not content or #content == 0
                error "file empty"

            File.Write( content )

        @Close!

        return true

    AddRequiredContent: ( contentName ) =>
        gpm_ArgAssert( contentName, 1, "string" )
        @requiredContent[ contentName ] = true

    RemoveRequiredContent: ( contentName ) =>
        gpm_ArgAssert( contentName, 1, "string" )
        @requiredContent[ contentName ] = nil

    ClearRequiredContent: =>
        table.Empty( @requiredContent )

    ClearFiles: =>
        table.Empty( @files )


obj = GMA!
obj\Open( "addons/colourable_hl2_crowbar_643148462.gma", "GAME" )
obj\Parse!
PrintTable( obj\ReadFiles! )
obj\Close!

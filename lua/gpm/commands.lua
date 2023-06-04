local gpm = gpm

do

    local workshopPath = gpm.WorkshopPath
    local cachePath = gpm.CachePath
    local logger = gpm.Logger
    local ipairs = ipairs
    local fs = gpm.fs

    function gpm.ClearCache()
        local count, size = 0, 0

        for _, fileName in ipairs( fs.Find( cachePath .. "*", "DATA" ) ) do
            local filePath = cachePath .. fileName
            local fileSize = fs.Size( filePath, "DATA" )
            fs.Delete( filePath )

            if not fs.IsFile( filePath, "DATA" ) then
                size = size + fileSize
                count = count + 1
                continue
            end

            logger:Warn( "Unable to remove file '%s' probably used by the game, restart game and try again.", filePath )
        end

        for _, fileName in ipairs( fs.Find( workshopPath .. "*", "DATA" ) ) do
            local filePath = workshopPath .. fileName
            local fileSize = fs.Size( filePath, "DATA" )
            fs.Delete( filePath )

            if not fs.IsFile( filePath, "DATA" ) then
                size = size + fileSize
                count = count + 1
                continue
            end

            logger:Warn( "Unable to remove file '%s' probably used by the game, restart game and try again.", filePath )
        end

        logger:Info( "Deleted %d cache files, freeing up %dMB of space.", count, size / 1024 / 1024 )
    end

end

do

    local string_format = string.format
    local colors = gpm.Colors
    local pairs = pairs
    local MsgC = MsgC

    function gpm.PrintPackageList()
        MsgC( colors.Realm, gpm.Realm, colors.PrimaryText, " packages:\n" )

        local total = 0
        for name, pkg in pairs( gpm.Packages ) do
            MsgC( colors.Realm, "\t* ", colors.PrimaryText, string_format( "%s@%s\n", name, pkg:GetVersion() ) )
            total = total + 1
        end

        MsgC( colors.Realm, "\tTotal: ", colors.PrimaryText, total, "\n" )
    end

end

do

    local hook_Run = hook.Run

    function gpm.Reload( packageName )
        if type( packageName ) == "string" and #packageName > 0 then

            -- TODO: PACKAGE RELOAD HERE

            return
        end

        hook_Run( "GPM - Reload" )
        include( "gpm/init.lua" )
        hook_Run( "GPM - Reloaded" )
    end

end

if SERVER then

    local concommand_Add = concommand.Add
    local BroadcastLua = BroadcastLua
    local IsValid = IsValid

    concommand_Add( "gpm_clear_cache", function( ply )
        if IsValid( ply ) then
            ply:SendLua( "gpm.ClearCache()" )
            if not ply:IsListenServerHost() then return end
        end

        gpm.ClearCache()
    end )

    concommand_Add( "gpm_list", function( ply )
        if IsValid( ply ) then
            ply:SendLua( "gpm.PrintPackageList()" )
            if not ply:IsListenServerHost() then return end
        end

        gpm.PrintPackageList()
    end )

    concommand_Add( "gpm_reload", function( ply, _, __, packageName )
        if IsValid( ply ) and not ply:IsSuperAdmin() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        gpm.Reload( packageName )
        BroadcastLua( "gpm.Reload(\"" .. packageName .. "\")" )
    end )

end
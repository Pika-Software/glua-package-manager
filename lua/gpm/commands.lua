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
    local pairs = pairs
    local MsgC = MsgC

    function gpm.PrintPackageList()
        MsgC( Colors.Realm, gpm.Realm, Colors.PrimaryText, " packages:\n" )

        local total = 0
        for name, pkg in pairs( Packages ) do
            MsgC( Colors.Realm, "\t* ", Colors.PrimaryText, string_format( "%s@%s\n", name, pkg:GetVersion() ) )
            total = total + 1
        end

        MsgC( Colors.Realm, "\tTotal: ", Colors.PrimaryText, total, "\n" )
    end

end

do

    local hook_Run = hook.Run

    function gpm.Reload()
        hook_Run( "GPM - Reload" )
        include( "gpm/init.lua" )
        hook_Run( "GPM - Reloaded" )
    end

end

if SERVER then

    local BroadcastLua = BroadcastLua
    local IsValid = IsValid

    concommand.Add( "gpm_clear_cache", function( ply )
        if not IsValid( ply ) or ply:IsListenServerHost() then
            gpm.ClearCache()
        end

        ply:SendLua( "gpm.ClearCache()" )
    end )

    concommand.Add( "gpm_list", function( ply )
        if not IsValid( ply ) or ply:IsListenServerHost() then
            gpm.PrintPackageList()
        end

        ply:SendLua( "gpm.PrintPackageList()" )
    end )

    concommand.Add( "gpm_reload", function( ply )
        if not IsValid( ply ) or ply:IsSuperAdmin() then
            gpm.Reload(); BroadcastLua( "gpm.Reload()" )
            return
        end

        ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
    end )

end
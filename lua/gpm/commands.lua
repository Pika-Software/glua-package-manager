local ipairs = ipairs
local table = table
local gpm = gpm

do

    local workshopPath = gpm.WorkshopPath
    local cachePath = gpm.CachePath
    local logger = gpm.Logger
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

    function gpm.Reload( ... )
        local packageNames = {...}
        if table.IsEmpty( packageNames ) then
            table.Empty( gpm.ImportTasks )
            table.Empty( gpm.Packages )
            hook_Run( "GPM - Reload" )
            include( "gpm/init.lua" )
            return hook_Run( "GPM - Reloaded" )
        end

        for _, packageName in ipairs( packageNames ) do
            if #packageName == 0 then continue end

            local pkgs = gpm.package.Find( packageName, false, true )
            if not pkgs then
                logger:Error( "Package reload failed, packages with name '%s' is not found.", packageName )
                continue
            end

            for _, pkg in ipairs( pkgs ) do
                pkg:Install()
            end
        end
    end

end

function gpm.UnInstall( ... )
    local packageNames = {...}
    local force = false

    for _, str in ipairs( packageNames ) do
        if string.lower( str ) == "-f" then
            force = true
            break
        end
    end

    for _, packageName in ipairs( packageNames ) do
        if #packageName == 0 then continue end

        local pkgs = gpm.package.Find( packageName, false, true )
        if not pkgs then
            logger:Error( "Package uninstall failed, packages with name '%s' is not found.", packageName )
            continue
        end

        for _, pkg in ipairs( pkgs ) do
            pkg:UnInstall( not force )
        end
    end
end

local net = net

if SERVER then

    util.AddNetworkString( "GPM.Commands" )

    local concommand_Add = concommand.Add
    local IsValid = IsValid

    concommand_Add( "gpm_clear_cache", function( ply )
        if IsValid( ply ) then
            net.Start( "GPM.Commands" )
                net.WriteUInt( 0, 3 )
            net.Send( ply )

            if not ply:IsListenServerHost() then return end
        end

        gpm.ClearCache()
    end )

    concommand_Add( "gpm_list", function( ply )
        if IsValid( ply ) then
            net.Start( "GPM.Commands" )
                net.WriteUInt( 1, 3 )
            net.Send( ply )

            if not ply:IsListenServerHost() then return end
        end

        gpm.PrintPackageList()
    end )

    concommand_Add( "gpm_reload", function( ply, _, args )
        if IsValid( ply ) and not ply:IsSuperAdmin() and not ply:IsListenServerHost() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        gpm.Reload( unpack( args ) )

        net.Start( "GPM.Commands" )
            net.WriteUInt( 2, 3 )
            net.WriteTable( args )
        net.Broadcast()
    end )

    concommand_Add( "gpm_install", function( ply, _, args )
        if not IsValid( ply ) then
            gpm.Install( nil, true, unpack( args ) )
            return
        end

        if not ply:IsSuperAdmin() and not ply:IsListenServerHost() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        net.Start( "GPM.Commands" )
            net.WriteUInt( 3, 3 )
            net.WriteTable( args )
        net.Send( ply )
    end )

    concommand_Add( "gpm_uninstall", function( ply, _, args )
        if not IsValid( ply ) then
            gpm.UnInstall( unpack( args ) )
            return
        end

        if not ply:IsSuperAdmin() and not ply:IsListenServerHost() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        net.Start( "GPM.Commands" )
            net.WriteUInt( 4, 3 )
            net.WriteTable( args )
        net.Send( ply )
    end )

end

if CLIENT then

    local events = {
        [0] = gpm.ClearCache,
        [1] = gpm.PrintPackageList,
        [2] = function()
            gpm.Reload( unpack( net.ReadTable() ) )
        end,
        [3] = function()
            gpm.Install( nil, true, unpack( net.ReadTable() ) )
        end,
        [4] = function()
            gpm.UnInstall( unpack( net.ReadTable() ) )
        end
    }

    net.Receive( "GPM.Commands", function()
        local func = events[ net.ReadUInt( 3 ) ]
        if not func then return end
        func()
    end )

end
local MENU_DLL, SERVER = MENU_DLL, SERVER
local net = not MENU_DLL and net
local gpm = gpm
local logger = gpm.Logger
local ipairs = ipairs
local table = table

if MENU_DLL or SERVER then

    if SERVER then
        util.AddNetworkString( "GPM.Networking" )
    end

    local concommand_Add = concommand.Add
    local IsValid = IsValid

    concommand_Add( "gpm_clear_cache", function( ply )
        if not MENU_DLL and IsValid( ply ) then
            net.Start( "GPM.Networking" )
                net.WriteUInt( 0, 3 )
            net.Send( ply )

            if not ply:IsListenServerHost() then return end
        end

        gpm.ClearCache()
    end )

    concommand_Add( "gpm_list", function( ply )
        if not MENU_DLL and IsValid( ply ) then
            net.Start( "GPM.Networking" )
                net.WriteUInt( 1, 3 )
            net.Send( ply )

            if not ply:IsListenServerHost() then return end
        end

        gpm.PrintPackageList()
    end )

    concommand_Add( "gpm_reload", function( ply, _, arguments )
        if not MENU_DLL and IsValid( ply ) and not ply:IsSuperAdmin() and not ply:IsListenServerHost() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        gpm.Reload( unpack( arguments ) )
    end )

    concommand_Add( "gpm_install", function( ply, _, arguments )
        if MENU_DLL or not IsValid( ply ) then
            gpm.Install( nil, true, unpack( arguments ) ):Catch( function( message )
                logger:Error( message )
            end )

            return
        end

        if not ply:IsSuperAdmin() and not ply:IsListenServerHost() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        net.Start( "GPM.Networking" )
            net.WriteUInt( 3, 3 )
            net.WriteTable( arguments )
        net.Send( ply )
    end )

    concommand_Add( "gpm_uninstall", function( ply, _, arguments )
        local force = false
        for index, str in ipairs( arguments ) do
            if string.lower( str ) == "-f" then
                table.remove( arguments, index )
                force = true
                break
            end
        end

        if MENU_DLL or not IsValid( ply ) then
            gpm.Uninstall( force, unpack( arguments ) )
            return
        end

        if not ply:IsSuperAdmin() and not ply:IsListenServerHost() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        net.Start( "GPM.Networking" )
            net.WriteUInt( 4, 3 )
            net.WriteBool( force )
            net.WriteTable( arguments )
        net.Send( ply )
    end )

end

if not MENU_DLL and CLIENT then

    local events = {
        [0] = gpm.ClearCache,
        [1] = gpm.PrintPackageList,
        [2] = function()
            gpm.Reload( unpack( net.ReadTable() ) )
        end,
        [3] = function()
            gpm.Install( nil, true, unpack( net.ReadTable() ) ):Catch( function( message )
                logger:Error( message )
            end )
        end,
        [4] = function()
            gpm.Uninstall( net.ReadBool(), unpack( net.ReadTable() ) )
        end,
        [5] = function()
            local importPath = net.ReadString()
            logger:Debug( "Received a request to reload package '%s' from the server.", importPath )

            local pkg = gpm.Packages[ importPath ]
            if not pkg then return end

            pkg:Reload():Catch( function( message )
                logger:Error( "Package '%s' reload failed, error:\n%s", pkg:GetIdentifier(), message )
            end )
        end
    }

    net.Receive( "GPM.Networking", function()
        local func = events[ net.ReadUInt( 3 ) ]
        if not func then return end
        func()
    end )

end
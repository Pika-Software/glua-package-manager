local logger = gpm.Logger
local SERVER = SERVER
local ipairs = ipairs
local table = table
local gpm = gpm
local net = net

do

    local workshopPath = gpm.WorkshopPath
    local cachePath = gpm.CachePath
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

    local colors = gpm.Colors
    local pairs = pairs
    local MsgC = MsgC
    local type = type

    function gpm.PrintPackageList( packages )
        MsgC( colors.Realm, gpm.Realm, colors.PrimaryText, " packages:\n" )

        if type( packages ) ~= "table" then
            packages = {}

            for _, pkg in pairs( gpm.Packages ) do
                packages[ #packages + 1 ] = pkg
            end
        end

        table.sort( packages, function( a, b )
            return a:GetIdentifier() < b:GetIdentifier()
        end )

        local total = 0
        for _, pkg in pairs( packages ) do
            MsgC( colors.Realm, "\t* ", colors.PrimaryText, pkg:GetIdentifier() .. "\n" )
            total = total + 1
        end

        MsgC( colors.Realm, "\tTotal: ", colors.PrimaryText, total, "\n" )
    end

end

local function catch( message )
    logger:Error( message )
end

function gpm.Reload( ... )
    local arguments = { ... }
    if #arguments == 0 then
        logger:Warn( "There is no information for package reloading, if you are trying to do a full reload then just use .*" )
        return
    end

    if SERVER then
        net.Start( "GPM.Networking" )
            net.WriteUInt( 2, 3 )
            net.WriteTable( arguments )
        net.Broadcast()
    end

    local packages, count = {}, 0
    for _, searchable in ipairs( arguments ) do
        if #searchable == 0 then continue end
        for _, pkg in ipairs( gpm.Find( searchable, false, false ) ) do
            packages[ pkg ] = true
            count = count + 1
        end
    end

    if count == 0 then
        logger:Info( "No candidates found for reloading, skipping..." )
        return
    end

    logger:Info( "Found %d candidates to reload, reloading...", count )

    for pkg in pairs( packages ) do
        pkg:Reload( true ):Catch( catch )
    end
end

function gpm.Uninstall( force, ... )
    local arguments = {...}
    if #arguments == 0 then
        logger:Warn( "There is no information for package uninstalling." )
        return
    end

    local packages, count = {}, 0
    for _, searchable in ipairs( arguments ) do
        if #searchable == 0 then continue end
        for _, pkg in ipairs( gpm.Find( searchable, false, false ) ) do
            packages[ pkg ] = true
            count = count + 1
        end
    end

    if count == 0 then
        logger:Info( "No candidates found for uninstalling, skipping..." )
        return
    end

    logger:Info( "Found %d candidates to uninstall, uninstalling...", count )

    for pkg in pairs( packages ) do
        local children = pkg:GetChildren()
        local childCount = #children
        if childCount ~= 0 and not force then
            logger:Error( "Package '%s' uninstallation cancelled, %d dependencies found, try use -f to force uninstallation, skipping...", pkg:GetIdentifier(), childCount )
            gpm.PrintPackageList( children )
            continue
        end

        pkg:Uninstall()
    end
end

local net = net

if SERVER then

    util.AddNetworkString( "GPM.Networking" )

    local concommand_Add = concommand.Add
    local IsValid = IsValid

    concommand_Add( "gpm_clear_cache", function( ply )
        if IsValid( ply ) then
            net.Start( "GPM.Networking" )
                net.WriteUInt( 0, 3 )
            net.Send( ply )

            if not ply:IsListenServerHost() then return end
        end

        gpm.ClearCache()
    end )

    concommand_Add( "gpm_list", function( ply )
        if IsValid( ply ) then
            net.Start( "GPM.Networking" )
                net.WriteUInt( 1, 3 )
            net.Send( ply )

            if not ply:IsListenServerHost() then return end
        end

        gpm.PrintPackageList()
    end )

    concommand_Add( "gpm_reload", function( ply, _, arguments )
        if IsValid( ply ) and not ply:IsSuperAdmin() and not ply:IsListenServerHost() then
            ply:ChatPrint( "[GPM] You do not have enough permissions to execute this command." )
            return
        end

        gpm.Reload( unpack( arguments ) )
    end )

    concommand_Add( "gpm_install", function( ply, _, arguments )
        if not IsValid( ply ) then
            gpm.Install( nil, true, unpack( arguments ) )
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

        if not IsValid( ply ) then
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
            gpm.Uninstall( net.ReadBool(), unpack( net.ReadTable() ) )
        end,
        [5] = function()
            local importPath = net.ReadString()
            logger:Debug( "Received a request to reload package '%s' from the server.", importPath )

            local pkg = gpm.Packages[ importPath ]
            if not pkg then return end

            pkg:Reload():Catch( catch )
        end
    }

    net.Receive( "GPM.Networking", function()
        local func = events[ net.ReadUInt( 3 ) ]
        if not func then return end
        func()
    end )

end
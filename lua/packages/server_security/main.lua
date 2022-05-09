if (CLIENT) then
    return
end

local packageName = "Server Security"

do

    module( "glua_server_security", package.seeall )

    local jail_time = CreateConVar( "server_security_jail_time", "15", FCVAR_ARCHIVE, " - Player jail time.", 0, math.huge ):GetInt() * 60
    cvars.AddChangeCallback("server_security_jail_time", function( name, old, new ) jail_time = tonumber( new ) * 60 end, packageName)

    local kick_reason = CreateConVar( "server_security_kick_reason", "Please, re-install your Garry's Mod.", FCVAR_ARCHIVE, " - Player kick reason." ):GetString()
    cvars.AddChangeCallback("server_security_kick_reason", function( name, old, new ) kick_reason = new end, packageName)

    local jail_list = {}
    function Get( any )
        return jail_list[ any ]
    end

    function Remove( any )
        jail_list[ any ] = nil
    end

    function Punish( ply )
        local steamid64, ip = ply:SteamID64(), ply:IPAddress()
        local data = { steamid64, ply:Nick(), SysTime() + jail_time }
        jail_list[ steamid64 ] = data
        jail_list[ ip ] = data

        ply:Kick( kick_reason )
    end

end

/*
    Authorization
*/

do

    local time_format = "%02i:%02i:%02i"
    local disconnect_string = [[
    Player %s (%s) was blocked!
    Please, re-install your Garry's Mod.
    You can connect only after %s.
    ]]

    local string_FormattedTime = string.FormattedTime
    local SysTime = SysTime

    hook.Add("CheckPassword", packageName, function( steamid64, ip, sv_pass, cl_pass, nickname )
        local steamid_data = glua_server_security.Get( steamid64 )
        if (steamid_data == nil) then
            local ip_data = glua_server_security.Get( ip )
            if (ip_data == nil) then
                return
            end

            if (ip_data[3] <= SysTime()) then
                glua_server_security.Remove( ip )
                return
            end

            return false, disconnect_string:format( jail_list[2], jail_list[1], string_FormattedTime( steamid_data[3] - SysTime(), time_format ) )
        end

        if (steamid_data[3] <= SysTime()) then
            glua_server_security.Remove( steamid64 )
            return
        end

        return false, disconnect_string:format( steamid_data[2], steamid_data[1], string_FormattedTime( steamid_data[3] - SysTime(), time_format ) )
    end)

end

hook.Add("PlayerInitialSpawn", packageName, function( ply )
    if (ply:SteamID64() == ply:OwnerSteamID64()) then return end
    glua_server_security.Punish( ply )
end)

do
    local PLAYER = FindMetaTable( "Player" )
    function PLAYER:IsSecureChecked()
        return self.SecureChecked or false
    end
end

hook.Add("PlayerInitialized", packageName, function( ply )
    if ply:IsFullyAuthenticated() then
        ply.SecureChecked = true
        return
    end

    glua_server_security.Punish( ply )
end)

/*
    Communication
*/
hook.Add("PreChatCommand", packageName, function( talker )
    if talker:IsSecureChecked() then return end
    return false
end)

hook.Add("PlayerCanSeePlayersChat", packageName, function( text, isTeam, listener, talker )
    if talker:IsSecureChecked() or listener:IsSecureChecked() then return end
    return false
end)

hook.Add("PlayerCanHearPlayersVoice", packageName, function( listener, talker )
    if talker:IsSecureChecked() or listener:IsSecureChecked() then return end
    return false
end)

/*
    Movement
*/
hook.Add("FinishMove", packageName, function( ply )
    if ply:IsSecureChecked() then return end
    return true
end)

/*
    Interactions
*/
hook.Add("PlayerUse", packageName, function( ply )
    if ply:IsSecureChecked() then return end
    return false
end)

hook.Add("PlayerSpray", packageName, function( ply )
    if ply:IsSecureChecked() then return end
    return false
end)

hook.Add("PlayerShouldTaunt", packageName, function( ply )
    if ply:IsSecureChecked() then return end
    return false
end)
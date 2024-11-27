concommand.Add( "glide_switch_seat", function( ply, _, args )
    if ply ~= LocalPlayer() then return end
    if #args == 0 then return end

    local seatIndex = tonumber( args[1] )
    if not seatIndex then return end

    local vehicle = ply:GlideGetVehicle()
    if not IsValid( vehicle ) then return end

    Glide.StartCommand( Glide.CMD_SWITCH_SEATS )
    net.WriteUInt( seatIndex, 5 )
    net.SendToServer()
end, nil, "Switch seats while inside a Glide vehicle." )

----- Check if the local player has entered/left a Glide vehicle.

local hideComponent = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true
}

local function HUDShouldDraw( name )
    if hideComponent[name] then return false end
end

local activeVehicle, activeSeatIndex = NULL, 0

local function DrawVehicleHUD()
    if IsValid( activeVehicle ) then
        activeVehicle:DrawVehicleHUD()
    end
end

local function OnEnter( vehicle, seatIndex )
    vehicle:OnLocalPlayerEnter( seatIndex )

    activeVehicle = vehicle
    activeSeatIndex = seatIndex

    Glide.currentVehicle = vehicle
    Glide.currentSeatIndex = seatIndex

    hook.Add( "HUDShouldDraw", "Glide.HideDefaultHealth", HUDShouldDraw )
    hook.Add( "HUDPaint", "Glide.DrawVehicleHUD", DrawVehicleHUD )
    hook.Run( "Glide_OnLocalEnterVehicle", vehicle, seatIndex )

    if vehicle.VehicleType == Glide.VEHICLE_TYPE.HELICOPTER and system.IsLinux() then
        Glide.Print( "Linux system detected, setting snd_fixed_rate to 1" )
        RunConsoleCommand( "snd_fixed_rate", "1" )
    end
end

local function OnLeave( ply )
    if IsValid( activeVehicle ) then
        activeVehicle:OnLocalPlayerExit()
    end

    activeVehicle = nil
    activeSeatIndex = 0

    Glide.currentVehicle = nil
    Glide.currentSeatIndex = nil
    Glide.ResetBoneManipulations( ply )

    hook.Remove( "HUDShouldDraw", "Glide.HideDefaultHealth" )
    hook.Remove( "HUDPaint", "Glide.DrawVehicleHUD" )
    hook.Run( "Glide_OnLocalExitVehicle" )

    if system.IsLinux() then
        Glide.Print( "Linux system detected, setting snd_fixed_rate to 0" )
        RunConsoleCommand( "snd_fixed_rate", "0" )
    end
end

local IsValid = IsValid
local LocalPlayer = LocalPlayer

hook.Add( "Tick", "Glide.CheckCurrentVehicle", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local seat = ply:GetVehicle()

    if not IsValid( seat ) then
        if activeSeatIndex > 0 then
            OnLeave( ply )
        end

        return
    end

    local parent = seat:GetParent()

    if not IsValid( parent ) or not parent.IsGlideVehicle then
        if activeSeatIndex > 0 then
            OnLeave( ply )
        end

        return
    end

    local seatIndex = seat:GetNWInt( "GlideSeatIndex", 0 )

    if activeSeatIndex ~= seatIndex then
        if activeSeatIndex > 0 then
            OnLeave( ply )
        end

        activeSeatIndex = seatIndex

        if seatIndex > 0 then
            OnEnter( parent, seatIndex )
        end
    end
end )

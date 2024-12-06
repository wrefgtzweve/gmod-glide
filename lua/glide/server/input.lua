-- Only allow these actions when receiving player input settings
local ACTION_FILTER = {
    ["switch_weapon"] = true,
    ["attack"] = true,
    ["attack_alt"] = true,

    -- Car actions
    ["steer_left"] = true,
    ["steer_right"] = true,
    ["accelerate"] = true,
    ["brake"] = true,
    ["handbrake"] = true,
    ["horn"] = true,
    ["headlights"] = true,
    ["reduce_throttle"] = true,

    ["shift_up"] = true,
    ["shift_down"] = true,
    ["shift_neutral"] = true,

    -- Airborne car/bike actions
    ["lean_forward"] = true,
    ["lean_back"] = true,

    -- Aircraft actions
    ["countermeasures"] = true,
    ["free_look"] = true,
    ["landing_gear"] = true,
    ["pitch_up"] = true,
    ["pitch_down"] = true,
    ["roll_left"] = true,
    ["roll_right"] = true,
    ["rudder_left"] = true,
    ["rudder_right"] = true,
    ["throttle_up"] = true,
    ["throttle_down"] = true
}

-- Store player input settings and binds
local playerSettings = Glide.playerSettings or {}

-- Store players that are currently controlling a Glide vehicle
local activeData = Glide.activeInputData or {}

Glide.playerSettings = playerSettings
Glide.activeInputData = activeData

--- Make sure the player has sent valid data.
local function Validate( settings )
    if type( settings ) ~= "table" then return false end
    if type( settings.mouseFlyMode ) ~= "number" then return false end
    if type( settings.binds ) ~= "table" then return false end

    return true
end

--- Validate and set the action binds for a specific player.
function Glide.SetupPlayerInput( ply, data )
    if not Validate( data ) then
        Glide.Print( "%s <%s> sent invalid input data!", ply:Nick(), ply:SteamID() )
        return
    end

    -- Store which actions are associated to each key, while
    -- filtering out actions that do not exist on ACTION_FILTER.
    local actions = {}

    for action, _ in pairs( ACTION_FILTER ) do
        local key = data.binds[action]

        if type( key ) == "number" then
            key = math.Clamp( key, KEY_FIRST, BUTTON_CODE_LAST )

            local t = actions[key]

            if not t then
                -- No actions for this key yet, create a new list.
                t = {}
                actions[key] = t
            end

            t[#t + 1] = action
        end
    end

    playerSettings[ply] = {
        actions = actions,
        manualGearShifting = data.manualGearShifting == true,
        mouseFlyMode = math.Round( Glide.ValidateNumber( data.mouseFlyMode, 0, 2, 0 ) )
    }

    -- If this player is already in a Glide vehicle, activate the inputs again.
    local activeVehicle = ply:GlideGetVehicle()

    if IsValid( activeVehicle ) then
        Glide.ActivateInput( ply, activeVehicle, ply:GlideGetSeatIndex() )
    end
end

--- Start listening to input events from this player.
function Glide.ActivateInput( ply, vehicle, seatIndex )
    Glide.DeactivateInput( ply )

    -- Make sure we have received settings from this player
    local settings = playerSettings[ply]
    if not settings then return end

    -- Set driver settings on this vehicle
    if seatIndex == 1 then
        vehicle.inputFlyMode = settings.mouseFlyMode
        vehicle.inputManualShift = settings.manualGearShifting
    end

    -- Let our input hooks handle this
    activeData[ply] = {
        vehicle = vehicle,
        seatIndex = seatIndex
    }
end

--- Stop listening to input events from this player.
function Glide.DeactivateInput( ply )
    local active = activeData[ply]

    if active and IsValid( active.vehicle ) then
        active.vehicle:ResetInputs( active.seatIndex )
    end

    activeData[ply] = nil
end

local SEAT_SWITCH_KEYS = {
    [KEY_1] = 1,
    [KEY_2] = 2,
    [KEY_3] = 3,
    [KEY_4] = 4,
    [KEY_5] = 5,
    [KEY_6] = 6,
    [KEY_7] = 7,
    [KEY_8] = 8,
    [KEY_9] = 9,
    [KEY_0] = 10
}

-- Change yaw actions to roll actions
-- while using the mouse `Point-to-aim` mode.
local MOUSE_AIM_OVERRIDE = {
    ["rudder_left"] = "roll_left",
    ["rudder_right"] = "roll_right"
}

-- Alternate actions
local ALT_ACTIONS = {
    ["attack_alt"] = "attack"
}

local IsValid = IsValid

--- Handle key up/down events.
local function HandleInput( ply, key, active, pressed )
    local vehicle = active.vehicle

    if not IsValid( vehicle ) then
        Glide.DeactivateInput( ply )
        return
    end

    -- Is this a "switch seat" key?
    if pressed and SEAT_SWITCH_KEYS[key] then
        Glide.SwitchSeat( ply, SEAT_SWITCH_KEYS[key] )

        return
    end

    local settings = playerSettings[ply]
    if not settings then return end

    -- Does this key have actions associated with it?
    local actions = settings.actions[key]
    if not actions then return end

    local mode = settings.mouseFlyMode

    for _, action in ipairs( actions ) do
        -- mode == Glide.MOUSE_FLY_MODE.AIM
        if mode == 0 and MOUSE_AIM_OVERRIDE[action] then
            action = MOUSE_AIM_OVERRIDE[action]
        end

        vehicle:SetInputBool( active.seatIndex, ALT_ACTIONS[action] or action, pressed )
    end
end

local FrameTime = FrameTime
local Clamp = math.Clamp

--- Handle mouse inputs when required.
local function HandleMouseInput( ply, active )
    local vehicle = active.vehicle

    if not IsValid( vehicle ) then
        Glide.DeactivateInput( ply )
        return
    end

    local settings = playerSettings[ply]
    if not settings then return end

    -- Glide.VEHICLE_TYPE.HELICOPTER, Glide.VEHICLE_TYPE.PLANE
    if vehicle.VehicleType ~= 3 and vehicle.VehicleType ~= 4 then return end

    -- Glide.MOUSE_FLY_MODE.CAMERA
    if settings.mouseFlyMode == 2 then return end

    local dt = FrameTime()
    local seatIndex = active.seatIndex

    -- Glide.MOUSE_FLY_MODE.AIM
    if settings.mouseFlyMode == 0 then

        local phys = vehicle:GetPhysicsObject()
        if not IsValid( phys ) then return end

        local angVel = phys:GetAngleVelocity()
        local targetDir = ply:GlideGetCameraAngles():Forward()

        local pitchDrag = Clamp( angVel[2] * -0.1, -3, 3 ) * dt * 40
        local rudderDrag = Clamp( angVel[3] * 0.1, -3, 3 ) * dt * 40

        local mult = vehicle.VehicleType == 4 and 15 or 8
        local pitch = Clamp( ( targetDir:Dot( vehicle:GetUp() ) * -mult ) + pitchDrag, -1, 1 )
        local rudder = Clamp( ( targetDir:Dot( vehicle:GetRight() ) * mult ) + rudderDrag, -1, 1 )

        if vehicle:GetInputBool( 1, "free_look" ) then
            pitch = 0
            rudder = 0
        end

        vehicle:SetInputFloat( seatIndex, "pitch", pitch )
        vehicle:SetInputFloat( seatIndex, "rudder", rudder )

    -- Glide.MOUSE_FLY_MODE.DIRECT
    elseif settings.mouseFlyMode == 1 then

        vehicle:SetInputFloat( seatIndex, "pitch", ply:GetInfoNum( "glide_input_pitch", 0 ) )
        vehicle:SetInputFloat( seatIndex, "roll", ply:GetInfoNum( "glide_input_roll", 0 ) )

    end
end

hook.Add( "PlayerButtonDown", "Glide.VehicleInput", function( ply, key )
    local active = activeData[ply]
    if active then
        HandleInput( ply, key, active, true )
    end
end )

hook.Add( "PlayerButtonUp", "Glide.VehicleInput", function( ply, key )
    local active = activeData[ply]
    if active then
        HandleInput( ply, key, active, false )
    end
end )

hook.Add( "Think", "Glide.ProcessMouseInput", function()
    for ply, active in pairs( activeData ) do
        HandleMouseInput( ply, active )
    end
end )

hook.Add( "PlayerDisconnected", "Glide.InputCleanup", function( ply )
    Glide.DeactivateInput( ply )
    playerSettings[ply] = nil
end )

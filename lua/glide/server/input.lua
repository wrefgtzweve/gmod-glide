-- Store player input settings and binds
local playerSettings = Glide.playerSettings or {}
Glide.playerSettings = playerSettings

-- Store players that are currently controlling a Glide vehicle
local activeData = Glide.activeInputData or {}
Glide.activeInputData = activeData

local EntityMeta = FindMetaTable( "Entity" )
local getTable = EntityMeta.GetTable

do
    local SetNumber = Glide.SetNumber

    --- Make sure the player has sent valid data.
    local function Validate( data )
        if type( data ) ~= "table" then return false end
        if type( data.mouseFlyMode ) ~= "number" then return false end
        if type( data.binds ) ~= "table" then return false end

        return true
    end

    --- Validate and set the action binds for a specific player.
    function Glide.SetupPlayerInput( ply, data )
        if not Validate( data ) then
            Glide.Print( "%s <%s> sent invalid input data!", ply:Nick(), ply:SteamID() )
            return
        end

        -- Filter out categories/actions that do not exist, and validate buttons
        local receivedBinds = type( data.binds ) == "table" and data.binds or {}
        local binds = {}

        for category, actions in pairs( Glide.InputCategories ) do
            binds[category] = {}

            for action, button in pairs( actions ) do
                local receivedCategory = receivedBinds[category]

                if type( receivedCategory ) == "table" then
                    SetNumber( binds[category], action, receivedCategory[action], KEY_NONE, BUTTON_CODE_LAST, button )
                end
            end
        end

        playerSettings[ply] = {
            binds = binds,
            manualGearShifting = data.manualGearShifting == true,
            mouseFlyMode = math.Round( Glide.ValidateNumber( data.mouseFlyMode, 0, 2, 0 ) )
        }

        -- Replace yaw actions with roll actions when the client asks for it,
        -- or while using the `Point-to-aim` mouse mode.
        if data.replaceYawWithRoll == true then
            playerSettings[ply].replaceYawWithRoll = true

        elseif playerSettings[ply].mouseFlyMode == Glide.MOUSE_FLY_MODE.AIM then
            playerSettings[ply].replaceYawWithRoll = true
        end

        -- If this player is already in a Glide vehicle, activate the inputs again.
        local activeVehicle = ply:GlideGetVehicle()

        if IsValid( activeVehicle ) then
            Glide.ActivateInput( ply, activeVehicle, ply:GlideGetSeatIndex() )
        end
    end
end

do
    local VEHICLE_ACTION_CATEGORY = {
        [Glide.VEHICLE_TYPE.UNDEFINED] = "land_controls",
        [Glide.VEHICLE_TYPE.CAR] = "land_controls",
        [Glide.VEHICLE_TYPE.MOTORCYCLE] = "land_controls",
        [Glide.VEHICLE_TYPE.HELICOPTER] = "aircraft_controls",
        [Glide.VEHICLE_TYPE.PLANE] = "aircraft_controls",
        [Glide.VEHICLE_TYPE.TANK] = "land_controls"
    }

    --- Given a category of input actions, get all actions
    --- from that category, and then separate them per button.
    local function AddActions( binds, category, buttons )
        local t

        for action, button in pairs( binds[category] ) do
            t = buttons[button]

            -- Theres no actions for this button yet, create a new list.
            if not t then
                buttons[button] = {}
                t = buttons[button]
            end

            -- Add this action to this button
            t[#t + 1] = action
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

        -- Separate actions for each button, and filter only the
        -- actions relevant to the current vehicle type.
        local buttons = {}

        -- Add button actions that apply to all vehicles
        AddActions( settings.binds, "general_controls", buttons )

        -- Add button actions that apply to this vehicle type
        AddActions( settings.binds, VEHICLE_ACTION_CATEGORY[vehicle.VehicleType], buttons )

        -- Let our input hooks handle this
        activeData[ply] = {
            vehicle = vehicle,
            seatIndex = seatIndex,
            buttons = buttons
        }
    end
end

--- Stop listening to input events from this player.
function Glide.DeactivateInput( ply )
    local active = activeData[ply]

    if active and IsValid( active.vehicle ) then
        active.vehicle:ResetInputs( active.seatIndex )
    end

    activeData[ply] = nil
end

local ACTION_ALIASES = Glide.ACTION_ALIASES
local SEAT_SWITCH_BUTTONS = Glide.SEAT_SWITCH_BUTTONS
local IsValid = IsValid

local MOUSE_ACTION_OVERRIDE = {
    ["yaw_left"] = "roll_left",
    ["yaw_right"] = "roll_right"
}

--- Handle button up/down events.
local function HandleInput( ply, button, active, pressed )
    local vehicle = active.vehicle

    if not IsValid( vehicle ) then
        Glide.DeactivateInput( ply )
        return
    end

    -- Is this a "switch seat" button?
    if pressed and SEAT_SWITCH_BUTTONS[button] then
        -- Let the driver lock the vehicle
        if ply:KeyDown( IN_WALK ) then
            if ply ~= vehicle:GetDriver() then return end

            if Glide.CanLockVehicle( ply, vehicle ) then
                vehicle:SetLocked( not vehicle:GetIsLocked() )
            else
                Glide.SendNotification( ply, {
                    text = "#glide.notify.lock_denied",
                    icon = "materials/icon16/cancel.png",
                    sound = "glide/ui/radar_alert.mp3",
                    immediate = true
                } )
            end
        else
            Glide.SwitchSeat( ply, SEAT_SWITCH_BUTTONS[button] )
        end

        return
    end

    local settings = playerSettings[ply]
    if not settings then return end

    -- Does this button have actions associated with it?
    local actions = active.buttons[button]
    if not actions then return end

    for _, action in ipairs( actions ) do
        if settings.replaceYawWithRoll and MOUSE_ACTION_OVERRIDE[action] then
            action = MOUSE_ACTION_OVERRIDE[action]
        end

        vehicle:SetInputBool( active.seatIndex, ACTION_ALIASES[action] or action, pressed )
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

    local vehTbl = getTable( vehicle )
    -- Ignore is this vehicle is not an aircraft
    if vehTbl.VehicleType ~= 3 and vehTbl.VehicleType ~= 4 then return end

    -- Ignore if the mouse aim mode is "Free camera"
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

        local mult = vehTbl.VehicleType == 4 and 15 or 8
        local pitch = Clamp( ( targetDir:Dot( vehicle:GetUp() ) * -mult ) + pitchDrag, -1, 1 )
        local rudder = Clamp( ( targetDir:Dot( vehicle:GetRight() ) * mult ) + rudderDrag, -1, 1 )

        if vehicle:GetInputBool( 1, "free_look" ) then
            pitch = 0
            rudder = 0
        end

        vehicle:SetInputFloat( seatIndex, "pitch", pitch )
        vehicle:SetInputFloat( seatIndex, "yaw", rudder )

    -- Glide.MOUSE_FLY_MODE.DIRECT
    elseif settings.mouseFlyMode == 1 then

        vehicle:SetInputFloat( seatIndex, "pitch", ply:GetInfoNum( "glide_input_pitch", 0 ) )
        vehicle:SetInputFloat( seatIndex, "yaw", ply:GetInfoNum( "glide_input_yaw", 0 ) )
        vehicle:SetInputFloat( seatIndex, "roll", ply:GetInfoNum( "glide_input_roll", 0 ) )

    end
end

hook.Add( "PlayerButtonDown", "Glide.VehicleInput", function( ply, button )
    local active = activeData[ply]
    if active then
        HandleInput( ply, button, active, true )
    end
end )

hook.Add( "PlayerButtonUp", "Glide.VehicleInput", function( ply, button )
    local active = activeData[ply]
    if active then
        HandleInput( ply, button, active, false )
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

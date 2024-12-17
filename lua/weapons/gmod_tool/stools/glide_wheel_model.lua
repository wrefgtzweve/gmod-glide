TOOL.Category = "Glide"
TOOL.Name = "#tool.glide_wheel_model.name"

TOOL.Information = {
    { name = "left" },
    { name = "right" }
}

TOOL.ClientConVar = {
    front = "models/props_vehicles/apc_tire001.mdl",
    front_scale_x = 1,
    front_scale_y = 1,
    front_scale_z = 1,

    rear = "models/props_vehicles/apc_tire001.mdl",
    rear_scale_x = 1,
    rear_scale_y = 1,
    rear_scale_z = 1
}

local function ValidateModel( model )
    if not file.Exists( model, "GAME" ) then
        return false
    end

    return true
end

local IsValid = IsValid

local function IsGlideVehicle( ent )
    return IsValid( ent ) and ent.IsGlideVehicle
end

function TOOL:GetGlideWheels( trace )
    local ent = trace.Entity
    if not IsGlideVehicle( ent ) then return false end
    if not SERVER then return ent end

    local owner = self:GetOwner()
    local frontWheels, rearWheels = {}, {}
    local frontCount, rearCount = 0, 0
    local hiddenCount = 0

    if ent.wheels then
        for _, w in ipairs( ent.wheels ) do
            if IsValid( w ) then
                if w:GetNoDraw() then
                    hiddenCount = hiddenCount + 1
                end

                if w.isFrontWheel then
                    frontCount = frontCount + 1
                    frontWheels[frontCount] = w
                else
                    rearCount = rearCount + 1
                    rearWheels[rearCount] = w
                end
            end
        end
    end

    if hiddenCount == frontCount + rearCount then
        Glide.SendNotification( owner, {
            text = "#tool.glide_wheel_model.vehicle_model",
            icon = "materials/icon16/cancel.png",
            sound = "glide/ui/radar_alert.wav",
            immediate = true
        } )

        return false
    end

    if frontCount + rearCount < 1 then
        Glide.SendNotification( owner, {
            text = "#tool.glide_water_driving.no_wheels",
            icon = "materials/icon16/cancel.png",
            sound = "glide/ui/radar_alert.wav",
            immediate = true
        } )

        return false
    end

    return ent, frontWheels, rearWheels
end

function TOOL:ApplyModifications( wheels, model, scale )
    if not ValidateModel( model ) then return end

    local data = list.Get( "GlideWheelModels" )[model]
    if not data then return end

    scale = ( data.scale or Vector( 1, 1, 0.35 ) ) * scale

    local angle = data.angle or Angle( 0, 0, 270 )
    local offset = data.offset or Vector( 0, 0, 0 )

    for _, w in ipairs( wheels ) do
        w.modelOverride = model
        w.modelScale = scale
        w:SetModel( model )
        w:ChangeRadius()

        if w.isOnRight then
            w:SetModelOffset( -offset )
            w:SetModelAngle( angle + Angle( 0, 180, 0 ) )
        else
            w:SetModelOffset( offset )
            w:SetModelAngle( angle )
        end
    end
end

function TOOL:LeftClick( trace )
    local veh, frontWheels, rearWheels = self:GetGlideWheels( trace )
    if not veh then return false end

    if SERVER then
        local frontModel = self:GetClientInfo( "front" )
        local rearModel = self:GetClientInfo( "rear" )

        local frontScale = Vector(
            self:GetClientNumber( "front_scale_x", 1 ),
            self:GetClientNumber( "front_scale_y", 1 ),
            self:GetClientNumber( "front_scale_z", 1 )
        )

        local rearScale = Vector(
            self:GetClientNumber( "rear_scale_x", 1 ),
            self:GetClientNumber( "rear_scale_y", 1 ),
            self:GetClientNumber( "rear_scale_z", 1 )
        )

        self:ApplyModifications( frontWheels, frontModel, frontScale )
        self:ApplyModifications( rearWheels, rearModel, rearScale )
    end

    return true
end

function TOOL:RightClick( trace )
    local veh, frontWheels, rearWheels = self:GetGlideWheels( trace )
    if not veh then return false end

    if SERVER then
        local frontModel = frontWheels[1]:GetModel()
        local rearModel = rearWheels[1]:GetModel()
        local ply = self:GetOwner()

        ply:ConCommand( "glide_wheel_model_front " .. frontModel )
        ply:ConCommand( "glide_wheel_model_rear " .. rearModel )
    end

    return true
end

function TOOL:Reload()
    return false
end

function TOOL.BuildCPanel( panel )
    local models = {}

    for path, _ in pairs( list.Get( "GlideWheelModels" ) ) do
        models[path] = { convar = path }
    end

    -- Front wheels
    panel:Help( "#tool.glide_wheel_model.front_scale" )

    panel:NumSlider( "X", "glide_wheel_model_front_scale_x", 0.1, 5, 2 )
    panel:NumSlider( "Y", "glide_wheel_model_front_scale_y", 0.1, 5, 2 )
    panel:NumSlider( "Z", "glide_wheel_model_front_scale_z", 0.1, 5, 2 )

    panel:PropSelect( "#tool.glide_wheel_model.front_model", "glide_wheel_model_front", models, 3 )

    -- Rear wheels
    panel:Help( "#tool.glide_wheel_model.rear_scale" )

    panel:NumSlider( "X", "glide_wheel_model_rear_scale_x", 0.1, 5, 2 )
    panel:NumSlider( "Y", "glide_wheel_model_rear_scale_y", 0.1, 5, 2 )
    panel:NumSlider( "Z", "glide_wheel_model_rear_scale_z", 0.1, 5, 2 )

    panel:PropSelect( "#tool.glide_wheel_model.rear_model", "glide_wheel_model_rear", models, 3 )
end

list.Set( "GlideWheelModels", "models/gta5/vehicles/airbus/wheel_front.mdl", { angle = angle_zero, scale = Vector( 1, 0.35, 1 ) } )
list.Set( "GlideWheelModels", "models/gta5/vehicles/airbus/wheel_rear.mdl", { angle = angle_zero, scale = Vector( 1, 0.35, 1 ) } )
list.Set( "GlideWheelModels", "models/gta5/vehicles/blazer/wheel.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.5, 1, 1 ) } )
list.Set( "GlideWheelModels", "models/gta5/vehicles/dukes/wheel.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.35, 1, 1 ) } )
list.Set( "GlideWheelModels", "models/gta5/vehicles/gauntlet_classic/wheel.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.35, 1, 1 ) } )
list.Set( "GlideWheelModels", "models/gta5/vehicles/speedo/wheel.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.35, 1, 1 ) } )
list.Set( "GlideWheelModels", "models/gta5/vehicles/stunt/stunt_wheel.mdl", { angle = Angle( 0, 180, 0 ), scale = Vector( 1, 0.6, 1 ) } )

list.Set( "GlideWheelModels", "models/mechanics/wheels/bmw.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/rim_1.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/tractors.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/wheel_2.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/wheel_extruded_48.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/wheel_race.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/wheel_rounded_36.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/wheel_rugged_24.mdl", {} )
list.Set( "GlideWheelModels", "models/mechanics/wheels/wheel_spike_24.mdl", {} )
list.Set( "GlideWheelModels", "models/nateswheel/nateswheel.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.4, 1, 1 ) } )
list.Set( "GlideWheelModels", "models/props_phx/normal_tire.mdl", { offset = Vector( 0, -4, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/smallwheel.mdl", { offset = Vector( 0, -4, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/747wheel.mdl", { offset = Vector( 0, -4, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/breakable_tire.mdl", { offset = Vector( 0, -4, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/drugster_back.mdl", { offset = Vector( 0, -4, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/drugster_front.mdl", { offset = Vector( 0, -4, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/magnetic_large.mdl", { offset = Vector( 0, -4, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/monster_truck.mdl", { offset = Vector( 0, -3.5, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/moped_tire.mdl", { offset = Vector( 0, -7, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/trucktire.mdl", { offset = Vector( 0, -3.5, 0 ) } )
list.Set( "GlideWheelModels", "models/props_phx/wheels/trucktire2.mdl", { offset = Vector( 0, -3.5, 0 ) } )
list.Set( "GlideWheelModels", "models/props_vehicles/apc_tire001.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.35, 1, 1 ) } )
list.Set( "GlideWheelModels", "models/xeon133/offroad/off-road-30.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.4, 1, 1 ) } )
list.Set( "GlideWheelModels", "models/xeon133/racewheel/race-wheel-30.mdl", { angle = Angle( 90, 0, 0 ), scale = Vector( 1, 0.4, 1 ) } )
list.Set( "GlideWheelModels", "models/xqm/airplanewheel1medium.mdl", { angle = Angle( 0, 90, 0 ), scale = Vector( 0.35, 1, 1 ) } )

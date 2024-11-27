ENT.Type = "anim"
ENT.Base = "base_glide"

ENT.PrintName = "Glide Car"
ENT.Author = "StyledStrike"
ENT.AdminOnly = false
ENT.Editable = true

-- Change vehicle type
ENT.VehicleType = Glide.VEHICLE_TYPE.CAR

-- Setup player sit animations
ENT.SeatDriverAnim = "drive_jeep"
ENT.SeatPassengerAnim = "sit"

-- Decrease default max. chassis health
ENT.MaxChassisHealth = 900

-- Should we allow editing the wheel radius?
ENT.AllowEditWheelRadius = true

-- Should we allow editing the suspension length?
ENT.AllowEditSuspensionLen = true

DEFINE_BASECLASS( "base_glide" )

--[[
    For cars, the values on Get/SetEngineState mean:

    0 - Off
    1 - Starting
    2 - Running
    3 - Shutting down or Ignition/Fuel cut-off
]]

function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    -- Setup default network variables. Do not override
    -- these slots when creating your own on child classes!
    self:NetworkVar( "Bool", "IsRedlining" )
    self:NetworkVar( "Bool", "IsHonking" )
    self:NetworkVar( "Bool", "IsBraking" )

    self:NetworkVar( "Int", "HeadlightState" )
    self:NetworkVar( "Int", "Gear" )

    self:NetworkVar( "Float", "Steering" )
    self:NetworkVar( "Float", "EngineRPM" )
    self:NetworkVar( "Float", "EngineThrottle" )

    -- Wheel and suspension properties, allow editing with the C menu.
    self:NetworkVar( "Vector", "TireSmokeColor", { KeyName = "TireSmokeColor", Edit = { type = "VectorColor", order = 0, category = "#glide.editvar.wheels" } } )

    local order = 0

    -- We add a bunch of floats here so, this utility function helps.
    local function AddFloatVar( key, min, max, category )
        order = order + 1

        local editData = Either( category == nil, nil, {
            KeyName = key,
            Edit = { type = "Float", order = order, min = min, max = max, category = category }
        } )

        self:NetworkVar( "Float", key, editData )
    end

    local function AddBoolVar( key, category )
        order = order + 1

        self:NetworkVar( "Bool", key, {
            KeyName = key,
            Edit = { type = "Bool", order = order, category = category }
        } )
    end

    AddBoolVar( "TurboCharged", "#glide.editvar.engine" )
    AddBoolVar( "FastTransmission", "#glide.editvar.engine" )

    -- Fake engine parameters
    AddFloatVar( "MinRPM", 1000, 50000, "#glide.editvar.engine" )
    AddFloatVar( "MaxRPM", 1000, 50000, "#glide.editvar.engine" )
    AddFloatVar( "MinRPMTorque", 10, 10000, "#glide.editvar.engine" )
    AddFloatVar( "MaxRPMTorque", 10, 10000, "#glide.editvar.engine" )
    AddFloatVar( "DifferentialRatio", 0.5, 5, "#glide.editvar.engine" )
    AddFloatVar( "TransmissionEfficiency", 0.3, 1, "#glide.editvar.engine" )

    -- Make wheel parameters available as network variables too
    AddFloatVar( "WheelRadius", 10, 40, Either( self.AllowEditWheelRadius, "#glide.editvar.wheels", nil ) )
    AddFloatVar( "WheelInertia", 1, 100, "#glide.editvar.wheels" )
    AddFloatVar( "MaxSteerAngle", 10, 50, "#glide.editvar.wheels" )
    AddFloatVar( "BrakePower", 500, 5000, "#glide.editvar.wheels" )

    AddFloatVar( "SuspensionLength", 5, 50, Either( self.AllowEditSuspensionLen, "#glide.editvar.suspension", nil ) )
    AddFloatVar( "SpringStrength", 100, 5000, "#glide.editvar.suspension" )
    AddFloatVar( "SpringDamper", 100, 10000, "#glide.editvar.suspension" )

    AddFloatVar( "MaxSlip", 5, 50, "#glide.editvar.static_friction" )
    AddFloatVar( "SlipForce", 10, 500, "#glide.editvar.static_friction" )

    AddFloatVar( "ExtremumValue", 0.5, 10, "#glide.editvar.dynamic_friction" )
    AddFloatVar( "AsymptoteSlip", 0, 1, "#glide.editvar.dynamic_friction" )
    AddFloatVar( "AsymptoteValue", 0.5, 5, "#glide.editvar.dynamic_friction" )

    if SERVER then
        -- Callback used to change the wheel radius
        self:NetworkVarNotify( "WheelRadius", self.OnWheelRadiusChange )
    end

    if CLIENT then
        -- Callback used to play gear change sounds
        self:NetworkVarNotify( "Gear", self.OnGearChange )
    end
end

function ENT:UpdatePlayerPoseParameters( ply )
    ply:SetPlaybackRate( 1 )

    if CLIENT and ply == self:GetDriver() then
        ply:SetPoseParameter( "vehicle_steer", self:GetSteering() )
        ply:InvalidateBoneCache()
    end

    return true
end

--- Override the base class `IsEngineOn` function.
function ENT:IsEngineOn()
    return self:GetEngineState() > 1
end

if CLIENT then
    -- Set which camera mode to use when entering this vehicle
    ENT.CameraType = Glide.CAMERA_TYPE.CAR
    ENT.CameraOffset = Vector( -230, 0, 50 )
    ENT.CameraAngleOffset = Angle( 4, 0, 0 )

    -- Setup how far away players can hear sounds and update misc. features
    ENT.MaxSoundDistance = 3000
    ENT.MaxMiscDistance = 4000

    -- Sounds
    ENT.StartSound = "Glide.Engine.CarStart"
    ENT.StartTailSound = "Glide.Engine.CarStartTail"
    ENT.ExhaustPopSound = "Glide.ExhaustPop.Sport"
    ENT.StartedSound = ""
    ENT.StoppedSound = "glide/engines/shut_down_1.wav"

    ENT.ExternalGearSwitchSound = "Glide.GearSwitch.External"
    ENT.InternalGearSwitchSound = "Glide.GearSwitch.Internal"
    ENT.HornSound = "glide/horns/car_horn_med_2.wav"

    ENT.ReverseSound = ""
    ENT.BrakeReleaseSound = ""
    ENT.BrakeSqueakSound = ""

    -- Exhaust positions
    ENT.ExhaustOffsets = {}
    ENT.ExhaustAlpha = 50

    -- Strips/lines where smoke particles are spawned when the engine is damaged
    ENT.EngineSmokeStrips = {}

    -- How much does the engine smoke gets shot up?
    ENT.EngineSmokeMaxZVel = 100

    -- Offset for break, reverse and headlight sprites
    ENT.LightSprites = {}

    -- Positions and colors for headlights
    ENT.Headlights = {}

    -- Children classes should override this
    -- function to add engine sounds to the stream.
    function ENT:OnCreateEngineStream( _stream ) end

    -- Children classes should override this function
    -- to update animations (the steering wheel for example).
    function ENT:OnUpdateAnimations()
        self:SetPoseParameter( "vehicle_steer", self:GetSteering() )
    end
end

if SERVER then
    ENT.EngineDamageMultiplier = 0.0016
    ENT.CollisionParticleSize = 0.9
    ENT.CollisionDamageMultiplier = 1.8
    ENT.AngularDrag = Vector( -0.5, -0.5, -3 ) -- Roll, pitch, yaw

    -- The steering angle is multiplied by this value before it is passed to
    -- the wheel models. This is purely visual, in other words, what you see
    -- in game is not what is actually happening to the steering angles.
    ENT.ModelSteerAngleMultiplier = 0.7

    -- The car's forward speed is divided by this value,
    -- and the resulting value is used to reduce the steering angles.
    ENT.SteerSpeedFactor = 1500

    -- How long does it take for the vehicle to start up?
    ENT.StartupTime = 0.6

    -- Is the driver allowed to switch headlights?
    ENT.CanSwitchHeadlights = true

    -- Bodygroup toggles for break, reverse and headlights
    ENT.LightBodygroups = {}

    -- How much force to apply when trying to turn while doing a burnout?
    ENT.BurnoutForce = 60

    -- How much force to apply when the driver tries to unflip the vehicle?
    ENT.UnflipForce = 3

    -- How much force to apply when the driver tries to spin the airborne vehicle?
    ENT.AirControlForce = Vector( 0.8, 0.3, 0.2 ) -- Roll, pitch, yaw

    -- How fast can the driver spin the vehicle while airborne?
    ENT.AirMaxAngularVelocity = Vector( 150, 200, 150 ) -- Roll, pitch, yaw

    --- Returns which inputs applies air control forces.
    --- Should return a roll, pitch and yaw input.
    function ENT:GetAirInputs()
        return self:GetInputFloat( 1, "steer" ), self:GetInputFloat( 1, "lean_pitch" ), 0
    end

    --- Returns a list of available gears and gear ratios for this vehicle.
    --- This has to be a function because children classes couldn't remove
    --- existing keys if this list was defined on the ENT table.
    function ENT:GetGears()
        return {
            [-1] = 2.9, -- Reverse
            [0] = 0, -- Neutral (this number has no effect)
            [1] = 2.8,
            [2] = 1.78,
            [3] = 1.3,
            [4] = 1,
            [5] = 0.8,
            [6] = 0.7
        }
    end

    -- Save these network variables when using the duplicator
    ENT.DuplicatorNetworkVariables = {
        TireSmokeColor = true,
        WheelRadius = true,
        WheelInertia = true,
        MaxSteerAngle = true,

        BrakePower = true,
        SuspensionLength = true,
        SpringStrength = true,
        SpringDamper = true,

        MaxSlip = true,
        SlipForce = true,

        ExtremumValue = true,
        AsymptoteSlip = true,
        AsymptoteValue = true,

        MinRPM = true,
        MaxRPM = true,
        MinRPMTorque = true,
        MaxRPMTorque = true,
        DifferentialRatio = true,
        TransmissionEfficiency = true
    }
end

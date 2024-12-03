ENT.Type = "anim"
ENT.Base = "base_glide_aircraft"

ENT.PrintName = "Glide Plane"
ENT.Author = "StyledStrike"
ENT.AdminOnly = false
ENT.AutomaticFrameAdvance = true

-- Change vehicle type
ENT.VehicleType = Glide.VEHICLE_TYPE.PLANE

-- Setup the plane propeller position
ENT.PropOffset = Vector()

DEFINE_BASECLASS( "base_glide_aircraft" )

function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Float", "Elevator" )
    self:NetworkVar( "Float", "Rudder" )
    self:NetworkVar( "Float", "Aileron" )
end

if CLIENT then
    ENT.MaxSoundDistance = 15000

    -- Play this sound at startup
    ENT.StartSoundPath = "glide/aircraft/start_3.wav"

    -- Play this sound from far away
    ENT.DistantSoundPath = "glide/aircraft/distant_stunt.wav"
    ENT.DistantSoundLevel = 140

    -- Play this sound at the propeller
    ENT.PropSoundPath = "glide/aircraft/prop_stunt.wav"
    ENT.PropSoundLevel = 80
    ENT.PropSoundVolume = 0.7
    ENT.PropSoundMinPitch = 62
    ENT.PropSoundMaxPitch = 105

    -- Play these sounds at the engine
    ENT.EngineSoundPath = "glide/aircraft/engine_velum.wav"
    ENT.EngineSoundLevel = 80
    ENT.EngineSoundVolume = 0.6
    ENT.EngineSoundMinPitch = 165
    ENT.EngineSoundMaxPitch = 190

    ENT.ExhaustSoundPath = "glide/aircraft/exhaust_stunt.wav"
    ENT.ExhaustSoundLevel = 80
    ENT.ExhaustSoundVolume = 0.7
    ENT.ExhaustSoundMinPitch = 100
    ENT.ExhaustSoundMaxPitch = 115

    ENT.StrobeLights = {}

    ENT.StrobeLightColors = {
        Color( 255, 255, 255 ),
        Color( 255, 0, 0 ),
        Color( 0, 255, 0 )
    }

    -- Children classes should override this function
    -- to update animations (the control surfaces for example).
    function ENT:OnUpdateAnimations() end
end

if SERVER then
    ENT.CollisionDamageMultiplier = 4
    ENT.AngularDrag = Vector( -2, -2, -10 ) -- Roll, pitch, yaw

    -- How far can the propeller's blades hit things
    ENT.PropRadius = 50

    -- Slow and fast models for the propeller
    ENT.PropModel = "models/gta5/vehicles/stunt/stunt_prop_slow.mdl"
    ENT.PropFastModel = "models/gta5/vehicles/stunt/stunt_prop_fast.mdl"

    -- Ground steering variables
    ENT.MaxSteerAngle = 40
    ENT.SteerSpeedFactor = 800
    ENT.ReverseTorque = 1000
    ENT.MaxReverseSpeed = -300

    -- Plane drag & force constants
    ENT.PlaneParams = {
        -- These drag forces only apply
        -- when flying at max. liftSpeed.
        liftAngularDrag = Vector( -5, -10, -3 ), -- (Roll, pitch, yaw)
        liftForwardDrag = 0.1,
        liftSideDrag = 3,

        liftFactor = 0.15,       -- How much of the up velocity to negate
        maxSpeed = 1800,        -- Speed limit
        liftSpeed = 1600,       -- Speed required to float
        controlSpeed = 1200,    -- Speed required to have complete control of the plane

        engineForce = 200,
        alignForce = 300,

        pitchForce = 1000,
        yawForce = 500,
        rollForce = 1200
    }
end

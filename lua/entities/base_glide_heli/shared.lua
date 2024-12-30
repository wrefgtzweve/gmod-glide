ENT.Type = "anim"
ENT.Base = "base_glide_aircraft"

ENT.PrintName = "Glide Helicopter"
ENT.Author = "StyledStrike"
ENT.AdminOnly = false
ENT.AutomaticFrameAdvance = true

-- Change vehicle type
ENT.VehicleType = Glide.VEHICLE_TYPE.HELICOPTER

-- Setup the helicopter's rotor positions
ENT.MainRotorOffset = Vector()
ENT.MainRotorAngle = Angle()

ENT.TailRotorOffset = Vector()
ENT.TailRotorAngle = Angle()

DEFINE_BASECLASS( "base_glide_aircraft" )

--- Override this base class function.
function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Bool", "OutOfControl" )
    self:SetOutOfControl( false )

    if CLIENT then
        -- Callback used to play out-of-control sounds clientside
        self:NetworkVarNotify( "OutOfControl", self.OnOutOfControlChange )
    end
end

if CLIENT then

    -- Play this sound at startup
    ENT.StartSoundPath = "glide/helicopters/start_1.mp3"

    -- Play this sound at the tail rotor
    ENT.TailSoundPath = "glide/helicopters/tail_rotor_1.wav"
    ENT.TailSoundLevel = 60

    -- Play this sound at the engine
    ENT.EngineSoundPath = "glide/helicopters/howl_1.wav"
    ENT.EngineSoundLevel = 75
    ENT.EngineSoundVolume = 0.9

    -- Play this sound at the engine too
    ENT.JetSoundPath = "glide/helicopters/jet_2.wav"
    ENT.JetSoundLevel = 60
    ENT.JetSoundVolume = 0.4

    -- Play this sound that can be heard from far away
    ENT.DistantSoundPath = "glide/helicopters/distant_loop_2.wav"

    -- Delay between each rotor "beat"
    ENT.RotorBeatInterval = 0.08

    -- Rotor beat sound sets (See lua/glide/sh_soundsets.lua)
    ENT.BassSoundSet = "Glide.GenericRotor.Bass"
    ENT.MidSoundSet = "Glide.GenericRotor.Mid"
    ENT.HighSoundSet = "Glide.GenericRotor.High"

    ENT.BassSoundVol = 1.0
    ENT.MidSoundVol = 0.4
    ENT.HighSoundVol = 0.8
end

if SERVER then
    ENT.CollisionDamageMultiplier = 2
    ENT.AngularDrag = Vector( -10, -18, -10 ) -- Roll, pitch, yaw

    -- How far can the rotor's blades hit things
    ENT.MainRotorRadius = 210
    ENT.TailRotorRadius = 10

    -- Slow and fast models for the main rotor
    ENT.MainRotorModel = "models/gta5/vehicles/frogger/frogger_rmain_slow.mdl"
    ENT.MainRotorFastModel = "models/gta5/vehicles/frogger/frogger_rmain_fast.mdl" -- Can be "" to use the slow model

    -- Slow and fast models for the tail rotor
    ENT.TailRotorModel = "models/gta5/vehicles/frogger/frogger_rrear_slow.mdl"
    ENT.TailRotorFastModel = "models/gta5/vehicles/frogger/frogger_rrear_fast.mdl" -- Can be "" to use the slow model

    -- Helicopter drag & force constants.
    -- On children classes, you don't have to override
    -- the whole table, just the values you want to change.
    ENT.HelicopterParams = {
        -- Add this to the power used on OnSimulatePhysics.
        -- Mostly used for things that float even while the engine is off.
        basePower = 0,

        drag = Vector( 0.3, 0.5, 0.5 ),     -- Forward, right, up
        maxFowardDrag = 200,                -- Limit "forward" drag force
        maxSideDrag = 300,                  -- Limit "right" drag force

        turbulanceForce = 50,   -- Force to wobble the helicopter
        pushUpForce = 250,      -- Up input force
        pitchForce = 700,       -- Pitch input force
        yawForce = 700,         -- Yaw input force
        rollForce = 700,        -- Roll input force

        pushForwardForce = 10,  -- Forward input force
        maxSpeed = 2000,        -- `PushForwardForce` won't apply when going faster than this

        uprightForce = 1000,    -- Force that tries to keep the helicopter upright
        maxPitch = 70,          -- Don't let the helicopter pitch more than this
        maxRoll = 85            -- Don't let the helicopter roll more than this
    }
end

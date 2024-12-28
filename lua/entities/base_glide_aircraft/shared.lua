ENT.Type = "anim"
ENT.Base = "base_glide"

ENT.PrintName = "Glide Aircraft"
ENT.Author = "StyledStrike"
ENT.AdminOnly = false
ENT.AutomaticFrameAdvance = true

-- Increase default max. chassis health
ENT.MaxChassisHealth = 1200

DEFINE_BASECLASS( "base_glide" )

--- Override this base class function.
function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Float", "Power" )
    self:SetPower( 0 )
end

--- Override this base class function.
function ENT:GetPlayerSitSequence( _seatIndex )
    return "sit"
end

if CLIENT then
    -- Set exhaust positions relative to the chassis
    ENT.ExhaustPositions = {}

    --- Override this base class function.
    function ENT:GetCameraType( _seatIndex )
        return 2 -- Glide.CAMERA_TYPE.AIRCRAFT
    end
end

if SERVER then
    ENT.IsHeavyVehicle = true
    ENT.ExplosionRadius = 700
    ENT.SuspensionHeavySound = "Glide.Suspension.CompressBike"

    -- Damaged engine sound
    ENT.DamagedEngineSound = "Glide.Damaged.GearGrind"
    ENT.DamagedEngineVolume = 0.4

    -- Should this vehicle use the landing gear system?
    ENT.HasLandingGear = false

    -- Setting this to a number higher than 0
    -- will enable flare contermeasures.
    ENT.CountermeasureCount = 3

    -- Delay between deployment of countermeasures
    ENT.CountermeasureCooldown = 5

    -- Animations to play when the landing gear state changes
    ENT.LandingGearAnims = {
        [0] = "gear_down",
        [1] = "move_gear_up",
        [2] = "gear_up",
        [3] = "move_gear_down"
    }

    -- Sounds to play when the landing gear state changes
    ENT.LandingGearSounds = {
        -- Sound path (empty to not play), volume, pitch
        [0] = { "", 1.0, 100 },
        [1] = { "glide/aircraft/gear_down.wav", 0.65, 100 },
        [2] = { "physics/metal/metal_barrel_impact_soft4.wav", 0.5, 100 },
        [3] = { "glide/aircraft/gear_down.wav", 0.65, 90 }
    }

    -- You can override this on your child classes.
    function ENT:OnLandingGearStateChange( _state ) end

    function ENT:RotorStartSpinningFast( rotor )
        rotor:SetModel( rotor.modelFast or rotor.modelSlow )
    end

    function ENT:RotorStopSpinningFast( rotor )
        rotor:SetModel( rotor.modelSlow )
    end
end

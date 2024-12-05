ENT.Type = "anim"
ENT.Base = "base_glide"

ENT.PrintName = "Glide Aircraft"
ENT.Author = "StyledStrike"
ENT.AdminOnly = false
ENT.AutomaticFrameAdvance = true

-- Setup player sit animations
ENT.SeatDriverAnim = "sit"
ENT.SeatPassengerAnim = "sit"

-- Increase default max. chassis health
ENT.MaxChassisHealth = 1200

DEFINE_BASECLASS( "base_glide" )

--- Override this base class function.
function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Float", "Power" )
    self:SetPower( 0 )
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
end

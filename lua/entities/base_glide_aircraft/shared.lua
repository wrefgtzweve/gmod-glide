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

function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Float", "Power" )
    self:SetPower( 0 )
end

if CLIENT then
    -- Set exhaust positions relative to the chassis
    ENT.ExhaustPositions = {}

    function ENT:GetCameraType( _seatIndex )
        return 2 -- Glide.CAMERA_TYPE.AIRCRAFT
    end
end

if SERVER then
    ENT.IsHeavyVehicle = true
    ENT.SuspensionHeavySound = "Glide.Suspension.CompressBike"

    -- Should this vehicle use the landing gear system?
    ENT.HasLandingGear = false

    -- Animations to play when the landing gear state changes
    ENT.LandingGearAnims = {
        [0] = "gear_down",
        [1] = "move_gear_up",
        [2] = "gear_up",
        [3] = "move_gear_down"
    }
end

ENT.Type = "anim"
ENT.Base = "base_glide"

ENT.PrintName = "Glide Tank"
ENT.Author = "StyledStrike"
ENT.AdminOnly = false
ENT.AutomaticFrameAdvance = true

-- Change vehicle type
ENT.VehicleType = Glide.VEHICLE_TYPE.TANK

-- Setup player sit animations
ENT.SeatDriverAnim = "sit"
ENT.SeatPassengerAnim = "sit"

-- Increase default max. chassis health
ENT.MaxChassisHealth = 3000

DEFINE_BASECLASS( "base_glide" )

function ENT:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Float", "EngineThrottle" )
    self:NetworkVar( "Float", "EnginePower" )
    self:NetworkVar( "Float", "TrackSpeed" )
    self:NetworkVar( "Angle", "TurretAngle" )
end

if CLIENT then
    -- Set which camera mode to use when entering this vehicle
    ENT.CameraType = Glide.CAMERA_TYPE.TURRET

    -- Setup default cannon
    ENT.WeaponInfo = {
        { name = "#glide.weapons.cannon", icon = "glide/icons/tank.png", crosshairType = "square", dontAutoUpdateCrosshair = true }
    }

    -- Track sound parameters
    ENT.TrackSound = ")glide/tanks/tracks_leopard.wav"
    ENT.TrackVolume = 0.9

    -- Engine sounds
    ENT.StartedSound = "glide/engines/start_tail_truck.wav"
    ENT.StoppedSound = "glide/engines/shut_down_1.wav"

    -- Children classes should override this
    -- function to add engine sounds to the stream.
    function ENT:OnCreateEngineStream( _stream ) end

    -- Children classes should override this function
    -- to update animations (the tracks/suspension for example).
    function ENT:OnUpdateAnimations() end
end

if SERVER then
    ENT.IsHeavyVehicle = true
    ENT.ChassisMass = 20000
    ENT.EngineDamageMultiplier = 0.0015

    ENT.SuspensionHeavySound = "Glide.Suspension.CompressTruck"
    ENT.SuspensionDownSound = "Glide.Suspension.Stress"

    -- Setup default cannon
    ENT.WeaponSlots = {
        { maxAmmo = 0, fireRate = 2.0 },
    }

    ENT.MinPitchAng = -25
    ENT.MaxPitchAng = 5
    ENT.MaxYawSpeed = 1

    -- How much torque to distribute among all wheels?
    ENT.EngineTorque = 40000

    -- How much extra torque to apply when trying to spin in place?
    ENT.SpinEngineTorqueMultiplier = 2

    ENT.MaxSpeed = 700
    ENT.MaxSteerAngle = 35

    -- Children classes should override this function
    -- to update bones (the turret/cannon for example).
    function ENT:OnUpdateBones() end

    -- Children classes should override this function
    -- to set where the cannon projectile is spawned.
    function ENT:GetProjectileStartPos()
        return self:GetPos()
    end
end

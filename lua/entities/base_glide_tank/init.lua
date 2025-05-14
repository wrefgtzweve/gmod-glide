AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

DEFINE_BASECLASS( "base_glide_car" )

--- Implement this base class function.
function ENT:OnPostInitialize()
    BaseClass.OnPostInitialize( self )

    -- Setup variables used on all tanks
    self.isTurningInPlace = false
    self.isCannonInsideWall = false

    self:SetTrackSpeed( 0 )
    self:SetTurretAngle( Angle() )
    self:SetIsAimingAtTarget( false )

    -- Override default NW engine params from the base class
    self.engineBrakeTorque = 40000
    self:SetMinRPMTorque( 40000 )
    self:SetMaxRPMTorque( 35000 )
    self:SetDifferentialRatio( 0.75 )
    self:SetTransmissionEfficiency( 1.0 )
    self:SetPowerDistribution( 0.0 )

    -- Steering parameters
    self:SetMaxSteerAngle( 30 )
    self:SetSteerConeChangeRate( 8 )
    self:SetSteerConeMaxSpeed( 500 )
    self:SetSteerConeMaxAngle( 0.25 )
    self:SetCounterSteer( 0.75 )

    -- Override default NW wheel params from the base class
    local params = {
        -- Suspension
        suspensionLength = 15,
        springStrength = 6000,
        springDamper = 30000,

        -- Brake force
        brakePower = 15000,

        -- Forward traction
        forwardTractionMax = 50000,

        -- Side traction
        sideTractionMultiplier = 800,
        sideTractionMaxAng = 25,
        sideTractionMax = 12000,
        sideTractionMin = 10000
    }

    -- Maximum length of the suspension
    self:SetSuspensionLength( params.suspensionLength )

    -- How strong is the suspension spring
    self:SetSpringStrength( params.springStrength )

    -- Damping coefficient for when the suspension is compressed/expanded
    self:SetSpringDamper( params.springDamper )

    -- Brake coefficient
    self:SetBrakePower( params.brakePower )

    -- Traction parameters
    self:SetForwardTractionMax( params.forwardTractionMax )
    self:SetForwardTractionBias( 0.0 )

    self:SetSideTractionMultiplier( params.sideTractionMultiplier )
    self:SetSideTractionMaxAng( params.sideTractionMaxAng )
    self:SetSideTractionMax( params.sideTractionMax )
    self:SetSideTractionMin( params.sideTractionMin )
end

--- Override this base class function.
function ENT:TurnOff()
    BaseClass.TurnOff( self )

    self.isTurningInPlace = false
end

--- Override this base class function.
function ENT:OnTakeDamage( dmginfo )
    if dmginfo:IsDamageType( 64 ) then -- DMG_BLAST
        local inflictor = dmginfo:GetInflictor()

        -- Increase damage taken by Half-life 2 RPGs
        if IsValid( inflictor ) and inflictor:GetClass() == "rpg_missile" then
            dmginfo:SetDamage( dmginfo:GetDamage() * 2.5 )
        end
    end

    BaseClass.OnTakeDamage( self, dmginfo )
end

function ENT:GetTurretOrigin()
    return self:LocalToWorld( self.TurretOffset )
end

function ENT:GetTurretAimDirection()
    local origin = self:GetTurretOrigin()
    local ang = self:LocalToWorldAngles( self:GetTurretAngle() )

    -- Use the driver's aim position directly when
    -- the turret is aiming close enough to it.
    local driver = self:GetDriver()

    if IsValid( driver ) and self:GetIsAimingAtTarget() then
        local dir = driver:GlideGetAimPos() - origin
        dir:Normalize()
        ang = dir:Angle()
    end

    return ang:Forward()
end

local TraceLine = util.TraceLine

function ENT:GetTurretAimPosition()
    local origin = self:GetTurretOrigin()
    local target = origin + self:GetTurretAimDirection() * 50000
    local tr = TraceLine( self:GetTraceData( origin, target ) )

    if tr.Hit then
        target = tr.HitPos
    end

    return target
end

--- Implement this base class function.
function ENT:OnWeaponFire( weapon )
    if self:WaterLevel() > 2 then return end

    if self.isCannonInsideWall then
        weapon.nextFire = 0
        return
    end

    local aimPos = self:GetTurretAimPosition()
    local projectilePos = self:GetProjectileStartPos()

    -- Make the projectile point towards the direction the
    -- turret is aiming at, no matter where it spawned.
    local dir = aimPos - projectilePos
    dir:Normalize()

    local projectile = Glide.FireProjectile( projectilePos, dir:Angle(), self:GetDriver(), self )
    projectile.damage = self.TurretDamage

    self:EmitSound( self.TurretFireSound, 100, math.random( 95, 105 ), self.TurretFireVolume )

    local eff = EffectData()
    eff:SetOrigin( projectilePos )
    eff:SetNormal( dir )
    eff:SetScale( 1 )
    util.Effect( "glide_tank_cannon", eff )

    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        phys:ApplyForceOffset( dir * phys:GetMass() * -self.TurretRecoilForce, projectilePos )
    end

    local driver = self:GetDriver()

    if IsValid( driver ) then
        Glide.SendViewPunch( driver, -0.2 )
    end
end

local Abs = math.abs

--- Override this base class function.
function ENT:OnPostThink( dt, selfTbl )
    BaseClass.OnPostThink( self, dt, selfTbl )

    -- Update turret angles, if we have a driver
    local driver = self:GetDriver()

    if IsValid( driver ) and self:WaterLevel() < 2 then
        local newAng, isAimingAtTarget = self:UpdateTurret( driver, dt, self:GetTurretAngle() )

        -- Don't let it shoot while inside walls
        local origin = self:GetTurretOrigin()
        local projectilePos = self:GetProjectileStartPos()
        local tr = TraceLine( self:GetTraceData( origin, projectilePos ) )

        selfTbl.isCannonInsideWall = tr.Hit

        if selfTbl.isCannonInsideWall then
            isAimingAtTarget = false
        end

        self:SetTurretAngle( newAng )
        self:SetIsAimingAtTarget( isAimingAtTarget )
        self:ManipulateTurretBones( newAng )
    end
end

--- Override this base class function.
function ENT:WheelThink( dt )
    BaseClass.WheelThink( self, dt )

    local phys = self:GetPhysicsObject()

    if IsValid( phys ) and phys:IsAsleep() then
        self:SetTrackSpeed( 0 )
    else
        local totalAngVel = 0

        for _, w in ipairs( self.wheels ) do
            totalAngVel = totalAngVel + Abs( w.state.angularVelocity )
        end

        self:SetTrackSpeed( totalAngVel / self.wheelCount )
    end
end

--[[    local inputThrottle = self:GetInputFloat( 1, "accelerate" )
    local inputHandbrake = self:GetInputBool( 1, "handbrake" )
    local inputBrake = self:GetInputFloat( 1, "brake" )
    local inputSteer = self:GetInputFloat( 1, "steer" )

    if inputHandbrake then
        inputThrottle = 0
        inputBrake = 1
    end

    self.isTurningInPlace = Abs( self.forwardSpeed ) < 100 and Abs( inputSteer ) > 0.1 and Abs( inputThrottle + inputBrake ) < 0.1
]]

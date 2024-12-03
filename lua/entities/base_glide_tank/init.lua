AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

duplicator.RegisterEntityClass( "base_glide_tank", Glide.VehicleFactory, "Data" )

DEFINE_BASECLASS( "base_glide" )

--- Implement the base class `OnPostInitialize` function.
function ENT:OnPostInitialize()
    -- Setup variables used on all tanks
    self.wheelCountL = 0
    self.wheelCountR = 0

    self.availableTorqueL = 0
    self.availableTorqueR = 0

    self.isGrounded = false
    self.isTurningInPlace = false
    self.brake = 0.5

    -- Update default wheel params
    local params = self.wheelParams

    params.brakePower = 15000
    params.suspensionLength = 10
    params.springStrength = 6000
    params.springDamper = 30000

    params.maxSlip = 80
    params.slipForce = 300
    params.extremumValue = 20
    params.asymptoteValue = 15

    self:SetEngineThrottle( 0 )
    self:SetEnginePower( 0 )
    self:SetTrackSpeed( 0 )

    self:SetTurretAngle( Angle() )
    self:SetIsAimingAtTarget( false )
end

--- Implement the base class `OnDriverEnter` function.
function ENT:OnDriverEnter()
    self:TurnOn()
end

--- Implement the base class `OnDriverExit` function.
function ENT:OnDriverExit()
    self:TurnOff()
end

--- Override the base class `TurnOn` function.
function ENT:TurnOn()
    local state = self:GetEngineState()

    if state ~= 2 then
        self:SetEngineState( 1 )
    end

    self:SetEngineThrottle( 0 )
    self:SetEnginePower( 0 )
end

--- Override the base class `TurnOff` function.
function ENT:TurnOff()
    BaseClass.TurnOff( self )

    self.startupTimer = nil
    self.availableTorqueL = 0
    self.availableTorqueR = 0
    self.isTurningInPlace = false
    self.brake = 0.5
end

--- Override the base class `OnTakeDamage` function.
function ENT:OnTakeDamage( dmginfo )
    BaseClass.OnTakeDamage( self, dmginfo )

    if self:GetEngineHealth() <= 0 and self:GetEngineState() == 2 then
        self:TurnOff()
    end
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

function ENT:GetTurretAimPosition()
    local origin = self:GetTurretOrigin()
    local target = origin + self:GetTurretAimDirection() * 50000
    local tr = util.TraceLine( self:GetTraceData( origin, target ) )

    if tr.Hit then
        target = tr.HitPos
    end

    return target
end

--- Implement the base class `OnWeaponFire` function.
function ENT:OnWeaponFire()
    if self:WaterLevel() > 2 then return end

    local aimPos = self:GetTurretAimPosition()
    local projectilePos = self:GetProjectileStartPos()

    -- Make the projectile point towards the direction the
    -- turret is aiming at, no matter where it spawned.
    local dir = aimPos - projectilePos
    dir:Normalize()

    Glide.FireProjectile( projectilePos, dir:Angle(), self:GetDriver(), self )
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

--- Override the base class `CreateWheel` function.
function ENT:CreateWheel( offset, params )
    local wheel = BaseClass.CreateWheel( self, offset, params )

    wheel.isLeftTrack = offset[2] > 0

    if wheel.isLeftTrack then
        self.wheelCountL = self.wheelCountL + 1

        if self.wheelCountL == 2 then
            wheel.enableSounds = false
        end
    else
        self.wheelCountR = self.wheelCountR + 1

        if self.wheelCountR == 2 then
            wheel.enableSounds = false
        end
    end

    return wheel
end

local Abs = math.abs
local Clamp = math.Clamp

local ExpDecayAngle = Glide.ExpDecayAngle
local AngleDifference = Glide.AngleDifference

--- Implement the base class `OnPostThink` function.
function ENT:OnPostThink( dt )
    local state = self:GetEngineState()

    -- Damage the engine when underwater
    if self:WaterLevel() > 2 then
        if state == 2 then
            self:TurnOff()
        end

        self:SetEngineHealth( 0 )
        self:UpdateHealthOutputs()
    end

    local health = self:GetEngineHealth()

    -- Attempt to start the engine
    if state == 1 then
        if self.startupTimer then
            if CurTime() > self.startupTimer then
                self.startupTimer = nil

                -- TODO: check fuel before allowing startup
                if health > 0 then
                    self:SetEngineState( 2 )
                else
                    self:SetEngineState( 0 )
                end
            end
        else
            local startupTime = health < 0.5 and math.Rand( 1, 2 ) or self.StartupTime
            self.startupTimer = CurTime() + startupTime
        end
    end

    if self:IsEngineOn() then
        self:UpdateEngine( dt )

        -- Make sure the physics stay awake when necessary,
        -- otherwise the driver's input won't do anything.
        local phys = self:GetPhysicsObject()

        if IsValid( phys ) and phys:IsAsleep() then
            self:SetTrackSpeed( 0 )
            self.availableTorqueL = 0
            self.availableTorqueR = 0

            local driverInput = self:GetInputFloat( 1, "accelerate" ) + self:GetInputFloat( 1, "brake" ) + self:GetInputFloat( 1, "steer" )

            if Abs( driverInput ) > 0.01 then
                phys:Wake()
            end
        end
    end

    local torqueL = self.availableTorqueL / self.wheelCountL
    local torqueR = self.availableTorqueR / self.wheelCountR

    local isGrounded = false
    local totalSideSlip = 0
    local totalAngVel = 0

    for _, w in ipairs( self.wheels ) do
        totalAngVel = totalAngVel + Abs( w.angularVelocity )

        if w.isOnGround then
            w.brake = self.brake
            w.torque = w.isLeftTrack and torqueL or torqueR

            isGrounded = true
            totalSideSlip = totalSideSlip + w:GetSideSlip()
        else
            w.brake = 1
            w.torque = 0
        end
    end

    self.isGrounded = isGrounded
    self:SetTrackSpeed( totalAngVel / self.wheelCount )

    local inputSteer = self:GetInputFloat( 1, "steer" )
    local sideSlip = Clamp( totalSideSlip / self.wheelCount, -1, 1 )

    -- Limit the input and the rate of change depending on speed,
    -- but allow a faster rate of change when slipping sideways.
    local invSpeedOverFactor = 1 - Clamp( self.totalSpeed / self.MaxSpeed, 0, 1 )

    inputSteer = inputSteer * Clamp( invSpeedOverFactor, 0.2, 1 )

    -- Counter-steer when slipping and going fast
    local counterSteer = Clamp( sideSlip * ( 1 - invSpeedOverFactor ), -0.05, 0.05 )
    inputSteer = Clamp( inputSteer + counterSteer, -1, 1 )

    local maxAng = self.isTurningInPlace and 90 or self.MaxSteerAngle

    self.inputSteer = inputSteer
    self.steerAngle[2] = -inputSteer * maxAng

    -- Update turret angles, if we have a driver
    local driver = self:GetDriver()
    if not IsValid( driver ) or self:WaterLevel() > 2 then return end

    local origin = self:LocalToWorld( self.TurretOffset )
    local targetDir = driver:GlideGetAimPos() - origin
    targetDir:Normalize()

    local targetAng = self:WorldToLocalAngles( targetDir:Angle() )
    local currentAng = self:GetTurretAngle()
    local isAimingAtTarget = true

    if targetAng[1] > self.LowPitchAng then
        targetAng[1] = self.LowPitchAng
        isAimingAtTarget = false

    elseif targetAng[1] < self.HighPitchAng then
        targetAng[1] = self.HighPitchAng
        isAimingAtTarget = false
    end

    targetAng[2] = ExpDecayAngle( currentAng[2], targetAng[2], 30, dt )
    currentAng[1] = ExpDecayAngle( currentAng[1], targetAng[1], 10, dt )
    currentAng[2] = currentAng[2] + Clamp( AngleDifference( currentAng[2], targetAng[2] ), -self.MaxYawSpeed, self.MaxYawSpeed )

    isAimingAtTarget = isAimingAtTarget and targetDir:Dot( self:LocalToWorldAngles( currentAng ):Forward() ) > 0.99

    self:SetTurretAngle( currentAng )
    self:SetIsAimingAtTarget( isAimingAtTarget )
    self:ManipulateTurretBones()
end

local ExpDecay = Glide.ExpDecay

function ENT:UpdateEngine( dt )
    local inputThrottle = self:GetInputFloat( 1, "accelerate" )
    local inputBrake = self:GetInputFloat( 1, "brake" )
    local inputSteer = self:GetInputFloat( 1, "steer" )

    self.isTurningInPlace = Abs( self.forwardSpeed ) < 100 and Abs( inputSteer ) > 0.1 and Abs( inputThrottle + inputBrake ) < 0.1

    local inputL, inputR = 0, 0
    local extraBrake = 0
    local power = 0

    if self.isTurningInPlace then
        inputL = inputSteer * self.SpinEngineTorqueMultiplier
        inputR = -inputSteer * self.SpinEngineTorqueMultiplier
        inputBrake = 0
        power = Abs( inputSteer ) * 0.5

        self:SetEngineThrottle( ExpDecay( self:GetEngineThrottle(), 0.75, 4, dt ) )
    else
        if self.forwardSpeed < 10 and inputBrake > 0.1 then
            inputThrottle, inputBrake = -inputBrake, inputThrottle
        end

        self:SetEngineThrottle( ExpDecay( self:GetEngineThrottle(), Abs( inputThrottle ), 4, dt ) )

        if Abs( self.forwardSpeed ) > self.MaxSpeed then
            inputThrottle = 0
        end

        extraBrake = ( 1 - Abs( inputThrottle ) ) * 0.3
        power = Clamp( Abs( self.forwardSpeed ) / self.MaxSpeed, 0, 1 )

        inputL = inputThrottle
        inputR = inputL
    end

    self.brake = inputBrake + extraBrake
    self.availableTorqueL = self.EngineTorque * inputL
    self.availableTorqueR = self.EngineTorque * inputR

    self:SetEnginePower( ExpDecay( self:GetEnginePower(), power, 2, dt ) )
end

AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )

include( "shared.lua" )

function ENT:Initialize()
    self:SetModel( "models/editor/axis_helper.mdl" )
    self:SetSolid( SOLID_NONE )
    self:SetMoveType( MOVETYPE_VPHYSICS )

    self.torque = 0     -- Amount of torque to apply to the wheel
    self.brake = 0      -- Amount of brake torque to apply to the wheel
    self.spin = 0       -- Wheel spin angle around it's axle axis

    -- Should torque change the angular velocity of the wheel? (Can it do a burnout?)
    self.enableTorqueInertia = false

    -- Traction multiplier, used for traction bias on cars
    self.tractionMult = 1

    self.isOnGround = false
    self.lastFraction = 1
    self.lastSpringOffset = 0
    self.angularVelocity = 0

    self.downSoundCD = 0
    self.upSoundCD = 0
    self.enableSounds = true

    self:SetupWheel()
end

--- Set the size, models and steering properties to use on this wheel.
function ENT:SetupWheel( params )
    params = params or {}

    -- Wheel offset relative to the parent
    self.basePos = params.basePos or self:GetLocalPos()
    self.isOnRight = self.basePos[2] < 0

    -- How much the parent's steering angle affects this wheel
    self.steerMultiplier = params.steerMultiplier or 0

    -- Regular model
    if params.model then
        self.model = params.model
        self:SetNoDraw( false )
    end

    -- Model rotation and scale
    self.modelScale = params.modelScale or Vector( 0.3, 1, 1 )
    self:SetModelAngle( params.modelAngle or Angle( 0, 0, 0 ) )
    self:SetModelOffset( params.modelOffset or Vector( 0, 0, 0 ) )

    -- Default (not blown) radius of the wheel
    self.defaultRadius = params.radius or 15

    -- Should we apply forces at the axle position?
    self.enableAxleForces = params.enableAxleForces or false

    self:Repair()
end

function ENT:Repair()
    if self.modelOverride then
        self:SetModel( self.modelOverride )

    elseif self.model then
        self:SetModel( self.model )
    end

    self:ChangeRadius()
end

function ENT:Blow()
    self:ChangeRadius( self.defaultRadius * 0.8 )
    self:EmitSound( "glide/wheels/blowout.wav", 80, math.random( 95, 105 ), 1 )
end

function ENT:ChangeRadius( radius )
    radius = radius or self.defaultRadius

    local size = self.modelScale * radius * 2
    local bounds = self:OBBMaxs() - self:OBBMins()
    local scale = Vector( size[1] / bounds[1], size[2] / bounds[2], size[3] / bounds[3] )

    self:SetRadius( radius )
    self:SetModelScale2( scale )

    -- Used on util.TraceHull
    self.traceMins = Vector( radius * -0.2, radius * -0.2, 0 )
    self.traceMaxs = Vector( radius * 0.2, radius * 0.2, 1 )
end

do
    local Deg = math.deg
    local Approach = math.Approach

    function ENT:Update( vehicle, steerAngle, isAsleep, dt )
        -- Get the wheel rotation relative to the vehicle, while applying the steering angle
        local ang = vehicle:LocalToWorldAngles( steerAngle * self.steerMultiplier )

        -- Rotate the wheel around the axle axis
        self.spin = ( self.spin - Deg( self.angularVelocity ) * dt ) % 360
        ang:RotateAroundAxis( ang:Right(), self.spin )
        self:SetAngles( ang )

        if isAsleep then
            self:SetForwardSlip( 0 )
            self:SetSideSlip( 0 )
        else
            self:SetLastSpin( self.spin )
            self:SetLastOffset( self:GetLocalPos()[3] - self.basePos[3] )
        end

        if isAsleep or not self.isOnGround then
            self.angularVelocity = self.angularVelocity + ( self.torque / 20 ) * dt
            self.angularVelocity = Approach( self.angularVelocity, 0, dt * 5 )
        end
    end

    local TAU = math.pi * 2

    function ENT:GetRPM()
        return self.angularVelocity * 60 / TAU
    end

    function ENT:SetRPM( rpm )
        self.angularVelocity = rpm / ( 60 / TAU )
    end
end

local Abs = math.abs
local Clamp = math.Clamp

do
    local CurTime = CurTime
    local PlaySoundSet = Glide.PlaySoundSet

    function ENT:DoSuspensionSounds( change, vehicle )
        if not self.enableSounds then return end

        local t = CurTime()

        if change > 0.01 and t > self.upSoundCD then
            self.upSoundCD = t + 0.3
            PlaySoundSet( vehicle.SuspensionUpSound, self, Clamp( Abs( change ) * 15, 0, 0.5 ) )
        end

        if change < -0.01 and t > self.downSoundCD then
            change = Abs( change )

            self.downSoundCD = t + 0.3
            PlaySoundSet( change > 0.03 and vehicle.SuspensionHeavySound or vehicle.SuspensionDownSound, self, Clamp( change * 20, 0, 1 ) )
        end
    end
end

local SURFACE_GRIP = Glide.SURFACE_GRIP
local SURFACE_RESISTANCE = Glide.SURFACE_RESISTANCE
local MAP_SURFACE_OVERRIDES = Glide.MAP_SURFACE_OVERRIDES

local PI = math.pi
local TAU = math.pi * 2

local Atan2 = math.atan2
local Approach = math.Approach
local TraceHull = util.TraceHull
local TractionCurve = Glide.TractionCurve

-- Temporary variables
local pos, ang, fw, rt, up, radius
local maxLen, ray, fraction, contactPos, surfaceId
local vel, velF, velR, upDotNormal, offset, springForce, damperForce
local brake, groundAngularVelocity, forwardSlip
local tractionMult, slipAngle, maxTraction, sideTraction
local force, linearImp, angularImp

function ENT:DoPhysics( vehicle, phys, params, traceData, outLin, outAng, dt )
    -- Get the starting point of the raycast, where the suspension connects to the chassis
    pos = phys:LocalToWorld( self.basePos )

    -- Get the wheel rotation relative to the chassis, applying the steering angle if necessary
    ang = vehicle:LocalToWorldAngles( vehicle.steerAngle * self.steerMultiplier )

    -- Store some directions
    fw = ang:Forward()
    rt = ang:Right()
    up = ang:Up()

    -- Do the raycast
    radius = self:GetRadius()
    maxLen = params.suspensionLength + radius

    traceData.start = pos
    traceData.endpos = pos - up * maxLen
    traceData.mins = self.traceMins
    traceData.maxs = self.traceMaxs

    ray = TraceHull( traceData )
    fraction = Clamp( ray.Fraction, radius / maxLen, 1 )
    contactPos = pos - maxLen * fraction * up

    -- Update ground contact NW variables
    surfaceId = ray.MatType or 0
    surfaceId = MAP_SURFACE_OVERRIDES[surfaceId] or surfaceId

    --debugoverlay.Cross( pos, 10, 0.05, Color( 100, 100, 100 ), true )
    --debugoverlay.Box( contactPos, self.traceMins, self.traceMaxs, 0.05, Color( 0, 200, 0 ) )

    self.isOnGround = ray.Hit
    self:SetContactSurface( surfaceId )

    -- Update the wheel position and sounds
    self:SetLocalPos( phys:WorldToLocal( contactPos + up * radius ) )
    self:DoSuspensionSounds( fraction - self.lastFraction, vehicle )
    self.lastFraction = fraction

    -- Let the torque spin the wheel's fake mass
    if self.enableTorqueInertia then
        self.angularVelocity = self.angularVelocity + ( self.torque / params.inertia ) * dt
    end

    if not ray.Hit then
        self:SetForwardSlip( 0 )
        self:SetSideSlip( 0 )

        return
    end

    pos = self.enableAxleForces and pos or contactPos

    -- Get the velocity at the wheel position
    vel = phys:GetVelocityAtPoint( pos )

    -- Split that velocity among our local directions
    velF = fw:Dot( vel )
    velR = rt:Dot( vel )

    -- Calculate side slip angle
    slipAngle = ( Atan2( velR, Abs( velF ) ) / PI ) * 2
    self:SetSideSlip( slipAngle * Clamp( vehicle.totalSpeed * 0.005, 0, 1 ) * 2 )
    slipAngle = Abs( slipAngle )

    -- Suspension spring force & damping
    offset = maxLen - ( fraction * maxLen )
    springForce = ( offset * params.springStrength )
    damperForce = ( self.lastSpringOffset - offset ) * params.springDamper

    self.lastSpringOffset = offset

    upDotNormal = up:Dot( ray.HitNormal )
    force = ( springForce - damperForce ) * upDotNormal * ray.HitNormal

    -- Torque & brake forces
    fw = -rt:Cross( ray.HitNormal )
    brake = self.brake

    force:Add( ( 1 - brake ) * self.torque * ( 1 - slipAngle * 0.5 ) * fw )
    force:Add( ( velF > 0 and -brake or brake ) * params.brakePower * ( 1 - slipAngle ) * fw )

    -- Rolling resistance
    force:Add( ( SURFACE_RESISTANCE[surfaceId] or 0.05 ) * fw * -velF )

    -- Get how fast the wheel would be spinning if it was not slipping
    groundAngularVelocity = TAU * ( velF / ( radius * TAU ) )

    -- Smoothly match our angular velocity to the ground angular velocity
    self.angularVelocity = Approach( self.angularVelocity, groundAngularVelocity, dt * 200 )
    self.angularVelocity = Clamp( self.angularVelocity, groundAngularVelocity - 100, groundAngularVelocity + 100 )

    forwardSlip = groundAngularVelocity - self.angularVelocity

    self:SetForwardSlip( forwardSlip )

    -- Traction
    tractionMult = self.tractionMult * upDotNormal * ( SURFACE_GRIP[surfaceId] or 1 )
    tractionMult = tractionMult * ( 1 - Clamp( Abs( forwardSlip ) / 20, 0, 1 ) * 0.8 )

    maxTraction = TractionCurve( slipAngle )
    sideTraction = -rt:Dot( vel * params.tractionMultiplier )
    sideTraction = Clamp( sideTraction, -maxTraction, maxTraction )

    force:Add( sideTraction * tractionMult * rt )

    -- Apply the forces at the axle/ground contact position
    linearImp, angularImp = phys:CalculateForceOffset( force, pos )

    outLin[1] = outLin[1] + linearImp[1] / dt
    outLin[2] = outLin[2] + linearImp[2] / dt
    outLin[3] = outLin[3] + linearImp[3] / dt

    outAng[1] = outAng[1] + angularImp[1] / dt
    outAng[2] = outAng[2] + angularImp[2] / dt
    outAng[3] = outAng[3] + angularImp[3] / dt
end

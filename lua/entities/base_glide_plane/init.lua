AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

duplicator.RegisterEntityClass( "base_glide_plane", Glide.VehicleFactory, "Data" )

DEFINE_BASECLASS( "base_glide_aircraft" )

--- Override this base class function.
function ENT:OnPostInitialize()
    BaseClass.OnPostInitialize( self )

    -- Setup variables used on all planes
    self.propellers = {}
    self.powerResponse = 0.15

    self.isGrounded = false
    self.brake = 0
    self.divePitch = 0

    -- Update default wheel params
    local params = self.wheelParams

    params.brakePower = 800
    params.suspensionLength = 10
    params.springStrength = 1000
    params.springDamper = 4000

    params.maxSlip = 20
    params.slipForce = 50
    params.extremumValue = 4
    params.asymptoteValue = 2
end

--- Override this base class function.
function ENT:Repair()
    BaseClass.Repair( self )

    -- Create main propeller, if it doesn't exist
    if not IsValid( self.mainProp ) and self.PropModel ~= "" then
        self.mainProp = self:CreatePropeller( self.PropOffset, self.PropRadius, self.PropModel, self.PropFastModel )
        self.mainProp:SetSpinAngle( math.random( 0, 180 ) )
    end

    for _, prop in ipairs( self.propellers ) do
        if IsValid( prop ) then
            prop:Repair()
        end
    end
end

--- Creates and stores a new propeller entity.
---
--- `radius` is used for collision checking.
--- `slowModel` is the model shown when the propeller is spinning slowly.
--- `fastModel` is the model shown when the propeller is spinning fast.
function ENT:CreatePropeller( offset, radius, slowModel, fastModel )
    local prop = ents.Create( "glide_rotor" )

    if not prop or not IsValid( prop ) then
        self:Remove()
        error( "Failed to spawn propeller! Vehicle removed!" )
        return
    end

    self:DeleteOnRemove( prop )

    prop:SetParent( self )
    prop:SetLocalPos( offset )
    prop:Spawn()
    prop:SetupRotor( offset, radius, slowModel, fastModel )
    prop:SetSpinAxis( 3 )
    prop.maxSpinSpeed = 5000

    self.propellers[#self.propellers + 1] = prop

    return prop
end

--- Override this base class function.
function ENT:TurnOn()
    BaseClass.TurnOn( self )
    self:SetExtraPitch( 1 )
    self.divePitch = 0
end

--- Override this base class function.
function ENT:TurnOff()
    BaseClass.TurnOff( self )
    self:SetExtraPitch( 1 )
    self.divePitch = 0
end

--- Implement this base class function.
function ENT:OnDriverEnter()
    if self:GetEngineHealth() > 0 then
        self:TurnOn()
    end
end

--- Implement this base class function.
function ENT:OnDriverExit()
    self:TurnOff()
    self.brake = 0.1
end

local Abs = math.abs
local Clamp = math.Clamp
local Approach = math.Approach
local ExpDecay = Glide.ExpDecay

local IsValid = IsValid
local TriggerOutput = Either( WireLib, WireLib.TriggerOutput, nil )

local WORLD_DOWN = Vector( 0, 0, -1 )

--- Override this base class function.
function ENT:OnPostThink( dt )
    BaseClass.OnPostThink( self, dt )

    self.inputPitch = ExpDecay( self.inputPitch, self:GetInputFloat( 1, "pitch" ), 10, dt )
    self.inputRoll = ExpDecay( self.inputRoll, self:GetInputFloat( 1, "roll" ), 10, dt )
    self.inputYaw = ExpDecay( self.inputYaw, self:GetInputFloat( 1, "rudder" ), 10, dt )

    self:SetElevator( self.inputPitch )
    self:SetRudder( self.inputYaw )
    self:SetAileron( self.inputRoll )

    local power = self:GetPower()
    local throttle = self:GetInputFloat( 1, "throttle" )

    -- If the main propeller was destroyed, turn off and disable power
    if not IsValid( self.mainProp ) and self.PropModel ~= "" then
        if self:IsEngineOn() then
            self:TurnOff()
        end

        power = 0
        throttle = 0
    end

    self:SetThrottle( throttle )

    if self:IsEngineOn() then
        -- Make sure the physics stay awake,
        -- otherwise the driver's input won't do anything.
        local phys = self:GetPhysicsObject()

        if IsValid( phys ) then
            local pitchVel = Clamp( Abs( phys:GetAngleVelocity()[2] / 50 ), -1, 1 ) * 0.1
            local downDot = WORLD_DOWN:Dot( self:GetForward() )

            self.divePitch = Approach( self.divePitch, downDot > 0.5 and downDot or 0, dt * 0.5 )
            self:SetExtraPitch( Approach( self:GetExtraPitch(), 1 + pitchVel + ( self.divePitch * 0.3 ), dt * 0.1 ) )

            if phys:IsAsleep() then
                phys:Wake()
            end
        end

        if self:GetEngineHealth() > 0 then
            if self.isGrounded then
                power = Approach( power, 1 + Clamp( throttle, -0.2, 1 ), dt * self.powerResponse )
            else
                local response = throttle < 0 and self.powerResponse * 0.75 or self.powerResponse

                -- Approach towards the idle power plus the throttle input
                power = Approach( power, 1 + throttle, dt * response )

                -- Let the pilot turn the engine off
                if throttle < 0 and power < 0.5 then
                    self:TurnOff()
                end
            end
        else
            -- Turn off
            power = Approach( power, 0, dt * self.powerResponse * 0.4 )

            if power < 0.1 then
                self:TurnOff()
            end
        end

        self:SetPower( power )

        -- Process damage effects over time
        self:DamageThink( dt )
    else
        -- Approach towards 0 power
        power = ( power > 0 ) and ( power - dt * self.powerResponse * 0.6 ) or 0

        self:SetPower( power )
        self:SetExtraPitch( Approach( self:GetExtraPitch(), 1, dt * 0.1 ) )

        if throttle > 0 then
            self:TurnOn()
        end
    end

    -- Spin the propellers
    for _, prop in ipairs( self.propellers ) do
        if IsValid( prop ) then
            prop.spinMultiplier = power
        end
    end

    if TriggerOutput then
        TriggerOutput( self, "Power", power )
    end

    -- Update wheels
    local torque = 0

    if throttle < 0 and self.forwardSpeed < 100 then
        self.brake = 0.1

        if self.forwardSpeed > self.MaxReverseSpeed then
            torque = -self.ReverseTorque
        end

    elseif throttle < 0 and self.forwardSpeed > 0 then
        self.brake = 1

    else
        self.brake = 0.5
    end

    local isGrounded = false
    local totalSideSlip = 0

    for _, w in ipairs( self.wheels ) do
        w.brake = self.brake
        w.torque = torque

        if w.isOnGround then
            isGrounded = true
            totalSideSlip = totalSideSlip + w:GetSideSlip()
        end
    end

    self.isGrounded = isGrounded

    local inputSteer = self:GetInputFloat( 1, "steer" )
    local sideSlip = Clamp( totalSideSlip / self.wheelCount, -1, 1 )

    -- Limit the input and the rate of change depending on speed.
    local invSpeedOverFactor = 1 - Clamp( self.totalSpeed / self.SteerSpeedFactor, 0, 0.9 )
    inputSteer = inputSteer * invSpeedOverFactor

    -- Counter-steer when slipping and going fast
    local counterSteer = Clamp( sideSlip * ( 1 - invSpeedOverFactor ), -0.5, 0.5 )
    inputSteer = Clamp( inputSteer + counterSteer, -1, 1 )

    self.steerAngle[2] = inputSteer * -self.MaxSteerAngle
end

--- Implement this base class function.
function ENT:OnSimulatePhysics( phys, dt, outLin, outAng )
    self:SimulatePlane( phys, dt, self.PlaneParams, 1, outLin, outAng )
end

function ENT:EngineInit()
    self:UpdateGearList()

    -- Fake flywheel parameters
    self.flywheelMass = 50
    self.flywheelRadius = 0.5

    self.flywheelFriction = -7000
    self.flywheelTorque = 20000

    -- Fake engine variables
    self.flywheelVelocity = 0
    self.availableTorque = 0
    self.clutch = 1
    self.brake = 0.3

    self.switchCD = 0
    self.noThrottleInAir = false
    self.reducedThrottle = false

    -- Wheel control variables
    self.poweredCount = 0
    self.areDriveWheelsGrounded = false
    self.driveWheelsAngVelMult = 1
    self.burnout = 0

    self.avgSideSlip = 0
    self.avgPoweredRPM = 0
    self.avgForwardSlip = 0
end

function ENT:UpdateGearList()
    local minGear = 0
    local maxGear = 0
    local gearRatios = {}

    for gear, ratio in pairs( self:GetGears() ) do
        gearRatios[gear] = ratio

        if gear < minGear then minGear = gear end
        if gear > maxGear then maxGear = gear end
    end

    if self.minGear ~= minGear or self.maxGear ~= maxGear then
        self:SwitchGear( 0, 0 )
    end

    self.minGear = minGear
    self.maxGear = maxGear
    self.gearRatios = gearRatios

    if WireLib then
        WireLib.TriggerOutput( self, "MaxGear", self.maxGear )
    end
end

function ENT:OnReloaded()
    self:UpdateGearList()
end

do
    local TAU = math.pi * 2

    function ENT:GetFlywheelRPM()
        return self.flywheelVelocity * 60 / TAU
    end

    function ENT:SetFlywheelRPM( rpm )
        self.flywheelVelocity = rpm * TAU / 60
        self:SetEngineRPM( rpm )
    end

    function ENT:TransmissionToEngineRPM( gear )
        return self.avgPoweredRPM * self.gearRatios[gear] * self:GetDifferentialRatio() * 60 / TAU
    end
end

function ENT:EngineAccelerate( torque, dt )
    -- Calculate moment of inertia
    local radius = self.flywheelRadius
    local inertia = 0.5 * self.flywheelMass * radius * radius

    -- Calculate angular acceleration using Newton's second law for rotation
    local angularAcceleration = torque / inertia -- Ah, the classic F = m * a, a = F / m

    -- Calculate new angular velocity after delta time
    self.flywheelVelocity = self.flywheelVelocity + angularAcceleration * dt
end

local Clamp = math.Clamp

function ENT:SwitchGear( index, cooldown )
    if self:GetGear() == index then return end

    index = Clamp( index, self.minGear, self.maxGear )

    self.switchCD = cooldown or ( index == 1 and 0 or ( self:GetFastTransmission() and 0.15 or 0.3 ) )
    self.clutch = 1
    self:SetGear( index )
end

local Remap = math.Remap

function ENT:GetTransmissionTorque( gear )
    local torque = Remap( self:GetFlywheelRPM(), self:GetMinRPM(), self:GetMaxRPM(), self:GetMinRPMTorque(), self:GetMaxRPMTorque() )

    -- Validation
    torque = Clamp( torque, self:GetMinRPMTorque(), self:GetMaxRPMTorque() )

    -- Clutch
    torque = torque * ( 1 - self.clutch )

    -- Gearing, differential & losses
    torque = torque * self.gearRatios[gear] * self:GetDifferentialRatio() * self:GetTransmissionEfficiency()

    return gear == -1 and -torque or torque
end

local Abs = math.abs

function ENT:AutoGearSwitch( throttle )
    -- Are we trying to go backwards?
    if self.forwardSpeed < 100 and self:GetInputFloat( 1, "brake" ) > 0.2 then
        self:SwitchGear( -1, 0 )
        return
    end

    -- Neutral when the speed is slow enough
    if Abs( self.forwardSpeed ) < 100 and throttle < 0.1 then
        self:SwitchGear( 0, 0 )
        return
    end

    if self.forwardSpeed < 0 and throttle < 0.1 then return end
    if not self.areDriveWheelsGrounded then return end

    local currentGear = self:GetGear()

    -- Pick the gear that matches better the engine-to-transmittion RPM
    local minRPM, maxRPM = self:GetMinRPM(), self:GetMaxRPM()
    local gear, gearRPM = 1, 0

    -- Avoid hitting the redline
    maxRPM = maxRPM * 0.98

    -- Switch up early when on 1st gear
    if currentGear == 1 and Abs( self.avgForwardSlip ) < 2 then
        maxRPM = maxRPM * 0.8

    elseif self.reducedThrottle then
        maxRPM = maxRPM * 0.8
    end

    for i = 1, self.maxGear do
        gearRPM = self:TransmissionToEngineRPM( i )

        if gearRPM > minRPM and gearRPM < maxRPM then
            gear = i
            break
        end
    end

    -- Switch down late when on 2st gear
    if gear < currentGear and currentGear == 2 then
        maxRPM = maxRPM * 0.75
    end

    -- Only shift down if the RPM is too low
    if gear < currentGear and self:GetEngineRPM() > maxRPM * 0.45 then return end

    -- Only shift up from the 1st gear when not slipping
    if currentGear == 1 and gear == 2 and Abs( self.avgForwardSlip ) > 1 then return end

    self:SwitchGear( gear )
end

-- These locals are used both on `ENT:EngineClutch` and `ENT:EngineThink`
local inputThrottle, inputBrake, inputHandbrake

function ENT:EngineClutch( dt )
    -- Is the gear switch on cooldown?
    if self.switchCD > 0 then
        self.switchCD = self.switchCD - dt
        inputThrottle = 0
        return 0
    end

    if inputHandbrake then
        return 1
    end

    local absForwardSpeed = Abs( self.forwardSpeed )

    -- Are we airborne while going fast?
    if not self.areDriveWheelsGrounded and absForwardSpeed > 30 then
        self.clutch = 1

        if self.noThrottleInAir then
            inputThrottle = 0
        end

        return 1
    end

    self.noThrottleInAir = false

    -- Are we trying to break from a backwards velocity?
    if self.forwardSpeed < -50 and inputBrake > 0 and self:GetGear() < 0 then
        return 1
    end

    -- Engage the clutch when moving fast enough
    if absForwardSpeed > 200 then
        return 0
    end

    -- Engage the clutch while the throttle is up
    return inputThrottle > 0.1 and 0 or 1
end

local Max = math.max
local Approach = math.Approach

local gear, rpm, clutch, isRedlining, transmissionRPM, maxRPM
local throttle, gearTorque, availableTorque

function ENT:EngineThink( dt )
    gear = self:GetGear()

    -- These variables are used both on `ENT:EngineClutch` and `ENT:EngineThink`
    inputThrottle = self:GetInputFloat( 1, "accelerate" )
    inputBrake = self:GetInputFloat( 1, "brake" )
    inputHandbrake = self:GetInputBool( 1, "handbrake" )

    -- Reverse the throttle/brake inputs while in reverse gear
    if gear < 0 then
        inputThrottle, inputBrake = inputBrake, inputThrottle
    end

    -- When the engine is damaged, reduce the throttle
    if self.damageThrottleCooldown and self.damageThrottleCooldown < 0.3 then
        inputThrottle = inputThrottle * 0.3
    end

    -- When the engine is on fire, reduce the throttle
    if self:GetIsEngineOnFire() then
        inputThrottle = inputThrottle * 0.7

    elseif self.reducedThrottle then
        inputThrottle = inputThrottle * 0.65
    end

    -- Handle auto-clutch
    clutch = self:EngineClutch( dt )

    if self.burnout > 0 then
        self:SwitchGear( 1, 0 )

        if inputThrottle < 0.1 or inputBrake < 0.1 then
            self.burnout = 0
        end

    elseif not self.inputManualShift then
        self:AutoGearSwitch( inputThrottle )
    end

    -- Do a burnout when holding down the throttle and brake inputs
    if inputThrottle > 0.1 and inputBrake > 0.1 and Abs( self.forwardSpeed ) < 50 then
        self.burnout = Approach( self.burnout, 1, dt )
        self.brake = 1
        self.driveWheelsAngVelMult = 1

        clutch = 0

        -- Allow the driver to spin the car
        local phys = self:GetPhysicsObject()
        local mins, maxs = self:OBBMins(), self:OBBMaxs()
        local burnoutForce = phys:GetMass() * self.BurnoutForce * self.burnout * dt

        burnoutForce = burnoutForce * self.inputSteer * Clamp( Abs( self.avgForwardSlip ) * 0.05, 0, 1 )

        for _, w in ipairs( self.wheels ) do
            if w.isPowered then
                local pos = w:GetLocalPos()

                pos[1] = pos[1] > 0 and maxs[1] * 2 or mins[1] * 2
                pos = self:LocalToWorld( pos )

                phys:ApplyForceOffset( -self:GetRight() * burnoutForce, pos )
            end
        end

    elseif inputHandbrake then
        -- Lock the wheels while using the handbrake
        self.driveWheelsAngVelMult = Approach( self.driveWheelsAngVelMult, 0, dt * 2 )
        self.brake = 1
        self.clutch = 1
        clutch = 1

    else
        -- Apply braking when going very slow and the clutch is not engaged
        if inputThrottle < 0.1 and inputBrake < 0.1 and gear < 2 then
            inputBrake = 0.2 * self.clutch
        end

        self.brake = inputBrake
        self.driveWheelsAngVelMult = Approach( self.driveWheelsAngVelMult, 1, dt * 2 )
    end

    rpm = self:GetFlywheelRPM()
    clutch = Approach( self.clutch, clutch, dt * ( ( gear < 2 and inputThrottle > 0.1 ) and 6 or 2 ) )

    self.clutch = clutch
    isRedlining = false
    transmissionRPM = 0

    -- If we're not in neutral, convert the avg.
    -- transmission RPM back to the engine RPM.
    if gear ~= 0 then
        transmissionRPM = self:TransmissionToEngineRPM( gear )
        transmissionRPM = gear < 0 and -transmissionRPM or transmissionRPM
        rpm = ( rpm * clutch ) + ( Max( 0, transmissionRPM ) * ( 1 - clutch ) )
    end

    throttle = self:GetEngineThrottle()
    gearTorque = self:GetTransmissionTorque( gear )
    availableTorque = gearTorque * throttle

    -- Simulate engine braking
    if transmissionRPM < 0 then
        -- The vehicle is moving against the current gear, do some hard engine braking.
        availableTorque = availableTorque + gearTorque * 2
    else
        availableTorque = availableTorque - gearTorque * ( 1 - throttle ) * 0.5
    end

    -- Limit the engine RPM, check if it's redlining
    maxRPM = self:GetMaxRPM()

    if rpm < self:GetMinRPM() then
        rpm = self:GetMinRPM()

    elseif rpm > maxRPM then
        if rpm > maxRPM * 1.2 then
            availableTorque = 0
        end

        rpm = maxRPM

        -- Don't let the throttle stay high next time we're airborne
        self.noThrottleInAir = true

        if gear ~= self.maxGear or not self.areDriveWheelsGrounded then
            isRedlining = true
        end
    end

    self:SetFlywheelRPM( Max( 0, rpm ) )

    -- Update the amount of available torque to the transmission
    if self:GetTurboCharged() then
        availableTorque = availableTorque * ( 1 + ( rpm / maxRPM ) * 0.3 )
    end

    if self.burnout > 0 then
        availableTorque = availableTorque + availableTorque * self.burnout * 0.1
    end

    self.availableTorque = availableTorque

    -- Accelerate the engine flywheel and update network variables
    throttle = Approach( throttle, inputThrottle, dt * 4 )

    self:EngineAccelerate( self.flywheelFriction + self.flywheelTorque * throttle, dt )
    self:SetEngineThrottle( throttle )
    self:SetIsBraking( inputBrake > 0.1 or inputHandbrake )
    self:SetIsRedlining( isRedlining and inputThrottle > 0 )
end

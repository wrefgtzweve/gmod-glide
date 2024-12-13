AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )

duplicator.RegisterEntityClass( "base_glide_car", Glide.VehicleFactory, "Data" )

DEFINE_BASECLASS( "base_glide" )

include( "shared.lua" )
include( "sv_engine.lua" )

--- Implement this base class function.
function ENT:OnPostInitialize()
    -- Setup variables used on all cars
    self.headlights = {}
    self.inputSteer = 0

    self.inputAirRoll = 0
    self.inputAirPitch = 0
    self.inputAirYaw = 0

    -- Initialize the engine
    self:EngineInit()

    -- Set default network values
    self:SetIsRedlining( false )
    self:SetIsHonking( false )
    self:SetIsBraking( false )
    self:SetHeadlightState( 0 )
    self:SetGear( 0 )

    self:SetSteering( 0 )
    self:SetEngineRPM( 0 )
    self:SetEngineThrottle( 0 )

    self:SetTireSmokeColor( Vector( 0.6, 0.6, 0.6 ) )
    self:SetWheelRadius( 15 )

    -- Setup default NW wheel params
    local params = self.wheelParams

    -- Wheel inertia
    self:SetWheelInertia( params.inertia )

    -- Maximum length of the suspension
    self:SetSuspensionLength( params.suspensionLength )

    -- How strong is the suspension spring
    self:SetSpringStrength( params.springStrength )

    -- Damping coefficient for when the suspension is compressed/expanded
    self:SetSpringDamper( params.springDamper )

    -- Brake coefficient
    self:SetBrakePower( params.brakePower )

    -- Static friction parameters
    self:SetMaxSlip( params.maxSlip )
    self:SetSlipForce( params.slipForce )

    -- Dynamic friction/slip curve parameters
    self:SetExtremumValue( params.extremumValue )
    self:SetAsymptoteSlip( params.asymptoteSlip )
    self:SetAsymptoteValue( params.asymptoteValue )

    -- Fake engine parameters
    self:SetMinRPM( 2000 )
    self:SetMaxRPM( 20000 )

    self:SetMinRPMTorque( 1100 )
    self:SetMaxRPMTorque( 1300 )
    self:SetDifferentialRatio( 1.9 )
    self:SetTransmissionEfficiency( 0.8 )

    -- Steering parameters
    self:SetMaxSteerAngle( 35 )
    self:SetSteerConeChangeRate( 8 )
    self:SetSteerConeMaxSpeed( 1500 )
    self:SetSteerConeMaxAngle( 0.25 )

    -- Update wheel parameters based on our network variables
    self.shouldUpdateWheelParams = true
end

--- Update the `wheelParams` table using values from our network variables.
function ENT:UpdateWheelParameters()
    self.shouldUpdateWheelParams = false

    local p = self.wheelParams

    p.suspensionLength = self:GetSuspensionLength()
    p.springStrength = self:GetSpringStrength()
    p.springDamper = self:GetSpringDamper()
    p.brakePower = self:GetBrakePower()
    p.inertia = self:GetWheelInertia()

    p.maxSlip = self:GetMaxSlip()
    p.slipForce = self:GetSlipForce()

    p.extremumValue = self:GetExtremumValue()
    p.asymptoteSlip = self:GetAsymptoteSlip()
    p.asymptoteValue = self:GetAsymptoteValue()
end

--- Implement this base class function.
function ENT:OnDriverEnter()
    self:TurnOn()
end

--- Implement this base class function.
function ENT:OnDriverExit()
    local keepOn = IsValid( self.lastDriver ) and self.lastDriver:KeyDown( IN_WALK )

    if not self.hasRagdolledAllPlayers and not keepOn then
        self:TurnOff()
    end
end

--- Override this base class function.
function ENT:TurnOn()
    self.reducedThrottle = false
    self:SetGear( 0 )

    local state = self:GetEngineState()

    if state == 3 then
        self:SetEngineState( 2 )
        return
    end

    if state ~= 2 then
        self:SetEngineState( 1 )
    end

    self:SetFlywheelRPM( 0 )
end

--- Override this base class function.
function ENT:TurnOff()
    BaseClass.TurnOff( self )

    self:SetIsHonking( false )
    self:SetEngineState( 3 )
    self:SetGear( 0 )
    self.startupTimer = nil

    self.clutch = 1
    self.brake = 0.3
    self.availableTorque = 0
    self.reducedThrottle = false
end

--- Override this base class function.
function ENT:ChangeWheelRadius( radius, dontSetNW )
    BaseClass.ChangeWheelRadius( self, radius )

    -- Avoid infinite loops when called by `OnWheelRadiusChange`
    if not dontSetNW then
        self:SetWheelRadius( radius )
    end
end

function ENT:OnWheelRadiusChange( _, _, radius )
    self:ChangeWheelRadius( radius, true )
end

--- Override this base class function.
function ENT:OnTakeDamage( dmginfo )
    BaseClass.OnTakeDamage( self, dmginfo )

    if self:GetEngineHealth() <= 0 and self:GetEngineState() == 2 then
        self:TurnOff()
    end
end

--- Implement this base class function.
function ENT:OnSeatInput( seatIndex, action, pressed )
    if not pressed or seatIndex > 1 then return end

    if action == "headlights" then
        self:ChangeHeadlightState( self:GetHeadlightState() + 1 )

    elseif action == "reduce_throttle" then
        self.reducedThrottle = not self.reducedThrottle

        Glide.SendNotification( self:GetAllPlayers(), {
            text = "#glide.notify.reduced_throttle_" .. ( self.reducedThrottle and "on" or "off" ),
            icon = "materials/glide/icons/" .. ( self.reducedThrottle and "play_next" or "fast_forward" ) .. ".png",
            immediate = true
        } )

    elseif action == "accelerate" and self:GetEngineState() == 0 then
        self:TurnOn()
    end

    if not self.inputManualShift then return end

    if action == "shift_up" then
        self:SwitchGear( self:GetGear() + 1 )

    elseif action == "shift_down" then
        self:SwitchGear( self:GetGear() - 1 )

    elseif action == "shift_neutral" then
        self:SwitchGear( 0 )
    end
end

function ENT:ChangeHeadlightState( state )
    if not self.CanSwitchHeadlights then return end

    if state < 0 then state = 2 end
    if state > 2 then state = 0 end

    self:SetHeadlightState( state )

    local driver = self:GetDriver()
    local soundEnt = IsValid( driver ) and driver or self

    soundEnt:EmitSound( state == 0 and "glide/headlights_off.wav" or "glide/headlights_on.wav", 70, 100, 1.0 )
end

--- Update out model's bodygroups depending on which lights are on.
function ENT:UpdateBodygroups()
    local isBraking = self:GetIsBraking()
    local isReversing = self:GetGear() == -1
    local isHeadlightOn = self:GetHeadlightState() > 0

    for _, l in ipairs( self.LightBodygroups ) do
        if l.type == "headlight" then
            self:SetBodygroup( l.bodyGroupId, isHeadlightOn and l.subModelId or 0 )

        elseif l.type == "brake" then
            self:SetBodygroup( l.bodyGroupId, isBraking and l.subModelId or 0 )

        elseif l.type == "reverse" then
            self:SetBodygroup( l.bodyGroupId, isReversing and l.subModelId or 0 )

        end
    end
end

local TriggerOutput = Either( WireLib, WireLib.TriggerOutput, nil )

--- Override this base class function.
function ENT:SetupWirePorts()
    if not TriggerOutput then return end

    WireLib.CreateSpecialOutputs( self,
        { "MaxChassisHealth", "ChassisHealth", "EngineHealth", "MaxGear", "Gear", "EngineState", "EngineRPM", "MaxRPM" },
        { "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL" },
        { nil, nil, nil, nil, nil, "0: Off\n1: Starting\n2: Running\n3: Shutting down/Ignition cut-off" }
    )

    WireLib.CreateSpecialInputs( self,
        { "Ignition", "Steer", "Throttle", "Brake", "Handbrake", "Gear" },
        { "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL" },
        {
            "1: Turn the engine on\n0: Turn the engine off",
            "A value between -1.0 and 1.0",
            "A value between 0.0 and 1.0\nAlso acts brake input when reversing.",
            "A value between 0.0 and 1.0\nAlso acts throttle input when reversing.",
            "A value larger than 0 will set the handbrake",
            "-2: Let the vehicle do auto gear shifting\n-1: Reverse\n0: Neutral\n1+: other gears"
        }
    )

    TriggerOutput( self, "MaxGear", self.maxGear )
    TriggerOutput( self, "Gear", 0 )
    TriggerOutput( self, "EngineRPM", 0 )
end

local Abs = math.abs
local Clamp = math.Clamp
local Approach = math.Approach

--- Implement this base class function.
function ENT:OnPostThink( dt )
    self:UpdateBodygroups()

    if self.shouldUpdateWheelParams then
        self:UpdateWheelParameters()
    end

    local state = self:GetEngineState()

    if TriggerOutput then
        local maxRPM = self:GetMaxRPM()
        TriggerOutput( self, "MaxRPM", maxRPM )
        TriggerOutput( self, "Gear", self:GetGear() )
        TriggerOutput( self, "EngineState", state )
        TriggerOutput( self, "EngineRPM", Clamp( self:GetFlywheelRPM(), 0, maxRPM ) )

        if self.wireSetEngineOn ~= nil then
            if self.wireSetEngineOn then
                if state < 1 then
                    self:TurnOn()
                end

            elseif state > 0 then
                self:TurnOff()
            end

            self.wireSetEngineOn = nil
        end
    end

    -- Damage the engine when underwater
    if self:WaterLevel() > 2 then
        if state == 2 then
            self:TurnOff()
        end

        self:SetEngineHealth( 0 )
        self:SetFlywheelRPM( 0 )
        self:UpdateHealthOutputs()
    else
        self:SetIsHonking( self:GetInputBool( 1, "horn" ) )
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
                    self:SetEngineThrottle( 2 )
                else
                    self:SetEngineState( 0 )
                    Glide.PlaySoundSet( "Glide.Engine.CarStartTail", self )
                end
            end
        else
            local startupTime = health < 0.5 and math.Rand( 1, 2 ) or self.StartupTime
            self.startupTimer = CurTime() + startupTime
        end

    elseif state == 2 then
        -- Stop rising the throttle at random intervals
        if health < 0.25 then
            if self.damageThrottleCooldown and self.damageThrottleCooldown > 0 then
                self.damageThrottleCooldown = self.damageThrottleCooldown - dt
            else
                self.damageThrottleCooldown = math.Rand( 3, 0.2 )
                Glide.PlaySoundSet( "Glide.Damaged.GearGrind", self, 0.45 - health )
            end
        else
            self.damageThrottleCooldown = nil
        end
    else
        self.damageThrottleCooldown = nil
        self.startupTimer = nil
    end

    if self:IsEngineOn() then
        -- Make sure the physics stay awake,
        -- otherwise the driver's input won't do anything.
        local phys = self:GetPhysicsObject()

        if IsValid( phys ) and phys:IsAsleep() then
            local driverInput = self:GetInputFloat( 1, "accelerate" ) + self:GetInputFloat( 1, "brake" )

            if Abs( driverInput ) > 0.01 then
                phys:Wake()
            end
        end

        -- Ignition cut-off, slowdown the flywheel and then turn off
        if state == 3 then
            local rpm = self:GetFlywheelRPM()

            self.clutch = 1
            self:SetFlywheelRPM( rpm )
            self:EngineAccelerate( self.flywheelFriction, dt )
            self:SetEngineThrottle( Approach( self:GetEngineThrottle(), 0, dt ) )

            if rpm < self:GetMinRPM() then
                self:SetEngineState( 0 )
                self:SetFlywheelRPM( 0 )
            end
        else
            self:EngineThink( dt )
        end
    end

    -- Update driver inputs
    self:UpdateSteering( dt )

    local phys = self:GetPhysicsObject()

    if not self.areDriveWheelsGrounded and IsValid( phys ) then
        if self.totalSpeed > 200 then
            self:UpdateAirControls( phys, dt )
        else
            self:UpdateUnflip( phys, dt )
        end
    else
        self.inputAirRoll = 0
        self.inputAirPitch = 0
        self.inputAirYaw = 0
    end

    return true
end

local ExpDecay = Glide.ExpDecay

function ENT:UpdateSteering( dt )
    local inputSteer = self:GetInputFloat( 1, "steer" )
    local absInputSteer = Abs( inputSteer )

    local sideSlip = Clamp( self.avgSideSlip, -1, 1 )
    local steerConeFactor = Clamp( self.forwardSpeed / self:GetSteerConeMaxSpeed(), 0, 1 )

    -- Limit the input depending on speed
    local steerCone = 1 - steerConeFactor * ( 1 - self:GetSteerConeMaxAngle() )
    inputSteer = ExpDecay( self.inputSteer, inputSteer * steerCone, self:GetSteerConeChangeRate(), dt )

    self.inputSteer = inputSteer
    self:SetSteering( inputSteer )

    -- Counter-steer when slipping, going fast and not using steer input
    local counterSteer = sideSlip * steerConeFactor * ( 1 - absInputSteer )

    counterSteer = Clamp( counterSteer, -0.5, 0.5 )
    inputSteer = Clamp( inputSteer + counterSteer, -1, 1 )

    self.steerAngle[2] = -inputSteer * self:GetMaxSteerAngle()
end

--- Let the driver unflip the vehicle when it is upside down.
function ENT:UpdateUnflip( phys, dt )
    if Abs( self.inputSteer ) < 0.1 then return end

    local ang = self:GetAngles()
    if Abs( ang[3] ) < 70 then return end

    if phys:IsAsleep() then
        phys:Wake()
    end

    local angVel = phys:GetAngleVelocity()
    local force = self.inputSteer * phys:GetMass() * Clamp( 1 - Abs( angVel[1] ) / 50, 0, 1 ) * self.UnflipForce

    phys:AddAngleVelocity( Vector( force * dt, 0, 0 ) )
end

--- Let the driver spin the car while airborne.
function ENT:UpdateAirControls( phys, dt )
    local mass = phys:GetMass()
    local angVel = phys:GetAngleVelocity()

    local roll, pitch, yaw = self:GetAirInputs()

    self.inputAirRoll = Approach( self.inputAirRoll, roll, dt )
    self.inputAirPitch = Approach( self.inputAirPitch, pitch, dt )
    self.inputAirYaw = Approach( self.inputAirYaw, yaw, dt )

    local rollMult = Clamp( 1 - Abs( angVel[1] / self.AirMaxAngularVelocity[1] ), 0, 1 )
    local pitchMult = Clamp( 1 - Abs( angVel[2] / self.AirMaxAngularVelocity[2] ), 0, 1 )
    local yawMult = Clamp( 1 - Abs( angVel[3] / self.AirMaxAngularVelocity[3] ), 0, 1 )

    -- Logic to only apply the limit when rotating in the same direction as the input
    roll = roll * ( roll > 0 and ( angVel[1] > 0 and rollMult or 1 ) or ( angVel[1] < 0 and rollMult or 1 ) )
    pitch = pitch * ( pitch > 0 and ( angVel[2] > 0 and pitchMult or 1 ) or ( angVel[2] < 0 and pitchMult or 1 ) )
    yaw = yaw * ( yaw > 0 and ( angVel[3] > 0 and yawMult or 1 ) or ( angVel[3] < 0 and yawMult or 1 ) )

    phys:AddAngleVelocity( Vector(
        self.AirControlForce[1] * roll * mass * dt,
        self.AirControlForce[2] * pitch * mass * dt,
        self.AirControlForce[3] * yaw * mass * dt
    ) )
end

--- Override this base class function.
function ENT:CreateWheel( offset, params )
    local wheel = BaseClass.CreateWheel( self, offset, params )
    wheel.enableTorqueInertia = true

    -- Changing this will set the behaviour of
    -- the power distribution and burnouts.
    wheel.isPowered = params.isPowered == true

    if wheel.isPowered then
        self.poweredCount = self.poweredCount + 1
    end

    return wheel
end

local availableBrake, availableTorque, steerAngle, angVelMult
local isGrounded, rpm, totalRPM, totalSideSlip, totalForwardSlip

--- Implement this base class function.
function ENT:WheelThink( dt )
    local phys = self:GetPhysicsObject()
    local isAsleep = IsValid( phys ) and phys:IsAsleep()
    local maxRPM = self:GetTransmissionMaxRPM( self:GetGear() )

    availableBrake = self.brake
    availableTorque = self.availableTorque / self.poweredCount
    steerAngle = self.steerAngle
    angVelMult = self.driveWheelsAngVelMult

    isGrounded, totalRPM, totalSideSlip, totalForwardSlip = false, 0, 0, 0

    for _, w in ipairs( self.wheels ) do
        w:Update( self, steerAngle, isAsleep, dt )

        totalSideSlip = totalSideSlip + w:GetSideSlip()
        totalForwardSlip = totalForwardSlip + w:GetForwardSlip()

        if w.isPowered then
            rpm = w:GetRPM()
            totalRPM = totalRPM + rpm

            w.brake = availableBrake
            w.torque = availableTorque
            w.angularVelocity = w.angularVelocity * angVelMult

            if rpm > maxRPM then
                w:SetRPM( maxRPM )
            end

            if w.isOnGround then
                isGrounded = true
            end
        else
            w.brake = self.burnout * 0.5
        end
    end

    self.avgPoweredRPM = totalRPM / self.poweredCount
    self.areDriveWheelsGrounded = isGrounded
    self.avgSideSlip = totalSideSlip / self.wheelCount
    self.avgForwardSlip = totalForwardSlip / self.wheelCount
end

local Floor = math.floor

function ENT:TriggerInput( name, value )
    if name == "Ignition" then
        -- Avoid continous triggers
        self.wireSetEngineOn = value > 0

    elseif name == "Throttle" then
        self:SetInputFloat( 1, "accelerate", Clamp( value, 0, 1 ) )

    elseif name == "Steer" then
        self:SetInputFloat( 1, "steer", Clamp( value, -1, 1 ) )

    elseif name == "Brake" then
        self:SetInputFloat( 1, "brake", Clamp( value, 0, 1 ) )

    elseif name == "Handbrake" then
        self:SetInputBool( 1, "handbrake", value > 0 )

    elseif name == "Gear" then
        value = Clamp( Floor( value ), -2, self.maxGear )

        if value > -2 then
            -- Manual gears
            self.inputManualShift = true

            if value ~= self:GetGear() then
                self:SwitchGear( value, 0 )
            end
        else
            self.inputManualShift = false
        end
    end
end

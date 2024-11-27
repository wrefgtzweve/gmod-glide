AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )

include( "shared.lua" )
include( "sv_input.lua" )
include( "sv_damage.lua" )
include( "sv_weapons.lua" )
include( "sv_wheels.lua" )

duplicator.RegisterEntityClass( "base_glide", Glide.VehicleFactory, "Data" )

-- Children classes can choose which NW variables to save
ENT.DuplicatorNetworkVariables = {}

function ENT:OnEntityCopyTableFinish( data )
    Glide.FilterEntityCopyTable( data, self.DuplicatorNetworkVariables )
end

--- Handle spawning this vehicle from the spawn menu or `gm_spawn` command.
function ENT:SpawnFunction( ply, tr )
    local pos = self.SpawnPositionOffset or Vector( 0, 0, 10 )
    local ang = self.SpawnAngleOffset or Angle( 0, 90, 0 )

    return Glide.VehicleFactory( ply, {
        Pos = tr.HitPos + pos,
        Angle = Angle( 0, ply:EyeAngles().y, 0 ) + ang,
        Class = self.ClassName
    } )
end

function ENT:Initialize()
    -- Setup variables used on all vehicle types.
    self.seats = {}     -- Keep track of all seats we've created
    self.exitPos = {}   -- Per-seat exit offsets
    self.lastDriver = NULL

    self.inputBools = {}        -- Per-seat bool inputs
    self.inputFloats = {}       -- Per-seat float inputs
    self.inputFlyMode = 0           -- Current mouse flying mode
    self.inputManualShift = false   -- Current manual gear shifting setting

    -- Setup collision variables
    self.collisionShakeCooldown = 0

    -- Setup speed variables
    self.localVelocity = Vector()
    self.forwardSpeed = 0
    self.totalSpeed = 0

    -- Setup trace data used for hitscan weapons and other things
    -- that need to ignore the vehicle's chassis and seats.
    self.traceData = {
        filter = { self }
    }

    -- Setup the chassis model and physics
    self:SetModel( self.ChassisModel )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )

    -- Setup weapon systems
    self:WeaponInit()

    -- Setup wheel systems
    self:WheelInit()

    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        phys:SetMaterial( "metalvehicle" )
        phys:SetMass( self.ChassisMass )
        phys:EnableDrag( false )
        phys:SetDamping( 0, 0 )
        phys:SetDragCoefficient( 0 )
        phys:SetAngleDragCoefficient( 0 )
        phys:SetBuoyancyRatio( 0.05 )

        phys:EnableMotion( true )
        phys:Wake()

        self:StartMotionController()

        debugoverlay.Cross( self:LocalToWorld( phys:GetMassCenter() ), 20, 5, Color( 0, 200, 0 ), true )
    else
        self:Remove()
        error( "Failed to setup physics! Vehicle removed!" )
        return
    end

    -- Pretty colors
    local colors = {
        Color( 180, 70, 70 ),
        Color( 80, 65, 50 ),
        Color( 162, 188, 243 ),
        Color( 214, 106, 53 ),
        Color( 45, 45, 45 ),
        Color( 20, 20, 20 ),
        Color( 100, 100, 100 ),
        Color( 190, 190, 190 ),
        Color( 255, 255, 255 )
    }

    local data = { Color = colors[math.random( #colors )] }

    self:SetColor( data.Color )
    duplicator.StoreEntityModifier( self, "colour", data )

    -- Let child classes add their own features
    self:OnPostInitialize()

    -- Setup wiremod ports
    self:SetupWirePorts()

    -- Set health back to defaults
    self:Repair()

    -- Let child classes create things like seats, turrets, etc.
    self:CreateFeatures()
end

function ENT:OnRemove()
    -- Stop physics processing
    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        self:StopMotionController()
    end
end

function ENT:UpdateTransmitState()
    return 2 -- TRANSMIT_PVS
end

function ENT:Use( activator )
    if not IsValid( activator ) then return end
    if not activator:IsPlayer() then return end

    local freeSeat = self:GetFreeSeat()
    if freeSeat then
        activator:SetAllowWeaponsInVehicle( false )
        activator:EnterVehicle( freeSeat )
    end
end

--- Sets the "EngineState" network variable to `1` and calls `ENT:OnTurnOn`.
function ENT:TurnOn()
    self:SetEngineState( 1 )
    self:OnTurnOn()
end

--- Sets the "EngineState" network variable to `0` and calls `ENT:OnTurnOff`.
function ENT:TurnOff()
    self:SetEngineState( 0 )
    self:OnTurnOff()
end

--- Utility function to setup trace data that
--- ignores the vehicle's chassis and seats.
function ENT:GetTraceData( startPos, endPos )
    local data = self.traceData

    data.start = startPos
    data.endpos = endPos

    return data
end

--- Kicks out all passengers, then ragdoll them.
function ENT:RagdollAllPlayers( time, vel )
    time = time or 3
    vel = vel or self:GetVelocity()

    for _, ply in ipairs( self:GetAllPlayers() ) do
        Glide.RagdollPlayer( ply, vel, time )
    end

    self.hasRagdolledAllPlayers = true
end

local IsValid = IsValid

do
    local TraceHull = util.TraceHull

    local TRACE_OFFSET = Vector( 0, 0, -100 )
    local TRACE_MINS = Vector( -16, -16, 0 )
    local TRACE_MAXS = Vector( 16, 16, 50 )

    local function ValidateExitPos( pos, data, vehicle )
        local exitPos = vehicle:LocalToWorld( pos )

        data.mins = TRACE_MINS
        data.maxs = TRACE_MAXS
        data.start = exitPos
        data.endpos = exitPos + TRACE_OFFSET

        -- debugoverlay.Box( data.start, data.mins, data.maxs, 10, Color( 255, 255, 255, 10 ) )
        -- debugoverlay.Line( data.start, data.endpos, 10, Color( 0, 0, 255 ), true )

        local tr = TraceHull( data )

        if tr.Hit then
            if tr.StartSolid then
                return true -- This exit is blocked
            end

            -- debugoverlay.Box( tr.HitPos, data.mins, data.maxs, 10, Color( 0, 255, 0, 30 ) )

            return false, tr.HitPos
        end

        return false, exitPos
    end

    --- Gets the exit position from a seat index.
    function ENT:GetSeatExitPos( index )
        local seat = self.seats[index]

        if not IsValid( seat ) then
            return self:GetPos() -- Not much we can do here...
        end

        -- Try the original exit position first
        local blocked, pos = ValidateExitPos( seat.GlideExitPos, self.traceData, self )

        if blocked then
            -- Try on the other side
            pos = Vector( seat.GlideExitPos[1], -seat.GlideExitPos[2], seat.GlideExitPos[3] )
            blocked, pos = ValidateExitPos( pos, self.traceData, self )
        end

        if blocked then
            -- Okay uh... Can we leave at the back?
            local mins = self:OBBMins()
            blocked, pos = ValidateExitPos( Vector( mins[1] * 1.5, 0, 0 ), self.traceData, self )
        end

        if blocked then
            -- Uhhh... Can we leave at the front?
            local maxs = self:OBBMaxs()
            blocked, pos = ValidateExitPos( Vector( maxs[1] * 2, 0, 0 ), self.traceData, self )
        end

        if blocked then
            -- We're cooked...
            pos = seat:GetPos()
        end

        return pos + Vector( 0, 0, 5 )
    end
end

--- Returns all players that are inside of this vehicle.
function ENT:GetAllPlayers()
    local players = {}
    local driver

    for _, seat in ipairs( self.seats ) do
        driver = seat:GetDriver()

        if IsValid( driver ) then
            players[#players + 1] = driver
        end
    end

    return players
end

--- Gets the driver from a seat index.
function ENT:GetSeatDriver( index )
    local seat = self.seats[index]

    if IsValid( seat ) then
        return seat:GetDriver()
    end
end

--- Gets the first free seat entity, or returns `nil` if none are available.
function ENT:GetFreeSeat()
    local driver

    for i, seat in ipairs( self.seats ) do
        driver = seat:GetDriver()

        if not IsValid( driver ) then
            return seat, i
        end
    end
end

local COLOR_HIDDEN = Color( 0, 0, 0, 0 )

--- Create a new seat.
---
--- `offset` is the seat's position relative to the chassis.
--- `angle` is the seat's angles relative to the chassis.
--- Set `isHidden` to `true` to disable drawing this seat.
function ENT:CreateSeat( offset, angle, exitPos, isHidden )
    local index = #self.seats + 1

    if index > Glide.MAX_SEATS then
        error( "Seat limit reached!" )

        return
    end

    local seat = ents.Create( "prop_vehicle_prisoner_pod" )

    if not IsValid( seat ) then
        self:Remove()
        error( "Failed to spawn a seat! Vehicle removed!" )

        return
    end

    seat:SetModel( "models/nova/airboat_seat.mdl" )
    seat:SetPos( self:LocalToWorld( offset or Vector() ) )
    seat:SetAngles( self:LocalToWorldAngles( angle or Angle( 0, 270, 10 ) ) )
    seat:SetMoveType( MOVETYPE_NONE )
    seat:SetOwner( self )
    seat:Spawn()

    seat.DoNotDuplicate = true
    seat:SetKeyValue( "limitview", 0 )
    seat:SetNotSolid( true )
    seat:SetParent( self )
    seat:DrawShadow( false )
    seat:PhysicsDestroy()

    if isHidden then
        -- This wont let the entity show up on self:GetChildren clientside
        --seat:SetNoDraw( true )
        seat:SetRenderMode( RENDERMODE_TRANSCOLOR )
        seat:SetColor( COLOR_HIDDEN )
    end

    -- Let Glide know it should handle this seat differently
    seat.GlideSeatIndex = index
    seat.GlideExitPos = exitPos
    seat:SetNWInt( "GlideSeatIndex", index )
    self:DeleteOnRemove( seat )

    self.seats[index] = seat

    -- Setup player inputs for this seat
    self.inputBools[index] = {}
    self.inputFloats[index] = {}

    -- Don't let weapon fire or other traces hit this seat
    local filter = self.traceData.filter
    filter[#filter + 1] = seat

    return seat
end

local CurTime = CurTime
local TickInterval = engine.TickInterval

function ENT:Think()
    -- Run again next tick
    self:NextThink( CurTime() )

    -- Update speed variables
    self.localVelocity = self:WorldToLocal( self:GetPos() + self:GetVelocity() )
    self.forwardSpeed = self.localVelocity[1]
    self.totalSpeed = self.localVelocity:Length()

    -- If we have at least one seat...
    if #self.seats > 0 then
        -- Use it to check if we have a driver
        local driver = self.seats[1]:GetDriver()

        if driver ~= self:GetDriver() then
            self:SetDriver( driver )
            self:ClearLockOnTarget()

            if IsValid( driver ) then
                self:OnDriverEnter()
                self.lastDriver = driver
            else
                self:OnDriverExit()
            end

            self.hasRagdolledAllPlayers = nil
        end
    end

    -- Update weapons
    if self.weaponCount > 0 then
        self:WeaponThink()
    end

    -- If necessary, kick passengers when underwater
    if self.FallOnCollision and self:WaterLevel() > 2 and #self:GetAllPlayers() > 0 then
        self:RagdollAllPlayers( 2 )
    end

    local dt = TickInterval()

    -- Deal engine fire damage over time
    if self:GetIsEngineOnFire() then
        if self:WaterLevel() > 2 then
            self:SetIsEngineOnFire( false )
        else
            local dmg = DamageInfo()
            dmg:SetDamage( 10 * dt )
            dmg:SetAttacker( self )
            dmg:SetInflictor( self )
            dmg:SetDamageType( 0 )
            dmg:SetDamageForce( Vector() )
            dmg:SetDamagePosition( self:GetPos() )
            self:TakeDamageInfo( dmg )
        end
    end

    -- Update wheels
    if self.wheelCount > 0 then
        self:WheelThink( dt )
    end

    -- Let children classes do their own stuff
    self:OnPostThink( dt )

    return true
end

local TriggerOutput = Either( WireLib, WireLib.TriggerOutput, nil )

function ENT:SetupWirePorts()
    if not TriggerOutput then return end

    -- Create Wiremod outputs for health values
    WireLib.CreateSpecialOutputs( self,
        { "MaxChassisHealth", "ChassisHealth", "EngineHealth" },
        { "NORMAL", "NORMAL", "NORMAL" }
    )
end

function ENT:UpdateHealthOutputs()
    if not TriggerOutput then return end

    TriggerOutput( self, "MaxChassisHealth", self.MaxChassisHealth )
    TriggerOutput( self, "ChassisHealth", self:GetChassisHealth() )
    TriggerOutput( self, "EngineHealth", self:GetEngineHealth() )
end

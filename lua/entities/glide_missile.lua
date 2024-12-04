AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Missile"

ENT.Spawnable = false
ENT.AdminOnly = false

ENT.PhysgunDisabled = true
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
    self:NetworkVar( "Float", "Effectiveness" )
    self:NetworkVar( "Bool", "HasTarget" )
end

local CurTime = CurTime

if CLIENT then
    function ENT:Initialize()
        self.smokeSpinSpeed = math.random( 60, 110 )

        -- Create a RangedFeature to handle missile sounds
        self.missileSounds = Glide.CreateRangedFeature( self, 4000 )
        self.missileSounds:SetActivateCallback( "ActivateSound" )
        self.missileSounds:SetDeactivateCallback( "DeactivateSound" )

        -- Assume we have one for now, to avoid issues with the lock-on warnings clientside
        self:SetHasTarget( true )
    end

    function ENT:OnRemove()
        if self.missileSounds then
            self.missileSounds:Destroy()
            self.missileSounds = nil
        end
    end

    function ENT:ActivateSound()
        if not self.missileLoop then
            self.missileLoop = CreateSound( self, "glide/weapons/missile_loop.wav" )
            self.missileLoop:SetSoundLevel( 80 )
            self.missileLoop:Play()
        end
    end

    function ENT:DeactivateSound()
        if self.missileLoop then
            self.missileLoop:Stop()
            self.missileLoop = nil
        end
    end

    local Effect = util.Effect
    local EffectData = EffectData

    function ENT:Think()
        if self.missileSounds then
            self.missileSounds:Think()
        end

        if self:WaterLevel() > 0 then
            self.smokeSpinSpeed = nil

        elseif self.smokeSpinSpeed then
            local eff = EffectData()
            eff:SetOrigin( self:GetPos() )
            eff:SetNormal( -self:GetForward() )
            eff:SetColor( self.smokeSpinSpeed )
            eff:SetScale( self:GetEffectiveness() )
            Effect( "glide_missile", eff )
        end

        self:SetNextClientThink( CurTime() + 0.02 )

        return true
    end
end

if not SERVER then return end

function ENT:Initialize()
    self:SetModel( "models/glide/weapons/homing_rocket.mdl" )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:DrawShadow( false )

    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        phys:Wake()
        phys:SetAngleDragCoefficient( 1 )
        phys:SetDragCoefficient( 0 )
        phys:EnableGravity( false )
        phys:SetMass( 20 )

        phys:SetVelocityInstantaneous( self:GetForward() * 200 )
    end

    self.radius = 350
    self.damage = 100
    self.lifeTime = CurTime() + 6
    self.maxSpeed = 3000
    self.acceleration = 12000
    self.turnEfficiency = 7

    self.target = NULL
    self.missThreshold = 0.9
    self.applyThrust = true
    self.flareExplodeRadius = 200 * 200

    self:SetEffectiveness( 0 )
end

local IsValid = IsValid

--- Prepare the missile.
function ENT:SetupMissile( attacker, parent )
    -- Set which player created this missile
    self.attacker = attacker

    -- Don't collide with our parent entity
    self:SetOwner( parent )
end

function ENT:SetTarget( target )
    if not target:IsPlayer() then
        -- Just use the target entity
        self.target = target

        -- Let Glide vehicles know about this missile
        if target.IsGlideVehicle then
            Glide.SendMissileDanger( target:GetAllPlayers(), self )

        -- Let players in seats know about this missile
        elseif target:IsVehicle() then
            local driver = target:GetDriver()

            if IsValid( driver ) then
                Glide.SendMissileDanger( driver, self )
            end
        end

        return
    end

    -- Try to target this player's seat
    local seat = target:GetVehicle()

    if IsValid( seat ) then
        -- Try to target this seat's parent
        local parent = seat:GetParent()

        if IsValid( parent ) then
            -- Use the parent as the target
            self.target = parent

            -- Let Glide vehicles know about this missile
            if parent.IsGlideVehicle then
                Glide.SendMissileDanger( parent:GetAllPlayers(), self )
            else
                Glide.SendMissileDanger( target, self )
            end
        else
            -- Use the seat as the target
            self.target = seat
            Glide.SendMissileDanger( target, self )
        end
    else
        -- Use the target player
        self.target = target
        Glide.SendMissileDanger( target, self )
    end
end

function ENT:Explode()
    if self.hasExploded then return end

    -- Don't let stuff like collision events call this again
    self.hasExploded = true

    Glide.CreateExplosion( self, self.attacker, self:GetPos(), self.radius, self.damage, -self:GetForward(), Glide.EXPLOSION_TYPE.MISSILE )

    self.attacker = nil
    self:Remove()
end

local FrameTime = FrameTime
local Approach = math.Approach

local GetClosestFlare = Glide.GetClosestFlare
local ExpDecayAngle = Glide.ExpDecayAngle
local ZERO_ANGVEL = Vector()

function ENT:Think()
    local t = CurTime()

    if t > self.lifeTime then
        self:Explode()
        return
    end

    self:NextThink( t )

    local dt = FrameTime()
    local phys = self:GetPhysicsObject()

    if not self.applyThrust or not IsValid( phys ) then
        return true
    end

    self:SetEffectiveness( Approach( self:GetEffectiveness(), 1, dt * 4 ) )

    if self:WaterLevel() > 0 then
        self.applyThrust = false
        phys:EnableGravity( true )
    end

    local fw = self:GetForward()
    local vel = phys:GetVelocity()

    -- Accelerate
    local speed = vel:Length()

    if speed < self.maxSpeed then
        speed = speed + self.acceleration * dt
    end

    vel = fw * speed

    -- Point towards the target
    local target = self.target
    local myPos = self:GetPos()

    -- Or towards a nearby flare
    local flare, flareDistSqr = GetClosestFlare( myPos, 1500 )

    if IsValid( flare ) then
        target = flare

        if flareDistSqr < self.flareExplodeRadius then
            self:Explode()
            return
        end
    end

    if IsValid( target ) then
        self:SetHasTarget( target.IsCountermeasure ~= true )

        local targetPos = target:LocalToWorld( target:OBBCenter() ) + target:GetVelocity() * dt

        local dir = targetPos - myPos
        dir:Normalize()

        local decay = self:GetEffectiveness() * self.turnEfficiency
        local myAng = self:GetAngles()
        local targetAng = dir:Angle()

        myAng[1] = ExpDecayAngle( myAng[1], targetAng[1], decay, dt )
        myAng[2] = ExpDecayAngle( myAng[2], targetAng[2], decay, dt )
        myAng[3] = ExpDecayAngle( myAng[3], targetAng[3], decay, dt )

        phys:SetAngles( myAng )

        if math.abs( dir:Dot( fw ) ) < self.missThreshold then
            self.target = nil -- We've missed
        end
    else
        self:SetHasTarget( false )
    end

    phys:SetVelocityInstantaneous( vel )
    phys:SetAngleVelocityInstantaneous( ZERO_ANGVEL )

    return true
end

function ENT:PhysicsCollide()
    self:Explode()
end

function ENT:OnTakeDamage()
    if not self.hasExploded then self:Explode() end
end

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Projectile"

ENT.Spawnable = false
ENT.AdminOnly = false

ENT.PhysgunDisabled = true
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

local CurTime = CurTime

if CLIENT then
    function ENT:Initialize()
        local m = Matrix()
        m:SetAngles( Angle( 90, 0, 0 ) )
        m:SetScale( Vector( 0.2, 0.2, 0.8 ) )
        self:EnableMatrix( "RenderMultiply", m )
    end

    local Effect = util.Effect
    local EffectData = EffectData

    function ENT:Think()
        if self:WaterLevel() > 0 then
            return false
        end

        local eff = EffectData()
        eff:SetOrigin( self:GetPos() )
        eff:SetNormal( -self:GetForward() )
        eff:SetScale( 1 )
        Effect( "glide_projectile", eff )

        self:SetNextClientThink( CurTime() + 0.02 )

        return true
    end
end

if not SERVER then return end

function ENT:Initialize()
    self:SetModel( "models/props_phx/misc/flakshell_big.mdl" )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:DrawShadow( false )

    self.damage = 250
    self.radius = 350
    self.lifeTime = CurTime() + 5

    -- We're gonna do our own physics for this
    -- to workaround source's velocity limit.
    self.velocity = self:GetForward() * 8000

    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        phys:SetMass( 30 )
        phys:SetAngleDragCoefficient( 0 )
        phys:SetDragCoefficient( 0 )
        phys:EnableDrag( false )
        phys:EnableGravity( false )
        phys:Sleep()
    end
end

function ENT:SetupProjectile( attacker, parent )
    -- Set which player created this projectile
    self.attacker = attacker

    -- Don't collide with our parent entity
    self:SetOwner( parent )
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
local TraceLine = util.TraceLine

local traceData = {
    filter = { NULL },
    mask = MASK_PLAYERSOLID,
}

local GRAVITY = Vector( 0, 0, -900 )

function ENT:Think()
    local t = CurTime()

    if t > self.lifeTime then
        self:Explode()
        return
    end

    local dt = FrameTime()
    local vel = self.velocity

    vel = vel + ( dt * GRAVITY )

    self.velocity = vel

    local lastPos = self:GetPos()
    local nextPos = lastPos + vel * dt

    -- Check if we've hit anything along the way
    traceData.start = lastPos
    traceData.endpos = nextPos
    traceData.filter[1] = self
    traceData.filter[2] = self:GetOwner()

    local tr = TraceLine( traceData )

    if tr.Hit then
        self:Explode()
        return
    end

    self:SetPos( nextPos )
    self:NextThink( CurTime() )

    return true
end

function ENT:PhysicsCollide()
    self:Explode()
end

function ENT:OnTakeDamage()
    if not self.hasExploded then self:Explode() end
end

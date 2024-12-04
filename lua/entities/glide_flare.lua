AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Flare Countermeasure"

ENT.Spawnable = false
ENT.AdminOnly = false

ENT.PhysgunDisabled = true
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

-- Hint for Glide missiles
ENT.IsCountermeasure = true

local CurTime = CurTime

if CLIENT then
    function ENT:Initialize()
        if not self.flareLoop then
            self.flareLoop = CreateSound( self, ")weapons/flaregun/burn.wav" )
            self.flareLoop:SetSoundLevel( 75 )
            self.flareLoop:PlayEx( 0.5, 110 )
        end
    end

    function ENT:OnRemove()
        if self.flareLoop then
            self.flareLoop:Stop()
            self.flareLoop = nil
        end
    end

    local Effect = util.Effect
    local EffectData = EffectData

    function ENT:Think()
        self:SetNextClientThink( CurTime() + 0.03 )

        local eff = EffectData()
        eff:SetOrigin( self:GetPos() )
        eff:SetScale( 1 )
        Effect( "glide_flare", eff )

        return true
    end
end

if not SERVER then return end

function ENT:Initialize()
    self:SetModel( "models/items/flare.mdl" )
    self:PhysicsInitSphere( 4 )
    self:DrawShadow( false )

    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        phys:Wake()
        phys:SetAngleDragCoefficient( 1 )
        phys:SetDragCoefficient( 0 )
        phys:EnableGravity( true )
        phys:SetMass( 5 )
        phys:SetVelocityInstantaneous( self:GetForward() * 2000 )
    end

    self.lifeTime = CurTime() + 10
    self:SetMissileSearchRadius( 1500 )
    self:SetMissileExplodeRadius( 200 )
end

function ENT:SetMissileSearchRadius( radius )
    self.searchRadius = radius * radius
end

function ENT:SetMissileExplodeRadius( radius )
    self.explodeRadius = radius * radius
end

local FindByClass = ents.FindByClass

function ENT:Think()
    local t = CurTime()

    if t > self.lifeTime then
        self:Remove()
        return
    end

    self:NextThink( t )

    if self:WaterLevel() > 0 then
        self:Remove()
        return false
    end

    -- Detour missiles
    local missiles = FindByClass( "glide_missile" )
    local pos = self:GetPos()
    local dist, searchDist, explodeDist = 0, self.searchRadius, self.explodeRadius

    for _, m in ipairs( missiles ) do
        dist = pos:DistToSqr( m:GetPos() )

        if dist < explodeDist then
            m:Explode()
            self:Remove()
            break

        elseif dist < searchDist then
            m.target = self
            m.turnEfficiency = 5
        end
    end

    -- Custom drag
    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        local vel = phys:GetVelocity()
        vel[1] = vel[1] * 0.98
        vel[2] = vel[2] * 0.98
        vel[3] = vel[3] * 0.98
        phys:SetVelocityInstantaneous( vel )
    end

    return true
end

function ENT:OnTakeDamage()
    self:Remove()
end

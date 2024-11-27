include( "shared.lua" )

--- Implement the base class `ShouldActivateSounds` function.
function ENT:ShouldActivateSounds()
    return self:GetPower() > 0.1
end

--- Implement the base class `OnActivateMisc` function.
function ENT:OnActivateMisc()
    self.particleCD = 0
end

local Effect = util.Effect
local EffectData = EffectData

local Clamp = math.Clamp

function ENT:OnUpdateParticles()
    local health = self:GetEngineHealth()
    if health > 0.5 then return end

    local velocity = self:GetVelocity()
    local normal = -self:GetForward()
    local power = self:GetPower()

    health = Clamp( health * 255, 0, 255 )

    for _, pos in ipairs( self.ExhaustPositions ) do
        local eff = EffectData()
        eff:SetOrigin( self:LocalToWorld( pos ) )
        eff:SetNormal( normal )
        eff:SetColor( health )
        eff:SetMagnitude( power * 1000 )
        eff:SetStart( velocity )
        eff:SetScale( 1 )
        Effect( "glide_damaged_exhaust", eff, true, true )
    end
end

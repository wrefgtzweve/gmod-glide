include( "shared.lua" )

--- Implement this base class function.
function ENT:ShouldActivateSounds()
    return self:GetPower() > 0.1
end

local Clamp = math.Clamp
local Effect = util.Effect
local EffectData = EffectData

--- Implement this base class function.
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

local DynamicLight = DynamicLight

local function DrawLight( id, pos, color, size )
    local dl = DynamicLight( id )
    if dl then
        dl.pos = pos
        dl.r = color.r
        dl.g = color.g
        dl.b = color.b
        dl.brightness = 5
        dl.decay = 1000
        dl.size = size or 70
        dl.dietime = CurTime() + 0.05
    end
end

local RealTime = RealTime
local DrawLightSprite = Glide.DrawLightSprite

--- Implement this base class function.
function ENT:OnUpdateMisc()
    if self:GetDriver() == NULL and self:GetPower() < 0.1 then return end

    -- Update strobe lights
    local t = RealTime()
    local on, pos, color

    t = t % 1

    for i, v in ipairs( self.StrobeLights ) do
        on = t > v.blinkTime and t < v.blinkTime + 0.05

        if on then
            pos = self:LocalToWorld( v.offset )
            color = self.StrobeLightColors[i]

            DrawLight( self:EntIndex() + i, pos, color, 80 )
            DrawLightSprite( pos, nil, 30, color )
        end
    end
end

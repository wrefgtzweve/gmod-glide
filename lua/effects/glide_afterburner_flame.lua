local CurTime = CurTime
local RandomFloat = math.Rand

function EFFECT:Init( data )
    self.parent = data:GetEntity()
    self.lifetime = CurTime() + 0.1

    if not IsValid( self.parent ) then return end

    self.offset = self.parent:WorldToLocal( data:GetOrigin() )
    self.angles = self.parent:WorldToLocalAngles( data:GetAngles() )

    self:SetRenderMode( RENDERMODE_WORLDGLOW )
    self:SetModel( "models/glide/effects/afterburner_flame.mdl" )
    self:SetModelScale( data:GetScale() * RandomFloat( 0.85, 1.1 ) )
end

function EFFECT:Think()
    return IsValid( self.parent ) and CurTime() < self.lifetime
end

function EFFECT:Render()
    local origin = self.parent:LocalToWorld( self.offset )
    local angles = self.parent:LocalToWorldAngles( self.angles )

    self:SetPos( origin )
    self:SetAngles( angles )
    self:DrawModel()
end

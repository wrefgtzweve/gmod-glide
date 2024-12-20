include( "shared.lua" )

function ENT:Initialize()
    self:SetPredictable( true )
    self.predictedBodyAngle = Angle()
end

function ENT:OnRemove()
    if self.shootSound then
        self.shootSound:Stop()
        self.shootSound = nil
    end
end

function ENT:UpdateSounds()
    if self:GetIsFiring() then
        if not self.shootSound then
            self.shootSound = CreateSound( self, "glide/weapons/turret_mg_loop.wav" )
            self.shootSound:SetSoundLevel( 85 )
            self.shootSound:PlayEx( 1.0, 100 )
        end

    elseif self.shootSound then
        self.shootSound:Stop()
        self.shootSound = nil

        self:EmitSound( "glide/weapons/turret_mg_end.wav", 85, 100, 1.0 )
    end
end

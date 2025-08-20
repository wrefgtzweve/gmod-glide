VSWEP.Base = "base"
VSWEP.Name = "#glide.weapons.explosive_cannon"

if SERVER then
    function VSWEP:OnFire()
        local vehicle = self.Vehicle

        vehicle:FireBullet( {
            pos = vehicle:LocalToWorld( self.ProjectileOffsets[self.projectileOffsetIndex] ),
            ang = vehicle:GetAngles(),
            attacker = vehicle:GetSeatDriver( 1 ),
            isExplosive = true,
            spread = self.Spread,
            damage = self.Damage,
            scale = self.TracerScale
        } )
    end
end

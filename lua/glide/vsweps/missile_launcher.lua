VSWEP.Base = "base"
VSWEP.Name = "#glide.weapons.missiles"
VSWEP.Icon = "glide/icons/rocket.png"

if SERVER then
    VSWEP.FireDelay = 1
    VSWEP.EnableLockOn = false
end

if CLIENT then
    VSWEP.CrosshairType = "square"
end

if SERVER then
    function VSWEP:OnFire()
        local vehicle = self.Vehicle
        local target

        -- Only make the missile follow the target when
        -- using the homing missiles and with a "hard" lock-on
        if self.EnableLockOn and vehicle:GetLockOnState() == 2 then
            target = vehicle:GetLockOnTarget()
        end

        local pos = vehicle:LocalToWorld( self.ProjectileOffsets[self.projectileOffsetIndex] )
        vehicle:FireMissile( pos, vehicle:GetAngles(), vehicle:GetSeatDriver( 1 ), target )
    end
end

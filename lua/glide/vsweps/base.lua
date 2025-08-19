VSWEP.Name = "#glide.weapons.mgs"
VSWEP.Icon = "glide/icons/bullets.png"

if SERVER then
    -- How often can this weapon fire?
    VSWEP.FireDelay = 0.5

    -- How long does it take to reload?
    VSWEP.ReloadDelay = 1

    -- Should this weapon enable the lock-on system?
    VSWEP.EnableLockOn = false

    -- Multiply the time it takes to progress through lock-on stages
    VSWEP.LockOnTimeMultiplier = 1.0

    -- Bullet spread (nil for default)
    VSWEP.Spread = nil

    -- Bullet damage (nil for default)
    VSWEP.Damage = nil

    -- Bullet tracer scale (nil for default)
    VSWEP.TracerScale = nil

    -- Set to 0 for unlimited ammo
    VSWEP.MaxAmmo = 0

    -- The "ammo type" of this weapon. It can be any string.
    -- When switching weapons, this is used to copy the reload and fire
    -- cooldowns from the previous weapon, as long as it has the same ammo type.
    VSWEP.AmmoType = ""

    -- Should the ammo capacity be shared with
    -- other weapons that have the same ammo type?
    VSWEP.AmmoTypeShareCapacity = false

    -- Positions (relative to the vehicle) to fire projectiles.
    VSWEP.ProjectileOffsets = {
        Vector( 0, 0, 0 )
    }

    -- A one-shot sound to play when the weapon fires.
    VSWEP.SingleShotSound = ""

    -- A one-shot sound to play when the weapon finishes reloading.
    VSWEP.SingleReloadSound = ""
end

if CLIENT then
    VSWEP.LocalCrosshairOrigin = Vector()
    VSWEP.LocalCrosshairAngle = Angle()

    -- Size relative to screen resolution
    VSWEP.CrosshairSize = 0.05

    -- Path (relative to "materials/") to a image/material file
    VSWEP.CrosshairImage = "glide/aim_dot.png"
end

if SERVER then
    function VSWEP:Initialize()
        self.ammo = self.MaxAmmo
        self.nextFire = 0
        self.nextReload = 0
        self.isFiring = false
        self.projectileOffsetIndex = 0

        -- Compatibility with vehicles that use `ENT.WeaponSlots`
        self.ammoType = self.AmmoType
    end

    function VSWEP:OnRemove()
    end

    function VSWEP:OnDeploy()
        self.Vehicle:ClearLockOnTarget()
        self.Vehicle:MarkWeaponDataAsDirty()
    end

    function VSWEP:OnHolster()
        local myIndex, myAmmoType = self.SlotIndex, self.AmmoType
        if myAmmoType == "" then return end

        for i, otherWeapon in ipairs( self.Vehicle.weapons ) do
            if i ~= myIndex and myAmmoType == otherWeapon.AmmoType then

                -- Share the reload and fire cooldowns to all
                -- other weapons with the same ammo type.
                otherWeapon.nextFire = self.nextFire
                otherWeapon.nextReload = self.nextReload

                -- Share the ammo count to all other weapons with the same
                -- ammo type AND that have `AmmoTypeShareCapacity` set to `true`.
                if otherWeapon.AmmoTypeShareCapacity then
                    otherWeapon.ammo = self.ammo
                    otherWeapon.projectileOffsetIndex = self.projectileOffsetIndex
                end
            end
        end
    end

    function VSWEP:OnFire()
        local vehicle = self.Vehicle

        vehicle:FireBullet( {
            pos = vehicle:LocalToWorld( self.ProjectileOffsets[self.projectileOffsetIndex] ),
            ang = vehicle:GetAngles(),
            attacker = vehicle:GetSeatDriver( 1 ),
            spread = self.Spread,
            damage = self.Damage,
            scale = self.TracerScale
        } )
    end

    function VSWEP:OnStartFiring()
        self.Vehicle:OnWeaponStart( self, self.SlotIndex )
    end

    function VSWEP:OnStopFiring()
        self.Vehicle:OnWeaponStop( self, self.SlotIndex )
    end

    function VSWEP:OnWriteData()
        net.WriteUInt( self.MaxAmmo, 16 )
        net.WriteUInt( self.ammo, 16 )
    end

    function VSWEP:Reload()
        self.ammo = self.MaxAmmo

        if self.SingleReloadSound ~= "" then
            self.Vehicle:EmitSound( self.SingleReloadSound )
        end
    end

    local CurTime = CurTime

    function VSWEP:Fire()
        self.ammo = self.ammo - 1
        self.nextFire = CurTime() + self.FireDelay

        -- Check if the vehicle is going to handle the weapon fire logic first.
        local vehicle = self.Vehicle
        local allowDefaultBehaviour = vehicle:OnWeaponFire( self, self.SlotIndex )

        -- If not, let this weapon class handle it.
        if allowDefaultBehaviour then
            self.projectileOffsetIndex = self.projectileOffsetIndex + 1

            if self.projectileOffsetIndex > #self.ProjectileOffsets then
                self.projectileOffsetIndex = 1
            end

            self:OnFire()

            if self.SingleShotSound ~= "" then
                vehicle:EmitSound( self.SingleShotSound )
            end
        end

        if self.ammo < 1 and self.MaxAmmo > 0 then
            self.nextReload = CurTime() + self.ReloadDelay
        end

        -- Let the driver's client know about the ammo change
        vehicle:MarkWeaponDataAsDirty()
    end

    function VSWEP:Think()
        local time = CurTime()
        local vehicle = self.Vehicle

        -- Reload if it is the time to do so
        if self.ammo < 1 and time > self.nextReload and self.MaxAmmo > 0 then
            self:Reload()
            vehicle:MarkWeaponDataAsDirty()
        end

        local shouldFire = vehicle:GetInputBool( 1, "attack" )

        if shouldFire and time > self.nextFire and ( self.ammo > 0 or self.MaxAmmo == 0 ) then
            self:Fire()
        end

        shouldFire = shouldFire and ( self.MaxAmmo == 0 or self.ammo > 0 )

        if self.isFiring ~= shouldFire then
            self.isFiring = shouldFire

            if shouldFire then
                self:OnStartFiring()
            else
                self:OnStopFiring()
            end
        end
    end
end

if CLIENT then
    --[[
        NOTE! NOTE! NOTE!

        Client-side, instances (or copies) of VWEPS are
        only created/updated on the local client when:

        - The local player is the driver of the vehicle that has this weapon
        - The weapon is the current active weapon
    ]]

    --- Called when this weapon is created locally,
    --- when the conditions mentioned above are met.
    function VSWEP:Initialize()
        self.maxAmmo = 0
        self.ammo = 0
    end

    --- Called when we're receiving a data sync event for this weapon.
    ---
    --- You must use `net.Read*` functions in the same order
    --- as you wrote them on `VSWEP:OnWriteData`.
    function VSWEP:OnReadData()
        self.maxAmmo = net.ReadUInt( 16 )
        self.ammo = net.ReadUInt( 16 )
    end

    local Floor = math.floor
    local SetColor = surface.SetDrawColor
    local DrawRect = surface.DrawRect
    local DrawSimpleText = draw.SimpleText
    local DrawIcon = Glide.DrawIcon

    local colors = {
        text = Color( 255, 255, 255 ),
        lowAmmo = Color( 255, 115, 0 ),
        noAmmo = Color( 255, 50, 50 )
    }

    local ammoText = "%d / %d"

    --- Draw the weapon HUD.
    function VSWEP:DrawHUD( _screenW, screenH )
        self:DrawCrosshair()

        local h = Floor( screenH * 0.04 )
        local y = screenH - Floor( screenH * 0.03 ) - h
        local margin = Floor( screenH * 0.005 )
        local iconSize = h * 0.8

        local ammo = self.ammo or 0
        local maxAmmo = self.maxAmmo or 0
        local text = maxAmmo > 0 and ammoText:format( ammo, maxAmmo ) or "ꝏ"

        surface.SetFont( "GlideHUD" )
        local w = surface.GetTextSize( text )

        w = w + iconSize + margin * 4

        SetColor( 30, 30, 30, 230 )
        DrawRect( 0, y, w, h )

        local ammoColor = colors.text

        if maxAmmo > 0 then
            ammoColor = ammo > 0 and ( ammo > maxAmmo * 0.3 and colors.text or colors.lowAmmo ) or colors.noAmmo
        end

        DrawSimpleText( text, "GlideHUD", iconSize + margin * 2, y + h * 0.5, ammoColor, 0, 1 )
        DrawIcon( margin + iconSize * 0.5, y + h * 0.5, self.Icon, iconSize, colors.text, 0 )
    end

    local LOCKON_STATE_COLORS = {
        [0] = Color( 255, 255, 255 ),
        [1] = Color( 100, 255, 100 ),
        [2] = Color( 255, 0, 0 ),
    }

    local DrawWeaponCrosshair = Glide.DrawWeaponCrosshair
    local TraceLine = util.TraceLine
    local IsValid = IsValid

    local traceData = {
        filter = { NULL, "glide_missile", "glide_projectile" }
    }

    function VSWEP:DrawCrosshair()
        if self.CrosshairImage == "" then return end

        local vehicle = self.Vehicle
        local lockOnTarget = vehicle:GetLockOnTarget()
        local origin, color

        if IsValid( lockOnTarget ) then
            origin = lockOnTarget:GetPos()
            color = LOCKON_STATE_COLORS[vehicle:GetLockOnState()]
        else
            origin = vehicle:LocalToWorld( self.LocalCrosshairOrigin )
            color = LOCKON_STATE_COLORS[0]

            local ang = vehicle:LocalToWorldAngles( self.LocalCrosshairAngle )

            traceData.start = origin
            traceData.endpos = origin + ang:Forward() * 10000
            traceData.filter[1] = vehicle

            origin = TraceLine( traceData ).HitPos
        end

        local pos = origin:ToScreen()

        if pos.visible then
            DrawWeaponCrosshair( pos.x, pos.y, self.CrosshairImage, self.CrosshairSize, color )
        end
    end
end

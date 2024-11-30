AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_glide_tank"
ENT.PrintName = "Rhino"

ENT.GlideCategory = "Default"
ENT.ChassisModel = "models/gta5/vehicles/rhino/chassis.mdl"

DEFINE_BASECLASS( "base_glide_tank" )

if CLIENT then
    ENT.CameraOffset = Vector( -380, 0, 150 )

    ENT.EngineFireOffsets = {
        { offset = Vector( -110, 0, 30 ), angle = Angle( 0, 90, 0 ), scale = 1.5 }
    }

    ENT.EngineSmokeStrips = {
        { offset = Vector( -130, 40, 18 ), angle = Angle( 0, 180, 0 ), width = 35 },
        { offset = Vector( -130, -40, 18 ), angle = Angle( 0, 180, 0 ), width = 35 }
    }

    function ENT:OnCreateEngineStream( stream )
        stream:LoadPreset( "airbus" )
        stream.offset = Vector( -30, 0, 0 )
        stream.pitch = 0.9
        stream.maxVolume = 0.8
    end

    function ENT:OnActivateMisc()
        self:SetupLeftTrack( 4, "models/gta5/vehicles/rhino/tracks", "models/gta5/vehicles/rhino/tracks_n" )
        self:SetupRightTrack( 5, "models/gta5/vehicles/rhino/tracks", "models/gta5/vehicles/rhino/tracks_n" )

        self.lastSpinL = 0
        self.lastSpinR = 0

        -- Turret
        self.turretBase = self:LookupBone( "turret_base" )
        self.cannonBase = self:LookupBone( "cannon_base" )

        -- Track pivots
        self.pivotFL = self:LookupBone( "misc_fl" )
        self.pivotRL = self:LookupBone( "misc_rl" )
        self.pivotFR = self:LookupBone( "misc_fr" )
        self.pivotRR = self:LookupBone( "misc_rr" )

        -- Left suspension
        self.suspensionL1 = self:LookupBone( "suspension_l1" )
        self.suspensionL2 = self:LookupBone( "suspension_l2" )
        self.suspensionL3 = self:LookupBone( "suspension_l3" )
        self.suspensionL4 = self:LookupBone( "suspension_l4" )
        self.suspensionL5 = self:LookupBone( "suspension_l5" )

        self.leftWheels = {
            self:LookupBone( "wheel_l1" ),
            self:LookupBone( "wheel_l2" ),
            self:LookupBone( "wheel_l3" ),
            self:LookupBone( "wheel_l4" ),
            self:LookupBone( "wheel_l5" )
        }

        -- Right suspension
        self.suspensionR1 = self:LookupBone( "suspension_r1" )
        self.suspensionR2 = self:LookupBone( "suspension_r2" )
        self.suspensionR3 = self:LookupBone( "suspension_r3" )
        self.suspensionR4 = self:LookupBone( "suspension_r4" )
        self.suspensionR5 = self:LookupBone( "suspension_r5" )

        self.rightWheels = {
            self:LookupBone( "wheel_r1" ),
            self:LookupBone( "wheel_r2" ),
            self:LookupBone( "wheel_r3" ),
            self:LookupBone( "wheel_r4" ),
            self:LookupBone( "wheel_r5" )
        }
    end

    local spinAng = Angle()
    local offset = Vector()

    function ENT:OnUpdateAnimations()
        local dt = FrameTime()
        local spinL = -self:GetWheelSpin( 2 )

        spinAng[1] = 0
        spinAng[2] = 0
        spinAng[3] = spinL

        self.leftTrackScroll[1] = self.leftTrackScroll[1] + ( self.lastSpinL - spinL ) * dt * 0.4
        self.lastSpinL = spinL

        self:ManipulateBoneAngles( self.pivotFL, spinAng )
        self:ManipulateBoneAngles( self.pivotRL, spinAng )

        for _, id in ipairs( self.leftWheels ) do
            self:ManipulateBoneAngles( id, spinAng )
        end

        local spinR = -self:GetWheelSpin( 5 )
        spinAng[3] = spinR

        self.rightTrackScroll[1] = self.rightTrackScroll[1] + ( self.lastSpinR - spinR ) * dt * 0.35
        self.lastSpinR = spinR

        self:ManipulateBoneAngles( self.pivotFR, spinAng )
        self:ManipulateBoneAngles( self.pivotRR, spinAng )

        for _, id in ipairs( self.rightWheels ) do
            self:ManipulateBoneAngles( id, spinAng )
        end

        -- Update left side of the tracks, using the 3 wheels we have there.
        local l1 = self:GetWheelOffset( 1 ) + 8
        local l3 = self:GetWheelOffset( 2 ) + 8
        local l5 = self:GetWheelOffset( 3 ) + 8

        offset[2] = l1
        self:ManipulateBonePosition( self.suspensionL1, offset )

        offset[2] = ( l1 + l3 ) * 0.5
        self:ManipulateBonePosition( self.suspensionL2, offset )

        offset[2] = l3
        self:ManipulateBonePosition( self.suspensionL3, offset )

        offset[2] = ( l3 + l5 ) * 0.5
        self:ManipulateBonePosition( self.suspensionL4, offset )

        offset[2] = l5
        self:ManipulateBonePosition( self.suspensionL5, offset )

        -- Update right side of the tracks, using the 3 wheels we have there.
        local r1 = self:GetWheelOffset( 4 ) + 8
        local r3 = self:GetWheelOffset( 5 ) + 8
        local r5 = self:GetWheelOffset( 6 ) + 8

        offset[2] = r1
        self:ManipulateBonePosition( self.suspensionR1, offset )

        offset[2] = ( r1 + r3 ) * 0.5
        self:ManipulateBonePosition( self.suspensionR2, offset )

        offset[2] = r3
        self:ManipulateBonePosition( self.suspensionR3, offset )

        offset[2] = ( r3 + r5 ) * 0.5
        self:ManipulateBonePosition( self.suspensionR4, offset )

        offset[2] = r5
        self:ManipulateBonePosition( self.suspensionR5, offset )
    end
end

if SERVER then
    duplicator.RegisterEntityClass( "gtav_rhino", Glide.VehicleFactory, "Data" )

    ENT.SpawnPositionOffset = Vector( 0, 0, 50 )

    function ENT:CreateFeatures()
        self:CreateSeat( Vector( 60, 25, 0 ), Angle( 0, 270, 30 ), Vector( 60, 100, 0 ), false )

        -- Front left
        self:CreateWheel( Vector( 88, 55, -10 ), {
            steerMultiplier = 1
        } ):SetNoDraw( true )

        -- Middle left
        self:CreateWheel( Vector( 5, 55, -10 ) ):SetNoDraw( true )

        -- Rear left
        self:CreateWheel( Vector( -76, 55, -10 ), {
            steerMultiplier = -1
        } ):SetNoDraw( true )

        -- Front right
        self:CreateWheel( Vector( 88, -55, -10 ), {
            steerMultiplier = 1
        } ):SetNoDraw( true )

        -- Middle right
        self:CreateWheel( Vector( 5, -55, -10 ) ):SetNoDraw( true )

        -- Rear right
        self:CreateWheel( Vector( -76, -55, -10 ), {
            steerMultiplier = -1
        } ):SetNoDraw( true )

        -- Manipulate these on the server side only, to allow
        -- spawning projectiles on the correct position.
        self.turretBase = self:LookupBone( "turret_base" )
        self.cannonBase = self:LookupBone( "cannon_base" )
        self.cannonMuzzle = self:LookupBone( "cannon_muzzle" )
    end

    function ENT:GetProjectileStartPos()
        if self.cannonMuzzle then
            return self:GetBoneMatrix( self.cannonMuzzle ):GetTranslation()
        end

        return BaseClass.GetProjectileStartPos( self )
    end
end

do
    local ang = Angle()

    function ENT:ManipulateTurretBones()
        if not self.turretBase then return end

        local turretAng = self:GetTurretAngle()

        ang[1] = turretAng[2]
        ang[2] = 0
        ang[3] = 0

        self:ManipulateBoneAngles( self.turretBase, ang, false )

        ang[1] = 0
        ang[2] = 0
        ang[3] = turretAng[1]

        self:ManipulateBoneAngles( self.cannonBase, ang, false )
    end
end

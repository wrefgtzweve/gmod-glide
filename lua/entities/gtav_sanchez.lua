AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_glide_motorcycle"
ENT.PrintName = "Sanchez"

ENT.GlideCategory = "Default"
ENT.ChassisModel = "models/gta5/vehicles/sanchez/chassis.mdl"

DEFINE_BASECLASS( "base_glide_motorcycle" )

if CLIENT then
    ENT.CameraOffset = Vector( -170, 0, 50 )
    ENT.CameraFirstPersonOffset = Vector( 0, 0, 0 )

    ENT.ExhaustOffsets = {
        { pos = Vector( -40, -5, 15 ), scale = 0.7 }
    }

    ENT.EngineSmokeStrips = {
        { offset = Vector( 5, 0, 5 ), angle = Angle( 40, 180, 0 ), width = 15 }
    }

    ENT.EngineFireOffsets = {
        { offset = Vector( -3, 5, 5 ), angle = Angle( 90, 90, 0 ), scale = 0.4 },
        { offset = Vector( -3, -5, 5 ), angle = Angle( 90, 270, 0 ), scale = 0.4 }
    }

    ENT.LightSprites = {
        { type = "brake", offset = Vector( -43, 0, 17.5 ), dir = Vector( -1, 0, 0 ), lightRadius = 50 },
        { type = "headlight", offset = Vector( 26, 0, 19.6 ), dir = Vector( 1, 0, 0 ), color = Glide.DEFAULT_HEADLIGHT_COLOR }
    }

    ENT.Headlights = {
        { offset = Vector( 28, 0, 27 ), color = Glide.DEFAULT_HEADLIGHT_COLOR }
    }

    function ENT:OnCreateEngineStream( stream )
        stream.offset = Vector( 5, 0, 0 )
        stream:LoadPreset( "sanchez" )
    end

    --- Override the base class `OnActivateMisc` function.
    function ENT:OnActivateMisc()
        BaseClass.OnActivateMisc( self )

        self.frontBoneId = self:LookupBone( "front_wheel" )
        self.rearBoneId = self:LookupBone( "rear_wheel" )
    end

    local Abs = math.abs
    local IsValid = IsValid
    local spinAng = Angle()

    --- Override the base class `OnUpdateAnimations` function.
    function ENT:OnUpdateAnimations()
        BaseClass.OnUpdateAnimations( self )

        local wheels = self.wheels
        if not wheels then return end

        local f = wheels[2]
        local r = wheels[1]
        if not IsValid( f ) or not IsValid( r ) then return end

        local offset = ( Abs( f:GetLocalPos()[3] ) - 1 ) / 7
        self:SetPoseParameter( "suspension_front", 1 - offset )

        offset = ( Abs( r:GetLocalPos()[3] ) - 1 ) / 7
        self:SetPoseParameter( "suspension_rear", 1 - offset )

        if not self.frontBoneId then return end

        spinAng[3] = -f:GetSpin()
        self:ManipulateBoneAngles( self.frontBoneId, spinAng, false )

        spinAng[3] = -r:GetSpin()
        self:ManipulateBoneAngles( self.rearBoneId, spinAng, false )
    end
end

if SERVER then
    duplicator.RegisterEntityClass( "gtav_sanchez", Glide.VehicleFactory, "Data" )

    ENT.SpawnPositionOffset = Vector( 0, 0, 40 )
    ENT.StartupTime = 0.4
    ENT.BurnoutForce = 180

    ENT.LightBodygroups = {
        { type = "headlight", bodyGroupId = 6, subModelId = 1 }, -- Headlight
        { type = "headlight", bodyGroupId = 7, subModelId = 1 } -- Tail light
    }

    function ENT:CreateFeatures()
        self:SetTransmissionEfficiency( 0.7 )
        self:SetDifferentialRatio( 1.8 )
        self:SetBrakePower( 2000 )
        self:SetWheelInertia( 9 )

        self:SetMaxRPM( 15000 )
        self:SetMinRPMTorque( 500 )
        self:SetMaxRPMTorque( 600 )

        self:SetSuspensionLength( 7 )
        self:SetSpringStrength( 1000 )
        self:SetSpringDamper( 4500 )

        self:CreateSeat( Vector( -17, 0, 12 ), Angle( 0, 270, -16 ), Vector( 0, 60, 0 ), true )
        self:CreateSeat( Vector( -26, 0, 12 ), Angle( 0, 270, -5 ), Vector( 0, -60, 0 ), true )

        -- Front
        self:CreateWheel( Vector( 36, 0, -1 ), {
            model = "models/gta5/vehicles/blazer/wheel.mdl",
            modelScale = Vector( 0.4, 1, 1 ),
            modelAngle = Angle( 0, 90, 0 ),
            steerMultiplier = 1
        } ):SetNoDraw( true )

        -- Rear
        self:CreateWheel( Vector( -29, 0, -1 ), {
            model = "models/gta5/vehicles/blazer/wheel.mdl",
            modelScale = Vector( 0.4, 1, 1 ),
            modelAngle = Angle( 0, 90, 0 ),
            isPowered = true
        } ):SetNoDraw( true )

        self:ChangeWheelRadius( 14 )
    end
end

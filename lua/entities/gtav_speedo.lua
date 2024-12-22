AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_glide_car"
ENT.PrintName = "Speedo"

ENT.GlideCategory = "Default"
ENT.ChassisModel = "models/gta5/vehicles/speedo/chassis.mdl"

if CLIENT then
    ENT.CameraOffset = Vector( -300, 0, 70 )

    ENT.HornSound = "glide/horns/car_horn_med_1.wav"

    ENT.ExhaustOffsets = {
        { pos = Vector( -110, 40, -19 ) }
    }

    ENT.EngineSmokeStrips = {
        { offset = Vector( 100, 0, -2 ), width = 42 }
    }

    ENT.EngineSmokeMaxZVel = 250

    ENT.EngineFireOffsets = {
        { offset = Vector( 90, 0, 15 ) }
    }

    ENT.Headlights = {
        { offset = Vector( 105, 32, 6.2 ), color = Glide.DEFAULT_HEADLIGHT_COLOR },
        { offset = Vector( 105, -32, 6.2 ), color = Glide.DEFAULT_HEADLIGHT_COLOR },
    }

    ENT.LightSprites = {
        { type = "brake", offset = Vector( -118, 37, 20 ), dir = Vector( -1, 0, 0 ) },
        { type = "brake", offset = Vector( -118, -37, 20 ), dir = Vector( -1, 0, 0 ) },
        { type = "reverse", offset = Vector( -118, 38, 15 ), dir = Vector( -1, 0, 0 ) },
        { type = "reverse", offset = Vector( -118, -38, 15 ), dir = Vector( -1, 0, 0 ) },
        { type = "headlight", offset = Vector( 105, 32, 6.2 ), dir = Vector( 1, 0, 0 ), color = Glide.DEFAULT_HEADLIGHT_COLOR },
        { type = "headlight", offset = Vector( 105, -32, 6.2 ), dir = Vector( 1, 0, 0 ), color = Glide.DEFAULT_HEADLIGHT_COLOR }
    }

    function ENT:OnCreateEngineStream( stream )
        stream.offset = Vector( 60, 0, 0 )
        stream:LoadPreset( "speedo" )
    end
end

if SERVER then
    ENT.SpawnPositionOffset = Vector( 0, 0, 50 )
    ENT.ChassisMass = 900
    ENT.BurnoutForce = 35

    ENT.AirControlForce = Vector( 0.4, 0.2, 0.1 ) -- Roll, pitch, yaw
    ENT.AirMaxAngularVelocity = Vector( 200, 200, 150 ) -- Roll, pitch, yaw

    ENT.LightBodygroups = {
        { type = "reverse", bodyGroupId = 12, subModelId = 1 },
        { type = "headlight", bodyGroupId = 11, subModelId = 1 }, -- Headlights
        { type = "headlight", bodyGroupId = 13, subModelId = 1 }  -- Tail lighs
    }

    function ENT:CreateFeatures()
        self:SetSpringStrength( 700 )
        self:SetSteerConeMaxSpeed( 1000 )
        self:SetForwardTractionBias( -0.15 )
        self:SetForwardTractionMax( 2900 )

        self:SetDifferentialRatio( 2.3 )
        self:SetTransmissionEfficiency( 0.75 )
        self:SetPowerDistribution( 0.8 )
        self:SetBrakePower( 2500 )

        self:SetMinRPMTorque( 1000 )
        self:SetMaxRPMTorque( 1200 )

        self:CreateSeat( Vector( 5, 22, 0 ), Angle( 0, 270, -10 ), Vector( 50, 80, 10 ), true )
        self:CreateSeat( Vector( 25, -22, 0 ), Angle( 0, 270, 5 ), Vector( 50, -80, 10 ), true )

        self:CreateSeat( Vector( -80, -29, 0 ), Angle( 0, 0, 3 ), Vector( -140, -70, 10 ), true )
        self:CreateSeat( Vector( -80, 29, 0 ), Angle( 0, 180, 4 ), Vector( -140, 70, 10 ), true )

        -- Front left
        self:CreateWheel( Vector( 74, 38, -10 ), {
            model = "models/gta5/vehicles/speedo/wheel.mdl",
            modelAngle = Angle( 0, 90, 0 ),
            steerMultiplier = 1
        } )

        -- Front right
        self:CreateWheel( Vector( 74, -38, -10 ), {
            model = "models/gta5/vehicles/speedo/wheel.mdl",
            modelAngle = Angle( 0, -90, 0 ),
            steerMultiplier = 1
        } )

        -- Rear left
        self:CreateWheel( Vector( -74, 39, -10 ), {
            model = "models/gta5/vehicles/speedo/wheel.mdl",
            modelAngle = Angle( 0, 90, 0 )
        } )

        -- Rear right
        self:CreateWheel( Vector( -74, -39, -10 ), {
            model = "models/gta5/vehicles/speedo/wheel.mdl",
            modelAngle = Angle( 0, -90, 0 )
        } )

        self:ChangeWheelRadius( 18 )
    end
end

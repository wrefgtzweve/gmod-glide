-- Example car class
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_glide_car"
ENT.PrintName = "Insurgent Pick-up"

ENT.GlideCategory = "Default"
ENT.ChassisModel = "models/gta5/vehicles/insurgent/chassis.mdl"
ENT.MaxChassisHealth = 1500

function ENT:GetPlayerSitSequence( seatIndex )
    return seatIndex == 5 and "drive_pd" or ( seatIndex > 1 and "sit" or "drive_jeep" )
end

if CLIENT then
    ENT.CameraOffset = Vector( -400, 0, 120 )

    ENT.ExhaustOffsets = {
        { pos = Vector( -65, 40, 7 ) },
        { pos = Vector( -65, -40, 7 ) }
    }

    ENT.EngineSmokeStrips = {
        { offset = Vector( 119, 0, 14 ), angle = Angle(), width = 45 }
    }

    ENT.EngineSmokeMaxZVel = 150

    ENT.EngineFireOffsets = {
        { offset = Vector( 70, 0, 40 ), angle = Angle() }
    }

    ENT.Headlights = {
        { offset = Vector( 115, 34, 18 ), color = color_white },
        { offset = Vector( 115, -34, 18 ), color = color_white }
    }

    ENT.LightSprites = {
        { type = "brake", offset = Vector( -132, 30.5, 11 ), dir = Vector( -1, 0, 0 ) },
        { type = "brake", offset = Vector( -132, -30.5, 11 ), dir = Vector( -1, 0, 0 ) },

        { type = "reverse", offset = Vector( -132, 24, 11 ), dir = Vector( -1, 0, 0 ) },
        { type = "reverse", offset = Vector( -132, -24, 11 ), dir = Vector( -1, 0, 0 ) },

        { type = "headlight", offset = Vector( 115, 34, 17.5 ), dir = Vector( 1, 0, 0 ), color = color_white },
        { type = "headlight", offset = Vector( 115, -34, 17.5 ), dir = Vector( 1, 0, 0 ), color = color_white },
    }

    function ENT:OnCreateEngineStream( stream )
        stream:LoadPreset( "insurgent" )
    end
end

if SERVER then
    duplicator.RegisterEntityClass( "gtav_insurgent", Glide.VehicleFactory, "Data" )

    ENT.SpawnPositionOffset = Vector( 0, 0, 45 )
    ENT.ChassisMass = 1000

    ENT.LightBodygroups = {
        { type = "headlight", bodyGroupId = 14, subModelId = 1 }, -- Tail lights
        { type = "headlight", bodyGroupId = 12, subModelId = 1 },  -- Headlights
        { type = "headlight", bodyGroupId = 15, subModelId = 1 },  -- Extra lights
        { type = "reverse", bodyGroupId = 13, subModelId = 1 }
    }

    function ENT:CreateFeatures()
        self:SetWheelInertia( 11 )
        self:SetBrakePower( 3800 )
        self:SetDifferentialRatio( 3.3 )
        self:SetPowerDistribution( -0.4 )

        self:SetMaxSteerAngle( 30 )
        self:SetSteerConeMaxSpeed( 1100 )

        self:SetSuspensionLength( 14 )
        self:SetSpringStrength( 500 )
        self:SetSpringDamper( 2500 )

        self:SetTractionCurveMinAng( 30 )
        self:SetTractionCurveMax( 1000 )

        self:CreateSeat( Vector( -2, 21.5, 9 ), Angle( 0, 270, -5 ), Vector( 40, 100, 0 ), true )
        self:CreateSeat( Vector( 15, -21.5, 7 ), Angle( 0, 270, 5 ), Vector( 40, -100, 0 ), true )
        self:CreateSeat( Vector( -35, 20, 6 ), Angle( 0, 270, 5 ), Vector( -40, 100, 0 ), true )
        self:CreateSeat( Vector( -35, -20, 6 ), Angle( 0, 270, 5 ), Vector( -40, -100, 0 ), true )

        self.turretSeat = self:CreateSeat( Vector( -39, 0, 55 ), Angle( 0, 270, 0 ), Vector( -80, -100, 0 ), true )

        -- Front left
        self:CreateWheel( Vector( 82, 48, -8 ), {
            model = "models/gta5/vehicles/insurgent/wheel.mdl",
            modelAngle = Angle( 0, 90, 0 ),
            steerMultiplier = 1
        } )

        -- Front right
        self:CreateWheel( Vector( 82, -48, -8 ), {
            model = "models/gta5/vehicles/insurgent/wheel.mdl",
            modelAngle = Angle( 0, -90, 0 ),
            steerMultiplier = 1
        } )

        -- Rear left
        self:CreateWheel( Vector( -82, 48, -8 ), {
            model = "models/gta5/vehicles/insurgent/wheel.mdl",
            modelAngle = Angle( 0, 90, 0 ),
            modelScale = Vector( 0.35, 1, 1 )
        } )

        -- Rear right
        self:CreateWheel( Vector( -82, -48, -8 ), {
            model = "models/gta5/vehicles/insurgent/wheel.mdl",
            modelAngle = Angle( 0, -90, 0 ),
            modelScale = Vector( 0.35, 1, 1 )
        } )

        self:ChangeWheelRadius( 24 )
    end
end

SWEP.PrintName = "#glide.swep.repair"
SWEP.Instructions = "#glide.swep.repair.desc"
SWEP.Author = "StyledStrike"
SWEP.Category = "Glide"

SWEP.Slot = 0
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.UseHands = true
SWEP.ViewModelFOV = 60
SWEP.BobScale = 0.5
SWEP.SwayScale = 1.0

SWEP.ViewModel = "models/weapons/v_physcannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"

if CLIENT then
    SWEP.DrawCrosshair = false
    SWEP.BounceWeaponIcon = false
    SWEP.WepSelectIcon = surface.GetTextureID( "glide/vgui/glide_repair_wrench_icon" )
    SWEP.IconOverride = "glide/vgui/glide_repair_wrench.png"
end

SWEP.DrawAmmo = false
SWEP.HoldType = "physgun"

SWEP.Primary.Ammo = "none"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = true

SWEP.Secondary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    self:SetDeploySpeed( 1.5 )
end

function SWEP:Deploy()
    self:SetHoldType( self.HoldType )
    self:SetDeploySpeed( 1.5 )
    self:SetNextPrimaryFire( CurTime() + 0.5 )

    self.repairTarget = NULL
    self.aimPos = nil

    return true
end

function SWEP:Holster()
    self.repairTarget = NULL
    self.aimPos = nil

    return true
end

function SWEP:GetVehicleFromTrace( trace, user )
    if user:EyePos():DistToSqr( trace.HitPos ) > 8000 then
        return
    end

    local ent = trace.Entity

    if IsValid( ent ) and ent.IsGlideVehicle and self:WaterLevel() < 3 then
        return ent
    end
end

function SWEP:Think()
    local user = self:GetOwner()

    if IsValid( user ) then
        self.repairTarget = self:GetVehicleFromTrace( user:GetEyeTraceNoCursor(), user )
    end
end

local CurTime = CurTime
local REPAIR_SOUND = "glide/train/track_clank_%d.wav"

function SWEP:PrimaryAttack()
    local user = self:GetOwner()
    if not IsValid( user ) then return end

    self:SetNextPrimaryFire( CurTime() + 0.15 )

    if not SERVER then return end

    local ent = self.repairTarget
    if not ent then return end

    local engineHealth = ent:GetEngineHealth()
    local chassisHealth = ent:GetChassisHealth()

    if chassisHealth >= ent.MaxChassisHealth and engineHealth >= 1 then return end

    if chassisHealth < ent.MaxChassisHealth then
        chassisHealth = chassisHealth + 20
        engineHealth = math.Clamp( engineHealth + 0.03, 0, 1 )

        if user.ViewPunch then
            user:ViewPunch( Angle( -1, 0, 0 ) )
        end

        if chassisHealth > 0.3 and ent.SetIsEngineOnFire then
            ent:SetIsEngineOnFire( false )
        end

        user:EmitSound( REPAIR_SOUND:format( math.random( 6 ) ), 75, 150, 0.2 )
    end

    if chassisHealth > ent.MaxChassisHealth then
        chassisHealth = ent.MaxChassisHealth
        engineHealth = 1

        ent:Repair()
        user:EmitSound( "buttons/lever6.wav", 75, math.random( 110, 120 ), 0.5 )
    end

    if chassisHealth >= ent.MaxChassisHealth then
        engineHealth = 1
    end

    ent:SetChassisHealth( chassisHealth )
    ent:SetEngineHealth( engineHealth )

    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    user:SetAnimation( PLAYER_ATTACK1 )

    if ent.UpdateHealthOutputs then
        ent:UpdateHealthOutputs()
    end
end

function SWEP:SecondaryAttack()
end

if not CLIENT then return end

local COLORS = {
    HEALTH = Glide.THEME_COLOR,
    LOW_HEALTH = Color( 250, 20, 20, 255 )
}

local SetColor = surface.SetDrawColor
local DrawRect = surface.DrawRect
local DrawOutlinedRect = surface.DrawOutlinedRect

local function DrawHealthBar( x, y, w, h, health, armor )
    if armor > 0 then
        SetColor( 255, 255, 255, 255 )
        DrawOutlinedRect( x - 1, y - 1, ( w + 2 ) * armor, h + 2, 1 )
    end

    SetColor( 20, 20, 20, 255 )
    DrawRect( x, y, w, h )

    x, y = x + 1, y + 1
    w, h = w - 2, h - 2

    local color = health < 0.3 and COLORS.LOW_HEALTH or COLORS.HEALTH

    SetColor( color:Unpack() )
    DrawRect( x, y, w * health, h )
end

local AIM_ICON = Material( "glide/aim_area.png", "smooth" )

function SWEP:DrawHUD()
    if not self:IsWeaponVisible() then return end

    local ent = self.repairTarget
    if not IsValid( ent ) then return end

    local x, y = ScrW() * 0.5, ScrH() * 0.5
    local size = math.floor( ScrH() * 0.07 )

    SetColor( 255, 255, 255, 255 )
    surface.SetMaterial( AIM_ICON )
    surface.DrawTexturedRectRotated( x, y, size, size, 0 )

    local w = math.floor( ScrH() * 0.2 )
    local h = math.floor( ScrH() * 0.01 )

    x = x - w * 0.5
    y = y + h * 5

    DrawHealthBar( x, y, w, h, ent:GetChassisHealth() / ent.MaxChassisHealth, ent:GetEngineHealth() )

    return true
end

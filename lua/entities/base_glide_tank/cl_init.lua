include( "shared.lua" )

DEFINE_BASECLASS( "base_glide" )

function ENT:SetupLeftTrack( materialSlot, texture, bumpmap )
    self.leftTrackScroll = Vector()
    self.leftTrackTexture = texture
    self.leftTrackBumpMap = bumpmap
    self:SetSubMaterial( materialSlot, "!glide_tank_track_l" )
end

function ENT:SetupRightTrack( materialSlot, texture, bumpmap )
    self.rightTrackScroll = Vector()
    self.rightTrackTexture = texture
    self.rightTrackBumpMap = bumpmap
    self:SetSubMaterial( materialSlot, "!glide_tank_track_r" )
end

--- Implement the base class `AllowFirstPersonMuffledSound` function.
function ENT:AllowFirstPersonMuffledSound( _ )
    return false
end

--- Override the base class `GetFirstPersonOffset` function.
function ENT:GetFirstPersonOffset()
    return Vector( 0, 0, 90 )
end

--- Override the base class `OnEngineStateChange` function.
function ENT:OnEngineStateChange( _, _, state )
    if state == 1 then
        if self.engineSounds and self.engineSounds.isActive then
            local snd = self:CreateLoopingSound( "start", Glide.GetRandomSound( self.StartSound ), 70, self )
            snd:PlayEx( 1, 100 )
        end

    elseif state == 2 then
        self:OnTurnOn()

    elseif state == 0 then
        self:OnTurnOff()
    end
end

--- Implement the base class `OnDeactivateSounds` function.
function ENT:OnDeactivateSounds()
    if self.stream then
        self.stream:Destroy()
        self.stream = nil
    end
end

--- Implement the base class `OnTurnOn` function.
function ENT:OnTurnOn()
    if self.StartedSound ~= "" then
        self:EmitSound( self.StartedSound, 85, 100, 1.0 )
    end
end

--- Implement the base class `OnTurnOff` function.
function ENT:OnTurnOff()
    if self.StoppedSound ~= "" then
        self:EmitSound( self.StoppedSound, 75, 100, 1.0 )
    end

    if self.stream then
        self.stream:Destroy()
        self.stream = nil
    end

    if self.sounds.runDamaged then
        self.sounds.runDamaged:Stop()
        self.sounds.runDamaged = nil
    end
end

--- Override the base class `ActivateMisc` function.
function ENT:ActivateMisc()
    BaseClass.ActivateMisc( self )

    -- Reduce the number of wheels playing sounds
    local wheels = self.wheels
    if not wheels then return end

    for i, w in ipairs( wheels ) do
        w.skidmarkScale = 1

        if i == 2 or i == 5 then
            w.enableSounds = false
        end
    end
end

--- Override the base class `DeactivateMisc` function.
function ENT:DeactivateMisc()
    BaseClass.DeactivateMisc( self )

    if self.trackSound then
        self.trackSound:Stop()
        self.trackSound = nil
    end
end

local Abs = math.abs
local Clamp = math.Clamp
local GetVolume = Glide.Config.GetVolume

--- Implement the base class `OnUpdateMisc` function.
function ENT:OnUpdateMisc()
    local speed = Abs( self:GetTrackSpeed() )

    if speed > 1 then
        if self.trackSound then
            self.trackSound:ChangeVolume( Clamp( speed * 0.2, 0, 1 ) * self.TrackVolume * GetVolume( "carVolume" ) )
            self.trackSound:ChangePitch( 70 + Clamp( speed * 0.02, 0, 1 ) * 30 )
        else
            self.trackSound = CreateSound( self, self.TrackSound )
            self.trackSound:SetSoundLevel( 80 )
            self.trackSound:PlayEx( 0.0, 100 )
        end

    elseif self.trackSound then
        self.trackSound:Stop()
        self.trackSound = nil
    end

    self:OnUpdateAnimations()
    self:ManipulateTurretBones()
end

local FrameTime = FrameTime

--- Implement the base class `OnUpdateSounds` function.
function ENT:OnUpdateSounds()
    local sounds = self.sounds

    if sounds.start and self:GetEngineState() ~= 1 then
        sounds.start:Stop()
        sounds.start = nil
        Glide.PlaySoundSet( self.StartTailSound, self )
    end

    if not self:IsEngineOn() then return end

    local stream = self.stream

    if not stream then
        self.stream = Glide.CreateEngineStream( self )
        self:OnCreateEngineStream( self.stream )
        self.stream.volume = 0
        self.stream:Play()

        return
    end

    local dt = FrameTime()

    if stream.volume < stream.maxVolume then
        stream.volume = math.Approach( stream.volume, stream.maxVolume, dt * 2 )
    end

    local inputs = stream.inputs

    inputs.rpmFraction = self:GetEnginePower()
    inputs.throttle = self:GetEngineThrottle()

    stream:Think( dt )
end

local DrawWeaponCrosshair = Glide.DrawWeaponCrosshair
local crosshairColor = {
    [true] = Color( 255, 255, 255, 255 ),
    [false] = Color( 150, 150, 150, 100 )
}

--- Override the base class `DrawVehicleHUD` function.
function ENT:DrawVehicleHUD()
    BaseClass.DrawVehicleHUD( self )

    DrawWeaponCrosshair( ScrW() * 0.5, ScrH() * 0.5, "glide/aim_tank.png", 0.14, crosshairColor[self:GetIsAimingAtTarget()] )
end

local Effect = util.Effect
local EffectData = EffectData

local DEFAULT_EXHAUST_ANG = Angle()

function ENT:OnUpdateParticles()
    local health = self:GetEngineHealth()
    if health > 0.5 then return end

    local color = Clamp( health * 255, 0, 255 )
    local velocity = self:GetVelocity()
    local scale = 2 - health * 2

    for _, v in ipairs( self.EngineSmokeStrips ) do
        local eff = EffectData()
        eff:SetOrigin( self:LocalToWorld( v.offset ) )
        eff:SetAngles( self:LocalToWorldAngles( v.angle or DEFAULT_EXHAUST_ANG ) )
        eff:SetStart( velocity )
        eff:SetColor( color )
        eff:SetMagnitude( v.width * 1000 )
        eff:SetScale( scale )
        eff:SetRadius( self.EngineSmokeMaxZVel )
        Effect( "glide_damaged_engine", eff, true, true )
    end
end

local matTrackL = CreateMaterial( "glide_tank_track_l", "VertexLitGeneric", {
    ["$alphatest"] = "1",
    ["$allowdiffusemodulation"] = "false"
} )

local matTrackR = CreateMaterial( "glide_tank_track_r", "VertexLitGeneric", {
    ["$alphatest"] = "1",
    ["$allowdiffusemodulation"] = "false"
} )

local scrollMatrix = Matrix()

function ENT:Draw()
    if self.leftTrackTexture then
        scrollMatrix:SetTranslation( self.leftTrackScroll )
        matTrackL:SetMatrix( "$basetexturetransform", scrollMatrix )
        matTrackL:SetTexture( "$basetexture", self.leftTrackTexture )
    end

    if self.leftTrackBumpMap then
        matTrackL:SetTexture( "$bumpmap", self.leftTrackBumpMap )
    end

    if self.rightTrackTexture then
        scrollMatrix:SetTranslation( self.rightTrackScroll )
        matTrackR:SetMatrix( "$basetexturetransform", scrollMatrix )
        matTrackR:SetTexture( "$basetexture", self.rightTrackTexture )
    end

    if self.rightTrackBumpMap then
        matTrackR:SetTexture( "$bumpmap", self.rightTrackBumpMap )
    end

    self:DrawModel()
end

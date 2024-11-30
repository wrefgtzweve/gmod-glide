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

--- Implement the base class `ShouldActivateSounds` function.
function ENT:ShouldActivateSounds()
    return self:IsEngineOn()
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

local traceData = {
    filter = {
        [1] = NULL,
        [2] = "glide_missile"
    }
}

local TraceLine = util.TraceLine
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

    if self:GetDriver() ~= LocalPlayer() then return end

    local pos = self:GetPos()

    traceData.start = pos
    traceData.endpos = pos + self:GetTurretAngle():Forward() * 50000
    traceData.filter[1] = self

    self.crosshairPos = TraceLine( traceData ).HitPos
end

local FrameTime = FrameTime

--- Implement the base class `OnUpdateSounds` function.
function ENT:OnUpdateSounds()
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

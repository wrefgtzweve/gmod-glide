include( "shared.lua" )

DEFINE_BASECLASS( "base_glide_aircraft" )

--- Implement the base class `OnTurnOn` function.
function ENT:OnTurnOn()
    if self:GetPower() < 0.01 then
        self:EmitSound( self.StartSoundPath, 80, 100, 0.6 )
    end
end

--- Override the base class `OnActivateSounds` function.
function ENT:OnActivateSounds()
    self:CreateLoopingSound( "engine", self.EngineSoundPath, self.EngineSoundLevel )
    self:CreateLoopingSound( "exhaust", self.ExhaustSoundPath, self.ExhaustSoundLevel )
    self:CreateLoopingSound( "distant", self.DistantSoundPath, self.DistantSoundLevel )

    if self.PropSoundPath == "" then return end

    -- Create a client-side entity to play the propeller sound
    self.entProp = ClientsideModel( "models/hunter/plates/plate.mdl" )
    self.entProp:SetPos( self:LocalToWorld( self.PropOffset ) )
    self.entProp:Spawn()
    self.entProp:SetParent( self )
    self.entProp:SetNoDraw( true )

    self:CreateLoopingSound( "prop", self.PropSoundPath, self.PropSoundLevel, self.entProp )
end

--- Override the base class `OnDeactivateSounds` function.
function ENT:OnDeactivateSounds()
    if IsValid( self.entProp ) then
        self.entProp:Remove()
        self.entProp = nil
    end
end

local DynamicLight = DynamicLight

local function DrawLight( id, pos, color, size )
    local dl = DynamicLight( id )
    if dl then
        dl.pos = pos
        dl.r = color.r
        dl.g = color.g
        dl.b = color.b
        dl.brightness = 5
        dl.decay = 1000
        dl.size = size or 70
        dl.dietime = CurTime() + 0.05
    end
end

local RealTime = RealTime
local DrawLightSprite = Glide.DrawLightSprite

--- Implement the base class `OnUpdateMisc` function.
function ENT:OnUpdateMisc()
    self:OnUpdateAnimations()

    local t = RealTime() % 1
    local on, pos, color

    for i, v in ipairs( self.StrobeLights ) do
        on = t > v.blinkTime and t < v.blinkTime + 0.05

        if on then
            pos = self:LocalToWorld( v.offset )
            color = self.StrobeLightColors[i]

            DrawLight( self:EntIndex() + i, pos, color, 80 )
            DrawLightSprite( pos, nil, 30, color )
        end
    end
end

local Clamp = math.Clamp
local Remap = math.Remap

local GetVolume = Glide.Config.GetVolume

--- Override the base class `OnUpdateSounds` function.
function ENT:OnUpdateSounds()
    local sounds = self.sounds
    local vol = GetVolume( "aircraftVolume" )

    for _, snd in pairs( sounds ) do
        if not snd:IsPlaying() then
            snd:PlayEx( 0, 1 )
        end
    end

    local power = self:GetPower()
    local power01 = Clamp( power, 0, 1 )

    if sounds.prop then
        sounds.prop:ChangePitch( Remap( power, 1, 2, self.PropSoundMinPitch, self.PropSoundMaxPitch ) )
        sounds.prop:ChangeVolume( power01 * self.PropSoundVolume * vol )
    end

    sounds.engine:ChangePitch( Remap( power, 1, 2, self.EngineSoundMinPitch, self.EngineSoundMaxPitch ) * power01 )
    sounds.engine:ChangeVolume( power01 * self.EngineSoundVolume * vol )

    sounds.exhaust:ChangePitch( Remap( power, 1, 2, self.ExhaustSoundMinPitch, self.ExhaustSoundMaxPitch ) * power01 )
    sounds.exhaust:ChangeVolume( power01 * self.ExhaustSoundVolume * vol )

    vol = vol * Clamp( self.engineSounds.lastDistance / 1000000, 0, 1 )

    sounds.distant:ChangePitch( Remap( power, 1, 2, 80, 100 ) )
    sounds.distant:ChangeVolume( vol * power01 )
end
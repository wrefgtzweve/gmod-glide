include( "shared.lua" )

function ENT:Initialize()
    self.isActive = false
    self.particleCD = 0
    self.modelCD = 0

    self.sounds = {}
    self.soundSurface = {}

    self.enableSounds = true
    self.skidmarkScale = 0.5
end

function ENT:OnRemove()
    self:CleanupSounds()
end

function ENT:CleanupSounds()
    self.lastSkidId = nil
    self.lastRollId = nil

    for _, snd in pairs( self.sounds ) do
        snd:Stop()
    end

    table.Empty( self.sounds )
    table.Empty( self.soundSurface )
end

local Clamp = math.Clamp

function ENT:ProcessSound( id, surfaceId, soundSet, altSurface, volume, pitch )
    if not self.enableSounds then return end

    local path = soundSet[surfaceId]
    local snd = self.sounds[id]

    -- Remove the sound if we're on the air, or the volume is too low,
    -- or we are missing a sound path/alternative sound path for this surface.
    if surfaceId == 0 or volume < 0.01 or ( not path and not altSurface ) then
        if snd then
            snd:Stop()
            self.sounds[id] = nil
        end

        return
    end

    -- Remove the sound if the surface has changed since the last call
    if surfaceId ~= self.soundSurface[id] then
        self.soundSurface[id] = surfaceId

        if snd then
            self.sounds[id] = nil
            snd:Stop()
            snd = nil
        end
    end

    if not snd then
        snd = CreateSound( self, path or soundSet[altSurface] )
        snd:SetSoundLevel( 80 )
        snd:PlayEx( 0, 100 )
        self.sounds[id] = snd
    end

    snd:ChangeVolume( volume )
    snd:ChangePitch( pitch )
end

local WHEEL_SOUNDS = Glide.WHEEL_SOUNDS
local ROLL_VOLUME = Glide.WHEEL_SOUNDS.ROLL_VOLUME
local SKID_MARK_SURFACES = Glide.SKID_MARK_SURFACES
local TIRE_ROLL_SURFACES = Glide.TIRE_ROLL_SURFACES

local AddSkidMarkPiece = Glide.AddSkidMarkPiece
local AddTireRollPiece = Glide.AddTireRollPiece

local IsValid = IsValid
local CurTime = CurTime
local Abs = math.abs

local Effect = util.Effect
local EffectData = EffectData
local IsUnderWater = Glide.IsUnderWater

local m = Matrix()

function ENT:Think()
    local t = CurTime()

    self:SetNextClientThink( t + 0.01 )

    -- Periodically rotate and resize the wheel model
    if t > self.modelCD then
        m:SetAngles( self:GetModelAngle() )
        m:SetScale( self:GetModelScale2() )
        self:EnableMatrix( "RenderMultiply", m )
        self.modelCD = t + 1
    end

    local parent = self:GetParent()
    if not IsValid( parent ) then return true end
    if not parent.miscFeatures then return true end

    -- Stop processing when the "miscFeatures" RangedFeature
    -- from our parent vehicle is not active.
    -- (Aka. the player is too far away or out of the PVS).
    local isActive = parent.miscFeatures.isActive
    if not isActive then return true end

    local velocity = parent:GetVelocity()
    local speed = Abs( parent:WorldToLocal( parent:GetPos() + velocity )[1] )

    local up = parent:GetUp()
    local surfaceId = self:GetContactSurface()
    local contactPos = self:GetPos() - up * self:GetRadius()

    if surfaceId > 0 and IsUnderWater( contactPos ) then
        surfaceId = 83
    end

    local isOnConcrete = surfaceId == 67
    local isTankWheel = parent.VehicleType == 5 -- Glide.VEHICLE_TYPE.TANK

    -- Fast roll sound
    local fastAmplitude = speed / 600

    self:ProcessSound( "fastRoll", surfaceId, WHEEL_SOUNDS.ROLL, nil,
        Clamp( fastAmplitude * 0.75, 0, ROLL_VOLUME[surfaceId] or 0.4 ), 70 + 25 * fastAmplitude )

    -- Slow roll sound
    local slowAmplitude = ( isTankWheel and isOnConcrete ) and 0 or 1.02 - ( speed / 600 )

    self:ProcessSound( "slowRoll", surfaceId, WHEEL_SOUNDS.ROLL_SLOW, 88,
        slowAmplitude * fastAmplitude * 2, 110 - 30 * slowAmplitude )

    -- Side slip sound
    local sideSlipAmplitude = ( isTankWheel and isOnConcrete ) and 0 or Abs( self:GetSideSlip() ) - 0.1

    sideSlipAmplitude = Clamp( sideSlipAmplitude * 1.5, 0, 0.8 )

    self:ProcessSound( "sideSlip", surfaceId, WHEEL_SOUNDS.SIDE_SLIP, nil,
        sideSlipAmplitude, 110 - 30 * sideSlipAmplitude )

    -- Forward slip sound
    local forwardSlip = self:GetForwardSlip() * 0.04
    local forwardSlipAmplitude = Clamp( Abs( forwardSlip ) - 0.1, 0, 1 )

    self:ProcessSound( "forwardSlip", surfaceId, WHEEL_SOUNDS.FORWARD_SLIP, 88,
        forwardSlipAmplitude, 100 - forwardSlipAmplitude * 10 )

    if isTankWheel and isOnConcrete then
        self.lastSkidId = nil
        self.lastRollId = nil

        return
    end

    -- Particles
    if t > self.particleCD then
        self.particleCD = t + 0.05

        if TIRE_ROLL_SURFACES[surfaceId] or surfaceId == 83 then
            sideSlipAmplitude = sideSlipAmplitude + Clamp( fastAmplitude, 0, 1 )
        end

        if sideSlipAmplitude > 0.05 then
            local scale = Clamp( self:GetRadius() * 0.05, 0.1, 1 )

            local eff = EffectData()
            eff:SetEntity( parent )
            eff:SetOrigin( contactPos )
            eff:SetStart( velocity )
            eff:SetScale( scale * sideSlipAmplitude )
            eff:SetSurfaceProp( surfaceId )
            Effect( "glide_tire_roll", eff )
        end

        if forwardSlipAmplitude > 0.2 and surfaceId ~= 83 then
            local fw = parent:GetForward()
            local scale = self:GetRadius() * ( 0.03 + Clamp( Abs( forwardSlip / 30 ), 0, 0.2 ) )

            local eff = EffectData()
            eff:SetEntity( parent )
            eff:SetOrigin( contactPos )
            eff:SetNormal( fw * ( forwardSlip > 1 and 1 or -1 ) )
            eff:SetScale( scale * forwardSlipAmplitude )
            eff:SetSurfaceProp( surfaceId )
            Effect( "glide_tire_slip", eff )
        end

        sideSlipAmplitude = sideSlipAmplitude + forwardSlipAmplitude

        if sideSlipAmplitude > 0.3 and SKID_MARK_SURFACES[surfaceId] then
            contactPos = contactPos + velocity * 0.04
            self.lastSkidId = AddSkidMarkPiece( self.lastSkidId, contactPos, velocity, up, self:GetRadius() * self.skidmarkScale, Clamp( sideSlipAmplitude, 0, 1 ) )
        else
            self.lastSkidId = nil
        end

        if fastAmplitude > 0.05 and TIRE_ROLL_SURFACES[surfaceId] then
            contactPos = contactPos + velocity * 0.04
            self.lastRollId = AddTireRollPiece( self.lastRollId, contactPos, velocity, up, self:GetRadius() * self.skidmarkScale, 1 )
        else
            self.lastRollId = nil
        end
    end

    return true
end

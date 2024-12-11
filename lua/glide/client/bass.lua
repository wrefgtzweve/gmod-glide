--[[
    Utility class to handle sounds from the BASS library.

    Loads sounds one by one to prevent `FILEFORM` errors,
    handles the math to make 2D sounds behave like 3D on demand,
    and uses the correct hooks to not "lag behind" fast-moving entities.
]]

local instances = Glide.bassInstances or {}

Glide.bassInstances = instances

-----

local Bass = Glide.Bass or {}

Glide.Bass = Bass
Bass.__index = Bass

function Glide.CreateBass( path )
    local id = ( Glide.bassLastInstanceID or 0 ) + 1
    Glide.bassLastInstanceID = id

    local bass = {
        path = path,
        origin = Vector(),
        fadeDist = 1000,

        pitch = 1.0,
        volume = 1.0,
        isPlaying = false,

        isLoaded = false,
        noPan = false,
        id = id
    }

    instances[id] = bass

    return setmetatable( bass, Bass )
end

local IsValid = IsValid

function Bass:Destroy()
    if IsValid( self.channel ) then
        self.channel:Stop()
    end

    instances[self.id] = nil

    self.channel = nil
    self.id = nil

    setmetatable( self, nil )
end

local Clamp = math.Clamp

local pitch, vol, pan
local dir, dist

function Bass:Think( eyePos, eyeRight )
    local channel = self.channel
    if not IsValid( channel ) then return end

    pitch, vol, pan = self.pitch, self.volume, 0
    dir = self.origin - eyePos
    dist = dir:Length()

    vol = vol * ( 1 - Clamp( dist / self.fadeDist, 0, 1 ) )

    if self.noPan then
        pan = 0
    else
        dir:Normalize()
        pan = eyeRight:Dot( dir )
    end

    channel:SetPlaybackRate( pitch )
    channel:SetVolume( vol )
    channel:SetPan( pan )

    if self.isPlaying and channel:GetState() < 1 then
        channel:Play()
    end
end

-----

local loadingId = nil

local function DestroyChannel( channel )
    if IsValid( channel ) then
        channel:Stop()
    end
end

local function LoadCallback( channel, _, errorName )
    -- Sanity check
    if not loadingId then
        DestroyChannel( channel )
        return
    end

    -- Make sure the instance still exists
    local bass = instances[loadingId]

    if not bass then
        Glide.Print( "Destroying audio for bass instance #%s, instance no longer exists.", loadingId )
        DestroyChannel( channel )
        loadingId = nil
        return
    end

    -- Make sure the channel is valid
    if not IsValid( channel ) then
        Glide.Print( "Could not load audio for bass instance #%s: %s", loadingId, errorName )
        loadingId = nil
        return
    end

    loadingId = nil
    bass.channel = channel

    channel:EnableLooping( true )
    channel:SetPlaybackRate( 1.0 )
    channel:SetVolume( 0.0 )
    channel:SetPan( 0 )
end

local EyePos = EyePos
local EyeAngles = EyeAngles

-- PostDrawOpaqueRenderables seems like a good place to get values from EyePos/EyeAngles reliably.
hook.Add( "PostDrawOpaqueRenderables", "Glide.HandleBass",
    function( bDrawingDepth, bDrawingSkybox, isDraw3DSkybox )
    if bDrawingDepth or bDrawingSkybox or isDraw3DSkybox then return end

    local eyePos = EyePos()
    local eyeRight = EyeAngles():Right()

    for id, bass in pairs( instances ) do
        if bass.isLoaded then
            bass:Think( eyePos, eyeRight )

        elseif loadingId == nil then
            -- Load bass sounds, one at a time
            loadingId = id
            bass.isLoaded = true
            sound.PlayFile( "sound/" .. bass.path, "noplay noblock", LoadCallback )
        end
    end
end )

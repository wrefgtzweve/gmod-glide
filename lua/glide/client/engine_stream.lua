--[[
    Utility class to handle engine sounds with the BASS library.

    Allows the manipulation of the pitch/volume of many sound
    layers using a combination of "controllers".
]]

local EngineStream = Glide.EngineStream or {}

Glide.EngineStream = EngineStream
EngineStream.__index = EngineStream

function Glide.CreateEngineStream( parent )
    return setmetatable( {
        layers = {},
        parent = parent,
        offset = Vector( 40, 0, 0 ),

        volume = 1,
        pitch = 1,
        maxVolume = 1.0,
        fadeDist = 2000,

        redlineFrequency = 50,
        wobbleFrequency = 25,
        wobbleStrength = 0.13,

        wobbleTime = 0,
        isRedlining = false,
        firstPerson = false,
        isPlaying = false,

        inputs = {
            throttle = 0,
            rpmFraction = 0
        }
    }, EngineStream )
end

function EngineStream:Destroy()
    for id, _ in pairs( self.layers ) do
        self:RemoveLayer( id )
    end
end

function EngineStream:LoadPreset( name )
    local path = "data_static/glide/stream_presets/" .. name .. ".json"
    local data = file.Read( path, "GAME" )

    if data then
        self:LoadJSON( data )
    else
        Glide.Print( "Engine stream preset not found: %s", path )
    end
end

local VALID_KV = {
    pitch = true,
    maxVolume = true,
    fadeDist = true,
    redlineFrequency = true,
    wobbleFrequency = true,
    wobbleStrength = true
}

function EngineStream:LoadJSON( data )
    data = Glide.FromJSON( data )

    local keyValues = data.kv or {}
    local layers = data.layers

    if type( keyValues ) ~= "table" then
        Glide.Print( "JSON does not have valid key-value data!" )
        return
    end

    for k, v in pairs( keyValues ) do
        if VALID_KV[k] and type( v ) == "number" then
            self[k] = v
        else
            Glide.Print( "Invalid key/value: %s/$s", k, v )
        end
    end

    if type( layers ) ~= "table" then
        Glide.Print( "JSON does not have valid layer data!" )
        return
    end

    for id, layer in SortedPairs( layers ) do
        if type( layer ) ~= "table" then
            Glide.Print( "JSON does not look like sound preset data!" )
            return
        end

        local p = layer.path
        local c = layer.controllers

        if
            type( id ) == "string" and
            type( p ) == "string" and
            type( c ) == "table"
        then
            self:AddLayer( id, p, c, layer.redline == true )
        else
            Glide.Print( "JSON does not look like sound preset data!" )
            return
        end
    end
end

local IsValid = IsValid

local function Load( instance, id, path )
    sound.PlayFile( "sound/" .. path, "3d noplay noblock", function( snd, _, errStr )
        if not IsValid( snd ) then
            Glide.Print( "Failed to load '%s' for layer '%s': %s", path, id, errStr )

            if instance.errorCallback then
                instance.errorCallback( id, path, errStr )
            end

            return
        end

        instance:OnLoadLayer( id, snd, path )
    end )
end

local outputs = {
    volume = 0,
    pitch = 0
}

do
    local VALIDATION_MSG = "Layer '%s', controller #%d: %s"

    local function Validate( controller, controllerId, layerId, stream )
        if not stream.inputs[controller[1]] then
            return false, VALIDATION_MSG:format( layerId, controllerId, "Invalid input type!" )
        end

        if type( controller[2] ) ~= "number" then
            return false, VALIDATION_MSG:format( layerId, controllerId, "Min. input value must be a number!" )
        end

        if type( controller[3] ) ~= "number" then
            return false, VALIDATION_MSG:format( layerId, controllerId, "Max. input value must be a number!" )
        end

        if not outputs[controller[4]] then
            return false, VALIDATION_MSG:format( layerId, controllerId, "Invalid output type!" )
        end

        if type( controller[5] ) ~= "number" then
            return false, VALIDATION_MSG:format( layerId, controllerId, "Min. output value must be a number!" )
        end

        if type( controller[6] ) ~= "number" then
            return false, VALIDATION_MSG:format( layerId, controllerId, "Max. output value must be a number!" )
        end

        return true
    end

    function EngineStream:AddLayer( id, path, controllers, redline )
        if self.layers[id] then return end

        if not table.IsSequential( controllers ) then
            Glide.Print( "Controllers for the layer '%s' must be a sequential table!", id )
            return
        end

        for i, c in ipairs( controllers ) do
            local valid, msg = Validate( c, i, id, self )

            if not valid then
                Glide.Print( msg )
                return
            end
        end

        self.layers[id] = {
            path = path,
            redline = redline,
            controllers = controllers,

            -- These are set after the controllers have calculated them
            volume = 0,
            pitch = 0
        }

        Load( self, id, path )
    end
end

function EngineStream:RemoveLayer( id )
    local layer = self.layers[id]
    if not layer then return end

    if IsValid( layer.snd ) then
        layer.snd:Stop()
    end

    self.layers[id] = nil
end

function EngineStream:OnLoadLayer( id, snd, path )
    local layer = self.layers[id]

    if not layer then
        snd:Stop()

        Glide.Print( "Removing sound '%s' because the layer '%s' does not exist anymore.", path, id )
        return
    end

    if path ~= layer.path then
        snd:Stop()

        Glide.Print( "Sound '%s' does not match the path for layer '%s' anymore.", path, id )
        return
    end

    if IsValid( layer.snd ) then
        layer.snd:Stop()
    end

    layer.snd = snd

    snd:SetPos( self.parent:GetPos() )
    snd:SetVolume( 0 )
    snd:Set3DFadeDistance( self.fadeDist * 0.2, self.fadeDist )
    snd:EnableLooping( true )

    if self.isPlaying then
        snd:Play()
    end
end

function EngineStream:Play()
    self.isPlaying = true

    for _, layer in pairs( self.layers ) do
        if IsValid( layer.snd ) then
            layer.snd:SetTime( 0, true )
            layer.snd:SetVolume( 0 )
            layer.snd:Play()
        end
    end
end

function EngineStream:Pause()
    self.isPlaying = false

    for _, layer in pairs( self.layers ) do
        if IsValid( layer.snd ) then
            layer.snd:Pause()
        end
    end
end

local Clamp = math.Clamp
local Remap = math.Remap

local Cos = math.cos
local Time = RealTime

local EyePos = EyePos
local GetVolume = Glide.Config.GetVolume

function EngineStream:Think( dt )
    local pos = self.firstPerson and EyePos() + self.parent:GetForward() * 30 or self.parent:LocalToWorld( self.offset )

    pos = pos + self.parent:GetVelocity() * dt

    local wave = Clamp( Cos( Time() * self.redlineFrequency ) * 2, -1, 1 )
    local redline = self.isRedlining and 0.8 + wave * 0.3 or 1

    local inputs = self.inputs
    local volume = self.volume * GetVolume( "carVolume" )
    local pitch = 1
    local value

    if self.wobbleTime > 0 then
        self.wobbleTime = self.wobbleTime - dt
        pitch = pitch + Cos( self.wobbleTime * self.wobbleFrequency ) * self.wobbleTime * ( 1 - self.wobbleTime ) * self.wobbleStrength
    end

    redline = redline * volume
    pitch = pitch * self.pitch

    for _, layer in pairs( self.layers ) do
        local snd = layer.snd

        if IsValid( snd ) then
            outputs.volume, outputs.pitch = 1, 1

            for _, c in ipairs( layer.controllers ) do
                value = Clamp( inputs[c[1]], c[2], c[3] )
                value = Remap( value, c[2], c[3], c[5], c[6] )

                -- If any previous controller(s) changed the
                -- same output type, mix their output with this one.
                outputs[c[4]] = outputs[c[4]] * value
            end

            layer.volume = outputs.volume * ( layer.redline and redline or volume )
            layer.pitch = outputs.pitch * pitch

            snd:SetPos( pos )
            snd:SetVolume( layer.volume )
            snd:SetPlaybackRate( layer.pitch )
        end
    end
end

-- Max. Engine Stream layers
Glide.MAX_STREAM_LAYERS = 8

-- Default Engine Stream parameters
local DEFAULT_STREAM_PARAMS = {
    pitch = 1,
    volume = 1,
    fadeDist = 1500,

    redlineFrequency = 55,
    wobbleFrequency = 25,
    wobbleStrength = 0.13
}

Glide.DEFAULT_STREAM_PARAMS = DEFAULT_STREAM_PARAMS

function Glide.ValidateStreamData( data )
    if type( data ) ~= "table" then
        return false, "Preset is not a table!"
    end

    local keyValues = data.kv

    if keyValues then
        if type( keyValues ) ~= "table" then
            return false, "Preset does not have valid key-value data!"
        end

        for k, v in pairs( keyValues ) do
            if not DEFAULT_STREAM_PARAMS[k] or type( v ) ~= "number" then
                data[k] = nil -- If invalid, just remove KV pair
            end
        end
    end

    local layers = data.layers

    if type( layers ) ~= "table" then
        return false, "Preset does not have valid layer data!"
    end

    local p, c
    local count, max = 0, Glide.MAX_STREAM_LAYERS

    for id, layer in pairs( layers ) do
        if type( layer ) ~= "table" then
            return false, "Preset does not look like sound preset data!"
        end

        p = layer.path
        c = layer.controllers

        if
            type( id ) ~= "string" or
            type( p ) ~= "string" or
            type( c ) ~= "table"
        then
            return false, "Preset does not look like sound preset data!"
        end

        count = count + 1

        if count >= max then
            return false, "Preset data has too many layers!"
        end
    end

    return true
end

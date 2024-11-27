local sprites = {}
local spriteCount = 0

function Glide.DrawLightSprite( pos, dir, size, color )
    spriteCount = spriteCount + 1
    sprites[spriteCount] = { pos, size, color, dir }
end

local Max = math.max
local EyeVector = EyeVector

local SetMaterial = render.SetMaterial
local DrawSprite = render.DrawSprite

local matLight = Material( "glide/effects/light_glow" )

hook.Add( "PreDrawEffects", "Glide.DrawSprites", function()
    if spriteCount < 1 then return end

    SetMaterial( matLight )

    local dir = -EyeVector()
    local s, dot

    for i = 1, spriteCount do
        s = sprites[i]
        dot = s[4] and dir:Dot( s[4] ) or 1
        dot = ( dot - 0.5 ) * 2

        s[2] = s[2] * Max( 0, dot )

        DrawSprite( s[1], s[2], s[2], s[3] )

        sprites[i] = nil
    end

    spriteCount = 0
end )

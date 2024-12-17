local sprites = {}
local spriteCount = 0

function Glide.DrawLightSprite( pos, dir, size, color )
    spriteCount = spriteCount + 1
    sprites[spriteCount] = { pos, size, color, dir }
end

local Max = math.max
local Clamp = math.Clamp

local SetMaterial = render.SetMaterial
local DrawSprite = render.DrawSprite
local DepthRange = render.DepthRange

local GetLocalViewLocation = Glide.GetLocalViewLocation
local matLight = Material( "glide/effects/light_glow" )

hook.Add( "PreDrawEffects", "Glide.DrawSprites", function()
    if spriteCount < 1 then return end

    SetMaterial( matLight )

    local pos, ang = GetLocalViewLocation()
    local dir = -ang:Forward()
    local s, dot

    for i = 1, spriteCount do
        s = sprites[i]

        -- Make so the sprite draws over things that are right on top of it,
        -- but does not draw on top of walls when viewed from far away.
        DepthRange( 0.0, Clamp( pos:DistToSqr( s[1] ) / 200000, 0.999, 1 ) )

        -- Make the sprite smaller as the viewer points away from it
        dot = s[4] and dir:Dot( s[4] ) or 1
        dot = ( dot - 0.5 ) * 2
        s[2] = s[2] * Max( 0, dot )

        DrawSprite( s[1], s[2], s[2], s[3] )

        sprites[i] = nil
    end

    spriteCount = 0
    DepthRange( 0.0, 1.0 )
end )

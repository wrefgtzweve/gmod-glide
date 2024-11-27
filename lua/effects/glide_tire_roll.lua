local DEBRIS_FX = {
    [MAT_GRASS] = {
        mat = Material( "particle/particle_debris_02" ),
        r = 255, g = 255, b = 255,
        minSize = 40,
        maxSize = 50,
        lifetime = 0.8,
        alpha = 255
    },

    [MAT_DIRT] = {
        mat = Material( "particle/particle_composite" ),
        r = 70, g = 60, b = 50,
        minSize = 20,
        maxSize = 30,
        lifetime = 1,
        alpha = 180
    },

    [MAT_SAND] = {
        mat = Material( "particle/particle_composite" ),
        r = 200, g = 170, b = 120,
        minSize = 20,
        maxSize = 60,
        lifetime = 1.5,
        alpha = 150
    },

    [MAT_SNOW] = {
        mat = Material( "particle/particle_composite" ),
        r = 200, g = 200, b = 200,
        minSize = 20,
        maxSize = 30,
        lifetime = 0.5,
        alpha = 100
    },

    [MAT_SLOSH] = {
        mat = Material( "effects/splash4" ),
        r = 200, g = 200, b = 200,
        minSize = 20,
        maxSize = 30,
        lifetime = 0.4,
        alpha = 100
    }
}

DEBRIS_FX[MAT_FOLIAGE] = DEBRIS_FX[MAT_GRASS]

local IsValid = IsValid
local DEFAULT_COLOR = Vector( 0, 0, 0 )

function EFFECT:Init( data )
    local origin = data:GetOrigin()
    local velocity = data:GetStart()
    local scale = data:GetScale()
    local surfaceId = data:GetSurfaceProp()

    local emitter = ParticleEmitter( origin, false )
    if not IsValid( emitter ) then return end

    local parent = data:GetEntity()
    local color = ( IsValid( parent ) and parent.GetTireSmokeColor ) and parent:GetTireSmokeColor() or DEFAULT_COLOR

    if DEBRIS_FX[surfaceId] then
        self:DoDebris( emitter, origin, velocity, DEBRIS_FX[surfaceId] )

    elseif scale > 0.2 then
        self:DoSmoke( emitter, origin, velocity, scale, color )
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end

local SMOKE_MAT = "particle/smokesprites_000"
local SMOKE_GRAVITY = Vector( 0, 0, 40 )

local RandomInt = math.random
local RandomFloat = math.Rand

-- TODO: Check if this is needed
function EFFECT:DoSmoke( emitter, origin, velocity, scale, color )
    local r, g, b = color:Unpack()

    r = r * 255
    g = g * 255
    b = b * 255
    scale = scale * scale

    for _ = 1, 5 do
        local p = emitter:Add( SMOKE_MAT .. RandomInt( 9 ), origin )
        if p then
            p:SetDieTime( RandomFloat( 2, 3 ) )
            p:SetStartAlpha( 50 )
            p:SetEndAlpha( 0 )
            p:SetStartSize( 15 + RandomInt( 10, 20 ) * scale )
            p:SetEndSize( 80 + RandomInt( 40, 80 ) * scale )
            p:SetRoll( RandomFloat( -1, 1 ) )

            p:SetAirResistance( 100 )
            p:SetGravity( SMOKE_GRAVITY * RandomFloat( 0.5, 1.1 ) )
            p:SetVelocity( velocity * 0.8 * RandomFloat( 0.9, 1.1 ) )
            p:SetColor( r, g, b )
            p:SetLighting( false )
        end
    end
end

local DEBRIS_GRAVITY = Vector( 0, 0, -30 )
local Clamp = math.Clamp

function EFFECT:DoDebris( emitter, origin, velocity, fx )
    local scale = ( velocity:Length() * 0.001 ) - 0.1
    if scale < 0 then return end

    scale = Clamp( scale, 0.5, 1 )

    for _ = 1, 5 do
        local p = emitter:Add( fx.mat, origin )
        if p then
            p:SetDieTime( fx.lifetime * RandomFloat( 0.8, 1.2 ) )
            p:SetStartAlpha( fx.alpha )
            p:SetEndAlpha( 0 )
            p:SetStartSize( fx.minSize * scale * RandomFloat( 0.9, 1.1 ) )
            p:SetEndSize( fx.maxSize * scale * RandomFloat( 0.8, 1.5 ) )
            p:SetRoll( RandomFloat( -1, 1 ) )

            p:SetAirResistance( 50 )
            p:SetGravity( DEBRIS_GRAVITY )
            p:SetVelocity( velocity * 0.8 * RandomFloat( 0.8, 1 ) * scale )
            p:SetColor( fx.r, fx.g, fx.b )
            p:SetLighting( false )
        end
    end
end

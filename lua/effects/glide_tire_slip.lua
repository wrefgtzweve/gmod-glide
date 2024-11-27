local DEBRIS_FX = {
    [MAT_GRASS] = {
        mat = Material( "particle/particle_debris_02" ),
        r = 255, g = 255, b = 255,
        minSize = 20,
        maxSize = 50,
        velocity = 120,
        lifetime = 0.8,
        alpha = 255
    },

    [MAT_DIRT] = {
        mat = Material( "particle/particle_composite" ),
        r = 70, g = 60, b = 50,
        minSize = 20,
        maxSize = 40,
        velocity = 120,
        lifetime = 0.5,
        alpha = 255
    },

    [MAT_SAND] = {
        mat = Material( "particle/particle_composite" ),
        r = 200, g = 170, b = 120,
        minSize = 20,
        maxSize = 50,
        velocity = 120,
        lifetime = 0.5,
        alpha = 200
    },

    [MAT_SNOW] = {
        mat = Material( "particle/particle_composite" ),
        r = 190, g = 190, b = 190,
        minSize = 20,
        maxSize = 40,
        velocity = 180,
        lifetime = 0.5,
        alpha = 150
    }
}

DEBRIS_FX[MAT_FOLIAGE] = DEBRIS_FX[MAT_GRASS]

local IsValid = IsValid
local DEFAULT_COLOR = Vector( 0, 0, 0 )

function EFFECT:Init( data )
    local origin = data:GetOrigin()
    local normal = data:GetNormal()
    local scale = data:GetScale()
    local surfaceId = data:GetSurfaceProp()

    local emitter = ParticleEmitter( origin, false )
    if not IsValid( emitter ) then return end

    local parent = data:GetEntity()
    local color = ( IsValid( parent ) and parent.GetTireSmokeColor ) and parent:GetTireSmokeColor() or DEFAULT_COLOR

    if DEBRIS_FX[surfaceId] then
        self:DoDebris( emitter, origin, normal, scale, DEBRIS_FX[surfaceId] )
    else
        self:DoSmoke( emitter, origin, normal, scale, color )
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end

local SMOKE_MAT = "particle/smokesprites_000"
local SMOKE_GRAVITY = Vector( 0, 0, 60 )

local RandomInt = math.random
local RandomFloat = math.Rand

function EFFECT:DoSmoke( emitter, origin, normal, scale, color )
    local r, g, b = color:Unpack()

    r = r * 255
    g = g * 255
    b = b * 255

    for _ = 1, 5 do
        local p = emitter:Add( SMOKE_MAT .. RandomInt( 9 ), origin )
        if p then
            p:SetDieTime( RandomInt( 2, 3 ) )
            p:SetStartAlpha( 50 )
            p:SetEndAlpha( 0 )
            p:SetStartSize( 5 + RandomInt( 10, 20 ) * scale )
            p:SetEndSize( 50 + RandomInt( 20, 80 ) * scale )
            p:SetRoll( RandomFloat( -1, 1 ) )

            p:SetAirResistance( 100 )
            p:SetGravity( SMOKE_GRAVITY * RandomFloat( 0.5, 1 ) )
            p:SetVelocity( normal * RandomInt( 100, 200 ) * scale )
            p:SetColor( r, g, b )
            p:SetLighting( false )
        end
    end
end

local DEBRIS_GRAVITY = Vector( 0, 0, -60 )

function EFFECT:DoDebris( emitter, origin, normal, scale, fx )
    normal = normal + Vector( 0, 0, 0.1 )

    for _ = 1, 10 do
        local p = emitter:Add( fx.mat, origin )
        if p then
            p:SetDieTime( fx.lifetime )
            p:SetStartAlpha( fx.alpha )

            p:SetEndAlpha( 0 )
            p:SetStartSize( fx.minSize * scale * RandomFloat( 0.9, 1.1 ) )
            p:SetEndSize( fx.maxSize * scale * RandomFloat( 0.9, 1.1 ) )
            p:SetRoll( RandomFloat( -1, 1 ) )

            p:SetAirResistance( 10 )
            p:SetGravity( DEBRIS_GRAVITY )
            p:SetVelocity( normal * fx.velocity * RandomFloat( 0.5, 1 ) * scale )
            p:SetColor( fx.r, fx.g, fx.b )
            p:SetLighting( false )
        end
    end
end

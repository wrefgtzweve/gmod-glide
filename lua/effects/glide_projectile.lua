local RandomVec = VectorRand
local RandomInt = math.random
local RandomFloat = math.Rand
local SMOKE_MATERIAL = "particle/smokesprites_000"

function EFFECT:Init( data )
    local origin = data:GetOrigin()
    local normal = data:GetNormal()
    local scale = data:GetScale()

    local emitter = ParticleEmitter( origin, false )
    if not IsValid( emitter ) then return end

    for i = 1, 10 do
        local p = emitter:Add( SMOKE_MATERIAL .. RandomInt( 9 ), origin + normal * i * 5 )

        if p then
            p:SetDieTime( RandomFloat( 0.5, 1.0 ) )
            p:SetStartAlpha( 60 )
            p:SetEndAlpha( 0 )
            p:SetStartSize( RandomFloat( 4, 10 ) * scale )
            p:SetEndSize( RandomFloat( 20, 50 ) * scale )
            p:SetRoll( RandomFloat( -1, 1 ) )

            p:SetAirResistance( 100 )
            p:SetVelocity( RandomVec() * RandomFloat( -100, 100 ) * scale )
            p:SetColor( 120, 120, 120 )
        end
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end

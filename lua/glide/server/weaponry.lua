local IsValid = IsValid

function Glide.CreateTurret( vehicle, offset, angles )
    local turret = ents.Create( "glide_vehicle_turret" )

    if not turret or not IsValid( turret ) then
        vehicle:Remove()
        error( "Failed to spawn turret! Vehicle removed!" )
        return
    end

    vehicle:DeleteOnRemove( turret )

    if vehicle.turretCount then
        vehicle.turretCount = vehicle.turretCount + 1
    end

    turret:SetParent( vehicle )
    turret:SetLocalPos( offset )
    turret:SetLocalAngles( angles )
    turret:Spawn()

    return turret
end

function Glide.FireMissile( pos, ang, attacker, parent, target )
    local missile = ents.Create( "glide_missile" )
    missile:SetPos( pos )
    missile:SetAngles( ang )
    missile:Spawn()
    missile:SetupMissile( attacker, parent )

    if IsValid( target ) then
        missile:SetTarget( target )
    end

    return missile
end

function Glide.FireProjectile( pos, ang, attacker, parent )
    local projectile = ents.Create( "glide_projectile" )
    projectile:SetPos( pos )
    projectile:SetAngles( ang )
    projectile:Spawn()
    projectile:SetupProjectile( attacker, parent )

    return projectile
end

do
    local RandomFloat = math.Rand
    local Effect = util.Effect
    local TraceLine = util.TraceLine
    local EffectData = EffectData

    local pos, ang
    local attacker, inflictor, length
    local damage, spread, explosionRadius

    function Glide.FireBullet( params, traceData )
        pos = params.pos
        ang = params.ang

        attacker = params.attacker
        inflictor = params.inflictor or attacker
        spread = params.spread or 0.3

        if params.isExplosive then
            length = params.length or 5000
            damage = params.damage or 25
            explosionRadius = params.explosionRadius or 180
        else
            length = params.length or 10000
            damage = params.damage or 20
        end

        ang[1] = ang[1] + RandomFloat( -spread, spread )
        ang[2] = ang[2] + RandomFloat( -spread, spread )

        local dir = ang:Forward()

        traceData = traceData or {}
        traceData.start = pos
        traceData.endpos = pos + dir * length

        local tr = TraceLine( traceData )

        if tr.Hit then
            length = length * tr.Fraction

            local waterTrace = TraceLine( {
                start = traceData.start,
                endpos = traceData.endpos,
                mask = MASK_WATER
            } )

            if waterTrace.Hit then
                local eff = EffectData()
                eff:SetOrigin( waterTrace.HitPos )
                eff:SetScale( 13 )

                if bit.band( waterTrace.Contents, CONTENTS_SLIME ) == 0 then
                    eff:SetFlags( 0 )
                end

                Effect( "watersplash", eff )
            end
        end

        if params.isExplosive then
            if tr.Hit and not tr.HitSky then
                Glide.CreateExplosion( inflictor, attacker, tr.HitPos, explosionRadius, damage, tr.HitNormal, Glide.EXPLOSION_TYPE.TURRET )
            end

        elseif IsValid( inflictor ) then
            inflictor:FireBullets( {
                Attacker = attacker,
                Damage = damage,
                Force = damage * 2,
                Distance = length,
                Dir = dir,
                Src = pos,
                HullSize = 2,
                Spread = Vector( 0.002, 0.002, 0 ),
                IgnoreEntity = inflictor,
                TracerName = "MuzzleFlash",
                AmmoType = "SMG1"
            } )
        end

        local eff = EffectData()
        eff:SetOrigin( pos )
        eff:SetStart( pos + dir * length )
        eff:SetScale( params.scale or 1 )
        eff:SetFlags( tr.Hit and 1 or 0 )
        eff:SetEntity( inflictor )

        local color = params.tracerColor

        if color then
            -- Use some unused EffectData fields for the RGB components
            eff:SetColor( 1 )
            eff:SetRadius( color.r )
            eff:SetHitBox( color.g )
            eff:SetMaterialIndex( color.b )
        else
            eff:SetColor( 0 )
        end

        Effect( "glide_tracer", eff )

        local shellDir = params.shellDirection

        if shellDir then
            eff = EffectData()
            eff:SetAngles( shellDir:Angle() )
            eff:SetOrigin( pos - dir * 30 )
            eff:SetEntity( inflictor )
            eff:SetMagnitude( 1 )
            eff:SetRadius( 5 )
            eff:SetScale( 1 )
            Effect( "RifleShellEject", eff )
        end
    end
end

do
    local BlastDamage = util.BlastDamage
    local GetNearbyPlayers = Glide.GetNearbyPlayers

    --- Utility function to create explosion sounds, particles and deal damage.
    function Glide.CreateExplosion( inflictor, attacker, origin, radius, damage, normal, explosionType )
        if not IsValid( inflictor ) then return end

        if not IsValid( attacker ) then
            attacker = inflictor
        end

        -- Deal damage
        BlastDamage( inflictor, attacker, origin, radius, damage )

        -- Let nearby players handle sounds and effects client side
        local targets, count = GetNearbyPlayers( origin, Glide.MAX_EXPLOSION_DISTANCE )

        -- Always let the attacker see/hear it too, if they are a player
        if attacker:IsPlayer() then
            count = count + 1
            targets[count] = attacker
        end

        if count == 0 then return end

        Glide.StartCommand( Glide.CMD_CREATE_EXPLOSION, true )
        net.WriteVector( origin )
        net.WriteVector( normal )
        net.WriteUInt( explosionType, 2 )
        net.Send( targets )

        util.ScreenShake( origin, 5, 0.5, 1.0, 1500, true )
    end
end

do
    local TraceLine = util.TraceLine
    local emptyData = {}

    --- Returns true if the target entity can be locked on from a starting position and direction.
    --- Part of that includes checking if the dot product between `normal` and
    --- the direction towards the target entity is larger than `threshold`.
    --- `attacker` is the player who is trying to lock-on.
    --- Set `includeEmpty` to true to include vehicles without a driver.
    --- `traceData` is a optional, to make use of it's filtering options.
    function Glide.CanLockOnEntity( ent, origin, normal, threshold, maxDistance, attacker, includeEmpty, traceData )
        if not includeEmpty and ent.GetDriver and ent:GetDriver() == NULL then
            return false -- Don't lock on empty seats
        end

        maxDistance = maxDistance * maxDistance

        local entPos = ent:LocalToWorld( ent:OBBCenter() )
        local diff = entPos - origin

        -- Is the entity too far away?
        if diff:LengthSqr() > maxDistance then return false end
        if not ent:TestPVS( origin ) then return false end

        -- Is the entity within the field of view threshold?
        diff:Normalize()
        local dot = diff:Dot( normal )
        if dot < threshold then return false end

        -- Check if other addons don't want the `attacker` to lock on this entity
        if hook.Run( "Glide_CanLockOn", ent, attacker ) == false then
            return false
        end

        traceData = traceData or emptyData
        traceData.start = origin
        traceData.endpos = entPos

        local tr = TraceLine( traceData )
        if not tr.Hit then return true, dot end

        -- Check if the trace hit the target directly
        if tr.Entity == ent then return true, dot end

        -- Check if the trace hit the target's parent
        return IsValid( tr.Entity ) and ent:GetParent() == tr.Entity, dot
    end
end

local EntityMeta = FindMetaTable( "Entity" )
local getClass = EntityMeta.GetClass
local isVehicle = EntityMeta.IsVehicle
local getParent = EntityMeta.GetParent

local AllEnts = ents.Iterator
local CanLockOnEntity = Glide.CanLockOnEntity
local WHITELIST = Glide.LOCKON_WHITELIST

local function IsLockableEntity( ent, skipParentCheck )
    local class = getClass( ent )

    -- Checks for parent vehicles, like for example glide
    if class == "prop_vehicle_prisoner_pod" and not skipParentCheck then
        local parent = getParent( ent )

        -- Check directly against NULL as getParent returns a clean NULL object and it's faster than IsValid
        if parent ~= NULL then
            if IsLockableEntity( parent, true ) then
                return false
            end
            return true
        end
    end

    if WHITELIST[class] then
        return true
    end

    if isVehicle( ent ) then
        return true
    end

    if ent.BaseClass and WHITELIST[ent.BaseClass.ClassName] then
        return true
    end

    return false
end

--- Finds all entities that we can lock on with `Glide.CanLockOnEntity`,
--- then returns which one has the largest dot product between `normal` and the direction towards them.
function Glide.FindLockOnTarget( origin, normal, threshold, maxDistance, attacker, traceData, filter )
    local largestDot = 0
    local canLock, dot, target

    local includeEmpty = attacker:GetInfoNum( "glide_homing_launcher_lock_on_empty", 0 )
    includeEmpty = includeEmpty and includeEmpty > 0 -- Could be nil

    local ignore = {}

    for _, ent in ipairs( filter or {} ) do
        ignore[ent] = true
    end

    for _, e in AllEnts() do
        if e ~= attacker and not ignore[e] and IsLockableEntity( e ) then
            canLock, dot = CanLockOnEntity( e, origin, normal, threshold, maxDistance, attacker, includeEmpty, traceData )

            if canLock and dot > largestDot then
                largestDot = dot
                target = e
            end
        end
    end

    return target
end

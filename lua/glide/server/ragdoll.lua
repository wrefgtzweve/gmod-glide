local IsValid = IsValid

--- Returns a list of all bone positions/rotations from a player,
--- while making sure those are relative to the world even while inside a vehicle.
local function GetAllBones( ply )
    local veh = ply:GetVehicle()
    local rotation, upAxis

    if IsValid( veh ) then
        rotation = Angle( 0, 270, 0 )
        upAxis = veh:GetUp()
    end

    local max = ply:GetBoneCount() - 1
    local bones = {}
    local pos, ang

    for i = 0, max do
        pos, ang = ply:GetBonePosition( i )

        if pos then
            if rotation then
                pos = veh:WorldToLocal( pos )
                ang = veh:WorldToLocalAngles( ang )

                pos:Rotate( rotation )
                ang:RotateAroundAxis( upAxis, rotation[2] )

                pos = veh:LocalToWorld( pos )
                ang = veh:LocalToWorldAngles( ang )
            end

            bones[i] = { pos, ang }
        end
    end

    return bones
end

--- Apply bone positions obtained from the function above to a ragdoll.
local function PoseRagdollBones( ragdoll, bones, velocity )
    local max = ragdoll:GetPhysicsObjectCount() - 1
    local boneId, bone

    for i = 0, max do
        local phys = ragdoll:GetPhysicsObjectNum( i )

        if IsValid( phys ) then
            phys:SetDamping( 0.3, 10 )
            phys:Wake()

            boneId = ragdoll:TranslatePhysBoneToBone( i )

            if boneId and bones[boneId] then
                bone = bones[boneId]

                phys:SetPos( bone[1], true )
                phys:SetAngles( bone[2] )
            end

            phys:SetVelocity( velocity )
        end
    end
end

function Glide.RagdollPlayer( ply, velocity, unragdollTime )
    if ply.GlideRagdoll then return end

    local ragdoll = ents.Create( "prop_ragdoll" )
    if not IsValid( ragdoll ) then return end

    local bones = GetAllBones( ply )
    local bodygroups = {}

    for _, v in ipairs( ply:GetBodyGroups() ) do
        bodygroups[v.id] = ply:GetBodygroup( v.id )
    end

    ply.GlideRagdollStartPos = ply:GetPos()

    ragdoll:SetPos( ply.GlideRagdollStartPos )
    ragdoll:SetModel( ply:GetModel() )
    ragdoll:Spawn()
    ragdoll:Activate()
    ragdoll.IsGlideRagdoll = true
    ragdoll.GlidePlayer = ply
    ragdoll.GlideHealth = ply:Health()
    ragdoll.GlideGodMode = ply:HasGodMode()

    if ply:InVehicle() then
        ply:ExitVehicle()
    end

    PoseRagdollBones( ragdoll, bones, velocity )

    for id, submodel in ipairs( bodygroups ) do
        ragdoll:SetBodygroup( id, submodel )
    end

    ragdoll:SetSkin( ply:GetSkin() )

    local weapon = ply:GetActiveWeapon()

    if IsValid( weapon ) then
        ply:SetActiveWeapon( NULL )
    end

    ply:SetVelocity( Vector() )
    ply:Spectate( OBS_MODE_CHASE )
    ply:SpectateEntity( ragdoll )
    ply.GlideRagdoll = ragdoll

    if unragdollTime then
        timer.Create( "Glide_Ragdoll_" .. ply:EntIndex(), unragdollTime, 1, function()
            Glide.UnRagdollPlayer( ply )
        end )
    end
end

local TRACE_MINS = Vector( -16, -16, 0 )
local TRACE_MAXS = Vector( 16, 16, 50 )

function Glide.UnRagdollPlayer( ply )
    if not IsValid( ply ) then return end

    timer.Remove( "Glide_Ragdoll_" .. ply:EntIndex() )

    local ragdoll = ply.GlideRagdoll
    if not ragdoll then return end

    local pos = ply.GlideRagdollStartPos
    local yaw = ply:GetAngles()[2]
    local velocity = Vector()
    local health = 1
    local god = false

    if IsValid( ragdoll ) then
        health = ragdoll.GlideHealth
        velocity = ragdoll:GetVelocity()
        pos = ragdoll:GetPos()
        god = ragdoll.GlideGodMode

        ragdoll:Remove()
    end

    ply.GlideRagdoll = nil
    ply.GlideRagdollStartPos = nil
    ply:UnSpectate()

    if not ply:Alive() then return end

    -- Try to make sure the player won't spawn inside a wall
    local tr = util.TraceHull( {
        mins = TRACE_MINS,
        maxs = TRACE_MAXS,
        start = pos + Vector( 0, 0, 100 ),
        endpos = pos
    } )

    if tr.Hit and not tr.StartSolid then
        endPos = tr.HitPos
    end

    ply:Spawn()
    ply:SetPos( pos )
    ply:SetAngles( Angle( 0, yaw, 0 ) )
    ply:SetVelocity( velocity )
    ply:SetHealth( health )

    if god then
        ply:GodEnable()
    end
end

hook.Add( "CanTool", "Glide.BlockPlayerRagdolls", function( _, tr )
    if IsValid( tr.Entity ) and tr.Entity.IsGlideRagdoll then
        return false
    end
end )

hook.Add( "CanProperty", "Glide.BlockPlayerRagdolls", function( _, _, ent )
    if ent.IsGlideRagdoll then
        return false
    end
end )

hook.Add( "PlayerDeath", "Glide.CleanupPlayerRagdolls", function( victim )
    if victim.GlideRagdoll then
        Glide.UnRagdollPlayer( victim )
    end
end )

hook.Add( "PlayerDisconnected", "Glide.CleanupPlayerRagdolls", function( ply )
    if ply.GlideRagdoll then
        Glide.UnRagdollPlayer( ply )
    end
end )

hook.Add( "PreCleanupMap", "Glide.CleanupPlayerRagdolls", function()
    for _, ply in ipairs( player.GetAll() ) do
        Glide.UnRagdollPlayer( ply )
    end
end )

hook.Add( "EntityTakeDamage", "Glide.RagdollDamage", function( ent, dmginfo )
    if not ent.IsGlideRagdoll then return end
    if ent.GlideGodMode then return end

    local inflictor = dmginfo:GetInflictor()

    -- Don't let missiles deal crush damage
    if dmginfo:IsDamageType( 1 ) and IsValid( inflictor ) and inflictor:GetClass() == "glide_missile" then
        return
    end

    local damage = dmginfo:GetDamage()

    if dmginfo:IsDamageType( 1 ) then
        damage = damage * 0.1
    end

    damage = math.ceil( damage )

    local health = ent.GlideHealth - damage
    local ply = ent.GlidePlayer

    ent.GlideHealth = health

    if health < 1 and IsValid( ply ) then
        Glide.UnRagdollPlayer( ply )

        timer.Simple( 0.1, function()
            if IsValid( ply ) then
                ply:TakeDamage( 1, ply, ply )
            end
        end )
    end
end )

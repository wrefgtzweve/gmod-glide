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
    ragdoll.GlideArmor = ply:Armor()
    ragdoll.GlideGodMode = ply:HasGodMode()
    ragdoll.GlideModel = ply:GetModel()

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

local traceData = {
    mins = Vector( -16, -16, 0 ),
    maxs = Vector( 16, 16, 64 )
}

local function GetFreeSpace( origin, filter )
    traceData.filter = filter

    local offset = Vector( 0, 0, 20 )
    local rad, tr

    for ang = 0, 360, 30 do
        rad = math.rad( ang )

        offset[1] = math.cos( rad ) * 20
        offset[2] = math.sin( rad ) * 20

        traceData.start = origin + offset
        traceData.endpos = origin

        tr = util.TraceHull( traceData )

        if tr.Hit and not tr.StartSolid then
            return tr.HitPos
        end
    end

    return origin
end

function Glide.UnRagdollPlayer( ply )
    if not IsValid( ply ) then return end

    timer.Remove( "Glide_Ragdoll_" .. ply:EntIndex() )

    local ragdoll = ply.GlideRagdoll
    if not ragdoll then return end

    local pos = ply.GlideRagdollStartPos
    local yaw = ply:GetAngles()[2]
    local velocity = Vector()
    local health, armor = 1, 0
    local god, model = false, nil

    if IsValid( ragdoll ) then
        health = ragdoll.GlideHealth
        armor = ragdoll.GlideArmor
        velocity = ragdoll:GetVelocity()
        pos = ragdoll:GetPos()
        god = ragdoll.GlideGodMode
        model = ragdoll.GlideModel

        ragdoll:Remove()
    end

    ply.GlideRagdoll = nil
    ply.GlideRagdollStartPos = nil
    ply:UnSpectate()

    if not ply:Alive() then return end

    ply.GlideBlockLoadout = true
    ply:Spawn()
    ply:SetPos( GetFreeSpace( pos, ragdoll ) )
    ply:SetEyeAngles( Angle( 0, yaw, 0 ) )
    ply:SetVelocity( velocity )
    ply:SetHealth( health )
    ply:SetArmor( armor )
    ply.GlideBlockLoadout = nil

    if model then
        ply:SetModel( model )
    end

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
    if ent.GlideHealth < 1 then return end

    local ply = ent.GlidePlayer
    if not IsValid( ply ) then return end

    if dmginfo:IsDamageType( 1 ) then
        dmginfo:SetDamage( math.ceil( dmginfo:GetDamage() * 0.1 ) )
    end

    local ignore = hook.Run( "EntityTakeDamage", ply, dmginfo )
    if ignore then return end

    local damage = dmginfo:GetDamage()
    if damage < 1 then return end

    ent.GlideHealth = ent.GlideHealth - damage
    if ent.GlideHealth > 0 then return end

    Glide.UnRagdollPlayer( ply )
    ply:TakeDamageInfo( dmginfo )
end )

hook.Add( "CLoadoutCanGiveWeapons", "Glide.BlockRagdollLoadout", function( ply )
    if ply.GlideBlockLoadout then return false end
end )

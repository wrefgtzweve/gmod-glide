local IsValid = IsValid

local EntityMeta = FindMetaTable( "Entity" )
local getTable = EntityMeta.GetTable

hook.Add( "UpdateAnimation", "Glide.OverridePlayerAnim", function( ply )
    local vehicle = ply:GlideGetVehicle()
    if not IsValid( vehicle ) then return end
    if not vehicle.UpdatePlayerPoseParameters then return end

    local updated = vehicle:UpdatePlayerPoseParameters( ply )

    if updated then
        GAMEMODE:GrabEarAnimation( ply )

        if CLIENT then
            GAMEMODE:MouthMoveAnimation( ply )
        end

        return false
    end
end )

hook.Add( "CalcMainActivity", "Glide.OverridePlayerActivity", function( ply )
    local vehicle = ply:GlideGetVehicle()

    local vehTbl = getTable( vehicle )
    if not vehTbl then return end
    if not vehTbl.GetPlayerSitSequence then return end

    local plyTbl = getTable( ply )
    if plyTbl.m_bWasNoclipping then
        plyTbl.m_bWasNoclipping = nil
        ply:AnimResetGestureSlot( 6 ) -- GESTURE_SLOT_CUSTOM

        if CLIENT then
            ply:SetIK( true )
        end
    end

    local anim = vehicle:GetPlayerSitSequence( ply:GlideGetSeatIndex() )

    plyTbl.CalcIdeal = 47 -- ACT_STAND
    plyTbl.CalcSeqOverride = ply:LookupSequence( anim )

    -- Just because we aren't a driver doesn't mean the vehicle can't have a custom sequence.
    if anim == "sit" and ply ~= vehicle:GetDriver() and ply:GetAllowWeaponsInVehicle() then
        local activeWep = ply:GetActiveWeapon()

        if not IsValid( activeWep ) or activeWep == NULL then
            return plyTbl.CalcIdeal, plyTbl.CalcSeqOverride
        end

        local holdType = activeWep:GetHoldType()

        if holdType == "smg" then
            holdType = "smg1"
        end

        local sequenceID = ply:LookupSequence( string.format( sitFormat, holdType ) )

        if sequenceID ~= -1 then
            plyTbl.CalcIdeal = 1970 -- ACT_HL2MP_SIT
            plyTbl.CalcSeqOverride = sequenceID
        end
    end

    return plyTbl.CalcIdeal, plyTbl.CalcSeqOverride
end )

if not CLIENT then return end

function Glide.ApplyBoneManipulations( ply, pose )
    local max = ply:GetBoneCount() - 1
    local name

    for i = 0, max do
        name = ply:GetBoneName( i )

        if name and pose[name] then
            ply:ManipulateBoneAngles( i, pose[name], false )
        end
    end

    ply.GlideHasPose = true
end

function Glide.ResetBoneManipulations( ply )
    if not ply.GlideHasPose then return end

    local max = ply:GetBoneCount() - 1
    local zeroAng = Angle()

    for i = 0, max do
        ply:ManipulateBoneAngles( i, zeroAng, false )
    end

    ply.GlideHasPose = nil
end

local ApplyBoneManipulations = Glide.ApplyBoneManipulations

hook.Add( "PrePlayerDraw", "Glide.ManipulatePlayerBones", function( ply )
    local vehicle = ply:GetNWEntity( "GlideVehicle", NULL )

    if IsValid( vehicle ) then
        local seatIndex = ply:GetNWInt( "GlideSeatIndex", 1 )
        local pose = vehicle:GetSeatBoneManipulations( seatIndex )

        if pose then
            ApplyBoneManipulations( ply, pose )
        end

    elseif ply.GlideHasPose then
        Glide.ResetBoneManipulations( ply )
    end
end )

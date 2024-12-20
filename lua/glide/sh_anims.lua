local IsValid = IsValid

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
    if not IsValid( vehicle ) then return end

    if ply.m_bWasNoclipping then
        ply.m_bWasNoclipping = nil
        ply:AnimResetGestureSlot( 6 ) -- GESTURE_SLOT_CUSTOM

        if CLIENT then
            ply:SetIK( true )
        end
    end

    local anim = vehicle:GetPlayerSitSequence( ply:GlideGetSeatIndex() )

    ply.CalcIdeal = 47 -- ACT_STAND
    ply.CalcSeqOverride = ply:LookupSequence( anim )

    return ply.CalcIdeal, ply.CalcSeqOverride
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

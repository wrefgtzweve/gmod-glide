local PlayerMeta = FindMetaTable( "Player" )

function PlayerMeta:GlideGetVehicle()
    return self:GetNWEntity( "GlideVehicle", NULL )
end

function PlayerMeta:GlideGetSeatIndex()
    return self:GetNWEntity( "GlideSeatIndex", -1 )
end

if SERVER then
    local IsValid = IsValid
    local playerAngles = {}

    hook.Add( "SetupMove", "Glide.StoreViewAngles", function( ply, _, cmd )
        if ply.IsUsingGlideVehicle then
            playerAngles[ply] = cmd:GetViewAngles()
        end
    end )

    hook.Add( "PlayerDisconnected", "Glide.CleanupViewAngles", function( ply )
        playerAngles[ply] = nil
    end )

    local ZERO_ANG = Angle()

    --- Get the player's camera angles from their `CUserCmd`.
    function PlayerMeta:GlideGetCameraAngles()
        return playerAngles[self] or ZERO_ANG
    end

    local ZERO_VEC = Vector()
    local TraceLine = util.TraceLine

    --- Attempt to get where this player is aiming at
    --- while inside a Glide vehicle.
    function PlayerMeta:GlideGetAimPos()
        local vehicle = self:GlideGetVehicle()
        if not IsValid( vehicle ) then return ZERO_VEC end

        local fw = self:GlideGetCameraAngles():Forward()
        local startPos = self:EyePos()

        local tr = TraceLine( {
            start = startPos,
            endpos = startPos + fw * 50000,
            filter = { self, vehicle }
        } )

        return tr.HitPos
    end
end

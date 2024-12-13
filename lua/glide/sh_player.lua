local PlayerMeta = FindMetaTable( "Player" )

function PlayerMeta:GlideGetVehicle()
    return self:GetNWEntity( "GlideVehicle", NULL )
end

function PlayerMeta:GlideGetSeatIndex()
    return self:GetNWEntity( "GlideSeatIndex", -1 )
end

if SERVER then
    --- Get the player's Glide camera position.
    function PlayerMeta:GlideGetCameraPos()
        return self.GlideCam and self.GlideCam.origin or self:EyePos()
    end

    --- Get the player's Glide camera angles.
    function PlayerMeta:GlideGetCameraAngles()
        return self.GlideCam and self.GlideCam.angle or self:EyePos()
    end

    local TraceLine = util.TraceLine

    function PlayerMeta:GlideGetAimPos()
        local origin = self:GlideGetCameraPos()

        return TraceLine( {
            start = origin,
            endpos = origin + self:GlideGetCameraAngles():Forward() * 50000,
            filter = { self, self:GlideGetVehicle() }
        } ).HitPos
    end
end

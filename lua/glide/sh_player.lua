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
        local camPos = self:EyePos() -- Just in case GetInfoNum fails

        camPos[1] = self:GetInfoNum( "glide_cam_x", camPos[1] )
        camPos[2] = self:GetInfoNum( "glide_cam_y", camPos[2] )
        camPos[3] = self:GetInfoNum( "glide_cam_z", camPos[3] )

        return camPos
    end

    --- Get the player's Glide camera angles.
    function PlayerMeta:GlideGetCameraAngles()
        local camAng = self:EyeAngles() -- Just in case GetInfoNum fails

        camAng[1] = self:GetInfoNum( "glide_cam_pitch", camAng[1] )
        camAng[2] = self:GetInfoNum( "glide_cam_yaw", camAng[2] )
        camAng[3] = self:GetInfoNum( "glide_cam_roll", camAng[3] )

        return camAng
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

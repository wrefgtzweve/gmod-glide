local IsValid = IsValid

-- Once a player enters a Glide vehicle, setup network variables
-- and trigger the `Glide_OnEnterVehicle` hook.
hook.Add( "PlayerEnteredVehicle", "Glide.OnEnterSeat", function( ply, seat )
    if not IsValid( seat ) then return end

    -- Make sure this seat was created by Glide
    local seatIndex = seat.GlideSeatIndex
    if not seatIndex then return end

    -- Is this seat's parent a Glide vehicle?
    local parent = seat:GetParent()
    if not IsValid( parent ) then return end
    if not parent.IsGlideVehicle then return end

    -- Holster held weapon
    local weapon = ply:GetActiveWeapon()

    if IsValid( weapon ) then
        ply.GlideLastWeaponClass = weapon:GetClass()
        ply:SetActiveWeapon( NULL )
    end

    -- Store some variables on this player
    ply.IsUsingGlideVehicle = true
    ply:SetNWInt( "GlideSeatIndex", seatIndex )
    ply:SetNWEntity( "GlideVehicle", parent )
    ply:DrawShadow( false )

    -- Enable vehicle input
    Glide.ActivateInput( ply, parent, seatIndex )

    hook.Run( "Glide_OnEnterVehicle", ply, parent, seatIndex )
end )

-- Once a player leaves a Glide vehicle, cleanup network variables
-- and trigger the `Glide_OnExitVehicle` hook.
hook.Add( "PlayerLeaveVehicle", "Glide.OnExitSeat", function( ply )
    if not ply.IsUsingGlideVehicle then return end

    local vehicle = ply:GlideGetVehicle()
    local seatIndex = ply:GlideGetSeatIndex()

    -- Disable vehicle input
    Glide.DeactivateInput( ply )

    -- Cleanup variables
    ply.IsUsingGlideVehicle = false
    ply:SetNWInt( "GlideSeatIndex", -1 )
    ply:SetNWEntity( "GlideVehicle", NULL )
    ply:DrawShadow( true )

    if IsValid( vehicle ) then
        vehicle:ResetInputs( seatIndex )

        ply:SetPos( vehicle:GetSeatExitPos( seatIndex ) )
        ply:SetVelocity( vehicle:GetPhysicsObject():GetVelocity() )
        ply:SetEyeAngles( Angle( 0, vehicle:GetAngles().y, 0 ) )
    end

    -- Restore previously held weapon
    local weaponClass = ply.GlideLastWeaponClass

    if weaponClass then
        ply.GlideLastWeaponClass = nil

        timer.Simple( 0, function()
            if IsValid( ply ) then ply:SelectWeapon( weaponClass ) end
        end )
    end

    hook.Run( "Glide_OnExitVehicle", ply, vehicle )
end )

-- Validate editable float variables and let the vehicle know they have changed.
hook.Add( "CanEditVariable", "Glide.ValidateEditVariables", function( ent, _, _, value, editor )
    if not ent.IsGlideVehicle then return end
    if not editor.min or not editor.max then return end

    value = tonumber( value )
    if not value then return false end

    if value < editor.min then return false end
    if value > editor.max then return false end

    ent.shouldUpdateWheelParams = true

    local phys = ent:GetPhysicsObject()

    if IsValid( phys ) then
        phys:Wake()
    end
end )

hook.Add( "EntityTakeDamage", "Glide.OverrideDamage", function( target, dmginfo )
    if dmginfo:IsDamageType( 1 ) then -- DMG_CRUSH
        local inflictor = dmginfo:GetInflictor()
        if not IsValid( inflictor ) then return end

        -- Set the vehicle's driver as the attacker 
        if inflictor.IsGlideVehicle then
            local driver = inflictor:GetDriver()

            if not IsValid( driver ) then
                driver = inflictor:GetCreator()
            end

            if IsValid( driver ) then
                dmginfo:SetAttacker( driver )
            end

            if target:IsPlayer() then
                Glide.PlaySoundSet( "Glide.Collision.AgainstPlayer", target )
            end

        -- Don't let missiles deal crush damage
        elseif inflictor:GetClass() == "glide_missile" then
            dmginfo:SetDamage( 0 )
        end
    end

    if not target:IsPlayer() then return end

    if dmginfo:IsDamageType( 64 ) then -- DMG_BLAST
        local vehicle = target:GlideGetVehicle()

        -- Don't damage players inside of Glide vehicles
        if IsValid( vehicle ) then
            dmginfo:SetDamage( 0 )
        end
    end
end, HOOK_LOW )

-- Mute the ringing sound effect while inside a Glide vehicle.
hook.Add( "OnDamagedByExplosion", "Glide.DisableRingingSound", function( _, dmginfo )
    local inflictor = dmginfo:GetInflictor()

    if IsValid( inflictor ) and ( inflictor.IsGlideVehicle or inflictor:GetClass() == "glide_missile" ) then
        return true
    end
end )

if not game.SinglePlayer() then return end

local function ResetVehicle( vehicle )
    vehicle:ResetInputs( 1 )
    vehicle:SetDriver( NULL )
    vehicle:TurnOff()

    -- Reset bone manipulations
    local pos = Vector()
    local ang = Angle()
    local scale = Vector( 1, 1, 1 )

    for i = 0, vehicle:GetBoneCount() - 1 do
        vehicle:ManipulateBoneAngles( i, ang )
        vehicle:ManipulateBonePosition( i, pos )
        vehicle:ManipulateBoneScale( i, scale )
    end

    -- Reset weapon timings
    if vehicle.weaponCount > 0 then
        for _, weapon in ipairs( vehicle.weapons ) do
            weapon.nextFire = 0
            weapon.nextReload = 0
        end
    end
end

local function ResetAll()
    -- Restore NW variables for all Glide seats
    for _, seat in ipairs( ents.FindByClass( "prop_vehicle_prisoner_pod" ) ) do
        local seatIndex = seat.GlideSeatIndex

        if seatIndex then
            seat:SetNWInt( "GlideSeatIndex", seatIndex )
            seat:SetMoveType( MOVETYPE_NONE )
            seat:SetNotSolid( true )
            seat:DrawShadow( false )
            seat:PhysicsDestroy()
        end
    end

    -- Reset all Glide vehicles
    local classes = {
        ["base_glide"] = true,
        ["base_glide_car"] = true,
        ["base_glide_tank"] = true,
        ["base_glide_aircraft"] = true,
        ["base_glide_heli"] = true,
        ["base_glide_plane"] = true,
        ["base_glide_motorcycle"] = true
    }

    for _, e in ents.Iterator() do
        if classes[e:GetClass()] or ( e.BaseClass and classes[e.BaseClass.ClassName] ) then
            ResetVehicle( e )
        end
    end

    -- Reset the player's current vehicle
    local ply = Entity( 1 )
    if not IsValid( ply ) then return end

    local seat = ply:GetVehicle()
    if not IsValid( seat ) then return end

    local seatIndex = seat.GlideSeatIndex
    if not seatIndex then return end

    local parent = seat:GetParent()
    if not IsValid( parent ) then return end
    if not parent.IsGlideVehicle then return end

    timer.Simple( 0, function()
        ply:ExitVehicle()

        if IsValid( seat ) then
            ply:EnterVehicle( seat )
        end
    end )
end

-- Restore state if the player was on a Glide vehicle during a Source Engine save or map transition.
hook.Add( "ClientSignOnStateChanged", "Glide.RestoreVehicle", function( _, _, newState )
    if newState == SIGNONSTATE_FULL then
        timer.Simple( 1, ResetAll )
    end
end )

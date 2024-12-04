local flares = Glide.flares or {}

Glide.flares = flares

function Glide.TrackFlare( flare )
    flares[#flares + 1] = flare
end

local IsValid = IsValid
local dist, closestDist, closestEnt

function Glide.GetClosestFlare( pos, radius )
    closestDist = radius * radius
    closestEnt = nil

    for _, ent in ipairs( flares ) do
        if IsValid( ent ) then
            dist = pos:DistToSqr( ent:GetPos() )

            if dist < closestDist then
                closestDist = dist
                closestEnt = ent
            end
        end
    end

    return closestEnt, closestDist
end

-- Periodically cleanup the flares table
local Remove = table.remove

timer.Create( "Glide.CleanupFlares", 1, 0, function()
    for i = #flares, 1, -1 do
        if not IsValid( flares[i] ) then
            Remove( flares, i )
        end
    end
end )

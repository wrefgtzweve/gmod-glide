local cache = {}

function Glide.GetCachedIcon( path )
    if cache[path] then
        return cache[path]
    end

    cache[path] = Material( path, "smooth" )

    return cache[path]
end

local ScrH = ScrH
local Floor = math.floor

local SetColor = surface.SetDrawColor
local SetMaterial = surface.SetMaterial
local DrawTexturedRectRotated = surface.DrawTexturedRectRotated

function Glide.DrawWeaponCrosshair( x, y, icon, size, color )
    size = Floor( ScrH() * size )

    if not cache[icon] then
        cache[icon] = Material( icon, "smooth" )
    end

    SetMaterial( cache[icon] )
    SetColor( color:Unpack() )
    DrawTexturedRectRotated( x, y, size, size, 0 )
end

local MAT_BACKGROUND = Material( "glide/weapon_name.png", "smooth" )

function Glide.DrawWeaponSelection( name, icon )
    local sw, sh = ScrW(), ScrH()
    local size = sh * 0.15
    local y = sh * 0.2

    SetMaterial( MAT_BACKGROUND )
    SetColor( 255, 255, 255 )
    DrawTexturedRectRotated( sw * 0.5, y, size, size, 0 )

    draw.SimpleText( name, "GlideSelectedWeapon", sw * 0.5, y + size * 0.06, color_white, 1 )

    if not cache[icon] then
        cache[icon] = Material( icon, "smooth" )
    end

    SetMaterial( cache[icon] )
    DrawTexturedRectRotated( sw * 0.5, y - size * 0.1, size * 0.3, size * 0.3, 0 )
end

local DrawRect = surface.DrawRect

function Glide.DrawHealthBar( x, y, w, h, health )
    SetColor( 20, 20, 20, 200 )
    DrawRect( x, y, w, h )

    x, y = x + 1, y + 1
    w, h = w - 2, h - 2

    SetColor( 255 * ( 1 - health ), 255 * health, 0 )
    DrawRect( x, y, w * health, h )
end

local DrawHealthBar = Glide.DrawHealthBar
local ICON_ENGINE = Glide.GetCachedIcon( "materials/glide/icons/cogs.png" )

local VEHICLE_ICONS = {
    [Glide.VEHICLE_TYPE.CAR] = Glide.GetCachedIcon( "materials/glide/icons/car.png" ),
    [Glide.VEHICLE_TYPE.MOTORCYCLE] = Glide.GetCachedIcon( "materials/glide/icons/motorcycle.png" ),
    [Glide.VEHICLE_TYPE.HELICOPTER] = Glide.GetCachedIcon( "materials/glide/icons/helicopter.png" ),
    [Glide.VEHICLE_TYPE.PLANE] = Glide.GetCachedIcon( "materials/glide/icons/plane.png" ),
    [Glide.VEHICLE_TYPE.TANK] = Glide.GetCachedIcon( "materials/glide/icons/tank.png" )
}

function Glide.DrawVehicleHealth( x, y, w, h, vehicleType, chassisHealth, engineHealth )
    local rowH = h * 0.5

    SetColor( 255, 255, 255, 255 )

    SetMaterial( VEHICLE_ICONS[vehicleType] or VEHICLE_ICONS[1] )
    DrawTexturedRectRotated( x + rowH * 0.5, y + rowH * 0.45, rowH, rowH, 0 )

    SetMaterial( ICON_ENGINE )
    DrawTexturedRectRotated( x + rowH * 0.5, y + rowH * 1.55, rowH, rowH, 0 )

    x = x + rowH * 1.2
    y = y + h * 0.1
    w = w - rowH * 1.2
    h = h * 0.5

    DrawHealthBar( x, y, w, h * 0.5, chassisHealth )
    DrawHealthBar( x, y + h, w, h * 0.5, engineHealth )
end

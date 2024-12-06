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

local DrawRoundedBox = draw.RoundedBoxEx
local GetCachedIcon = Glide.GetCachedIcon

local THEME_COLOR = Glide.THEME_COLOR
local BG_COLOR = Color( 20, 20, 20, 240 )
local FG_COLOR = Color( 0, 255, 0, 255 )

function Glide.DrawHealthBar( x, y, w, h, health, icon )
    icon = GetCachedIcon( icon or "materials/glide/icons/cogs.png" )

    local radius = h * 0.25

    THEME_COLOR.a = 255
    DrawRoundedBox( radius, x, y, h, h, THEME_COLOR, true, false, true, false )
    DrawRoundedBox( radius, x + h, y, w - h, h, BG_COLOR, false, true, false, true )

    SetMaterial( icon )
    SetColor( 255, 255, 255, 255 )
    DrawTexturedRectRotated( x + h * 0.5, y + h * 0.5, h, h, 0 )

    FG_COLOR.r = 255 * ( 1 - health )
    FG_COLOR.g = 255 * health

    x = x + h + 2
    y = y + 2
    w = w - h - 4
    h = h - 4

    DrawRoundedBox( radius, x, y, w * health, h, FG_COLOR, false, true, false, true )
end

local VEHICLE_ICONS = {
    [Glide.VEHICLE_TYPE.CAR] = "materials/glide/icons/car.png",
    [Glide.VEHICLE_TYPE.MOTORCYCLE] = "materials/glide/icons/motorcycle.png",
    [Glide.VEHICLE_TYPE.HELICOPTER] = "materials/glide/icons/helicopter.png",
    [Glide.VEHICLE_TYPE.PLANE] = "materials/glide/icons/plane.png",
    [Glide.VEHICLE_TYPE.TANK] = "materials/glide/icons/tank.png"
}

local DrawHealthBar = Glide.DrawHealthBar

function Glide.DrawVehicleHealth( x, y, w, h, vehicleType, chassisHealth, engineHealth )
    local colW = w * 0.49

    DrawHealthBar( x, y, colW, h, chassisHealth, VEHICLE_ICONS[vehicleType] or VEHICLE_ICONS[1] )
    DrawHealthBar( x + w - colW, y, colW, h, engineHealth )
end

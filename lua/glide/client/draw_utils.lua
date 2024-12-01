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

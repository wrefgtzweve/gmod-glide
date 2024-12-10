local TEXT_COLOR = Color( 255, 255, 255, 255 )
local BG_COLOR = Color( 20, 20, 20, 230 )

local Floor = math.floor
local Clamp = math.Clamp

local GetTextSize = surface.GetTextSize
local DrawRoundedBox = draw.RoundedBoxEx
local DrawSimpleText = draw.SimpleText

local DrawRect = surface.DrawRect
local SetColor = surface.SetDrawColor

local function DrawPlayerTag( ply, health, pos )
    pos = pos:ToScreen()

    local nick = ply:Nick()
    local screenH = ScrH()

    surface.SetFont( "GlideSelectedWeapon" )

    local w, h = GetTextSize( nick )
    local minW = Floor( screenH * 0.1 )
    local padding = math.floor( screenH * 0.004 )

    w = Clamp( w, minW, screenH ) + padding * 2
    h = h + padding * 2

    local x = pos.x - w * 0.5
    local y = pos.y - h * 1.5

    DrawRoundedBox( screenH * 0.005, x, y, w, h, BG_COLOR, true, true, false, false )
    DrawSimpleText( nick, "GlideSelectedWeapon", x + w * 0.5, y + h * 0.5, TEXT_COLOR, 1, 1 )

    y = y + h
    h = h * 0.25

    SetColor( 0, 0, 0, 255 )
    DrawRect( x, y, w, h )

    SetColor( 255 * ( 1 - health ), 255 * health, 0, 255 )
    DrawRect( x, y, w * health, h )
end

local IsValid = IsValid
local FrameTime = FrameTime
local LocalPlayer = LocalPlayer
local SetAlphaMultiplier = surface.SetAlphaMultiplier

local Camera = Glide.Camera
local lastTarget = NULL
local alpha = 0

hook.Add( "HUDDrawTargetID", "Glide.HUDDrawTargetID", function()
    local target = Camera.isActive and Camera.lastAimEntity or LocalPlayer():GetEyeTrace().Entity

    if IsValid( target ) and not target:IsWorld() then
        lastTarget = target
        alpha = 1
    end

    if not IsValid( lastTarget ) then
        alpha = 0
        return
    end

    alpha = alpha - FrameTime()

    if alpha < 0 then
        lastTarget = NULL
        return
    end

    SetAlphaMultiplier( alpha )

    if lastTarget.IsGlideVehicle then
        local health = lastTarget:GetChassisHealth() / lastTarget.MaxChassisHealth
        local driver = lastTarget:GetDriver()

        if IsValid( driver ) then
            local pos = lastTarget:GetPos()
            local maxs = lastTarget:OBBMaxs()

            pos[3] = pos[3] + maxs[3]

            DrawPlayerTag( driver, health, pos )
        end

    elseif lastTarget:IsPlayer() then
        DrawPlayerTag( lastTarget, Clamp( lastTarget:Health() / 100, 0, 1 ), lastTarget:EyePos() )
    end

    SetAlphaMultiplier( 1 )

    return false
end )

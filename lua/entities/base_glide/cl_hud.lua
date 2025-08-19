local IsValid = IsValid
local RealTime = RealTime
local LocalPlayer = LocalPlayer

function ENT:OnLockOnStateChange( _, _, state )
    if self:GetDriver() ~= LocalPlayer() then return end

    if self.lockOnSound then
        self.lockOnSound:Stop()
        self.lockOnSound = nil
    end

    if state > 0 then
        self.lockOnSound = CreateSound( self, state == 1 and "glide/weapons/lockstart.wav" or "glide/weapons/locktone.wav" )
        self.lockOnSound:SetSoundLevel( 90 )
        self.lockOnSound:PlayEx( 1.0, 98 )
    end
end

function ENT:OnDriverChange( _, _, _ )
    if self.lockOnSound then
        self.lockOnSound:Stop()
        self.lockOnSound = nil
    end

    self.weapons = {}
    self.weaponSlotIndex = 0
end

function ENT:OnSyncWeaponData()
    -- Read metadata
    local slotIndex = net.ReadUInt( 5 )
    local className = net.ReadString()

    -- If it does not exist, create a client-side instance of
    -- this weapon class on the new active slot index.
    local weapon = self.weapons[slotIndex]

    if not weapon then
        weapon = Glide.CreateVehicleWeapon( className )
        weapon.Vehicle = self
        weapon:Initialize()

        self.weapons[slotIndex] = weapon
    end

    -- Let the weapon class read custom data
    weapon.SlotIndex = slotIndex
    weapon:OnReadData()

    -- Check if the weapon index has changed
    if self.weaponSlotIndex ~= slotIndex then
        self.weaponSlotIndex = slotIndex

        self.weaponSwitchNotification = {
            time = RealTime() + 1.5,
            name = weapon.Name or "MISSING",
            icon = weapon.Icon or "glide/aim_dot.png"
        }

        EmitSound( "glide/ui/hud_switch.wav", Vector(), -2, nil, 1.0, nil, nil, 100 )
    end
end

local Config = Glide.Config
local DrawWeaponSelection = Glide.DrawWeaponSelection

function ENT:DrawVehicleHUD( screenW, screenH )
    local playerListWidth = 0

    if Config.showPassengerList and hook.Run( "Glide_CanDrawHUDSeats", self ) ~= false then
        playerListWidth = self:DrawPlayerListHUD( screenW, screenH )
    end

    -- Draw weapon switch notification
    if self.weaponSwitchNotification then
        local notif = self.weaponSwitchNotification

        DrawWeaponSelection( notif.name, notif.icon )

        if RealTime() > notif.time then
            self.weaponSwitchNotification = nil
        end
    end

    -- Let the weapon class draw it's own HUD
    local weapon = self.weapons[self.weaponSlotIndex]

    if weapon then
        weapon:DrawHUD( screenW, screenH )
    end

    return playerListWidth
end

local FrameTime = FrameTime
local LocalPlayer = LocalPlayer

local Floor = math.floor
local ExpDecay = Glide.ExpDecay

local SetColor = surface.SetDrawColor
local DrawRect = surface.DrawRect
local DrawSimpleText = draw.SimpleText

local colors = {
    bgAlpha = 255,
    seat = Color( 255, 255, 255 ),
    nick = Color( 240, 240, 240 ),
    accent = Glide.THEME_COLOR
}

local expanded = 0
local expandTimer = 0

function ENT:DrawPlayerListHUD( screenW, screenH )
    local seats = self.seats
    if not seats then return 0 end

    local t = RealTime()
    local localPly = LocalPlayer()

    expanded = ExpDecay( expanded, t > expandTimer and 0 or 1, 6, FrameTime() )

    colors.bgAlpha = 180 + 40 * expanded
    colors.nick.a = 255 * ( expanded - 0.5 ) * 2
    colors.accent.a = 150 + 40 * expanded

    local margin = Floor( screenH * 0.03 )
    local padding = Floor( screenH * 0.006 )
    local spacing = Floor( screenH * 0.004 )
    local w, h = screenH * 0.3, Floor( screenH * 0.03 )

    w = Floor( ( w * 0.15 ) + ( w * 0.85 * expanded ) )

    local x = screenW - w
    local y = screenH - margin - h

    local nickOffset = w - padding
    local lastNick = self.lastNick
    local count = #seats
    local driver, nick

    for i = count, 1, -1 do
        driver = IsValid( seats[i] ) and seats[i]:GetDriver()
        nick = IsValid( driver ) and driver:Nick() or "#glide.hud.empty"

        if lastNick[i] ~= nick then
            lastNick[i] = nick
            expandTimer = t + 4
        end

        if nick:len() > 25 then
            nick = nick:sub( 1, 22 ) .. "..."
        end

        SetColor( 30, 30, 30, colors.bgAlpha )
        DrawRect( x, y, w, h )

        if driver == localPly then
            SetColor( colors.accent:Unpack() )
            DrawRect( x + 1, y + 1, w - 2, h - 2 )
        end

        DrawSimpleText( "#" .. i, "GlideHUD", x + padding, y + h * 0.5, colors.seat, 0, 1 )

        if expanded > 0.5 then
            DrawSimpleText( nick, "GlideHUD", x + nickOffset, y + h * 0.5, colors.nick, 2, 1 )
        end

        y = y - h - spacing
    end

    return w
end

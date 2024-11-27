CreateConVar( "glide_input_pitch", "0", FCVAR_USERINFO + FCVAR_UNREGISTERED, "Transmit this pitch input to the server.", -1, 1 )
CreateConVar( "glide_input_roll", "0", FCVAR_USERINFO + FCVAR_UNREGISTERED, "Transmit this roll input to the server.", -1, 1 )

local MouseInput = Glide.MouseInput or {}

Glide.MouseInput = MouseInput

hook.Add( "Glide_OnLocalEnterVehicle", "Glide.ActivateMouseInput", function()
    MouseInput:Activate()
end )

hook.Add( "Glide_OnLocalExitVehicle", "Glide.DeactivateMouseInput", function()
    MouseInput:Deactivate()
end )

local Config = Glide.Config

function MouseInput:Activate()
    local vehicle = Glide.currentVehicle

    -- Only activate mouse input while being a aircraft pilot with direct mouse input enabled
    if
        not IsValid( vehicle ) or
        not Glide.IsAircraft( vehicle ) or
        Glide.currentSeatIndex > 1 or
        Config.mouseFlyMode ~= Glide.MOUSE_FLY_MODE.DIRECT
    then
        self:Deactivate()

        return
    end

    self.mouse = { 0, 0 }
    self.sensitivity = { 0, 0 }
    self.freeLook = false
    self:Reset()

    self.cvarPitch = GetConVar( "glide_input_pitch" )
    self.cvarRoll = GetConVar( "glide_input_roll" )

    hook.Add( "InputMouseApply", "Glide.UpdateMouseInput", function( _, x, y )
        self:InputMouseApply( x, y )
    end )

    hook.Add( "Think", "Glide.UpdateMouseInput", function()
        self:Think()
    end )

    hook.Add( "HUDPaint", "Glide.DrawMouseInput", function()
        self:DrawHUD()
    end )
end

function MouseInput:Deactivate()
    hook.Remove( "InputMouseApply", "Glide.UpdateMouseInput" )
    hook.Remove( "Think", "Glide.UpdateMouseInput" )
    hook.Remove( "HUDPaint", "Glide.DrawMouseInput" )
end

function MouseInput:Reset()
    self.pitch = 0
    self.roll = 0

    if not self.cvarPitch then return end

    self.cvarPitch:SetFloat( self.pitch )
    self.cvarRoll:SetFloat( self.roll )
end

local Clamp = math.Clamp

function MouseInput:InputMouseApply( x, y )
    if self.freeLook then return end

    local mouse = self.mouse

    mouse[1] = Config.mouseInvertX and -x or x
    mouse[2] = Config.mouseInvertY and -y or y

    local sensitivity = self.sensitivity

    sensitivity[1] = Config.mouseSensitivityX
    sensitivity[2] = Config.mouseSensitivityY

    local pitch = mouse[Config.pitchMouseAxis] * sensitivity[Config.pitchMouseAxis] * 0.01
    local roll = mouse[Config.rollMouseAxis] * sensitivity[Config.rollMouseAxis] * 0.01

    self.pitch = Clamp( self.pitch - pitch, -1, 1 )
    self.roll = Clamp( self.roll + roll, -1, 1 )

    self.cvarPitch:SetFloat( self.pitch )
    self.cvarRoll:SetFloat( self.roll )
end

local Abs = math.abs
local Approach = math.Approach

function MouseInput:Think()
    self.freeLook = input.IsKeyDown( Config.binds.free_look )

    if self.freeLook then
        self:Reset()
        return
    end

    local dt = FrameTime()
    local deadzone = Config.mouseDeadzone

    if Abs( self.pitch ) < deadzone then
        self.pitch = Approach( self.pitch, 0, dt )
    end

    if Abs( self.roll ) < deadzone then
        self.roll = Approach( self.roll, 0, dt )
    end
end

local ScrW, ScrH = ScrW, ScrH
local SetColor = surface.SetDrawColor
local SetMaterial = surface.SetMaterial

local DrawRect = surface.DrawRect
local DrawTexturedRectRotated = surface.DrawTexturedRectRotated

local MAT_BACKGROUND = Material( "glide/mouse_area.png", "smooth" )
local MAT_JOYSTICK = Material( "glide/mouse_joystick.png", "smooth" )

function MouseInput:DrawHUD()
    if not Config.mouseShow then return end
    if self.freeLook then return end

    local sw, sh = ScrW(), ScrH()
    local size = sh * 0.1

    local x = sw * 0.5
    local y = sh * 0.9

    SetColor( 50, 50, 50, 180 )

    local deadzoneSize = size * Config.mouseDeadzone

    DrawRect( x - size * 0.5, y - deadzoneSize * 0.5, size, deadzoneSize )
    DrawRect( x - deadzoneSize * 0.5, y - size * 0.5, deadzoneSize, size )

    SetColor( 255, 255, 255, 255 )
    SetMaterial( MAT_BACKGROUND )
    DrawTexturedRectRotated( x, y, size, size, 0 )

    size = size * 0.25

    SetMaterial( MAT_JOYSTICK )
    DrawTexturedRectRotated( x + self.roll * size * 2, y - self.pitch * size * 2, size, size, 0 )
end

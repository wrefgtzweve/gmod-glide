local Config = Glide.Config or {}

Glide.Config = Config

--- Reset settings to their default values.
function Config:Reset()
    -- Audio settings
    self.carVolume = 1.0
    self.aircraftVolume = 1.0
    self.explosionVolume = 1.0
    self.windVolume = 0.7
    self.vcVolume = 0.4

    -- Camera settings
    self.lookSensitivity = 1.0
    self.cameraInvertX = false
    self.cameraInvertY = false

    self.cameraDistance = 1.0
    self.cameraHeight = 1.0
    self.cameraFOVInternal = 75
    self.cameraFOVExternal = 75

    self.enableAutoCenter = true
    self.autoCenterDelay = 1.5

    -- Mouse settings
    self.mouseFlyMode = Glide.MOUSE_FLY_MODE.AIM
    self.mouseSensitivityX = 1.0
    self.mouseSensitivityY = 1.0
    self.mouseInvertX = false
    self.mouseInvertY = false

    self.pitchMouseAxis = 2 -- Y
    self.rollMouseAxis = 1 -- X
    self.mouseDeadzone = 0.2
    self.mouseShow = true

    -- Misc. settings
    self.autoHeadlightOn = true
    self.autoHeadlightOff = true
    self.headlightShadows = true
    self.enableTips = true
end

--- Reset binds to their default keys.
function Config:ResetBinds()
    -- Action-key dictionary, aka. button binds
    self.binds = {}
    self.manualGearShifting = false

    -- General inputs
    self:SetActionKey( "switch_weapon", KEY_R )
    self:SetActionKey( "attack", KEY_SPACE )
    self:SetActionKey( "attack_alt", MOUSE_LEFT )

    -- Car inputs
    self:SetActionKey( "steer_left", KEY_A )
    self:SetActionKey( "steer_right", KEY_D )
    self:SetActionKey( "accelerate", KEY_W )
    self:SetActionKey( "brake", KEY_S )
    self:SetActionKey( "handbrake", KEY_SPACE )
    self:SetActionKey( "horn", KEY_R )
    self:SetActionKey( "headlights", KEY_H )
    self:SetActionKey( "reduce_throttle", KEY_LSHIFT )

    self:SetActionKey( "shift_up", KEY_F )
    self:SetActionKey( "shift_down", KEY_G )
    self:SetActionKey( "shift_neutral", KEY_N )

    -- Airborne car/bike controls
    self:SetActionKey( "lean_forward", KEY_UP )
    self:SetActionKey( "lean_back", KEY_DOWN )

    -- Aircraft inputs
    self:SetActionKey( "free_look", KEY_LALT )
    self:SetActionKey( "landing_gear", KEY_G )
    self:SetActionKey( "pitch_up", KEY_DOWN )
    self:SetActionKey( "pitch_down", KEY_UP )
    self:SetActionKey( "roll_left", KEY_LEFT )
    self:SetActionKey( "roll_right", KEY_RIGHT )
    self:SetActionKey( "rudder_left", KEY_A )
    self:SetActionKey( "rudder_right", KEY_D )
    self:SetActionKey( "throttle_up", KEY_W )
    self:SetActionKey( "throttle_down", KEY_S )
end

--- Set which key triggers an action.
function Config:SetActionKey( action, button )
    self.binds[action] = button
end

--- Save settings to disk.
function Config:Save( immediate )
    timer.Remove( "Glide.SaveConfig" )

    if not immediate then
        -- Don't spam when this function gets called in quick succession
        timer.Create( "Glide.SaveConfig", 1, 1, function()
            self:Save( true )
        end )

        return
    end

    local data = Glide.ToJSON( {
        -- Audio settings
        carVolume = self.carVolume,
        aircraftVolume = self.aircraftVolume,
        explosionVolume = self.explosionVolume,
        windVolume = self.windVolume,
        vcVolume = self.vcVolume,

        -- Camera settings
        lookSensitivity = self.lookSensitivity,
        cameraInvertX = self.cameraInvertX,
        cameraInvertY = self.cameraInvertY,

        cameraDistance = self.cameraDistance,
        cameraHeight = self.cameraHeight,
        cameraFOVInternal = self.cameraFOVInternal,
        cameraFOVExternal = self.cameraFOVExternal,

        enableAutoCenter = self.enableAutoCenter,
        autoCenterDelay = self.autoCenterDelay,

        -- Mouse settings
        mouseFlyMode = self.mouseFlyMode,
        mouseSensitivityX = self.mouseSensitivityX,
        mouseSensitivityY = self.mouseSensitivityY,
        mouseInvertX = self.mouseInvertX,
        mouseInvertY = self.mouseInvertY,

        pitchMouseAxis = self.pitchMouseAxis,
        rollMouseAxis = self.rollMouseAxis,
        mouseDeadzone = self.mouseDeadzone,
        mouseShow = self.mouseShow,

        -- Misc. settings
        autoHeadlightOn = self.autoHeadlightOn,
        autoHeadlightOff = self.autoHeadlightOff,
        headlightShadows = self.headlightShadows,
        enableTips = self.enableTips,

        -- Action-key dictionary
        binds = self.binds,
        manualGearShifting = self.manualGearShifting
    }, true )

    Glide.SaveDataFile( "glide.json", data )
end

--- Load settings from disk.
function Config:Load()
    self:Reset()
    self:ResetBinds()

    local data = Glide.FromJSON( Glide.LoadDataFile( "glide.json" ) )
    local SetNumber = Glide.SetNumber

    local LoadBool = function( k, default )
        self[k] = Either( data[k] == nil, default, data[k] == true )
    end

    -- Audio settings
    SetNumber( self, "carVolume", data.carVolume, 0, 1, self.carVolume )
    SetNumber( self, "aircraftVolume", data.aircraftVolume, 0, 1, self.aircraftVolume )
    SetNumber( self, "explosionVolume", data.explosionVolume, 0, 1, self.explosionVolume )
    SetNumber( self, "windVolume", data.windVolume, 0, 1, self.windVolume )
    SetNumber( self, "vcVolume", data.vcVolume, 0, 1, self.vcVolume )

    -- Camera settings
    SetNumber( self, "lookSensitivity", data.lookSensitivity, 0.01, 5, self.lookSensitivity )
    LoadBool( "cameraInvertX", false )
    LoadBool( "cameraInvertY", false )

    SetNumber( self, "cameraDistance", data.cameraDistance, 0.5, 3, self.cameraDistance )
    SetNumber( self, "cameraHeight", data.cameraHeight, 0.25, 2, self.cameraHeight )
    SetNumber( self, "cameraFOVInternal", data.cameraFOVInternal, 30, 100, self.cameraFOVInternal )
    SetNumber( self, "cameraFOVExternal", data.cameraFOVExternal, 30, 100, self.cameraFOVExternal )

    LoadBool( "enableAutoCenter", true )
    SetNumber( self, "autoCenterDelay", data.autoCenterDelay, 0.1, 5, self.autoCenterDelay )

    -- Mouse settings
    self.mouseFlyMode = math.Round( Glide.ValidateNumber( data.mouseFlyMode, 0, 2, self.mouseFlyMode ) )
    LoadBool( "mouseInvertX", false )
    LoadBool( "mouseInvertY", false )

    SetNumber( self, "mouseSensitivityX", data.mouseSensitivityX, 0.01, 5, self.mouseSensitivityX )
    SetNumber( self, "mouseSensitivityY", data.mouseSensitivityY, 0.01, 5, self.mouseSensitivityY )
    SetNumber( self, "pitchMouseAxis", data.pitchMouseAxis, 1, 2, self.pitchMouseAxis )
    SetNumber( self, "rollMouseAxis", data.rollMouseAxis, 1, 2, self.rollMouseAxis )

    self.mouseDeadzone =  Glide.ValidateNumber( data.mouseDeadzone, 0, 1, self.mouseDeadzone )
    LoadBool( "mouseShow", true )

    -- Misc. settings
    LoadBool( "autoHeadlightOn", true )
    LoadBool( "autoHeadlightOff", false )
    LoadBool( "headlightShadows", true )
    LoadBool( "enableTips", true )

    -- Action-key dictionary
    LoadBool( "manualGearShifting", false )

    local binds = self.binds
    local loadedBinds = type( data.binds ) == "table" and data.binds or {}

    for action, button in pairs( binds ) do
        SetNumber( binds, action, loadedBinds[action], KEY_NONE, BUTTON_CODE_LAST, button )
    end
end

--- Send the current input settings to the server.
function Config:TransmitInputSettings( immediate )
    timer.Remove( "Glide.TransmitInputSettings" )

    if not immediate then
        -- Don't spam when this function gets called in quick succession
        timer.Create( "Glide.TransmitInputSettings", 1, 1, function()
            self:TransmitInputSettings( true )
        end )

        return
    end

    local data = {
        -- Mouse settings
        mouseFlyMode = self.mouseFlyMode,

        -- Keyboard settings
        manualGearShifting = self.manualGearShifting,

        -- Action-key dictionary
        binds = self.binds
    }

    Glide.StartCommand( Glide.CMD_INPUT_SETTINGS )
    Glide.WriteTable( data )
    net.SendToServer()
end

Config:Load()

hook.Add( "InitPostEntity", "Glide.TransmitInputSettings", function()
    Config:TransmitInputSettings()
end )

----------

concommand.Add(
    "glide_settings",
    function() Config:OpenFrame() end,
    nil,
    "Opens the Glide settings menu."
)

if engine.ActiveGamemode() == "sandbox" then
    list.Set(
        "DesktopWindows",
        "GlideDesktopIcon",
        {
            title = Glide.GetLanguageText( "settings_window" ),
            icon = "materials/glide/icons/car.png",
            init = function() Config:OpenFrame() end
        }
    )
end

function Config:CloseFrame()
    if IsValid( self.frame ) then
        self.frame:Close()
    end
end

function Config:OpenFrame()
    if IsValid( self.frame ) then
        self:CloseFrame()
        return
    end

    local theme = Glide.Theme

    local frame = vgui.Create( "Styled_TabbedFrame" )
    frame:SetIcon( "glide/icons/car.png" )
    frame:SetTitle( Glide.GetLanguageText( "settings_window" ) )
    frame:ApplyTheme( theme )
    frame:Center()
    frame:MakePopup()

    frame.OnClose = function()
        self.frame = nil
    end

    self.frame = frame

    local L = Glide.GetLanguageText

    ----- Camera settings -----

    local panelCamera = frame:AddTab( "icon16/camera.png", L"settings.camera" )

    theme:CreateHeader( panelCamera, L"settings.camera" )

    theme:CreateSlider( panelCamera, L"camera.sensitivity", self.lookSensitivity, 0.01, 5, 2, function( value )
        self.lookSensitivity = value
        self:Save()
    end )

    theme:CreateToggleButton( panelCamera, L"camera.invert_x", self.cameraInvertX, function( value )
        self.cameraInvertX = value
        self:Save()
    end )

    theme:CreateToggleButton( panelCamera, L"camera.invert_y", self.cameraInvertY, function( value )
        self.cameraInvertY = value
        self:Save()
    end )

    theme:CreateSlider( panelCamera, L"camera.distance", self.cameraDistance, 0.5, 3, 2, function( value )
        self.cameraDistance = value
        self:Save()
    end )

    theme:CreateSlider( panelCamera, L"camera.height", self.cameraHeight, 0.25, 2, 2, function( value )
        self.cameraHeight = value
        self:Save()
    end )

    theme:CreateSlider( panelCamera, L"camera.fov_internal", self.cameraFOVInternal, 30, 100, 0, function( value )
        self.cameraFOVInternal = value
        self:Save()

        if Glide.Camera.isActive then
            Glide.Camera:SetFirstPerson( true )
        end
    end )

    theme:CreateSlider( panelCamera, L"camera.fov_external", self.cameraFOVExternal, 30, 100, 0, function( value )
        self.cameraFOVExternal = value
        self:Save()

        if Glide.Camera.isActive then
            Glide.Camera:SetFirstPerson( false )
        end
    end )

    theme:CreateToggleButton( panelCamera, L"camera.autocenter", self.enableAutoCenter, function( value )
        self.enableAutoCenter = value
        self:Save()
    end )

    theme:CreateSlider( panelCamera, L"camera.autocenter_delay", self.autoCenterDelay, 0.1, 5, 2, function( value )
        self.autoCenterDelay = value
        self:Save()
    end )

    ----- Mouse settings -----

    local panelMouse = frame:AddTab( "icon16/mouse.png", L"settings.mouse" )

    theme:CreateHeader( panelMouse, L"settings.mouse" )

    local mouseModeOptions = {
        L"mouse.mode_aim",
        L"mouse.mode_direct",
        L"mouse.mode_camera"
    }

    local mouseAxisOptions = {
        L"mouse.x",
        L"mouse.y"
    }

    local SetupMouseModeSettings

    theme:CreateComboBox( panelMouse, L"mouse.flying_mode", mouseModeOptions, self.mouseFlyMode + 1, function( value )
        self.mouseFlyMode = value - 1
        self:Save()
        self:TransmitInputSettings()

        SetupMouseModeSettings()
        Glide.MouseInput:Activate()
    end )

    local directMousePanel = vgui.Create( "DPanel", panelMouse )
    directMousePanel:SetPaintBackground( false )
    directMousePanel:Dock( TOP )

    directMousePanel.PerformLayout = function()
        if self.mouseFlyMode == Glide.MOUSE_FLY_MODE.DIRECT then
            directMousePanel:SizeToChildren( false, true )
        else
            directMousePanel:SetTall( 1 )
        end
    end

    SetupMouseModeSettings = function()
        for _, p in pairs( directMousePanel:GetChildren() ) do
            p:Remove()
        end

        if self.mouseFlyMode ~= Glide.MOUSE_FLY_MODE.DIRECT then return end

        theme:CreateComboBox( directMousePanel, L"mouse.pitch_axis", mouseAxisOptions, self.pitchMouseAxis, function( value )
            self.pitchMouseAxis = value
            self:Save()
        end )

        theme:CreateComboBox( directMousePanel, L"mouse.roll_axis", mouseAxisOptions, self.rollMouseAxis, function( value )
            self.rollMouseAxis = value
            self:Save()
        end )

        theme:CreateToggleButton( directMousePanel, L"mouse.invert_x", self.mouseInvertX, function( value )
            self.mouseInvertX = value
            self:Save()
        end )

        theme:CreateToggleButton( directMousePanel, L"mouse.invert_y", self.mouseInvertY, function( value )
            self.mouseInvertY = value
            self:Save()
        end )

        theme:CreateSlider( directMousePanel, L"mouse.sensitivity_x", self.mouseSensitivityX, 0.1, 5, 1, function( value )
            self.mouseSensitivityX = value
            self:Save()
        end )

        theme:CreateSlider( directMousePanel, L"mouse.sensitivity_y", self.mouseSensitivityY, 0.1, 5, 1, function( value )
            self.mouseSensitivityY = value
            self:Save()
        end )

        theme:CreateSlider( directMousePanel, L"mouse.deadzone", self.mouseDeadzone, 0, 1, 2, function( value )
            self.mouseDeadzone = value
            self:Save()
        end )

        theme:CreateToggleButton( directMousePanel, L"mouse.show_hud", self.mouseShow, function( value )
            self.mouseShow = value
            self:Save()
        end )
    end

    SetupMouseModeSettings()

    ----- Keyboard settings -----

    local SEAT_SWITCH_KEYS = {
        [KEY_1] = 1,
        [KEY_2] = 2,
        [KEY_3] = 3,
        [KEY_4] = 4,
        [KEY_5] = 5,
        [KEY_6] = 6,
        [KEY_7] = 7,
        [KEY_8] = 8,
        [KEY_9] = 9,
        [KEY_0] = 10
    }

    local CreateBinderButton = function( parent, text, actionId, defaultKey, callback )
        local binder = theme:CreateBinderButton( parent, text, defaultKey )

        function binder:OnChange( value )
            if self._ignoreChange then return end

            if SEAT_SWITCH_KEYS[value] then
                self._ignoreChange = true
                binder:SetValue( defaultKey )
                self._ignoreChange = nil

                local msg = Glide.GetLanguageText( "input.reserved_seat_key" ):format( input.GetKeyName( value ) )
                Derma_Message( msg, "#glide.input.invalid_bind", "#glide.ok" )
            else
                callback( actionId, value )
            end
        end
    end

    local panelKeyboard = frame:AddTab( "icon16/keyboard.png", L"settings.input" )

    local binds = self.binds

    local function OnChangeBind( action, key )
        binds[action] = key
        self:Save()
        self:TransmitInputSettings()
    end

    theme:CreateHeader( panelKeyboard, L"input.general_controls" )
    CreateBinderButton( panelKeyboard, L"input.switch_weapon", "switch_weapon", binds.switch_weapon, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.attack", "attack", binds.attack, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.attack_alt", "attack_alt", binds.attack_alt, OnChangeBind )

    theme:CreateHeader( panelKeyboard, L"input.car_controls" )
    CreateBinderButton( panelKeyboard, L"input.steer_left", "steer_left", binds.steer_left, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.steer_right", "steer_right", binds.steer_right, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.accelerate", "accelerate", binds.accelerate, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.brake", "brake", binds.brake, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.handbrake", "handbrake", binds.handbrake, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.horn", "horn", binds.horn, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.headlights", "headlights", binds.headlights, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.reduce_throttle", "reduce_throttle", binds.reduce_throttle, OnChangeBind )

    theme:CreateHeader( panelKeyboard, L"input.manual_shift" )
    theme:CreateToggleButton( panelKeyboard, L"input.manual_shift", self.manualGearShifting, function( value )
        self.manualGearShifting = value
        self:Save()
        self:TransmitInputSettings()
    end )

    CreateBinderButton( panelKeyboard, L"input.shift_up", "shift_up", binds.shift_up, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.shift_down", "shift_down", binds.shift_down, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.shift_neutral", "shift_neutral", binds.shift_neutral, OnChangeBind )

    theme:CreateHeader( panelKeyboard, L"input.air_car_controls" )
    CreateBinderButton( panelKeyboard, L"input.lean_forward", "lean_forward", binds.lean_forward, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.lean_back", "lean_back", binds.lean_back, OnChangeBind )

    theme:CreateHeader( panelKeyboard, L"input.aircraft_controls" )
    CreateBinderButton( panelKeyboard, L"input.free_look", "free_look", binds.free_look, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.landing_gear", "landing_gear", binds.landing_gear, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.pitch_up", "pitch_up", binds.pitch_up, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.pitch_down", "pitch_down", binds.pitch_down, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.roll_left", "roll_left", binds.roll_left, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.roll_right", "roll_right", binds.roll_right, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.rudder_left", "rudder_left", binds.rudder_left, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.rudder_right", "rudder_right", binds.rudder_right, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.throttle_up", "throttle_up", binds.throttle_up, OnChangeBind )
    CreateBinderButton( panelKeyboard, L"input.throttle_down", "throttle_down", binds.throttle_down, OnChangeBind )

    ----- Audio settings -----

    local panelAudio = frame:AddTab( "icon16/sound.png", L"settings.audio" )

    theme:CreateHeader( panelAudio, L"settings.audio" )

    theme:CreateSlider( panelAudio, L"audio.car_volume", self.carVolume, 0, 1, 1, function( value )
        self.carVolume = value
        self:Save()
    end )

    theme:CreateSlider( panelAudio, L"audio.aircraft_volume", self.aircraftVolume, 0, 1, 1, function( value )
        self.aircraftVolume = value
        self:Save()
    end )

    theme:CreateSlider( panelAudio, L"audio.explosion_volume", self.explosionVolume, 0, 1, 1, function( value )
        self.explosionVolume = value
        self:Save()
    end )

    theme:CreateSlider( panelAudio, L"audio.wind_volume", self.windVolume, 0, 1, 1, function( value )
        self.windVolume = value
        self:Save()
    end )

    theme:CreateSlider( panelAudio, L"audio.voice_chat_reduction", self.vcVolume, 0, 1, 1, function( value )
        self.vcVolume = value
        self:Save()
    end )

    ----- Misc -----

    local panelMisc = frame:AddTab( "icon16/cog.png", L"settings.misc" )

    theme:CreateHeader( panelMisc, L"settings.misc" )

    theme:CreateToggleButton( panelMisc, L"misc.auto_headlights_on", self.autoHeadlightOn, function( value )
        self.autoHeadlightOn = value
        self:Save()
    end )

    theme:CreateToggleButton( panelMisc, L"misc.auto_headlights_off", self.autoHeadlightOff, function( value )
        self.autoHeadlightOff = value
        self:Save()
    end )

    theme:CreateToggleButton( panelMisc, L"misc.headlight_shadows", self.headlightShadows, function( value )
        self.headlightShadows = value
        self:Save()
    end )

    theme:CreateToggleButton( panelMisc, L"misc.tips", self.enableTips, function( value )
        self.enableTips = value
        self:Save()
    end )

    theme:CreateHeader( panelMisc, L"settings.reset" )

    theme:CreateButton( panelMisc, L"misc.reset_binds", function()
        Derma_Query( L"misc.reset_binds_query", L"misc.reset_binds", L"yes", function()
            self:CloseFrame()
            self:ResetBinds()
            self:Save()
            self:TransmitInputSettings()

            timer.Simple( 1, function()
                self:OpenFrame()
                self.frame:SetActiveTabByIndex( 5 )
            end )
        end, L"no" )
    end )

    theme:CreateButton( panelMisc, L"misc.reset_settings", function()
        Derma_Query( L"misc.reset_settings_query", L"misc.reset_settings", L"yes", function()
            self:CloseFrame()
            self:Reset()
            self:Save()
            self:TransmitInputSettings()

            timer.Simple( 1, function()
                self:OpenFrame()
                self.frame:SetActiveTabByIndex( 5 )
            end )
        end, L"no" )
    end )
end

local FrameTime = FrameTime
local Approach = math.Approach

local glideVolume = 1

hook.Add( "Tick", "Glide.CheckVoiceActivity", function()
    local players = player.GetAll()
    local ply, isAnyoneTalking = nil, false

    for i = 1, #players do
        ply = players[i]

        if ply:IsVoiceAudible() and ply:VoiceVolume() > 0.01 then
            isAnyoneTalking = true
            break
        end
    end

    glideVolume = Approach(
        glideVolume,
        isAnyoneTalking and Config.vcVolume or 1,
        FrameTime() * ( isAnyoneTalking and 10 or 2 )
    )
end )

-- Calculate the volume multiplier for a specific audio type,
-- depending on settings and how loud the voice chat is.
--
-- audioType must be one of these:
-- "carVolume", "aircraftVolume", "explosionVolume", "windVolume"
function Config.GetVolume( audioType )
    return Config[audioType] * glideVolume
end

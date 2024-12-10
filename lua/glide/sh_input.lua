--[[
    Categorize and enumerate input actions.

    Each category contains a key-value pairs of
    action names and the default key that triggers them.
]]

local InputCategories = Glide.InputCategories or {}

Glide.InputCategories = InputCategories

-- Inputs that apply to all vehicle types
InputCategories["general_controls"] = {
    ["switch_weapon"] = KEY_R
}

-- Inputs that only apply to land vehicle types
InputCategories["land_controls"] = {
    ["attack"] = MOUSE_LEFT,

    ["steer_left"] = KEY_A,
    ["steer_right"] = KEY_D,
    ["accelerate"] = KEY_W,
    ["brake"] = KEY_S,
    ["handbrake"] = KEY_SPACE,

    ["horn"] = KEY_R,
    ["headlights"] = KEY_H,
    ["reduce_throttle"] = KEY_LSHIFT,
    ["lean_forward"] = KEY_UP,
    ["lean_back"] = KEY_DOWN,

    ["shift_up"] = KEY_F,
    ["shift_down"] = KEY_G,
    ["shift_neutral"] = KEY_N
}

-- Inputs that only apply to aicraft vehicle types
InputCategories["aircraft_controls"] = {
    ["attack"] = MOUSE_LEFT,
    ["attack_alt"] = KEY_SPACE,

    ["free_look"] = KEY_LALT,
    ["landing_gear"] = KEY_G,
    ["countermeasures"] = KEY_F,

    ["pitch_up"] = KEY_DOWN,
    ["pitch_down"] = KEY_UP,
    ["yaw_left"] = KEY_A,
    ["yaw_right"] = KEY_D,
    ["roll_left"] = KEY_LEFT,
    ["roll_right"] = KEY_RIGHT,
    ["throttle_up"] = KEY_W,
    ["throttle_down"] = KEY_S
}

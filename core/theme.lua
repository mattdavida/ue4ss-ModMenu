--[[
  ModMenu.core.theme — author-facing color presets.

  Init({ theme = "light" | "dark", colors = { panelBg = { R,G,B,A }, ... } }).
  light = current ModMenu look (dark panel, light fields).
  dark  = charcoal panel, dark fields, teal/gold accents.
  Not a player setting — hosts pick a preset (and optional overrides) at Init.
]]

local M = {}

local KEYS = {
    "panelBg",
    "panelBorder",
    "textPrimary",
    "textMuted",
    "textAccent",
    "textStatus",
    "buttonBg",
    "buttonText",
    "buttonBgPrimary",
    "buttonTextPrimary",
    "buttonBgSecondary",
    "buttonTextSecondary",
    "buttonBgSuccess",
    "buttonTextSuccess",
    "buttonBgDanger",
    "buttonTextDanger",
    "buttonBgWarning",
    "buttonTextWarning",
    "buttonBgInfo",
    "buttonTextInfo",
    "buttonBgActive",
    "buttonTextActive",
    "buttonBgDisabled",
    "buttonTextDisabled",
    "sectionHeaderBg",
    "sectionMark",
    "fieldBg",
    "fieldText",
    "fieldHint",
    "dropdownHeaderBg",
    "dropdownHeaderText",
    "dropdownOptionBg",
    "dropdownOptionText",
    "dropdownMore",
}

local function C(r, g, b, a)
    return { R = r, G = g, B = b, A = a or 1.0 }
end

local function CopyColor(c)
    if type(c) ~= "table" then
        return nil
    end
    return {
        R = tonumber(c.R) or 0,
        G = tonumber(c.G) or 0,
        B = tonumber(c.B) or 0,
        A = tonumber(c.A) or 1,
    }
end

local function CopyColors(src)
    local out = {}
    for _, key in ipairs(KEYS) do
        out[key] = CopyColor(src[key])
    end
    return out
end

-- Current shipped look: navy panel, mid-blue buttons, light editable fields.
local LIGHT = {
    panelBg = C(0.05, 0.07, 0.12, 0.92),
    panelBorder = C(0.05, 0.07, 0.12, 0.92),
    textPrimary = C(0.95, 0.95, 0.98),
    textMuted = C(0.72, 0.76, 0.82),
    textAccent = C(0.45, 0.72, 0.88),
    textStatus = C(0.83, 0.69, 0.22),
    buttonBg = C(0.18, 0.22, 0.32),
    buttonText = C(0.95, 0.95, 0.98),
    -- Bootstrap-like action colors (flat UMG; no outline/link variants).
    buttonBgPrimary = C(0.05, 0.43, 0.99),
    buttonTextPrimary = C(1.0, 1.0, 1.0),
    buttonBgSecondary = C(0.42, 0.46, 0.49),
    buttonTextSecondary = C(1.0, 1.0, 1.0),
    buttonBgSuccess = C(0.10, 0.53, 0.33),
    buttonTextSuccess = C(1.0, 1.0, 1.0),
    buttonBgDanger = C(0.86, 0.21, 0.27),
    buttonTextDanger = C(1.0, 1.0, 1.0),
    buttonBgWarning = C(1.0, 0.76, 0.03),
    buttonTextWarning = C(0.08, 0.09, 0.10),
    buttonBgInfo = C(0.05, 0.79, 0.94),
    buttonTextInfo = C(0.08, 0.09, 0.10),
    buttonBgActive = C(0.12, 0.40, 0.28),
    buttonTextActive = C(0.82, 0.98, 0.88),
    buttonBgDisabled = C(0.12, 0.14, 0.18),
    buttonTextDisabled = C(0.45, 0.48, 0.52),
    sectionHeaderBg = C(0.10, 0.13, 0.20),
    sectionMark = C(0.72, 0.76, 0.82),
    fieldBg = C(0.88, 0.90, 0.94),
    fieldText = C(0.06, 0.07, 0.10),
    fieldHint = C(0.35, 0.38, 0.45),
    dropdownHeaderBg = C(0.22, 0.28, 0.40),
    dropdownHeaderText = C(0.98, 0.98, 1.0),
    dropdownOptionBg = C(0.88, 0.90, 0.94),
    dropdownOptionText = C(0.06, 0.07, 0.10),
    dropdownMore = C(0.70, 0.75, 0.85),
}

-- Dark preset: charcoal panel, dark fields. Flat UMG (no bevel/glow).
local DARK = {
    panelBg = C(0.11, 0.11, 0.12, 0.90),
    panelBorder = C(0.62, 0.62, 0.64, 0.90),
    textPrimary = C(0.92, 0.92, 0.93),
    textMuted = C(0.62, 0.62, 0.64),
    textAccent = C(0.12, 0.72, 0.70),
    textStatus = C(0.83, 0.69, 0.22),
    buttonBg = C(0.20, 0.20, 0.21),
    buttonText = C(0.92, 0.92, 0.93),
    buttonBgPrimary = C(0.08, 0.34, 0.78),
    buttonTextPrimary = C(1.0, 1.0, 1.0),
    buttonBgSecondary = C(0.32, 0.32, 0.34),
    buttonTextSecondary = C(0.92, 0.92, 0.93),
    buttonBgSuccess = C(0.08, 0.42, 0.28),
    buttonTextSuccess = C(0.92, 0.98, 0.94),
    buttonBgDanger = C(0.72, 0.18, 0.22),
    buttonTextDanger = C(1.0, 1.0, 1.0),
    buttonBgWarning = C(0.90, 0.68, 0.10),
    buttonTextWarning = C(0.10, 0.09, 0.06),
    buttonBgInfo = C(0.08, 0.52, 0.58),
    buttonTextInfo = C(0.90, 0.98, 0.98),
    buttonBgActive = C(0.10, 0.36, 0.28),
    buttonTextActive = C(0.72, 0.95, 0.84),
    buttonBgDisabled = C(0.14, 0.14, 0.15),
    buttonTextDisabled = C(0.40, 0.40, 0.42),
    sectionHeaderBg = C(0.16, 0.16, 0.17),
    sectionMark = C(0.62, 0.62, 0.64),
    fieldBg = C(0.06, 0.06, 0.07),
    fieldText = C(0.94, 0.94, 0.94),
    fieldHint = C(0.50, 0.50, 0.52),
    dropdownHeaderBg = C(0.20, 0.20, 0.21),
    dropdownHeaderText = C(0.92, 0.92, 0.93),
    dropdownOptionBg = C(0.08, 0.08, 0.09),
    dropdownOptionText = C(0.92, 0.92, 0.93),
    dropdownMore = C(0.62, 0.62, 0.64),
}

local PAD = {
    light = { Left = 20, Top = 18, Right = 20, Bottom = 18 },
    dark = { Left = 16, Top = 14, Right = 16, Bottom = 14 },
}

local PRESETS = {
    light = LIGHT,
    dark = DARK,
}

function M.Normalize(name)
    if name == nil or name == "light" then
        return "light"
    end
    if name == "dark" then
        return "dark"
    end
    error('ModMenu.Init: theme must be "light" or "dark"')
end

function M.Preset(name)
    local key = name
    if key ~= "dark" then
        key = "light"
    end
    return CopyColors(PRESETS[key])
end

function M.Merge(base, overrides)
    local out = CopyColors(base)
    if type(overrides) ~= "table" then
        return out
    end
    for _, key in ipairs(KEYS) do
        if overrides[key] ~= nil then
            local copied = CopyColor(overrides[key])
            if copied then
                out[key] = copied
            end
        end
    end
    return out
end

function M.Resolve(name, overrides)
    return M.Merge(PRESETS[M.Normalize(name)], overrides)
end

function M.Of(config)
    if config ~= nil and type(config.colors) == "table" then
        return config.colors
    end
    return M.Preset("light")
end

function M.PadPanel(config)
    local name = "light"
    if config ~= nil and config.theme == "dark" then
        name = "dark"
    end
    local pad = PAD[name]
    return {
        Left = pad.Left,
        Top = pad.Top,
        Right = pad.Right,
        Bottom = pad.Bottom,
    }
end

return M

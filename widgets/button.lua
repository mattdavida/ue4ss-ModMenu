--[[
  ModMenu widget: button

  Visual layers (disabled wins, then active, then variant):
    enabled = false  → themed disabled chrome + no clicks
    active = true    → "this is on" (green) — not a variant
    variant          → Bootstrap-like intent (primary/danger/warning/…)
    default          → theme buttonBg
    confirm          → optional table; onClick waits for the in-shell modal
]]

local Util = require("ModMenu.core.util")
local Theme = require("ModMenu.core.theme")

local Button = {}
Button.type = "button"

local VARIANTS = {
    default = true,
    primary = true,
    secondary = true,
    success = true,
    danger = true,
    warning = true,
    info = true,
}

-- Short-lived names from the first variant pass.
local ALIASES = {
    accent = "primary",
}

local VARIANT_CHROME = {
    primary = { "buttonBgPrimary", "buttonTextPrimary" },
    secondary = { "buttonBgSecondary", "buttonTextSecondary" },
    success = { "buttonBgSuccess", "buttonTextSuccess" },
    danger = { "buttonBgDanger", "buttonTextDanger" },
    warning = { "buttonBgWarning", "buttonTextWarning" },
    info = { "buttonBgInfo", "buttonTextInfo" },
}

local VARIANT_HELP = "default|primary|secondary|success|danger|warning|info"

function Button.NormalizeVariant(value)
    if value == nil or value == "" then
        return "default"
    end
    if type(value) ~= "string" then
        return nil
    end
    value = ALIASES[value] or value
    if VARIANTS[value] then
        return value
    end
    return nil
end

local function ChromeColors(colors, item)
    colors = colors or {}
    local fallbackBg, fallbackFg = colors.buttonBg, colors.buttonText
    if item.enabled == false then
        return colors.buttonBgDisabled or fallbackBg, colors.buttonTextDisabled or fallbackFg
    end
    if item.active == true then
        return colors.buttonBgActive or fallbackBg, colors.buttonTextActive or fallbackFg
    end
    local variant = item.variant or "default"
    local keys = VARIANT_CHROME[variant]
    if keys then
        return colors[keys[1]] or fallbackBg, colors[keys[2]] or fallbackFg
    end
    return fallbackBg, fallbackFg
end

--- Paint UMG from item.enabled / item.active / item.variant.
function Button.applyChrome(ctrl, ctx)
    if ctrl == nil or ctrl.item == nil then
        return
    end
    local item = ctrl.item
    local enabled = item.enabled ~= false
    ctrl.enabled = enabled
    local colors = Theme.Of(ctx and ctx.config)
    local bg, fg = ChromeColors(colors, item)
    pcall(function()
        if ctrl.widget ~= nil then
            ctrl.widget:SetIsEnabled(enabled)
            ctrl.widget:SetBackgroundColor(bg)
        end
    end)
    if ctrl.labelWidget ~= nil and ctx ~= nil and ctx.umg ~= nil then
        ctx.umg.StyleText(ctrl.labelWidget, ctx.config.fontItem, fg)
    end
end

function Button.validate(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if item.id == nil or item.id == "" then
        error(prefix .. " requires .id")
    end
    if item.label == nil then
        error(prefix .. " requires .label")
    end
    if item.onClick ~= nil and type(item.onClick) ~= "function" then
        error(prefix .. " onClick must be a function")
    end
    if item.enabled ~= nil and type(item.enabled) ~= "boolean" then
        error(prefix .. " enabled must be a boolean")
    end
    if item.active ~= nil and type(item.active) ~= "boolean" then
        error(prefix .. " active must be a boolean")
    end
    if item.variant ~= nil and Button.NormalizeVariant(item.variant) == nil then
        error(prefix .. " variant must be " .. VARIANT_HELP)
    end
    if item.confirm ~= nil then
        if type(item.confirm) ~= "table" then
            error(prefix .. " confirm must be a table")
        end
        for _, key in ipairs({ "title", "message", "confirmLabel", "cancelLabel" }) do
            if item.confirm[key] ~= nil and type(item.confirm[key]) ~= "string" then
                error(prefix .. " confirm." .. key .. " must be a string")
            end
        end
        if item.confirm.variant ~= nil and Button.NormalizeVariant(item.confirm.variant) == nil then
            error(prefix .. " confirm.variant must be " .. VARIANT_HELP)
        end
        if item.onClick == nil then
            error(prefix .. " confirm requires onClick (runs after Confirm)")
        end
    end
end

function Button.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    item.variant = Button.NormalizeVariant(item.variant) or "default"
    local button, label = umg.CreateTextButton(ctx.contentBox, ctx.namePrefix, item.label)
    umg.AddToContent(ctx, button)
    umg.AddItemPad(ctx, ctx.namePrefix .. "_Pad", 8)
    local ctrl = {
        kind = "button",
        sectionId = ctx.section.id,
        item = item,
        widget = button,
        labelWidget = label,
        enabled = item.enabled ~= false,
        wasPressed = false,
    }
    Button.applyChrome(ctrl, ctx)
    table.insert(ctx.liveControls, ctrl)
end

--- Fire onClick. Shared by IsPressed poll and LMB-latch pollClick.
---@param path string
local function FireClick(ctrl, ctx, path)
    ctx.Input.DebugClick(path, ctrl, ctrl.widget)
    ctx.Input.SuppressPressEdge(ctrl)
    if ctrl.item.confirm ~= nil and ctx.ShowConfirm ~= nil then
        ctx.ShowConfirm(ctrl.item)
    else
        ctx.SafeCall(ctrl.item.onClick)
    end
    ctx.ReclaimMenuInput()
    ctx.Input.IgnoreClicks(2)
    -- Reclaim touches PlayerController / SetInputMode — must stay on the game thread.
    ExecuteInGameThreadWithDelay(200, Util.PinFn(function()
        ctx.ReclaimMenuInput()
    end))
    return true
end

--- Continuous press poll — does not need the global LMB latch (engine / GameAndUI).
function Button.poll(ctrl, ctx)
    if ctrl.enabled == false then
        return
    end
    if ctx.Input.WidgetPressedEdge(ctrl, ctrl.widget) then
        FireClick(ctrl, ctx, "press-edge")
    end
end

--- @return boolean true if click consumed
function Button.pollClick(ctrl, ctx)
    if ctrl.enabled == false then
        return false
    end
    if not ctx.Input.WidgetHovered(ctrl.widget) then
        return false
    end
    return FireClick(ctrl, ctx, "latch-hover")
end

return Button

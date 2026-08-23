--[[
  ModMenu.shell.confirm — in-shell modal for destructive actions.

  Covers the docked panel (same canvas, higher Z). Blocks other widget polls
  while open. Cancel / close menu runs nothing. Confirm runs onConfirm once.
  A new Show replaces the current prompt (treated as Cancel).
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Theme = require("ModMenu.core.theme")
local Input = require("ModMenu.core.input")
local InputMode = require("ModMenu.core.inputmode")
local Dock = require("ModMenu.shell.dock")
local Button = require("ModMenu.widgets.button")

local Log = Util.Log
local Debug = Util.Debug
local IsValid = Util.IsValid
local SafeCall = Util.SafeCall
local Construct = Umg.Construct
local StyleText = Umg.StyleText
local SetLabelText = Umg.SetLabelText
local EnableAutoWrap = Umg.EnableAutoWrap

local M = {}

local function Normalize(opts)
    if type(opts) ~= "table" then
        error("ModMenu.Confirm expects a table")
    end
    if type(opts.onConfirm) ~= "function" then
        error("ModMenu.Confirm requires onConfirm")
    end
    if opts.onCancel ~= nil and type(opts.onCancel) ~= "function" then
        error("ModMenu.Confirm onCancel must be a function")
    end
    local variant = Button.NormalizeVariant(opts.variant) or "danger"
    local title = opts.title
    if type(title) ~= "string" or title == "" then
        title = "Are you sure?"
    end
    local message = opts.message
    if type(message) ~= "string" or message == "" then
        message = nil
    end
    local confirmLabel = opts.confirmLabel
    if type(confirmLabel) ~= "string" or confirmLabel == "" then
        confirmLabel = "Confirm"
    end
    local cancelLabel = opts.cancelLabel
    if type(cancelLabel) ~= "string" or cancelLabel == "" then
        cancelLabel = "Cancel"
    end
    return {
        title = title,
        message = message,
        confirmLabel = confirmLabel,
        cancelLabel = cancelLabel,
        variant = variant,
        onConfirm = opts.onConfirm,
        onCancel = opts.onCancel,
    }
end

local function DestroyOverlay(S)
    if IsValid(S.confirmRoot) then
        pcall(function()
            S.confirmRoot:RemoveFromParent()
        end)
        pcall(function()
            S.confirmRoot:SetVisibility(1)
        end)
    end
    S.confirmRoot = nil
    S.confirmSlot = nil
    S.confirmControls = nil
end

--- Dismiss without stacking. reason = "confirm" | "cancel" | "close"
function M.Hide(S, reason)
    local spec = S.confirm
    S.confirm = nil
    DestroyOverlay(S)
    if spec == nil then
        return
    end
    if reason == "confirm" then
        Debug("Confirm accepted: " .. tostring(spec.title))
        SafeCall(spec.onConfirm)
    else
        Debug("Confirm dismissed (" .. tostring(reason) .. "): " .. tostring(spec.title))
        SafeCall(spec.onCancel)
    end
end

function M.IsOpen(S)
    return S.confirm ~= nil
end

local CARD_WIDTH = 360

local function AddHairline(parent, name, color)
    local box = Construct("/Script/UMG.SizeBox", parent, name)
    pcall(function()
        box:SetHeightOverride(1)
    end)
    local line = Construct("/Script/UMG.Border", box, name .. "_Line")
    pcall(function()
        line:SetBrushColor(color)
        line:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        box:SetContent(line)
    end)
    parent:AddChildToVerticalBox(box)
end

local function MakeButton(S, parent, namePrefix, label, variant, role)
    local colors = Theme.Of(S.config)
    local keys = {
        default = { "buttonBg", "buttonText" },
        primary = { "buttonBgPrimary", "buttonTextPrimary" },
        secondary = { "buttonBgSecondary", "buttonTextSecondary" },
        success = { "buttonBgSuccess", "buttonTextSuccess" },
        danger = { "buttonBgDanger", "buttonTextDanger" },
        warning = { "buttonBgWarning", "buttonTextWarning" },
        info = { "buttonBgInfo", "buttonTextInfo" },
    }
    local pair = keys[variant] or keys.default
    local bg = colors[pair[1]] or colors.buttonBg
    local fg = colors[pair[2]] or colors.buttonText
    local button, text = Umg.CreateTextButton(parent, namePrefix, label, bg, fg, S.config.fontItem)
    return {
        kind = "confirm",
        role = role,
        widget = button,
        labelWidget = text,
        item = { variant = variant, enabled = true, label = label },
        wasPressed = false,
    }
end

local function BuildOverlay(S, spec)
    if not IsValid(S.menuCanvas) then
        Log("Confirm: no menu canvas")
        return false
    end

    S.confirmGen = (S.confirmGen or 0) + 1
    local suffix = tostring(S.confirmGen)
    local colors = Theme.Of(S.config)
    local canvas = S.menuCanvas

    -- Dim fills the docked panel. The card is a separate auto-sized child so
    -- height follows title + message + buttons (Bootstrap-style), not the panel.
    local dim = Construct("/Script/UMG.Border", canvas, "ModMenu_ConfirmDim_" .. suffix)
    pcall(function()
        dim:SetBrushColor(colors.overlayDim or { R = 0, G = 0, B = 0, A = 0.55 })
        dim:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
    end)

    local inner = Construct("/Script/UMG.CanvasPanel", dim, "ModMenu_ConfirmInner_" .. suffix)
    pcall(function()
        dim:SetContent(inner)
    end)

    local sizeBox = Construct("/Script/UMG.SizeBox", inner, "ModMenu_ConfirmSize_" .. suffix)
    pcall(function()
        sizeBox:SetWidthOverride(CARD_WIDTH)
        if sizeBox.SetMaxDesiredWidth then
            sizeBox:SetMaxDesiredWidth(CARD_WIDTH)
        end
    end)

    local card = Construct("/Script/UMG.Border", sizeBox, "ModMenu_ConfirmCard_" .. suffix)
    pcall(function()
        card:SetBrushColor(colors.confirmCardBg or colors.panelBg)
        card:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        sizeBox:SetContent(card)
    end)

    local vbox = Construct("/Script/UMG.VerticalBox", card, "ModMenu_ConfirmBox_" .. suffix)
    pcall(function()
        card:SetContent(vbox)
    end)

    local sectionPad = { Left = 16, Top = 12, Right = 16, Bottom = 12 }
    local divider = colors.confirmDivider or colors.panelBorder

    local title = Construct("/Script/UMG.TextBlock", vbox, "ModMenu_ConfirmTitle_" .. suffix)
    StyleText(title, S.config.fontSection, colors.textPrimary)
    SetLabelText(title, spec.title)
    EnableAutoWrap(title)
    local titleSlot = vbox:AddChildToVerticalBox(title)
    pcall(function()
        titleSlot:SetPadding(sectionPad)
        titleSlot:SetHorizontalAlignment(0)
        titleSlot:SetSize({ SizeRule = 0, Value = 0.0 })
    end)

    AddHairline(vbox, "ModMenu_ConfirmRule1_" .. suffix, divider)

    if spec.message ~= nil then
        local msg = Construct("/Script/UMG.TextBlock", vbox, "ModMenu_ConfirmMsg_" .. suffix)
        StyleText(msg, S.config.fontItem, colors.textMuted)
        SetLabelText(msg, spec.message)
        EnableAutoWrap(msg)
        local msgSlot = vbox:AddChildToVerticalBox(msg)
        pcall(function()
            msgSlot:SetPadding(sectionPad)
            msgSlot:SetHorizontalAlignment(0)
            msgSlot:SetSize({ SizeRule = 0, Value = 0.0 })
        end)
        AddHairline(vbox, "ModMenu_ConfirmRule2_" .. suffix, divider)
    end

    local row = Construct("/Script/UMG.HorizontalBox", vbox, "ModMenu_ConfirmRow_" .. suffix)
    local rowSlot = vbox:AddChildToVerticalBox(row)
    pcall(function()
        rowSlot:SetPadding({ Left = 12, Top = 10, Right = 12, Bottom = 10 })
        rowSlot:SetSize({ SizeRule = 0, Value = 0.0 })
    end)

    local push = Construct("/Script/UMG.Spacer", row, "ModMenu_ConfirmPush_" .. suffix)
    local pushSlot = row:AddChildToHorizontalBox(push)
    pcall(function()
        pushSlot:SetSize({ SizeRule = 1, Value = 1.0 })
    end)

    local cancel = MakeButton(S, row, "ModMenu_ConfirmNo_" .. suffix, spec.cancelLabel, "secondary", "cancel")
    local cancelSlot = row:AddChildToHorizontalBox(cancel.widget)
    pcall(function()
        cancelSlot:SetSize({ SizeRule = 0, Value = 0.0 })
        cancelSlot:SetPadding({ Left = 0, Top = 0, Right = 8, Bottom = 0 })
        cancelSlot:SetVerticalAlignment(2)
    end)

    local ok = MakeButton(S, row, "ModMenu_ConfirmYes_" .. suffix, spec.confirmLabel, spec.variant, "confirm")
    local okSlot = row:AddChildToHorizontalBox(ok.widget)
    pcall(function()
        okSlot:SetSize({ SizeRule = 0, Value = 0.0 })
        okSlot:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        okSlot:SetVerticalAlignment(2)
    end)

    local cardSlot = inner:AddChildToCanvas(sizeBox)
    pcall(function()
        cardSlot:SetAutoSize(true)
        cardSlot:SetAnchors({
            Minimum = { X = 0.5, Y = 0.5 },
            Maximum = { X = 0.5, Y = 0.5 },
        })
        cardSlot:SetAlignment({ X = 0.5, Y = 0.5 })
        cardSlot:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        cardSlot:SetZOrder(1)
    end)

    local slot = canvas:AddChildToCanvas(dim)
    Dock.ApplyPercentLayout(slot, S.config)
    pcall(function()
        slot:SetZOrder(20)
    end)

    S.confirmRoot = dim
    S.confirmSlot = slot
    S.confirmControls = { cancel, ok }
    return true
end

function M.Show(S, opts)
    local spec = Normalize(opts)
    if M.IsOpen(S) then
        M.Hide(S, "cancel")
    end
    if not IsValid(S.menuCanvas) or S.menuOpen ~= true then
        Log("Confirm: menu is not open")
        return false
    end
    if not BuildOverlay(S, spec) then
        return false
    end
    S.confirm = spec
    Input.ClearClickState()
    Input.IgnoreClicks(2)
    InputMode.Reclaim()
    Debug("Confirm shown: " .. spec.title)
    return true
end

--- Poll only the modal buttons. Consumes leftover clicks so they cannot hit the panel.
---@return boolean true if a confirm is open
function M.Poll(S)
    if S.confirm == nil then
        return false
    end

    local fired = nil
    for _, ctrl in ipairs(S.confirmControls or {}) do
        if Input.WidgetPressedEdge(ctrl, ctrl.widget) then
            fired = ctrl.role
            Input.SuppressPressEdge(ctrl)
            break
        end
    end

    if Input.ConsumeMouseClick() and fired == nil then
        for _, ctrl in ipairs(S.confirmControls or {}) do
            if Input.WidgetHovered(ctrl.widget) then
                fired = ctrl.role
                Input.SuppressPressEdge(ctrl)
                break
            end
        end
    end

    if fired == "confirm" then
        Input.IgnoreClicks(2)
        M.Hide(S, "confirm")
        InputMode.Reclaim()
    elseif fired == "cancel" then
        Input.IgnoreClicks(2)
        M.Hide(S, "cancel")
        InputMode.Reclaim()
    end
    return true
end

--- Button item.confirm → Show. onClick runs only after Confirm.
function M.FromButton(S, item)
    local spec = item.confirm
    if type(spec) ~= "table" then
        return false
    end
    M.Show(S, {
        title = spec.title,
        message = spec.message,
        confirmLabel = spec.confirmLabel,
        cancelLabel = spec.cancelLabel,
        variant = spec.variant or item.variant,
        onConfirm = item.onClick,
    })
    return true
end

return M

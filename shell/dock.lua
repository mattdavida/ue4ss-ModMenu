--[[
  ModMenu.shell.dock — percent layout and dock chrome dropdown.

  Init({ dock }) is the author default. The header picker offers Left / Right /
  Top / Bottom for every host. Same rectangle, rotated 90° on top/bottom.
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Config = require("ModMenu.core.config")
local Widgets = require("ModMenu.widgets.init")

local Dropdown = Widgets.get("dropdown")
local Debug = Util.Debug

-- Clockwise. Selection must not rotate this list.
local SIDES = {
    { label = "Top", value = "top" },
    { label = "Right", value = "right" },
    { label = "Bottom", value = "bottom" },
    { label = "Left", value = "left" },
}

local M = {}

--- Percentage anchors. left/right unchanged; top/bottom is the same strip rotated 90°.
--- rightFrac = thickness-edge gap; widthFrac = thickness; topFrac/bottomFrac = long-axis margins.
function M.ApplyPercentLayout(slot, config)
    if slot == nil then
        return
    end
    local edge = config.rightFrac or 0.01
    local thick = config.widthFrac or 0.32
    local longMin = config.topFrac
    local longMax = 1.0 - config.bottomFrac
    local minX
    local maxX
    local minY
    local maxY
    local dock = config.dock
    if dock == "top" then
        minX = longMin
        maxX = longMax
        minY = edge
        maxY = edge + thick
    elseif dock == "bottom" then
        minX = longMin
        maxX = longMax
        minY = 1.0 - thick - edge
        maxY = 1.0 - edge
    elseif dock == "left" then
        minX = edge
        maxX = edge + thick
        minY = longMin
        maxY = longMax
    else
        minX = 1.0 - thick - edge
        maxX = 1.0 - edge
        minY = longMin
        maxY = longMax
    end

    pcall(function()
        slot:SetAutoSize(false)
        slot:SetAnchors({
            Minimum = { X = minX, Y = minY },
            Maximum = { X = maxX, Y = maxY },
        })
        slot:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        slot:SetAlignment({ X = 0.0, Y = 0.0 })
    end)
end

function M.BuildChrome(S, contentBox, suffix)
    local config = S.config
    local caption = Umg.Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_DockCap_" .. suffix)
    Umg.StyleText(caption, config.fontHint)
    Umg.SetLabelText(caption, "Dock")
    contentBox:AddChildToVerticalBox(caption)

    local root, picker = Dropdown.createPicker(
        contentBox,
        "ModMenu_Dock_" .. suffix,
        SIDES,
        config.dock,
        { maxVisible = 4 },
        config
    )
    contentBox:AddChildToVerticalBox(root)

    local dockPad = 8
    if config.pointerMode == "touch" then
        dockPad = 24
    end
    Umg.AddSpacer(contentBox, "ModMenu_DockPad_" .. suffix, dockPad)

    table.insert(S.liveControls, Dropdown.liveControl(picker, {
        role = "dock",
        widget = root,
        valueKey = "__modmenu.dock",
        item = {
            onChange = function(value)
                M.Set(S, value)
            end,
        },
    }))
end

function M.SyncChrome(S)
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "dropdown" and ctrl.role == "dock" then
            Dropdown.apply(ctrl, S.config.dock)
        end
    end
end

function M.Set(S, side)
    S.config.dock = Config.NormalizeDock(side)
    M.ApplyPercentLayout(S.panelSlot, S.config)
    M.SyncChrome(S)
    if S.menuScroll ~= nil then
        pcall(function()
            S.menuScroll:ScrollToStart()
        end)
    end
    Debug("Dock -> " .. S.config.dock)
    for _, fn in ipairs(S.onDockCallbacks or {}) do
        Util.SafeCall(fn, S.config.dock)
    end
end

return M

--[[
  ModMenu.shell.dock — left/right percent layout and dock chrome button.
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local InputMode = require("ModMenu.core.inputmode")
local Config = require("ModMenu.core.config")
local Widgets = require("ModMenu.widgets.init")

local Dropdown = Widgets.get("dropdown")
local Debug = Util.Debug
local Construct = Umg.Construct
local StyleText = Umg.StyleText

local M = {}

function M.Caption(config)
    local side = config.dock == "left" and "Left" or "Right"
    return "Dock: " .. side
end

--- Percentage anchors for left or right dock. rightFrac is the edge margin for both sides.
function M.ApplyPercentLayout(slot, config)
    if slot == nil then
        return
    end
    local edge = config.rightFrac or 0.01
    local width = config.widthFrac or 0.32
    local topFrac = config.topFrac
    local bottomFrac = 1.0 - config.bottomFrac
    local minX
    local maxX
    if config.dock == "left" then
        minX = edge
        maxX = edge + width
    else
        minX = 1.0 - width - edge
        maxX = 1.0 - edge
    end

    pcall(function()
        slot:SetAutoSize(false)
        slot:SetAnchors({
            Minimum = { X = minX, Y = topFrac },
            Maximum = { X = maxX, Y = bottomFrac },
        })
        slot:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        slot:SetAlignment({ X = 0.0, Y = 0.0 })
    end)
end

function M.SyncChrome(S)
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "dock" and ctrl.widget ~= nil then
            -- Recreate Button content — SetText on Button children goes stale after a few flips.
            local serial = Dropdown.nextRowSerial()
            pcall(function()
                local label = Construct(
                    "/Script/UMG.TextBlock",
                    ctrl.widget,
                    "ModMenu_DockLbl_" .. tostring(serial)
                )
                StyleText(label, S.config.fontItem)
                label:SetText(FText(M.Caption(S.config)))
                ctrl.widget:SetContent(label)
                ctrl.label = label
            end)
        end
    end
end

function M.Set(S, side)
    S.config.dock = Config.NormalizeDock(side)
    M.ApplyPercentLayout(S.panelSlot, S.config)
    M.SyncChrome(S)
    Debug("Dock -> " .. S.config.dock)
end

function M.Flip(S)
    M.Set(S, S.config.dock == "left" and "right" or "left")
end

function M.Poll(S, ctrl)
    if Input.WidgetPressedEdge(ctrl, ctrl.widget) then
        Input.DebugClick("press-edge", ctrl, ctrl.widget)
        M.Flip(S)
        InputMode.Reclaim()
        Input.IgnoreClicks(2)
    end
end

---@return boolean
function M.PollClick(S, ctrl)
    if not Input.WidgetHovered(ctrl.widget) then
        return false
    end
    Input.DebugClick("latch-hover", ctrl, ctrl.widget)
    Input.SuppressPressEdge(ctrl)
    M.Flip(S)
    InputMode.Reclaim()
    Input.IgnoreClicks(2)
    return true
end

return M

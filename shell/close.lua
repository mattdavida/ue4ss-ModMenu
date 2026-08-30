--[[
  ModMenu.shell.close — title-row Close button. Same path as the toggle key.
]]

local Input = require("ModMenu.core.input")

local M = {}

local function Request(S, ctrl)
    Input.SuppressPressEdge(ctrl)
    Input.IgnoreClicks(2)
    S.pendingClose = true
end

function M.Poll(S, ctrl)
    if Input.WidgetPressedEdge(ctrl, ctrl.widget) then
        Input.DebugClick("press-edge", ctrl, ctrl.widget)
        Request(S, ctrl)
    end
end

---@return boolean
function M.PollClick(S, ctrl)
    if not Input.WidgetHovered(ctrl.widget) then
        return false
    end
    Input.DebugClick("latch-hover", ctrl, ctrl.widget)
    Request(S, ctrl)
    return true
end

return M

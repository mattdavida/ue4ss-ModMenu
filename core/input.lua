--[[
  ModMenu.core.input — LMB click latch + hover helpers for constructed UButtons.
]]

local M = {}

-- IsPressed() polling misses short clicks on constructed UButtons.
local mouseClickLatch = false
local mouseBindInstalled = false
local clickIgnore = 0

--- @param isMenuOpen fun(): boolean
function M.InstallMouseClickLatch(isMenuOpen)
    if mouseBindInstalled then
        return
    end
    mouseBindInstalled = true
    RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function()
        if isMenuOpen and isMenuOpen() then
            mouseClickLatch = true
        end
    end)
end

function M.ConsumeMouseClick()
    if clickIgnore > 0 then
        clickIgnore = clickIgnore - 1
        mouseClickLatch = false
        return false
    end
    if not mouseClickLatch then
        return false
    end
    mouseClickLatch = false
    return true
end

function M.IgnoreClicks(n)
    clickIgnore = math.max(clickIgnore, n or 2)
    mouseClickLatch = false
end

--- Clear latch + ignore counters (e.g. after content rebuild while open).
function M.ClearClickState()
    mouseClickLatch = false
    clickIgnore = 0
end

function M.WidgetHovered(widget)
    if widget == nil then
        return false
    end
    local ok, hovered = pcall(function()
        if type(widget.IsValid) == "function" and not widget:IsValid() then
            return false
        end
        return widget:IsHovered()
    end)
    return ok and hovered == true
end

return M

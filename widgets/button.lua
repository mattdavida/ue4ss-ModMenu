--[[
  ModMenu widget: button
]]

local Button = {}
Button.type = "button"

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
end

function Button.build(ctx)
    local umg = ctx.umg
    local button, label = umg.CreateTextButton(ctx.contentBox, ctx.namePrefix, ctx.item.label)
    umg.AddToContent(ctx, button)
    umg.AddItemPad(ctx, ctx.namePrefix .. "_Pad", 8)
    local enabled = ctx.item.enabled ~= false
    pcall(function()
        button:SetIsEnabled(enabled)
    end)
    table.insert(ctx.liveControls, {
        kind = "button",
        sectionId = ctx.section.id,
        item = ctx.item,
        widget = button,
        labelWidget = label,
        enabled = enabled,
        wasPressed = false,
    })
end

--- Fire onClick. Shared by IsPressed poll and LMB-latch pollClick.
local function FireClick(ctrl, ctx)
    ctx.Input.SuppressPressEdge(ctrl)
    ctx.SafeCall(ctrl.item.onClick)
    ctx.ReclaimMenuInput()
    ctx.Input.IgnoreClicks(2)
    -- Reclaim touches PlayerController / SetInputMode — must stay on the game thread.
    ExecuteInGameThreadWithDelay(200, function()
        ctx.ReclaimMenuInput()
    end)
    return true
end

--- Continuous press poll — does not need the global LMB latch (engine / GameAndUI).
function Button.poll(ctrl, ctx)
    if ctrl.enabled == false then
        return
    end
    if ctx.Input.WidgetPressedEdge(ctrl, ctrl.widget) then
        FireClick(ctrl, ctx)
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
    return FireClick(ctrl, ctx)
end

return Button

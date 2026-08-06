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
    local button = umg.CreateTextButton(ctx.contentBox, ctx.namePrefix, ctx.item.label)
    ctx.contentBox:AddChildToVerticalBox(button)
    umg.AddSpacer(ctx.contentBox, ctx.namePrefix .. "_Pad", 8)
    table.insert(ctx.liveControls, {
        kind = "button",
        sectionId = ctx.section.id,
        item = ctx.item,
        widget = button,
        wasPressed = false,
    })
end

--- @return boolean true if click consumed
function Button.pollClick(ctrl, ctx)
    if not ctx.Input.WidgetHovered(ctrl.widget) then
        return false
    end
    ctx.SafeCall(ctrl.item.onClick)
    ctx.ReclaimMenuInput()
    ExecuteWithDelay(200, function()
        ctx.ReclaimMenuInput()
    end)
    return true
end

return Button

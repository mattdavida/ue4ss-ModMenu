--[[
  ModMenu widget: checkbox
]]

local Checkbox = {}
Checkbox.type = "checkbox"

local function Caption(item, isOn)
    if item.showState == false then
        return item.label
    end
    return string.format("%s: %s", item.label, isOn and "ON" or "OFF")
end

Checkbox.Caption = Caption

function Checkbox.validate(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if item.id == nil or item.id == "" then
        error(prefix .. " requires .id")
    end
    if item.label == nil then
        error(prefix .. " requires .label")
    end
    if item.onChange ~= nil and type(item.onChange) ~= "function" then
        error(prefix .. " onChange must be a function")
    end
end

function Checkbox.seed(sectionId, item, values)
    if not item.id then
        return
    end
    local vkey = tostring(sectionId) .. "." .. tostring(item.id)
    if values[vkey] == nil then
        values[vkey] = item.default and true or false
    end
end

function Checkbox.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    local vkey = ctx.ValueKey(ctx.section.id, item.id)
    local current = ctx.values[vkey]
    if current == nil then
        current = item.default and true or false
        ctx.values[vkey] = current
    end
    local check, label = umg.CreateLabeledToggle(
        ctx.contentBox,
        ctx.namePrefix,
        Caption(item, current),
        current
    )
    ctx.contentBox:AddChildToVerticalBox(check)
    umg.AddSpacer(ctx.contentBox, ctx.namePrefix .. "_Pad", 8)
    table.insert(ctx.liveControls, {
        kind = "checkbox",
        sectionId = ctx.section.id,
        item = item,
        widget = check,
        label = label,
        valueKey = vkey,
    })
end

--- Continuous state poll (not LMB latch).
function Checkbox.poll(ctrl, ctx)
    if not ctx.IsValid(ctrl.widget) then
        return
    end
    local ok, checked = pcall(function()
        return ctrl.widget:IsChecked()
    end)
    if ok and checked ~= ctx.values[ctrl.valueKey] then
        ctx.values[ctrl.valueKey] = checked
        ctx.umg.SetLabelText(ctrl.label, Caption(ctrl.item, checked))
        ctx.SafeCall(ctrl.item.onChange, checked)
        ctx.ReclaimMenuInput()
    end
end

function Checkbox.apply(ctrl, value, ctx)
    if not ctx.IsValid(ctrl.widget) then
        return
    end
    local on = value and true or false
    pcall(function()
        ctrl.widget:SetIsChecked(on)
    end)
    ctx.umg.SetLabelText(ctrl.label, Caption(ctrl.item, on))
end

return Checkbox

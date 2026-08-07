--[[
  ModMenu widget: label
]]

local Label = {}
Label.type = "label"

function Label.validate(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if item.label == nil then
        error(prefix .. " label requires .label")
    end
end

function Label.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    local label = umg.Construct("/Script/UMG.TextBlock", ctx.contentBox, ctx.namePrefix)
    umg.StyleText(label, ctx.config.fontHint)
    umg.SetLabelText(label, item.label)
    umg.EnableAutoWrap(label)
    local slot = ctx.contentBox:AddChildToVerticalBox(label)
    umg.FillVerticalSlot(slot)
    umg.AddSpacer(ctx.contentBox, ctx.namePrefix .. "_Pad", 6)
    if item.id then
        table.insert(ctx.liveControls, {
            kind = "label",
            sectionId = ctx.section.id,
            item = item,
            widget = label,
            valueKey = ctx.ValueKey(ctx.section.id, item.id),
        })
    end
end

function Label.apply(ctrl, text, ctx)
    if ctrl.widget ~= nil then
        ctx.umg.SetLabelText(ctrl.widget, tostring(text))
    end
end

return Label

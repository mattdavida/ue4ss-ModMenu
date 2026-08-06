--[[
  ModMenu widget: separator
]]

local Separator = {}
Separator.type = "separator"

function Separator.validate(_item, _sectionId, _index)
    -- no fields required
end

function Separator.build(ctx)
    ctx.umg.AddSpacer(ctx.contentBox, ctx.namePrefix .. "_Sep", 14)
end

return Separator

--[[
  ModMenu.core.options — dropdown option normalize / filter helpers.
]]

local Util = require("ModMenu.core.util")

local M = {}

--- Normalize dropdown options into { {label, value}, ... } plus lookup maps.
--- Labels/values are forced to plain Lua strings so lang + category behave identically.
function M.NormalizeOptions(options)
    local list = {}
    local labelToValue = {}
    local valueToLabel = {}
    for _, opt in ipairs(options or {}) do
        if type(opt) == "string" then
            local s = Util.ToPlainString(opt) or opt
            table.insert(list, { label = s, value = s })
            labelToValue[s] = s
            valueToLabel[s] = s
        elseif type(opt) == "table" then
            local value = opt.value
            local label = opt.label
            if value == nil and label == nil then
                error("dropdown option needs .label or .value")
            end
            if label == nil then
                label = value
            end
            if value == nil then
                value = label
            end
            label = Util.ToPlainString(label) or tostring(label)
            value = Util.ToPlainString(value) or tostring(value)
            table.insert(list, { label = label, value = value })
            labelToValue[label] = value
            valueToLabel[value] = label
        end
    end
    return list, labelToValue, valueToLabel
end

function M.OptionMatchesFilter(label, filter)
    if filter == nil or filter == "" then
        return true
    end
    local hay = string.lower(tostring(label or ""))
    local needle = string.lower(tostring(filter))
    return string.find(hay, needle, 1, true) ~= nil
end

function M.GetWidgetPlainText(widget)
    if widget == nil then
        return ""
    end
    local ok, text = pcall(function()
        return widget:GetText()
    end)
    if not ok or text == nil then
        return ""
    end
    return Util.ToPlainString(text) or tostring(text) or ""
end

return M

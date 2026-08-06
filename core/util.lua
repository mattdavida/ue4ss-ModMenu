--[[
  ModMenu.core.util — shared helpers (logging, validity, strings, value keys).
]]

local M = {}

local LIB_NAME = "ModMenu"

function M.Log(msg)
    print(string.format("[%s] %s\n", LIB_NAME, tostring(msg)))
end

function M.IsValid(obj)
    return obj ~= nil and type(obj.IsValid) == "function" and obj:IsValid()
end

--- ComboBoxString / FText / FString userdata — normalize before compare/store.
function M.ToPlainString(value)
    if value == nil then
        return nil
    end
    if type(value) == "string" then
        return value
    end
    if type(value) == "userdata" or type(value) == "table" then
        if value.ToString then
            local ok, s = pcall(function()
                return value:ToString()
            end)
            if ok and type(s) == "string" then
                return s
            end
        end
    end
    local s = tostring(value)
    -- Avoid storing "FString: 0000..." pointer junk as a real value.
    if string.find(s, "FString:", 1, true) == 1 then
        return nil
    end
    return s
end

function M.ValueKey(sectionId, itemId)
    return tostring(sectionId) .. "." .. tostring(itemId)
end

function M.SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        M.Log("callback error: " .. tostring(err))
    end
end

return M

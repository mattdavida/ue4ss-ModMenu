--[[
  ModMenu.core.util — shared helpers (logging, validity, strings, value keys).
]]

local M = {}

local LIB_NAME = "ModMenu"

-- UE4SS LoopInGameThreadWithDelay / ExecuteInGameThreadWithDelay store a
-- registry ref. If Lua GC collects the closure, EngineTick throws
-- "Ref was not function" and removes the whole Lua tick hook.
local pinnedFns = {}

function M.PinFn(fn)
    if type(fn) == "function" then
        pinnedFns[fn] = true
    end
    return fn
end

local debugOn = false

function M.SetDebug(on)
    debugOn = on == true
end

function M.Log(msg)
    print(string.format("[%s] %s\n", LIB_NAME, tostring(msg)))
end

--- Verbose traces (collapse, open/close, section register). Off by default.
function M.Debug(msg)
    if debugOn then
        M.Log(msg)
    end
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

--- Default debounce for textinput / number onChange (ms). 0 = immediate.
M.DEFAULT_INPUT_DEBOUNCE_MS = 250

function M.ValidateDebounceMs(item, prefix)
    if item.debounceMs ~= nil and (type(item.debounceMs) ~= "number" or item.debounceMs < 0) then
        error(prefix .. " debounceMs must be a number >= 0")
    end
end

function M.ResolveDebounceMs(item, defaultMs)
    if item.debounceMs == nil then
        return defaultMs or M.DEFAULT_INPUT_DEBOUNCE_MS
    end
    return item.debounceMs
end

--- Queue a debounced onChange. Values store should already be updated (Get stays live).
function M.ScheduleDebouncedOnChange(ctrl, debounceMs)
    if debounceMs == nil or debounceMs <= 0 then
        ctrl.onChangeDue = 0
    else
        ctrl.onChangeDue = os.clock() + (debounceMs / 1000)
    end
end

--- Fire pending onChange when due. No-op if nothing scheduled or value unchanged since last fire.
function M.FlushDebouncedOnChange(ctrl, ctx)
    if ctrl.onChangeDue == nil then
        return
    end
    if os.clock() < ctrl.onChangeDue then
        return
    end
    ctrl.onChangeDue = nil
    local v = ctx.values[ctrl.valueKey]
    if v == ctrl.lastFiredOnChange then
        return
    end
    ctrl.lastFiredOnChange = v
    M.SafeCall(ctrl.item.onChange, v)
end

--- Clear pending debounce (e.g. after Set/apply). Optionally sync lastFiredOnChange.
function M.ClearDebouncedOnChange(ctrl, syncValue)
    ctrl.onChangeDue = nil
    if syncValue ~= nil then
        ctrl.lastFiredOnChange = syncValue
    end
end

return M

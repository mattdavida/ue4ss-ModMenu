--[[
  ModMenu.core.shared — ModRef shared variables (process-wide, survive hot-reload).

  Scalars only. Do not store tables or functions.
]]

local M = {}

M.NEXT_INSTANCE = "ModMenu.NextInstanceId"
M.OPEN_COUNT = "ModMenu.OpenCount"
--- Claim map: ModMenu.KeyClaim.<keyHint> -> instanceTag (string). Warn-only on clash.
M.KEY_CLAIM_PREFIX = "ModMenu.KeyClaim."
--- Stashed PlayerController input flags while any ModMenu is open.
M.INPUT_SAVED = "ModMenu.InputSaved"
M.SAVED_SHOW_CURSOR = "ModMenu.Saved.bShowMouseCursor"
M.SAVED_CLICK = "ModMenu.Saved.bEnableClickEvents"
M.SAVED_HOVER = "ModMenu.Saved.bEnableMouseOverEvents"
M.SAVED_LOOK_BUMP = "ModMenu.Saved.LookIgnoreBump"

function M.Get(name)
    if ModRef == nil then
        return nil
    end
    local ok, value = pcall(function()
        return ModRef:GetSharedVariable(name)
    end)
    if ok then
        return value
    end
    return nil
end

function M.Set(name, value)
    if ModRef == nil then
        return false
    end
    local ok = pcall(function()
        ModRef:SetSharedVariable(name, value)
    end)
    return ok == true
end

function M.AdjustOpenCount(delta)
    local n = M.Get(M.OPEN_COUNT)
    if type(n) ~= "number" then
        n = 0
    end
    n = math.max(0, n + delta)
    M.Set(M.OPEN_COUNT, n)
    return n
end

return M

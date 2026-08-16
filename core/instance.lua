--[[
  ModMenu.core.instance — per-Lua-state identity, FName suffix, key claims, open-count hold.
]]

local Shared = require("ModMenu.core.shared")
local Util = require("ModMenu.core.util")

local M = {}

local VIEWPORT_Z_BASE = 1000

local instanceSerial = nil ---@type integer?
local instanceTag = nil ---@type string?
local viewportZ = VIEWPORT_Z_BASE
local createAttempts = 0
--- True while this instance has incremented SHARED_OPEN_COUNT.
local openCountHeld = false

local function SanitizeTag(raw)
    local s = tostring(raw or "mod"):gsub("[^%w_]", "_")
    if s == "" then
        s = "mod"
    end
    -- FName-friendly length; keep Live View readable.
    if #s > 48 then
        s = string.sub(s, 1, 48)
    end
    return s
end

--- Allocate a process-wide instance id so UObject names never collide across mods.
---@param config table
function M.Ensure(config)
    if instanceSerial ~= nil and instanceTag ~= nil then
        return
    end

    local nextId = Shared.Get(Shared.NEXT_INSTANCE)
    if type(nextId) ~= "number" then
        nextId = 0
    end
    nextId = nextId + 1
    if not Shared.Set(Shared.NEXT_INSTANCE, nextId) then
        -- No ModRef (unexpected): fall back to a local-only id (single-mod safe).
        nextId = (createAttempts > 0 and createAttempts or 1)
        Util.Log("WARNING: ModRef shared vars unavailable — instance id may collide across mods")
    end
    instanceSerial = nextId

    local tag = config.instanceId
    if tag == nil or tostring(tag) == "" then
        tag = "i" .. tostring(instanceSerial)
    end
    instanceTag = SanitizeTag(tag)
    viewportZ = VIEWPORT_Z_BASE + (instanceSerial - 1)

    Util.Log(string.format(
        "Instance identity serial=%d tag=%q viewportZ=%d",
        instanceSerial,
        instanceTag,
        viewportZ
    ))
end

function M.BumpCreateAttempts()
    createAttempts = createAttempts + 1
    return createAttempts
end

---@param config table
---@return string
function M.ShellNameSuffix(config)
    M.Ensure(config)
    return string.format("%s_%d", instanceTag, createAttempts)
end

function M.GetTag()
    return instanceTag
end

function M.GetSerial()
    return instanceSerial
end

function M.GetViewportZ()
    return viewportZ
end

function M.IsOpenCountHeld()
    return openCountHeld == true
end

function M.NoteOpened()
    if openCountHeld then
        return
    end
    Shared.AdjustOpenCount(1)
    openCountHeld = true
end

function M.NoteClosed()
    if not openCountHeld then
        return Shared.AdjustOpenCount(0)
    end
    openCountHeld = false
    return Shared.AdjustOpenCount(-1)
end

--- Advertise our toggle key via ModRef so two mods on the same key log a clear clash.
--- Does not block binding — authors/players decide whether to change keys.
---@param config table
---@param keyHint any
function M.ClaimToggleKey(config, keyHint)
    M.Ensure(config)
    local hint = tostring(keyHint or "unknown")
    local claimKey = Shared.KEY_CLAIM_PREFIX .. hint
    local owner = Shared.Get(claimKey)
    local me = tostring(instanceTag)

    if type(owner) == "string" and owner ~= "" and owner ~= me then
        -- Single Log() line (Util.Log already prefixes [ModMenu]).
        Util.Log(string.format(
            "KEY CONFLICT: %s already claimed by %q — this menu (%q) shares that bind. "
                .. "Both may toggle together (ok for same-author dual docks); "
                .. "unrelated mods should use different keys.",
            hint,
            owner,
            me
        ))
    elseif type(owner) == "string" and owner == me then
        Util.Log(string.format("Key %s already claimed by this instance (%q)", hint, me))
    else
        Util.Log(string.format("Key %s claimed by %q", hint, me))
    end

    -- Last Init wins the registry slot (still useful: next mod sees the latest owner).
    Shared.Set(claimKey, me)
end

return M

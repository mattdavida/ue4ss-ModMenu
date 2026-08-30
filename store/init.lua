--[[
  ModMenu.store — host-owned JSON key/value store.

  Public name is ModMenu.ConfigManager (facade + ConfigManager.lua shim):

    local ModMenu = require("ModMenu.ModMenu")
    local ConfigManager = ModMenu.ConfigManager
    -- or: require("ModMenu.ConfigManager") / require("ModMenu.core.store")

    ConfigManager.Init({
        id = "MyMod",
        defaults = { volume = 1 },
    })
    ConfigManager.Get("volume")
    ConfigManager.Set("volume", 0.5)  -- writes Mods/MyMod/config.json

  JSON-safe values only (bool, number, string, table, nil). Hosts still own
  when to Set and how to apply. Unknown file keys are kept.
  This module must not require ModMenu.ModMenu (no cycle).
]]

local Json = require("ModMenu.store.json")
local Paths = require("ModMenu.store.paths")

local M = {}

local LIB_NAME = "ConfigManager"

local initialized = false
local modId = nil
local filePath = nil
local autosave = true
local defaults = {}
local store = {}
local loadFailed = false

local function Log(msg)
    print(string.format("[%s] %s\n", LIB_NAME, tostring(msg)))
end

---@param value any
---@param seen table|nil
---@return any
local function Copy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        error(LIB_NAME .. ": circular table")
    end
    seen[value] = true
    local out = {}
    for k, v in pairs(value) do
        out[Copy(k, seen)] = Copy(v, seen)
    end
    seen[value] = nil
    return out
end

---@param a any
---@param b any
---@return boolean
local function Equal(a, b)
    if a == b then
        return true
    end
    if type(a) ~= type(b) or type(a) ~= "table" then
        return false
    end
    for k, v in pairs(a) do
        if not Equal(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

---@param path string
---@return table|nil, string|nil
local function ReadFile(path)
    local f, err = io.open(path, "r")
    if not f then
        return nil, err
    end
    local text = f:read("*a")
    f:close()
    if type(text) ~= "string" or text:match("^%s*$") then
        return {}
    end
    local ok, decoded = pcall(Json.DecodeObject, text)
    if not ok then
        return nil, tostring(decoded)
    end
    return decoded
end

---@param path string
---@param text string
---@return boolean, string|nil
local function WriteFile(path, text)
    local tmp = path .. ".tmp"
    local f, err = io.open(tmp, "w")
    if not f then
        f, err = io.open(path, "w")
        if not f then
            return false, err
        end
        f:write(text)
        if text:sub(-1) ~= "\n" then
            f:write("\n")
        end
        f:close()
        return true
    end
    f:write(text)
    if text:sub(-1) ~= "\n" then
        f:write("\n")
    end
    f:close()
    os.remove(path)
    local renamed, renameErr = os.rename(tmp, path)
    if renamed then
        return true
    end
    os.remove(tmp)
    local f2, err2 = io.open(path, "w")
    if not f2 then
        return false, renameErr or err2
    end
    f2:write(text)
    if text:sub(-1) ~= "\n" then
        f2:write("\n")
    end
    f2:close()
    return true
end

local function EnsureInit()
    if not initialized then
        error(LIB_NAME .. ": call Init first")
    end
end

local function MergeLoaded(loaded)
    store = Copy(defaults)
    if type(loaded) ~= "table" then
        return
    end
    for k, v in pairs(loaded) do
        if type(k) == "string" then
            store[k] = Copy(v)
        end
    end
end

--- Initialize the store and load config.json if present. Safe to call again.
---@param opts { id: string, defaults?: table, file?: string, autosave?: boolean }
---@return table
function M.Init(opts)
    opts = opts or {}
    if type(opts.id) ~= "string" or opts.id == "" then
        error(LIB_NAME .. ".Init: id must be a non-empty string")
    end
    if opts.defaults ~= nil and type(opts.defaults) ~= "table" then
        error(LIB_NAME .. ".Init: defaults must be a table")
    end
    if opts.defaults ~= nil and not Json.IsSafe(opts.defaults) then
        error(LIB_NAME .. ".Init: defaults must be JSON-safe")
    end

    modId = opts.id
    autosave = opts.autosave ~= false
    defaults = Copy(opts.defaults or {})
    filePath = Paths.ResolveFile(modId, opts.file)
    loadFailed = false

    if Paths.FileExists(filePath) then
        local loaded, err = ReadFile(filePath)
        if loaded == nil then
            loadFailed = true
            MergeLoaded(nil)
            Log(string.format("%s: failed to parse %s — %s (file left untouched)", modId, filePath, tostring(err)))
            initialized = true
            return M
        end
        MergeLoaded(loaded)
        Log(string.format("%s: loaded %s", modId, filePath))
    else
        MergeLoaded(nil)
        Log(string.format("%s: no config yet (%s)", modId, filePath))
    end
    initialized = true
    return M
end

---@return string|nil
function M.File()
    return filePath
end

--- Current value, or the Init default if unset. Tables are copies.
---@param key string
---@return any
function M.Get(key)
    EnsureInit()
    if type(key) ~= "string" or key == "" then
        error(LIB_NAME .. ".Get: key must be a non-empty string")
    end
    local value = store[key]
    if value == nil then
        value = defaults[key]
    end
    return Copy(value)
end

--- Write a key. nil removes it (Get then returns the default). Autosaves.
---@param key string
---@param value any
function M.Set(key, value)
    EnsureInit()
    if type(key) ~= "string" or key == "" then
        error(LIB_NAME .. ".Set: key must be a non-empty string")
    end
    if value ~= nil and not Json.IsSafe(value) then
        error(LIB_NAME .. ".Set: value must be JSON-safe")
    end

    local current = store[key]
    if current == nil then
        current = defaults[key]
    end
    if Equal(current, value) then
        return
    end

    if value == nil then
        store[key] = nil
    else
        store[key] = Copy(value)
    end
    loadFailed = false
    if autosave then
        M.Save()
    end
end

--- Write the store to disk now. No-op if Init never loaded a path.
function M.Save()
    EnsureInit()
    if loadFailed then
        Log(string.format("%s: skip save, %s did not parse", modId, filePath))
        return false
    end
    local out = {}
    for k, v in pairs(store) do
        out[k] = v
    end
    local ok, err = WriteFile(filePath, Json.Encode(out, 0))
    if not ok then
        Log(string.format("%s: save failed %s — %s", modId, filePath, tostring(err)))
        return false
    end
    return true
end

return M

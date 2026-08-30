--[[
  ModMenu.ConfigManager — tiny JSON key/value store (optional; host-owned).

  Same singleton as ModMenu.ConfigManager on the facade:

    local ModMenu = require("ModMenu.ModMenu")
    local ConfigManager = ModMenu.ConfigManager
    -- or: require("ModMenu.ConfigManager")

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

---@param s string
---@return string
local function EscapePattern(s)
    return (s:gsub("(%W)", "%%%1"))
end

---@param path string
---@return string
local function NormalizePath(path)
    return (tostring(path):gsub("\\", "/"))
end

---@param path string
---@return boolean
local function FileExists(path)
    local f = io.open(path, "r")
    if not f then
        return false
    end
    f:close()
    return true
end

---@param dir string
---@return boolean
local function LooksLikeModDir(dir)
    return FileExists(dir .. "/Scripts/main.lua")
        or FileExists(dir .. "/enabled.txt")
        or FileExists(dir .. "/config.json")
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

---@param value any
---@return boolean
local function IsJsonSafe(value)
    local t = type(value)
    if value == nil or t == "boolean" or t == "string" then
        return true
    end
    if t == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    if t ~= "table" then
        return false
    end
    for k, v in pairs(value) do
        local kt = type(k)
        if kt ~= "string" and kt ~= "number" then
            return false
        end
        if not IsJsonSafe(v) then
            return false
        end
    end
    return true
end

---@param n number
---@return string
local function EncodeNumber(n)
    if n ~= n or n == math.huge or n == -math.huge then
        error(LIB_NAME .. ": cannot encode nan/inf")
    end
    if n == math.floor(n) and math.abs(n) < 1e15 then
        return string.format("%.0f", n)
    end
    return tostring(n)
end

---@param s string
---@return string
local function EncodeString(s)
    s = s:gsub(".", function(ch)
        local b = string.byte(ch)
        if ch == "\\" then
            return "\\\\"
        end
        if ch == "\"" then
            return "\\\""
        end
        if b == 8 then
            return "\\b"
        end
        if b == 12 then
            return "\\f"
        end
        if b == 10 then
            return "\\n"
        end
        if b == 13 then
            return "\\r"
        end
        if b == 9 then
            return "\\t"
        end
        if b < 32 then
            return string.format("\\u%04x", b)
        end
        return ch
    end)
    return "\"" .. s .. "\""
end

---@param t table
---@return boolean
local function IsArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
            return false
        end
        if k > n then
            n = k
        end
    end
    if n == 0 then
        return false
    end
    for i = 1, n do
        if t[i] == nil then
            return false
        end
    end
    return true
end

---@param value any
---@param level integer
---@return string
local function Encode(value, level)
    if value == nil then
        return "null"
    end
    local t = type(value)
    if t == "boolean" then
        return value and "true" or "false"
    end
    if t == "number" then
        return EncodeNumber(value)
    end
    if t == "string" then
        return EncodeString(value)
    end
    if t ~= "table" then
        error(LIB_NAME .. ": cannot encode " .. t)
    end

    level = level or 0
    local inner = level + 1
    local pad = string.rep("  ", inner)
    local close = string.rep("  ", level)

    if IsArray(value) then
        if #value == 0 then
            return "[]"
        end
        local parts = {}
        for i = 1, #value do
            parts[#parts + 1] = pad .. Encode(value[i], inner)
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. close .. "]"
    end

    local keys = {}
    for k in pairs(value) do
        if type(k) ~= "string" then
            error(LIB_NAME .. ": object keys must be strings")
        end
        keys[#keys + 1] = k
    end
    if #keys == 0 then
        return "{}"
    end
    table.sort(keys)
    local parts = {}
    for i = 1, #keys do
        local k = keys[i]
        parts[#parts + 1] = pad .. EncodeString(k) .. ": " .. Encode(value[k], inner)
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. close .. "}"
end

---@param s string
---@param i integer
---@return integer
local function SkipWs(s, i)
    local from = s:find("[^ \t\n\r]", i)
    return from or (#s + 1)
end

local ParseValue

---@param s string
---@param i integer
---@return string, integer
local function ParseString(s, i)
    i = i + 1
    local out = {}
    while i <= #s do
        local ch = s:sub(i, i)
        if ch == "\"" then
            return table.concat(out), i + 1
        end
        if ch ~= "\\" then
            out[#out + 1] = ch
            i = i + 1
        else
            local n = s:sub(i + 1, i + 1)
            local map = {
                ["\""] = "\"",
                ["\\"] = "\\",
                ["/"] = "/",
                b = "\b",
                f = "\f",
                n = "\n",
                r = "\r",
                t = "\t",
            }
            if map[n] then
                out[#out + 1] = map[n]
                i = i + 2
            elseif n == "u" then
                local hex = s:sub(i + 2, i + 5)
                if not hex:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
                    error("bad \\u escape")
                end
                local cp = tonumber(hex, 16)
                if cp < 128 then
                    out[#out + 1] = string.char(cp)
                elseif cp < 2048 then
                    out[#out + 1] = string.char(192 + math.floor(cp / 64), 128 + (cp % 64))
                else
                    out[#out + 1] = string.char(
                        224 + math.floor(cp / 4096),
                        128 + (math.floor(cp / 64) % 64),
                        128 + (cp % 64)
                    )
                end
                i = i + 6
            else
                error("bad escape")
            end
        end
    end
    error("unterminated string")
end

---@param s string
---@param i integer
---@return number, integer
local function ParseNumber(s, i)
    local slice = s:sub(i)
    local num = slice:match("^-?%d+%.%d+[eE][%+%-]?%d+")
        or slice:match("^-?%d+[eE][%+%-]?%d+")
        or slice:match("^-?%d+%.%d+")
        or slice:match("^-?%d+")
    if not num then
        error("bad number")
    end
    return tonumber(num), i + #num
end

---@param s string
---@param i integer
---@return table, integer
local function ParseArray(s, i)
    i = SkipWs(s, i + 1)
    local arr = {}
    if s:sub(i, i) == "]" then
        return arr, i + 1
    end
    while true do
        local v
        v, i = ParseValue(s, i)
        arr[#arr + 1] = v
        i = SkipWs(s, i)
        local ch = s:sub(i, i)
        if ch == "]" then
            return arr, i + 1
        end
        if ch ~= "," then
            error("expected comma in array")
        end
        i = SkipWs(s, i + 1)
    end
end

---@param s string
---@param i integer
---@return table, integer
local function ParseObject(s, i)
    i = SkipWs(s, i + 1)
    local obj = {}
    if s:sub(i, i) == "}" then
        return obj, i + 1
    end
    while true do
        if s:sub(i, i) ~= "\"" then
            error("expected string key")
        end
        local key
        key, i = ParseString(s, i)
        i = SkipWs(s, i)
        if s:sub(i, i) ~= ":" then
            error("expected colon")
        end
        local v
        v, i = ParseValue(s, SkipWs(s, i + 1))
        obj[key] = v
        i = SkipWs(s, i)
        local ch = s:sub(i, i)
        if ch == "}" then
            return obj, i + 1
        end
        if ch ~= "," then
            error("expected comma in object")
        end
        i = SkipWs(s, i + 1)
    end
end

function ParseValue(s, i)
    i = SkipWs(s, i)
    local ch = s:sub(i, i)
    if ch == "\"" then
        return ParseString(s, i)
    end
    if ch == "{" then
        return ParseObject(s, i)
    end
    if ch == "[" then
        return ParseArray(s, i)
    end
    if ch == "t" and s:sub(i, i + 3) == "true" then
        return true, i + 4
    end
    if ch == "f" and s:sub(i, i + 4) == "false" then
        return false, i + 5
    end
    if ch == "n" and s:sub(i, i + 3) == "null" then
        return nil, i + 4
    end
    if ch == "-" or ch:match("%d") then
        return ParseNumber(s, i)
    end
    error("unexpected " .. tostring(ch))
end

---@param text string
---@return table
local function DecodeObject(text)
    local value, i = ParseValue(text, 1)
    i = SkipWs(text, i)
    if i <= #text then
        error("trailing junk")
    end
    if type(value) ~= "table" or IsArray(value) then
        error("root must be an object")
    end
    return value
end

---@param id string
---@return string|nil
local function CallerModRoot(id)
    local needle = EscapePattern(id)
    for level = 3, 12 do
        local info = debug.getinfo(level, "S")
        if info and type(info.source) == "string" then
            local src = info.source
            if src:sub(1, 1) == "@" then
                src = src:sub(2)
            end
            src = NormalizePath(src)
            local root = src:match("^(.*[\\/]Mods[\\/]" .. needle .. ")[\\/]")
            if root then
                return root
            end
        end
    end
    return nil
end

---@param id string
---@param explicit string|nil
---@return string
local function ResolveFile(id, explicit)
    if type(explicit) == "string" and explicit ~= "" then
        return NormalizePath(explicit)
    end

    local root = CallerModRoot(id)
    if root then
        return root .. "/config.json"
    end

    local candidates = {
        "ue4ss/Mods/" .. id .. "/config.json",
        "Mods/" .. id .. "/config.json",
    }
    for i = 1, #candidates do
        local path = candidates[i]
        local dir = path:match("^(.*)/[^/]+$")
        if dir and LooksLikeModDir(dir) then
            return path
        end
    end
    return candidates[1]
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
    local ok, decoded = pcall(DecodeObject, text)
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
    if opts.defaults ~= nil and not IsJsonSafe(opts.defaults) then
        error(LIB_NAME .. ".Init: defaults must be JSON-safe")
    end

    modId = opts.id
    autosave = opts.autosave ~= false
    defaults = Copy(opts.defaults or {})
    filePath = ResolveFile(modId, opts.file)
    loadFailed = false

    if FileExists(filePath) then
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
    if value ~= nil and not IsJsonSafe(value) then
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
    local ok, err = WriteFile(filePath, Encode(out, 0))
    if not ok then
        Log(string.format("%s: save failed %s — %s", modId, filePath, tostring(err)))
        return false
    end
    return true
end

return M

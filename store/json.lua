--[[
  ModMenu.store.json — JSON-safe encode/decode for host config.json.
]]

local M = {}

local LIB_NAME = "ConfigManager"

---@param value any
---@return boolean
function M.IsSafe(value)
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
        if not M.IsSafe(v) then
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
function M.Encode(value, level)
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
            parts[#parts + 1] = pad .. M.Encode(value[i], inner)
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
        parts[#parts + 1] = pad .. EncodeString(k) .. ": " .. M.Encode(value[k], inner)
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

ParseValue = function(s, i)
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
function M.DecodeObject(text)
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

return M

--[[
  No-game Lua suite. C# injects _REPO (ModMenu repo root) and a require searcher.
  Prints one JSON object to stdout.
]]

local passed = 0
local failed = 0
local failures = {}

local function encode(value)
    local t = type(value)
    if value == nil then
        return "null"
    end
    if t == "boolean" then
        return value and "true" or "false"
    end
    if t == "number" then
        return tostring(value)
    end
    if t == "string" then
        return string.format("%q", value)
    end
    if t ~= "table" then
        return string.format("%q", tostring(value))
    end
    local max = 0
    local asObject = false
    for k in pairs(value) do
        if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
            asObject = true
            break
        end
        if k > max then
            max = k
        end
    end
    if not asObject then
        local parts = {}
        for i = 1, max do
            parts[i] = encode(value[i])
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(value) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    local parts = {}
    for i = 1, #keys do
        local k = keys[i]
        parts[#parts + 1] = encode(tostring(k)) .. ":" .. encode(value[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function deep_eq(a, b)
    if a == b then
        return true
    end
    if type(a) ~= type(b) then
        return false
    end
    if type(a) == "number" then
        local d = a - b
        if d < 0 then
            d = -d
        end
        return d < 1e-9
    end
    if type(a) ~= "table" then
        return false
    end
    for k, v in pairs(a) do
        if not deep_eq(v, b[k]) then
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

local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        return
    end
    failed = failed + 1
    failures[#failures + 1] = name .. (detail and (": " .. detail) or "")
end

function assert_true(name, cond)
    check(name, cond == true, "expected true")
end

function assert_eq(name, got, want)
    if deep_eq(got, want) then
        passed = passed + 1
        return
    end
    failed = failed + 1
    failures[#failures + 1] = name .. ": got " .. encode(got) .. " want " .. encode(want)
end

local specs = {
    "store_spec.lua",
    "dock_spec.lua",
    "options_spec.lua",
}

local here = _REPO .. "/tooling/lua/"
for i = 1, #specs do
    local path = here .. specs[i]
    local chunk, err = loadfile(path)
    if not chunk then
        check("load " .. specs[i], false, tostring(err))
    else
        local ok, runErr = pcall(chunk)
        if not ok then
            check("run " .. specs[i], false, tostring(runErr))
        end
    end
end

print(encode({
    ok = failed == 0,
    passed = passed,
    failed = failed,
    failures = failures,
}))

return failed == 0

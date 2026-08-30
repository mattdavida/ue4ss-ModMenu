--[[
  ModMenu.store.paths — resolve Mods/<id>/config.json for the host store.
]]

local M = {}

---@param s string
---@return string
local function EscapePattern(s)
    return (s:gsub("(%W)", "%%%1"))
end

---@param path string
---@return string
function M.Normalize(path)
    return (tostring(path):gsub("\\", "/"))
end

---@param path string
---@return boolean
function M.FileExists(path)
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
    return M.FileExists(dir .. "/Scripts/main.lua")
        or M.FileExists(dir .. "/enabled.txt")
        or M.FileExists(dir .. "/config.json")
end

---@param id string
---@return string|nil
local function CallerModRoot(id)
    if type(debug) ~= "table" or type(debug.getinfo) ~= "function" then
        return nil
    end

    local needle = EscapePattern(id)
    for level = 3, 12 do
        local info = debug.getinfo(level, "S")
        if info and type(info.source) == "string" then
            local src = info.source
            if src:sub(1, 1) == "@" then
                src = src:sub(2)
            end
            src = M.Normalize(src)
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
function M.ResolveFile(id, explicit)
    if type(explicit) == "string" and explicit ~= "" then
        return M.Normalize(explicit)
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

return M

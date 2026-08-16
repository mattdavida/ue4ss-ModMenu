--[[
  ModMenu.shell.registry — sections, values, Register, Get/Set, live widget apply.
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local Options = require("ModMenu.core.options")
local Widgets = require("ModMenu.widgets.init")
local Session = require("ModMenu.shell.session")
local Build = require("ModMenu.shell.build")

local Log = Util.Log
local IsValid = Util.IsValid
local ToPlainString = Util.ToPlainString
local ValueKey = Util.ValueKey
local SetLabelText = Umg.SetLabelText
local NormalizeOptions = Options.NormalizeOptions
local Dropdown = Widgets.get("dropdown")

local M = {}

local function ValidateItem(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if type(item) ~= "table" then
        error(prefix .. " must be a table")
    end
    local t = item.type
    local widget = Widgets.get(t)
    if not widget then
        error(prefix .. " unsupported type '" .. tostring(t) .. "' (" .. Widgets.typeList() .. ")")
    end
    if widget.validate then
        widget.validate(item, sectionId, index)
    end
end

--- Walk top-level + row.children items (depth 1 nesting).
local function FindItemById(items, itemId, typeName)
    for _, item in ipairs(items or {}) do
        if item.id == itemId and (typeName == nil or item.type == typeName) then
            return item
        end
        if item.type == "row" and type(item.items) == "table" then
            for _, child in ipairs(item.items) do
                if child.id == itemId and (typeName == nil or child.type == typeName) then
                    return child
                end
            end
        end
    end
    return nil
end

local function ValidateSection(section)
    if type(section) ~= "table" then
        error("Register() expects a section table")
    end
    if section.id == nil or section.id == "" then
        error("Register() section requires .id")
    end
    if type(section.items) ~= "table" then
        error("Register(" .. tostring(section.id) .. ") requires .items array")
    end
    for i, item in ipairs(section.items) do
        ValidateItem(item, section.id, i)
    end
end

local function RebuildIfOpen(S)
    if not S.menuOpen then
        return
    end
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            if Build.Ensure(S) then
                Build.BuildContent(S)
                Session.EnsureVisible(S)
                Input.ClearClickState()
            end
        end)
        if not ok then
            Log("Register rebuild failed: " .. tostring(err))
            Session.EnsureVisible(S)
        end
    end)
end

--- Apply a stored value to any live control with that valueKey.
local function ApplyLive(S, vkey, value)
    local ctx = S.makeWidgetCtx()
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.valueKey == vkey then
            local widget = Widgets.get(ctrl.kind)
            if widget and widget.apply then
                widget.apply(ctrl, value, ctx)
            end
        end
    end
end

function M.Register(S, section)
    ValidateSection(section)

    local copy = {
        id = section.id,
        title = section.title or section.id,
        items = section.items,
    }

    -- Seed defaults into values store.
    for _, item in ipairs(copy.items) do
        local widget = Widgets.get(item.type)
        if widget and widget.seed then
            widget.seed(copy.id, item, S.values)
        end
    end

    local existing = S.sectionIndexById[copy.id]
    if existing then
        S.sections[existing] = copy
        Log("Updated section: " .. copy.id)
    else
        table.insert(S.sections, copy)
        S.sectionIndexById[copy.id] = #S.sections
        Log("Registered section: " .. copy.id .. " (" .. tostring(#copy.items) .. " items)")
    end

    RebuildIfOpen(S)
end

function M.Get(S, sectionId, itemId)
    return S.values[ValueKey(sectionId, itemId)]
end

function M.Set(S, sectionId, itemId, value)
    local vkey = ValueKey(sectionId, itemId)
    S.values[vkey] = value
    ApplyLive(S, vkey, value)
end

function M.SetLabel(S, sectionId, itemId, text)
    local idx = S.sectionIndexById[sectionId]
    if not idx then
        return false
    end
    local section = S.sections[idx]
    local item = FindItemById(section.items, itemId, "label")
    if not item then
        return false
    end
    item.label = tostring(text)
    local vkey = ValueKey(sectionId, itemId)
    local ctx = S.makeWidgetCtx()
    local labelWidget = Widgets.get("label")
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "label" and ctrl.valueKey == vkey and IsValid(ctrl.widget) then
            if labelWidget and labelWidget.apply then
                labelWidget.apply(ctrl, item.label, ctx)
            end
        end
    end
    return true
end

function M.SetButtonLabel(S, sectionId, itemId, text)
    local idx = S.sectionIndexById[sectionId]
    if not idx then
        return false
    end
    local section = S.sections[idx]
    local item = FindItemById(section.items, itemId, "button")
    if not item then
        return false
    end
    item.label = tostring(text)
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "button"
            and ctrl.sectionId == sectionId
            and ctrl.item
            and ctrl.item.id == itemId
        then
            -- Do not gate on IsValid(labelWidget) — Button child TextBlocks often report invalid.
            SetLabelText(ctrl.labelWidget, item.label)
            return true
        end
    end
    return true
end

function M.SetButtonEnabled(S, sectionId, itemId, enabled)
    local idx = S.sectionIndexById[sectionId]
    if not idx then
        return false
    end
    local section = S.sections[idx]
    local item = FindItemById(section.items, itemId, "button")
    if not item then
        return false
    end
    local on = enabled and true or false
    item.enabled = on
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "button"
            and ctrl.sectionId == sectionId
            and ctrl.item
            and ctrl.item.id == itemId
        then
            ctrl.enabled = on
            if IsValid(ctrl.widget) then
                pcall(function()
                    ctrl.widget:SetIsEnabled(on)
                end)
            end
            return true
        end
    end
    return true
end

--- Replace dropdown options.
--- Searchable dropdowns refresh rows in place when live; others rebuild the panel.
function M.SetOptions(S, sectionId, itemId, options, selectedValue)
    local idx = S.sectionIndexById[sectionId]
    if not idx then
        return false
    end
    local section = S.sections[idx]
    for _, item in ipairs(section.items) do
        if item.id == itemId and item.type == "dropdown" then
            if type(options) ~= "table" or #options == 0 then
                error("SetOptions requires non-empty options array")
            end
            local list = NormalizeOptions(options)
            item.options = list
            local vkey = ValueKey(sectionId, itemId)
            if selectedValue == false then
                S.values[vkey] = nil
                item.default = nil
            elseif selectedValue ~= nil then
                local plain = ToPlainString(selectedValue) or selectedValue
                S.values[vkey] = plain
                item.default = plain
            end

            -- Prefer in-place refresh for searchable lists (category filter, etc.).
            local live = nil
            for _, ctrl in ipairs(S.liveControls) do
                if ctrl.kind == "dropdown" and ctrl.valueKey == vkey then
                    live = ctrl
                    break
                end
            end

            if S.menuOpen and live and live.searchable and live.listBox ~= nil then
                Dropdown.refreshLive(live, list, selectedValue, S.values, vkey)
                Log(string.format(
                    "SetOptions(%s.%s) refreshed searchable list (%d options)",
                    tostring(sectionId),
                    tostring(itemId),
                    #list
                ))
                return true
            end

            if S.menuOpen then
                ExecuteInGameThread(function()
                    local ok, err = pcall(function()
                        if Build.Ensure(S) then
                            Build.BuildContent(S)
                            Session.EnsureVisible(S)
                            Input.ClearClickState()
                        end
                    end)
                    if not ok then
                        Log("SetOptions rebuild failed: " .. tostring(err))
                        Session.EnsureVisible(S)
                    else
                        Log(string.format(
                            "SetOptions(%s.%s) rebuilt UI with %d options",
                            tostring(sectionId),
                            tostring(itemId),
                            #list
                        ))
                    end
                end)
            end
            return true
        end
    end
    return false
end

function M.ListSections(S)
    local ids = {}
    for _, section in ipairs(S.sections) do
        table.insert(ids, section.id)
    end
    return ids
end

return M

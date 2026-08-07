--[[
  ModMenu.core.umg — StaticConstructObject helpers and common UMG controls.
]]

local Util = require("ModMenu.core.util")

local M = {}

local defaults = {
    fontItem = 24,
}

function M.SetDefaults(opts)
    opts = opts or {}
    if opts.fontItem ~= nil then
        defaults.fontItem = opts.fontItem
    end
end

local function FindClass(path)
    local cls = StaticFindObject(path)
    if not Util.IsValid(cls) then
        error("StaticFindObject failed: " .. path)
    end
    return cls
end

function M.Construct(classPath, outer, name)
    local cls = FindClass(classPath)
    local obj = StaticConstructObject(cls, outer, FName(name))
    if not Util.IsValid(obj) then
        error("StaticConstructObject failed: " .. classPath .. " as " .. name)
    end
    return obj
end

function M.StyleText(textBlock, size, color)
    color = color or { R = 0.95, G = 0.95, B = 0.98, A = 1.0 }
    pcall(function()
        if textBlock.Font then
            textBlock.Font.Size = size or defaults.fontItem
        end
        textBlock:SetColorAndOpacity({
            SpecifiedColor = color,
            ColorUseRule = 0,
        })
    end)
end

--- Do not gate on IsValid() — child TextBlocks inside Buttons often report invalid.
function M.SetLabelText(textBlock, str)
    if textBlock == nil then
        return false
    end
    local ok = pcall(function()
        textBlock:SetText(FText(tostring(str)))
    end)
    return ok == true
end

--- Soft-wrap TextBlock to its laid-out width (needed for long hint / status labels).
function M.EnableAutoWrap(textBlock)
    if textBlock == nil then
        return
    end
    pcall(function()
        textBlock:SetAutoWrapText(true)
    end)
    pcall(function()
        textBlock.AutoWrapText = true
    end)
end

--- HAlign_Fill so AutoWrapText uses the panel width instead of desired (unwrapped) width.
function M.FillVerticalSlot(slot)
    if slot == nil then
        return
    end
    pcall(function()
        slot:SetHorizontalAlignment(0) -- EHorizontalAlignment::HAlign_Fill
    end)
end

function M.AddSpacer(parent, name, height)
    local spacer = M.Construct("/Script/UMG.Spacer", parent, name)
    pcall(function()
        spacer:SetSize({ X = 1, Y = height or 12 })
    end)
    parent:AddChildToVerticalBox(spacer)
end

function M.CreateLabeledToggle(outer, namePrefix, caption, initialChecked, fontSize)
    local check = M.Construct("/Script/UMG.CheckBox", outer, namePrefix .. "_Check")
    local label = M.Construct("/Script/UMG.TextBlock", check, namePrefix .. "_Label")
    M.StyleText(label, fontSize or defaults.fontItem)
    M.SetLabelText(label, caption)
    check:SetContent(label)
    check:SetIsChecked(initialChecked and true or false)
    return check, label
end

function M.CreateTextButton(outer, namePrefix, caption, bgColor, textColor, fontSize)
    local button = M.Construct("/Script/UMG.Button", outer, namePrefix .. "_Btn")
    local label = M.Construct("/Script/UMG.TextBlock", button, namePrefix .. "_BtnLabel")
    M.StyleText(label, fontSize or defaults.fontItem, textColor)
    M.SetLabelText(label, caption)
    pcall(function()
        button:SetContent(label)
        button:SetBackgroundColor(bgColor or { R = 0.18, G = 0.22, B = 0.32, A = 1.0 })
    end)
    return button, label
end

return M

--[[
  ModMenu.core.umg — StaticConstructObject helpers and common UMG controls.
]]

local Util = require("ModMenu.core.util")
local Theme = require("ModMenu.core.theme")

local M = {}

local defaults = {
    fontItem = 16,
    colors = nil, ---@type table|nil resolved in Init
}

function M.SetDefaults(opts)
    opts = opts or {}
    if opts.fontItem ~= nil then
        defaults.fontItem = opts.fontItem
    end
    if opts.colors ~= nil then
        defaults.colors = opts.colors
    end
end

local function Colors()
    return defaults.colors or Theme.Preset("light")
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
    color = color or Colors().textPrimary
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
    return spacer
end

--- Attach a widget to ctx.contentBox (VerticalBox or HorizontalBox via ctx.layout).
--- opts: fill (HBox fill), fillWeight, padLeft/Right/Top/Bottom, vAlign, fillVertical (VBox)
function M.AddToContent(ctx, widget, opts)
    opts = opts or {}
    local parent = ctx.contentBox
    local slot
    if ctx.layout == "horizontal" then
        slot = parent:AddChildToHorizontalBox(widget)
        pcall(function()
            if opts.fill then
                slot:SetSize({ SizeRule = 1, Value = opts.fillWeight or 1.0 })
            else
                slot:SetSize({ SizeRule = 0, Value = 0.0 })
            end
            slot:SetPadding({
                Left = opts.padLeft or 0,
                Top = opts.padTop or 0,
                Right = opts.padRight or 6,
                Bottom = opts.padBottom or 0,
            })
            -- EVerticalAlignment::VAlign_Center = 2
            slot:SetVerticalAlignment(opts.vAlign or 2)
        end)
    else
        slot = parent:AddChildToVerticalBox(widget)
        if opts.fillVertical then
            M.FillVerticalSlot(slot)
        end
    end
    return slot
end

--- Trailing pad after an item. No-op in horizontal rows (slot padding handles gaps).
function M.AddItemPad(ctx, name, size)
    if ctx.layout == "horizontal" then
        return nil
    end
    return M.AddSpacer(ctx.contentBox, name, size or 8)
end

--- Style an EditableTextBox from theme field tokens.
--- The engine's default slate box is light-grey; WidgetStyle.BackgroundColor
--- often does not tint it. Hide those brushes and let the wrapping Border
--- (CreateLabeledEditable / dropdown search) be the visible fill.
function M.StyleEditableTextBox(edit, fontSize)
    if edit == nil then
        return
    end
    local colors = Colors()
    local fill = colors.fieldBg
    local dark = colors.fieldText
    local hint = colors.fieldHint
    local slateFill = { SpecifiedColor = fill, ColorUseRule = 0 }
    local slateText = { SpecifiedColor = dark, ColorUseRule = 0 }
    local slateHint = { SpecifiedColor = hint, ColorUseRule = 0 }

    pcall(function()
        edit:SetForegroundColor(dark)
    end)
    pcall(function()
        local style = edit.WidgetStyle
        if style == nil then
            return
        end
        pcall(function()
            style.ForegroundColor = slateText
        end)
        pcall(function()
            style.BackgroundColor = slateFill
        end)
        pcall(function()
            style.FocusedForegroundColor = slateText
        end)
        for _, key in ipairs({
            "BackgroundImageNormal",
            "BackgroundImageHovered",
            "BackgroundImageFocused",
            "BackgroundImageReadOnly",
        }) do
            local brush = style[key]
            if brush ~= nil then
                pcall(function()
                    brush.TintColor = slateFill
                    -- ESlateBrushDrawType::NoDrawType — Border behind the field is the fill.
                    brush.DrawAs = 0
                end)
            end
        end
        if style.TextStyle ~= nil then
            if style.TextStyle.ColorAndOpacity ~= nil then
                style.TextStyle.ColorAndOpacity = slateText
            end
            if style.TextStyle.Font ~= nil and style.TextStyle.Font.Size ~= nil and fontSize then
                style.TextStyle.Font.Size = fontSize
            end
        end
        if style.HintTextStyle ~= nil then
            if style.HintTextStyle.ColorAndOpacity ~= nil then
                style.HintTextStyle.ColorAndOpacity = slateHint
            end
            if style.HintTextStyle.Font ~= nil and style.HintTextStyle.Font.Size ~= nil and fontSize then
                style.HintTextStyle.Font.Size = fontSize
            end
        end
        edit.WidgetStyle = style
    end)
end

--- Labeled single-line field: HorizontalBox(label + SizeBox(Border(EditableTextBox))).
--- Field chrome follows the active theme (light fields on light, dark on dark).
--- @return root, editBox, label
function M.CreateLabeledEditable(outer, namePrefix, caption, initialText, opts)
    opts = opts or {}
    local fontSize = opts.fontSize or defaults.fontItem
    local fieldWidth = opts.fieldWidth or 96
    local hint = opts.hint

    local root = M.Construct("/Script/UMG.HorizontalBox", outer, namePrefix .. "_Row")

    local label = M.Construct("/Script/UMG.TextBlock", root, namePrefix .. "_Label")
    M.StyleText(label, fontSize)
    M.SetLabelText(label, caption or "")

    local labelHost = label
    if type(opts.labelWidth) == "number" and opts.labelWidth > 0 then
        local labelSize = M.Construct("/Script/UMG.SizeBox", root, namePrefix .. "_LabelSize")
        pcall(function()
            labelSize:SetWidthOverride(opts.labelWidth)
            labelSize:SetContent(label)
        end)
        labelHost = labelSize
    end

    local labelSlot = root:AddChildToHorizontalBox(labelHost)
    pcall(function()
        labelSlot:SetSize({ SizeRule = 0, Value = 0.0 })
        labelSlot:SetPadding({ Left = 0, Top = 4, Right = 8, Bottom = 4 })
        labelSlot:SetVerticalAlignment(2)
    end)

    local sizeBox = M.Construct("/Script/UMG.SizeBox", root, namePrefix .. "_Size")
    pcall(function()
        sizeBox:SetWidthOverride(fieldWidth)
    end)

    local border = M.Construct("/Script/UMG.Border", sizeBox, namePrefix .. "_Border")
    pcall(function()
        border:SetBrushColor(Colors().fieldBg)
        border:SetPadding({ Left = 8, Top = 4, Right = 8, Bottom = 4 })
    end)

    local edit = M.Construct("/Script/UMG.EditableTextBox", border, namePrefix .. "_Edit")
    pcall(function()
        edit:SetText(FText(tostring(initialText or "")))
        if hint ~= nil and hint ~= "" then
            edit:SetHintText(FText(tostring(hint)))
        end
    end)
    M.StyleEditableTextBox(edit, fontSize)
    pcall(function()
        border:SetContent(edit)
        sizeBox:SetContent(border)
    end)

    local fieldSlot = root:AddChildToHorizontalBox(sizeBox)
    pcall(function()
        if opts.fillField then
            fieldSlot:SetSize({ SizeRule = 1, Value = 1.0 })
        else
            fieldSlot:SetSize({ SizeRule = 0, Value = 0.0 })
        end
        fieldSlot:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        fieldSlot:SetVerticalAlignment(2)
    end)

    return root, edit, label
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
    M.StyleText(label, fontSize or defaults.fontItem, textColor or Colors().buttonText)
    M.SetLabelText(label, caption)
    pcall(function()
        button:SetContent(label)
        button:SetBackgroundColor(bgColor or Colors().buttonBg)
        -- MouseDown: pressed state as soon as the pointer goes down (helps IsPressed poll).
        if button.SetClickMethod then
            button:SetClickMethod(1)
        end
    end)
    return button, label
end

return M

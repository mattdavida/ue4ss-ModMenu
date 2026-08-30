--[[
  ModMenu.shell.build — construct / destroy the UMG tree and rebuild section content.
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Theme = require("ModMenu.core.theme")
local Instance = require("ModMenu.core.instance")
local InputMode = require("ModMenu.core.inputmode")
local Cursor = require("ModMenu.core.cursor")
local Widgets = require("ModMenu.widgets.init")
local Session = require("ModMenu.shell.session")
local Dock = require("ModMenu.shell.dock")
local Collapse = require("ModMenu.shell.collapse")
local Tabs = require("ModMenu.shell.tabs")
local Confirm = require("ModMenu.shell.confirm")

local Log = Util.Log
local Debug = Util.Debug
local IsValid = Util.IsValid
local Construct = Umg.Construct
local StyleText = Umg.StyleText
local SetLabelText = Umg.SetLabelText
local AddSpacer = Umg.AddSpacer
local CreateTextButton = Umg.CreateTextButton

local M = {}

function M.BuildContent(S)
    if not IsValid(S.contentBox) then
        return
    end
    S.contentDirty = false

    pcall(function()
        S.contentBox:ClearChildren()
    end)
    Session.ClearLive(S)

    -- Must change every rebuild. Reusing FNames after ClearChildren resurrects zombies —
    -- category (more option rows) breaks harder than language; both are the same control.
    S.contentGen = S.contentGen + 1
    local suffix = tostring(S.contentGen)
    local config = S.config
    local contentBox = S.contentBox

    local titleRow = Construct("/Script/UMG.HorizontalBox", contentBox, "ModMenu_TitleRow_" .. suffix)
    contentBox:AddChildToVerticalBox(titleRow)

    local title = Construct("/Script/UMG.TextBlock", titleRow, "ModMenu_Title_" .. suffix)
    StyleText(title, config.fontTitle)
    SetLabelText(title, config.title)
    local titleSlot = titleRow:AddChildToHorizontalBox(title)
    pcall(function()
        titleSlot:SetSize({ SizeRule = 1, Value = 1.0 })
        titleSlot:SetVerticalAlignment(2)
    end)

    -- Handheld: tap Close instead of opening the OSK for F6.
    if config.pointerMode == "touch" then
        local closeBtn, closeLbl = CreateTextButton(
            titleRow,
            "ModMenu_Close_" .. suffix,
            "Close"
        )
        local closeSlot = titleRow:AddChildToHorizontalBox(closeBtn)
        pcall(function()
            closeSlot:SetSize({ SizeRule = 0, Value = 0.0 })
            closeSlot:SetPadding({ Left = 8, Top = 0, Right = 0, Bottom = 0 })
            closeSlot:SetVerticalAlignment(2)
        end)
        table.insert(S.liveControls, {
            kind = "close",
            widget = closeBtn,
            label = closeLbl,
            role = "close",
            wasPressed = false,
        })
    end

    local keyName = tostring(config.keyHint or config.keyName or "F6")
    local hintText = "[" .. keyName .. "] toggle menu"
    if type(config.consoleCommand) == "string" and config.consoleCommand ~= "" then
        hintText = hintText .. " · " .. config.consoleCommand
    end
    local hint = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Hint_" .. suffix)
    StyleText(hint, config.fontHint)
    SetLabelText(hint, hintText)
    contentBox:AddChildToVerticalBox(hint)

    -- Shell chrome: four-side dock picker (no panel rebuild).
    Dock.BuildChrome(S, contentBox, suffix)

    Tabs.BuildStrip(S, contentBox, suffix)

    AddSpacer(contentBox, "ModMenu_HeadPad_" .. suffix, 16)

    if #S.sections == 0 then
        local empty = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Empty_" .. suffix)
        StyleText(empty, config.fontHint)
        SetLabelText(empty, "No mods registered yet.")
        contentBox:AddChildToVerticalBox(empty)
        return
    end

    local visible = {}
    for _, section in ipairs(S.sections) do
        if Tabs.SectionVisible(S, section) then
            table.insert(visible, section)
        end
    end

    if #visible == 0 then
        local emptyTab = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_EmptyTab_" .. suffix)
        StyleText(emptyTab, config.fontHint)
        SetLabelText(emptyTab, "No sections on this tab.")
        contentBox:AddChildToVerticalBox(emptyTab)
        return
    end

    for sIndex, section in ipairs(visible) do
        local collapsed = Collapse.IsCollapsed(S, section)
        local itemParent = contentBox
        if Collapse.IsCollapsible(section) then
            local header = Collapse.BuildHeader(S, section, contentBox, suffix)
            local body = Construct(
                "/Script/UMG.VerticalBox",
                contentBox,
                string.format("ModMenu_SecBody_%s_%s", section.id, suffix)
            )
            contentBox:AddChildToVerticalBox(body)
            Collapse.AttachBody(header, body, collapsed)
            itemParent = body
        else
            local secTitle = Construct(
                "/Script/UMG.TextBlock",
                contentBox,
                string.format("ModMenu_Sec_%s_%s", section.id, suffix)
            )
            StyleText(secTitle, config.fontSection)
            SetLabelText(secTitle, section.title or section.id)
            contentBox:AddChildToVerticalBox(secTitle)
        end
        AddSpacer(itemParent, string.format("ModMenu_SecPad_%s_%s", section.id, suffix), 8)

        -- Always build children. Collapsed sections hide the body (dropdown-style)
        -- so toggling does not rebuild and flicker under a still-down click.
        local ctx = S.makeWidgetCtx()
        ctx.contentBox = itemParent

        for i, item in ipairs(section.items) do
            local namePrefix = string.format("ModMenu_%s_%s_%d_%s", section.id, tostring(item.id or item.type), i, suffix)
            local widget = Widgets.get(item.type)
            if not widget or not widget.build then
                error("BuildContent: no builder for type " .. tostring(item.type))
            end
            ctx.section = section
            ctx.item = item
            ctx.namePrefix = namePrefix
            widget.build(ctx)
        end

        if sIndex < #visible then
            AddSpacer(contentBox, "ModMenu_Between_" .. section.id .. "_" .. suffix, 18)
        end
    end

    -- Touch: last Combat buttons sat on the 1080p clip edge. Mouse does not
    -- need that extra well — those clicks were landing (God hid the HP change).
    local foot = 8
    if config.pointerMode == "touch" then
        foot = 120
    end
    AddSpacer(contentBox, "ModMenu_Foot_" .. suffix, foot)
end

function M.Teardown(S)
    Confirm.Hide(S, "close")
    Cursor.Destroy(S)
    if IsValid(S.menuRoot) then
        pcall(function()
            S.menuRoot:RemoveFromParent()
        end)
        pcall(function()
            S.menuRoot:RemoveFromViewport()
        end)
    end
    S.menuRoot = nil
    S.contentBox = nil
    S.menuScroll = nil
    S.menuCanvas = nil
    S.panelSlot = nil
    S.panelBorder = nil
    S.panelOutline = nil
    S.confirm = nil
    S.confirmRoot = nil
    S.confirmSlot = nil
    S.confirmControls = nil
    Session.ClearLive(S)
    S.menuOpen = false
end

--- ClientRestart always destroys the shell. Do not ApplyGameOnly / hide
--- the cursor unless this instance had actually taken input.
function M.Destroy(S, stopPoll)
    if stopPoll then
        stopPoll()
    end
    local wasHoldingInput = S.menuOpen or Instance.IsOpenCountHeld()
    local remaining = Instance.NoteClosed()
    M.Teardown(S)
    if wasHoldingInput then
        InputMode.SetActive(false, remaining)
    end
end

function M.Create(S)
    local config = S.config
    Instance.Ensure(config)
    Instance.BumpCreateAttempts()
    local suffix = Instance.ShellNameSuffix(config)

    local outer = UEHelpers.GetGameInstance()
    if not IsValid(outer) then
        outer = UEHelpers.GetPlayerController()
    end
    if not IsValid(outer) then
        error("No GameInstance or PlayerController to parent the widget")
    end

    -- Names must be unique under GameInstance across ALL mods (ModRef-backed tag/serial).
    local hud = Construct("/Script/UMG.UserWidget", outer, "ModMenu_Root_" .. suffix)
    local tree = Construct("/Script/UMG.WidgetTree", hud, "ModMenu_Tree_" .. suffix)
    hud.WidgetTree = tree

    local canvas = Construct("/Script/UMG.CanvasPanel", tree, "ModMenu_Canvas_" .. suffix)
    tree.RootWidget = canvas
    S.menuCanvas = canvas

    local colors = Theme.Of(config)
    local fill = Construct("/Script/UMG.Border", canvas, "ModMenu_Border_" .. suffix)
    pcall(function()
        fill:SetBrushColor(colors.panelBg)
        fill:SetPadding(Theme.PadPanel(config))
    end)

    -- Always wrap in a 1px outline. Light uses panelBg so the edge is invisible.
    local outline = Construct("/Script/UMG.Border", canvas, "ModMenu_Outline_" .. suffix)
    pcall(function()
        outline:SetBrushColor(colors.panelBorder)
        outline:SetPadding({ Left = 1, Top = 1, Right = 1, Bottom = 1 })
        outline:SetContent(fill)
    end)

    -- ScrollBox fills the docked panel so long section lists are reachable.
    local scroll = Construct("/Script/UMG.ScrollBox", fill, "ModMenu_Scroll_" .. suffix)
    fill:SetContent(scroll)

    local vbox = Construct("/Script/UMG.VerticalBox", scroll, "ModMenu_VBox_" .. suffix)
    pcall(function()
        scroll:AddChild(vbox)
    end)
    -- After children: constructed ScrollBox often ignores thickness until the slot exists.
    Umg.StyleScrollBox(scroll, config)

    local slot = canvas:AddChildToCanvas(outline)
    S.panelSlot = slot
    S.panelBorder = fill
    S.panelOutline = outline
    if slot then
        Dock.ApplyPercentLayout(slot, config)
    end

    hud:AddToViewport(Instance.GetViewportZ())
    hud:SetVisibility(Session.VIS_COLLAPSED)
    Umg.StyleScrollBox(scroll, config)

    S.menuRoot = hud
    S.contentBox = vbox
    S.menuScroll = scroll
    M.BuildContent(S)

    local thickPct = (config.widthFrac or 0.32) * 100
    local longPct = (1.0 - (config.topFrac or 0) - (config.bottomFrac or 0)) * 100
    local spanX = thickPct
    local spanY = longPct
    if config.dock == "top" or config.dock == "bottom" then
        spanX = longPct
        spanY = thickPct
    end
    Debug(string.format(
        "Shell ready name=ModMenu_Root_%s z=%d dock=%s (~%.0f%% x ~%.0f%%). Sections: %d",
        suffix,
        Instance.GetViewportZ(),
        tostring(config.dock),
        spanX,
        spanY,
        #S.sections
    ))
end

function M.Ensure(S)
    if IsValid(S.menuRoot) and IsValid(S.contentBox) then
        return true
    end
    local ok, err = pcall(M.Create, S)
    if not ok then
        Log("CreateShell failed: " .. tostring(err))
        M.Destroy(S, S.stopPoll)
        return false
    end
    return IsValid(S.menuRoot)
end

return M

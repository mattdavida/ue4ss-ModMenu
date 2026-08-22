--[[
  ModMenu.core.cursor — opt-in ModMenu-owned cursor overlay.

  Init({ cursorMode = "modmenu" }) draws a HitTestInvisible pointer above the
  shell while open. Default remains "engine" (PlayerController / GameAndUI only).

  Optional cursorHideClasses collapses named UUserWidget classes while open
  (host-supplied; e.g. Wuchang WB_Cursor_C). Empty by default — game-agnostic.
  Class defaults are skipped; prior visibility is restored on hide/close.
  A later Init that changes cursorMode / cursorScale / cursorHideClasses
  rebuilds the overlay.
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Instance = require("ModMenu.core.instance")

local M = {}

local POLL_MS = 16
local CURSOR_Z_OFFSET = 1

local VIS_VISIBLE = 0
local VIS_COLLAPSED = 1
local VIS_HITTEST_INVISIBLE = 3

-- Windows IDC_ARROW topology (12x21), restroked at 2x with a 1px outline.
-- 3x read as ~1.5–2× a normal desktop pointer. cursorScale still multiplies
-- this glyph if a host wants it larger.
local SHADOW_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 0.40 }
local OUTLINE_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 }
local FILL_COLOR = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }

local SRC_SCALE = 2
local PAD = 2
local SHADOW_OX = 1
local SHADOW_OY = 1
local HOTSPOT_X = PAD
local HOTSPOT_Y = PAD

-- Head-only fill spans (0-based, inclusive). The stem is drawn as a
-- straight 2px ribbon — interpolating the 12px tail is what made it noisy.
local WIN_HEAD_SPANS = {
    [2] = { { 1, 1 } },
    [3] = { { 1, 2 } },
    [4] = { { 1, 3 } },
    [5] = { { 1, 4 } },
    [6] = { { 1, 5 } },
    [7] = { { 1, 6 } },
    [8] = { { 1, 7 } },
    [9] = { { 1, 8 } },
    [10] = { { 1, 9 } },
    [11] = { { 1, 10 } },
    [12] = { { 1, 6 } },
    [13] = { { 1, 3 } },
    [14] = { { 1, 2 } },
    [15] = { { 1, 1 } },
}

local SRC_W = 12
local SRC_H = 21
local GLYPH_W = SRC_W * SRC_SCALE + PAD * 2 + SHADOW_OX
local GLYPH_H = SRC_H * SRC_SCALE + PAD * 2 + SHADOW_OY

local function NewGrid(w, h)
    local g = {}
    for y = 0, h - 1 do
        g[y] = {}
    end
    return g
end

local function InBounds(x, y, w, h)
    return x >= 0 and y >= 0 and x < w and y < h
end

local function Plot(g, x, y, w, h)
    if InBounds(x, y, w, h) then
        g[y][x] = true
    end
end

--- 4-connected ring only — 8-connected dilation makes fat corners.
local function DilateOutline(fill, w, h)
    local outline = NewGrid(w, h)
    local dirs = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if fill[y][x] then
                for d = 1, #dirs do
                    local nx = x + dirs[d][1]
                    local ny = y + dirs[d][2]
                    if InBounds(nx, ny, w, h) and not fill[ny][nx] then
                        outline[ny][nx] = true
                    end
                end
            end
        end
    end
    return outline
end

local function MergeRuns(runs)
    table.sort(runs, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        if a.w ~= b.w then
            return a.w < b.w
        end
        return a.y < b.y
    end)
    local merged = {}
    for i = 1, #runs do
        local r = runs[i]
        local prev = merged[#merged]
        if prev and prev.x == r.x and prev.w == r.w and prev.y + prev.h == r.y then
            prev.h = prev.h + r.h
        else
            merged[#merged + 1] = r
        end
    end
    return merged
end

local function GridToRuns(grid, w, h)
    local runs = {}
    for y = 0, h - 1 do
        local x = 0
        while x < w do
            if grid[y][x] then
                local x0 = x
                x = x + 1
                while x < w and grid[y][x] do
                    x = x + 1
                end
                runs[#runs + 1] = { x = x0, y = y, w = x - x0, h = 1 }
            else
                x = x + 1
            end
        end
    end
    return MergeRuns(runs)
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function FillHead(g, w, h)
    local scale = SRC_SCALE
    local y0 = PAD + 2 * scale
    local y1 = PAD + 15 * scale + (scale - 1)
    for dy = y0, y1 do
        local srcY = (dy - PAD) / scale
        local yA = math.floor(srcY)
        local yB = yA + 1
        local t = srcY - yA
        local a = WIN_HEAD_SPANS[yA] and WIN_HEAD_SPANS[yA][1]
        local b = WIN_HEAD_SPANS[yB] and WIN_HEAD_SPANS[yB][1]
        if a == nil then
            a = b
        end
        if b == nil then
            b = a
        end
        if a ~= nil then
            local x0 = Lerp(a[1], b[1], t)
            local x1 = Lerp(a[2], b[2], t)
            local dx0 = math.floor(PAD + x0 * scale + 0.5)
            local dx1 = math.floor(PAD + (x1 + 1) * scale - 1 + 0.5)
            if dx1 < dx0 then
                dx1 = dx0
            end
            for x = dx0, dx1 do
                Plot(g, x, dy, w, h)
            end
        end
    end
    Plot(g, PAD + 1, PAD + 1, w, h)
end

--- 3-down, 1-right stair. DDA made the tail bend; a regular step stays even.
local function FillStemStair(g, w, h, x0, y0, width, length)
    for i = 0, length - 1 do
        local x = x0 + math.floor(i / 3)
        local y = y0 + i
        for k = 0, width - 1 do
            Plot(g, x + k, y, w, h)
        end
    end
    local capX = x0 + math.floor((length - 1) / 3)
    local capY = y0 + length - 1
    for k = 0, width - 1 do
        Plot(g, capX + k, capY + 1, w, h)
    end
end

--- Outline pixels jammed in the head/stem crease (3+ fill neighbors).
local function CleanJoinOutline(outline, fill, w, h)
    local dirs = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if outline[y][x] then
                local n = 0
                for d = 1, #dirs do
                    local nx = x + dirs[d][1]
                    local ny = y + dirs[d][2]
                    if InBounds(nx, ny, w, h) and fill[ny][nx] then
                        n = n + 1
                    end
                end
                if n >= 3 then
                    outline[y][x] = nil
                end
            end
        end
    end
end

local function FillWindowsArrow(g, w, h)
    local scale = SRC_SCALE
    FillHead(g, w, h)
    -- Vertical socket in the notch, then a regular stair. Keeps the join
    -- filled so the outline cannot wrap between head and stem.
    local stemW = 2
    local x0 = PAD + 5 * scale
    local socketY = PAD + 10 * scale
    local socketH = 2 * scale + 2
    for oy = 0, socketH - 1 do
        for ox = 0, stemW - 1 do
            Plot(g, x0 + ox, socketY + oy, w, h)
        end
    end
    FillStemStair(g, w, h, x0, socketY + socketH - 2, stemW, 5 * scale + 2)
end

local function OffsetRuns(runs, dx, dy)
    local out = {}
    for i = 1, #runs do
        local r = runs[i]
        out[i] = { x = r.x + dx, y = r.y + dy, w = r.w, h = r.h }
    end
    return out
end

local function BuildPointerRuns()
    local w, h = GLYPH_W, GLYPH_H
    local fill = NewGrid(w, h)
    FillWindowsArrow(fill, w, h)
    local outline = DilateOutline(fill, w, h)
    CleanJoinOutline(outline, fill, w, h)
    local fillRuns = GridToRuns(fill, w, h)
    local outlineRuns = GridToRuns(outline, w, h)
    local shadow = {}
    for i = 1, #outlineRuns do
        shadow[#shadow + 1] = outlineRuns[i]
    end
    for i = 1, #fillRuns do
        shadow[#shadow + 1] = fillRuns[i]
    end
    shadow = MergeRuns(OffsetRuns(shadow, SHADOW_OX, SHADOW_OY))
    return outlineRuns, fillRuns, shadow
end

local ARROW_OUTLINE, ARROW_FILL, ARROW_SHADOW = BuildPointerRuns()

local IsValid = Util.IsValid

local function Log(msg)
    Util.Log("Cursor: " .. tostring(msg))
end

local function Debug(msg)
    Util.Debug("Cursor: " .. tostring(msg))
end

-- Soft construct: overlay must not error() the shell if a class is missing.
local function Construct(classPath, outer, name)
    local cls = StaticFindObject(classPath)
    if not IsValid(cls) then
        return nil
    end
    local obj = StaticConstructObject(cls, outer, FName(name))
    if not IsValid(obj) then
        return nil
    end
    return obj
end

--- UE4SS IsValid is true for pending-kill objects. Native calls on those are fatals.
local function IsLiveWidget(obj)
    if not IsValid(obj) then
        return false
    end
    local dead = false
    pcall(function()
        if obj.IsPendingKill and obj:IsPendingKill() then
            dead = true
        end
    end)
    if dead then
        return false
    end
    pcall(function()
        if obj.bIsPendingKill == true then
            dead = true
        end
    end)
    return not dead
end

local function SetVisibility(widget, vis)
    if not IsLiveWidget(widget) then
        return
    end
    pcall(function()
        widget:SetVisibility(vis)
    end)
end

local function ReadVisibility(widget)
    if not IsValid(widget) then
        return nil
    end
    local ok, vis = pcall(function()
        return widget:GetVisibility()
    end)
    if not ok or vis == nil then
        return nil
    end
    if type(vis) == "number" then
        return vis
    end
    local n = tonumber(vis)
    if n ~= nil then
        return n
    end
    local okVal, value = pcall(function()
        return vis.Value or vis.value
    end)
    if okVal and type(value) == "number" then
        return value
    end
    return nil
end

--- UE4SS FindAllOf often includes the CDO (Default__Class). Collapsing that
--- would change every future instance of the class.
local function IsClassDefault(obj)
    if not IsValid(obj) then
        return true
    end
    local ok, isDefault = pcall(function()
        return obj.IsDefaultObject and obj:IsDefaultObject()
    end)
    if ok and isDefault == true then
        return true
    end
    local okName, name = pcall(function()
        if obj.GetName then
            return tostring(obj:GetName())
        end
        return ""
    end)
    if okName and type(name) == "string" and name:find("Default__", 1, true) then
        return true
    end
    return false
end

local function RemoveOverlayWidget(hud)
    if not IsLiveWidget(hud) then
        return
    end
    pcall(function()
        hud:RemoveFromParent()
    end)
    pcall(function()
        hud:RemoveFromViewport()
    end)
end

--- Mouse coords from GetMousePositionOnViewport are viewport-space. The
--- overlay UserWidget must fill the viewport or SetPosition clips / drifts.
local function FillViewport(hud)
    if not IsValid(hud) then
        return
    end
    pcall(function()
        if hud.SetAnchorsInViewport then
            hud:SetAnchorsInViewport({ Minimum = { X = 0, Y = 0 }, Maximum = { X = 1, Y = 1 } })
        end
        if hud.SetAlignmentInViewport then
            hud:SetAlignmentInViewport({ X = 0, Y = 0 })
        end
        if hud.SetPositionInViewport then
            hud:SetPositionInViewport({ X = 0, Y = 0 }, false)
        end
    end)
    pcall(function()
        local slot = hud.Slot
        if slot == nil or slot.SetAnchors == nil then
            return
        end
        slot:SetAnchors({ Minimum = { X = 0, Y = 0 }, Maximum = { X = 1, Y = 1 } })
        if slot.SetOffsets then
            slot:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        end
        if slot.SetAlignment then
            slot:SetAlignment({ X = 0, Y = 0 })
        end
    end)
end

local function AddRect(canvas, name, x, y, w, h, color, z)
    local border = Construct("/Script/UMG.Border", canvas, name)
    if not border then
        return false
    end
    pcall(function()
        border:SetBrushColor(color)
        border:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
    end)

    local slot = canvas:AddChildToCanvas(border)
    if not slot then
        return false
    end
    pcall(function()
        slot:SetAnchors({ Minimum = { X = 0, Y = 0 }, Maximum = { X = 0, Y = 0 } })
        slot:SetAlignment({ X = 0, Y = 0 })
        slot:SetPosition({ X = x, Y = y })
        slot:SetSize({ X = w, Y = h })
        slot:SetZOrder(z or 1)
    end)
    SetVisibility(border, VIS_HITTEST_INVISIBLE)
    return true
end

local function ReadVec2(v)
    if v == nil then
        return nil, nil
    end
    if type(v) == "table" then
        return v.X or v.x, v.Y or v.y
    end
    local okX, x = pcall(function()
        return v.X
    end)
    local okY, y = pcall(function()
        return v.Y
    end)
    if okX and okY and type(x) == "number" and type(y) == "number" then
        return x, y
    end
    return nil, nil
end

local function GetMouseXY()
    local world = UEHelpers.GetGameInstance()
    if IsValid(world) then
        local ok, lib = pcall(function()
            return StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        end)
        if ok and IsValid(lib) and lib.GetMousePositionOnViewport then
            local okPos, pos = pcall(function()
                return lib:GetMousePositionOnViewport(world)
            end)
            if okPos then
                local x, y = ReadVec2(pos)
                if x and y then
                    return x, y
                end
            end
        end
    end

    local pc = UEHelpers.GetPlayerController()
    if IsValid(pc) and pc.GetMousePosition then
        local ok, a, b = pcall(function()
            return pc:GetMousePosition()
        end)
        if ok and type(a) == "number" and type(b) == "number" then
            return a, b
        end
    end

    return nil, nil
end

local function ResolveScale(config)
    local n = config and config.cursorScale
    if type(n) ~= "number" or n ~= n or n < 1 then
        return 1
    end
    n = math.floor(n + 0.5)
    if n < 1 then
        return 1
    end
    if n > 8 then
        return 8
    end
    return n
end

local function CursorConfigSig(config)
    local mode = (config and config.cursorMode) or "engine"
    local scale = ResolveScale(config)
    local classes = config and config.cursorHideClasses
    local hide = ""
    if type(classes) == "table" and #classes > 0 then
        hide = table.concat(classes, "\0")
    end
    return mode .. "|" .. tostring(scale) .. "|" .. hide
end

local function BuildArrowGlyphRoot(canvas, suffix, scale)
    local sizeBox = Construct("/Script/UMG.SizeBox", canvas, "ModMenu_CursorSize_" .. suffix)
    if not sizeBox then
        return nil
    end
    pcall(function()
        sizeBox:SetWidthOverride(GLYPH_W * scale)
        sizeBox:SetHeightOverride(GLYPH_H * scale)
    end)

    local innerCanvas = Construct("/Script/UMG.CanvasPanel", sizeBox, "ModMenu_CursorInner_" .. suffix)
    if not innerCanvas then
        return nil
    end
    pcall(function()
        sizeBox:SetContent(innerCanvas)
    end)

    for i = 1, #ARROW_SHADOW do
        local part = ARROW_SHADOW[i]
        AddRect(
            innerCanvas,
            "ModMenu_CursorShadow_" .. suffix .. "_" .. i,
            part.x * scale,
            part.y * scale,
            part.w * scale,
            part.h * scale,
            SHADOW_COLOR,
            0
        )
    end
    for i = 1, #ARROW_OUTLINE do
        local part = ARROW_OUTLINE[i]
        AddRect(
            innerCanvas,
            "ModMenu_CursorOutline_" .. suffix .. "_" .. i,
            part.x * scale,
            part.y * scale,
            part.w * scale,
            part.h * scale,
            OUTLINE_COLOR,
            1
        )
    end
    for i = 1, #ARROW_FILL do
        local part = ARROW_FILL[i]
        AddRect(
            innerCanvas,
            "ModMenu_CursorFill_" .. suffix .. "_" .. i,
            part.x * scale,
            part.y * scale,
            part.w * scale,
            part.h * scale,
            FILL_COLOR,
            2
        )
    end

    SetVisibility(sizeBox, VIS_HITTEST_INVISIBLE)
    SetVisibility(innerCanvas, VIS_HITTEST_INVISIBLE)
    return sizeBox
end

local function StopPoll(S)
    if S.cursorPollHandle then
        pcall(function()
            CancelDelayedAction(S.cursorPollHandle)
        end)
        S.cursorPollHandle = nil
    end
    -- Keep S.cursorPollFn pinned. CancelDelayedAction can still run this tick.
end

local function RestoreHidden(S)
    local list = S.cursorHiddenWidgets
    if type(list) ~= "table" then
        return
    end
    for i = 1, #list do
        local entry = list[i]
        local widget = entry
        local vis = VIS_VISIBLE
        if type(entry) == "table" and entry.widget ~= nil then
            widget = entry.widget
            if type(entry.vis) == "number" then
                vis = entry.vis
            end
        end
        SetVisibility(widget, vis)
    end
    S.cursorHiddenWidgets = {}
end

local function HideConfiguredClasses(S)
    RestoreHidden(S)
    local classes = S.config.cursorHideClasses
    if type(classes) ~= "table" or #classes == 0 then
        return
    end
    local hidden = {}
    for i = 1, #classes do
        local cls = classes[i]
        if type(cls) == "string" and cls ~= "" then
            local found = FindAllOf(cls)
            if type(found) == "table" then
                for j = 1, #found do
                    local w = found[j]
                    if IsLiveWidget(w) and not IsClassDefault(w) then
                        hidden[#hidden + 1] = {
                            widget = w,
                            vis = ReadVisibility(w),
                        }
                        SetVisibility(w, VIS_COLLAPSED)
                    end
                end
            end
        end
    end
    S.cursorHiddenWidgets = hidden
end

local function EnsureOverlay(S)
    if IsValid(S.cursorRoot) and S.cursorSlot then
        SetVisibility(S.cursorRoot, VIS_HITTEST_INVISIBLE)
        return true
    end

    local outer = UEHelpers.GetGameInstance()
    if not IsValid(outer) then
        outer = UEHelpers.GetPlayerController()
    end
    if not IsValid(outer) then
        return false
    end

    Instance.Ensure(S.config)
    local suffix = Instance.ShellNameSuffix(S.config)
    local z = Instance.GetViewportZ() + CURSOR_Z_OFFSET

    local hud = Construct("/Script/UMG.UserWidget", outer, "ModMenu_CursorOverlay_" .. suffix)
    if not hud then
        return false
    end

    local tree = Construct("/Script/UMG.WidgetTree", hud, "ModMenu_CursorTree_" .. suffix)
    if not tree then
        RemoveOverlayWidget(hud)
        return false
    end
    hud.WidgetTree = tree

    local canvas = Construct("/Script/UMG.CanvasPanel", tree, "ModMenu_CursorCanvas_" .. suffix)
    if not canvas then
        RemoveOverlayWidget(hud)
        return false
    end
    tree.RootWidget = canvas

    local scale = ResolveScale(S.config)
    local glyph = BuildArrowGlyphRoot(canvas, suffix, scale)
    if not glyph then
        Log("failed to build glyph")
        RemoveOverlayWidget(hud)
        return false
    end

    local slot = canvas:AddChildToCanvas(glyph)
    if not slot then
        Log("failed to add glyph to canvas")
        RemoveOverlayWidget(hud)
        return false
    end
    pcall(function()
        slot:SetAnchors({ Minimum = { X = 0, Y = 0 }, Maximum = { X = 0, Y = 0 } })
        slot:SetAlignment({ X = 0, Y = 0 })
        slot:SetPosition({ X = 0, Y = 0 })
        slot:SetAutoSize(true)
        slot:SetZOrder(9999)
    end)

    SetVisibility(hud, VIS_HITTEST_INVISIBLE)
    SetVisibility(canvas, VIS_HITTEST_INVISIBLE)
    SetVisibility(glyph, VIS_HITTEST_INVISIBLE)

    local added = pcall(function()
        hud:AddToViewport(z)
    end)
    if not added then
        Log("failed to add overlay to viewport")
        RemoveOverlayWidget(hud)
        return false
    end
    FillViewport(hud)

    S.cursorScale = scale
    S.cursorHotspotX = HOTSPOT_X * scale
    S.cursorHotspotY = HOTSPOT_Y * scale
    S.cursorRoot = hud
    S.cursorSlot = slot
    Debug(string.format("overlay ready z=%d tag=%s", z, tostring(Instance.GetTag())))
    return true
end

local function UpdatePosition(S)
    if not S.cursorSlot then
        return
    end
    local x, y = GetMouseXY()
    if not x or not y then
        return
    end
    pcall(function()
        S.cursorSlot:SetPosition({
            X = x - (S.cursorHotspotX or HOTSPOT_X),
            Y = y - (S.cursorHotspotY or HOTSPOT_Y),
        })
    end)
end

---@param S table
---@return boolean
function M.IsEnabled(S)
    return S ~= nil and S.config ~= nil and S.config.cursorMode == "modmenu"
end

---@param S table
function M.Show(S)
    if not M.IsEnabled(S) then
        return
    end
    if not EnsureOverlay(S) then
        return
    end
    HideConfiguredClasses(S)
    SetVisibility(S.cursorRoot, VIS_HITTEST_INVISIBLE)
    UpdatePosition(S)
end

---@param S table
function M.Hide(S)
    StopPoll(S)
    RestoreHidden(S)
    if IsValid(S.cursorRoot) then
        SetVisibility(S.cursorRoot, VIS_COLLAPSED)
    end
end

---@param S table
function M.StartPoll(S)
    if not M.IsEnabled(S) then
        return
    end
    StopPoll(S)
    if S.cursorPollFn == nil then
        S.cursorPollFn = Util.PinFn(function()
            if not S.menuOpen or not IsValid(S.cursorRoot) or not S.cursorSlot then
                return
            end
            UpdatePosition(S)
        end)
    end
    S.cursorPollHandle = LoopInGameThreadWithDelay(POLL_MS, S.cursorPollFn)
end

--- Tear down overlay UObjects (ClientRestart / DestroyShell / live Init).
---@param S table
function M.Destroy(S)
    if S.cursorShowHandle ~= nil then
        pcall(function()
            CancelDelayedAction(S.cursorShowHandle)
        end)
        S.cursorShowHandle = nil
    end
    StopPoll(S)
    RestoreHidden(S)
    RemoveOverlayWidget(S.cursorRoot)
    S.cursorRoot = nil
    S.cursorSlot = nil
    S.cursorHiddenWidgets = nil
    S.cursorScale = nil
    S.cursorHotspotX = nil
    S.cursorHotspotY = nil
end

--- Rebuild the overlay when a later Init changes cursorMode / cursorScale /
--- cursorHideClasses. First Init only records the signature (no overlay yet).
---@param S table
function M.OnConfigChanged(S)
    if S == nil or S.config == nil then
        return
    end
    local sig = CursorConfigSig(S.config)
    local prev = S.cursorConfigSig
    S.cursorConfigSig = sig
    if prev == nil or prev == sig then
        return
    end
    M.Destroy(S)
    if M.IsEnabled(S) and S.menuOpen then
        M.Show(S)
        M.StartPoll(S)
    end
end

return M

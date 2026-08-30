local Config = require("ModMenu.core.config")
local DockMath = require("ModMenu.core.dockmath")

assert_eq("NormalizeDock left", Config.NormalizeDock("left"), "left")
assert_eq("NormalizeDock RIGHT", Config.NormalizeDock("RIGHT"), "right")
assert_eq("NormalizeDock top", Config.NormalizeDock("top"), "top")
assert_eq("NormalizeDock bottom", Config.NormalizeDock("Bottom"), "bottom")
assert_eq("NormalizeDock junk", Config.NormalizeDock("centre"), "right")
assert_eq("NormalizeDock nil", Config.NormalizeDock(nil), "right")

local cfg = {
    dock = "left",
    widthFrac = 0.32,
    topFrac = 0.05,
    bottomFrac = 0.05,
    rightFrac = 0.01,
}

local left = DockMath.PercentRect(cfg)
assert_eq("left minX", left.minX, 0.01)
assert_eq("left maxX", left.maxX, 0.33)
assert_eq("left minY", left.minY, 0.05)
assert_eq("left maxY", left.maxY, 0.95)

cfg.dock = "right"
local right = DockMath.PercentRect(cfg)
assert_eq("right minX", right.minX, 0.67)
assert_eq("right maxX", right.maxX, 0.99)
assert_eq("right minY", right.minY, 0.05)
assert_eq("right maxY", right.maxY, 0.95)

cfg.dock = "top"
local top = DockMath.PercentRect(cfg)
assert_eq("top minX", top.minX, 0.05)
assert_eq("top maxX", top.maxX, 0.95)
assert_eq("top minY", top.minY, 0.01)
assert_eq("top maxY", top.maxY, 0.33)

cfg.dock = "bottom"
local bottom = DockMath.PercentRect(cfg)
assert_eq("bottom minX", bottom.minX, 0.05)
assert_eq("bottom maxX", bottom.maxX, 0.95)
assert_eq("bottom minY", bottom.minY, 0.67)
assert_eq("bottom maxY", bottom.maxY, 0.99)

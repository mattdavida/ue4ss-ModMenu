local Config = require("ModMenu.core.config")

local function apply(opts)
    local cfg = Config.New()
    cfg.key = 1
    cfg.keyHint = "F6"
    Config.ApplyInit(cfg, opts)
    return cfg
end

assert_true("showClose default on", Config.New().showClose == true)
assert_true("showClose stays on when omitted", apply({}).showClose == true)
assert_true("showClose false", apply({ showClose = false }).showClose == false)
assert_true("showClose true", apply({ showClose = true }).showClose == true)

local kept = apply({ showClose = false })
Config.ApplyInit(kept, { title = "Keep" })
assert_true("showClose persists across Init", kept.showClose == false)
Config.ApplyInit(kept, { showClose = true })
assert_true("showClose can turn back on", kept.showClose == true)

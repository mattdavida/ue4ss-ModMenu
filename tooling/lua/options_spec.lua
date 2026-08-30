local Options = require("ModMenu.core.options")

local list, labelToValue, valueToLabel = Options.NormalizeOptions({
    "Left",
    { label = "Right", value = "right" },
    { value = "top" },
})

assert_eq("list length", #list, 3)
assert_eq("string option", list[1], { label = "Left", value = "Left" })
assert_eq("label+value option", list[2], { label = "Right", value = "right" })
assert_eq("value-only option", list[3], { label = "top", value = "top" })
assert_eq("order is stable", { list[1].value, list[2].value, list[3].value }, {
    "Left",
    "right",
    "top",
})
assert_eq("labelToValue Right", labelToValue.Right, "right")
assert_eq("valueToLabel right", valueToLabel.right, "Right")

assert_true("filter empty matches", Options.OptionMatchesFilter("Top", "") == true)
assert_true("filter case-insensitive", Options.OptionMatchesFilter("Top", "to") == true)
assert_true("filter miss", Options.OptionMatchesFilter("Top", "bottom") == false)

local Json = require("ModMenu.store.json")

assert_true("IsSafe string", Json.IsSafe("dock") == true)
assert_true("IsSafe number", Json.IsSafe(3) == true)
assert_true("IsSafe object", Json.IsSafe({ dock = "left", n = 2 }) == true)
assert_true("IsSafe rejects function", Json.IsSafe(function() end) == false)
assert_true("IsSafe rejects nan", Json.IsSafe(0 / 0) == false)

local text = Json.Encode({ dock = "right", n = 2 }, 0)
assert_true("Encode writes object", type(text) == "string" and text:sub(1, 1) == "{")
assert_true("Encode has dock", text:find('"dock"', 1, true) ~= nil)
assert_true("Encode has right", text:find('"right"', 1, true) ~= nil)

local obj = Json.DecodeObject(text)
assert_eq("Decode dock", obj.dock, "right")
assert_eq("Decode number", obj.n, 2)

local ok, err = pcall(Json.DecodeObject, "[1,2]")
assert_true("Decode root must be object", ok == false)
assert_true("Decode error mentions object", type(err) == "string" and err:find("object", 1, true) ~= nil)

-- SPDX-License-Identifier: GPL-3.0-or-later
local name = "Fisher"
UnitFullName = function() return name, "Forever" end
local ns = {storage = {db = {}}}
assert(loadfile("FishingAtlas/Kitchen/RecipeKnowledge.lua"))("FishingAtlas", ns)
local K = ns.recipeKnowledge
assert(K.status(18243) == "unchecked")
assert(K.cycle(18243) == "known")
assert(K.status(18243) == "known")
assert(K.cycle(18243) == "unknown")
assert(K.status(18243) == "unknown")
name = "Chef"
assert(K.status(18243) == "unchecked", "Knowledge leaked between characters")
assert(K.set(18243, "known"))
name = "Fisher"
assert(K.status(18243) == "unknown")
assert(K.cycle(18243) == "unchecked")
assert(K.status(18243) == "unchecked")
print("per-character recipe tracking tests passed")

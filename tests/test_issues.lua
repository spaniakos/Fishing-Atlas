-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/UI/Issues.lua"))("FishingAtlas", ns)
assert(ns.issues.url == "https://github.com/spaniakos/Fishing-Atlas/issues/new/choose")
assert(ns.issues.open() == false) -- no UIParent in the unit-test process
print("issue-link fallback test passed")

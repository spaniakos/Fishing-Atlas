-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
-- Reference-only metadata derived from known Classic recipes, not yet validated in Forever.
-- No speculative coordinates, market prices, acquisition costs or drop rates.
ns.data.recipes = {
  {
    id = "brilliant-smallfish", name = "Recipe: Brilliant Smallfish",
    output = "Brilliant Smallfish", skill = 1, source = "classic_reference",
    sourceText = "Cooking recipe vendor (verify stock and faction in Forever)",
    ingredients = {{name = "Raw Brilliant Smallfish", amount = 1}}
  },
  {
    id = "longjaw-mud-snapper", name = "Recipe: Longjaw Mud Snapper",
    output = "Longjaw Mud Snapper", skill = 50, source = "classic_reference",
    sourceText = "Cooking recipe vendor (verify exact NPC in Forever)",
    ingredients = {{name = "Raw Longjaw Mud Snapper", amount = 1}}
  },
  {
    id = "nightfin-soup", name = "Recipe: Nightfin Soup",
    output = "Nightfin Soup", skill = 250, source = "classic_reference",
    sourceText = "Gikkix, Tanaris (Classic reference; verify in Forever)",
    ingredients = {
      {name = "Raw Nightfin Snapper", amount = 1},
      {name = "Refreshing Spring Water", amount = 1}
    }
  }
}

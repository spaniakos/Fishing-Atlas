-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
-- Editorial names and zones from the WoW Forever fishing vendor overview.
-- Source: https://www.wow-professions.com/forever/how-to-fish
-- Lists a known *reference* vendor, not a build-confirmed stock snapshot.
-- Exact coordinates omitted where the player has not confirmed them in-game.
ns.data.referenceVendors = {
  {name="Zansoa",mapID=1411,area="Sen'jin Village",items={6256,6529},side="Horde"},
  {name="Wunna Darkmane",mapID=1412,area="Bloodhoof Village",items={6256,6529},side="Horde"},
  {name="Martine Tramblay",mapID=1420,area="Death's Watch Waystation",items={6256,6529},side="Horde"},
  {name="Shankys",mapID=1454,area="Orgrimmar, fishing trainer",items={6256,6529},side="Horde"},
  {name="Lizbeth Cromwell",mapID=1458,area="Undercity, fishing trainer",items={6256,6529},side="Horde"},
  {name="Sewa Mistrunner",mapID=1456,area="Thunder Bluff, fishing trainer",items={6256,6529,6365},side="Horde"},
  {name="Wik'Tar",mapID=1440,area="Zoram'gar Outpost",items={6256,6529},side="Horde"},
  {name="Katoom the Angler",mapID=1425,area="Revantusk Village",items={6256,6529},side="Horde"},
  {name="Tharynn Bouden",mapID=1429,area="Goldshire",items={6256,6529},side="Alliance"},
  {name="Gretta Ganter",mapID=1426,area="Iceflow Lake",items={6256,6529},side="Alliance"},
  {name="Nessa Shadowsong",mapID=1438,area="Rut'theran Village",items={6256,6529},side="Alliance"},
  {name="Catherine Leland",mapID=1453,area="Stormwind fishing trainer",items={6256,6529,6365},side="Alliance"},
  {name="Tansy Puddlefizz",mapID=1455,area="Ironforge fishing trainer",items={6256,6529,6365},side="Alliance"},
  {name="Voloren",mapID=1457,area="Darnassus fishing trainer",items={6256,6529,6365},side="Alliance"},
  {name="Khara Deepwater",mapID=1432,area="Loch Modan",items={6256,6529,6365},side="Alliance"},
  {name="Stuart Fleming",mapID=1437,area="Menethil Harbor",items={6256,6529,6365},side="Alliance"},
  {name="Vernon Hale",mapID=1433,area="Lake Everstill",items={6256,6529,6365},side="Alliance"},
  {name="Lindea Rabonne",mapID=1424,area="Southshore",items={6256,6529,6365},side="Alliance"},
}

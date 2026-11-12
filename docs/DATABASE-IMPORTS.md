# Source imports and evidence gates

Target client: WoW Forever **1.60.1.70888** (interface 16001).

## Data categories

* **Client extracts**: item, spell and recipe IDs. An entry in game files does not prove live availability.
* **In-game observations**: merchant inventory snapshots, fishing catches and player fishing positions.
* **Historic references**: Classic guides and public sites. Not considered confirmed in Forever.
* **External published datasets**: may be imported only after provenance, licensing and attribution checks.

## Vendor observations (v0.8)

A merchant window scan stores a list of item IDs, NPC ID and timestamp account-wide in `FishingAtlasDB.vendorObservations`.
Only a valid `Creature-...` GUID from the current `npc` unit is accepted.
No vendor prices or vendor location coordinates are inferred. A record is an observation of a merchant inventory snapshot, not a guaranteed permanent stock listing.

## External data licenses

Everloot publishes observations under CC BY-SA 4.0, while its software is AGPL-3.0.
Respect attribution and share-alike obligations; do **not** relicense third-party observations as GPL source.
AHledger API has use and retention restrictions. We must not create a bulk archive from its API without appropriate rights.

Before a bulk import lands in Git, record the exact export URL, build, publication date, license, terms and source hash. Run validation and coverage reports. Do not silently treat another client's IDs and catch probabilities as Forever-confirmed.

## Coverage gate for v0.8

v0.8 is incomplete until the curated game IDs and relationships are populated sufficiently to back the promised fish, equipment, vendor, recipe and cooking guide screens. Record coverage explicitly; unknown data stays unknown.

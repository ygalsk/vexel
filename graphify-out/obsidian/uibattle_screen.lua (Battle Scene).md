---
source_file: "phases/phase-9.2.md"
type: "document"
community: "Codecritter Game Design"
location: "### `ui/battle_screen.lua`"
tags:
  - graphify/document
  - graphify/EXTRACTED
  - community/Codecritter_Game_Design
---

# ui/battle_screen.lua (Battle Scene)

## Connections
- [[Battle State Machine]] - `implements` [EXTRACTED]
- [[Scene Stack (PushPopSwitch)]] - `references` [EXTRACTED]
- [[Screen Shake System]] - `references` [EXTRACTED]
- [[Type Attack Effects (Per-Type Visuals)]] - `references` [EXTRACTED]
- [[audiomusic.lua (Context → Track Map)]] - `references` [EXTRACTED]
- [[battleai.lua (Wild Critter AI)]] - `references` [EXTRACTED]
- [[battleengine.lua (Core Battle Logic)]] - `references` [EXTRACTED]
- [[battlestatus.lua (Status Effect Registry)]] - `references` [EXTRACTED]
- [[critterstats.lua (Stat Calc + XP + Scars)]] - `references` [EXTRACTED]
- [[datamoves.lua (52 Moves + 21 Discs)]] - `references` [EXTRACTED]
- [[datatypes.lua (Type Effectiveness Matrix)]] - `references` [EXTRACTED]
- [[meta.lua (Reactive Event Handler)]] - `references` [EXTRACTED]
- [[spriteregistry.lua (Species → Sprite Config)]] - `references` [EXTRACTED]
- [[uianim.lua (Battle Step Sequencer)]] - `references` [EXTRACTED]
- [[uidungeon_screen.lua (Dungeon Exploration Scene)]] - `references` [EXTRACTED]
- [[uimoments.lua (Full-Screen Interruptions)]] - `references` [EXTRACTED]
- [[uiwidgets.lua (Reusable UI Components)]] - `references` [EXTRACTED]

#graphify/document #graphify/EXTRACTED #community/Codecritter_Game_Design
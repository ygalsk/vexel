# Phase 9.7 — Persistence (SQLite)

## Goal
Replace the `db/persistence.lua` stub with real SQLite-backed save/load. All player state (roster, inventory, codex, achievements, unlocks, lifetime stats) survives quit + restart. Run state is NOT persisted mid-run — a quit mid-run is treated as a wipe.

## Verify
- Quit after catching a critter → restart → critter is in roster
- Quit mid-run → restart → treated as wipe (party critters get cooldowns)
- All hub tabs show correct persisted state
- Achievements persist and track correctly

---

## Files to Create/Modify

```
games/codecritter/
└── db/persistence.lua   -- Full SQLite schema + save/load
```

---

## Database Design

One SQLite file: `codecritter.db` in the game directory.

### Tables

```sql
-- Persistent critter data
CREATE TABLE IF NOT EXISTS critters (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    species_id  TEXT NOT NULL,
    name        TEXT NOT NULL,
    level       INTEGER NOT NULL DEFAULT 1,
    xp          INTEGER NOT NULL DEFAULT 0,
    hp          INTEGER NOT NULL,
    max_hp      INTEGER NOT NULL,
    stat_logic  INTEGER NOT NULL,
    stat_resolve INTEGER NOT NULL,
    stat_speed  INTEGER NOT NULL,
    disc        TEXT,         -- equipped move disc id or NULL
    hold_item   TEXT,         -- equipped hold item id or NULL
    cooldown_runs INTEGER NOT NULL DEFAULT 0,
    scar_data   TEXT          -- JSON array of {stat, amount} objects
);

-- Player global state (single row)
CREATE TABLE IF NOT EXISTS player (
    id              INTEGER PRIMARY KEY DEFAULT 1,
    first_launch    INTEGER NOT NULL DEFAULT 1,
    party_slots     TEXT,     -- JSON array of critter IDs (ordered)
    inventory_json  TEXT,     -- JSON {healing:[], catch:[], disc:[], hold:[]}
    codex_json      TEXT,     -- JSON {species_id: {seen, caught}}
    commits_json    TEXT,     -- JSON {commit_id: true}
    unlocks_json    TEXT,     -- JSON {unlock_id: true}
    lifetime_json   TEXT      -- JSON {runs, floors, catches, faints, currency}
);

-- Run state (in-progress run — if row exists, last run was interrupted)
CREATE TABLE IF NOT EXISTS active_run (
    id          INTEGER PRIMARY KEY DEFAULT 1,
    floor       INTEGER NOT NULL,
    currency    INTEGER NOT NULL,
    party_json  TEXT,         -- JSON array of critter snapshot IDs
    inv_json    TEXT          -- run inventory snapshot
);
```

---

## `db/persistence.lua`

```lua
-- db/persistence.lua
-- Full SQLite persistence for Codecritter player state

local M = {}

local DB_PATH = "codecritter.db"
local db = nil

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function open()
    if db then return end
    db = engine.db.open(DB_PATH)
    M._init_schema()
end

function M._init_schema()
    engine.db.exec(db, [[
        CREATE TABLE IF NOT EXISTS critters (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            species_id    TEXT NOT NULL,
            name          TEXT NOT NULL,
            level         INTEGER NOT NULL DEFAULT 1,
            xp            INTEGER NOT NULL DEFAULT 0,
            hp            INTEGER NOT NULL,
            max_hp        INTEGER NOT NULL,
            stat_logic    INTEGER NOT NULL,
            stat_resolve  INTEGER NOT NULL,
            stat_speed    INTEGER NOT NULL,
            disc          TEXT,
            hold_item     TEXT,
            cooldown_runs INTEGER NOT NULL DEFAULT 0,
            scar_data     TEXT
        );
    ]])
    engine.db.exec(db, [[
        CREATE TABLE IF NOT EXISTS player (
            id             INTEGER PRIMARY KEY DEFAULT 1,
            first_launch   INTEGER NOT NULL DEFAULT 1,
            party_slots    TEXT,
            inventory_json TEXT,
            codex_json     TEXT,
            commits_json   TEXT,
            unlocks_json   TEXT,
            lifetime_json  TEXT
        );
    ]])
    engine.db.exec(db, [[
        CREATE TABLE IF NOT EXISTS active_run (
            id          INTEGER PRIMARY KEY DEFAULT 1,
            floor       INTEGER NOT NULL DEFAULT 1,
            currency    INTEGER NOT NULL DEFAULT 0,
            party_json  TEXT,
            inv_json    TEXT
        );
    ]])
    -- Ensure player row exists
    engine.db.exec(db, "INSERT OR IGNORE INTO player (id) VALUES (1);")
end

-- Simple JSON encode (Lua tables only — no external lib needed for our data shapes)
local function json_encode(val)
    if type(val) == "nil" then return "null" end
    if type(val) == "boolean" then return val and "true" or "false" end
    if type(val) == "number" then return tostring(val) end
    if type(val) == "string" then
        -- Escape special chars
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    end
    if type(val) == "table" then
        -- Detect array vs object (array = all integer keys 1..n)
        local is_array = true
        local n = 0
        for k, _ in pairs(val) do
            n = n + 1
            if type(k) ~= "number" or k ~= math.floor(k) then is_array = false; break end
        end
        if is_array and n > 0 then
            -- Check contiguous
            for i = 1, n do if val[i] == nil then is_array = false; break end end
        end
        if is_array then
            local parts = {}
            for i = 1, #val do parts[i] = json_encode(val[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, json_encode(tostring(k)) .. ":" .. json_encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

-- Simple JSON decode (covers our known shapes: strings, numbers, bools, arrays, objects)
local function json_decode(str)
    if str == nil or str == "null" then return nil end
    -- Use Lua pattern matching for simple nested JSON
    -- For production quality we'd use a library, but our data is well-formed
    local fn, err = load("return " .. str:gsub(':', '='):gsub('%[', '{'):gsub('%]', '}')
        :gsub('"([^"]-)"%s*=', '["%1"]=')
        :gsub('true', 'true'):gsub('false', 'false'))
    -- NOTE: This naive approach breaks on strings with colons/brackets.
    -- Use a proper approach instead: serialize to Lua table syntax on write.
    -- For Phase 9.7, we serialize using Lua table syntax (not JSON) for simplicity.
    if fn then return fn() end
    return nil
end

-- Serialize to Lua table literal (safe roundtrip for our data)
local function lua_encode(val)
    if type(val) == "nil" then return "nil" end
    if type(val) == "boolean" then return tostring(val) end
    if type(val) == "number" then return tostring(val) end
    if type(val) == "string" then
        return string.format("%q", val)
    end
    if type(val) == "table" then
        local parts = {}
        -- Check if array
        local is_arr = (#val > 0)
        if is_arr then
            for _, v in ipairs(val) do
                table.insert(parts, lua_encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            for k, v in pairs(val) do
                local key = type(k) == "string" and ("[" .. string.format("%q", k) .. "]") or ("[" .. k .. "]")
                table.insert(parts, key .. "=" .. lua_encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "nil"
end

local function lua_decode(str)
    if not str or str == "nil" then return nil end
    local fn, err = load("return " .. str)
    if fn then return fn() end
    return nil
end

-- ---------------------------------------------------------------------------
-- Critter persistence
-- ---------------------------------------------------------------------------

-- Save a single critter, returns its DB id
function M.save_critter(critter)
    open()
    local scar_str = lua_encode(critter.scars or {})
    if critter.db_id then
        engine.db.exec(db,
            "UPDATE critters SET species_id=?,name=?,level=?,xp=?,hp=?,max_hp=?,"..
            "stat_logic=?,stat_resolve=?,stat_speed=?,disc=?,hold_item=?,"..
            "cooldown_runs=?,scar_data=? WHERE id=?",
            critter.species_id, critter.name, critter.level, critter.xp,
            critter.hp, critter.max_hp,
            critter.stats.logic, critter.stats.resolve, critter.stats.speed,
            critter.disc, critter.hold_item,
            critter.cooldown_runs or 0, scar_str, critter.db_id
        )
    else
        engine.db.exec(db,
            "INSERT INTO critters (species_id,name,level,xp,hp,max_hp,"..
            "stat_logic,stat_resolve,stat_speed,disc,hold_item,cooldown_runs,scar_data)"..
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            critter.species_id, critter.name, critter.level, critter.xp,
            critter.hp, critter.max_hp,
            critter.stats.logic, critter.stats.resolve, critter.stats.speed,
            critter.disc, critter.hold_item,
            critter.cooldown_runs or 0, scar_str
        )
        local rows = engine.db.query(db, "SELECT last_insert_rowid() as id")
        critter.db_id = rows[1] and rows[1].id
    end
    return critter.db_id
end

function M.load_critter_row(row)
    return {
        db_id      = row.id,
        species_id = row.species_id,
        name       = row.name,
        level      = row.level,
        xp         = row.xp,
        hp         = row.hp,
        max_hp     = row.max_hp,
        stats      = {logic=row.stat_logic, resolve=row.stat_resolve, speed=row.stat_speed},
        disc       = row.disc,
        hold_item  = row.hold_item,
        cooldown_runs = row.cooldown_runs or 0,
        scars      = lua_decode(row.scar_data) or {},
        -- Re-derive moves from species data on load
        moves      = M._load_moves_for_species(row.species_id, row.level),
    }
end

function M._load_moves_for_species(species_id, level)
    local species_data = require("data.species")
    for _, sp in ipairs(species_data) do
        if sp.id == species_id then
            -- Return learned moves up to current level
            local learned = {}
            for _, move_entry in ipairs(sp.moveset or {}) do
                if move_entry.level <= level then
                    table.insert(learned, move_entry)
                end
            end
            -- Keep last 4 (or all if fewer)
            while #learned > 4 do table.remove(learned, 1) end
            return learned
        end
    end
    return {}
end

-- ---------------------------------------------------------------------------
-- Player save/load
-- ---------------------------------------------------------------------------

function M.save_player(player)
    open()

    -- Save all roster critters first
    local roster_ids = {}
    for _, critter in ipairs(player.roster or {}) do
        local cid = M.save_critter(critter)
        table.insert(roster_ids, cid)
    end

    -- Party = ordered IDs from roster
    local party_ids = {}
    for _, critter in ipairs(player.party or {}) do
        if critter.db_id then
            table.insert(party_ids, critter.db_id)
        end
    end

    engine.db.exec(db,
        "UPDATE player SET first_launch=?,party_slots=?,inventory_json=?,"..
        "codex_json=?,commits_json=?,unlocks_json=?,lifetime_json=? WHERE id=1",
        player.first_launch and 1 or 0,
        lua_encode(party_ids),
        lua_encode(player.inventory or {}),
        lua_encode(player.codex or {}),
        lua_encode(player.commits or {}),
        lua_encode(player.unlocks or {}),
        lua_encode(player.lifetime or {})
    )
end

function M.load_player()
    open()

    local rows = engine.db.query(db, "SELECT * FROM player WHERE id=1")
    if not rows or #rows == 0 then
        return M._default_player()
    end

    local row = rows[1]

    -- First launch?
    if row.first_launch == 1 then
        return M._default_player()
    end

    -- Load all critters
    local critter_rows = engine.db.query(db, "SELECT * FROM critters ORDER BY id")
    local critters_by_id = {}
    local roster = {}
    for _, cr in ipairs(critter_rows) do
        local critter = M.load_critter_row(cr)
        critters_by_id[cr.id] = critter
        table.insert(roster, critter)
    end

    -- Reconstruct ordered party
    local party_ids = lua_decode(row.party_slots) or {}
    local party = {}
    for _, cid in ipairs(party_ids) do
        if critters_by_id[cid] then
            table.insert(party, critters_by_id[cid])
        end
    end

    local player = {
        first_launch = false,
        roster       = roster,
        party        = party,
        inventory    = lua_decode(row.inventory_json) or {healing={}, catch={}, disc={}, hold={}},
        codex        = lua_decode(row.codex_json)    or {},
        commits      = lua_decode(row.commits_json)  or {},
        unlocks      = lua_decode(row.unlocks_json)  or {},
        lifetime     = lua_decode(row.lifetime_json) or {runs=0, floors=0, catches=0, faints=0, currency=0},
    }

    -- Check for interrupted run
    local run_rows = engine.db.query(db, "SELECT * FROM active_run WHERE id=1")
    if run_rows and #run_rows > 0 then
        -- Interrupted run: apply wipe penalties
        M._apply_interrupted_run(player, run_rows[1])
        engine.db.exec(db, "DELETE FROM active_run WHERE id=1")
    end

    return player
end

function M._apply_interrupted_run(player, run_row)
    -- Critters that were in the party get cooldown (treated as wipe)
    local party_ids = lua_decode(run_row.party_json) or {}
    local critters_by_id = {}
    for _, cr in ipairs(player.roster) do
        if cr.db_id then critters_by_id[cr.db_id] = cr end
    end
    for _, cid in ipairs(party_ids) do
        local critter = critters_by_id[cid]
        if critter then
            critter.cooldown_runs = (critter.cooldown_runs or 0) + 1
        end
    end
    -- Re-save affected critters
    for _, cid in ipairs(party_ids) do
        local critter = critters_by_id[cid]
        if critter then M.save_critter(critter) end
    end
end

function M._default_player()
    return {
        first_launch = true,
        roster       = {},
        party        = {},
        inventory    = {
            healing = {},
            catch   = {"catch_basic", "catch_basic", "catch_basic"},
            disc    = {},
            hold    = {},
        },
        codex     = {},
        commits   = {},
        unlocks   = {},
        lifetime  = {runs=0, floors=0, catches=0, faints=0, currency=0},
    }
end

-- ---------------------------------------------------------------------------
-- Run state (for interrupted run detection)
-- ---------------------------------------------------------------------------

function M.begin_run(run)
    open()
    local party_ids = {}
    for _, critter in ipairs(run.party or {}) do
        if critter.db_id then table.insert(party_ids, critter.db_id) end
    end
    engine.db.exec(db,
        "INSERT OR REPLACE INTO active_run (id,floor,currency,party_json,inv_json) VALUES (1,?,?,?,?)",
        run.floor or 1, run.currency or 0,
        lua_encode(party_ids),
        lua_encode(run.inventory or {})
    )
end

function M.update_run(run)
    open()
    engine.db.exec(db,
        "UPDATE active_run SET floor=?,currency=? WHERE id=1",
        run.floor or 1, run.currency or 0
    )
end

function M.end_run()
    open()
    engine.db.exec(db, "DELETE FROM active_run WHERE id=1")
end

-- ---------------------------------------------------------------------------
-- Achievement helpers
-- ---------------------------------------------------------------------------

function M.grant_commit(player, commit_id)
    if player.commits[commit_id] then return false end
    player.commits[commit_id] = true
    M.save_player(player)
    return true
end

function M.check_unlocks(player)
    -- Check all unlock conditions and update player.unlocks
    local changed = false
    local function unlock(id)
        if not player.unlocks[id] then
            player.unlocks[id] = true
            changed = true
        end
    end

    -- Floor-based
    if (player.lifetime.floors or 0) >= 5  then unlock("biome_select") end
    if (player.lifetime.floors or 0) >= 10 then unlock("hard_mode") end
    if (player.lifetime.floors or 0) >= 15 then unlock("depth_mode") end

    -- Codex-based
    local caught_types = {}
    local caught_count = 0
    local species_data = require("data.species")
    for sp_id, entry in pairs(player.codex) do
        if entry.caught then
            caught_count = caught_count + 1
            for _, sp in ipairs(species_data) do
                if sp.id == sp_id then
                    caught_types[sp.type] = true
                    break
                end
            end
        end
    end

    -- 4th slot: caught one of each starter type (7 types)
    local type_count = 0
    for _ in pairs(caught_types) do type_count = type_count + 1 end
    if type_count >= 7 then unlock("fourth_slot") end

    -- Fill codex
    if caught_count >= #species_data then
        unlock("secret_starter")
        unlock("linus")
    end

    -- Catch all LEGACY species
    local legacy_complete = true
    for _, sp in ipairs(species_data) do
        if sp.type == "LEGACY" then
            if not (player.codex[sp.id] and player.codex[sp.id].caught) then
                legacy_complete = false
                break
            end
        end
    end
    if legacy_complete then unlock("root_encounter") end

    if changed then M.save_player(player) end
    return changed
end

return M
```

---

## Integration Points

### In `dungeon/run.lua` — call `persistence.begin_run()` when run starts:
```lua
function M.new(player)
    local run = {
        party     = {},
        floor     = 1,
        currency  = 10,
        inventory = {},
        caught    = {},
        total_faints = 0,
        extracted = false,
    }
    require("db.persistence").begin_run(run)
    return run
end
```

### In `dungeon/run.lua` — call `persistence.update_run()` when advancing floors:
```lua
function M.advance_floor(run)
    run.floor = run.floor + 1
    require("db.persistence").update_run(run)
end
```

### In `ui/run_over.lua` — call `persistence.end_run()` + `save_player()`:
```lua
function S.load(data)
    -- ... existing code ...
    local persistence = require("db.persistence")
    S._apply_post_run(S.run)
    -- Merge run results into player
    S._merge_run_results(S.run, data.player)
    persistence.end_run()
    persistence.save_player(data.player)
end

function S._merge_run_results(run, player)
    -- Add caught critters to roster
    for _, critter in ipairs(run.caught or {}) do
        table.insert(player.roster, critter)
        -- Update codex
        player.codex[critter.species_id] = player.codex[critter.species_id] or {}
        player.codex[critter.species_id].caught = true
        player.codex[critter.species_id].seen   = true
    end
    -- Update lifetime stats
    player.lifetime.runs     = (player.lifetime.runs or 0) + 1
    player.lifetime.floors   = math.max(player.lifetime.floors or 0, run.floor - 1)
    player.lifetime.catches  = (player.lifetime.catches or 0) + #(run.caught or {})
    player.lifetime.faints   = (player.lifetime.faints or 0) + (run.total_faints or 0)
    player.lifetime.currency = (player.lifetime.currency or 0) + run.currency
end
```

---

## Checklist

- [ ] `db/persistence.lua` — full schema init, `lua_encode`/`lua_decode` helpers
- [ ] `save_critter()` / `load_critter_row()` — single critter round-trip
- [ ] `save_player()` / `load_player()` — full player state round-trip
- [ ] `begin_run()` / `update_run()` / `end_run()` — interrupted run detection
- [ ] `_apply_interrupted_run()` — apply cooldowns on next launch
- [ ] `grant_commit()` — achievement persistence
- [ ] `check_unlocks()` — verify all unlock conditions, unlock + save
- [ ] `_merge_run_results()` in run_over.lua — caught critters → roster, lifetime stats
- [ ] Wire `begin_run()` call in `dungeon/run.lua`
- [ ] Wire `update_run()` call on floor advance
- [ ] Wire `end_run()` + `save_player()` in run_over.lua
- [ ] Test: catch critter → run over → quit → restart → critter in roster
- [ ] Test: quit mid-run → restart → cooldown applied to party critters
- [ ] Test: floor 15 clear → `depth_mode` unlock persists across restart
- [ ] Test: fill codex → `secret_starter` unlock appears in Records tab

local M = {}

-- 14 base items from items.json
M.print_statement  = {id="print_statement",  name="Print Statement",       kind="catch_tool", rarity="common",   base_catch_rate=20,  buy_price=50,   sell_price=25,  description="Prints critter state to stdout. Sometimes catches them off guard."}
M.breakpoint_tool  = {id="breakpoint_tool",  name="Breakpoint",            kind="catch_tool", rarity="uncommon", base_catch_rate=40,  buy_price=150,  sell_price=75,  description="Halts execution at a precise moment. More reliable than print debugging."}
M.try_catch_tool   = {id="try_catch_tool",   name="Try-Catch",             kind="catch_tool", rarity="rare",     base_catch_rate=60,  buy_price=300,  sell_price=150, description="High success rate, but failures let the critter counter-attack."}
M.linter_tool      = {id="linter_tool",      name="Linter",                kind="catch_tool", rarity="epic",     base_catch_rate=50,  buy_price=500,  sell_price=250, description="Static analysis. Moderate but consistent catch rate."}
M.formal_proof_tool= {id="formal_proof_tool",name="Formal Proof",          kind="catch_tool", rarity="epic",     base_catch_rate=70,  buy_price=800,  sell_price=400, description="Mathematically rigorous containment. Expensive but highly effective."}
M.small_patch      = {id="small_patch",      name="Small Patch",           kind="healing",    rarity="common",   heal_amount=30,      buy_price=40,   sell_price=20,  description="Restores a small amount of HP."}
M.hotfix           = {id="hotfix",           name="Hotfix",                kind="healing",    rarity="uncommon", heal_amount=80,      buy_price=100,  sell_price=50,  description="Emergency production patch. Restores moderate HP."}
M.full_rebuild     = {id="full_rebuild",     name="Full Rebuild",          kind="healing",    rarity="rare",     heal_amount=9999,    buy_price=500,  sell_price=250, description="Wipes the build cache and recompiles. Fully restores HP."}
M.git_revert       = {id="git_revert",       name="Git Revert",            kind="revive",     rarity="rare",     revive_percent=50,   buy_price=300,  sell_price=150, description="Rolls back to a known good state. Revives at 50% HP."}
M.disc_buffer_overflow = {id="disc_buffer_overflow", name="Move Disc: Buffer Overflow", kind="move_disc", rarity="uncommon", move_id="buffer_overflow", buy_price=400, sell_price=200, description="Equip to third move slot."}
M.disc_mutex_lock  = {id="disc_mutex_lock",  name="Move Disc: Mutex Lock", kind="move_disc",  rarity="uncommon", move_id="mutex_lock",  buy_price=350,  sell_price=175, description="Equip to third move slot."}
M["code_review"]   = {id="code_review",      name="Code Review",           kind="xp_grant",   rarity="uncommon", xp_amount=150,       buy_price=200,  sell_price=100, description="Thorough peer review. Grants 150 XP."}
M.tech_talk        = {id="tech_talk",        name="Tech Talk",             kind="xp_grant",   rarity="rare",     xp_amount=500,       buy_price=500,  sell_price=250, description="Conference talk. Grants 500 XP."}
M.pair_programming = {id="pair_programming", name="Pair Programming",      kind="xp_grant",   rarity="epic",     xp_amount=1500,      buy_price=1200, sell_price=600, description="Intensive expert pairing. Grants 1500 XP."}

-- 13 hold items from DESIGN.md (not in JSON)
M.config_file      = {id="config_file",      name="Config File",        kind="hold", effect="max_chosen_stat",    buy_price=400,  sell_price=200, description="Set one chosen stat to its maximum value for the battle."}
M.ssd_cache        = {id="ssd_cache",        name="SSD Cache",          kind="hold", effect="first_hit_guarantee",buy_price=350,  sell_price=175, description="First move each battle ignores accuracy roll."}
M.memory_leak      = {id="memory_leak",      name="Memory Leak",        kind="hold", effect="regen_5pct",         buy_price=300,  sell_price=150, description="Recover 5% max HP at end of each turn."}
M.mutex_lock_hold  = {id="mutex_lock_hold",  name="Mutex Lock (Hold)",  kind="hold", effect="immune_blocked",     buy_price=400,  sell_price=200, description="Immune to Blocked status."}
M.tech_debt_hold   = {id="tech_debt_hold",   name="Tech Debt (Hold)",   kind="hold", effect="start_in_the_zone",  buy_price=450,  sell_price=225, description="Start battle with In The Zone (+30% Logic, -20% Resolve)."}
M.unit_tests       = {id="unit_tests",       name="Unit Tests",         kind="hold", effect="one_time_negate",    buy_price=500,  sell_price=250, description="When HP drops below 25%, negate all damage once."}
M.root_access      = {id="root_access",      name="Root Access",        kind="hold", effect="min_neutral_eff",    buy_price=600,  sell_price=300, description="All moves deal minimum 1.0× effectiveness."}
M.two_monitors     = {id="two_monitors",     name="Two Monitors",       kind="hold", effect="double_action_half", buy_price=700,  sell_price=350, description="Use two actions per turn, each at 50% power."}
M.syntax_error     = {id="syntax_error",     name="Syntax Error",       kind="hold", effect="waste_first_turn",   buy_price=400,  sell_price=200, description="Opponent wastes their first turn on battle entry."}
M.documentation    = {id="documentation",    name="Documentation",      kind="hold", effect="reveal_enemy_stats", buy_price=350,  sell_price=175, description="Reveal enemy's full moveset and stats at battle start."}
M.garbage_collector= {id="garbage_collector",name="Garbage Collector",  kind="hold", effect="cleanse_every_2",    buy_price=450,  sell_price=225, description="Remove own status effect every 2nd turn."}
M.fork_bomb        = {id="fork_bomb",        name="Fork Bomb",          kind="hold", effect="on_faint_damage_30", buy_price=350,  sell_price=175, description="On faint, deal 30% of max HP as damage to opponent."}
M.singleton_pattern= {id="singleton_pattern",name="Singleton Pattern",  kind="hold", effect="last_alive_boost",   buy_price=500,  sell_price=250, description="Last critter in party alive: +25% to all stats."}

function M.get(id)
  return M[id]
end

function M.is_catch_tool(id)
  local item = M[id]
  return item and item.kind == "catch_tool"
end

return M

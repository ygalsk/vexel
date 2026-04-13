-- All 61 species. Fields mapped from species.json:
--   critter_type (from critter_type), rarity, base_{hp,logic,resolve,speed}
--   move1 (signature_move), move2 (secondary_move, nil if none)
--   evolves_to (nil if none), evolution_level (nil if none)
--   archetype: deployer|hotfix|monolith|uptime|regression|reviewer|zero_day

local M = {}

-- === COMMON BASE FORMS (starter triangle + first-forms) ===

M.println = {
  id="println", name="Println", critter_type="debug", rarity="common", archetype="deployer",
  base_hp=45, base_logic=55, base_resolve=40, base_speed=50,
  move1="log_dump", move2=nil, evolves_to="tracer", evolution_level=12,
}
M.tracer = {
  id="tracer", name="Tracer", critter_type="debug", rarity="common", archetype="deployer",
  base_hp=60, base_logic=75, base_resolve=55, base_speed=60,
  move1="log_dump", move2="stack_trace", evolves_to="profiler", evolution_level=28,
}
M.glitch = {
  id="glitch", name="Glitch", critter_type="chaos", rarity="common", archetype="regression",
  base_hp=40, base_logic=60, base_resolve=35, base_speed=65,
  move1="bit_flip", move2=nil, evolves_to="gremlin", evolution_level=14,
}
M["goto"] = {
  id="goto", name="Goto", critter_type="legacy", rarity="common", archetype="deployer",
  base_hp=50, base_logic=45, base_resolve=55, base_speed=40,
  move1="jump_table", move2=nil, evolves_to="spaghetto", evolution_level=13,
}
M.monad = {
  id="monad", name="Monad", critter_type="wisdom", rarity="common", archetype="deployer",
  base_hp=35, base_logic=70, base_resolve=45, base_speed=50,
  move1="bind", move2=nil, evolves_to="functor", evolution_level=15,
}
M.copilot = {
  id="copilot", name="Copilot", critter_type="vibe", rarity="common", archetype="deployer",
  base_hp=40, base_logic=50, base_resolve=45, base_speed=65,
  move1="ship_it", move2=nil, evolves_to="autopilot", evolution_level=14,
}
M.segfault = {
  id="segfault", name="Segfault", critter_type="chaos", rarity="common", archetype="regression",
  base_hp=45, base_logic=60, base_resolve=30, base_speed=55,
  move1="access_violation", move2=nil, evolves_to="stack_overflow", evolution_level=14,
}
M.mutex = {
  id="mutex", name="Mutex", critter_type="patience", rarity="common", archetype="uptime",
  base_hp=55, base_logic=40, base_resolve=60, base_speed=35,
  move1="mutex_lock", move2=nil, evolves_to="semaphore", evolution_level=13,
}
M.lgtm = {
  id="lgtm", name="LGTM", critter_type="snark", rarity="common", archetype="regression",
  base_hp=40, base_logic=55, base_resolve=50, base_speed=55,
  move1="code_review", move2=nil, evolves_to="nitpick", evolution_level=13,
}
M.singleton = {
  id="singleton", name="Singleton", critter_type="legacy", rarity="common", archetype="deployer",
  base_hp=50, base_logic=45, base_resolve=55, base_speed=40,
  move1="global_state", move2=nil, evolves_to="god_object", evolution_level=13,
}
M.printf = {
  id="printf", name="Printf", critter_type="debug", rarity="common", archetype="deployer",
  base_hp=40, base_logic=55, base_resolve=45, base_speed=50,
  move1="print_debug", move2=nil, evolves_to="fprintf", evolution_level=12,
}

-- === COMMON EVOLUTIONS ===

M.gremlin = {
  id="gremlin", name="Gremlin", critter_type="chaos", rarity="common", archetype="deployer",
  base_hp=50, base_logic=80, base_resolve=45, base_speed=75,
  move1="bit_flip", move2="null_deref", evolves_to="pandemonium", evolution_level=30,
}
M.spaghetto = {
  id="spaghetto", name="Spaghetto", critter_type="legacy", rarity="common", archetype="deployer",
  base_hp=65, base_logic=55, base_resolve=70, base_speed=60,
  move1="jump_table", move2="tech_debt", evolves_to="dependency", evolution_level=28,
}
M.functor = {
  id="functor", name="Functor", critter_type="wisdom", rarity="common", archetype="deployer",
  base_hp=45, base_logic=85, base_resolve=55, base_speed=65,
  move1="bind", move2="fmap", evolves_to="burrito", evolution_level=28,
}
M.autopilot = {
  id="autopilot", name="Autopilot", critter_type="vibe", rarity="common", archetype="deployer",
  base_hp=50, base_logic=65, base_resolve=55, base_speed=80,
  move1="ship_it", move2="autocomplete", evolves_to="hallucination", evolution_level=28,
}
M.stack_overflow = {
  id="stack_overflow", name="Stack Overflow", critter_type="chaos", rarity="common", archetype="hotfix",
  base_hp=55, base_logic=75, base_resolve=40, base_speed=80,
  move1="access_violation", move2="stack_smash", evolves_to="kernel_panic_critter", evolution_level=30,
}
M.god_object = {
  id="god_object", name="God Object", critter_type="legacy", rarity="common", archetype="deployer",
  base_hp=65, base_logic=55, base_resolve=70, base_speed=60,
  move1="global_state", move2="feature_creep", evolves_to="monolith", evolution_level=28,
}
M.semaphore = {
  id="semaphore", name="Semaphore", critter_type="patience", rarity="common", archetype="uptime",
  base_hp=70, base_logic=50, base_resolve=75, base_speed=55,
  move1="mutex_lock", move2="semaphore_wait", evolves_to="deadlock", evolution_level=28,
}
M.nitpick = {
  id="nitpick", name="Nitpick", critter_type="snark", rarity="common", archetype="regression",
  base_hp=50, base_logic=70, base_resolve=60, base_speed=70,
  move1="code_review", move2="nit", evolves_to="bikeshed", evolution_level=28,
}
M.fprintf = {
  id="fprintf", name="Fprintf", critter_type="debug", rarity="common", archetype="deployer",
  base_hp=55, base_logic=70, base_resolve=55, base_speed=70,
  move1="print_debug", move2="format_string", evolves_to="logstash", evolution_level=28,
}

-- === UNCOMMON FINAL FORMS ===

M.pandemonium = {
  id="pandemonium", name="Pandemonium", critter_type="chaos", rarity="uncommon", archetype="hotfix",
  base_hp=60, base_logic=100, base_resolve=50, base_speed=110,
  move1="buffer_overflow", move2="kernel_panic", evolves_to=nil, evolution_level=nil,
}
M.dependency = {
  id="dependency", name="Dependency", critter_type="legacy", rarity="uncommon", archetype="monolith",
  base_hp=100, base_logic=60, base_resolve=95, base_speed=65,
  move1="tech_debt", move2="vendor_lock", evolves_to=nil, evolution_level=nil,
}
M.profiler = {
  id="profiler", name="Profiler", critter_type="debug", rarity="uncommon", archetype="deployer",
  base_hp=75, base_logic=95, base_resolve=65, base_speed=85,
  move1="stack_trace", move2="heap_profile", evolves_to=nil, evolution_level=nil,
}
M.logstash = {
  id="logstash", name="Logstash", critter_type="debug", rarity="uncommon", archetype="deployer",
  base_hp=70, base_logic=90, base_resolve=75, base_speed=80,
  move1="format_string", move2="structured_log", evolves_to=nil, evolution_level=nil,
}
M.kernel_panic_critter = {
  id="kernel_panic_critter", name="Kernel Panic", critter_type="chaos", rarity="uncommon", archetype="hotfix",
  base_hp=65, base_logic=95, base_resolve=55, base_speed=100,
  move1="stack_smash", move2="kernel_panic", evolves_to=nil, evolution_level=nil,
}
M.monolith = {
  id="monolith", name="Monolith", critter_type="legacy", rarity="uncommon", archetype="monolith",
  base_hp=110, base_logic=55, base_resolve=100, base_speed=50,
  move1="feature_creep", move2="big_ball_of_mud", evolves_to=nil, evolution_level=nil,
}
M.deadlock = {
  id="deadlock", name="Deadlock", critter_type="patience", rarity="uncommon", archetype="monolith",
  base_hp=90, base_logic=55, base_resolve=100, base_speed=70,
  move1="semaphore_wait", move2="resource_starvation", evolves_to=nil, evolution_level=nil,
}
M.burrito = {
  id="burrito", name="Burrito", critter_type="wisdom", rarity="uncommon", archetype="deployer",
  base_hp=55, base_logic=105, base_resolve=70, base_speed=85,
  move1="fmap", move2="category_theory", evolves_to=nil, evolution_level=nil,
}
M.bikeshed = {
  id="bikeshed", name="Bikeshed", critter_type="snark", rarity="uncommon", archetype="regression",
  base_hp=60, base_logic=85, base_resolve=80, base_speed=90,
  move1="nit", move2="bikeshedding", evolves_to=nil, evolution_level=nil,
}
M.hallucination = {
  id="hallucination", name="Hallucination", critter_type="vibe", rarity="uncommon", archetype="hotfix",
  base_hp=60, base_logic=85, base_resolve=60, base_speed=110,
  move1="autocomplete", move2="confabulate", evolves_to=nil, evolution_level=nil,
}
M.todo = {
  id="todo", name="TODO", critter_type="snark", rarity="uncommon", archetype="regression",
  base_hp=65, base_logic=75, base_resolve=70, base_speed=80,
  move1="nit", move2="code_review", evolves_to="fixme", evolution_level=32,
}
M.readme = {
  id="readme", name="README", critter_type="vibe", rarity="uncommon", archetype="deployer",
  base_hp=60, base_logic=70, base_resolve=55, base_speed=100,
  move1="autocomplete", move2="ship_it", evolves_to="no_tests", evolution_level=32,
}
M.makefile = {
  id="makefile", name="Makefile", critter_type="legacy", rarity="uncommon", archetype="uptime",
  base_hp=85, base_logic=55, base_resolve=90, base_speed=55,
  move1="tech_debt", move2="global_state", evolves_to="jenkins", evolution_level=32,
}

-- === UNCOMMON WITH EVOLUTIONS (mid-tier) ===

M.breakpoint = {
  id="breakpoint", name="Breakpoint", critter_type="debug", rarity="uncommon", archetype="deployer",
  base_hp=70, base_logic=80, base_resolve=70, base_speed=70,
  move1="breakpoint_set", move2="stack_trace", evolves_to="watchpoint", evolution_level=32,
}
M.fuzzer = {
  id="fuzzer", name="Fuzzer", critter_type="chaos", rarity="uncommon", archetype="hotfix",
  base_hp=55, base_logic=85, base_resolve=50, base_speed=95,
  move1="fuzz_input", move2="bit_flip", evolves_to="chaos_monkey", evolution_level=32,
}
M.queue = {
  id="queue", name="Queue", critter_type="patience", rarity="uncommon", archetype="uptime",
  base_hp=80, base_logic=55, base_resolve=85, base_speed=65,
  move1="semaphore_wait", move2="mutex_lock", evolves_to="priority_queue", evolution_level=32,
}
M.hashmap = {
  id="hashmap", name="Hashmap", critter_type="wisdom", rarity="uncommon", archetype="deployer",
  base_hp=55, base_logic=90, base_resolve=60, base_speed=85,
  move1="pattern_match", move2="fmap", evolves_to="b_tree", evolution_level=32,
}

-- === RARE FINAL FORMS ===

M.watchpoint = {
  id="watchpoint", name="Watchpoint", critter_type="debug", rarity="rare", archetype="deployer",
  base_hp=85, base_logic=100, base_resolve=80, base_speed=95,
  move1="breakpoint_set", move2="memory_watch", evolves_to=nil, evolution_level=nil,
}
M.chaos_monkey = {
  id="chaos_monkey", name="Chaos Monkey", critter_type="chaos", rarity="rare", archetype="hotfix",
  base_hp=70, base_logic=110, base_resolve=60, base_speed=120,
  move1="fuzz_input", move2="process_kill", evolves_to=nil, evolution_level=nil,
}
M.priority_queue = {
  id="priority_queue", name="Priority Queue", critter_type="patience", rarity="rare", archetype="uptime",
  base_hp=100, base_logic=70, base_resolve=105, base_speed=85,
  move1="semaphore_wait", move2="priority_boost", evolves_to=nil, evolution_level=nil,
}
M.b_tree = {
  id="b_tree", name="B-Tree", critter_type="wisdom", rarity="rare", archetype="deployer",
  base_hp=75, base_logic=110, base_resolve=80, base_speed=95,
  move1="pattern_match", move2="rebalance", evolves_to=nil, evolution_level=nil,
}
M.fixme = {
  id="fixme", name="FIXME", critter_type="snark", rarity="rare", archetype="hotfix",
  base_hp=75, base_logic=95, base_resolve=85, base_speed=110,
  move1="nit", move2="bikeshedding", evolves_to=nil, evolution_level=nil,
}
M.no_tests = {
  id="no_tests", name="No Tests", critter_type="vibe", rarity="rare", archetype="hotfix",
  base_hp=55, base_logic=115, base_resolve=50, base_speed=130,
  move1="autocomplete", move2="confabulate", evolves_to=nil, evolution_level=nil,
}
M.jenkins = {
  id="jenkins", name="Jenkins", critter_type="legacy", rarity="rare", archetype="monolith",
  base_hp=115, base_logic=60, base_resolve=110, base_speed=55,
  move1="tech_debt", move2="vendor_lock", evolves_to=nil, evolution_level=nil,
}
M.heisenbug = {
  id="heisenbug", name="Heisenbug", critter_type="debug", rarity="rare", archetype="hotfix",
  base_hp=65, base_logic=90, base_resolve=60, base_speed=140,
  move1="observer_effect", move2="memory_watch", evolves_to=nil, evolution_level=nil,
}
M.bobby_tables = {
  id="bobby_tables", name="Bobby Tables", critter_type="chaos", rarity="rare", archetype="hotfix",
  base_hp=60, base_logic=120, base_resolve=45, base_speed=130,
  move1="sql_injection", move2="process_kill", evolves_to=nil, evolution_level=nil,
}
M.cron = {
  id="cron", name="Cron", critter_type="patience", rarity="rare", archetype="deployer",
  base_hp=90, base_logic=80, base_resolve=95, base_speed=90,
  move1="cron_job", move2="priority_boost", evolves_to=nil, evolution_level=nil,
}
M.rubber_duck = {
  id="rubber_duck", name="Rubber Duck", critter_type="wisdom", rarity="rare", archetype="deployer",
  base_hp=80, base_logic=100, base_resolve=90, base_speed=85,
  move1="explain_yourself", move2="rebalance", evolves_to=nil, evolution_level=nil,
}
M.four_oh_four = {
  id="four_oh_four", name="404", critter_type="snark", rarity="rare", archetype="hotfix",
  base_hp=55, base_logic=80, base_resolve=75, base_speed=145,
  move1="bikeshedding", move2="nit", evolves_to=nil, evolution_level=nil,
}
M.yolo = {
  id="yolo", name="YOLO", critter_type="vibe", rarity="rare", archetype="hotfix",
  base_hp=70, base_logic=130, base_resolve=45, base_speed=110,
  move1="ship_it", move2="confabulate", evolves_to=nil, evolution_level=nil,
}
M.cobol = {
  id="cobol", name="COBOL", critter_type="legacy", rarity="rare", archetype="monolith",
  base_hp=130, base_logic=65, base_resolve=120, base_speed=45,
  move1="big_ball_of_mud", move2="vendor_lock", evolves_to=nil, evolution_level=nil,
}

-- === EPIC SPECIES (zero_day archetype) ===

M.valgrind = {
  id="valgrind", name="Valgrind", critter_type="debug", rarity="epic", archetype="zero_day",
  base_hp=110, base_logic=150, base_resolve=130, base_speed=30,
  move1="memory_scan", move2="heap_profile", evolves_to=nil, evolution_level=nil,
}
M.race_condition = {
  id="race_condition", name="Race Condition", critter_type="chaos", rarity="epic", archetype="zero_day",
  base_hp=80, base_logic=140, base_resolve=60, base_speed=145,
  move1="data_race", move2="kernel_panic", evolves_to=nil, evolution_level=nil,
}
M.load_balancer = {
  id="load_balancer", name="Load Balancer", critter_type="patience", rarity="epic", archetype="zero_day",
  base_hp=160, base_logic=50, base_resolve=120, base_speed=90,
  move1="priority_boost", move2="resource_starvation", evolves_to=nil, evolution_level=nil,
}
M.turing_machine = {
  id="turing_machine", name="Turing Machine", critter_type="wisdom", rarity="epic", archetype="zero_day",
  base_hp=95, base_logic=145, base_resolve=105, base_speed=70,
  move1="category_theory", move2="pattern_match", evolves_to=nil, evolution_level=nil,
}
M.regex = {
  id="regex", name="Regex", critter_type="snark", rarity="epic", archetype="zero_day",
  base_hp=85, base_logic=150, base_resolve=80, base_speed=115,
  move1="regex_match", move2="bikeshedding", evolves_to=nil, evolution_level=nil,
}
M.prompt_engineer = {
  id="prompt_engineer", name="Prompt Engineer", critter_type="vibe", rarity="epic", archetype="zero_day",
  base_hp=110, base_logic=5, base_resolve=155, base_speed=145,
  move1="prompt", move2="autocomplete", evolves_to=nil, evolution_level=nil,
}
M.mainframe = {
  id="mainframe", name="Mainframe", critter_type="legacy", rarity="epic", archetype="zero_day",
  base_hp=220, base_logic=85, base_resolve=130, base_speed=5,
  move1="core_dump", move2="big_ball_of_mud", evolves_to=nil, evolution_level=nil,
}

-- === LEGENDARY SPECIES (zero_day archetype) ===

M.root = {
  id="root", name="Root", critter_type="legacy", rarity="legendary", archetype="zero_day",
  base_hp=130, base_logic=110, base_resolve=135, base_speed=100,
  move1="sudo", move2="vendor_lock", evolves_to=nil, evolution_level=nil,
}
M.zero_day = {
  id="zero_day", name="Zero Day", critter_type="chaos", rarity="legendary", archetype="zero_day",
  base_hp=90, base_logic=145, base_resolve=80, base_speed=160,
  move1="zero_day_exploit", move2="process_kill", evolves_to=nil, evolution_level=nil,
}
M.linus = {
  id="linus", name="Linus", critter_type="wisdom", rarity="legendary", archetype="zero_day",
  base_hp=110, base_logic=135, base_resolve=120, base_speed=105,
  move1="revert", move2="explain_yourself", evolves_to=nil, evolution_level=nil,
}

function M.get(id)
  return M[id]
end

return M

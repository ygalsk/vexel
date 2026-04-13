local M = {}

-- 50 base moves from moves.json
-- Fields: id, name, move_type, power, accuracy, status_effect (nil if none), status_chance (0 if none)

M.log_dump             = {id="log_dump",             name="Log Dump",             move_type="debug",    power=40,  accuracy=100, status_effect=nil,          status_chance=0  }
M.stack_trace          = {id="stack_trace",          name="Stack Trace",          move_type="debug",    power=65,  accuracy=90,  status_effect="linted",      status_chance=20 }
M.bit_flip             = {id="bit_flip",             name="Bit Flip",             move_type="chaos",    power=45,  accuracy=95,  status_effect="segfaulted",  status_chance=15 }
M.buffer_overflow      = {id="buffer_overflow",      name="Buffer Overflow",      move_type="chaos",    power=70,  accuracy=80,  status_effect=nil,           status_chance=0  }
M.jump_table           = {id="jump_table",           name="Jump Table",           move_type="legacy",   power=40,  accuracy=100, status_effect=nil,           status_chance=0  }
M.tech_debt            = {id="tech_debt",            name="Tech Debt",            move_type="legacy",   power=60,  accuracy=85,  status_effect="deprecated",  status_chance=25 }
M.bind                 = {id="bind",                 name="Bind",                 move_type="wisdom",   power=50,  accuracy=95,  status_effect=nil,           status_chance=0  }
M.pattern_match        = {id="pattern_match",        name="Pattern Match",        move_type="wisdom",   power=70,  accuracy=90,  status_effect=nil,           status_chance=0  }
M.mutex_lock           = {id="mutex_lock",           name="Mutex Lock",           move_type="patience", power=35,  accuracy=100, status_effect="blocked",     status_chance=40 }
M.code_review          = {id="code_review",          name="Code Review",          move_type="snark",    power=55,  accuracy=90,  status_effect="tilted",      status_chance=20 }
M.ship_it              = {id="ship_it",              name="Ship It",              move_type="vibe",     power=80,  accuracy=70,  status_effect=nil,           status_chance=0  }
M.tackle               = {id="tackle",               name="Tackle",               move_type="debug",    power=30,  accuracy=100, status_effect=nil,           status_chance=0  }
M.null_deref           = {id="null_deref",           name="Null Deref",           move_type="chaos",    power=55,  accuracy=90,  status_effect="segfaulted",  status_chance=20 }
M.heap_profile         = {id="heap_profile",         name="Heap Profile",         move_type="debug",    power=85,  accuracy=85,  status_effect="linted",      status_chance=25 }
M.kernel_panic         = {id="kernel_panic",         name="Kernel Panic",         move_type="chaos",    power=90,  accuracy=75,  status_effect="segfaulted",  status_chance=25 }
M.vendor_lock          = {id="vendor_lock",          name="Vendor Lock",          move_type="legacy",   power=80,  accuracy=85,  status_effect="deprecated",  status_chance=30 }
M.print_debug          = {id="print_debug",          name="Print Debug",          move_type="debug",    power=35,  accuracy=100, status_effect=nil,           status_chance=0  }
M.format_string        = {id="format_string",        name="Format String",        move_type="debug",    power=60,  accuracy=90,  status_effect="linted",      status_chance=15 }
M.structured_log       = {id="structured_log",       name="Structured Log",       move_type="debug",    power=80,  accuracy=85,  status_effect="linted",      status_chance=25 }
M.access_violation     = {id="access_violation",     name="Access Violation",     move_type="chaos",    power=40,  accuracy=95,  status_effect="segfaulted",  status_chance=15 }
M.stack_smash          = {id="stack_smash",          name="Stack Smash",          move_type="chaos",    power=65,  accuracy=85,  status_effect="segfaulted",  status_chance=20 }
M.global_state         = {id="global_state",         name="Global State",         move_type="legacy",   power=40,  accuracy=100, status_effect=nil,           status_chance=0  }
M.feature_creep        = {id="feature_creep",        name="Feature Creep",        move_type="legacy",   power=60,  accuracy=90,  status_effect="deprecated",  status_chance=20 }
M.big_ball_of_mud      = {id="big_ball_of_mud",      name="Big Ball of Mud",      move_type="legacy",   power=85,  accuracy=80,  status_effect="deprecated",  status_chance=30 }
M.semaphore_wait       = {id="semaphore_wait",       name="Semaphore Wait",       move_type="patience", power=55,  accuracy=95,  status_effect="blocked",     status_chance=30 }
M.resource_starvation  = {id="resource_starvation",  name="Resource Starvation",  move_type="patience", power=75,  accuracy=85,  status_effect="blocked",     status_chance=35 }
M.fmap                 = {id="fmap",                 name="Fmap",                 move_type="wisdom",   power=55,  accuracy=95,  status_effect="enlightened", status_chance=15 }
M.category_theory      = {id="category_theory",      name="Category Theory",      move_type="wisdom",   power=80,  accuracy=85,  status_effect="enlightened", status_chance=25 }
M.nit                  = {id="nit",                  name="Nit",                  move_type="snark",    power=50,  accuracy=95,  status_effect="tilted",      status_chance=25 }
M.bikeshedding         = {id="bikeshedding",         name="Bikeshedding",         move_type="snark",    power=75,  accuracy=85,  status_effect="tilted",      status_chance=30 }
M.autocomplete         = {id="autocomplete",         name="Autocomplete",         move_type="vibe",     power=55,  accuracy=90,  status_effect="hallucinating",status_chance=15}
M.confabulate          = {id="confabulate",          name="Confabulate",          move_type="vibe",     power=80,  accuracy=75,  status_effect="hallucinating",status_chance=25}
M.breakpoint_set       = {id="breakpoint_set",       name="Breakpoint Set",       move_type="debug",    power=70,  accuracy=90,  status_effect="linted",      status_chance=25 }
M.memory_watch         = {id="memory_watch",         name="Memory Watch",         move_type="debug",    power=85,  accuracy=85,  status_effect="linted",      status_chance=30 }
M.observer_effect      = {id="observer_effect",      name="Observer Effect",      move_type="debug",    power=75,  accuracy=70,  status_effect=nil,           status_chance=0  }
M.fuzz_input           = {id="fuzz_input",           name="Fuzz Input",           move_type="chaos",    power=60,  accuracy=80,  status_effect="segfaulted",  status_chance=25 }
M.process_kill         = {id="process_kill",         name="Process Kill",         move_type="chaos",    power=90,  accuracy=80,  status_effect="segfaulted",  status_chance=30 }
M.sql_injection        = {id="sql_injection",        name="SQL Injection",        move_type="chaos",    power=95,  accuracy=75,  status_effect="segfaulted",  status_chance=35 }
M.priority_boost       = {id="priority_boost",       name="Priority Boost",       move_type="patience", power=70,  accuracy=90,  status_effect="blocked",     status_chance=30 }
M.cron_job             = {id="cron_job",             name="Cron Job",             move_type="patience", power=85,  accuracy=85,  status_effect="blocked",     status_chance=35 }
M.rebalance            = {id="rebalance",            name="Rebalance",            move_type="wisdom",   power=75,  accuracy=90,  status_effect="enlightened", status_chance=25 }
M.explain_yourself     = {id="explain_yourself",     name="Explain Yourself",     move_type="wisdom",   power=70,  accuracy=95,  status_effect="enlightened", status_chance=35 }
M.memory_scan          = {id="memory_scan",          name="Memory Scan",          move_type="debug",    power=95,  accuracy=90,  status_effect="linted",      status_chance=30 }
M.data_race            = {id="data_race",            name="Data Race",            move_type="chaos",    power=100, accuracy=65,  status_effect="segfaulted",  status_chance=40 }
M.regex_match          = {id="regex_match",          name="Regex Match",          move_type="snark",    power=120, accuracy=50,  status_effect="tilted",      status_chance=40 }
M.prompt               = {id="prompt",               name="Prompt",               move_type="vibe",     power=0,   accuracy=100, status_effect="in_the_zone", status_chance=100}
M.core_dump            = {id="core_dump",            name="Core Dump",            move_type="legacy",   power=110, accuracy=70,  status_effect="deprecated",  status_chance=35 }
M.sudo                 = {id="sudo",                 name="Sudo",                 move_type="legacy",   power=90,  accuracy=90,  status_effect=nil,           status_chance=0  }
M.zero_day_exploit     = {id="zero_day_exploit",     name="Zero Day Exploit",     move_type="chaos",    power=100, accuracy=85,  status_effect="segfaulted",  status_chance=30 }
M.revert               = {id="revert",               name="Revert",               move_type="wisdom",   power=75,  accuracy=95,  status_effect="enlightened", status_chance=40 }

-- 21 move discs: 7 types × 3 tiers (from DESIGN.md: 50/95, 70/85, 90/75)
local DISC_TIERS = {
  {power = 50, accuracy = 95, suffix = "I"},
  {power = 70, accuracy = 85, suffix = "II"},
  {power = 90, accuracy = 75, suffix = "III"},
}
for _, t in ipairs({"debug","patience","chaos","wisdom","snark","vibe","legacy"}) do
  local tname = t:sub(1,1):upper() .. t:sub(2)
  for tier, cfg in ipairs(DISC_TIERS) do
    local id = "disc_" .. t .. "_" .. tier
    M[id] = {
      id            = id,
      name          = tname .. " Disc " .. cfg.suffix,
      move_type     = t,
      power         = cfg.power,
      accuracy      = cfg.accuracy,
      status_effect = nil,
      status_chance = 0,
      is_disc       = true,
    }
  end
end

function M.get(id)
  return M[id]
end

return M
